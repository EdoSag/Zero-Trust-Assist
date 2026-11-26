package dev.sagron.zerotrustassist;

import android.app.Service;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.Message;
import android.os.Messenger;
import android.os.Process;
import android.os.RemoteException;

import io.flutter.FlutterInjector;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

/**
 * Lets the other Zero-Trust apps ask the model on this phone for a summary,
 * a correction and the like.
 *
 * <p>Another app binds to this service and sends a request; the answer goes
 * back piece by piece. The model itself is run by the app's Dart code
 * (lib/service/), which this service starts without a screen and talks to
 * over a method channel.
 *
 * <p>Who may ask: only apps signed with the same key as this one, which is
 * every Zero-Trust app and nothing else. The check is made here for each
 * message, by the sender's signature, and not with a manifest permission:
 * that way it does not depend on which app was installed first.
 *
 * <p>It runs in a process of its own (android:process=":engine"), so the
 * model's memory is separate from the chat's and is surely given back when
 * the last app lets go: the process ends.
 *
 * <p>Plain Java, like the code in the other apps that calls it
 * (Zero-Trust-Core, packages/zt_assist). The message numbers and field
 * names below are the contract between the two; change them in both.
 */
public final class AssistService extends Service {
    /** Raised when a message changes shape. Sent with every status. */
    static final int PROTOCOL = 1;

    // From an app.
    static final int MSG_STATUS = 1;
    static final int MSG_ASK = 2;
    static final int MSG_CANCEL = 3;

    // To an app.
    static final int MSG_STATUS_REPLY = 101;
    static final int MSG_CHUNK = 102;
    static final int MSG_DONE = 103;
    static final int MSG_FAILED = 104;

    private static final String CHANNEL = "zt_assist/service";

    /** How long the Dart side may take to start before requests are refused. */
    private static final long START_TIMEOUT_MS = 30_000;

    /** Services alive in this process: 0 means it is safe to end it. */
    private static int live = 0;

    /** One request in flight: who asked, and under which id of theirs. */
    private static final class Asker {
        final Messenger replyTo;
        final String id;

        Asker(Messenger replyTo, String id) {
            this.replyTo = replyTo;
            this.id = id;
        }
    }

    private final Handler main = new Handler(Looper.getMainLooper());
    private final Map<String, Asker> askers = new HashMap<>();
    private final ArrayList<Runnable> waitingForDart = new ArrayList<>();
    private FlutterEngine engine;
    private MethodChannel channel;
    private boolean dartReady = false;
    private boolean dartFailed = false;

    private final Messenger incoming = new Messenger(new Handler(Looper.getMainLooper()) {
        @Override
        public void handleMessage(Message message) {
            onAppMessage(message);
        }
    });

