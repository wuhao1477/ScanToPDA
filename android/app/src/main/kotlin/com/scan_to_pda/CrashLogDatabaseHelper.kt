package com.scan_to_pda

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

/**
 * 崩溃日志数据库助手类
 * 负责崩溃日志的本地存储和管理
 */
class CrashLogDatabaseHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {
    
    companion object {
        private const val TAG = "CrashLogDB"
        private const val DATABASE_NAME = "crash_logs.db"
        private const val DATABASE_VERSION = 1
        
        // 表名和字段定义
        private const val TABLE_CRASH_LOGS = "crash_logs"
        private const val COLUMN_ID = "id"
        private const val COLUMN_TIMESTAMP = "timestamp"
        private const val COLUMN_CRASH_TYPE = "crash_type"
        private const val COLUMN_ERROR_MESSAGE = "error_message"
        private const val COLUMN_STACK_TRACE = "stack_trace"
        private const val COLUMN_DEVICE_INFO = "device_info"
        private const val COLUMN_APP_VERSION = "app_version"
        private const val COLUMN_ANDROID_VERSION = "android_version"
        private const val COLUMN_DEVICE_MODEL = "device_model"
        private const val COLUMN_AVAILABLE_MEMORY = "available_memory"
        private const val COLUMN_TOTAL_MEMORY = "total_memory"
        private const val COLUMN_IS_READ = "is_read"
        
        // 单例实例
        @Volatile
        private var INSTANCE: CrashLogDatabaseHelper? = null
        
        fun getInstance(context: Context): CrashLogDatabaseHelper {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: CrashLogDatabaseHelper(context.applicationContext).also { INSTANCE = it }
            }
        }
    }
    
    override fun onCreate(db: SQLiteDatabase) {
        val createTableQuery = """
            CREATE TABLE $TABLE_CRASH_LOGS (
                $COLUMN_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $COLUMN_TIMESTAMP INTEGER NOT NULL,
                $COLUMN_CRASH_TYPE TEXT NOT NULL,
                $COLUMN_ERROR_MESSAGE TEXT NOT NULL,
                $COLUMN_STACK_TRACE TEXT NOT NULL,
                $COLUMN_DEVICE_INFO TEXT,
                $COLUMN_APP_VERSION TEXT,
                $COLUMN_ANDROID_VERSION TEXT,
                $COLUMN_DEVICE_MODEL TEXT,
                $COLUMN_AVAILABLE_MEMORY INTEGER DEFAULT 0,
                $COLUMN_TOTAL_MEMORY INTEGER DEFAULT 0,
                $COLUMN_IS_READ INTEGER DEFAULT 0
            )
        """.trimIndent()
        
        try {
            db.execSQL(createTableQuery)
            Log.d(TAG, "崩溃日志表创建成功")
        } catch (e: Exception) {
            Log.e(TAG, "创建崩溃日志表失败: ${e.message}")
        }
    }
    
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // 如果需要升级数据库结构，在这里处理
        Log.d(TAG, "数据库升级从版本 $oldVersion 到 $newVersion")
    }
    
    /**
     * 插入崩溃日志
     */
    fun insertCrashLog(crashLog: CrashLog): Long {
        return try {
            val db = writableDatabase
            val values = ContentValues().apply {
                put(COLUMN_TIMESTAMP, crashLog.timestamp)
                put(COLUMN_CRASH_TYPE, crashLog.crashType)
                put(COLUMN_ERROR_MESSAGE, crashLog.errorMessage)
                put(COLUMN_STACK_TRACE, crashLog.stackTrace)
                put(COLUMN_DEVICE_INFO, crashLog.deviceInfo)
                put(COLUMN_APP_VERSION, crashLog.appVersion)
                put(COLUMN_ANDROID_VERSION, crashLog.androidVersion)
                put(COLUMN_DEVICE_MODEL, crashLog.deviceModel)
                put(COLUMN_AVAILABLE_MEMORY, crashLog.availableMemory)
                put(COLUMN_TOTAL_MEMORY, crashLog.totalMemory)
                put(COLUMN_IS_READ, if (crashLog.isRead) 1 else 0)
            }
            
            val id = db.insert(TABLE_CRASH_LOGS, null, values)
            Log.d(TAG, "崩溃日志插入成功，ID: $id")
            id
        } catch (e: Exception) {
            Log.e(TAG, "插入崩溃日志失败: ${e.message}")
            -1
        }
    }
    
    /**
     * 获取所有崩溃日志
     */
    fun getAllCrashLogs(): List<CrashLog> {
        val crashLogs = mutableListOf<CrashLog>()
        val db = readableDatabase
        
        try {
            val cursor = db.query(
                TABLE_CRASH_LOGS,
                null,
                null,
                null,
                null,
                null,
                "$COLUMN_TIMESTAMP DESC"
            )
            
            cursor.use {
                while (it.moveToNext()) {
                    val crashLog = CrashLog(
                        id = it.getLong(it.getColumnIndexOrThrow(COLUMN_ID)),
                        timestamp = it.getLong(it.getColumnIndexOrThrow(COLUMN_TIMESTAMP)),
                        crashType = it.getString(it.getColumnIndexOrThrow(COLUMN_CRASH_TYPE)),
                        errorMessage = it.getString(it.getColumnIndexOrThrow(COLUMN_ERROR_MESSAGE)),
                        stackTrace = it.getString(it.getColumnIndexOrThrow(COLUMN_STACK_TRACE)),
                        deviceInfo = it.getString(it.getColumnIndexOrThrow(COLUMN_DEVICE_INFO)) ?: "",
                        appVersion = it.getString(it.getColumnIndexOrThrow(COLUMN_APP_VERSION)) ?: "",
                        androidVersion = it.getString(it.getColumnIndexOrThrow(COLUMN_ANDROID_VERSION)) ?: "",
                        deviceModel = it.getString(it.getColumnIndexOrThrow(COLUMN_DEVICE_MODEL)) ?: "",
                        availableMemory = it.getLong(it.getColumnIndexOrThrow(COLUMN_AVAILABLE_MEMORY)),
                        totalMemory = it.getLong(it.getColumnIndexOrThrow(COLUMN_TOTAL_MEMORY)),
                        isRead = it.getInt(it.getColumnIndexOrThrow(COLUMN_IS_READ)) == 1
                    )
                    crashLogs.add(crashLog)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "查询崩溃日志失败: ${e.message}")
        }
        
        return crashLogs
    }
    
    /**
     * 根据ID获取崩溃日志
     */
    fun getCrashLogById(id: Long): CrashLog? {
        val db = readableDatabase
        
        try {
            val cursor = db.query(
                TABLE_CRASH_LOGS,
                null,
                "$COLUMN_ID = ?",
                arrayOf(id.toString()),
                null,
                null,
                null
            )
            
            cursor.use {
                if (it.moveToFirst()) {
                    return CrashLog(
                        id = it.getLong(it.getColumnIndexOrThrow(COLUMN_ID)),
                        timestamp = it.getLong(it.getColumnIndexOrThrow(COLUMN_TIMESTAMP)),
                        crashType = it.getString(it.getColumnIndexOrThrow(COLUMN_CRASH_TYPE)),
                        errorMessage = it.getString(it.getColumnIndexOrThrow(COLUMN_ERROR_MESSAGE)),
                        stackTrace = it.getString(it.getColumnIndexOrThrow(COLUMN_STACK_TRACE)),
                        deviceInfo = it.getString(it.getColumnIndexOrThrow(COLUMN_DEVICE_INFO)) ?: "",
                        appVersion = it.getString(it.getColumnIndexOrThrow(COLUMN_APP_VERSION)) ?: "",
                        androidVersion = it.getString(it.getColumnIndexOrThrow(COLUMN_ANDROID_VERSION)) ?: "",
                        deviceModel = it.getString(it.getColumnIndexOrThrow(COLUMN_DEVICE_MODEL)) ?: "",
                        availableMemory = it.getLong(it.getColumnIndexOrThrow(COLUMN_AVAILABLE_MEMORY)),
                        totalMemory = it.getLong(it.getColumnIndexOrThrow(COLUMN_TOTAL_MEMORY)),
                        isRead = it.getInt(it.getColumnIndexOrThrow(COLUMN_IS_READ)) == 1
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "根据ID查询崩溃日志失败: ${e.message}")
        }
        
        return null
    }
    
    /**
     * 标记崩溃日志为已读
     */
    fun markCrashLogAsRead(id: Long): Boolean {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(COLUMN_IS_READ, 1)
        }
        
        return try {
            val rowsAffected = db.update(
                TABLE_CRASH_LOGS,
                values,
                "$COLUMN_ID = ?",
                arrayOf(id.toString())
            )
            Log.d(TAG, "标记崩溃日志为已读，ID: $id")
            rowsAffected > 0
        } catch (e: Exception) {
            Log.e(TAG, "标记崩溃日志为已读失败: ${e.message}")
            false
        }
    }
    
    /**
     * 删除崩溃日志
     */
    fun deleteCrashLog(id: Long): Boolean {
        val db = writableDatabase
        
        return try {
            val rowsAffected = db.delete(
                TABLE_CRASH_LOGS,
                "$COLUMN_ID = ?",
                arrayOf(id.toString())
            )
            Log.d(TAG, "删除崩溃日志，ID: $id")
            rowsAffected > 0
        } catch (e: Exception) {
            Log.e(TAG, "删除崩溃日志失败: ${e.message}")
            false
        }
    }
    
    /**
     * 清空所有崩溃日志
     */
    fun clearAllCrashLogs(): Boolean {
        val db = writableDatabase
        
        return try {
            val rowsAffected = db.delete(TABLE_CRASH_LOGS, null, null)
            Log.d(TAG, "清空所有崩溃日志，删除了 $rowsAffected 条记录")
            rowsAffected >= 0
        } catch (e: Exception) {
            Log.e(TAG, "清空崩溃日志失败: ${e.message}")
            false
        }
    }
    
    /**
     * 获取崩溃日志总数
     */
    fun getCrashLogCount(): Int {
        val db = readableDatabase
        
        return try {
            val cursor = db.rawQuery("SELECT COUNT(*) FROM $TABLE_CRASH_LOGS", null)
            cursor.use {
                if (it.moveToFirst()) {
                    it.getInt(0)
                } else {
                    0
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "获取崩溃日志总数失败: ${e.message}")
            0
        }
    }
    
    /**
     * 获取未读崩溃日志数量
     */
    fun getUnreadCrashLogCount(): Int {
        val db = readableDatabase
        
        return try {
            val cursor = db.rawQuery(
                "SELECT COUNT(*) FROM $TABLE_CRASH_LOGS WHERE $COLUMN_IS_READ = 0",
                null
            )
            cursor.use {
                if (it.moveToFirst()) {
                    it.getInt(0)
                } else {
                    0
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "获取未读崩溃日志数量失败: ${e.message}")
            0
        }
    }
    
    /**
     * 按类型查询崩溃日志
     */
    fun getCrashLogsByType(crashType: String): List<CrashLog> {
        val crashLogs = mutableListOf<CrashLog>()
        val db = readableDatabase
        
        try {
            val cursor = db.query(
                TABLE_CRASH_LOGS,
                null,
                "$COLUMN_CRASH_TYPE = ?",
                arrayOf(crashType),
                null,
                null,
                "$COLUMN_TIMESTAMP DESC"
            )
            
            cursor.use {
                while (it.moveToNext()) {
                    val crashLog = CrashLog(
                        id = it.getLong(it.getColumnIndexOrThrow(COLUMN_ID)),
                        timestamp = it.getLong(it.getColumnIndexOrThrow(COLUMN_TIMESTAMP)),
                        crashType = it.getString(it.getColumnIndexOrThrow(COLUMN_CRASH_TYPE)),
                        errorMessage = it.getString(it.getColumnIndexOrThrow(COLUMN_ERROR_MESSAGE)),
                        stackTrace = it.getString(it.getColumnIndexOrThrow(COLUMN_STACK_TRACE)),
                        deviceInfo = it.getString(it.getColumnIndexOrThrow(COLUMN_DEVICE_INFO)) ?: "",
                        appVersion = it.getString(it.getColumnIndexOrThrow(COLUMN_APP_VERSION)) ?: "",
                        androidVersion = it.getString(it.getColumnIndexOrThrow(COLUMN_ANDROID_VERSION)) ?: "",
                        deviceModel = it.getString(it.getColumnIndexOrThrow(COLUMN_DEVICE_MODEL)) ?: "",
                        availableMemory = it.getLong(it.getColumnIndexOrThrow(COLUMN_AVAILABLE_MEMORY)),
                        totalMemory = it.getLong(it.getColumnIndexOrThrow(COLUMN_TOTAL_MEMORY)),
                        isRead = it.getInt(it.getColumnIndexOrThrow(COLUMN_IS_READ)) == 1
                    )
                    crashLogs.add(crashLog)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "按类型查询崩溃日志失败: ${e.message}")
        }
        
        return crashLogs
    }
}
