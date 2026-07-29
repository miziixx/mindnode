package com.thoughtgraph.app.exportimport

import com.thoughtgraph.app.data.Edge
import com.thoughtgraph.app.data.GraphMeta
import com.thoughtgraph.app.data.GraphSnapshot
import com.thoughtgraph.app.data.Importance
import com.thoughtgraph.app.data.Node
import com.thoughtgraph.app.data.NodeStatus
import com.thoughtgraph.app.data.NodeType
import org.json.JSONArray
import org.json.JSONObject

/**
 * Pure serialization for export/import and backup. Contains no Android or
 * network dependencies so it is fully unit-testable.
 *
 * NOTE: API keys are intentionally never part of any exported payload or backup.
 */
object GraphSerializer {

    const val FORMAT_VERSION = 1

    // ---- JSON (single graph) ----

    fun toJson(snapshot: GraphSnapshot): String = graphObject(snapshot).toString(2)

    private fun graphObject(snapshot: GraphSnapshot): JSONObject {
        val obj = JSONObject()
        obj.put("formatVersion", FORMAT_VERSION)
        obj.put("id", snapshot.meta.id)
        obj.put("title", snapshot.meta.title)
        obj.put("createdAt", snapshot.meta.createdAt)
        obj.put("updatedAt", snapshot.meta.updatedAt)
        val nodes = JSONArray()
        snapshot.nodes.filterNot { it.isDraft }.forEach { nodes.put(nodeObject(it)) }
        obj.put("nodes", nodes)
        val edges = JSONArray()
        snapshot.edges.forEach { edges.put(edgeObject(it)) }
        obj.put("edges", edges)
        return obj
    }

    private fun nodeObject(n: Node) = JSONObject().apply {
        put("id", n.id)
        put("graphId", n.graphId)
        put("title", n.title)
        put("description", n.description)
        put("type", n.type.name)
        put("status", n.status.name)
        put("importance", n.importance.name)
        put("dueAt", n.dueAt ?: JSONObject.NULL)
        put("estimatedMinutes", n.estimatedMinutes ?: JSONObject.NULL)
        put("x", n.x.toDouble())
        put("y", n.y.toDouble())
        put("createdAt", n.createdAt)
        put("updatedAt", n.updatedAt)
    }

    private fun edgeObject(e: Edge) = JSONObject().apply {
        put("id", e.id)
        put("graphId", e.graphId)
        put("sourceNodeId", e.sourceNodeId)
        put("targetNodeId", e.targetNodeId)
        put("relationType", e.relationType)
        put("label", e.label)
        put("createdAt", e.createdAt)
    }

    /**
     * Parses a single-graph JSON export. Throws [ImportException] on malformed
     * input so callers can show a clear error instead of crashing.
     */
    fun fromJson(text: String): GraphSnapshot {
        try {
            val obj = JSONObject(text)
            return parseGraphObject(obj)
        } catch (e: ImportException) {
            throw e
        } catch (e: Exception) {
            throw ImportException("JSON 형식이 올바르지 않습니다.", e)
        }
    }

