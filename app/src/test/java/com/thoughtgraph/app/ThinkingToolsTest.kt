package com.thoughtgraph.app

import com.thoughtgraph.app.data.Edge
import com.thoughtgraph.app.data.GraphMeta
import com.thoughtgraph.app.data.GraphSnapshot
import com.thoughtgraph.app.data.Node
import com.thoughtgraph.app.data.NodeStatus
import com.thoughtgraph.app.data.NodeType
import com.thoughtgraph.app.localtools.ThinkingTools
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ThinkingToolsTest {

    private val gid = "g1"

    private fun node(title: String, type: NodeType, status: NodeStatus = NodeStatus.THOUGHT, minutes: Int? = null) =
        Node(graphId = gid, title = title, type = type, status = status, estimatedMinutes = minutes)

    @Test
    fun questionTemplate_createsQuestionNodesLinkedToBase() {
        val base = node("주제", NodeType.CENTRAL)
        val (nodes, edges) = ThinkingTools.applyTemplate(ThinkingTools.Template.QUESTION, base, gid)
        assertEquals(3, nodes.size)
        assertTrue(nodes.all { it.type == NodeType.QUESTION })
        assertTrue(edges.all { it.sourceNodeId == base.id })
    }

    @Test
    fun stepsTemplate_createsThreeSteps() {
        val base = node("작업", NodeType.GOAL)
        val (nodes, _) = ThinkingTools.applyTemplate(ThinkingTools.Template.STEPS, base, gid)
        assertEquals(3, nodes.size)
        assertTrue(nodes.all { it.type == NodeType.STEP })
    }

    @Test
    fun convertToTask_setsTaskDefaults() {
        val base = node("아이디어", NodeType.IDEA)
        val task = ThinkingTools.convertToTask(base)
        assertEquals(NodeType.TASK, task.type)
        assertEquals(NodeStatus.TODO, task.status)
        assertTrue((task.estimatedMinutes ?: 0) > 0)
    }

    @Test
    fun structureCheck_flagsGoalWithoutCriteria() {
        val goal = node("앱 출시", NodeType.GOAL)
        val snap = GraphSnapshot(GraphMeta(id = gid, title = "t"), listOf(goal), emptyList())
        val issues = ThinkingTools.structureCheck(snap)
        assertTrue(issues.any { it.message.contains("완료 기준") })
    }

    @Test
    fun structureCheck_flagsTaskWithoutEstimateOrStatus() {
        val task = node("코딩", NodeType.TASK, status = NodeStatus.THOUGHT, minutes = null)
        val other = node("주제", NodeType.CENTRAL)
        val edge = Edge(graphId = gid, sourceNodeId = other.id, targetNodeId = task.id)
        val snap = GraphSnapshot(GraphMeta(id = gid, title = "t"), listOf(task, other), listOf(edge))
        val issues = ThinkingTools.structureCheck(snap)
        assertTrue(issues.any { it.message.contains("예상 시간") })
    }

    @Test
    fun structureCheck_flagsDuplicateTitles() {
        val a = node("같은 제목", NodeType.IDEA)
        val b = node("같은 제목", NodeType.IDEA)
        val c = node("중심", NodeType.CENTRAL)
        val edges = listOf(
            Edge(graphId = gid, sourceNodeId = c.id, targetNodeId = a.id),
            Edge(graphId = gid, sourceNodeId = c.id, targetNodeId = b.id)
        )
        val snap = GraphSnapshot(GraphMeta(id = gid, title = "t"), listOf(a, b, c), edges)
        val issues = ThinkingTools.structureCheck(snap)
        assertTrue(issues.any { it.message.contains("제목이 같은") })
    }

    @Test
    fun structureCheck_flagsIsolatedNode() {
        val a = node("고립", NodeType.IDEA)
        val b = node("연결됨", NodeType.IDEA)
        val c = node("중심", NodeType.CENTRAL)
        val edge = Edge(graphId = gid, sourceNodeId = c.id, targetNodeId = b.id)
        val snap = GraphSnapshot(GraphMeta(id = gid, title = "t"), listOf(a, b, c), listOf(edge))
        val issues = ThinkingTools.structureCheck(snap)
        assertTrue(issues.any { it.message.contains("연결되어 있지 않") })
    }

    @Test
    fun autoLayout_returnsCoordinatesForEveryNode() {
        val c = node("중심", NodeType.CENTRAL)
        val a = node("a", NodeType.IDEA)
        val edge = Edge(graphId = gid, sourceNodeId = c.id, targetNodeId = a.id)
        val snap = GraphSnapshot(GraphMeta(id = gid, title = "t"), listOf(c, a), listOf(edge))
        val layout = ThinkingTools.autoLayout(snap)
        assertEquals(2, layout.size)
    }
}
