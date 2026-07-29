package com.thoughtgraph.app.ui.screens

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.ClipboardManager
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.thoughtgraph.app.ai.AiAction
import com.thoughtgraph.app.data.Edge
import com.thoughtgraph.app.data.Importance
import com.thoughtgraph.app.data.Node
import com.thoughtgraph.app.data.NodeStatus
import com.thoughtgraph.app.data.NodeType
import com.thoughtgraph.app.exportimport.GraphSerializer
import com.thoughtgraph.app.localtools.ThinkingTools
import com.thoughtgraph.app.ui.AiPreviewState
import com.thoughtgraph.app.ui.AppViewModel
import com.thoughtgraph.app.ui.UiState
import com.thoughtgraph.app.ui.theme.Accent
import com.thoughtgraph.app.ui.theme.AccentDark
import com.thoughtgraph.app.ui.theme.GreenSoft
import com.thoughtgraph.app.ui.theme.Line
import com.thoughtgraph.app.ui.theme.Muted
import com.thoughtgraph.app.ui.theme.Panel
import com.thoughtgraph.app.ui.theme.Panel2
import com.thoughtgraph.app.ui.theme.Purple
import com.thoughtgraph.app.ui.theme.PurpleSoft

@Composable
fun ToolPanelContent(
    viewModel: AppViewModel,
    state: UiState,
    modifier: Modifier = Modifier,
    onStartConnect: () -> Unit,
    onOpenSettings: () -> Unit
) {
    val selected = state.snapshot.nodes.firstOrNull { it.id == state.selectedNodeId }
    val aiReady = viewModel.ai.isReady()
    val drafts = state.snapshot.nodes.filter { it.isDraft }

    Column(
        modifier = modifier
            .clip(RoundedCornerShape(22.dp))
            .background(Panel)
            .border(1.dp, Line, RoundedCornerShape(22.dp))
            .verticalScroll(rememberScrollState())
            .padding(14.dp)
    ) {
        Text("생각 도구", fontSize = 14.sp, fontWeight = FontWeight.Black)
        Text("기본 기능은 규칙과 템플릿으로 동작합니다.", color = Muted, fontSize = 10.sp)
        Box(
            modifier = Modifier.padding(top = 10.dp).clip(RoundedCornerShape(999.dp))
                .background(GreenSoft).padding(horizontal = 8.dp, vertical = 5.dp)
        ) {
            Text(if (aiReady) "로컬 우선 · AI 수동 호출" else "로컬 모드 · AI 꺼짐",
                color = Color(0xFF628F76), fontSize = 9.sp, fontWeight = FontWeight.Black)
        }

        // Selected node card
        Box(
            modifier = Modifier.fillMaxWidth().padding(top = 14.dp)
                .clip(RoundedCornerShape(16.dp)).background(Color(0xFFFFF6F1)).padding(13.dp)
        ) {
            Column {
                Text("선택한 노드", color = AccentDark, fontSize = 8.sp, fontWeight = FontWeight.Black)
                Text(selected?.title?.ifBlank { "제목 없음" } ?: "노드를 선택하세요",
                    fontSize = 13.sp, fontWeight = FontWeight.Black, modifier = Modifier.padding(top = 6.dp))
                if (selected?.description?.isNotBlank() == true) {
                    Text(selected.description, color = Muted, fontSize = 9.sp, modifier = Modifier.padding(top = 6.dp))
                }
            }
        }

        // Local tools
        GroupTitle("AI 없이 바로 쓰는 도구")
        Row(horizontalArrangement = Arrangement.spacedBy(7.dp), modifier = Modifier.fillMaxWidth()) {
            ToolButton("?", "질문 붙이기", "고정 질문 추가", Modifier.weight(1f)) { viewModel.applyTemplate(ThinkingTools.Template.QUESTION) }
            ToolButton("↔", "원인·결과", "두 갈래 구조", Modifier.weight(1f)) { viewModel.applyTemplate(ThinkingTools.Template.CAUSE_EFFECT) }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(7.dp), modifier = Modifier.fillMaxWidth().padding(top = 7.dp)) {
            ToolButton("1·2·3", "단계로 나누기", "준비·실행·확인", Modifier.weight(1f)) { viewModel.applyTemplate(ThinkingTools.Template.STEPS) }
            ToolButton("✓", "할 일로 바꾸기", "상태·예상 시간", Modifier.weight(1f)) { viewModel.convertSelectedToTask() }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(7.dp), modifier = Modifier.fillMaxWidth().padding(top = 7.dp)) {
            ToolButton("⤢", "자동 정렬", "겹침 정리", Modifier.weight(1f)) { viewModel.autoLayout() }
            ToolButton("⇢", "연결 시작", "다른 노드 탭", Modifier.weight(1f), enabled = selected != null) { onStartConnect() }
        }

        // Structure check
        var issues by remember { mutableStateOf<List<ThinkingTools.Issue>?>(null) }
        Box(
            modifier = Modifier.fillMaxWidth().padding(top = 12.dp)
                .clip(RoundedCornerShape(15.dp)).background(GreenSoft)
                .clickable { issues = viewModel.runStructureCheck() }.padding(12.dp)
        ) {
            Column {
                Text("로컬 구조 점검 (탭하여 실행)", color = Color(0xFF4F775F), fontSize = 10.sp, fontWeight = FontWeight.Black)
                val list = issues
                if (list == null) {
                    Text("저장된 노드 종류만 확인하며 외부 전송을 하지 않습니다.", color = Color(0xFF61776A), fontSize = 9.sp,
                        modifier = Modifier.padding(top = 6.dp))
                } else if (list.isEmpty()) {
                    Text("발견된 문제가 없습니다.", color = Color(0xFF61776A), fontSize = 9.sp, modifier = Modifier.padding(top = 6.dp))
                } else {
                    list.take(6).forEach { Text("• ${it.message}", color = Color(0xFF61776A), fontSize = 9.sp, modifier = Modifier.padding(top = 4.dp)) }
                }
            }
        }

        // Optional AI section
        Box(
            modifier = Modifier.fillMaxWidth().padding(top = 14.dp)
                .clip(RoundedCornerShape(15.dp)).background(PurpleSoft).padding(12.dp)
        ) {
            Column {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("선택형 AI 보조", color = Color(0xFF625995), fontSize = 10.sp, fontWeight = FontWeight.Black)
                    Text(if (aiReady) "수동 사용 가능" else "사용 안 함", color = Color(0xFF6F669B), fontSize = 8.sp, fontWeight = FontWeight.Black)
                }
                if (aiReady) {
                    Text("노드를 선택하고 버튼을 누르면 전송 내용을 먼저 확인합니다.", color = Color(0xFF716A8D), fontSize = 9.sp,
                        modifier = Modifier.padding(top = 7.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                        AiButton("빈틈 찾기", Modifier.weight(1f)) { viewModel.prepareAi(AiAction.FIND_GAPS) }
                        AiButton("반대 관점", Modifier.weight(1f)) { viewModel.prepareAi(AiAction.OPPOSITE) }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth().padding(top = 6.dp)) {
                        AiButton("문장 구체화", Modifier.weight(1f)) { viewModel.prepareAi(AiAction.REFINE) }
                        AiButton("다음 단계", Modifier.weight(1f)) { viewModel.prepareAi(AiAction.NEXT_STEP) }
                    }
                } else {
                    Text("설정에서 직접 켜기 전에는 버튼도 호출도 동작하지 않습니다.", color = Color(0xFF716A8D), fontSize = 9.sp,
                        modifier = Modifier.padding(top = 7.dp))
                    Box(
                        modifier = Modifier.fillMaxWidth().padding(top = 9.dp)
                            .clip(RoundedCornerShape(10.dp)).background(Color.White)
                            .clickable(onClick = onOpenSettings).padding(vertical = 10.dp),
                        contentAlignment = Alignment.Center
                    ) { Text("AI 설정 열기", color = Color(0xFF635A93), fontSize = 9.sp, fontWeight = FontWeight.Black) }
                }
            }
        }

        // Draft approvals
        if (drafts.isNotEmpty()) {
            GroupTitle("AI 임시 제안 (승인 전)")
            drafts.forEach { draft ->
                Box(
                    modifier = Modifier.fillMaxWidth().padding(bottom = 6.dp)
                        .clip(RoundedCornerShape(13.dp)).background(PurpleSoft).padding(11.dp)
                ) {
                    Column {
                        Text(draft.title, color = Purple, fontSize = 11.sp, fontWeight = FontWeight.Black)
                        Row(modifier = Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            SmallBtn("추가", Accent, Color.White) { viewModel.approveDraft(draft.id) }
                            SmallBtn("숨기기", Panel2, Muted) { viewModel.dismissDraft(draft.id) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun GroupTitle(text: String) {
    Text(text, color = Muted, fontSize = 9.sp, fontWeight = FontWeight.Black,
        modifier = Modifier.padding(top = 14.dp, bottom = 8.dp))
}

@Composable
private fun ToolButton(icon: String, name: String, desc: String, modifier: Modifier, enabled: Boolean = true, onClick: () -> Unit) {
    Column(
        modifier = modifier
            .heightIn(min = 72.dp)
            .clip(RoundedCornerShape(13.dp))
            .background(Color.White)
            .border(1.dp, Line, RoundedCornerShape(13.dp))
            .clickable(enabled = enabled, onClick = onClick)
            .padding(10.dp)
    ) {
        Text(icon, fontSize = 15.sp)
        Text(name, fontSize = 10.sp, fontWeight = FontWeight.Black, modifier = Modifier.padding(top = 6.dp))
        Text(desc, color = Muted, fontSize = 8.sp)
    }
}

@Composable
private fun AiButton(label: String, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier = modifier.clip(RoundedCornerShape(10.dp)).background(Color.White)
            .clickable(onClick = onClick).padding(vertical = 10.dp),
        contentAlignment = Alignment.Center
    ) { Text(label, color = Color(0xFF635A93), fontSize = 9.sp, fontWeight = FontWeight.Black) }
}

@Composable
private fun SmallBtn(label: String, bg: Color, fg: Color, onClick: () -> Unit) {
    Box(
        modifier = Modifier.clip(RoundedCornerShape(9.dp)).background(bg).clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 6.dp)
    ) { Text(label, color = fg, fontSize = 9.sp, fontWeight = FontWeight.Black) }
}

// ---- Export / Import dialog ----

@Composable
fun ExportDialog(viewModel: AppViewModel, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val clipboard = LocalClipboardManager.current
    val state by viewModel.state.collectAsState()
    var importOpen by remember { mutableStateOf(false) }

    if (importOpen) {
        ImportDialog(viewModel = viewModel, onDone = { importOpen = false; onDismiss() }, onCancel = { importOpen = false })
        return
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = onDismiss) { Text("닫기") } },
        title = { Text("내보내기 · 백업", fontWeight = FontWeight.Black) },
        text = {
            Column {
                OptionRow("JSON · 노드와 연결 구조") {
                    shareText(context, GraphSerializer.toJson(state.snapshot))
                }
                OptionRow("Markdown · 읽기 쉬운 문서") {
                    shareText(context, GraphSerializer.toMarkdown(state.snapshot))
                }
                OptionRow("AI 전달용 맥락 · 클립보드 복사") {
                    val sel = state.snapshot.nodes.filter { it.id == state.selectedNodeId }
                    clipboard.setText(AnnotatedString(GraphSerializer.toAiContext(state.snapshot, sel)))
                    viewModel.postMessage("AI 전달용 맥락을 복사했습니다.")
                    onDismiss()
                }
                OptionRow("전체 백업 (모든 그래프) · 공유") {
                    shareText(context, GraphSerializer.backup(viewModel.repository().allGraphs()))
                }
                OptionRow("가져오기 / 복구 (JSON 붙여넣기)") { importOpen = true }
            }
        }
    )
}

@Composable
private fun OptionRow(label: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)
            .clip(RoundedCornerShape(12.dp)).background(Color.White)
            .border(1.dp, Line, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick).padding(12.dp)
    ) { Text(label, fontSize = 11.sp, fontWeight = FontWeight.Black) }
}

@Composable
fun ImportDialog(viewModel: AppViewModel, onDone: () -> Unit, onCancel: () -> Unit) {
    var text by remember { mutableStateOf("") }
    var preview by remember { mutableStateOf<String?>(null) }
    var parsed by remember { mutableStateOf<List<com.thoughtgraph.app.data.GraphSnapshot>?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var replace by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onCancel,
        confirmButton = {
            TextButton(
                enabled = parsed != null,
                onClick = {
                    parsed?.let {
                        try {
                            viewModel.repository().restoreBackup(it, replace = replace)
                            viewModel.refreshRecents()
                            it.firstOrNull()?.let { g -> viewModel.openGraph(g.meta.id) }
                            viewModel.postMessage("${it.size}개 그래프를 가져왔습니다.")
                            onDone()
                        } catch (e: Exception) {
                            error = "가져오기에 실패했습니다."
                        }
                    }
                }
            ) { Text("가져오기") }
        },
        dismissButton = { TextButton(onClick = onCancel) { Text("취소") } },
        title = { Text("가져오기 / 복구", fontWeight = FontWeight.Black) },
        text = {
            Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
                Text("JSON 또는 백업 텍스트를 붙여넣고 미리보기로 확인하세요.", color = Muted, fontSize = 10.sp)
                OutlinedTextField(
                    value = text,
                    onValueChange = { text = it; preview = null; parsed = null; error = null },
                    modifier = Modifier.fillMaxWidth().heightIn(min = 120.dp).padding(top = 8.dp),
                    placeholder = { Text("{ \"nodes\": [ ... ] }") }
                )
                TextButton(onClick = {
                    try {
                        val graphs = try {
                            GraphSerializer.restore(text)
                        } catch (e: GraphSerializer.ImportException) {
                            listOf(GraphSerializer.fromJson(text))
                        }
                        parsed = graphs
                        val nodeCount = graphs.sumOf { it.nodes.size }
                        preview = "그래프 ${graphs.size}개 · 노드 ${nodeCount}개"
                        error = null
                    } catch (e: GraphSerializer.ImportException) {
                        error = e.message; parsed = null; preview = null
                    } catch (e: Exception) {
                        error = "형식이 올바르지 않습니다."; parsed = null; preview = null
                    }
                }) { Text("미리보기") }
                preview?.let { Text(it, color = Color(0xFF4F775F), fontSize = 11.sp, fontWeight = FontWeight.Black) }
                error?.let { Text(it, color = Color(0xFFC85151), fontSize = 11.sp) }
                Row(modifier = Modifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                    androidx.compose.material3.Checkbox(checked = replace, onCheckedChange = { replace = it })
                    Text("기존 데이터를 모두 지우고 교체 (중복 처리)", fontSize = 10.sp)
                }
                if (!replace) Text("체크 해제 시 기존 그래프에 추가/병합됩니다.", color = Muted, fontSize = 9.sp)
            }
        }
    )
}

private fun shareText(context: android.content.Context, content: String) {
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, content)
    }
    context.startActivity(Intent.createChooser(intent, "내보내기"))
}

