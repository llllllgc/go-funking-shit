package com.lalema.lalema

import java.util.Calendar
import java.util.TimeZone
import org.junit.Assert.*
import org.junit.Test

class ReminderScheduleTest {
    private fun at(zone: TimeZone, year: Int, month: Int, day: Int, hour: Int, minute: Int): Long =
        Calendar.getInstance(zone).apply { clear(); set(year, month - 1, day, hour, minute, 0) }.timeInMillis

    @Test fun nextUsesLocalDayNotTwentyFourHours() {
        val zone = TimeZone.getTimeZone("Pacific/Auckland")
        val now = at(zone, 2026, 9, 26, 20, 1)
        val next = ReminderSchedule.next(now, 20, 0, zone)
        assertEquals(at(zone, 2026, 9, 27, 20, 0), next)
        assertEquals(23 * 60 * 60 * 1000L - 60000, next - now)
    }

    @Test fun missingSpringHourDoesNotShiftFollowingDay() {
        val zone = TimeZone.getTimeZone("Pacific/Auckland")
        val now = at(zone, 2026, 9, 27, 0, 0)
        val first = ReminderSchedule.next(now, 2, 30, zone)
        assertEquals(at(zone, 2026, 9, 27, 3, 30), first)
        val following = ReminderSchedule.next(first, 2, 30, zone, "2026-09-27")
        assertEquals(at(zone, 2026, 9, 28, 2, 30), following)
    }

    @Test fun deliveredLocalDayCannotBeRepeatedAfterClockRollback() {
        val zone = TimeZone.getTimeZone("Pacific/Auckland")
        val now = at(zone, 2026, 4, 5, 1, 0)
        val next = ReminderSchedule.next(now, 2, 30, zone, "2026-04-05")
        assertEquals(at(zone, 2026, 4, 6, 2, 30), next)
    }

    @Test fun timeZoneChangesKeepChosenWallTime() {
        val tokyo = TimeZone.getTimeZone("Asia/Tokyo")
        val auckland = TimeZone.getTimeZone("Pacific/Auckland")
        val now = at(tokyo, 2026, 10, 9, 10, 0)
        assertEquals(at(tokyo, 2026, 10, 9, 20, 15), ReminderSchedule.next(now, 20, 15, tokyo))
        assertEquals(at(auckland, 2026, 10, 9, 20, 15), ReminderSchedule.next(now, 20, 15, auckland))
    }

    @Test fun midnightAndYearEndUseNextCalendarDate() {
        val zone = TimeZone.getTimeZone("Asia/Tokyo")
        assertEquals(at(zone, 2027, 1, 1, 0, 0), ReminderSchedule.next(at(zone, 2026, 12, 31, 23, 59), 0, 0, zone))
        assertEquals(at(zone, 2027, 1, 2, 0, 0), ReminderSchedule.next(at(zone, 2027, 1, 1, 0, 0), 0, 0, zone))
    }

    @Test(expected = IllegalArgumentException::class)
    fun invalidTimeIsRejected() { ReminderSchedule.next(0, 24, 0, TimeZone.getTimeZone("UTC")) }
}
