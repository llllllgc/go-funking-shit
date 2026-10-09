package com.lalema.lalema

import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var cover: View? = null
    private var foreground = false
    private var coverEpoch = 0L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Remain protected until Dart has successfully read the stored setting.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        if (Build.VERSION.SDK_INT >= 33) setRecentsScreenshotEnabled(false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lalema/privacy_screen")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "protect" -> {
                        if (call.arguments == true) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "foregroundEpoch" -> result.success(if (foreground) coverEpoch else null)
                    "frameReady" -> {
                        val epoch = (call.arguments as? Number)?.toLong()
                        if (foreground && epoch == coverEpoch) {
                            cover?.let { (it.parent as? ViewGroup)?.removeView(it) }
                            cover = null
                            findViewById<View>(android.R.id.content)?.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_AUTO
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onPause() {
        foreground = false
        coverEpoch++
        if (cover == null) {
            findViewById<View>(android.R.id.content)?.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
            cover = View(this).apply {
                setBackgroundColor(0xFFF7F4EA.toInt())
                contentDescription = "内容已隐藏"
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            }
            (window.decorView as ViewGroup).addView(cover, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        }
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        foreground = true
        // Dart removes the cover only after painting a safe foreground frame.
    }
}
