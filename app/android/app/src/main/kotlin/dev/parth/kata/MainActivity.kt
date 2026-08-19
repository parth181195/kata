package dev.parth.kata

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var bridge: UsbBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val b = UsbBridge(applicationContext)
        bridge = b
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UsbBridge.CHANNEL).setMethodCallHandler(b)
    }

    override fun onDestroy() {
        bridge?.close()
        super.onDestroy()
    }
}
