package com.thoughtgraph.app.ui.screens

import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
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
import com.thoughtgraph.app.data.GraphSnapshot
import com.thoughtgraph.app.data.NodeType
import com.thoughtgraph.app.exportimport.FileOps
import com.thoughtgraph.app.exportimport.GraphSerializer
import com.thoughtgraph.app.ui.AppViewModel
import com.thoughtgraph.app.ui.MainView
import com.thoughtgraph.app.ui.UiState
import com.thoughtgraph.app.ui.theme.Bg
import com.thoughtgraph.app.ui.theme.Panel

private data class ImportPreview(val graphs: List<GraphSnapshot>, val nodeCount: Int)

@Composable
fun AppRoot(viewModel: AppViewModel, state: UiState) {
    val configuration = LocalConfiguration.current
    val wide = configuration.screenWidthDp >= 900
    val context = LocalContext.current

    var drawerOpen by remember { mutableStateOf(false) }
    var settingsOpen by remember { mutableStateOf(false) }
    var exportOpen by remember { mutableStateOf(false) }
    var searchOpen by remember { mutableStateOf(false) }
    var editorNodeId by remember { mutableStateOf<String?>(null) }
    var menuNodeId by remember { mutableStateOf<String?>(null) }
    var pendingConnectFrom by remember { mutableStateOf<String?>(null) }
    var zoom by remember { mutableStateOf(1f) }
    var pan by remember { mutableStateOf(Offset.Zero) }
    var quickText by remember { mutableStateOf("") }
    var quickType by remember { mutableStateOf(NodeType.IDEA) }

    // Export/import via the Android Storage Access Framework (real files).
    var pendingExport by remember { mutableStateOf<String?>(null) }
    var importPreview by remember { mutableStateOf<ImportPreview?>(null) }

    val createJson = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        val content = pendingExport
        if (uri != null && content != null) {
            viewModel.postMessage(if (FileOps.writeToUri(context, uri, content)) "JSON 파일을 저장했습니다." else "파일 저장에 실패했습니다.")
        }
        pendingExport = null
    }
    val createMarkdown = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/markdown")) { uri ->
        val content = pendingExport
        if (uri != null && content != null) {
            viewModel.postMessage(if (FileOps.writeToUri(context, uri, content)) "Markdown 파일을 저장했습니다." else "파일 저장에 실패했습니다.")
        }
        pendingExport = null
    }
    val openDoc = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            val text = FileOps.readFromUri(context, uri)
            if (text == null) {
                viewModel.postMessage("파일을 읽을 수 없습니다.")
            } else {
                try {
                    val graphs = try {
                        GraphSerializer.restore(text)
                    } catch (e: GraphSerializer.ImportException) {
                        listOf(GraphSerializer.fromJson(text))
                    }
                    importPreview = ImportPreview(graphs, graphs.sumOf { it.nodes.size })
                } catch (e: GraphSerializer.ImportException) {
                    viewModel.postMessage("가져오기 실패: ${e.message}")
                } catch (e: Exception) {
                    viewModel.postMessage("가져오기 실패: 형식이 올바르지 않습니다.")
                }
            }
        }
    }

    val snackbarHost = remember { SnackbarHostState() }
    LaunchedEffect(state.message) {
        state.message?.let {
            snackbarHost.showSnackbar(it)
            viewModel.consumeMessage()
        }
    }

    // Android back button order: dialog/sheet → settings → drawer → connect-mode.
    BackHandler(enabled = editorNodeId != null) { editorNodeId = null }
    BackHandler(enabled = editorNodeId == null && menuNodeId != null) { menuNodeId = null }
    BackHandler(enabled = editorNodeId == null && menuNodeId == null && settingsOpen) { settingsOpen = false }
    BackHandler(enabled = editorNodeId == null && menuNodeId == null && !settingsOpen && drawerOpen) { drawerOpen = false }
    BackHandler(enabled = editorNodeId == null && menuNodeId == null && !settingsOpen && !drawerOpen && pendingConnectFrom != null) { pendingConnectFrom = null }

    fun onNodeSelect(id: String) {
        val from = pendingConnectFrom
        if (from != null && from != id) {
            viewModel.connect(from, id)
            pendingConnectFrom = null
        } else {
            viewModel.select(id)
        }
    }

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

            if (searchOpen) SearchBar(state.searchQuery, viewModel::setSearch)

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
                    when (state.mainView) {
                        MainView.GRAPH -> GraphCanvas(
                            snapshot = state.snapshot,
                            selectedNodeId = state.selectedNodeId,
                            zoom = zoom,
                            pan = pan,
                            onZoomPan = { z, p -> zoom = z; pan = p },
                            onSelect = { onNodeSelect(it) },
                            onClearSelection = { viewModel.select(null); pendingConnectFrom = null },
                            onMove = viewModel::moveNode,
                            onAddNodeAt = { x, y -> viewModel.addNodeAt(x, y) },
                            onOpenNode = { editorNodeId = it },
                            onNodeMenu = { menuNodeId = it },
                            onConnect = { s, t -> viewModel.connect(s, t) }
                        )
                        MainView.LIST -> Box(Modifier.fillMaxSize().clip(RoundedCornerShape(24.dp)).background(Panel)) {
                            ListView(state.snapshot, state.searchQuery, viewModel::select)
                        }
                        MainView.PLAN -> Box(Modifier.fillMaxSize().clip(RoundedCornerShape(24.dp)).background(Panel)) {
                            PlanView(state.snapshot, viewModel::select)
                        }
                    }

                    if (state.mainView == MainView.GRAPH) {
                        ZoomControls(
                            zoom = zoom,
                            onZoomIn = { zoom = (zoom + 0.1f).coerceAtMost(1.8f) },
                            onZoomOut = { zoom = (zoom - 0.1f).coerceAtLeast(0.4f) },
                            onFit = { zoom = 1f; pan = Offset.Zero },
                            modifier = Modifier.align(Alignment.TopEnd).padding(12.dp)
                        )
                        if (pendingConnectFrom != null) {
                            Box(
                                Modifier.align(Alignment.TopCenter).padding(12.dp)
                                    .clip(RoundedCornerShape(999.dp)).background(Color(0xFFEF7657)).padding(horizontal = 14.dp, vertical = 8.dp)
                            ) { Text("연결할 노드를 탭하세요 (뒤로가기로 취소)", color = Color.White, fontWeight = FontWeight.Black) }
                        }
                        QuickInput(
                            text = quickText,
                            type = quickType,
                            onText = { quickText = it },
                            onCycleType = { quickType = nextType(quickType) },
                            onAdd = {
                                if (quickText.isNotBlank()) { viewModel.addNode(quickText.trim(), quickType); quickText = "" }
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
                        onStartConnect = { pendingConnectFrom = state.selectedNodeId },
                        onOpenSettings = { settingsOpen = true }
                    )
                }
            }
        }

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

        Scrim(visible = drawerOpen && !wide) { drawerOpen = false }
        AnimatedVisibility(visible = drawerOpen && !wide, enter = slideInHorizontally { -it }, exit = slideOutHorizontally { -it }) {
            SideDrawerContent(
                state = state,
                modifier = Modifier.width(300.dp).fillMaxHeight(),
                onNewGraph = { viewModel.newGraph(); drawerOpen = false },
                onOpenGraph = { viewModel.openGraph(it); drawerOpen = false },
                onView = { viewModel.setMainView(it); drawerOpen = false },
                onSettings = { drawerOpen = false; settingsOpen = true }
            )
        }

        Scrim(visible = settingsOpen) { settingsOpen = false }
        AnimatedVisibility(
            visible = settingsOpen,
            enter = slideInHorizontally { it },
            exit = slideOutHorizontally { it },
            modifier = Modifier.align(Alignment.CenterEnd)
        ) {
            Box(Modifier.fillMaxHeight().width(if (wide) 460.dp else configuration.screenWidthDp.dp)) {
                SettingsSheet(
                    settings = viewModel.settings,
                    credentials = viewModel.credentials,
                    aiClient = viewModel.ai,
                    onClose = { settingsOpen = false },
                    onToast = { viewModel.postMessage(it) }
                )
            }
        }

        if (exportOpen) {
            ExportSheet(
                onDismiss = { exportOpen = false },
                onSaveJson = { pendingExport = GraphSerializer.toJson(state.snapshot); createJson.launch("${safeName(state.snapshot.meta.title)}.json"); exportOpen = false },
                onSaveMarkdown = { pendingExport = GraphSerializer.toMarkdown(state.snapshot); createMarkdown.launch("${safeName(state.snapshot.meta.title)}.md"); exportOpen = false },
                onShareJson = { FileOps.shareText(context, "${safeName(state.snapshot.meta.title)}.json", "application/json", GraphSerializer.toJson(state.snapshot)); exportOpen = false },
                onBackup = { pendingExport = GraphSerializer.backup(viewModel.repository().allGraphs()); createJson.launch("nodemode-backup.json"); exportOpen = false },
                onCopyAiContext = {
                    val sel = state.snapshot.nodes.filter { it.id == state.selectedNodeId }
                    FileOps.shareText(context, "context.txt", "text/plain", GraphSerializer.toAiContext(state.snapshot, sel))
                    exportOpen = false
                },
                onImport = { openDoc.launch(arrayOf("application/json", "text/*", "*/*")); exportOpen = false }
            )
        }

        importPreview?.let { preview ->
            ImportConfirmDialog(
                nodeCount = preview.nodeCount,
                graphCount = preview.graphs.size,
                onConfirm = { replace ->
                    viewModel.repository().restoreBackup(preview.graphs, replace)
                    viewModel.refreshRecents()
                    preview.graphs.firstOrNull()?.let { viewModel.openGraph(it.meta.id) }
                    viewModel.postMessage("${preview.graphs.size}개 그래프를 가져왔습니다.")
                    importPreview = null
                },
                onCancel = { importPreview = null }
            )
        }

        menuNodeId?.let { id ->
            NodeContextMenu(
                onEdit = { editorNodeId = id; menuNodeId = null },
                onDuplicate = { viewModel.duplicateNode(id); menuNodeId = null },
                onConnect = { viewModel.select(id); pendingConnectFrom = id; menuNodeId = null },
                onDelete = { viewModel.deleteNode(id); menuNodeId = null },
                onDismiss = { menuNodeId = null }
            )
        }

        editorNodeId?.let { id ->
            state.snapshot.nodes.firstOrNull { it.id == id }?.let { node ->
                NodeEditorSheet(
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
            AiPreviewDialog(preview = preview, onConfirm = viewModel::confirmAi, onCancel = viewModel::cancelAiPreview)
        }

        SnackbarHost(hostState = snackbarHost, modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 80.dp))
    }
}

