package com.example.scan_to_pda

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.net.Uri
import android.provider.Settings
import android.widget.Toast

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val OVERLAY_PERMISSION_REQ_CODE = 1234
    }
    
    private val BARCODE_SCANNER_CHANNEL = "com.example.scan_to_pda/barcode_scanner"
    private val BARCODE_SCANNER_EVENT_CHANNEL = "com.example.scan_to_pda/barcode_scanner_events"
    private val CRASH_LOG_CHANNEL = "com.example.scan_to_pda/crash_log"
    
    private var eventSink: EventChannel.EventSink? = null
    private var crashLogDatabaseHelper: CrashLogDatabaseHelper? = null
    
    // 跟踪上一次处理的按键事件
    private var lastKeyDownCode: Int = -1
    private var lastKeyDownTime: Long = 0
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 初始化崩溃日志数据库助手
        crashLogDatabaseHelper = CrashLogDatabaseHelper.getInstance(this)
        
        // 设置方法通道，用于控制服务
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BARCODE_SCANNER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    startBarcodeScannerService()
                    result.success(true)
                }
                "stopService" -> {
                    stopBarcodeScannerService()
                    result.success(true)
                }
                "getScannedBarcodes" -> {
                    val barcodes = getScannedBarcodes()
                    result.success(barcodes)
                }
                "clearBarcodes" -> {
                    clearBarcodes()
                    result.success(true)
                }
                "simulateBarcodeScan" -> {
                    val code = call.argument<String>("code")
                    val timestamp = call.argument<Long>("timestamp") ?: System.currentTimeMillis()
                    
                    if (code != null) {
                        val service = BarcodeScannerService.getInstance()
                        service?.addBarcode(code)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "showFloatingWindow" -> {
                    startFloatingWindowService()
                    result.success(true)
                }
                "hideFloatingWindow" -> {
                    stopFloatingWindowService()
                    result.success(true)
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(true)
                }
                "requestAccessibilityPermission" -> {
                    requestAccessibilityPermission()
                    result.success(true)
                }
                "isAccessibilityServiceEnabled" -> {
                    val isEnabled = isAccessibilityServiceEnabled()
                    result.success(isEnabled)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // 设置崩溃日志方法通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CRASH_LOG_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCrashLogs" -> {
                    val crashLogs = crashLogDatabaseHelper?.getAllCrashLogs() ?: emptyList()
                    val crashLogsJson = crashLogs.map { crashLog ->
                        mapOf(
                            "id" to crashLog.id,
                            "timestamp" to crashLog.timestamp,
                            "formattedTime" to crashLog.getFormattedTime(),
                            "crashType" to crashLog.crashType,
                            "errorMessage" to crashLog.errorMessage,
                            "shortDescription" to crashLog.getShortDescription(),
                            "stackTrace" to crashLog.stackTrace,
                            "deviceInfo" to crashLog.deviceInfo,
                            "appVersion" to crashLog.appVersion,
                            "androidVersion" to crashLog.androidVersion,
                            "deviceModel" to crashLog.deviceModel,
                            "availableMemory" to crashLog.availableMemory,
                            "totalMemory" to crashLog.totalMemory,
                            "isRead" to crashLog.isRead
                        )
                    }
                    result.success(crashLogsJson)
                }
                "getCrashLogById" -> {
                    val id = call.argument<Long>("id")
                    if (id != null) {
                        val crashLog = crashLogDatabaseHelper?.getCrashLogById(id)
                        if (crashLog != null) {
                            val crashLogJson = mapOf(
                                "id" to crashLog.id,
                                "timestamp" to crashLog.timestamp,
                                "formattedTime" to crashLog.getFormattedTime(),
                                "crashType" to crashLog.crashType,
                                "errorMessage" to crashLog.errorMessage,
                                "shortDescription" to crashLog.getShortDescription(),
                                "stackTrace" to crashLog.stackTrace,
                                "deviceInfo" to crashLog.deviceInfo,
                                "appVersion" to crashLog.appVersion,
                                "androidVersion" to crashLog.androidVersion,
                                "deviceModel" to crashLog.deviceModel,
                                "availableMemory" to crashLog.availableMemory,
                                "totalMemory" to crashLog.totalMemory,
                                "isRead" to crashLog.isRead
                            )
                            result.success(crashLogJson)
                        } else {
                            result.success(null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Missing crash log id", null)
                    }
                }
                "markCrashLogAsRead" -> {
                    val id = call.argument<Long>("id")
                    if (id != null) {
                        val success = crashLogDatabaseHelper?.markCrashLogAsRead(id) ?: false
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Missing crash log id", null)
                    }
                }
                "deleteCrashLog" -> {
                    val id = call.argument<Long>("id")
                    if (id != null) {
                        val success = crashLogDatabaseHelper?.deleteCrashLog(id) ?: false
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Missing crash log id", null)
                    }
                }
                "clearAllCrashLogs" -> {
                    val success = crashLogDatabaseHelper?.clearAllCrashLogs() ?: false
                    result.success(success)
                }
                "getCrashLogCount" -> {
                    val count = crashLogDatabaseHelper?.getCrashLogCount() ?: 0
                    result.success(count)
                }
                "getUnreadCrashLogCount" -> {
                    val count = crashLogDatabaseHelper?.getUnreadCrashLogCount() ?: 0
                    result.success(count)
                }
                "exportCrashLog" -> {
                    val id = call.argument<Long>("id")
                    val format = call.argument<String>("format") ?: "txt"
                    if (id != null) {
                        val crashLog = crashLogDatabaseHelper?.getCrashLogById(id)
                        if (crashLog != null) {
                            val exportData = when (format.lowercase()) {
                                "json" -> crashLog.toJsonFormat()
                                else -> crashLog.toTextFormat()
                            }
                            result.success(exportData)
                        } else {
                            result.error("NOT_FOUND", "Crash log not found", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Missing crash log id", null)
                    }
                }
                "testCrash" -> {
                    // 用于测试的崩溃方法
                    try {
                        Thread {
                            throw RuntimeException("这是一个测试崩溃")
                        }.start()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("TEST_CRASH_FAILED", "Failed to create test crash", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // 设置事件通道，用于推送扫码结果
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, BARCODE_SCANNER_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    eventSink = events
                    BarcodeScannerService.setEventSink(events)
                }
                
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    BarcodeScannerService.setEventSink(null)
                }
            }
        )
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 初始化崩溃处理器
        CrashHandler.getInstance().init(this)
        
        // 启动ANR检测（可选）
        CrashHandler.getInstance().startAnrDetection()
        
        // 应用启动时不自动请求权限和启动服务
    }
    
    override fun onDestroy() {
        super.onDestroy()
        
        // 停止ANR检测，避免内存泄漏
        CrashHandler.getInstance().stopAnrDetection()
        
        // 清理事件接收器
        eventSink = null
        
        // 应用销毁时不要停止服务，保持后台运行
        // stopBarcodeScannerService()
    }
    
    // 启动扫码服务
    private fun startBarcodeScannerService() {
        val serviceIntent = Intent(this, BarcodeScannerService::class.java)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }
    
    // 停止扫码服务
    private fun stopBarcodeScannerService() {
        val serviceIntent = Intent(this, BarcodeScannerService::class.java)
        stopService(serviceIntent)
    }
    
    // 获取已扫描的条码
    private fun getScannedBarcodes(): List<String> {
        val service = BarcodeScannerService.getInstance()
        return service?.getScannedBarcodes() ?: ArrayList()
    }
    
    // 清空扫描记录
    private fun clearBarcodes() {
        val service = BarcodeScannerService.getInstance()
        service?.clearBarcodes()
    }
    
    // 重写按键处理方法，将按键事件传递给服务
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        // 只处理按键按下事件
        if (event.action == KeyEvent.ACTION_DOWN) {
            val keyCode = event.keyCode
            val eventTime = event.eventTime
            
            // 检查是否是短时间内的重复事件
            if (keyCode == lastKeyDownCode && (eventTime - lastKeyDownTime) < 50) {
                // 如果是短时间内的重复按键，继续正常流程，但不发送给服务
                Log.d(TAG, "忽略重复按键: $keyCode")
                return super.dispatchKeyEvent(event)
            }
            
            // 更新记录的按键信息
            lastKeyDownCode = keyCode
            lastKeyDownTime = eventTime
            
            // 获取服务实例
            val service = BarcodeScannerService.getInstance()
            
            // 如果服务存在，则将按键事件传递给服务处理
            if (service != null) {
                Log.d(TAG, "处理按键: $keyCode")
                service.handleKeyEvent(event)
            }
        }
        
        // 继续正常的按键处理流程
        return super.dispatchKeyEvent(event)
    }
    
    // 请求悬浮窗权限
    private fun requestOverlayPermission() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (!Settings.canDrawOverlays(this)) {
                    val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                    intent.data = Uri.parse("package:$packageName")
                    startActivityForResult(intent, OVERLAY_PERMISSION_REQ_CODE)
                } else {
                    // 已有权限，直接启动悬浮窗
                    startFloatingWindowService()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "请求悬浮窗权限失败: ${e.message}")
        }
    }
    
    // 启动悬浮窗服务
    private fun startFloatingWindowService() {
        try {
            val intent = Intent(this, FloatingWindowService::class.java)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            
            Log.d(TAG, "悬浮窗服务已启动")
        } catch (e: Exception) {
            Log.e(TAG, "启动悬浮窗服务失败: ${e.message}")
        }
    }
    
    // 停止悬浮窗服务
    private fun stopFloatingWindowService() {
        try {
            val intent = Intent(this, FloatingWindowService::class.java)
            stopService(intent)
            Log.d(TAG, "悬浮窗服务已停止")
        } catch (e: Exception) {
            Log.e(TAG, "停止悬浮窗服务失败: ${e.message}")
        }
    }
    
    // 处理权限请求结果
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == OVERLAY_PERMISSION_REQ_CODE) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (Settings.canDrawOverlays(this)) {
                    // 权限获取成功，启动悬浮窗
                    startFloatingWindowService()
                } else {
                    // 用户拒绝了权限
                    Toast.makeText(this, "需要悬浮窗权限才能保持后台扫码功能运行", Toast.LENGTH_LONG).show()
                }
            }
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
    
    // 请求忽略电池优化，使服务在后台持续运行
    private fun requestIgnoreBatteryOptimization() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val packageName = packageName
                val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                
                if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                    val intent = Intent()
                    intent.action = android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                    intent.data = android.net.Uri.parse("package:$packageName")
                    startActivity(intent)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "请求忽略电池优化失败: ${e.message}")
        }
    }
    
    // 检查无障碍服务是否已启用
    private fun isAccessibilityServiceEnabled(): Boolean {
        val accessibilityServiceName = "${packageName}/.KeyboardAccessibilityService"
        
        try {
            // 先检查KeyboardAccessibilityService实例是否存在（运行中）
            if (KeyboardAccessibilityService.isRunning()) {
                // 检查服务是否处于启用状态
                if (KeyboardAccessibilityService.isServiceEnabled()) {
                    Log.d(TAG, "无障碍服务实例正在运行并且处于启用状态")
                    return true
                } else {
                    Log.d(TAG, "无障碍服务实例存在但已被禁用")
                }
            }
            
            // 如果实例不存在或已被禁用，再检查系统设置
            val accessibilityEnabled = Settings.Secure.getInt(
                contentResolver,
                Settings.Secure.ACCESSIBILITY_ENABLED
            )
            
            if (accessibilityEnabled == 1) {
                val settingValue = Settings.Secure.getString(
                    contentResolver,
                    Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
                ) ?: return false
                
                val isEnabled = settingValue.split(':')
                    .map { it.trim() }
                    .any { it.equals(accessibilityServiceName, ignoreCase = true) }
                
                Log.d(TAG, "无障碍服务设置状态: $isEnabled, 设置值: $settingValue")
                return isEnabled
            }
        } catch (e: Exception) {
            Log.e(TAG, "检查无障碍服务状态失败: ${e.message}")
        }
        
        return false
    }
    
    // 请求无障碍服务权限
    private fun requestAccessibilityPermission() {
        try {
            Toast.makeText(
                this,
                "请开启【蓝牙扫码枪服务】无障碍服务，以便在后台捕获蓝牙扫码枪输入",
                Toast.LENGTH_LONG
            ).show()
            
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "请求无障碍服务权限失败: ${e.message}")
        }
    }
}
