package com.example.scan_to_pda

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * 广播接收器插件
 */
class BroadcastReceiverPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private var broadcastReceiver: GlobalBroadcastReceiver? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "com.example.broadcast_receiver")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "com.example.broadcast_receiver/events")
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startBroadcastReceiver" -> {
                registerBroadcastReceiver()
                result.success(true)
            }
            "stopBroadcastReceiver" -> {
                unregisterBroadcastReceiver()
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        unregisterBroadcastReceiver()
    }

    private fun registerBroadcastReceiver() {
        if (broadcastReceiver == null) {
            broadcastReceiver = GlobalBroadcastReceiver()
            // 注册全局广播接收器
            val intentFilter = IntentFilter()
            intentFilter.addAction(Intent.ACTION_BATTERY_CHANGED)
            intentFilter.addAction(Intent.ACTION_POWER_CONNECTED)
            intentFilter.addAction(Intent.ACTION_POWER_DISCONNECTED)
            intentFilter.addAction(Intent.ACTION_SCREEN_ON)
            intentFilter.addAction(Intent.ACTION_SCREEN_OFF)
            intentFilter.addAction(Intent.ACTION_TIME_TICK)
            
            // 添加常见的PDA扫码枪广播Action
            intentFilter.addAction("android.intent.action.DECODE_DATA")
            intentFilter.addAction("com.android.server.scannerservice.broadcast")
            intentFilter.addAction("android.intent.ACTION_DECODE_DATA")
            intentFilter.addAction("scanner.rcv.message")
            intentFilter.addAction("com.symbol.datawedge.api.RESULT_ACTION")
            intentFilter.addAction("com.honeywell.intent.action.SCAN_RESULT")
            intentFilter.addAction("unitech.scanservice.result")
            
            // 添加广播接收优先级，确保能及时接收到广播
            intentFilter.priority = 999
            
            // 注册动态广播接收器
            context.registerReceiver(broadcastReceiver, intentFilter)
        }
    }

    private fun unregisterBroadcastReceiver() {
        if (broadcastReceiver != null) {
            context.unregisterReceiver(broadcastReceiver)
            broadcastReceiver = null
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        // 如果有广播接收器，设置事件接收器
        broadcastReceiver?.setEventSink(eventSink)
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        broadcastReceiver?.setEventSink(null)
    }

    /**
     * 全局广播接收器
     */
    inner class GlobalBroadcastReceiver : BroadcastReceiver() {
        private var sink: EventChannel.EventSink? = null

        fun setEventSink(eventSink: EventChannel.EventSink?) {
            sink = eventSink
        }

        override fun onReceive(context: Context, intent: Intent) {
            // 获取广播的Action
            val action = intent.action ?: return
            
            // 提取广播中的Extra数据
            val extras = Bundle()
            intent.extras?.let { intentExtras ->
                extras.putAll(intentExtras)
            }

            // 创建返回给Flutter的数据Map
            val event = HashMap<String, Any>()
            event["action"] = action
            
            // 将Bundle转换为Map
            val extrasMap = HashMap<String, Any>()
            for (key in extras.keySet()) {
                val value = extras.get(key)
                if (value != null) {
                    extrasMap[key] = value.toString()
                }
            }
            
            event["extras"] = extrasMap
            
            // 通过EventSink发送广播数据
            sink?.success(event)
        }
    }
} 