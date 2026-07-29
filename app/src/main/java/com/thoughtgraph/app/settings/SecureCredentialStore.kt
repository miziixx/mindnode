package com.thoughtgraph.app.settings

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Stores the API key using an Android Keystore backed master key
 * (EncryptedSharedPreferences). The key is:
 *
 *  - never written to plain SharedPreferences, the graph DB, files, logs,
 *    crash reports or analytics,
 *  - masked on screen by the UI layer,
 *  - excluded from app backups (see xml/backup_rules.xml), and
 *  - removed from secure storage immediately when cleared.
 *
 * If the encrypted store cannot be initialised (rare device Keystore issues) we
 * fall back to keeping the key in memory only for the current process, never
 * persisting it in the clear.
 */
class SecureCredentialStore(context: Context) {

    private val appContext = context.applicationContext
    private var inMemoryKey: String? = null

    private val prefs: SharedPreferences? by lazy {
        try {
            val masterKey = MasterKey.Builder(appContext)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()
            EncryptedSharedPreferences.create(
                appContext,
                SECURE_PREFS_NAME,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        } catch (t: Throwable) {
            null
        }
    }

    fun getApiKey(): String {
        prefs?.let { return it.getString(KEY_API, "") ?: "" }
        return inMemoryKey ?: ""
    }

    fun hasApiKey(): Boolean = getApiKey().isNotBlank()

    fun setApiKey(value: String) {
        val trimmed = value.trim()
        val p = prefs
        if (p != null) {
            p.edit().putString(KEY_API, trimmed).apply()
        } else {
            inMemoryKey = trimmed
        }
    }

    /** Immediately removes the key from secure storage and memory. */
    fun clear() {
        prefs?.edit()?.remove(KEY_API)?.apply()
        inMemoryKey = null
    }

    /** A masked preview for display, e.g. "sk-…4f2a". */
    fun maskedPreview(): String {
        val key = getApiKey()
        if (key.isBlank()) return ""
        if (key.length <= 8) return "•".repeat(key.length)
        return key.take(3) + "…" + key.takeLast(4)
    }

    companion object {
        const val SECURE_PREFS_NAME = "thoughtgraph_secure_prefs"
        private const val KEY_API = "api_key"
    }
}
