package com.example.flutter_application_1

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

/**
 * 无障碍服务，用于捕获全局按键事件，即使应用在后台
 */
class KeyboardAccessibilityService : AccessibilityService() {
    companion object {
        private const val TAG = "KeyboardAccessService"
        
        // 静态实例，方便从其他地方访问
        private var instance: KeyboardAccessibilityService? = null
        
        // 添加服务启用状态标志
        private var serviceEnabled = false
        
        fun getInstance(): KeyboardAccessibilityService? {
            return instance
        }
        
        fun isRunning(): Boolean {
            return instance != null
        }
        
        // 新增方法：获取服务启用状态
        fun isServiceEnabled(): Boolean {
            return serviceEnabled
        }
    }
    
    // 保存扫码枪输入的字符
    private val stringBuilder = StringBuilder()
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "无障碍服务已连接")
        
        try {
            // 保存实例
            instance = this
            // 设置服务启用状态
            serviceEnabled = true
            
            // 配置服务，只监听键盘事件
            val info = AccessibilityServiceInfo()
            info.eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            
            // 使用安全的方式设置标志
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // 安卓12及以上版本的处理
                info.flags = AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
            } else {
                // 安卓12以下版本的处理
                info.flags = AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
            }
            
            serviceInfo = info
            
            // 通知悬浮窗更新状态
            try {
                val intent = Intent(this, FloatingWindowService::class.java)
                intent.putExtra(FloatingWindowService.EXTRA_ACTION, FloatingWindowService.ACTION_UPDATE_UI)
                startService(intent)
            } catch (e: Exception) {
                Log.e(TAG, "无法更新悬浮窗: ${e.message}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "onServiceConnected异常: ${e.message}")
            e.printStackTrace()
        }
    }
    
    override fun onInterrupt() {
        Log.d(TAG, "无障碍服务被中断")
    }
    
    override fun onDestroy() {
        Log.d(TAG, "无障碍服务被销毁")
        
        try {
            // 通知悬浮窗更新状态
            val intent = Intent(this, FloatingWindowService::class.java)
            intent.putExtra(FloatingWindowService.EXTRA_ACTION, FloatingWindowService.ACTION_UPDATE_UI)
            startService(intent)
            
            // 清理静态引用，避免内存泄漏
            instance = null
            serviceEnabled = false
            
            // 尝试自动重启服务（系统可能会阻止这种行为）
            try {
                val serviceIntent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                serviceIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(serviceIntent)
            } catch (e: Exception) {
                Log.e(TAG, "尝试重启无障碍服务失败: ${e.message}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "onDestroy异常: ${e.message}")
            e.printStackTrace()
        }
        
        super.onDestroy()
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        // 不需要处理辅助功能事件
    }
    
    // 捕获全局按键事件
    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (!serviceEnabled) {
            // 服务已被标记为未启用，但仍在运行
            Log.d(TAG, "无障碍服务已被禁用，忽略按键事件")
            return false
        }
        
        if (event.action == KeyEvent.ACTION_DOWN) {
            val keyCode = event.keyCode
            Log.d(TAG, "无障碍服务捕获按键: $keyCode")
            
            // 处理回车键，表示扫码完成
            if (keyCode == KeyEvent.KEYCODE_ENTER) {
                val barcode = stringBuilder.toString()
                if (barcode.isNotEmpty()) {
                    val timestamp = System.currentTimeMillis()
                    Log.d(TAG, "无障碍服务扫码结果: $barcode, 时间戳: $timestamp")
                    
                    // 发送广播通知
                    sendBarcodeIntent("android.intent.action.DECODE_DATA", barcode)
                    sendBarcodeIntent("scanner.rcv.message", barcode)
                    sendBarcodeIntent("com.android.server.scannerservice.broadcast", barcode)
                    
                    // 将扫码结果发送到BarcodeScannerService
                    val scannerService = BarcodeScannerService.getInstance()
                    if (scannerService != null) {
                        Log.d(TAG, "发送扫码结果到BarcodeScannerService: $barcode")
                        scannerService.addBarcode(barcode)
                    } else {
                        Log.e(TAG, "BarcodeScannerService不可用，无法发送扫码结果")
                        // 尝试启动扫码服务
                        try {
                            val serviceIntent = Intent(this, BarcodeScannerService::class.java)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(serviceIntent)
                            } else {
                                startService(serviceIntent)
                            }
                            Log.d(TAG, "已尝试启动BarcodeScannerService")
                        } catch (e: Exception) {
                            Log.e(TAG, "启动BarcodeScannerService失败: ${e.message}")
                        }
                    }
                    
                    // 清空缓冲区，准备下一次扫码
                    stringBuilder.clear()
                }
                return true
            } 
            // 处理数字和字母
            else if (keyCode >= KeyEvent.KEYCODE_0 && keyCode <= KeyEvent.KEYCODE_9 || 
                    keyCode >= KeyEvent.KEYCODE_A && keyCode <= KeyEvent.KEYCODE_Z) {
                val character = getCharacterFromKeyCode(keyCode)
                stringBuilder.append(character)
                Log.d(TAG, "无障碍服务添加字符: $character")
                return true
            }
        }
        return super.onKeyEvent(event)
    }
    
    private fun getCharacterFromKeyCode(keyCode: Int): Char {
        return when {
            keyCode >= KeyEvent.KEYCODE_0 && keyCode <= KeyEvent.KEYCODE_9 -> 
                '0' + (keyCode - KeyEvent.KEYCODE_0)
            keyCode >= KeyEvent.KEYCODE_A && keyCode <= KeyEvent.KEYCODE_Z -> 
                'A' + (keyCode - KeyEvent.KEYCODE_A)
            else -> ' '
        }
    }
    
    private fun sendBarcodeIntent(action: String, barcode: String) {
        val intent = Intent(action)
        intent.putExtra("barcode", barcode)
        intent.putExtra("barcodeStr", barcode)
        intent.putExtra("data", barcode)
        
        // 添加额外的PDA特定标志
        intent.putExtra("length", barcode.length)
        intent.putExtra("time", System.currentTimeMillis())
        
        sendBroadcast(intent)
        Log.d(TAG, "无障碍服务发送PDA扫码广播: $action, 条码: $barcode")
    }
} 