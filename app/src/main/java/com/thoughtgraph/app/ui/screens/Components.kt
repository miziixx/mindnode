package com.thoughtgraph.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Redo
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Undo
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.thoughtgraph.app.data.GraphMeta
import com.thoughtgraph.app.data.NodeType
import com.thoughtgraph.app.ui.MainView
import com.thoughtgraph.app.ui.UiState
import com.thoughtgraph.app.ui.theme.Accent
import com.thoughtgraph.app.ui.theme.AccentDark
import com.thoughtgraph.app.ui.theme.AccentSoft
import com.thoughtgraph.app.ui.theme.Green
import com.thoughtgraph.app.ui.theme.GreenSoft
import com.thoughtgraph.app.ui.theme.Line
import com.thoughtgraph.app.ui.theme.Muted
import com.thoughtgraph.app.ui.theme.Panel
import com.thoughtgraph.app.ui.theme.Panel2
import com.thoughtgraph.app.ui.theme.TextMain

@Composable
fun TopBar(
    title: String,
    saving: Boolean,
    canUndo: Boolean,
    canRedo: Boolean,
    onMenu: () -> Unit,
    onTitle: (String) -> Unit,
    onUndo: () -> Unit,
    onRedo: () -> Unit,
    onSearch: () -> Unit,
    onFocus: () -> Unit,
    onExport: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(60.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(Panel)
            .border(1.dp, Line, RoundedCornerShape(18.dp))
            .padding(horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = onMenu) { Icon(Icons.Filled.Menu, contentDescription = "메뉴 열기") }
        Box(
            modifier = Modifier.size(34.dp).clip(RoundedCornerShape(11.dp)).background(Accent),
            contentAlignment = Alignment.Center
        ) { Text("T", color = Color.White, fontWeight = FontWeight.Black) }
        Spacer(Modifier.width(8.dp))
        BasicTextField(
            value = title,
            onValueChange = onTitle,
            singleLine = true,
            textStyle = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.Black, color = TextMain),
            modifier = Modifier.weight(1f)
        )
        if (saving) {
            Text("저장 중…", color = Muted, fontSize = 9.sp)
        } else {
            Box(
                modifier = Modifier.clip(RoundedCornerShape(999.dp)).background(GreenSoft).padding(horizontal = 8.dp, vertical = 4.dp)
            ) { Text("기기에 저장됨", color = Green, fontSize = 9.sp, fontWeight = FontWeight.Black) }
        }
        IconButton(onClick = onUndo, enabled = canUndo) { Icon(Icons.Filled.Undo, contentDescription = "실행 취소") }
        IconButton(onClick = onRedo, enabled = canRedo) { Icon(Icons.Filled.Redo, contentDescription = "다시 실행") }
        IconButton(onClick = onSearch) { Icon(Icons.Filled.Search, contentDescription = "검색") }
        Box(
            modifier = Modifier.clip(RoundedCornerShape(12.dp)).background(Accent).clickable(onClick = onExport).padding(horizontal = 12.dp, vertical = 8.dp)
        ) { Text("내보내기", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Black) }
    }
}

@Composable
fun SearchBar(query: String, onChange: (String) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Panel)
            .border(1.dp, Line, RoundedCornerShape(14.dp))
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(Icons.Filled.Search, contentDescription = null, tint = Muted)
        Spacer(Modifier.width(8.dp))
        BasicTextField(
            value = query,
            onValueChange = onChange,
            singleLine = true,
            textStyle = TextStyle(fontSize = 13.sp, color = TextMain),
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
fun SideDrawerContent(
    state: UiState,
    modifier: Modifier = Modifier,
    onNewGraph: () -> Unit,
    onOpenGraph: (String) -> Unit,
    onView: (MainView) -> Unit,
    onSettings: () -> Unit
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(22.dp))
            .background(Panel)
            .border(1.dp, Line, RoundedCornerShape(22.dp))
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("LOCAL-FIRST GRAPH", color = Muted, fontSize = 9.sp, fontWeight = FontWeight.Black)
            Text("내 생각 보관함", fontSize = 15.sp, fontWeight = FontWeight.Black, modifier = Modifier.padding(top = 4.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth().padding(top = 12.dp)
                    .clip(RoundedCornerShape(13.dp)).background(AccentSoft)
                    .clickable(onClick = onNewGraph).padding(vertical = 12.dp),
                contentAlignment = Alignment.Center
            ) { Text("＋ 새 그래프", color = AccentDark, fontSize = 12.sp, fontWeight = FontWeight.Black) }
        }
        Column(modifier = Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 10.dp)) {
            NavLabel("메뉴")
            NavItem("⌘", "그래프 편집", "직접 노드와 연결 만들기", state.mainView == MainView.GRAPH) { onView(MainView.GRAPH) }
            NavItem("☷", "목록 보기", "노드를 텍스트로 확인", state.mainView == MainView.LIST) { onView(MainView.LIST) }
            NavItem("✓", "실행 계획", "할 일과 순서 정리", state.mainView == MainView.PLAN) { onView(MainView.PLAN) }

            NavLabel("최근 그래프")
            state.recentGraphs.forEach { g ->
                RecentItem(g, g.id == state.snapshot.meta.id) { onOpenGraph(g.id) }
            }

            Box(
                modifier = Modifier
                    .fillMaxWidth().padding(vertical = 10.dp)
                    .clip(RoundedCornerShape(14.dp)).background(GreenSoft).padding(12.dp)
            ) {
                Text(
                    "그래프와 설정은 기본적으로 기기에 저장됩니다. AI 기능은 꺼져 있으며, 직접 켜고 실행한 경우에만 선택한 내용이 전송됩니다.",
                    color = Color(0xFF4F765F), fontSize = 10.sp
                )
            }
        }
        Box(modifier = Modifier.fillMaxWidth().border(1.dp, Line, RoundedCornerShape(0.dp)).padding(10.dp)) {
            NavItem("⚙", "설정", "API 키 · 저장 · 화면", false, onSettings)
        }
    }
}

