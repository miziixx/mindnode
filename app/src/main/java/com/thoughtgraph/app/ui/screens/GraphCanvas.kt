package com.thoughtgraph.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.thoughtgraph.app.data.GraphSnapshot
import com.thoughtgraph.app.data.Node
import com.thoughtgraph.app.ui.theme.Accent
import com.thoughtgraph.app.ui.theme.Line
import com.thoughtgraph.app.ui.theme.Muted
import com.thoughtgraph.app.ui.theme.Panel
import com.thoughtgraph.app.ui.theme.Purple

private const val NODE_W_DP = 188f
private const val NODE_H_DP = 96f

/**
 * Pannable, zoomable graph canvas with full touch handling:
 *  - empty single tap: clear selection
 *  - empty double tap: add a node at that point
 *  - two-finger pinch / drag: zoom + pan the canvas
 *  - node tap: select · node double tap: open editor · node long-press: context menu
 *  - node drag: move (node events are consumed so the canvas does not pan)
 *  - drag the selected node's connection handle onto another node: connect them
 */
@Composable
fun GraphCanvas(
    snapshot: GraphSnapshot,
    selectedNodeId: String?,
    zoom: Float,
    pan: Offset,
    onZoomPan: (Float, Offset) -> Unit,
    onSelect: (String) -> Unit,
    onClearSelection: () -> Unit,
    onMove: (String, Float, Float, Boolean) -> Unit,
    onAddNodeAt: (Float, Float) -> Unit,
    onOpenNode: (String) -> Unit,
    onNodeMenu: (String) -> Unit,
    onConnect: (String, String) -> Unit,
    showMiniMap: Boolean = false,
    modifier: Modifier = Modifier
) {
    val density = LocalDensity.current
    val nodeWpx = with(density) { NODE_W_DP.dp.toPx() }
    val nodeHpx = with(density) { NODE_H_DP.dp.toPx() }
    var canvasSize by remember { mutableStateOf(androidx.compose.ui.unit.IntSize.Zero) }

    // Live connection-drag state (screen-space endpoint of the in-progress link).
    var linkFrom by remember { mutableStateOf<String?>(null) }
    var linkTo by remember { mutableStateOf<Offset?>(null) }

    fun nodeCenterScreen(n: Node) = Offset(n.x * zoom + pan.x + nodeWpx / 2f, n.y * zoom + pan.y + nodeHpx / 2f)

    fun nodeAt(screen: Offset): Node? = snapshot.nodes.lastOrNull { n ->
        val left = n.x * zoom + pan.x
        val top = n.y * zoom + pan.y
        screen.x in left..(left + nodeWpx) && screen.y in top..(top + nodeHpx)
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(24.dp))
            .background(Color(0xFFFAF7F0))
            .onSizeChanged { canvasSize = it }
            // Tap on empty space: single = clear, double = add node at point (graph coords).
            .pointerInput(zoom, pan) {
                detectTapGestures(
                    onTap = { onClearSelection() },
                    onDoubleTap = { pos ->
                        onAddNodeAt((pos.x - pan.x) / zoom, (pos.y - pan.y) / zoom)
                    }
                )
            }
            // Two-finger pinch to zoom and drag to pan the whole stage.
            .pointerInput(Unit) {
                detectTransformGestures { _, panChange, zoomChange, _ ->
                    val newZoom = (zoom * zoomChange).coerceIn(0.4f, 1.8f)
                    onZoomPan(newZoom, pan + panChange)
                }
            }
    ) {
        // Connections (dashed bezier curves, matching the prototype) + in-progress link.
        androidx.compose.foundation.Canvas(modifier = Modifier.fillMaxSize()) {
            val byId = snapshot.nodes.associateBy { it.id }
            val dashed = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(14f, 16f))
            snapshot.edges.forEach { e ->
                val a = byId[e.sourceNodeId]
                val b = byId[e.targetNodeId]
                if (a != null && b != null) {
                    val s = nodeCenterScreen(a)
                    val t = nodeCenterScreen(b)
                    val dx = (t.x - s.x) * 0.45f
                    val path = androidx.compose.ui.graphics.Path().apply {
                        moveTo(s.x, s.y)
                        cubicTo(s.x + dx, s.y, t.x - dx, t.y, t.x, t.y)
                    }
                    drawPath(
                        path = path,
                        color = Color(0xFFC7BAA9),
                        style = androidx.compose.ui.graphics.drawscope.Stroke(width = 2.5f, pathEffect = dashed)
                    )
                }
            }
            val from = linkFrom?.let { byId[it] }
            val to = linkTo
            if (from != null && to != null) {
                drawLine(color = Accent, start = nodeCenterScreen(from), end = to, strokeWidth = 3f)
            }
        }

        // Nodes.
        snapshot.nodes.forEach { node ->
            NodeCard(
                node = node,
                selected = node.id == selectedNodeId,
                zoom = zoom,
                pan = pan,
                onSelect = { onSelect(node.id) },
                onOpen = { onOpenNode(node.id) },
                onMenu = { onNodeMenu(node.id) },
                onMove = onMove
            )
        }

        // Connection handle on the selected node.
        val selected = snapshot.nodes.firstOrNull { it.id == selectedNodeId }
        if (selected != null) {
            val handleX = selected.x * zoom + pan.x + nodeWpx - with(density) { 6.dp.toPx() }
            val handleY = selected.y * zoom + pan.y + nodeHpx / 2f - with(density) { 12.dp.toPx() }
            Box(
                modifier = Modifier
                    .offset { IntOffset(handleX.toInt(), handleY.toInt()) }
                    .size(28.dp) // >= 24dp touch target
                    .pointerInput(selected.id, zoom, pan) {
                        detectDragGestures(
                            onDragStart = {
                                linkFrom = selected.id
                                linkTo = nodeCenterScreen(selected)
                            },
                            onDrag = { change, _ ->
                                change.consume()
                                linkTo = change.position + Offset(handleX, handleY)
                            },
                            onDragEnd = {
                                val target = linkTo?.let { nodeAt(it) }
                                if (target != null && target.id != selected.id) onConnect(selected.id, target.id)
                                linkFrom = null; linkTo = null
                            },
                            onDragCancel = { linkFrom = null; linkTo = null }
                        )
                    },
                contentAlignment = Alignment.Center
            ) {
                Box(
                    modifier = Modifier.size(14.dp).clip(RoundedCornerShape(50))
                        .background(Panel).border(3.dp, Accent, RoundedCornerShape(50))
                )
            }
        }

        if (showMiniMap && canvasSize.width > 0 && canvasSize.height > 0) {
            MiniMap(
                nodes = snapshot.nodes,
                zoom = zoom,
                pan = pan,
                canvasW = canvasSize.width.toFloat(),
                canvasH = canvasSize.height.toFloat(),
                modifier = Modifier.align(Alignment.BottomEnd).padding(12.dp)
            )
        }
    }
}

