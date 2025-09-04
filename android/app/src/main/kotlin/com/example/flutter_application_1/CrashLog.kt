package com.example.flutter_application_1

import java.util.Date

/**
 * 崩溃日志数据模型
 * 用于存储和管理应用崩溃信息
 */
data class CrashLog(
    val id: Long = 0,
    val timestamp: Long = System.currentTimeMillis(),
    val crashType: String = "Unknown",
    val errorMessage: String = "",
    val stackTrace: String = "",
    val deviceInfo: String = "",
    val appVersion: String = "",
    val androidVersion: String = "",
    val deviceModel: String = "",
    val availableMemory: Long = 0,
    val totalMemory: Long = 0,
    val isRead: Boolean = false
) {
    companion object {
        const val CRASH_TYPE_JAVA = "JavaException"
        const val CRASH_TYPE_ANR = "ANR"
        const val CRASH_TYPE_NATIVE = "NativeCrash"
        const val CRASH_TYPE_OOM = "OutOfMemory"
        const val CRASH_TYPE_FLUTTER = "FlutterError"
        
        // 线程安全的时间格式化器
        private val DATE_FORMATTER = ThreadLocal.withInitial { 
            java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault()) 
        }
        
        /**
         * 从异常创建崩溃日志
         */
        fun fromException(throwable: Throwable, deviceInfo: String = ""): CrashLog {
            val stackTrace = android.util.Log.getStackTraceString(throwable)
            val crashType = when {
                throwable is OutOfMemoryError -> CRASH_TYPE_OOM
                throwable.javaClass.name.contains("flutter", ignoreCase = true) -> CRASH_TYPE_FLUTTER
                else -> CRASH_TYPE_JAVA
            }
            
            return CrashLog(
                timestamp = System.currentTimeMillis(),
                crashType = crashType,
                errorMessage = throwable.message ?: throwable.javaClass.simpleName,
                stackTrace = stackTrace,
                deviceInfo = deviceInfo
            )
        }
    }
    
    /**
     * 获取格式化的时间字符串
     */
    fun getFormattedTime(): String {
        val date = Date(timestamp)
        return DATE_FORMATTER.get().format(date)
    }
    
    /**
     * 获取简短的错误描述
     */
    fun getShortDescription(): String {
        return when {
            errorMessage.length > 100 -> errorMessage.substring(0, 100) + "..."
            errorMessage.isNotEmpty() -> errorMessage
            else -> crashType
        }
    }
    
    /**
     * 导出为文本格式
     */
    fun toTextFormat(): String {
        return buildString {
            appendLine("=== 崩溃日志详情 ===")
            appendLine("时间: ${getFormattedTime()}")
            appendLine("类型: $crashType")
            appendLine("错误信息: $errorMessage")
            appendLine("设备型号: $deviceModel")
            appendLine("Android版本: $androidVersion")
            appendLine("应用版本: $appVersion")
            appendLine("可用内存: ${availableMemory / 1024 / 1024} MB")
            appendLine("总内存: ${totalMemory / 1024 / 1024} MB")
            appendLine()
            appendLine("=== 设备信息 ===")
            appendLine(deviceInfo)
            appendLine()
            appendLine("=== 堆栈跟踪 ===")
            appendLine(stackTrace)
            appendLine("=== 日志结束 ===")
        }
    }
    
    /**
     * 导出为JSON格式
     */
    fun toJsonFormat(): String {
        return """
        {
            "timestamp": $timestamp,
            "formattedTime": "${getFormattedTime()}",
            "crashType": "$crashType",
            "errorMessage": "${errorMessage.replace("\"", "\\\"")}",
            "stackTrace": "${stackTrace.replace("\"", "\\\"").replace("\n", "\\n")}",
            "deviceInfo": "${deviceInfo.replace("\"", "\\\"")}",
            "appVersion": "$appVersion",
            "androidVersion": "$androidVersion",
            "deviceModel": "$deviceModel",
            "availableMemory": $availableMemory,
            "totalMemory": $totalMemory,
            "isRead": $isRead
        }
        """.trimIndent()
    }
}
