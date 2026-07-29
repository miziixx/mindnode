package com.thoughtgraph.app.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import com.thoughtgraph.app.data.NodeType
import com.thoughtgraph.app.ui.AppViewModel
import com.thoughtgraph.app.ui.MainView
import com.thoughtgraph.app.ui.UiState
import com.thoughtgraph.app.ui.theme.Accent
import com.thoughtgraph.app.ui.theme.Bg
import com.thoughtgraph.app.ui.theme.Line
import com.thoughtgraph.app.ui.theme.Muted
import com.thoughtgraph.app.ui.theme.Panel

@Composable
fun AppRoot(viewModel: AppViewModel, state: UiState) {
    val configuration = LocalConfiguration.current
    val wide = configuration.screenWidthDp >= 900

    var drawerOpen by remember { mutableStateOf(false) }
    var settingsOpen by remember { mutableStateOf(false) }
    var exportOpen by remember { mutableStateOf(false) }
    var searchOpen by remember { mutableStateOf(false) }
    var editorNodeId by remember { mutableStateOf<String?>(null) }
    var connectingFrom by remember { mutableStateOf<String?>(null) }
    var zoom by remember { mutableStateOf(1f) }
    var pan by remember { mutableStateOf(Offset.Zero) }
    var quickText by remember { mutableStateOf("") }
    var quickType by remember { mutableStateOf(NodeType.IDEA) }

    val snackbarHost = remember { SnackbarHostState() }
    LaunchedEffect(state.message) {
        state.message?.let {
            snackbarHost.showSnackbar(it)
            viewModel.consumeMessage()
        }
    }

    // Android back button order: settings → drawer → current screen default.
    BackHandler(enabled = settingsOpen) { settingsOpen = false }
    BackHandler(enabled = !settingsOpen && drawerOpen) { drawerOpen = false }
    BackHandler(enabled = !settingsOpen && !drawerOpen && connectingFrom != null) { connectingFrom = null }

    Box(modifier = Modifier.fillMaxSize().background(Bg)) {
        Column(modifier = Modifier.fillMaxSize().padding(8.dp)) {
            TopBar(
                title = state.snapshot.meta.title,
                saving = state.saveState.saving,
                canUndo = state.canUndo,
                canRedo = state.canRedo,
                onMenu = { drawerOpen = true },
                onTitle = viewModel::setTitle,
                onUndo = viewModel::undo,
                onRedo = viewModel::redo,
                onSearch = { searchOpen = !searchOpen },
                onFocus = viewModel::toggleFocus,
                onExport = { exportOpen = true }
            )

            if (searchOpen) {
                SearchBar(state.searchQuery, viewModel::setSearch)
            }

            Row(modifier = Modifier.weight(1f).padding(top = 8.dp)) {
                if (wide && !state.focusMode) {
                    SideDrawerContent(
                        state = state,
                        modifier = Modifier.width(240.dp).fillMaxHeight(),
                        onNewGraph = viewModel::newGraph,
                        onOpenGraph = viewModel::openGraph,
                        onView = viewModel::setMainView,
                        onSettings = { settingsOpen = true }
                    )
                    Spacer(Modifier.width(8.dp))
                }

                Box(modifier = Modifier.weight(1f).fillMaxHeight()) {
                    MainContent(
                        viewModel, state, zoom, pan, connectingFrom,
                        onZoomPan = { z, p -> zoom = z; pan = p },
                        onOpenNode = { editorNodeId = it },
                        onTapConnecting = { target ->
                            connectingFrom?.let { viewModel.connect(it, target) }
                            connectingFrom = null
                        }
                    )
                    if (state.mainView == MainView.GRAPH) {
                        ZoomControls(
                            zoom = zoom,
                            onZoomIn = { zoom = (zoom + 0.1f).coerceAtMost(1.6f) },
                            onZoomOut = { zoom = (zoom - 0.1f).coerceAtLeast(0.5f) },
                            onFit = { zoom = 1f; pan = Offset.Zero },
                            modifier = Modifier.align(Alignment.TopEnd).padding(12.dp)
                        )
                        QuickInput(
                            text = quickText,
                            type = quickType,
                            onText = { quickText = it },
                            onCycleType = { quickType = nextType(quickType) },
                            onAdd = {
                                if (quickText.isNotBlank()) {
                                    viewModel.addNode(quickText.trim(), quickType)
                                    quickText = ""
                                }
                            },
                            modifier = Modifier.align(Alignment.BottomCenter).padding(12.dp)
                        )
                    }
                }

                if (wide && !state.focusMode) {
                    Spacer(Modifier.width(8.dp))
                    ToolPanelContent(
                        viewModel = viewModel,
                        state = state,
                        modifier = Modifier.width(300.dp).fillMaxHeight(),
                        onStartConnect = { connectingFrom = state.selectedNodeId },
                        onOpenSettings = { settingsOpen = true }
                    )
                }
            }
        }

        // Bottom nav on narrow screens
        if (!wide && !state.focusMode) {
            BottomNav(
                current = state.mainView,
                modifier = Modifier.align(Alignment.BottomCenter).padding(8.dp),
                onGraph = { viewModel.setMainView(MainView.GRAPH) },
                onTools = { drawerOpen = true },
                onExport = { exportOpen = true },
                onSettings = { settingsOpen = true }
            )
        }

        // Modal drawer (narrow)
        Scrim(visible = drawerOpen && !wide) { drawerOpen = false }
        AnimatedVisibility(
            visible = drawerOpen && !wide,
            enter = slideInHorizontally { -it },
            exit = slideOutHorizontally { -it }
        ) {
            SideDrawerContent(
                state = state,
                modifier = Modifier.width(300.dp).fillMaxHeight(),
                onNewGraph = { viewModel.newGraph(); drawerOpen = false },
                onOpenGraph = { viewModel.openGraph(it); drawerOpen = false },
                onView = { viewModel.setMainView(it); drawerOpen = false },
                onSettings = { drawerOpen = false; settingsOpen = true }
            )
        }

        // Settings sheet (full-screen on narrow)
        Scrim(visible = settingsOpen) { settingsOpen = false }
        AnimatedVisibility(
            visible = settingsOpen,
            enter = slideInHorizontally { it },
            exit = slideOutHorizontally { it },
            modifier = Modifier.align(Alignment.CenterEnd)
        ) {
            Box(modifier = Modifier.fillMaxHeight().width(if (wide) 460.dp else configuration.screenWidthDp.dp)) {
                SettingsSheet(
                    settings = viewModel.settings,
                    credentials = viewModel.credentials,
                    onClose = { settingsOpen = false },
                    onToast = { viewModel.postMessage(it) }
                )
            }
        }

        if (exportOpen) {
            ExportDialog(
                viewModel = viewModel,
                onDismiss = { exportOpen = false }
            )
        }

        editorNodeId?.let { id ->
            state.snapshot.nodes.firstOrNull { it.id == id }?.let { node ->
                NodeEditorDialog(
                    node = node,
                    edges = state.snapshot.edges,
                    onSave = { viewModel.updateNode(it); editorNodeId = null },
                    onDelete = { viewModel.deleteNode(id); editorNodeId = null },
                    onDuplicate = { viewModel.duplicateNode(id); editorNodeId = null },
                    onDisconnect = viewModel::disconnect,
                    onDismiss = { editorNodeId = null }
                )
            }
        }

        state.aiPreview?.let { preview ->
            AiPreviewDialog(
                preview = preview,
                onConfirm = viewModel::confirmAi,
                onCancel = viewModel::cancelAiPreview
            )
        }

        SnackbarHost(hostState = snackbarHost, modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 80.dp))
    }
}

