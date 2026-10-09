package com.lalema.lalema

import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

internal object ReminderSchedule {
    fun dayKey(time: Long, zone: TimeZone): String {
        val day = Calendar.getInstance(zone).apply { timeInMillis = time }
        return String.format(Locale.ROOT, "%04d-%02d-%02d", day.get(Calendar.YEAR), day.get(Calendar.MONTH) + 1, day.get(Calendar.DAY_OF_MONTH))
    }

    fun next(now: Long, hour: Int, minute: Int, zone: TimeZone, lastDay: String? = null): Long {
        require(hour in 0..23 && minute in 0..59)
        val current = Calendar.getInstance(zone).apply { timeInMillis = now }
        // Construct each local date independently. Adding 24 hours or adding a
        // day to a DST-normalized 02:30 would change the next day's wall time.
        for (offset in 0..2) {
            val candidate = Calendar.getInstance(zone).apply {
                clear()
                set(current.get(Calendar.YEAR), current.get(Calendar.MONTH), current.get(Calendar.DAY_OF_MONTH) + offset, hour, minute, 0)
            }.timeInMillis
            if (candidate > now && dayKey(candidate, zone) != lastDay) return candidate
        }
        error("Unable to determine next reminder")
    }
}
