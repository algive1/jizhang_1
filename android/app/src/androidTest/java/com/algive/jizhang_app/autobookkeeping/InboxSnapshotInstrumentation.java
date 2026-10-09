package com.algive.jizhang_app.autobookkeeping;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Context;
import android.os.Bundle;
import org.json.JSONObject;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;

/** Read-only backup; deliberately independent of the target APK's obfuscated classes. */
public final class InboxSnapshotInstrumentation extends Instrumentation {
    @Override public void onCreate(Bundle arguments) { super.onCreate(arguments); start(); }
    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            snapshot(getTargetContext());
            result.putString("stream", "PASS: inbox preferences snapshot saved\n");
            finish(Activity.RESULT_OK, result);
        } catch (Exception error) {
            result.putString("stream", "FAIL: " + error + "\n");
            finish(Activity.RESULT_CANCELED, result);
        }
    }
    public static void snapshot(Context context) throws Exception {
        JSONObject values = new JSONObject(context.getSharedPreferences("autobookkeeping.pending", Context.MODE_PRIVATE).getAll());
        File file = new File(context.getExternalFilesDir(null), "inbox-before-2008.json");
        try (FileOutputStream out = new FileOutputStream(file)) {
            out.write(values.toString().getBytes(StandardCharsets.UTF_8));
        }
        File logs = new File(context.getExternalFilesDir(null), "inbox-log-snapshot.txt");
        try (FileOutputStream out = new FileOutputStream(logs)) {
            out.write(context.getSharedPreferences("autobookkeeping_logs", Context.MODE_PRIVATE)
                .getString("lines", "").getBytes(StandardCharsets.UTF_8));
        }
    }
}
