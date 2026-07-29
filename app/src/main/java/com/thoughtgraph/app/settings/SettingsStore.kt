package com.thoughtgraph.app.settings

import android.content.Context
import android.content.SharedPreferences

/**
 * Non-sensitive app preferences. Never stores API keys — those live only in
 * [SecureCredentialStore].
 */
class SettingsStore(context: Context) {

    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences("thoughtgraph_prefs", Context.MODE_PRIVATE)

    // AI usage policy
    var aiEnabled: Boolean
        get() = prefs.getBoolean(KEY_AI_ENABLED, false) // default OFF
        set(v) = prefs.edit().putBoolean(KEY_AI_ENABLED, v).apply()

    /** Manual-only is fixed ON: automatic/background calls are never made. */
    val manualOnly: Boolean get() = true

    var selectedOnly: Boolean
        get() = prefs.getBoolean(KEY_SELECTED_ONLY, true)
        set(v) = prefs.edit().putBoolean(KEY_SELECTED_ONLY, v).apply()

    var provider: String
        get() = prefs.getString(KEY_PROVIDER, "anthropic") ?: "anthropic"
        set(v) = prefs.edit().putString(KEY_PROVIDER, v).apply()

    /** Model id is user-entered; never hard-coded. */
    var model: String
        get() = prefs.getString(KEY_MODEL, "") ?: ""
        set(v) = prefs.edit().putString(KEY_MODEL, v).apply()

    var customEndpoint: String
        get() = prefs.getString(KEY_ENDPOINT, "") ?: ""
        set(v) = prefs.edit().putString(KEY_ENDPOINT, v).apply()

    // Local storage
    var autoSave: Boolean
        get() = prefs.getBoolean(KEY_AUTO_SAVE, true)
        set(v) = prefs.edit().putBoolean(KEY_AUTO_SAVE, v).apply()

    /** When ON, raw request/response bodies are never persisted or logged. */
    var noHistory: Boolean
        get() = prefs.getBoolean(KEY_NO_HISTORY, true)
        set(v) = prefs.edit().putBoolean(KEY_NO_HISTORY, v).apply()

    // Screen
    var showMiniMap: Boolean
        get() = prefs.getBoolean(KEY_MINIMAP, true)
        set(v) = prefs.edit().putBoolean(KEY_MINIMAP, v).apply()

    var highContrast: Boolean
        get() = prefs.getBoolean(KEY_CONTRAST, false)
        set(v) = prefs.edit().putBoolean(KEY_CONTRAST, v).apply()

    // Session restore
    var lastGraphId: String?
        get() = prefs.getString(KEY_LAST_GRAPH, null)
        set(v) = prefs.edit().putString(KEY_LAST_GRAPH, v).apply()

    var seeded: Boolean
        get() = prefs.getBoolean(KEY_SEEDED, false)
        set(v) = prefs.edit().putBoolean(KEY_SEEDED, v).apply()

    companion object {
        private const val KEY_AI_ENABLED = "ai_enabled"
        private const val KEY_SELECTED_ONLY = "selected_only"
        private const val KEY_PROVIDER = "provider"
        private const val KEY_MODEL = "model"
        private const val KEY_ENDPOINT = "endpoint"
        private const val KEY_AUTO_SAVE = "auto_save"
        private const val KEY_NO_HISTORY = "no_history"
        private const val KEY_MINIMAP = "minimap"
        private const val KEY_CONTRAST = "contrast"
        private const val KEY_LAST_GRAPH = "last_graph"
        private const val KEY_SEEDED = "seeded"
    }
}
