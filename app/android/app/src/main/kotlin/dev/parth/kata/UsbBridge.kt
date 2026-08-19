package dev.parth.kata

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Deliberately dumb USB-host bridge. Knows nothing about PTP.
 *
 * Methods (all async, results posted on main thread):
 *  listDevices()                          -> [{name, vid, pid, product, manufacturer, hasPermission, interfaces:[{id, cls, sub, proto, bulkIn, bulkOut}]}]
 *  requestPermission(name)                -> bool
 *  open(name, [interfaceId])              -> {interfaceId, epIn, epOut, maxPacketIn, maxPacketOut}
 *  bulkOut(data: ByteArray, timeoutMs)    -> int (bytes written)
 *  bulkIn(maxLen, timeoutMs)              -> ByteArray (may be empty on timeout -> error)
 *  close()                                -> null
 */
class UsbBridge(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "fuji/usb"
        private const val ACTION_USB_PERMISSION = "dev.parth.kata.USB_PERMISSION"
    }

    private val usb: UsbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private val io = Executors.newSingleThreadExecutor()
    private val main = android.os.Handler(android.os.Looper.getMainLooper())

    private var device: UsbDevice? = null
    private var conn: UsbDeviceConnection? = null
    private var intf: UsbInterface? = null
    private var epIn: UsbEndpoint? = null
    private var epOut: UsbEndpoint? = null

    private var pendingPermission: MethodChannel.Result? = null
    private var permissionReceiver: BroadcastReceiver? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "listDevices" -> result.success(listDevices())
                "requestPermission" -> requestPermission(call.argument<String>("name")!!, result)
                "open" -> result.success(open(call.argument<String>("name")!!, call.argument<Int>("interfaceId")))
                "bulkOut" -> {
                    val data = call.argument<ByteArray>("data")!!
                    val timeout = call.argument<Int>("timeoutMs") ?: 5000
                    io.execute {
                        val r = runCatching { bulkOut(data, timeout) }
                        main.post { r.fold({ result.success(it) }, { result.error("USB", it.message, null) }) }
                    }
                }
                "bulkIn" -> {
                    val maxLen = call.argument<Int>("maxLen") ?: 16384
                    val timeout = call.argument<Int>("timeoutMs") ?: 5000
                    io.execute {
                        val r = runCatching { bulkIn(maxLen, timeout) }
                        main.post { r.fold({ result.success(it) }, { result.error("USB", it.message, null) }) }
                    }
                }
                "close" -> { close(); result.success(null) }
                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            result.error("USB", e.message ?: e.toString(), null)
        }
    }

    // ---------------------------------------------------------------- discovery

    private fun listDevices(): List<Map<String, Any?>> =
        usb.deviceList.values.map { d ->
            val ifaces = (0 until d.interfaceCount).map { i ->
                val itf = d.getInterface(i)
                var bIn: Int? = null; var bOut: Int? = null
                for (e in 0 until itf.endpointCount) {
                    val ep = itf.getEndpoint(e)
                    if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                        if (ep.direction == UsbConstants.USB_DIR_IN) bIn = ep.address else bOut = ep.address
                    }
                }
                mapOf(
                    "id" to itf.id, "cls" to itf.interfaceClass, "sub" to itf.interfaceSubclass,
                    "proto" to itf.interfaceProtocol, "bulkIn" to bIn, "bulkOut" to bOut,
                )
            }
            mapOf(
                "name" to d.deviceName,
                "vid" to d.vendorId, "pid" to d.productId,
                "product" to d.productName, "manufacturer" to d.manufacturerName,
                "hasPermission" to usb.hasPermission(d),
                "interfaces" to ifaces,
            )
        }

    private fun findDevice(name: String): UsbDevice =
        usb.deviceList[name] ?: throw IllegalArgumentException("No USB device named $name")

    private fun requestPermission(name: String, result: MethodChannel.Result) {
        val d = findDevice(name)
        if (usb.hasPermission(d)) { result.success(true); return }
        if (pendingPermission != null) { result.error("USB", "permission request already pending", null); return }
        pendingPermission = result

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                if (intent.action != ACTION_USB_PERMISSION) return
                val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                runCatching { context.unregisterReceiver(this) }
                permissionReceiver = null
                pendingPermission?.success(granted)
                pendingPermission = null
            }
        }
        permissionReceiver = receiver
        val filter = IntentFilter(ACTION_USB_PERMISSION)
        if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            context.registerReceiver(receiver, filter)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
        val pi = PendingIntent.getBroadcast(
            context, 0, Intent(ACTION_USB_PERMISSION).setPackage(context.packageName), flags,
        )
        usb.requestPermission(d, pi)
    }

    // ---------------------------------------------------------------- connection

    private fun open(name: String, interfaceId: Int?): Map<String, Any?> {
        close()
        val d = findDevice(name)
        if (!usb.hasPermission(d)) throw IllegalStateException("No permission for $name")
        val c = usb.openDevice(d) ?: throw IllegalStateException("openDevice() returned null")

        // Pick interface: explicit id, else first PTP/still-image class (6), else first with bulk in+out.
        var chosen: UsbInterface? = null
        val all = (0 until d.interfaceCount).map { d.getInterface(it) }
        if (interfaceId != null) chosen = all.firstOrNull { it.id == interfaceId }
        if (chosen == null) chosen = all.firstOrNull { it.interfaceClass == 6 && hasBulkPair(it) }
        if (chosen == null) chosen = all.firstOrNull { hasBulkPair(it) }
        if (chosen == null) { c.close(); throw IllegalStateException("No interface with bulk IN+OUT endpoints") }

        if (!c.claimInterface(chosen, /*force=*/true)) { c.close(); throw IllegalStateException("claimInterface failed (another app holds the camera?)") }

        var i: UsbEndpoint? = null; var o: UsbEndpoint? = null
        for (e in 0 until chosen.endpointCount) {
            val ep = chosen.getEndpoint(e)
            if (ep.type != UsbConstants.USB_ENDPOINT_XFER_BULK) continue
            if (ep.direction == UsbConstants.USB_DIR_IN) i = ep else o = ep
        }
        device = d; conn = c; intf = chosen; epIn = i; epOut = o
        return mapOf(
            "interfaceId" to chosen.id,
            "epIn" to i!!.address, "epOut" to o!!.address,
            "maxPacketIn" to i.maxPacketSize, "maxPacketOut" to o.maxPacketSize,
        )
    }

    private fun hasBulkPair(itf: UsbInterface): Boolean {
        var i = false; var o = false
        for (e in 0 until itf.endpointCount) {
            val ep = itf.getEndpoint(e)
            if (ep.type != UsbConstants.USB_ENDPOINT_XFER_BULK) continue
            if (ep.direction == UsbConstants.USB_DIR_IN) i = true else o = true
        }
        return i && o
    }

    private fun bulkOut(data: ByteArray, timeoutMs: Int): Int {
        val c = conn ?: throw IllegalStateException("not open")
        val ep = epOut ?: throw IllegalStateException("no OUT endpoint")
        var off = 0
        // bulkTransfer with offset needs API 18+; chunk to 16 KB to be safe on old stacks.
        while (off < data.size) {
            val len = minOf(16 * 1024, data.size - off)
            val n = c.bulkTransfer(ep, data, off, len, timeoutMs)
            if (n < 0) throw IllegalStateException("bulkOut failed at offset $off (rc=$n)")
            off += n
        }
        // PTP requires a zero-length packet when the transfer is an exact multiple of maxPacketSize.
        if (data.isNotEmpty() && data.size % ep.maxPacketSize == 0) {
            c.bulkTransfer(ep, ByteArray(0), 0, timeoutMs)
        }
        return off
    }

    private fun bulkIn(maxLen: Int, timeoutMs: Int): ByteArray {
        val c = conn ?: throw IllegalStateException("not open")
        val ep = epIn ?: throw IllegalStateException("no IN endpoint")
        val buf = ByteArray(maxLen)
        val n = c.bulkTransfer(ep, buf, maxLen, timeoutMs)
        if (n < 0) throw IllegalStateException("bulkIn failed/timeout (rc=$n)")
        return buf.copyOf(n)
    }

    fun close() {
        runCatching { intf?.let { conn?.releaseInterface(it) } }
        runCatching { conn?.close() }
        conn = null; intf = null; epIn = null; epOut = null; device = null
    }
}
