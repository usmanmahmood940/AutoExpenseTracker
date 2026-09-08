package com.example.nova_spend

import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onDestroy() {
        try {
            super.onDestroy()
        } catch (e: RuntimeException) {
            // Firebase Auth / App Check EventChannel handlers can NPE in
            // onCancel when the engine detaches. Swallow so Android can
            // finish destroying the activity instead of crashing.
            Log.w(TAG, "Flutter plugin threw while destroying activity", e)
        }
    }

    companion object {
        private const val TAG = "MainActivity"
    }
}
