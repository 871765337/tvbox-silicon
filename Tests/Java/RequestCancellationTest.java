import java.lang.reflect.Method;
import java.util.List;
import java.util.concurrent.CancellationException;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;
import org.json.JSONObject;
import tvbox.runtime.InProcessHost;

public final class RequestCancellationTest {
    private static void check(boolean condition, String message) { if (!condition) throw new AssertionError(message); }

    public static void main(String[] args) throws Exception {
        // A cancel can reach the host before its request; the request then never opens a plugin.
        check(new JSONObject(InProcessHost.request("{\"command\":\"cancel\",\"request\":\"early\"}")).getBoolean("result"), "Cancel was refused");
        JSONObject answer = new JSONObject(InProcessHost.request("{\"request\":\"early\",\"session\":\"s\",\"cache\":\"/nonexistent\",\"params\":{\"wd\":\"x\"}}"));
        check("cancelled".equals(answer.optString("errorCode")), "Cancelled request still ran: " + answer);

        Class<?> type = Class.forName("tvbox.runtime.OpeningGate");
        var constructor = type.getDeclaredConstructor(); constructor.setAccessible(true);
        Object gate = constructor.newInstance();
        Method enter = type.getDeclaredMethod("enter", boolean.class, AtomicBoolean.class); enter.setAccessible(true);
        Method leave = type.getDeclaredMethod("leave"); leave.setAccessible(true);

        // The viewer's request opens before a search that was already waiting.
        enter.invoke(gate, false, null);
        List<String> order = new CopyOnWriteArrayList<>();
        Thread search = opener(gate, enter, leave, true, null, order, new AtomicReference<>());
        Thread.sleep(100);
        Thread detail = opener(gate, enter, leave, false, null, order, new AtomicReference<>());
        Thread.sleep(100);
        leave.invoke(gate);
        search.join(5000); detail.join(5000);
        check(order.equals(List.of("detail", "search")), "Searches went first: " + order);

        // An abandoned opener stops waiting.
        enter.invoke(gate, false, null);
        AtomicBoolean cancelled = new AtomicBoolean();
        AtomicReference<Throwable> failure = new AtomicReference<>();
        Thread waiting = opener(gate, enter, leave, true, cancelled, new CopyOnWriteArrayList<>(), failure);
        Thread.sleep(100);
        cancelled.set(true);
        waiting.join(2000);
        check(!waiting.isAlive(), "Cancelled opener kept waiting");
        check(failure.get() instanceof CancellationException, "Cancelled opener did not fail with cancellation: " + failure.get());
        leave.invoke(gate);
        cancelWaitingSourceRequest(constructor.newInstance());
        System.out.println("RequestCancellationTest passed: early cancel, viewer before searches, abandoned openers stop");
    }

    /** A warm single-source runtime must release a cancelled waiter without running its plugin. */
    private static void cancelWaitingSourceRequest(Object requestGate) throws Exception {
        var type = Class.forName("tvbox.runtime.InProcessHost$Runtime");
        var constructor = type.getDeclaredConstructors()[0]; constructor.setAccessible(true);
        var loader = new java.net.URLClassLoader(new java.net.URL[0], RequestCancellationTest.class.getClassLoader());
        var plugin = new BlockingPlugin();
        Object runtime = constructor.newInstance(loader, plugin, false, java.nio.file.Path.of("/tmp"), requestGate);
        var field = InProcessHost.class.getDeclaredField("runtimes"); field.setAccessible(true);
        @SuppressWarnings("unchecked") var runtimes = (java.util.Map<String, Object>) field.get(null);
        synchronized (InProcessHost.class) { runtimes.put("session:cancellation-test", runtime); }
        AtomicReference<String> answer = new AtomicReference<>();
        Thread active = new Thread(() -> InProcessHost.request("{\"request\":\"active\",\"session\":\"cancellation-test\",\"params\":{\"play\":\"1\"}}"));
        Thread waiting = new Thread(() -> answer.set(InProcessHost.request("{\"request\":\"waiting\",\"session\":\"cancellation-test\",\"params\":{\"wd\":\"x\"}}")));
        try {
            active.start();
            check(plugin.started.await(2, java.util.concurrent.TimeUnit.SECONDS), "Plugin did not start");
            waiting.start();
            long deadline = System.nanoTime() + 2_000_000_000L;
            while (waiting.getState() != Thread.State.TIMED_WAITING && System.nanoTime() < deadline) Thread.sleep(5);
            check(waiting.getState() == Thread.State.TIMED_WAITING, "Request did not wait for the source");
            InProcessHost.request("{\"command\":\"cancel\",\"request\":\"waiting\"}");
            waiting.join(2000);
            check(!waiting.isAlive(), "Cancelled source waiter kept its worker slot");
            check("cancelled".equals(new JSONObject(answer.get()).optString("errorCode")), "Wrong cancellation response: " + answer.get());
            check(plugin.calls.get() == 1, "Abandoned request entered the plugin");
            var busyField = InProcessHost.class.getDeclaredField("busy"); busyField.setAccessible(true);
            synchronized (InProcessHost.class) {
                var busy = (java.util.Map<?, ?>) busyField.get(null);
                check(Integer.valueOf(1).equals(busy.get("session:cancellation-test")), "Cancelled request kept the runtime busy");
            }
        } finally {
            plugin.release.countDown(); active.join(2000); waiting.join(2000);
            InProcessHost.closeAll();
        }
    }

    public static final class BlockingPlugin {
        final java.util.concurrent.CountDownLatch started = new java.util.concurrent.CountDownLatch(1);
        final java.util.concurrent.CountDownLatch release = new java.util.concurrent.CountDownLatch(1);
        final java.util.concurrent.atomic.AtomicInteger calls = new java.util.concurrent.atomic.AtomicInteger();
        public String request(JSONObject input) throws InterruptedException {
            calls.incrementAndGet(); started.countDown(); release.await(); return "{}";
        }
        public void close() {}
    }

    private static Thread opener(Object gate, Method enter, Method leave, boolean search, AtomicBoolean cancelled,
                                 List<String> order, AtomicReference<Throwable> failure) {
        Thread thread = new Thread(() -> {
            try {
                enter.invoke(gate, search, cancelled);
                order.add(search ? "search" : "detail");
                leave.invoke(gate);
            } catch (java.lang.reflect.InvocationTargetException error) { failure.set(error.getCause()); }
            catch (Exception error) { failure.set(error); }
        });
        thread.start();
        return thread;
    }
}