@Composable
private fun NavLabel(text: String) {
    Text(text, color = Muted, fontSize = 9.sp, fontWeight = FontWeight.Black,
        modifier = Modifier.padding(start = 8.dp, top = 12.dp, bottom = 6.dp))
}

@Composable
private fun NavItem(icon: String, name: String, meta: String, active: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth().padding(bottom = 4.dp)
            .clip(RoundedCornerShape(13.dp))
            .background(if (active) Color(0xFFFFF6F1) else Color.Transparent)
            .border(1.dp, if (active) Color(0xFFF1C8BB) else Color.Transparent, RoundedCornerShape(13.dp))
            .clickable(onClick = onClick)
            .padding(11.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(icon, fontSize = 15.sp, modifier = Modifier.width(24.dp))
        Column(modifier = Modifier.padding(start = 8.dp)) {
            Text(name, fontSize = 12.sp, fontWeight = FontWeight.Black)
            Text(meta, color = Muted, fontSize = 9.sp)
        }
    }
}

@Composable
private fun RecentItem(g: GraphMeta, active: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth().padding(bottom = 4.dp)
            .clip(RoundedCornerShape(13.dp))
            .background(if (active) Color(0xFFFFF6F1) else Color.Transparent)
            .clickable(onClick = onClick)
            .padding(11.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text("●", color = Accent, fontSize = 12.sp, modifier = Modifier.width(24.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(g.title.ifBlank { "제목 없음" }, fontSize = 12.sp, fontWeight = FontWeight.Black)
            Text("노드 ${g.nodeCount}개", color = Muted, fontSize = 9.sp)
        }
        Text("${g.nodeCount}", color = Muted, fontSize = 9.sp)
    }
}

@Composable
fun BottomNav(
    current: MainView,
    modifier: Modifier = Modifier,
    onGraph: () -> Unit,
    onTools: () -> Unit,
    onExport: () -> Unit,
    onSettings: () -> Unit
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(Panel)
            .border(1.dp, Line, RoundedCornerShape(18.dp))
            .padding(5.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        BottomItem("⌘", "그래프", current == MainView.GRAPH, Modifier.weight(1f), onGraph)
        BottomItem("◇", "도구", false, Modifier.weight(1f), onTools)
        BottomItem("⇧", "내보내기", false, Modifier.weight(1f), onExport)
        BottomItem("⚙", "설정", false, Modifier.weight(1f), onSettings)
    }
}

@Composable
private fun BottomItem(icon: String, label: String, active: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(13.dp))
            .background(if (active) AccentSoft else Color.Transparent)
            .clickable(onClick = onClick)
            .padding(vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(icon, fontSize = 16.sp, color = if (active) AccentDark else Muted)
        Text(label, fontSize = 9.sp, fontWeight = FontWeight.Black, color = if (active) AccentDark else Muted)
    }
}

@Composable
fun ZoomControls(
    zoom: Float,
    onZoomIn: () -> Unit,
    onZoomOut: () -> Unit,
    onFit: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(Panel)
            .border(1.dp, Line, RoundedCornerShape(14.dp))
            .padding(4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        ZoomBtn("−", onZoomOut)
        Text("${(zoom * 100).toInt()}%", color = Muted, fontSize = 9.sp, fontWeight = FontWeight.Black,
            modifier = Modifier.width(40.dp), )
        ZoomBtn("＋", onZoomIn)
        ZoomBtn("⌗", onFit)
    }
}

@Composable
private fun ZoomBtn(label: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier.size(30.dp).clip(RoundedCornerShape(9.dp)).clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) { Text(label, color = Muted, fontWeight = FontWeight.Black) }
}

@Composable
fun QuickInput(
    text: String,
    type: NodeType,
    onText: (String) -> Unit,
    onCycleType: () -> Unit,
    onAdd: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Panel)
            .border(1.dp, Line, RoundedCornerShape(16.dp))
            .padding(start = 15.dp, top = 8.dp, bottom = 8.dp, end = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        BasicTextField(
            value = text,
            onValueChange = onText,
            singleLine = true,
            textStyle = TextStyle(fontSize = 13.sp, color = TextMain),
            modifier = Modifier.weight(1f),
            decorationBox = { inner ->
                if (text.isEmpty()) Text("떠오른 생각을 바로 적으세요", color = Muted, fontSize = 13.sp)
                inner()
            }
        )
        Box(
            modifier = Modifier.size(38.dp).clip(RoundedCornerShape(12.dp)).background(Panel2).clickable(onClick = onCycleType),
            contentAlignment = Alignment.Center
        ) { Text(type.label.take(2), fontSize = 9.sp, fontWeight = FontWeight.Black, color = Muted) }
        Spacer(Modifier.width(8.dp))
        Box(
            modifier = Modifier.size(38.dp).clip(RoundedCornerShape(12.dp)).background(Accent).clickable(onClick = onAdd),
            contentAlignment = Alignment.Center
        ) { Icon(Icons.Filled.Add, contentDescription = "노드 추가", tint = Color.White) }
    }
}
