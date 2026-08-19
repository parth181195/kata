package dev.parth.fuji_ptp

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/** Registers the dumb USB-host bridge (MethodChannel `fuji/usb`). PTP itself lives in Dart. */
class FujiPtpPlugin : FlutterPlugin {
    private var channel: MethodChannel? = null
    private var bridge: UsbBridge? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val b = UsbBridge(binding.applicationContext)
        bridge = b
        channel = MethodChannel(binding.binaryMessenger, UsbBridge.CHANNEL).also { it.setMethodCallHandler(b) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        bridge?.close()
        bridge = null
    }
}
