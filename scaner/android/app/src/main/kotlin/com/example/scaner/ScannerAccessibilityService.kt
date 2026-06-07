package com.example.scaner

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.io.File

class ScannerAccessibilityService : AccessibilityService() {

    private data class ContentResult(val content: String, val type: String)

    companion object {
        const val OUTPUT_FILE = "scanner_content.json"

        private val SOCIAL_APPS = setOf(
            "com.instagram.android",
            "com.instagram.barcelona",       // Threads (correct package name)
            "com.facebook.katana",
            "com.facebook.lite",
            "com.zhiliaoapp.musically",      // TikTok (global)
            "com.ss.android.ugc.trill",      // TikTok (some regions)
            "jp.naver.line.android",
            "org.telegram.messenger",
            "org.telegram.messenger.web",
            "com.discord",
            "com.google.android.youtube",
            "com.twitter.android",
            "com.X.android",                 // X (alternate package)
            "com.reddit.frontpage",
            "com.whatsapp",
            "com.whatsapp.w4b",              // WhatsApp Business
            "com.pinterest",
            "com.linkedin.android",
        )

        private val URL_PATTERN = Regex("""https?://[a-zA-Z0-9\-._~:/?#\[\]@!${'$'}&'()*+,;=%]{8,}""")
        private const val MIN_TEXT_LENGTH = 40   // chars; filters out short UI labels
    }

    private var lastWrittenContent = ""
    private var lastWriteTime = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        serviceInfo = serviceInfo.apply {
            notificationTimeout = 500
            eventTypes = AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event ?: return
        val pkg = event.packageName?.toString() ?: return
        if (pkg !in SOCIAL_APPS) return

        val now = System.currentTimeMillis()
        if (now - lastWriteTime < 2000) return

        // Fast path: check event text for URL
        val eventText = event.text?.joinToString(" ") ?: ""
        var result: ContentResult? = URL_PATTERN.find(eventText)?.value?.let {
            ContentResult(it, "url")
        }

        // Slow path: traverse window node tree (URL-first, then longest text)
        if (result == null) {
            val root = rootInActiveWindow ?: return
            result = findContentInNode(root, depth = 0)
            root.recycle()
        }

        if (result != null && result.content != lastWrittenContent) {
            lastWrittenContent = result.content
            lastWriteTime = now
            writeDetected(result.content, result.type, pkg)
        }
    }

    // Returns URL immediately when found; otherwise the longest post-like text
    private fun findContentInNode(node: AccessibilityNodeInfo, depth: Int): ContentResult? {
        if (depth > 12) return null

        val text = node.text?.toString() ?: ""
        URL_PATTERN.find(text)?.let { return ContentResult(it.value, "url") }

        val desc = node.contentDescription?.toString() ?: ""
        URL_PATTERN.find(desc)?.let { return ContentResult(it.value, "url") }

        var longestText: ContentResult? =
            if (text.length >= MIN_TEXT_LENGTH) ContentResult(text, "text") else null

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val childResult = findContentInNode(child, depth + 1)
            child.recycle()
            if (childResult != null) {
                if (childResult.type == "url") return childResult
                if (longestText == null || childResult.content.length > longestText!!.content.length) {
                    longestText = childResult
                }
            }
        }

        return longestText
    }

    private fun writeDetected(content: String, type: String, pkg: String) {
        try {
            val safeContent = content
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
            val safePkg = pkg.replace("\"", "\\\"")
            val json = """{"content":"$safeContent","type":"$type","app":"$safePkg","timestamp":${System.currentTimeMillis()}}"""
            File(filesDir, OUTPUT_FILE).writeText(json)
        } catch (_: Exception) {}
    }

    override fun onInterrupt() {}
}
