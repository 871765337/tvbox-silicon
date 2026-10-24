package tvbox.runtime;

/** Controlled responses for the real JNI bridge, without loading third-party plugins. */
public final class AppleBootstrap {
    public static String request(String input) {
        return switch (input) {
            case "high-surrogate" -> "{\"result\":\"" + (char) 0xd800 + "\"}";
            case "low-surrogate" -> "{\"result\":\"" + (char) 0xdc00 + "\"}";
            case "exception" -> throw new IllegalStateException("Test plugin failure");
            case "out-of-memory" -> throw new OutOfMemoryError("Test plugin allocation failure");
            case "no-response" -> null;
            default -> input;
        };
    }
}
