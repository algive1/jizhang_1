package com.algive.jizhang_app.autobookkeeping

import com.algive.jizhang_app.autobookkeeping.overlay.ReviewNote
import org.junit.Assert.*
import org.junit.Test

class ReviewNoteTest {
    @Test fun lateNoteEnrichesUntouchedDraft() {
        val note = ReviewNote("支付宝")
        assertTrue(note.enrich("午餐"))
        assertEquals("午餐", note.value)
        assertFalse(note.enrich(""))
    }

    @Test fun userEditClearAndRevertAllPreventOverwrite() {
        for (text in listOf("手填", "", "支付宝")) {
            val note = ReviewNote("支付宝")
            note.edit(text)
            assertFalse(note.enrich("午餐"))
            assertEquals(text, note.value)
        }
    }
}
