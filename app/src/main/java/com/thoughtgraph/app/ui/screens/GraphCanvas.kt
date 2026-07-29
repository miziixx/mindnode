package com.thoughtgraph.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.thoughtgraph.app.data.GraphSnapshot
import com.thoughtgraph.app.data.Node
import com.thoughtgraph.app.ui.theme.Accent
import com.thoughtgraph.app.ui.theme.Line
import com.thoughtgraph.app.ui.theme.Muted
import com.thoughtgraph.app.ui.theme.Panel
import com.thoughtgraph.app.ui.theme.Purple

/**
 * Pannable, zoomable graph canvas. Node coordinates are stored in graph space;
 * the whole stage is translated by [pan] and scaled by [zoom].
 */
@Composable
fun GraphCanvas(
    snapshot: GraphSnapshot,
    selectedNodeId: String?,
    zoom: Float,
    pan: Offset,
    connectingFromId: String?,
    onZoomPan: (Float, Offset) -> Unit,
    onSelect: (String) -> Unit,
    onMove: (String, Float, Float, Boolean) -> Unit,
    onTapNodeWhileConnecting: (String) -> Unit,
    onOpenNode: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    var localZoom by remember(zoom) { mutableFloatStateOf(zoom) }
    var localPan by remember(pan) { mutableStateOf(pan) }

    Box(
        modifier = modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(24.dp))
            .background(Color(0xFFFAF7F0))
            .pointerInput(Unit) {
                detectDragGestures(
                    onDrag = { change, drag ->
                        change.consume()
                        localPan += drag
                        onZoomPan(localZoom, localPan)
                    }
                )
            }
    ) {
        // Connections layer
        androidx.compose.foundation.Canvas(modifier = Modifier.fillMaxSize()) {
            val byId = snapshot.nodes.associateBy { it.id }
            val dashed = PathEffect.dashPathEffect(floatArrayOf(14f, 16f))
            snapshot.edges.forEach { e ->
                val a = byId[e.sourceNodeId]
                val b = byId[e.targetNodeId]
                if (a != null && b != null) {
                    val start = Offset(a.x * localZoom + localPan.x + 94, a.y * localZoom + localPan.y + 47)
                    val end = Offset(b.x * localZoom + localPan.x + 94, b.y * localZoom + localPan.y + 47)
                    drawLine(
                        color = Color(0xFFC7BAA9),
                        start = start,
                        end = end,
                        strokeWidth = 2.5f,
                        pathEffect = dashed
                    )
                }
            }
        }

        // Nodes layer
        snapshot.nodes.forEach { node ->
            NodeCard(
                node = node,
                selected = node.id == selectedNodeId,
                connecting = connectingFromId != null,
                zoom = localZoom,
                pan = localPan,
                onSelect = {
                    if (connectingFromId != null) onTapNodeWhileConnecting(node.id)
                    else onSelect(node.id)
                },
                onMove = onMove,
                onOpen = { onOpenNode(node.id) }
            )
        }
    }
}

@Composable
private fun NodeCard(
    node: Node,
    selected: Boolean,
    connecting: Boolean,
    zoom: Float,
    pan: Offset,
    onSelect: () -> Unit,
    onMove: (String, Float, Float, Boolean) -> Unit,
    onOpen: () -> Unit
) {
    val accent = Color(node.type.accent)
    val bg = when {
        node.isDraft -> Purple.copy(alpha = 0.12f)
        node.type == com.thoughtgraph.app.data.NodeType.CENTRAL -> Color(0xFFFFF5EF)
        else -> Panel
    }
    Box(
        modifier = Modifier
            .absoluteOffsetPx(node.x * zoom + pan.x, node.y * zoom + pan.y)
            .width(188.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(if (node.isDraft) bg else bg.copy(alpha = 0.98f))
            .border(
                width = if (selected) 2.dp else 1.dp,
                color = if (selected) Accent else Line,
                shape = RoundedCornerShape(16.dp)
            )
            .pointerInput(node.id, connecting) {
                detectTapGestures(
                    onTap = { onSelect() },
                    onDoubleTap = { onOpen() }
                )
            }
            .pointerInput(node.id, zoom) {
                detectDragGestures(
                    onDragStart = { onSelect() },
                    onDrag = { change, drag ->
                        change.consume()
                        onMove(node.id, node.x + drag.x / zoom, node.y + drag.y / zoom, false)
                    },
                    onDragEnd = { onMove(node.id, node.x, node.y, true) }
                )
            }
            .padding(13.dp)
            .alpha(if (node.isDraft) 0.72f else 1f)
    ) {
        Column {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(999.dp))
                    .background(accent.copy(alpha = 0.10f))
                    .padding(horizontal = 7.dp, vertical = 4.dp)
            ) {
                Text(
                    text = if (node.isDraft) "보조 제안" else node.type.label,
                    color = accent,
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Black
                )
            }
            Text(
                text = node.title.ifBlank { "제목 없음" },
                fontSize = 13.sp,
                fontWeight = FontWeight.Black,
                modifier = Modifier.padding(top = 8.dp)
            )
            if (node.description.isNotBlank()) {
                Text(
                    text = node.description,
                    color = Muted,
                    fontSize = 10.sp,
                    modifier = Modifier.padding(top = 5.dp)
                )
            }
        }
    }
}

// ---- tiny modifiers ----

private fun Modifier.absoluteOffsetPx(x: Float, y: Float): Modifier =
    this.then(androidx.compose.foundation.layout.offset {
        androidx.compose.ui.unit.IntOffset(x.toInt(), y.toInt())
    })

private fun Modifier.alpha(value: Float): Modifier =
    this.then(androidx.compose.ui.draw.alpha(value))