    @Override
    public void onCreate() {
        super.onCreate();
        live++;
        engine = new FlutterEngine(this);
        channel = new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(this::onDartCall);
        engine.getDartExecutor().executeDartEntrypoint(new DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "assistServiceMain"));
        main.postDelayed(() -> {
            if (dartReady) return;
            dartFailed = true;
            runWaiting();
        }, START_TIMEOUT_MS);
    }

    @Override
    public IBinder onBind(Intent intent) {
        return incoming.getBinder();
    }

    @Override
    public void onDestroy() {
        live--;
        final FlutterEngine ending = engine;
        final MethodChannel last = channel;
        engine = null;
        channel = null;
        askers.clear();
        waitingForDart.clear();
        main.removeCallbacksAndMessages(null);
        final boolean[] finished = {false};
        final Runnable finish = () -> {
            if (finished[0]) return;
            finished[0] = true;
            if (ending != null) ending.destroy();
            // The model's memory goes with the process. Not when another
            // app has bound again in the meantime.
            if (live == 0) Process.killProcess(Process.myPid());
        };
        // Lets the Dart side stop the model and free it first.
        if (last != null && dartReady) {
            last.invokeMethod("shutdown", null, new MethodChannel.Result() {
                @Override
                public void success(Object result) {
                    finish.run();
                }

                @Override
                public void error(String code, String message, Object details) {
                    finish.run();
                }

                @Override
                public void notImplemented() {
                    finish.run();
                }
            });
            main.postDelayed(finish, 3_000);
        } else {
            finish.run();
        }
        super.onDestroy();
    }

    /** Whether the app with this user id is signed with this app's key. */
    private boolean trusted(int uid) {
        if (uid == Process.myUid()) return true;
        return getPackageManager().checkSignatures(Process.myUid(), uid)
                == PackageManager.SIGNATURE_MATCH;
    }

    private void onAppMessage(Message message) {
        // The message object is reused once this method returns, so what is
        // needed later is taken out of it now.
        final int what = message.what;
        final int uid = message.sendingUid;
        final Messenger replyTo = message.replyTo;
        final Bundle data = message.getData() == null ? new Bundle() : new Bundle(message.getData());
        if (replyTo == null) return;
        final String id = data.getString("id", "");
        if (!trusted(uid)) {
            fail(replyTo, id, "not_allowed", null);
            return;
        }
        whenDartReady(() -> {
            if (dartFailed || channel == null) {
                fail(replyTo, id, "failed", "ZT Assist did not start.");
                return;
            }
            // Two apps may pick the same id; the sender's user id keeps
            // them apart.
            final String key = uid + ":" + id;
            switch (what) {
                case MSG_STATUS:
                    status(replyTo, id);
                    break;
                case MSG_ASK:
                    ask(replyTo, id, key, data);
                    break;
                case MSG_CANCEL:
                    channel.invokeMethod("cancel", key);
                    break;
                default:
                    fail(replyTo, id, "unsupported", null);
            }
        });
    }

    private void whenDartReady(Runnable action) {
        if (dartReady || dartFailed) {
            action.run();
        } else {
            waitingForDart.add(action);
        }
    }

    private void runWaiting() {
        final ArrayList<Runnable> actions = new ArrayList<>(waitingForDart);
        waitingForDart.clear();
        for (Runnable action : actions) action.run();
    }

    private void status(Messenger replyTo, String id) {
        channel.invokeMethod("status", null, new MethodChannel.Result() {
            @Override
            public void success(Object result) {
                final Bundle reply = new Bundle();
                reply.putString("id", id);
                reply.putInt("protocol", PROTOCOL);
                boolean ready = false;
                boolean busy = false;
                if (result instanceof Map) {
                    final Map<?, ?> values = (Map<?, ?>) result;
                    ready = Boolean.TRUE.equals(values.get("ready"));
                    busy = Boolean.TRUE.equals(values.get("busy"));
                }
                reply.putBoolean("ready", ready);
                reply.putBoolean("busy", busy);
                send(replyTo, MSG_STATUS_REPLY, reply);
            }

            @Override
            public void error(String code, String message, Object details) {
                fail(replyTo, id, "failed", message);
            }

            @Override
            public void notImplemented() {
                fail(replyTo, id, "failed", null);
            }
        });
    }

    private void ask(Messenger replyTo, String id, String key, Bundle data) {
        askers.put(key, new Asker(replyTo, id));
        final Map<String, Object> request = new HashMap<>();
        request.put("id", key);
        request.put("task", data.getString("task"));
        request.put("text", data.getString("text"));
        request.put("instruction", data.getString("instruction"));
        request.put("language", data.getString("language"));
        if (data.containsKey("maxTokens")) request.put("maxTokens", data.getInt("maxTokens"));
        channel.invokeMethod("ask", request);
    }

    /** A message from the Dart side: it is up, or a piece of an answer. */
    private void onDartCall(MethodCall call, MethodChannel.Result result) {
        if ("ready".equals(call.method)) {
            dartReady = true;
            result.success(null);
            runWaiting();
            return;
        }
        final String key = call.argument("id");
        final Asker asker = key == null ? null : askers.get(key);
        result.success(null);
        if (asker == null) return; // The app is gone, or already answered.
        final Bundle reply = new Bundle();
        reply.putString("id", asker.id);
        switch (call.method) {
            case "chunk": {
                final String text = call.argument("text");
                reply.putString("text", text == null ? "" : text);
                if (!send(asker.replyTo, MSG_CHUNK, reply)) {
                    // Nobody is listening any more: stop writing.
                    askers.remove(key);
                    if (channel != null) channel.invokeMethod("cancel", key);
                }
                break;
            }
            case "done": {
                askers.remove(key);
                reply.putBoolean("stopped", Boolean.TRUE.equals(call.argument("stopped")));
                reply.putBoolean("truncated", Boolean.TRUE.equals(call.argument("truncated")));
                reply.putInt("tokens", intOf(call.argument("tokens")));
                reply.putInt("milliseconds", intOf(call.argument("milliseconds")));
                reply.putInt("firstMilliseconds", intOf(call.argument("firstMilliseconds")));
                send(asker.replyTo, MSG_DONE, reply);
                break;
            }
            case "failed": {
                askers.remove(key);
                final String code = call.argument("code");
                final String detail = call.argument("detail");
                reply.putString("code", code == null ? "failed" : code);
                if (detail != null) reply.putString("detail", detail);
                send(asker.replyTo, MSG_FAILED, reply);
                break;
            }
            default:
                break;
        }
    }

    private static int intOf(Object value) {
        return value instanceof Number ? ((Number) value).intValue() : 0;
    }

    private void fail(Messenger replyTo, String id, String code, String detail) {
        final Bundle reply = new Bundle();
        reply.putString("id", id);
        reply.putString("code", code);
        if (detail != null) reply.putString("detail", detail);
        send(replyTo, MSG_FAILED, reply);
    }

    /** False when the app that asked is no longer there. */
    private static boolean send(Messenger to, int what, Bundle data) {
        final Message message = Message.obtain(null, what);
        message.setData(data);
        try {
            to.send(message);
            return true;
        } catch (RemoteException gone) {
            return false;
        }
    }
}
