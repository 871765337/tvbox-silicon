import tvbox.runtime.CloudDriveBridge;
import org.json.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.io.*;
import java.util.*;

public class CloudDriveBridgeTest {
    static void check(boolean value, String message) { if (!value) throw new AssertionError(message); }
    static HttpURLConnection connection(String address) throws Exception {
        var connection = (HttpURLConnection)new URL(address).openConnection();
        connection.setConnectTimeout(2000); connection.setReadTimeout(2000); return connection;
    }
    public static void main(String[] args) throws Exception {
        Path cache = Files.createTempDirectory("cloud-bridge-test");
        try (var bridge = new CloudDriveBridge(cache)) {
            var accounts = new JSONObject().put("quarkCookie", "__pus=test-only").put("ucCookie", "__pus=uc-test").put("token", "test-token");
            var ext = new JSONObject(bridge.extension("{\"Cloud-drive\":\"tvfan/Cloud-drive.txt\",\"cookie\":\"http://127.0.0.1:9978/file/TVBox/quark.txt\",\"siteUrl\":\"https://example.com\"}", accounts));
            check(ext.getString("siteUrl").equals("https://example.com"), "Source settings changed");
            String address = ext.getString("Cloud-drive");
            var config = connection(address);
            check(new JSONObject(new String(config.getInputStream().readAllBytes(), StandardCharsets.UTF_8)).getString("quarkCookie").equals("__pus=test-only"), "Cloud config was not delivered");
            var cookie = connection(ext.getString("cookie"));
            check(new String(cookie.getInputStream().readAllBytes(), StandardCharsets.UTF_8).equals("__pus=test-only"), "Legacy cookie file failed");
            check(connection(address.replaceAll("/[a-f0-9-]+/accounts$", "/accounts")).getResponseCode() == 403, "Missing capability accepted");
            var crossOrigin = connection(address); crossOrigin.setRequestProperty("Origin", "https://example.com");
            // JDK may filter Origin unless explicitly enabled; the process sets the property below.
            check(crossOrigin.getResponseCode() == 403, "Browser origin accepted");
            check(connection(address + "/../private").getResponseCode() == 404, "Unknown file accepted");
            bridge.setProxy(params -> {
                check("bytes=2-4".equals(params.get("range")), "Range header lost");
                check("a+b".equals(params.get("id")), "Query decoding failed");
                return new Object[]{206, "video/mp4", new ByteArrayInputStream("234".getBytes()), Map.of("Content-Range", "bytes 2-4/10", "Accept-Ranges", "bytes")};
            });
            String media = bridge.rewriteAddress("http://127.0.0.1:9978/proxy?do=quark&id=a%2Bb");
            check(!media.contains("/proxy?"), "Proxy was not routed");
            var stream = connection(media); stream.setRequestProperty("Range", "bytes=2-4");
            check(stream.getResponseCode() == 206, "Partial response status lost");
            check("bytes 2-4/10".equals(stream.getHeaderField("Content-Range")), "Content range lost");
            check(new String(stream.getInputStream().readAllBytes()).equals("234"), "Media payload changed");
            bridge.setProxy(params -> new Object[]{200, "video/mp4", new ByteArrayInputStream("01extra".getBytes()),
                Map.of("Content-Range", "bytes 0-1/10", "Content-Length", "10", "Accept-Ranges", "bytes")});
            var probe = connection(media); probe.setRequestProperty("Range", "bytes=0-1");
            check(probe.getResponseCode() == 206, "Zero-offset range must be a partial response");
            check(probe.getContentLengthLong() == 2, "Range response length lost");
            check(new String(probe.getInputStream().readAllBytes()).equals("01"), "Proxy read past the declared range");
            var head = connection(media); head.setRequestMethod("HEAD"); head.setRequestProperty("Range", "bytes=0-1");
            check(head.getResponseCode() == 206 && head.getContentLengthLong() == 2, "HEAD lost range metadata");
            check(head.getInputStream().read() == -1, "HEAD returned a body");
            check(Files.exists(cache.resolve("proxy-active")), "Playback lease not updated");
            check(bridge.rewriteAddress("https://example.com/proxy?do=quark").startsWith("https://example.com"), "Remote proxy rewritten");
            String array = bridge.playback("{\"url\":[\"HD\",\"http://127.0.0.1:9978/proxy?do=quark\"],\"header\":{\"Referer\":\"https://example.com\"}}");
            check(new JSONObject(array).getJSONArray("url").getString(1).contains("/media?"), "Quality array lost proxy routing");
            check(bridge.extension("{\"Cloud-drive\":\"original\"}", new JSONObject()).contains("original"), "Empty credentials replaced existing config");
        }
        cloudFamilyCredentials();
        ftyFamilyCredentials();
        proxyAddressMethodsUseHost();
        suspendedListenerRecovers();
        System.out.println("Cloud bridge checks passed (credentials, capability, range streaming, quality arrays).");
    }
    static void suspendedListenerRecovers() throws Exception {
        try (var bridge = new CloudDriveBridge(Files.createTempDirectory("cloud-resume-test"))) {
            bridge.setProxy(params -> new Object[]{200, "video/mp4", new ByteArrayInputStream("video".getBytes()), Map.of("Content-Length", "5")});
            String address = CloudDriveBridge.getUrl();
            check(connection(address).getResponseCode() == 200, "Initial listener did not start");
            var field = CloudDriveBridge.class.getDeclaredField("server"); field.setAccessible(true);
            var original = (com.sun.net.httpserver.HttpServer)field.get(bridge);
            check(bridge.recoverProxy("http://127.0.0.1:1/unrelated") == null, "Unrelated localhost URL was claimed");
            check(bridge.recoverProxy(address.replaceFirst("/[a-z0-9-]+/", "/wrong/")) == null, "Another capability was claimed");
            original.stop(0); // Models a socket invalidated while the process remains alive.
            var session = new tvbox.runtime.PluginSession(new com.github.catvod.crawler.Spider() {}, null, bridge);
            String recovered = session.recoverProxy(address);
            check(address.equals(recovered), "Recovery should preserve the port for cached player URLs");
            check(field.get(bridge) != original, "Dead listener was retained");
            check(new String(connection(recovered).getInputStream().readAllBytes()).equals("video"), "Recovered listener did not serve bytes");
            var restarted = field.get(bridge);
            bridge.ensureAvailable();
            check(field.get(bridge) == restarted, "Healthy listener was restarted");
            ((com.sun.net.httpserver.HttpServer)restarted).stop(0);
            bridge.playback(new JSONObject().put("url", address).toString());
            check(connection(address).getResponseCode() == 200, "Fresh playback did not recover its listener");
            bridge.close();
            try { bridge.ensureAvailable(); throw new AssertionError("Closed source was resurrected"); }
            catch (IOException expected) { }
        }
    }
    static void proxyAddressMethodsUseHost() throws Exception {
        Path folder = Files.createTempDirectory("cloud-methods-test");
        Path source = folder.resolve("original.jar"), rewritten = folder.resolve("rewritten.jar");
        var writer = new org.objectweb.asm.ClassWriter(0);
        writer.visit(52, 1, "com/github/catvod/spider/ProxyOrigin", null, "java/lang/Object", null);
        for (String name : List.of("getUrl", "getOwnProxyUrl")) {
            var method = writer.visitMethod(9, name, "()Ljava/lang/String;", null, null);
            method.visitCode(); method.visitLdcInsn("android-only"); method.visitInsn(176); method.visitMaxs(1, 0); method.visitEnd();
        }
        var method = writer.visitMethod(9, "getOwnProxyUrl", "(Ljava/lang/String;)Ljava/lang/String;", null, null);
        method.visitCode(); method.visitLdcInsn("android-only"); method.visitInsn(176); method.visitMaxs(1, 1); method.visitEnd();
        writer.visitEnd();
        try (var zip = new java.util.zip.ZipOutputStream(Files.newOutputStream(source))) {
            zip.putNextEntry(new java.util.zip.ZipEntry("com/github/catvod/spider/ProxyOrigin.class")); zip.write(writer.toByteArray()); zip.closeEntry();
        }
        tvbox.runtime.BytecodeCompatibility.rewrite(source, rewritten);
        try (var bridge = new CloudDriveBridge(folder); var loader = new java.net.URLClassLoader(new URL[]{rewritten.toUri().toURL()}, CloudDriveBridgeTest.class.getClassLoader())) {
            var proxy = loader.loadClass("com.github.catvod.spider.ProxyOrigin");
            check(((String)proxy.getMethod("getUrl").invoke(null)).endsWith("/media"), "Main proxy adapter failed");
            check(((String)proxy.getMethod("getOwnProxyUrl").invoke(null)).endsWith("/drive/"), "Drive root adapter failed");
            check(((String)proxy.getMethod("getOwnProxyUrl", String.class).invoke(null, "qk")).endsWith("/drive/proxy/qk/"), "Named drive adapter failed");
        }
    }

