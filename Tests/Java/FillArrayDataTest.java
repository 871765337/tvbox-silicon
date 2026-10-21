import dalvik.system.DexClassLoader;
import java.nio.file.*;
import java.util.*;

/**
 * Plugins keep their encrypted strings in large constant arrays, which DEX fills with fill-array-data.
 * The converter must copy the decoded values into the array; copied the other way round, the array
 * stays all zeros and every string the plugin decrypts comes out as one repeated character.
 */
public final class FillArrayDataTest {
    static void check(boolean value, String message) { if (!value) throw new AssertionError(message); }
    public static void main(String[] args) throws Exception {
        Path root = Files.createTempDirectory("fill-array-test");
        try (var loader = new DexClassLoader("Tests/TVCoreTests/Fixtures/array-probe.jar", root.toString(), "", FillArrayDataTest.class.getClassLoader())) {
            int hash = (int) loader.loadClass("tvbox.ArrayProbe").getMethod("run").invoke(null);
            // ArrayProbe.run() on a plain JVM, from Tests/Java/ArrayProbe.java.
            check(hash == -803540076, "Large constant array lost its values after conversion: hash " + hash);
        } finally {
            try (var files = Files.walk(root)) { for (Path p : files.sorted(Comparator.reverseOrder()).toList()) Files.deleteIfExists(p); }
        }
        System.out.println("FillArrayDataTest passed: large constant arrays keep their values after conversion");
    }
}