private fun nextType(current: NodeType): NodeType {
    val order = listOf(NodeType.IDEA, NodeType.QUESTION, NodeType.TASK, NodeType.PROBLEM, NodeType.GOAL, NodeType.DECISION)
    val idx = order.indexOf(current)
    return order[(idx + 1).mod(order.size)]
}

@Composable
private fun MainContent(
    viewModel: AppViewModel,
    state: UiState,
    zoom: Float,
    pan: Offset,
    connectingFrom: String?,
    onZoomPan: (Float, Offset) -> Unit,
    onOpenNode: (String) -> Unit,
    onTapConnecting: (String) -> Unit
) {
    when (state.mainView) {
        MainView.GRAPH -> GraphCanvas(
            snapshot = state.snapshot,
            selectedNodeId = state.selectedNodeId,
            zoom = zoom,
            pan = pan,
            connectingFromId = connectingFrom,
            onZoomPan = onZoomPan,
            onSelect = viewModel::select,
            onMove = viewModel::moveNode,
            onTapNodeWhileConnecting = onTapConnecting,
            onOpenNode = onOpenNode
        )
        MainView.LIST -> Box(
            modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(24.dp)).background(Panel)
        ) { ListView(state.snapshot, state.searchQuery, viewModel::select) }
        MainView.PLAN -> Box(
            modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(24.dp)).background(Panel)
        ) { PlanView(state.snapshot, viewModel::select) }
    }
}

@Composable
private fun Scrim(visible: Boolean, onClick: () -> Unit) {
    AnimatedVisibility(visible = visible, enter = fadeIn(), exit = fadeOut()) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0x57231F1A))
                .clickable(onClick = onClick)
        )
    }
}