@Composable
private fun MiniMap(
    nodes: List<Node>,
    zoom: Float,
    pan: Offset,
    canvasW: Float,
    canvasH: Float,
    modifier: Modifier = Modifier
) {
    if (nodes.isEmpty()) return
    val minX = nodes.minOf { it.x }
    val minY = nodes.minOf { it.y }
    val maxX = nodes.maxOf { it.x } + NODE_W_DP
    val maxY = nodes.maxOf { it.y } + NODE_H_DP
    val spanX = (maxX - minX).coerceAtLeast(1f)
    val spanY = (maxY - minY).coerceAtLeast(1f)
    Box(
        modifier = modifier
            .size(width = 108.dp, height = 73.dp)
            .clip(RoundedCornerShape(13.dp))
            .background(Color(0xF5FFFDF8))
            .border(1.dp, Line, RoundedCornerShape(13.dp))
    ) {
        androidx.compose.foundation.Canvas(modifier = Modifier.fillMaxSize().padding(6.dp)) {
            val s = minOf(size.width / spanX, size.height / spanY)
            fun mx(gx: Float) = (gx - minX) * s
            fun my(gy: Float) = (gy - minY) * s
            nodes.forEach { n ->
                drawRect(
                    color = Color(n.type.accent).copy(alpha = 0.85f),
                    topLeft = Offset(mx(n.x), my(n.y)),
                    size = androidx.compose.ui.geometry.Size((NODE_W_DP * s).coerceAtLeast(3f), (NODE_H_DP * s).coerceAtLeast(2f))
                )
            }
            val vpLeft = (-pan.x) / zoom
            val vpTop = (-pan.y) / zoom
            val vpW = (canvasW / zoom)
            val vpH = (canvasH / zoom)
            drawRect(
                color = Accent,
                topLeft = Offset(mx(vpLeft), my(vpTop)),
                size = androidx.compose.ui.geometry.Size(vpW * s, vpH * s),
                style = androidx.compose.ui.graphics.drawscope.Stroke(width = 2f)
            )
        }
    }
}

@Composable
private fun NodeCard(
    node: Node,
    selected: Boolean,
    zoom: Float,
    pan: Offset,
    onSelect: () -> Unit,
    onOpen: () -> Unit,
    onMenu: () -> Unit,
    onMove: (String, Float, Float, Boolean) -> Unit
) {
    val accent = Color(node.type.accent)
    val bg = when {
        node.isDraft -> Purple.copy(alpha = 0.12f)
        node.type == com.thoughtgraph.app.data.NodeType.CENTRAL -> Color(0xFFFFF5EF)
        else -> Panel
    }
    Box(
        modifier = Modifier
            .offset { IntOffset((node.x * zoom + pan.x).toInt(), (node.y * zoom + pan.y).toInt()) }
            .width(NODE_W_DP.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(bg)
            .border(
                width = if (selected) 2.dp else 1.dp,
                color = if (selected) Accent else Line,
                shape = RoundedCornerShape(16.dp)
            )
            .pointerInput(node.id) {
                detectTapGestures(
                    onTap = { onSelect() },
                    onDoubleTap = { onOpen() },
                    onLongPress = { onMenu() }
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
                modifier = Modifier.clip(RoundedCornerShape(999.dp))
                    .background(accent.copy(alpha = 0.10f)).padding(horizontal = 7.dp, vertical = 4.dp)
            ) {
                Text(if (node.isDraft) "보조 제안" else node.type.label, color = accent, fontSize = 9.sp, fontWeight = FontWeight.Black)
            }
            Text(node.title.ifBlank { "제목 없음" }, fontSize = 13.sp, fontWeight = FontWeight.Black, modifier = Modifier.padding(top = 8.dp))
            if (node.description.isNotBlank()) {
                Text(node.description, color = Muted, fontSize = 10.sp, modifier = Modifier.padding(top = 5.dp))
            }
        }
    }
}