@Composable
private fun NodeContextMenu(
    onEdit: () -> Unit,
    onDuplicate: () -> Unit,
    onConnect: () -> Unit,
    onDelete: () -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text("닫기") } },
        title = { Text("노드 작업", fontWeight = FontWeight.Black) },
        text = {
            Column {
                MenuRow("편집", onEdit)
                MenuRow("복제", onDuplicate)
                MenuRow("연결 시작", onConnect)
                MenuRow("삭제", onDelete, danger = true)
            }
        }
    )
}

@Composable
private fun MenuRow(label: String, onClick: () -> Unit, danger: Boolean = false) {
    Text(
        label,
        color = if (danger) Color(0xFFC85151) else Color(0xFF26241F),
        fontWeight = FontWeight.Black,
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 14.dp)
    )
}

@Composable
private fun ImportConfirmDialog(
    nodeCount: Int,
    graphCount: Int,
    onConfirm: (Boolean) -> Unit,
    onCancel: () -> Unit
) {
    var replace by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onCancel,
        confirmButton = { TextButton(onClick = { onConfirm(replace) }) { Text("가져오기") } },
        dismissButton = { TextButton(onClick = onCancel) { Text("취소") } },
        title = { Text("가져오기 미리보기", fontWeight = FontWeight.Black) },
        text = {
            Column {
                Text("그래프 ${graphCount}개 · 노드 ${nodeCount}개를 가져옵니다.")
                Row(modifier = Modifier.padding(top = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                    androidx.compose.material3.Checkbox(checked = replace, onCheckedChange = { replace = it })
                    Text("기존 데이터를 모두 지우고 교체")
                }
                if (!replace) Text("체크 해제 시 기존 그래프에 추가/병합됩니다.", color = Color(0xFF888177))
            }
        }
    )
}

private fun safeName(title: String): String =
    title.ifBlank { "graph" }.replace(Regex("[^\\p{L}\\p{N}_-]"), "_").take(40)

private fun nextType(current: NodeType): NodeType {
    val order = listOf(NodeType.IDEA, NodeType.QUESTION, NodeType.TASK, NodeType.PROBLEM, NodeType.GOAL, NodeType.DECISION)
    val idx = order.indexOf(current)
    return order[(idx + 1).mod(order.size)]
}

@Composable
private fun Scrim(visible: Boolean, onClick: () -> Unit) {
    AnimatedVisibility(visible = visible, enter = fadeIn(), exit = fadeOut()) {
        Box(Modifier.fillMaxSize().background(Color(0x57231F1A)).clickable(onClick = onClick))
    }
}
