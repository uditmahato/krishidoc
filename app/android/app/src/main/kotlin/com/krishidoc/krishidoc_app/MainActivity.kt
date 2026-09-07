package com.krishidoc.krishidoc_app

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Diagnostic-only: keep the test visible without changing the phone's
        // global sleep setting or any behaviour of the farmer's normal app.
        if (packageName == "com.krishidoc.app.modelaudit" ||
            packageName == "com.krishidoc.app.v7audit" ||
            packageName == "com.krishidoc.app.v7test") {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
}
