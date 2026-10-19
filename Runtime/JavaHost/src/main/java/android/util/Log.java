package android.util;
/** Plugins are compiled against Android's Log, so every public overload must exist (a missing one is a NoSuchMethodError). */
public final class Log {
    public static final int VERBOSE = 2, DEBUG = 3, INFO = 4, WARN = 5, ERROR = 6, ASSERT = 7;
    public static int d(String tag, String text) { System.err.println("["+tag+"] "+text); return 0; }
    public static int i(String tag, String text) { return d(tag,text); }
    public static int e(String tag, String text) { return d(tag,text); }
    public static int w(String tag, String text) { return d(tag,text); }
    public static int v(String tag, String text) { return d(tag,text); }
    public static int wtf(String tag, String text) { return d(tag,text); }
    public static int d(String tag, String text, Throwable e) { d(tag,text); if (e != null) e.printStackTrace(System.err); return 0; }
    public static int i(String tag, String text, Throwable e) { return d(tag,text,e); }
    public static int e(String tag, String text, Throwable e) { return d(tag,text,e); }
    public static int w(String tag, String text, Throwable e) { return d(tag,text,e); }
    public static int v(String tag, String text, Throwable e) { return d(tag,text,e); }
    public static int wtf(String tag, String text, Throwable e) { return d(tag,text,e); }
    public static int w(String tag, Throwable e) { return d(tag,"",e); }
    public static int wtf(String tag, Throwable e) { return d(tag,"",e); }
    public static int println(int priority, String tag, String text) { return d(tag,text); }
    public static boolean isLoggable(String tag, int level) { return level >= INFO; }
    public static String getStackTraceString(Throwable error) { if (error == null) return ""; java.io.StringWriter w = new java.io.StringWriter(); error.printStackTrace(new java.io.PrintWriter(w)); return w.toString(); }
}