    static void ftyFamilyCredentials() throws Exception {
        class Loader extends ClassLoader {
            Class<?> define(String name, String parent, int shape) {
                var w = new org.objectweb.asm.ClassWriter(0);
                w.visit(52, 1, name, null, parent, null);
                if (shape == 1) w.visitField(1, "yq", "Lcom/github/catvod/spider/Cloud_quark;", null, null).visitEnd();
                if (shape == 2) {
                    for (String field : List.of("F5", "W", "ee")) w.visitField(1, field, "Ljava/lang/String;", null, null).visitEnd();
                    w.visitField(9, "instance", "L" + name + ";", null, null).visitEnd();
                    var init = w.visitMethod(1, "<init>", "()V", null, null);
                    init.visitCode(); init.visitVarInsn(25, 0); init.visitMethodInsn(183, "java/lang/Object", "<init>", "()V", false);
                    init.visitInsn(177); init.visitMaxs(1, 1); init.visitEnd();
                    var singleton = w.visitMethod(9, "Zm", "()L" + name + ";", null, null);
                    singleton.visitCode(); singleton.visitFieldInsn(178, name, "instance", "L" + name + ";");
                    singleton.visitInsn(176); singleton.visitMaxs(1, 0); singleton.visitEnd();
                    for (String method : List.of("Gd", "k")) {
                        var verify = w.visitMethod(1, method, method.equals("k") ? "(Ljava/lang/String;)Z" : "()Z", null, null);
                        verify.visitCode(); verify.visitInsn(3); verify.visitInsn(172); verify.visitMaxs(1, 2); verify.visitEnd();
                    }
                }
                w.visitEnd(); byte[] bytes = w.toByteArray();
                return defineClass(name.replace('/', '.'), bytes, 0, bytes.length);
            }
        }
        for (String helper : List.of("xU", "Z")) {
            var loader = new Loader();
            loader.define("com/github/catvod/spider/Cloud_quark", "java/lang/Object", 0);
            loader.define("com/github/catvod/spider/Pan", "java/lang/Object", 1);
            var wogg = loader.define("com/github/catvod/spider/WoGG", "com/github/catvod/spider/Pan", 0);
            var type = loader.define("com/github/catvod/spider/merge/" + helper, "java/lang/Object", 2);
            var account = type.getConstructor().newInstance(); type.getField("instance").set(null, account);
            try (var bridge = new CloudDriveBridge(Files.createTempDirectory("fty-cloud-test"))) {
                var accounts = new JSONObject().put("quarkCookie", "__pus=fixture");
                check(!bridge.restoreFtyQuarkAccount(accounts, wogg), "Incomplete legacy login was restored");
                accounts.put("quarkServiceTicket", "mobile-fixture");
                check(!bridge.restoreFtyQuarkAccount(accounts, Object.class), "Unrelated plugin received credentials");
                check(bridge.restoreFtyQuarkAccount(accounts, wogg), "FTY login was not restored");
                check(type.getField("F5").get(account).equals("__pus=fixture"), "FTY web cookie missing");
                check(type.getField("W").get(account).equals("mobile-fixture"), "FTY mobile ticket missing");
                check(type.getField("ee").get(account) == null, "External-source account was changed");
                check(Boolean.FALSE.equals(type.getMethod("Gd").invoke(account)), "Account validation was bypassed");
            }
        }
    }