// ---- Node editor ----

@Composable
fun NodeEditorDialog(
    node: Node,
    edges: List<Edge>,
    onSave: (Node) -> Unit,
    onDelete: () -> Unit,
    onDuplicate: () -> Unit,
    onDisconnect: (String) -> Unit,
    onDismiss: () -> Unit
) {
    var title by remember { mutableStateOf(node.title) }
    var desc by remember { mutableStateOf(node.description) }
    var type by remember { mutableStateOf(node.type) }
    var status by remember { mutableStateOf(node.status) }
    var importance by remember { mutableStateOf(node.importance) }
    var minutes by remember { mutableStateOf(node.estimatedMinutes?.toString() ?: "") }

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = {
                onSave(node.copy(
                    title = title, description = desc, type = type, status = status,
                    importance = importance,
                    estimatedMinutes = minutes.toIntOrNull()
                ))
            }) { Text("저장") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("닫기") } },
        title = { Text("노드 편집", fontWeight = FontWeight.Black) },
        text = {
            Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
                OutlinedTextField(title, { title = it }, label = { Text("제목") }, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(desc, { desc = it }, label = { Text("설명") }, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))

                ChipLabel("종류")
                ChipRow(NodeType.entries.map { it.label }, type.label) { type = NodeType.fromLabel(it) }
                ChipLabel("상태")
                ChipRow(NodeStatus.entries.map { it.label }, status.label) { sel -> status = NodeStatus.entries.first { it.label == sel } }
                ChipLabel("중요도")
                ChipRow(Importance.entries.map { it.label }, importance.label) { sel -> importance = Importance.entries.first { it.label == sel } }

                OutlinedTextField(minutes, { minutes = it.filter { c -> c.isDigit() } }, label = { Text("예상 시간(분)") },
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp))

                val connected = edges.filter { it.sourceNodeId == node.id || it.targetNodeId == node.id }
                if (connected.isNotEmpty()) {
                    ChipLabel("연결 (${connected.size})")
                    connected.forEach { e ->
                        Row(modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(e.relationType, fontSize = 11.sp)
                            TextButton(onClick = { onDisconnect(e.id) }) { Text("연결 삭제", fontSize = 11.sp) }
                        }
                    }
                }

                Row(modifier = Modifier.padding(top = 8.dp)) {
                    TextButton(onClick = onDuplicate) { Text("복제") }
                    TextButton(onClick = onDelete) { Text("삭제", color = Color(0xFFC85151)) }
                }
            }
        }
    )
}

