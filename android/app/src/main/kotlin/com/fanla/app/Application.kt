package com.fanla.app

import io.flutter.app.FlutterApplication
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.annotation.NonNull

class Application : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        
        // Android 8.0 (API 26) ve üzeri için bildirim kanalı oluştur
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "fanla_team_notifications"
            val channelName = "Takım Bildirimleri"
            val channelDescription = "Takımlarla ilgili önemli bildirimler"
            val importance = NotificationManager.IMPORTANCE_HIGH
            
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
                enableLights(true)
                enableVibration(true)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            
            println("Bildirim kanalı oluşturuldu: $channelId")
        }
    }
}
