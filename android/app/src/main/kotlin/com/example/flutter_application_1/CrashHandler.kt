package com.example.flutter_application_1

import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import java.io.File
import java.io.FileWriter
import java.io.PrintWriter
import java.io.StringWriter

/**
 * 全局崩溃处理器
 * 负责捕获并记录应用崩溃信息
 */
class CrashHandler private constructor() : Thread.UncaughtExceptionHandler {
    
    companion object {
        private const val TAG = "CrashHandler"
        
        @Volatile
        private var INSTANCE: CrashHandler? = null
        
        fun getInstance(): CrashHandler {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: CrashHandler().also { INSTANCE = it }
            }
        }
    }
    
    private var context: Context? = null
    private var defaultHandler: Thread.UncaughtExceptionHandler? = null
    private var databaseHelper: CrashLogDatabaseHelper? = null
    private var anrDetectorThread: Thread? = null
    private var isAnrDetectionRunning = false
    
    // 缓存设备信息，避免重复收集
    private var cachedDeviceInfo: String? = null
    private var cachedAppVersion: String? = null
    
    /**
     * 初始化崩溃处理器
     */
    fun init(context: Context) {
        this.context = context.applicationContext
        this.databaseHelper = CrashLogDatabaseHelper.getInstance(context)
        
        // 获取系统默认的异常处理器
        defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        
        // 设置该CrashHandler为程序的默认处理器
        Thread.setDefaultUncaughtExceptionHandler(this)
        
        Log.d(TAG, "崩溃处理器初始化完成")
    }
    
    override fun uncaughtException(thread: Thread, throwable: Throwable) {
        Log.e(TAG, "捕获到未处理的异常", throwable)
        
        try {
            // 收集设备和应用信息
            val deviceInfo = collectDeviceInfo()
            
            // 创建崩溃日志对象
            val crashLog = CrashLog.fromException(throwable, deviceInfo).copy(
                appVersion = getAppVersion(),
                androidVersion = Build.VERSION.RELEASE,
                deviceModel = "${Build.MANUFACTURER} ${Build.MODEL}",
                availableMemory = getAvailableMemory(),
                totalMemory = getTotalMemory()
            )
            
            // 保存到数据库
            databaseHelper?.insertCrashLog(crashLog)
            
            // 同时保存到文件作为备份
            saveCrashLogToFile(crashLog)
            
            Log.d(TAG, "崩溃日志保存完成")
            
        } catch (e: Exception) {
            Log.e(TAG, "保存崩溃日志时发生异常", e)
        }
        
        // 调用系统默认的异常处理器
        defaultHandler?.uncaughtException(thread, throwable)
    }
    
    /**
     * 手动记录异常（用于捕获的异常）
     */
    fun logException(throwable: Throwable, tag: String = "ManualLog") {
        try {
            Log.w(TAG, "手动记录异常: $tag", throwable)
            
            val deviceInfo = collectDeviceInfo()
            val crashLog = CrashLog.fromException(throwable, deviceInfo).copy(
                appVersion = getAppVersion(),
                androidVersion = Build.VERSION.RELEASE,
                deviceModel = "${Build.MANUFACTURER} ${Build.MODEL}",
                availableMemory = getAvailableMemory(),
                totalMemory = getTotalMemory(),
                crashType = "CaughtException"
            )
            
            databaseHelper?.insertCrashLog(crashLog)
            
        } catch (e: Exception) {
            Log.e(TAG, "手动记录异常时发生错误", e)
        }
    }
    
    /**
     * 收集设备信息（带缓存优化）
     */
    private fun collectDeviceInfo(): String {
        // 使用缓存避免重复收集静态信息
        if (cachedDeviceInfo != null) {
            return cachedDeviceInfo!!
        }
        
        cachedDeviceInfo = buildString {
            appendLine("=== 设备基本信息 ===")
            appendLine("设备制造商: ${Build.MANUFACTURER}")
            appendLine("设备型号: ${Build.MODEL}")
            appendLine("设备品牌: ${Build.BRAND}")
            appendLine("产品名称: ${Build.PRODUCT}")
            appendLine("硬件信息: ${Build.HARDWARE}")
            appendLine("设备指纹: ${Build.FINGERPRINT}")
            appendLine()
            
            appendLine("=== 系统信息 ===")
            appendLine("Android版本: ${Build.VERSION.RELEASE}")
            appendLine("API级别: ${Build.VERSION.SDK_INT}")
            appendLine("构建版本: ${Build.VERSION.INCREMENTAL}")
            appendLine("构建时间: ${Build.TIME}")
            appendLine()
            
            appendLine("=== 内存信息 ===")
            appendLine("可用内存: ${getAvailableMemory() / 1024 / 1024} MB")
            appendLine("总内存: ${getTotalMemory() / 1024 / 1024} MB")
            appendLine("最大堆内存: ${Runtime.getRuntime().maxMemory() / 1024 / 1024} MB")
            appendLine("已用堆内存: ${(Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory()) / 1024 / 1024} MB")
            appendLine()
            
            appendLine("=== 应用信息 ===")
            appendLine("应用版本: ${getAppVersion()}")
            appendLine("包名: ${context?.packageName ?: "Unknown"}")
            appendLine("进程名: ${getCurrentProcessName()}")
            appendLine()
            
            appendLine("=== 运行时信息 ===")
            appendLine("CPU架构: ${Build.SUPPORTED_ABIS.joinToString(", ")}")
            appendLine("可用处理器: ${Runtime.getRuntime().availableProcessors()}")
            appendLine("当前时间: ${java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())}")
        }
        
        return cachedDeviceInfo!!
    }
    
    /**
     * 获取应用版本（带缓存优化）
     */
    private fun getAppVersion(): String {
        if (cachedAppVersion != null) {
            return cachedAppVersion!!
        }
        
        cachedAppVersion = try {
            val packageInfo = context?.packageManager?.getPackageInfo(context?.packageName ?: "", 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                "${packageInfo?.versionName ?: "Unknown"} (${packageInfo?.longVersionCode ?: 0})"
            } else {
                @Suppress("DEPRECATION")
                "${packageInfo?.versionName ?: "Unknown"} (${packageInfo?.versionCode ?: 0})"
            }
        } catch (e: PackageManager.NameNotFoundException) {
            "Unknown"
        }
        
        return cachedAppVersion!!
    }
    
    /**
     * 获取可用内存
     */
    private fun getAvailableMemory(): Long {
        return try {
            val activityManager = context?.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            val memoryInfo = ActivityManager.MemoryInfo()
            activityManager?.getMemoryInfo(memoryInfo)
            memoryInfo.availMem
        } catch (e: Exception) {
            0L
        }
    }
    
    /**
     * 获取总内存
     */
    private fun getTotalMemory(): Long {
        return try {
            val activityManager = context?.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            val memoryInfo = ActivityManager.MemoryInfo()
            activityManager?.getMemoryInfo(memoryInfo)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
                memoryInfo.totalMem
            } else {
                // Android 4.1以下版本不支持totalMem，使用估算值
                Runtime.getRuntime().maxMemory() * 4
            }
        } catch (e: Exception) {
            0L
        }
    }
    
    /**
     * 获取当前进程名
     */
    private fun getCurrentProcessName(): String {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                android.app.Application.getProcessName()
            } else {
                val activityManager = context?.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                activityManager?.runningAppProcesses?.find { 
                    it.pid == android.os.Process.myPid() 
                }?.processName ?: "Unknown"
            }
        } catch (e: Exception) {
            "Unknown"
        }
    }
    
    /**
     * 将崩溃日志保存到文件
     */
    private fun saveCrashLogToFile(crashLog: CrashLog) {
        try {
            val crashDir = File(context?.filesDir, "crash_logs")
            if (!crashDir.exists()) {
                crashDir.mkdirs()
            }
            
            val fileName = "crash_${crashLog.timestamp}.txt"
            val crashFile = File(crashDir, fileName)
            
            FileWriter(crashFile).use { writer ->
                writer.write(crashLog.toTextFormat())
            }
            
            Log.d(TAG, "崩溃日志文件保存成功: ${crashFile.absolutePath}")
            
            // 清理旧的日志文件，只保留最近30个
            cleanupOldCrashFiles(crashDir)
            
        } catch (e: Exception) {
            Log.e(TAG, "保存崩溃日志文件失败", e)
        }
    }
    
    /**
     * 清理旧的崩溃日志文件
     */
    private fun cleanupOldCrashFiles(crashDir: File) {
        try {
            val files = crashDir.listFiles { file -> 
                file.isFile && file.name.startsWith("crash_") && file.name.endsWith(".txt")
            }
            
            if (files != null && files.size > 30) {
                // 按修改时间排序，删除最旧的文件
                files.sortBy { it.lastModified() }
                for (i in 0 until (files.size - 30)) {
                    if (files[i].delete()) {
                        Log.d(TAG, "删除旧的崩溃日志文件: ${files[i].name}")
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "清理旧崩溃日志文件失败", e)
        }
    }
    
    /**
     * 获取崩溃日志文件目录
     */
    fun getCrashLogDirectory(): File? {
        return try {
            val crashDir = File(context?.filesDir, "crash_logs")
            if (!crashDir.exists()) {
                crashDir.mkdirs()
            }
            crashDir
        } catch (e: Exception) {
            Log.e(TAG, "获取崩溃日志目录失败", e)
            null
        }
    }
    
    /**
     * 检测ANR（Application Not Responding）
     * 优化版本：避免内存泄漏和资源浪费
     */
    fun startAnrDetection() {
        if (isAnrDetectionRunning) {
            Log.d(TAG, "ANR检测已在运行中")
            return
        }
        
        isAnrDetectionRunning = true
        anrDetectorThread = Thread {
            Log.d(TAG, "ANR检测线程启动")
            while (isAnrDetectionRunning && !Thread.currentThread().isInterrupted) {
                try {
                    Thread.sleep(5000) // 每5秒检测一次
                    
                    if (!isAnrDetectionRunning) break
                    
                    // 简单的主线程阻塞检测
                    val startTime = System.currentTimeMillis()
                    val handler = android.os.Handler(android.os.Looper.getMainLooper())
                    
                    handler.post {
                        val endTime = System.currentTimeMillis()
                        val delay = endTime - startTime
                        
                        if (delay > 5000 && isAnrDetectionRunning) { // 如果主线程响应超过5秒
                            Log.w(TAG, "检测到可能的ANR，主线程响应延迟: ${delay}ms")
                            
                            try {
                                // 创建ANR日志
                                val anrException = RuntimeException("ANR detected: Main thread blocked for ${delay}ms")
                                val deviceInfo = collectDeviceInfo()
                                val crashLog = CrashLog.fromException(anrException, deviceInfo).copy(
                                    crashType = CrashLog.CRASH_TYPE_ANR,
                                    appVersion = getAppVersion(),
                                    androidVersion = Build.VERSION.RELEASE,
                                    deviceModel = "${Build.MANUFACTURER} ${Build.MODEL}",
                                    availableMemory = getAvailableMemory(),
                                    totalMemory = getTotalMemory()
                                )
                                
                                databaseHelper?.insertCrashLog(crashLog)
                            } catch (e: Exception) {
                                Log.e(TAG, "记录ANR日志时发生异常", e)
                            }
                        }
                    }
                } catch (e: InterruptedException) {
                    Log.d(TAG, "ANR检测线程被中断")
                    break
                } catch (e: Exception) {
                    Log.e(TAG, "ANR检测异常", e)
                }
            }
            Log.d(TAG, "ANR检测线程结束")
        }.apply {
            isDaemon = true
            name = "ANR-Detector"
            start()
        }
    }
    
    /**
     * 停止ANR检测
     */
    fun stopAnrDetection() {
        isAnrDetectionRunning = false
        anrDetectorThread?.interrupt()
        anrDetectorThread = null
        Log.d(TAG, "ANR检测已停止")
    }
}