    static void cloudFamilyCredentials() throws Exception {
        class Loader extends ClassLoader {
            Class<?> define(String name, String parent, boolean fields) {
                var writer = new org.objectweb.asm.ClassWriter(0);
                writer.visit(52, 1, name, null, parent, null);
                if (fields) {
                    writer.visitField(1, "a", "Lcom/github/catvod/spider/Quark;", null, null).visitEnd();
                    writer.visitField(1, "c", "Lcom/github/catvod/spider/UC;", null, null).visitEnd();
                }
                writer.visitEnd(); byte[] bytes = writer.toByteArray();
                return defineClass(name.replace('/', '.'), bytes, 0, bytes.length);
            }
        }
        var loader = new Loader();
        loader.define("com/github/catvod/spider/Quark", "java/lang/Object", false);
        loader.define("com/github/catvod/spider/UC", "java/lang/Object", false);
        loader.define("com/github/catvod/spider/Cloud", "java/lang/Object", true);
        var wogg = loader.define("com/github/catvod/spider/Wogg", "com/github/catvod/spider/Cloud", false);
        try (var bridge = new CloudDriveBridge(Files.createTempDirectory("cloud-family-test"))) {
            String original = "{\"site\":[\"https://example.com\"]}";
            var accounts = new JSONObject().put("quarkCookie", "__pus=quark-fixture").put("ucCookie", "__pus=uc-fixture").put("token", "ali-fixture");
            var ext = new JSONObject(bridge.cloudExtension(original, accounts, wogg));
            check(ext.getString("cookie").equals("__pus=quark-fixture"), "Wogg requires an inline cookie even without an existing ext key");
            check(ext.getString("uccookie").equals("__pus=uc-fixture"), "Wogg UC credential key is uccookie");
            check(ext.getString("token").equals("ali-fixture"), "Ali account mapping failed");
            check(ext.getJSONArray("site").getString(0).equals("https://example.com"), "Source origin changed");
            check(bridge.cloudExtension(original, accounts, Object.class).equals(original), "Unrelated plugin received accounts");
        }
    }

}
