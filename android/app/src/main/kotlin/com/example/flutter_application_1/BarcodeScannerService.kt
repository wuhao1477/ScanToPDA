package com.example.scan_to_pda

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import android.view.KeyEvent
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.EventChannel
import org.json.JSONObject

class BarcodeScannerService : Service() {
    companion object {
        private const val TAG = "BarcodeScannerService"
        private const val NOTIFICATION_CHANNEL_ID = "barcode_scanner_service_channel"
        private const val NOTIFICATION_ID = 1001
        private const val WAKELOCK_TAG = "BarcodeScannerService:WakeLock"
        
        // 静态引用，方便从Flutter调用
        private var instance: BarcodeScannerService? = null
        
        // Flutter事件通道
        private var eventSink: EventChannel.EventSink? = null
        
        // PDA扫码枪常用广播Action
        private val PDA_SCAN_ACTIONS = arrayOf(
            "android.intent.action.DECODE_DATA",           // 通用扫码广播
            "scanner.rcv.message",                         // 通用扫码广播
            "com.android.server.scannerservice.broadcast"  // 常见PDA扫码广播
        )
        
        fun setEventSink(sink: EventChannel.EventSink?) {
            eventSink = sink
        }
        
        fun getInstance(): BarcodeScannerService? {
            return instance
        }
    }
    
    // 保存扫码枪输入的字符
    private val barcodeBuilder = StringBuilder()
    private var lastKeyTime: Long = 0
    private val KEY_TIMEOUT = 500L // 500毫秒超时
    
    // 保存已处理的按键，避免重复处理
    private var lastKeyCode: Int = -1
    private var lastKeyDownTime: Long = 0
    
    // 保存已扫描的条码
    private val scannedBarcodes = ArrayList<String>()
    
    // 使用HashMap保存条码及其时间戳
    private val barcodeTimestamps = HashMap<String, Long>()
    
