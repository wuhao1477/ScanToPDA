package com.example.bluetooth2pda

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import java.util.Timer
import java.util.TimerTask
import androidx.core.app.NotificationCompat

/**
 * 悬浮窗服务，保持应用在前台运行，提高后台扫码稳定性
 */
class FloatingWindowService : Service() {
    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var params: WindowManager.LayoutParams? = null
    
    // 悬浮窗组件
    private var tvStatus: TextView? = null
    private var tvLastCode: TextView? = null
    private var btnClose: ImageView? = null
    private var btnCollapse: ImageView? = null
    private var btnExpand: ImageView? = null
    
    // 记录最后一次扫码结果
    private var lastScanCode: String = ""
    private var isExpanded = true
    
    // 定时更新UI
    private var timer: Timer? = null
    
    override fun onBind(intent: Intent): IBinder? {
        return null
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "悬浮窗服务创建")
        
        // 在Android O及以上版本需要将服务设为前台服务
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notification = createNotification()
            startForeground(NOTIFICATION_ID, notification)
        }
        
        // 初始化窗口管理器
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        
        // 创建布局参数
        createLayoutParams()
        
        // 初始化悬浮窗视图
        initializeFloatingView()
        
        // 添加悬浮窗到屏幕
        windowManager?.addView(floatingView, params)
        
        // 启动定时更新任务
        startUpdateTimer()
    }
    
    private fun createLayoutParams() {
        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )
        
        // 初始位置
        params?.gravity = Gravity.TOP or Gravity.START
        params?.x = 0
        params?.y = 100
    }
    
    private fun initializeFloatingView() {
        // 加载悬浮窗布局
        val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        floatingView = inflater.inflate(R.layout.floating_window_layout, null)
        
        // 初始化视图组件
        tvStatus = floatingView?.findViewById(R.id.tv_status)
        tvLastCode = floatingView?.findViewById(R.id.tv_last_code)
        btnClose = floatingView?.findViewById(R.id.btn_close)
        btnCollapse = floatingView?.findViewById(R.id.btn_collapse)
        btnExpand = floatingView?.findViewById(R.id.btn_expand)
        
        // 设置关闭按钮点击事件
        btnClose?.setOnClickListener {
            stopSelf()
        }
        
        // 设置收起按钮点击事件
        btnCollapse?.setOnClickListener {
            collapseView()
        }
        
        // 设置展开按钮点击事件
        btnExpand?.setOnClickListener {
            expandView()
        }
        
        // 设置启动服务按钮
        floatingView?.findViewById<Button>(R.id.btn_start_service)?.setOnClickListener {
            startBarcodeScannerService()
        }
        
        // 设置停止服务按钮
        floatingView?.findViewById<Button>(R.id.btn_stop_service)?.setOnClickListener {
            stopBarcodeScannerService()
        }
        
        // 设置拖动事件
        setupDragToMove()
        
        // 初始化状态
        updateUI()
    }
    
    private fun setupDragToMove() {
        // 初始触摸位置
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        
        floatingView?.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    // 记录初始位置
                    initialX = params?.x ?: 0
                    initialY = params?.y ?: 0
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    // 计算移动距离
                    params?.x = initialX + (event.rawX - initialTouchX).toInt()
                    params?.y = initialY + (event.rawY - initialTouchY).toInt()
                    
                    // 更新悬浮窗位置
                    windowManager?.updateViewLayout(floatingView, params)
                    true
                }
                else -> false
            }
        }
    }
    
    private fun collapseView() {
        if (!isExpanded) return
        
        // 切换到收起状态
        tvLastCode?.visibility = View.GONE
        btnCollapse?.visibility = View.GONE
        btnExpand?.visibility = View.VISIBLE
        
        isExpanded = false
        updateWindowSize()
    }
    
    private fun expandView() {
        if (isExpanded) return
        
        // 切换到展开状态
        tvLastCode?.visibility = View.VISIBLE
        btnCollapse?.visibility = View.VISIBLE
        btnExpand?.visibility = View.GONE
        
        isExpanded = true
        updateWindowSize()
    }
    
    private fun updateWindowSize() {
        // 根据当前状态调整窗口大小
        windowManager?.updateViewLayout(floatingView, params)
    }
    
    private fun startUpdateTimer() {
        timer = Timer()
        timer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                // 更新UI需要在主线程中执行
                val handler = android.os.Handler(mainLooper)
                handler.post {
                    updateUI()
                }
            }
        }, 0, 1000) // 每秒更新一次
    }
    
    private fun updateUI() {
        // 获取扫码服务实例
        val scannerService = BarcodeScannerService.getInstance()
        
        // 获取无障碍服务实例
        val accessibilityService = KeyboardAccessibilityService.getInstance()
        
        // 更新状态文本
        if (scannerService != null) {
            tvStatus?.text = "扫码服务: 运行中"
            tvStatus?.setTextColor(resources.getColor(android.R.color.holo_green_dark))
            
            // 获取最后一次扫码结果
            val barcodes = scannerService.getScannedBarcodes()
            if (barcodes.isNotEmpty()) {
                val lastCode = barcodes[0]
                if (lastCode != lastScanCode) {
                    lastScanCode = lastCode
                    tvLastCode?.text = "最近扫码: $lastCode"
                }
            }
        } else {
            tvStatus?.text = "扫码服务: 未运行"
            tvStatus?.setTextColor(resources.getColor(android.R.color.holo_red_dark))
        }
        
        // 更新无障碍服务状态
        val accessText = if (accessibilityService != null) {
            "无障碍: 已启用"
        } else {
            "无障碍: 未启用"
        }
        floatingView?.findViewById<TextView>(R.id.tv_accessibility_status)?.let { tv ->
            tv.text = accessText
            tv.setTextColor(
                resources.getColor(
                    if (accessibilityService != null) android.R.color.holo_green_dark 
                    else android.R.color.holo_red_light
                )
            )
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "悬浮窗服务启动命令")
        
        // 如果服务已经在运行，处理传递的操作
        if (intent != null) {
            when (intent.getStringExtra(EXTRA_ACTION)) {
                ACTION_START_SCANNER -> startBarcodeScannerService()
                ACTION_STOP_SCANNER -> stopBarcodeScannerService()
                ACTION_UPDATE_UI -> updateUI()
            }
        }
        
        return START_STICKY
    }
    
    private fun startBarcodeScannerService() {
        // 启动或重启扫码服务
        val serviceIntent = Intent(this, BarcodeScannerService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
        
        Toast.makeText(this, "扫码服务已启动", Toast.LENGTH_SHORT).show()
        updateUI()
    }
    
    private fun stopBarcodeScannerService() {
        // 停止扫码服务
        val serviceIntent = Intent(this, BarcodeScannerService::class.java)
        stopService(serviceIntent)
        
        Toast.makeText(this, "扫码服务已停止", Toast.LENGTH_SHORT).show()
        updateUI()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "悬浮窗服务销毁")
        
        // 取消定时任务
        timer?.cancel()
        timer = null
        
        // 移除悬浮窗
        if (floatingView != null && windowManager != null) {
            windowManager?.removeView(floatingView)
        }
    }
    
    // 创建通知
    private fun createNotification(): Notification {
        // 创建通知渠道
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "悬浮窗服务",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.description = "保持蓝牙扫码服务在后台运行"
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
        
        // 创建通知点击Intent
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE
        )
        
        // 构建通知
        val notificationBuilder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
        } else {
            NotificationCompat.Builder(this)
        }
        
        return notificationBuilder
            .setContentTitle("扫码悬浮窗")
            .setContentText("蓝牙扫码服务在后台运行")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
    
    companion object {
        private const val TAG = "FloatingWindowService"
        private const val NOTIFICATION_CHANNEL_ID = "floating_window_service_channel"
        private const val NOTIFICATION_ID = 2001
        
        const val EXTRA_ACTION = "extra_action"
        const val ACTION_START_SCANNER = "start_scanner"
        const val ACTION_STOP_SCANNER = "stop_scanner"
        const val ACTION_UPDATE_UI = "update_ui"
    }
} 