    private fun parseGraphObject(obj: JSONObject): GraphSnapshot {
        if (!obj.has("nodes")) throw ImportException("노드 정보가 없는 파일입니다.")
        val meta = GraphMeta(
            id = obj.optString("id").ifEmpty { java.util.UUID.randomUUID().toString() },
            title = obj.optString("title", "가져온 그래프"),
            createdAt = obj.optLong("createdAt", System.currentTimeMillis()),
            updatedAt = obj.optLong("updatedAt", System.currentTimeMillis())
        )
        val nodes = ArrayList<Node>()
        val nodesArr = obj.getJSONArray("nodes")
        for (i in 0 until nodesArr.length()) {
            val o = nodesArr.getJSONObject(i)
            nodes.add(
                Node(
                    id = o.optString("id").ifEmpty { java.util.UUID.randomUUID().toString() },
                    graphId = meta.id,
                    title = o.optString("title"),
                    description = o.optString("description"),
                    type = NodeType.fromName(o.optString("type")),
                    status = NodeStatus.fromName(o.optString("status")),
                    importance = Importance.fromName(o.optString("importance")),
                    dueAt = if (o.isNull("dueAt")) null else o.optLong("dueAt"),
                    estimatedMinutes = if (o.isNull("estimatedMinutes")) null else o.optInt("estimatedMinutes"),
                    x = o.optDouble("x", 0.0).toFloat(),
                    y = o.optDouble("y", 0.0).toFloat(),
                    createdAt = o.optLong("createdAt", System.currentTimeMillis()),
                    updatedAt = o.optLong("updatedAt", System.currentTimeMillis())
                )
            )
        }
        val edges = ArrayList<Edge>()
        val edgesArr = obj.optJSONArray("edges") ?: JSONArray()
        val nodeIds = nodes.map { it.id }.toHashSet()
        for (i in 0 until edgesArr.length()) {
            val o = edgesArr.getJSONObject(i)
            val src = o.optString("sourceNodeId")
            val tgt = o.optString("targetNodeId")
            if (src !in nodeIds || tgt !in nodeIds) continue
            edges.add(
                Edge(
                    id = o.optString("id").ifEmpty { java.util.UUID.randomUUID().toString() },
                    graphId = meta.id,
                    sourceNodeId = src,
                    targetNodeId = tgt,
                    relationType = o.optString("relationType", "관계"),
                    label = o.optString("label"),
                    createdAt = o.optLong("createdAt", System.currentTimeMillis())
                )
            )
        }
        return GraphSnapshot(meta.copy(nodeCount = nodes.size), nodes, edges)
    }

    // ---- Full backup (all graphs) ----

    fun backup(graphs: List<GraphSnapshot>): String {
        val root = JSONObject()
        root.put("formatVersion", FORMAT_VERSION)
        root.put("kind", "thoughtgraph-backup")
        root.put("exportedAt", System.currentTimeMillis())
        val arr = JSONArray()
        graphs.forEach { arr.put(graphObject(it)) }
        root.put("graphs", arr)
        return root.toString(2)
    }

    fun restore(text: String): List<GraphSnapshot> {
        try {
            val root = JSONObject(text)
            if (root.optString("kind") != "thoughtgraph-backup") {
                // Allow a bare single-graph file to be restored too.
                if (root.has("nodes")) return listOf(parseGraphObject(root))
                throw ImportException("백업 파일이 아닙니다.")
            }
            val arr = root.getJSONArray("graphs")
            val out = ArrayList<GraphSnapshot>()
            for (i in 0 until arr.length()) out.add(parseGraphObject(arr.getJSONObject(i)))
            return out
        } catch (e: ImportException) {
            throw e
        } catch (e: Exception) {
            throw ImportException("백업 파일을 읽을 수 없습니다.", e)
        }
    }

    // ---- Markdown ----

    fun toMarkdown(snapshot: GraphSnapshot): String {
        val sb = StringBuilder()
        sb.append("# ${snapshot.meta.title}\n\n")
        val nodes = snapshot.nodes.filterNot { it.isDraft }
        val byId = nodes.associateBy { it.id }
        nodes.forEach { n ->
            sb.append("- **${n.title}** · ${n.type.label}")
            if (n.type == NodeType.TASK) sb.append(" · ${n.status.label}")
            sb.append("\n")
            if (n.description.isNotBlank()) sb.append("  - ${n.description}\n")
            snapshot.edges.filter { it.sourceNodeId == n.id }.forEach { e ->
                byId[e.targetNodeId]?.let { child ->
                    val rel = if (e.label.isNotBlank()) e.label else e.relationType
                    sb.append("  - → ${child.title} (${rel})\n")
                }
            }
        }
        return sb.toString()
    }

    // ---- AI hand-off context (copied to clipboard, never auto-sent) ----

    fun toAiContext(snapshot: GraphSnapshot, selected: List<Node>): String {
        val sb = StringBuilder()
        sb.append("[프로젝트]\n${snapshot.meta.title}\n\n")
        val nodes = (if (selected.isNotEmpty()) selected else snapshot.nodes)
            .filterNot { it.isDraft }
        sb.append("[정리된 노드]\n")
        nodes.forEach { n ->
            sb.append("- ${n.type.label}: ${n.title} — ${n.description}\n")
        }
        sb.append("\n[요청]\n위 구조를 유지하면서 필요한 작업을 수행해줘.")
        return sb.toString()
    }

    class ImportException(message: String, cause: Throwable? = null) : Exception(message, cause)
}
