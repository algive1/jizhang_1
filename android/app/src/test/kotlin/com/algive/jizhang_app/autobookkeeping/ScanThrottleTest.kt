package com.algive.jizhang_app.autobookkeeping

import com.algive.jizhang_app.autobookkeeping.accessibility.ScanThrottle
import org.junit.Assert.*
import org.junit.Test

class ScanThrottleTest {
    @Test fun contentStormDoesNotRescheduleFirstScan() {
        val throttle = ScanThrottle()
        assertTrue(throttle.request())
        repeat(100) { assertFalse(throttle.request()) }
        throttle.consumed()
        assertTrue(throttle.request())
    }

    @Test fun retryAndEventShareOnePendingSlot() {
        val throttle = ScanThrottle()
        throttle.request()
        throttle.consumed()
        assertTrue(throttle.request()) // root retry
        assertFalse(throttle.request()) // content event during retry delay
        throttle.consumed() // interrupt/cancel
        assertFalse(throttle.pending)
        assertTrue(throttle.request())
    }
}
