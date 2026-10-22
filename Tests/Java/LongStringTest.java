import dalvik.system.DexClassLoader;
import java.nio.file.*;
import java.util.*;
import java.util.zip.*;
import org.jf.dexlib2.*;
import org.jf.dexlib2.immutable.*;
import org.jf.dexlib2.immutable.instruction.*;
import org.jf.dexlib2.immutable.reference.*;
import org.jf.dexlib2.writer.io.MemoryDataStore;
import org.jf.dexlib2.writer.pool.DexPool;

/**
 * 风云 in the FTY jar keeps a whole Python spider in one const-string, in the register just below `this`.
 * dex2jar split strings of 32767+ characters into a StringBuilder that used the next register as scratch,
 * so `this` became the last piece of the string and the JVM refused the class (VerifyError).
 */
public final class LongStringTest {
    static final String PROBE = "Ltvbox/LongStringProbe;";
    static void check(boolean value, String message) { if (!value) throw new AssertionError(message); }

    /** run(String tail): const-string v0, text; invoke-virtual {p0, v0, p1} join; the shape of 风云's init. */
    static byte[] probeDex(String text) throws Exception {
        var join = new ImmutableMethodReference(PROBE, "join", List.of("Ljava/lang/String;", "Ljava/lang/String;"), "Ljava/lang/String;");
        var concat = new ImmutableMethodReference("Ljava/lang/String;", "concat", List.of("Ljava/lang/String;"), "Ljava/lang/String;");
        var objectInit = new ImmutableMethodReference("Ljava/lang/Object;", "<init>", List.of(), "V");
        var init = new ImmutableMethod(PROBE, "<init>", List.of(), "V", AccessFlags.PUBLIC.getValue() | AccessFlags.CONSTRUCTOR.getValue(), Set.of(), Set.of(),
            new ImmutableMethodImplementation(1, List.of(
                new ImmutableInstruction35c(Opcode.INVOKE_DIRECT, 1, 0, 0, 0, 0, 0, objectInit),
                new ImmutableInstruction10x(Opcode.RETURN_VOID)), null, null));
        var run = new ImmutableMethod(PROBE, "run", List.of(new ImmutableMethodParameter("Ljava/lang/String;", Set.of(), null)), "Ljava/lang/String;", AccessFlags.PUBLIC.getValue(), Set.of(), Set.of(),
            new ImmutableMethodImplementation(3, List.of(
                new ImmutableInstruction21c(Opcode.CONST_STRING, 0, new ImmutableStringReference(text)),
                new ImmutableInstruction35c(Opcode.INVOKE_VIRTUAL, 3, 1, 0, 2, 0, 0, join),
                new ImmutableInstruction11x(Opcode.MOVE_RESULT_OBJECT, 0),
                new ImmutableInstruction11x(Opcode.RETURN_OBJECT, 0)), null, null));
        var joinMethod = new ImmutableMethod(PROBE, "join", List.of(new ImmutableMethodParameter("Ljava/lang/String;", Set.of(), null), new ImmutableMethodParameter("Ljava/lang/String;", Set.of(), null)), "Ljava/lang/String;", AccessFlags.PUBLIC.getValue(), Set.of(), Set.of(),
            new ImmutableMethodImplementation(4, List.of(
                new ImmutableInstruction35c(Opcode.INVOKE_VIRTUAL, 2, 2, 3, 0, 0, 0, concat),
                new ImmutableInstruction11x(Opcode.MOVE_RESULT_OBJECT, 0),
                new ImmutableInstruction11x(Opcode.RETURN_OBJECT, 0)), null, null));
        var pool = new DexPool(Opcodes.getDefault());
        pool.internClass(new ImmutableClassDef(PROBE, AccessFlags.PUBLIC.getValue(), "Ljava/lang/Object;", List.of(), null, Set.of(), List.of(), List.of(init, run, joinMethod)));
        var store = new MemoryDataStore();
        pool.writeTo(store);
        return Arrays.copyOf(store.getBuffer(), store.getSize());
    }

    static String run(String text, String tail) throws Exception {
        Path root = Files.createTempDirectory("long-string-test");
        try {
            Path jar = root.resolve("probe.jar");
            try (var zip = new ZipOutputStream(Files.newOutputStream(jar))) {
                zip.putNextEntry(new ZipEntry("classes.dex"));
                zip.write(probeDex(text));
            }
            try (var loader = new DexClassLoader(jar.toString(), root.toString(), "", LongStringTest.class.getClassLoader())) {
                Object probe = loader.loadClass("tvbox.LongStringProbe").getDeclaredConstructor().newInstance();
                return (String) probe.getClass().getMethod("run", String.class).invoke(probe, tail);
            }
        } finally {
            try (var files = Files.walk(root)) { for (Path p : files.sorted(Comparator.reverseOrder()).toList()) Files.deleteIfExists(p); }
        }
    }

    public static void main(String[] args) throws Exception {
        // 40000 ASCII characters: over dex2jar's 32767-character split, under the class file's 65535-byte limit.
        String ascii = "# spider\n".repeat(4445).substring(0, 40000);
        check(run(ascii, "|tail").equals(ascii + "|tail"), "40000-character constant or `this` changed in conversion");
        // 30000 CJK characters are 90000 bytes of modified UTF-8: too long for one class file constant.
        String wide = "影匣".repeat(15000);
        check(run(wide, "|tail").equals(wide + "|tail"), "90000-byte constant changed in conversion");
        System.out.println("LongStringTest passed: long string constants keep `this` and their text after conversion");
    }
}
