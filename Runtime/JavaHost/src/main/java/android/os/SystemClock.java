package android.os;

/** Monotonic timing for Java plugins; never bind android.jar's native declarations. */
public final class SystemClock {
    public static long elapsedRealtime() { return System.nanoTime() / 1_000_000L; }
    public static long elapsedRealtimeNanos() { return System.nanoTime(); }
    public static long uptimeMillis() { return elapsedRealtime(); }
    public static long currentThreadTimeMillis() {
        long nanos = java.lang.management.ManagementFactory.getThreadMXBean().getCurrentThreadCpuTime();
        return Math.max(0, nanos / 1_000_000L);
    }
    public static void sleep(long milliseconds) {
        // QR helpers may run on a plugin executor while the playback thread polls here.
        // End that wait when the host needs to hand login back to the native app.
        tvbox.runtime.HttpDiagnostics.throwIfLoginRequired();
        long remaining = milliseconds;
        long started = elapsedRealtime();
        boolean interrupted = false;
        while (remaining > 0) {
            try { Thread.sleep(remaining); break; }
            catch (InterruptedException interruption) { interrupted = true; remaining = milliseconds - (elapsedRealtime() - started); }
        }
        if (interrupted) Thread.currentThread().interrupt();
    }
}
