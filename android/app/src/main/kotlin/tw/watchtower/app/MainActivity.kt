package tw.watchtower.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createAlertChannel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { view -> view.remove() }
        }
    }

    private fun createAlertChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "major_alerts",
            getString(R.string.major_alerts_channel),
            NotificationManager.IMPORTANCE_HIGH,
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }
}
