package tvbox.runtime;

import java.io.IOException;
import okhttp3.Call;
import okhttp3.Response;

/**
 * Captures failures even when a spider catches an exception and returns an empty string.
 * State is per thread: concurrent searches each run on their own native worker thread and
 * must not report another source's failure.
 */
public final class HttpDiagnostics {
    private static final class State { String host; int status; String networkError; int newCzChallenges; volatile CloudLoginRequired loginRequired; volatile boolean active; }
    private static final ThreadLocal<State> state = ThreadLocal.withInitial(State::new);

    private static final InheritableThreadLocal<State> requestContext = new InheritableThreadLocal<>();
    // FTY/standalone runtimes own exactly one serialized source. Their pre-existing executor
    // threads cannot inherit a new request's context, so they can notify its active playback.
    // Shared multi-source runtimes never use this fallback.
    private static volatile boolean singleSource;
    private static volatile State activePlayback;

    public static void singleSourceRuntime(boolean value) { singleSource = value; }
    public static void reset() { endRequest(); state.remove(); }
    public static void beginRequest(boolean playback) {
        reset();
        State current = state.get(); current.active = true;
        requestContext.set(current);
        if (singleSource && playback) activePlayback = current;
    }
    public static void endRequest() {
        State current = state.get(); current.active = false;
        if (activePlayback == current) activePlayback = null;
        requestContext.remove();
    }
    private static State loginState() {
        State inherited = requestContext.get();
        if (inherited != null && inherited.active) return inherited;
        State playback = activePlayback;
        return playback != null && playback.active ? playback : state.get();
    }
    public static String host() { return state.get().host; }
    public static void recordStatus(String host, int status) { State current = state.get(); current.host = host; current.status = status; }

    public static Response execute(Call call) throws IOException { return execute(call, false); }
    public static Response executeNewCz(Call call) throws IOException { return execute(call, true); }

    private static Response execute(Call call, boolean newCz) throws IOException {
        String remote = call.request().url().host();
        String path = call.request().url().encodedPath();
        // These Android plugin flows wait for a QR dialog that cannot be shown by this host.
        // Return the provider to the app so its native QR login can take over. Swift's own
        // login uses URLSession and never passes through this plugin-only boundary.
        if (path.equals("/cas/ajax/getTokenForQrcodeLogin") || path.equals("/cas/ajax/getServiceTicketByQrcodeToken")) {
            String drive = remote.equals("uop.quark.cn") ? "quark" : remote.equals("api.open.uc.cn") ? "uc" : null;
            if (drive != null) {
                State request = loginState();
                request.loginRequired = new CloudLoginRequired(drive);
                call.cancel();
                throw request.loginRequired;
            }
        }
        throwIfLoginRequired();
        boolean local = remote.equals("127.0.0.1") || remote.equals("localhost") || remote.equals("::1");
        if (!local) PreparationProgress.waiting(remote);
        try {
            Response response = call.execute();
            if (local) return response;
            System.err.println("SOURCE_HTTP " + response.request().url().host() + response.request().url().encodedPath() + " " + response.code());
            State current = state.get();
            if (!response.isSuccessful()) {
                current.host = remote; current.status = response.code(); current.networkError = null;
            } else if (remote.equals(current.host)) { current.host = null; current.status = 0; current.networkError = null; }
            // NewCz blindly persists a missing Set-Cookie value and recurses on 403.
            // Allow its normal cookie handshake, but stop an invalid/unbounded retry.
            if (newCz && response.code() == 403 && (++current.newCzChallenges > 2 || response.header("set-cookie") == null)) {
                response.close();
                throw new SourceHTTPException(remote, 403);
            }
            return response;
        } catch (IOException failure) {
            if (!local && !(failure instanceof SourceHTTPException)) {
                State current = state.get();
                current.host = remote; current.status = 0; current.networkError = failure.getClass().getSimpleName();
            }
            throw failure;
        } finally {
            if (!local) PreparationProgress.waiting(null);
        }
    }

    public static void throwIfLoginRequired() {
        CloudLoginRequired login = loginState().loginRequired;
        if (login != null) throw login;
    }

    public static void throwIfFailed() throws IOException {
        throwIfLoginRequired();
        State current = state.get();
        if (current.host == null) return;
        if (current.status > 0) throw new SourceHTTPException(current.host, current.status);
        if (current.networkError != null) throw new IOException("Network request to " + current.host + " failed: " + current.networkError);
    }

    /** A host handoff, not a retryable network exception: bypass plugin catch(Exception) retry loops. */
    public static final class CloudLoginRequired extends Error {
        public final String drive;
        CloudLoginRequired(String drive) {
            super("Sign in to " + (drive.equals("quark") ? "Quark" : "UC") + " in the app to play this episode.");
            this.drive = drive;
        }
    }

    public static final class SourceHTTPException extends IOException {
        public final String host;
        public final int status;
        public SourceHTTPException(String host, int status) {
            super("The source " + host + " returned HTTP " + status);
            this.host = host; this.status = status;
        }
    }
}
