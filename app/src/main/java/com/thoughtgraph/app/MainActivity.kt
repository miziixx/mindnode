package com.thoughtgraph.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.runtime.collectAsState
import com.thoughtgraph.app.ui.AppViewModel
import com.thoughtgraph.app.ui.screens.AppRoot
import com.thoughtgraph.app.ui.theme.Bg
import com.thoughtgraph.app.ui.theme.ThoughtGraphTheme

class MainActivity : ComponentActivity() {

    private val viewModel: AppViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            ThoughtGraphTheme {
                val state by viewModel.state.collectAsState()
                Surface(
                    modifier = Modifier
                        .fillMaxSize()
                        .windowInsetsPadding(WindowInsets.systemBars)
                        .imePadding(),
                    color = Bg
                ) {
                    AppRoot(viewModel = viewModel, state = state)
                }
            }
        }
    }
}
