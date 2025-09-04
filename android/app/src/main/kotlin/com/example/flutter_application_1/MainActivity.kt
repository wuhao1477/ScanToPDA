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
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val OVERLAY_PERMISSION_REQ_CODE = 1234
        private const val BLUETOOTH_PERMISSION_REQ_CODE = 1235
        private const val LOCATION_PERMISSION_REQ_CODE = 1236
    }
    
    private val BARCODE_SCANNER_CHANNEL = "com.example.scan_to_pda/barcode_scanner"
    private val BARCODE_SCANNER_EVENT_CHANNEL = "com.example.scan_to_pda/barcode_scanner_events"
    
    private var barcodeEventChannel: EventChannel? = null
    private var barcodeEventSink: EventChannel.EventSink? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 条码扫描器MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BARCODE_SCANNER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    startBarcodeService()
                    result.success(true)
                }
                "stopService" -> {
                    stopBarcodeService()
                    result.success(true)
                }
                "startFloatingWindow" -> {
                    startFloatingWindow()
                    result.success(true)
                }
                "stopFloatingWindow" -> {
                    stopFloatingWindow()
                    result.success(true)
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(true)
                }
                "requestBluetoothPermissions" -> {
                    requestBluetoothPermissions()
                    result.success(true)
                }
                "requestLocationPermissions" -> {
                    requestLocationPermissions()
                    result.success(true)
                }
                "requestAllRequiredPermissions" -> {
                    requestAllRequiredPermissions()
                    result.success(true)
                }
                "getDeviceCompatibility" -> {
                    val info = getDeviceCompatibilityInfo()
                    result.success(info)
                }
                "hasBluetoothPermissions" -> {
                    val hasPermissions = hasBluetoothPermissions()
                    result.success(hasPermissions)
                }
                "isAccessibilityServiceEnabled" -> {
                    val isEnabled = isAccessibilityServiceEnabled()
                    result.success(isEnabled)
                }
                "getScannedBarcodes" -> {
                    val barcodes = getScannedBarcodes()
                    result.success(barcodes)
                }
                "requestAccessibilityPermission" -> {
                    requestAccessibilityPermission()
                    result.success(true)
                }
                "clearBarcodes" -> {
                    clearBarcodes()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        // 条码扫描器EventChannel
        barcodeEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, BARCODE_SCANNER_EVENT_CHANNEL)
        barcodeEventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                barcodeEventSink = events
                Log.d(TAG, "条码事件流开始监听")
            }
            
            override fun onCancel(arguments: Any?) {
                barcodeEventSink = null
                Log.d(TAG, "条码事件流取消监听")
            }
        })
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "MainActivity创建完成")
    }
    
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        // 将按键事件发送到Flutter
        val keyData = mapOf(
            "keyCode" to keyCode,
            "scanCode" to (event?.scanCode ?: 0),
            "action" to (event?.action ?: 0),
            "metaState" to (event?.metaState ?: 0),
            "repeatCount" to (event?.repeatCount ?: 0),
            "displayLabel" to (event?.displayLabel?.toString() ?: ""),
            "unicodeChar" to (event?.unicodeChar ?: 0),
            "characters" to (event?.characters ?: ""),
            "timestamp" to System.currentTimeMillis()
        )
        
        barcodeEventSink?.success(keyData)
        
        return super.onKeyDown(keyCode, event)
    }
    
    // 启动条码扫描服务
    private fun startBarcodeService() {
        try {
            val serviceIntent = Intent(this, BarcodeScannerService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
            Log.d(TAG, "条码扫描服务已启动")
        } catch (e: Exception) {
            Log.e(TAG, "启动条码扫描服务失败: ${e.message}")
        }
    }
    
    // 停止条码扫描服务
    private fun stopBarcodeService() {
        try {
            val serviceIntent = Intent(this, BarcodeScannerService::class.java)
            stopService(serviceIntent)
            Log.d(TAG, "条码扫描服务已停止")
        } catch (e: Exception) {
            Log.e(TAG, "停止条码扫描服务失败: ${e.message}")
        }
    }
    
    // 启动悬浮窗服务
    private fun startFloatingWindow() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                Log.w(TAG, "没有悬浮窗权限，无法启动悬浮窗")
                Toast.makeText(this, "请先授予悬浮窗权限", Toast.LENGTH_LONG).show()
                requestOverlayPermission()
                return
            }
            
            val serviceIntent = Intent(this, FloatingWindowService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
            Log.d(TAG, "悬浮窗服务已启动")
        } catch (e: Exception) {
            Log.e(TAG, "启动悬浮窗服务失败: ${e.message}")
        }
    }
    
    // 停止悬浮窗服务
    private fun stopFloatingWindow() {
        try {
            val serviceIntent = Intent(this, FloatingWindowService::class.java)
            stopService(serviceIntent)
            Log.d(TAG, "悬浮窗服务已停止")
        } catch (e: Exception) {
            Log.e(TAG, "停止悬浮窗服务失败: ${e.message}")
        }
    }
    
    // 请求悬浮窗权限
    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
            startActivityForResult(intent, OVERLAY_PERMISSION_REQ_CODE)
        }
    }
    
    // 请求蓝牙权限
    private fun requestBluetoothPermissions() {
        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                Log.d(TAG, "当前Android版本无需运行时权限请求")
                return
            }
            
            val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12及以上使用新蓝牙权限
                arrayOf(
                    android.Manifest.permission.BLUETOOTH_SCAN,
                    android.Manifest.permission.BLUETOOTH_CONNECT
                )
            } else {
                // Android 12以下使用传统蓝牙权限
                arrayOf(
                    android.Manifest.permission.BLUETOOTH,
                    android.Manifest.permission.BLUETOOTH_ADMIN
                )
            }
            
            val missingPermissions = permissions.filter { permission ->
                ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED
            }
            
            if (missingPermissions.isNotEmpty()) {
                Log.d(TAG, "请求蓝牙权限: ${missingPermissions.joinToString()}")
                ActivityCompat.requestPermissions(this, missingPermissions.toTypedArray(), BLUETOOTH_PERMISSION_REQ_CODE)
            } else {
                Log.d(TAG, "蓝牙权限已授予")
                
                // 检查是否需要位置权限进行蓝牙扫描（Android 6.0-11需要）
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                    val hasLocationPermission = ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                            ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    
                    if (!hasLocationPermission) {
                        Log.d(TAG, "蓝牙扫描需要位置权限，开始请求")
                        requestLocationPermissions()
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "请求蓝牙权限失败: ${e.message}")
        }
    }
    
    // 请求位置权限
    private fun requestLocationPermissions() {
        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                Log.d(TAG, "当前Android版本无需运行时位置权限请求")
                return
            }
            
            val permissions = arrayOf(
                android.Manifest.permission.ACCESS_FINE_LOCATION,
                android.Manifest.permission.ACCESS_COARSE_LOCATION
            )
            
            val missingPermissions = permissions.filter { permission ->
                ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED
            }
            
            if (missingPermissions.isNotEmpty()) {
                Log.d(TAG, "请求位置权限: ${missingPermissions.joinToString()}")
                ActivityCompat.requestPermissions(this, missingPermissions.toTypedArray(), LOCATION_PERMISSION_REQ_CODE)
            } else {
                Log.d(TAG, "位置权限已授予")
            }
        } catch (e: Exception) {
            Log.e(TAG, "请求位置权限失败: ${e.message}")
        }
    }
    
    // 请求所有必需权限
    private fun requestAllRequiredPermissions() {
        try {
            Log.d(TAG, "开始请求所有必需权限")
            requestBluetoothPermissions()
        } catch (e: Exception) {
            Log.e(TAG, "请求所有权限失败: ${e.message}")
        }
    }
    
    // 检查蓝牙权限
    private fun hasBluetoothPermissions(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12及以上使用新的蓝牙权限
                ContextCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
                        ContextCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
            } else {
                // Android 12以下使用传统蓝牙权限
                ContextCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH) == PackageManager.PERMISSION_GRANTED &&
                        ContextCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH_ADMIN) == PackageManager.PERMISSION_GRANTED
            }
        } catch (e: Exception) {
            Log.e(TAG, "检查蓝牙权限失败: ${e.message}")
            false
        }
    }
    
    // 获取设备兼容性信息
    private fun getDeviceCompatibilityInfo(): Map<String, Any> {
        return try {
            val hasBluetoothPermissions = hasBluetoothPermissions()
            val hasLocationPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                        ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
            } else {
                true
            }
            val hasOverlayPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Settings.canDrawOverlays(this)
            } else {
                true
            }
            
            mapOf<String, Any>(
                "apiLevel" to Build.VERSION.SDK_INT,
                "supportsRuntimePermissions" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M),
                "bluetoothPermissionType" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) "NEW" else "LEGACY",
                "needsLocationForBluetooth" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Build.VERSION.SDK_INT < Build.VERSION_CODES.S),
                "hasBluetoothPermissions" to hasBluetoothPermissions,
                "hasLocationPermission" to hasLocationPermission,
                "hasOverlayPermission" to hasOverlayPermission,
                "isSupported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN),
                "functionalLimitations" to when {
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP -> listOf("limited_bluetooth", "no_floating_window")
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.M -> listOf("no_runtime_permissions")
                    else -> emptyList<String>()
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "获取设备兼容性信息失败: ${e.message}")
            mapOf<String, Any>(
                "error" to "Failed to get compatibility info: ${e.message}"
            )
        }
    }
    
    // 获取扫描的条码
    private fun getScannedBarcodes(): List<Map<String, Any>> {
        // 这里应该从某个存储中获取扫描的条码
        // 暂时返回空列表，实际实现需要根据具体需求
        return emptyList()
    }
    
    // 请求无障碍权限
    private fun requestAccessibilityPermission() {
        try {
            val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
            Log.d(TAG, "打开无障碍设置页面")
        } catch (e: Exception) {
            Log.e(TAG, "打开无障碍设置失败: ${e.message}")
        }
    }
    
    // 清除条码
    private fun clearBarcodes() {
        // 这里应该清除存储的条码
        // 暂时为空实现，实际需要根据具体需求实现
        Log.d(TAG, "清除条码数据")
    }
    
    // 检查无障碍服务是否启用
    private fun isAccessibilityServiceEnabled(): Boolean {
        return try {
            val accessibilityManager = getSystemService(Context.ACCESSIBILITY_SERVICE) as android.view.accessibility.AccessibilityManager
            val enabledServices = android.provider.Settings.Secure.getString(
                contentResolver,
                android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: ""
            
            val serviceName = "$packageName/${KeyboardAccessibilityService::class.java.name}"
            val isEnabled = enabledServices.contains(serviceName)
            
            Log.d(TAG, "无障碍服务检查: $serviceName, 状态: $isEnabled")
            isEnabled
        } catch (e: Exception) {
            Log.e(TAG, "检查无障碍服务状态失败: ${e.message}")
            false
        }
    }
    
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        when (requestCode) {
            BLUETOOTH_PERMISSION_REQ_CODE -> {
                val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
                if (allGranted) {
                    Log.d(TAG, "蓝牙权限已授予")
                    Toast.makeText(this, "蓝牙权限已授予", Toast.LENGTH_SHORT).show()
                    
                    // 检查是否需要位置权限
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                        val hasLocationPermission = ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                                ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
                        
                        if (!hasLocationPermission) {
                            requestLocationPermissions()
                        }
                    }
                } else {
                    Log.w(TAG, "蓝牙权限被拒绝")
                    Toast.makeText(this, "蓝牙权限被拒绝，部分功能可能无法使用", Toast.LENGTH_LONG).show()
                }
            }
            LOCATION_PERMISSION_REQ_CODE -> {
                val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
                if (allGranted) {
                    Log.d(TAG, "位置权限已授予")
                    Toast.makeText(this, "位置权限已授予", Toast.LENGTH_SHORT).show()
                } else {
                    Log.w(TAG, "位置权限被拒绝")
                    Toast.makeText(this, "位置权限被拒绝，蓝牙扫描功能可能受限", Toast.LENGTH_LONG).show()
                }
            }
        }
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == OVERLAY_PERMISSION_REQ_CODE) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Settings.canDrawOverlays(this)) {
                Log.d(TAG, "悬浮窗权限已授予")
                Toast.makeText(this, "悬浮窗权限已授予", Toast.LENGTH_SHORT).show()
            } else {
                Log.w(TAG, "悬浮窗权限被拒绝")
                Toast.makeText(this, "悬浮窗权限被拒绝，悬浮窗功能无法使用", Toast.LENGTH_LONG).show()
            }
        }
    }
}