    // 唤醒锁，防止CPU休眠
    private var wakeLock: PowerManager.WakeLock? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "服务创建")
        instance = this
        
        // 创建通知渠道
        createNotificationChannel()
        
        // 获取唤醒锁
        acquireWakeLock()
        
        // 启动为前台服务，增加服务优先级
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10及以上版本需要指定前台服务类型
            startForeground(NOTIFICATION_ID, createNotification(), android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, createNotification())
        }
        
        // 发送一个心跳广播，让系统知道服务在运行
        startHeartbeatAlarm()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "服务启动")
        
        // 如果服务被系统杀死并重新创建，确保重新获取唤醒锁
        if (wakeLock == null || !wakeLock!!.isHeld) {
            acquireWakeLock()
        }
        
        return START_STICKY // 服务被杀死后自动重启
    }
    
    override fun onDestroy() {
        Log.d(TAG, "服务销毁")
        
        // 释放唤醒锁
        releaseWakeLock()
        
        // 停止心跳
        stopHeartbeatAlarm()
        
        // 清理静态引用，避免内存泄漏
        instance = null
        eventSink = null
        
        super.onDestroy()
        
        // 尝试重启服务
        val restartServiceIntent = Intent(applicationContext, BarcodeScannerService::class.java)
        restartServiceIntent.setPackage(packageName)
        startService(restartServiceIntent)
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    // 获取唤醒锁
    private fun acquireWakeLock() {
        try {
            if (wakeLock == null) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK, 
                    WAKELOCK_TAG
                )
                wakeLock?.setReferenceCounted(false)
            }
            
            if (wakeLock != null && !wakeLock!!.isHeld) {
                wakeLock!!.acquire(10*60*1000L) // 10分钟超时
                Log.d(TAG, "获取唤醒锁成功")
            }
        } catch (e: Exception) {
            Log.e(TAG, "获取唤醒锁失败: ${e.message}")
        }
    }
    
    // 释放唤醒锁
    private fun releaseWakeLock() {
        try {
            if (wakeLock != null && wakeLock!!.isHeld) {
                wakeLock!!.release()
                Log.d(TAG, "释放唤醒锁")
            }
        } catch (e: Exception) {
            Log.e(TAG, "释放唤醒锁失败: ${e.message}")
        }
    }
    
    // 添加扫描结果
    fun addBarcode(barcode: String?) {
        if (!barcode.isNullOrEmpty()) {
            // 生成当前时间戳
            val timestamp = System.currentTimeMillis()
            
            // 添加到列表中
            scannedBarcodes.add(0, barcode) // 新条码放在最前面
            
            // 保存条码和时间戳
            barcodeTimestamps[barcode + "_" + timestamp] = timestamp
            
            // 创建JSON对象包含条码内容和时间戳
            val jsonData = JSONObject()
            jsonData.put("code", barcode)
            jsonData.put("timestamp", timestamp)
            
            // 通过事件通道发送给Flutter
            eventSink?.success(jsonData.toString())
            
            Log.d(TAG, "扫码结果: $barcode, 时间戳: $timestamp")
            
            // 模拟PDA扫码枪广播发送
            sendPdaScanBroadcast(barcode, timestamp)
        }
    }
    
    // 发送PDA扫码枪风格的广播
    private fun sendPdaScanBroadcast(barcode: String, timestamp: Long) {
        try {
            // 发送多种类型的扫码广播，覆盖大部分PDA
            for (action in PDA_SCAN_ACTIONS) {
                val intent = Intent(action)
                
                // 添加常见的扫码数据字段，覆盖大部分PDA设备格式
                intent.putExtra("barcode", barcode)
                intent.putExtra("scannerdata", barcode) 
                intent.putExtra("data", barcode)
                intent.putExtra("barcodeData", barcode)
                intent.putExtra("decode_data", barcode)
                intent.putExtra("scan_data", barcode)
                intent.putExtra("scanData", barcode)
                intent.putExtra("scanResult", barcode)
                intent.putExtra("time", timestamp)
                intent.putExtra("timestamp", timestamp)
                
                // 兼容Zebra设备
                val bundle = android.os.Bundle()
                bundle.putString("com.symbol.datawedge.data_string", barcode)
                bundle.putString("com.symbol.datawedge.label_type", "LABEL-TYPE-CODE128")
                intent.putExtra("com.symbol.datawedge.decode_data", bundle)
                
                // 发送广播
                sendBroadcast(intent)
                Log.d(TAG, "发送PDA扫码广播: $action, 条码: $barcode")
            }
        } catch (e: Exception) {
            Log.e(TAG, "发送PDA广播失败: ${e.message}")
        }
    }
    
    // 获取所有扫描结果
    fun getScannedBarcodes(): ArrayList<String> {
        return scannedBarcodes
    }
    
    // 清空扫描记录
    fun clearBarcodes() {
        scannedBarcodes.clear()
        barcodeTimestamps.clear()
    }
    
    // 处理键盘输入事件
    fun handleKeyEvent(event: KeyEvent) {
        // 只处理按键按下事件
        if (event.action == KeyEvent.ACTION_DOWN) {
            val keyCode = event.keyCode
            val eventTime = event.eventTime
            
            // 判断是否是同一个按键事件的重复处理（如按下的同一个键被处理了多次）
            if (keyCode == lastKeyCode && (eventTime - lastKeyDownTime) < 50) {
                // 如果是短时间内的同一个按键，则忽略
                return
            }
            
            // 更新上一个按键的信息
            lastKeyCode = keyCode
            lastKeyDownTime = eventTime
            
            // 获取当前时间
            val currentTime = System.currentTimeMillis()
            
            // 如果距离上次按键时间超过超时时间，则重置条码构建器
            if (currentTime - lastKeyTime > KEY_TIMEOUT) {
                barcodeBuilder.setLength(0)
            }
            
            // 更新上次按键时间
            lastKeyTime = currentTime
            
            // 处理特殊键
            if (event.keyCode == KeyEvent.KEYCODE_ENTER) {
                // 回车键表示扫码结束，处理结果
                val barcode = barcodeBuilder.toString().trim()
                if (barcode.isNotEmpty()) {
                    addBarcode(barcode)
                }
                barcodeBuilder.setLength(0) // 清空缓冲区
            } else {
                // 普通字符，添加到缓冲区
                val unicodeChar = event.unicodeChar.toChar()
                if (unicodeChar.code != 0) {
                    barcodeBuilder.append(unicodeChar)
                    // 记录下这个字符，用于调试
                    Log.d(TAG, "添加字符: $unicodeChar (${unicodeChar.code})")
                }
            }
        }
    }
    
    // 创建通知渠道
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "蓝牙扫码监听",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "监听蓝牙扫码枪输入"
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    // 创建通知
    private fun createNotification(): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("蓝牙扫码监听")
            .setContentText("正在后台监听蓝牙扫码枪输入")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .build()
    }
    
    // 停止心跳广播
    private fun stopHeartbeatAlarm() {
        try {
            val heartbeatIntent = Intent(this, HeartbeatReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                0,
                heartbeatIntent,
                PendingIntent.FLAG_IMMUTABLE
            )
            
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            alarmManager.cancel(pendingIntent)
            
            Log.d(TAG, "停止心跳广播")
        } catch (e: Exception) {
            Log.e(TAG, "停止心跳广播失败: ${e.message}")
        }
    }
    
    // 启动心跳广播，保持服务活跃
    fun startHeartbeatAlarm() {
        try {
            val heartbeatIntent = Intent(this, HeartbeatReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                0,
                heartbeatIntent,
                PendingIntent.FLAG_IMMUTABLE
            )
            
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            val triggerAtMillis = System.currentTimeMillis() + 60 * 1000 // 60秒后触发
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    android.app.AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    android.app.AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )
            }
            
            Log.d(TAG, "启动心跳广播")
        } catch (e: Exception) {
            Log.e(TAG, "启动心跳广播失败: ${e.message}")
        }
    }
} 