@Composable
private fun ChipLabel(text: String) {
    Text(text, color = Muted, fontSize = 9.sp, fontWeight = FontWeight.Black, modifier = Modifier.padding(top = 12.dp, bottom = 6.dp))
}

@Composable
private fun ChipRow(options: List<String>, selected: String, onSelect: (String) -> Unit) {
    val scroll = rememberScrollState()
    Row(modifier = Modifier.fillMaxWidth().horizontalScrollCompat(scroll), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        options.forEach { opt ->
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(999.dp))
                    .background(if (opt == selected) Accent else Panel2)
                    .clickable { onSelect(opt) }
                    .padding(horizontal = 10.dp, vertical = 6.dp)
            ) { Text(opt, color = if (opt == selected) Color.White else Muted, fontSize = 10.sp, fontWeight = FontWeight.Black) }
        }
    }
}

private fun Modifier.horizontalScrollCompat(state: androidx.compose.foundation.ScrollState): Modifier =
    this.horizontalScroll(state)

// ---- AI preview dialog ----

@Composable
fun AiPreviewDialog(preview: AiPreviewState, onConfirm: () -> Unit, onCancel: () -> Unit) {
    AlertDialog(
        onDismissRequest = onCancel,
        confirmButton = { TextButton(onClick = onConfirm) { Text("확인 후 호출") } },
        dismissButton = { TextButton(onClick = onCancel) { Text("취소") } },
        title = { Text("전송 내용 확인", fontWeight = FontWeight.Black) },
        text = {
            Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
                Text("${preview.provider} · ${preview.model}", color = Muted, fontSize = 10.sp)
                Text(preview.endpoint, color = Muted, fontSize = 9.sp, modifier = Modifier.padding(top = 2.dp))
                Box(
                    modifier = Modifier.fillMaxWidth().padding(top = 10.dp)
                        .clip(RoundedCornerShape(12.dp)).background(Panel2).padding(12.dp)
                ) { Text(preview.contextText, fontSize = 11.sp) }
                Text("이 내용만 전송됩니다. 결과는 임시 노드로 표시되며 승인해야 저장됩니다.",
                    color = Muted, fontSize = 9.sp, modifier = Modifier.padding(top = 8.dp))
            }
        }
    )
}
