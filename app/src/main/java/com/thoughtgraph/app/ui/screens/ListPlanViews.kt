package com.thoughtgraph.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.thoughtgraph.app.data.GraphSnapshot
import com.thoughtgraph.app.data.Node
import com.thoughtgraph.app.data.NodeStatus
import com.thoughtgraph.app.data.NodeType
import com.thoughtgraph.app.ui.theme.Line
import com.thoughtgraph.app.ui.theme.Muted
import com.thoughtgraph.app.ui.theme.Panel

@Composable
fun ListView(
    snapshot: GraphSnapshot,
    query: String,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val nodes = snapshot.nodes
        .filterNot { it.isDraft }
        .filter { query.isBlank() || it.title.contains(query, true) || it.description.contains(query, true) }
    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(nodes, key = { it.id }) { node ->
            NodeRow(node) { onSelect(node.id) }
        }
    }
}

@Composable
private fun NodeRow(node: Node, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Panel)
            .border(1.dp, Line, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(999.dp))
                .background(Color(node.type.accent).copy(alpha = 0.12f))
                .padding(horizontal = 8.dp, vertical = 4.dp)
        ) {
            Text(node.type.label, color = Color(node.type.accent), fontSize = 9.sp, fontWeight = FontWeight.Black)
        }
        Column(modifier = Modifier.padding(start = 12.dp)) {
            Text(node.title.ifBlank { "제목 없음" }, fontWeight = FontWeight.Black, fontSize = 13.sp)
            if (node.description.isNotBlank()) {
                Text(node.description, color = Muted, fontSize = 10.sp)
            }
        }
    }
}

@Composable
fun PlanView(
    snapshot: GraphSnapshot,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val tasks = snapshot.nodes.filterNot { it.isDraft }
        .filter { it.type == NodeType.TASK || it.type == NodeType.GOAL || it.type == NodeType.STEP }
    val columns = listOf(
        NodeStatus.THOUGHT, NodeStatus.TODO, NodeStatus.IN_PROGRESS, NodeStatus.DONE
    )
    LazyColumn(
        modifier = modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        items(columns, key = { it.name }) { status ->
            val inColumn = tasks.filter { it.status == status }
            Column {
                Text("${status.label} · ${inColumn.size}", fontWeight = FontWeight.Black, fontSize = 12.sp, color = Muted)
                Column(modifier = Modifier.padding(top = 6.dp)) {
                    if (inColumn.isEmpty()) {
                        Text("항목 없음", color = Muted, fontSize = 10.sp)
                    }
                    inColumn.forEach { node ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 3.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(Panel)
                                .border(1.dp, Line, RoundedCornerShape(12.dp))
                                .clickable { onSelect(node.id) }
                                .padding(12.dp)
                        ) {
                            Column {
                                Text(node.title, fontWeight = FontWeight.Black, fontSize = 12.sp)
                                val meta = buildString {
                                    append(node.importance.label)
                                    node.estimatedMinutes?.let { append(" · ${it}분") }
                                    node.dueAt?.let { append(" · 마감 설정됨") }
                                }
                                Text(meta, color = Muted, fontSize = 9.sp)
                            }
                        }
                    }
                }
            }
        }
    }
}
