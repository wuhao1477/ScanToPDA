package com.example.bluetooth2pda

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * 心跳广播接收器，用于保持后台服务运行
 */
class HeartbeatReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "HeartbeatReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "接收到心跳广播，确保服务运行")
        
        // 检查服务是否在运行，如果没有则启动
        if (BarcodeScannerService.getInstance() == null) {
            Log.d(TAG, "服务未运行，尝试重新启动")
            
            // 重新启动服务
            val serviceIntent = Intent(context, BarcodeScannerService::class.java)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } else {
            // 服务正在运行，再次设置心跳以保持活跃
            BarcodeScannerService.getInstance()?.startHeartbeatAlarm()
        }
    }
} 