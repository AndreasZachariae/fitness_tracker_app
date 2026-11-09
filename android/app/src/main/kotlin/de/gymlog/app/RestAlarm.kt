package de.gymlog.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * Vibrates at the end of a rest (1.0.1) or of a countdown of a timed set (1.3.0) while GymLog is in the background
 * or the screen is locked.
 * An exact system alarm wakes [RestAlarmReceiver]; no notification, no service. In the foreground the
 * Dart side vibrates itself and cancels the alarm.
 */
object RestAlarm {
    const val CHANNEL = "de.gymlog.app/rest_alarm"

    /** Same as PlatformFeedback.restOverPattern: wait, buzz, pause, buzz, pause, long buzz (ms), full strength (1.3.0). */
    val PATTERN = longArrayOf(0, 500, 250, 500, 250, 800)
    val AMPLITUDES = intArrayOf(0, 255, 0, 255, 0, 255)

    private fun intent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, RestAlarmReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    fun schedule(context: Context, atMillis: Long) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val pending = intent(context)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()) {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pending)
        } else {
            // Exact alarms revoked by the user: may come a little late, but still comes.
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pending)
        }
    }

    fun cancel(context: Context) {
        context.getSystemService(AlarmManager::class.java)?.cancel(intent(context))
    }
}

class RestAlarmReceiver : BroadcastReceiver() {
    @Suppress("DEPRECATION")
    override fun onReceive(context: Context, intent: Intent) {
        val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            context.getSystemService(Vibrator::class.java)
        }
        if (vibrator == null || !vibrator.hasVibrator()) return
        // Usage "alarm": Android lets background apps vibrate only for alarms, calls and notifications.
        val audio = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            vibrator.vibrate(RestAlarm.PATTERN, -1, audio)
            return
        }
        val effect = if (vibrator.hasAmplitudeControl()) {
            VibrationEffect.createWaveform(RestAlarm.PATTERN, RestAlarm.AMPLITUDES, -1)
        } else {
            VibrationEffect.createWaveform(RestAlarm.PATTERN, -1)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            vibrator.vibrate(effect, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM))
        } else {
            vibrator.vibrate(effect, audio)
        }
    }
}
