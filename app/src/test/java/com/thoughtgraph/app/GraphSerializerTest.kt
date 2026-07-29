package com.thoughtgraph.app

import com.thoughtgraph.app.data.Edge
import com.thoughtgraph.app.data.GraphMeta
import com.thoughtgraph.app.data.GraphSnapshot
import com.thoughtgraph.app.data.Importance
import com.thoughtgraph.app.data.Node
import com.thoughtgraph.app.data.NodeStatus
import com.thoughtgraph.app.data.NodeType
import com.thoughtgraph.app.exportimport.GraphSerializer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class GraphSerializerTest {

    private fun sample(): GraphSnapshot {
        val gid = "graph-1"
        val a = Node(id = "n1", graphId = gid, title = "중심", type = NodeType.CENTRAL, x = 10f, y = 20f, importance = Importance.HIGH)
        val b = Node(id = "n2", graphId = gid, title = "할 일", type = NodeType.TASK, status = NodeStatus.TODO, estimatedMinutes = 30)
        val e = Edge(id = "e1", graphId = gid, sourceNodeId = "n1", targetNodeId = "n2", relationType = "할 일")
        return GraphSnapshot(GraphMeta(id = gid, title = "테스트"), listOf(a, b), listOf(e))
    }

    @Test
    fun jsonRoundTrip_preservesNodesAndEdges() {
        val original = sample()
        val json = GraphSerializer.toJson(original)
        val restored = GraphSerializer.fromJson(json)
        assertEquals(original.nodes.size, restored.nodes.size)
        assertEquals(original.edges.size, restored.edges.size)
        assertEquals("중심", restored.nodes.first { it.id == "n1" }.title)
        assertEquals(NodeType.TASK, restored.nodes.first { it.id == "n2" }.type)
    }

    @Test
    fun draftNodes_areNeverExported() {
        val gid = "g"
        val real = Node(id = "r", graphId = gid, title = "실제")
        val draft = Node(id = "d", graphId = gid, title = "임시", isDraft = true)
        val snap = GraphSnapshot(GraphMeta(id = gid, title = "t"), listOf(real, draft), emptyList())
        val restored = GraphSerializer.fromJson(GraphSerializer.toJson(snap))
        assertEquals(1, restored.nodes.size)
        assertEquals("실제", restored.nodes.first().title)
    }

    @Test
    fun backupRestore_roundTripsMultipleGraphs() {
        val g1 = sample()
        val g2 = sample().let { it.copy(meta = it.meta.copy(id = "graph-2", title = "둘째")) }
        val backup = GraphSerializer.backup(listOf(g1, g2))
        val restored = GraphSerializer.restore(backup)
        assertEquals(2, restored.size)
    }

    @Test
    fun invalidJson_throwsImportException() {
        assertThrows(GraphSerializer.ImportException::class.java) {
            GraphSerializer.fromJson("not json at all")
        }
    }

    @Test
    fun markdown_containsTitleAndNodes() {
        val md = GraphSerializer.toMarkdown(sample())
        assertTrue(md.contains("# 테스트"))
        assertTrue(md.contains("중심"))
        assertTrue(md.contains("할 일"))
    }

    @Test
    fun aiContext_withSelection_onlyIncludesSelected() {
        val snap = sample()
        val selected = listOf(snap.nodes.first { it.id == "n1" })
        val ctx = GraphSerializer.toAiContext(snap, selected)
        assertTrue(ctx.contains("중심"))
        assertTrue(!ctx.contains("할 일"))
    }

    @Test
    fun edgesReferencingMissingNodes_areDropped() {
        val json = """
            { "id":"g", "title":"t",
              "nodes":[{"id":"n1","title":"a","type":"IDEA"}],
              "edges":[{"id":"e","sourceNodeId":"n1","targetNodeId":"missing"}] }
        """.trimIndent()
        val restored = GraphSerializer.fromJson(json)
        assertEquals(0, restored.edges.size)
    }
}
