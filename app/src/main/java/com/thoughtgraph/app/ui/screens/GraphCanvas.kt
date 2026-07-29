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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.thoughtgraph.app.data.GraphSnapshot
import com.thoughtgraph.app.data.Node
import com.thoughtgraph.app.ui.theme.Accent
import com.thoughtgraph.app.ui.theme.Line
import com.thoughtgraph.app.ui.theme.Muted
import com.thoughtgraph.app.ui.theme.Panel
import com.thoughtgraph.app.ui.theme.Purple

private const val NODE_W_DP = 150f
private const val NODE_H_DP = 80f

/**
 * Pannable, zoomable graph canvas.
 *
 * The nodes + handles live inside a single "stage" that is scaled and translated
 * as one unit via [graphicsLayer] (like the prototype's `transform: scale`), so
 * zooming actually resizes the cards and their touch targets together. Connection
 * lines are drawn in screen space so they never get clipped by the stage bounds.
 *
 * Touch model: empty tap = clear, empty double-tap = add node, pinch = zoom,
 * one/two-finger drag = pan, node tap = select, double-tap = edit, long-press =
 * menu, node drag = move, selected node's handle drag onto another = connect.
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
    fitRequest: Int = 0,
    modifier: Modifier = Modifier
) {
    val density = LocalDensity.current
    val nodeWpx = with(density) { NODE_W_DP.dp.toPx() }
    val nodeHpx = with(density) { NODE_H_DP.dp.toPx() }
    var canvasSize by remember { mutableStateOf(IntSize.Zero) }

    val curZoom by rememberUpdatedState(zoom)
    val curPan by rememberUpdatedState(pan)

    var linkFrom by remember { mutableStateOf<String?>(null) }
    var linkTo by remember { mutableStateOf<Offset?>(null) }

    // Screen-space centre of a node (stage transform = pos*zoom + pan, origin top-left).
    fun centerScreen(n: Node) = Offset(n.x * zoom + pan.x + nodeWpx * zoom / 2f, n.y * zoom + pan.y + nodeHpx * zoom / 2f)
    fun nodeAtScreen(p: Offset): Node? = snapshot.nodes.lastOrNull { n ->
        val l = n.x * zoom + pan.x; val t = n.y * zoom + pan.y
        p.x in l..(l + nodeWpx * zoom) && p.y in t..(t + nodeHpx * zoom)
    }

    // Auto-fit the whole graph into view on graph change / size change / fit press.
    LaunchedEffect(snapshot.meta.id, canvasSize, fitRequest) {
        val live = snapshot.nodes.filterNot { it.isDraft }
        if (canvasSize.width > 0 && live.isNotEmpty()) {
            val minX = live.minOf { it.x }
            val minY = live.minOf { it.y }
            val maxX = live.maxOf { it.x } + nodeWpx
            val maxY = live.maxOf { it.y } + nodeHpx
            val cw = canvasSize.width.toFloat()
            val ch = canvasSize.height.toFloat()
            val z = (minOf(cw / (maxX - minX), ch / (maxY - minY)) * 0.82f).coerceIn(0.3f, 0.85f)
            val px = (cw - (maxX - minX) * z) / 2f - minX * z
            val py = (ch - (maxY - minY) * z) / 2f - minY * z
            onZoomPan(z, Offset(px, py))
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(24.dp))
            .background(Color(0xFFFAF7F0))
            .onSizeChanged { canvasSize = it }
            .pointerInput(Unit) {
                detectTransformGestures { centroid, panChange, zoomChange, _ ->
                    val z = curZoom
                    val nz = (z * zoomChange).coerceIn(0.35f, 1.8f)
                    val adjusted = curPan + (centroid - centroid * (nz / z)) + panChange
                    onZoomPan(nz, adjusted)
                }
            }
            .pointerInput(Unit) {
                detectTapGestures(
                    onTap = { onClearSelection() },
                    onDoubleTap = { pos -> onAddNodeAt((pos.x - curPan.x) / curZoom, (pos.y - curPan.y) / curZoom) }
                )
            }
    ) {
        // Connections (dashed bezier curves) in screen space.
        androidx.compose.foundation.Canvas(modifier = Modifier.fillMaxSize()) {
            val byId = snapshot.nodes.associateBy { it.id }
            val dashed = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(14f, 16f))
            snapshot.edges.forEach { e ->
                val a = byId[e.sourceNodeId]; val b = byId[e.targetNodeId]
                if (a != null && b != null) {
                    val s = centerScreen(a); val t = centerScreen(b)
                    val dx = (t.x - s.x) * 0.45f
                    val path = androidx.compose.ui.graphics.Path().apply {
                        moveTo(s.x, s.y); cubicTo(s.x + dx, s.y, t.x - dx, t.y, t.x, t.y)
                    }
                    drawPath(path, Color(0xFFC7BAA9), style = androidx.compose.ui.graphics.drawscope.Stroke(width = 2.5f, pathEffect = dashed))
                }
            }
            val from = linkFrom?.let { byId[it] }
            val to = linkTo
            if (from != null && to != null) drawLine(Accent, centerScreen(from), to, strokeWidth = 3f)
        }

        // Stage: all nodes scaled + translated as one unit.
        Box(
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer {
                    scaleX = zoom; scaleY = zoom
                    translationX = pan.x; translationY = pan.y
                    transformOrigin = TransformOrigin(0f, 0f)
                }
        ) {
            snapshot.nodes.forEach { node ->
                NodeCard(
                    node = node,
                    selected = node.id == selectedNodeId,
                    onSelect = { onSelect(node.id) },
                    onOpen = { onOpenNode(node.id) },
                    onMenu = { onNodeMenu(node.id) },
                    onMove = onMove
                )
            }
        }

        // Connection handle (screen space) for the selected node.
        val selected = snapshot.nodes.firstOrNull { it.id == selectedNodeId }
        if (selected != null) {
            val hx = selected.x * zoom + pan.x + nodeWpx * zoom - with(density) { 14.dp.toPx() }
            val hy = selected.y * zoom + pan.y + nodeHpx * zoom / 2f - with(density) { 14.dp.toPx() }
            Box(
                modifier = Modifier
                    .offset { IntOffset(hx.toInt(), hy.toInt()) }
                    .size(28.dp)
                    .pointerInput(selected.id, zoom, pan) {
                        detectDragGestures(
                            onDragStart = { linkFrom = selected.id; linkTo = centerScreen(selected) },
                            onDrag = { change, _ -> change.consume(); linkTo = change.position + Offset(hx, hy) },
                            onDragEnd = {
                                val target = linkTo?.let { nodeAtScreen(it) }
                                if (target != null && target.id != selected.id) onConnect(selected.id, target.id)
                                linkFrom = null; linkTo = null
                            },
                            onDragCancel = { linkFrom = null; linkTo = null }
                        )
                    },
                contentAlignment = Alignment.Center
            ) {
                Box(Modifier.size(14.dp).clip(RoundedCornerShape(50)).background(Panel).border(3.dp, Accent, RoundedCornerShape(50)))
            }
        }

        if (showMiniMap && canvasSize.width > 0) {
            MiniMap(
                nodes = snapshot.nodes.filterNot { it.isDraft },
                zoom = zoom, pan = pan,
                canvasW = canvasSize.width.toFloat(), canvasH = canvasSize.height.toFloat(),
                nodeWpx = nodeWpx, nodeHpx = nodeHpx,
                modifier = Modifier.align(Alignment.BottomEnd).padding(12.dp)
            )
        }
    }
}

@Composable
private fun NodeCard(
    node: Node,
    selected: Boolean,
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
    // Inside the scaled stage: absolute local coords, drag deltas are stage-local.
    Box(
        modifier = Modifier
            .offset { IntOffset(node.x.toInt(), node.y.toInt()) }
            .width(NODE_W_DP.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(bg)
            .border(if (selected) 2.dp else 1.dp, if (selected) Accent else Line, RoundedCornerShape(16.dp))
            .pointerInput(node.id) {
                detectTapGestures(onTap = { onSelect() }, onDoubleTap = { onOpen() }, onLongPress = { onMenu() })
            }
            .pointerInput(node.id) {
                detectDragGestures(
                    onDragStart = { onSelect() },
                    onDrag = { change, drag -> change.consume(); onMove(node.id, node.x + drag.x, node.y + drag.y, false) },
                    onDragEnd = { onMove(node.id, node.x, node.y, true) }
                )
            }
            .padding(10.dp)
            .alpha(if (node.isDraft) 0.72f else 1f)
    ) {
        Column {
            Box(Modifier.clip(RoundedCornerShape(999.dp)).background(accent.copy(alpha = 0.10f)).padding(horizontal = 6.dp, vertical = 3.dp)) {
                Text(if (node.isDraft) "보조 제안" else node.type.label, color = accent, fontSize = 8.sp, fontWeight = FontWeight.Black)
            }
            Text(
                node.title.ifBlank { "제목 없음" },
                fontSize = 12.sp,
                fontWeight = FontWeight.Black,
                maxLines = 2,
                overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 6.dp)
            )
            if (node.description.isNotBlank()) {
                Text(
                    node.description,
                    color = Muted,
                    fontSize = 9.sp,
                    maxLines = 2,
                    overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }
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
    nodeWpx: Float,
    nodeHpx: Float,
    modifier: Modifier = Modifier
) {
    if (nodes.isEmpty()) return
    val minX = nodes.minOf { it.x }
    val minY = nodes.minOf { it.y }
    val maxX = nodes.maxOf { it.x } + nodeWpx
    val maxY = nodes.maxOf { it.y } + nodeHpx
    val spanX = (maxX - minX).coerceAtLeast(1f)
    val spanY = (maxY - minY).coerceAtLeast(1f)
    Box(
        modifier = modifier
            .size(width = 104.dp, height = 70.dp)
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
                    size = androidx.compose.ui.geometry.Size((nodeWpx * s).coerceAtLeast(3f), (nodeHpx * s).coerceAtLeast(2f))
                )
            }
            // Visible region: screen (0,0)-(canvasW,canvasH) mapped back to graph units.
            val vpLeft = -pan.x / zoom
            val vpTop = -pan.y / zoom
            drawRect(
                color = Accent,
                topLeft = Offset(mx(vpLeft), my(vpTop)),
                size = androidx.compose.ui.geometry.Size((canvasW / zoom) * s, (canvasH / zoom) * s),
                style = androidx.compose.ui.graphics.drawscope.Stroke(width = 2f)
            )
        }
    }
}
