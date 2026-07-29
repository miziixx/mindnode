package com.thoughtgraph.app.localtools

import com.thoughtgraph.app.data.Edge
import com.thoughtgraph.app.data.GraphSnapshot
import com.thoughtgraph.app.data.Importance
import com.thoughtgraph.app.data.Node
import com.thoughtgraph.app.data.NodeStatus
import com.thoughtgraph.app.data.NodeType

/**
 * All "생각 도구" features. These run with fixed rules and templates only — no
 * network, no API calls — so they always work offline.
 */
object ThinkingTools {

    /** The four template generators exposed as tool buttons. */
    enum class Template { QUESTION, CAUSE_EFFECT, STEPS, TO_TASK }

    /**
     * Produces new nodes (and connecting edges to [base]) for the chosen
     * template. Returned nodes are positioned around the base node. The caller
     * decides how to commit them.
     */
    fun applyTemplate(
        template: Template,
        base: Node,
        graphId: String
    ): Pair<List<Node>, List<Edge>> {
        val specs: List<Pair<String, NodeType>> = when (template) {
            Template.QUESTION -> listOf(
                "${base.title}에서 가장 중요한 것은?" to NodeType.QUESTION,
                "완료 기준은 무엇인가?" to NodeType.QUESTION,
                "누구에게 필요한가?" to NodeType.QUESTION
            )
            Template.CAUSE_EFFECT -> listOf(
                "${base.title}의 원인" to NodeType.CAUSE,
                "${base.title}의 결과" to NodeType.RESULT
            )
            Template.STEPS -> listOf(
                "준비하기" to NodeType.STEP,
                "실행하기" to NodeType.STEP,
                "확인하기" to NodeType.STEP
            )
            Template.TO_TASK -> listOf(
                "${base.title}의 첫 행동" to NodeType.TASK
            )
        }

        val nodes = ArrayList<Node>()
        val edges = ArrayList<Edge>()
        specs.forEachIndexed { index, (title, type) ->
            val angle = Math.toRadians((index * 47 + 30).toDouble())
            val node = Node(
                graphId = graphId,
                title = title,
                description = "고정 템플릿으로 생성됨",
                type = type,
                status = if (type == NodeType.TASK) NodeStatus.TODO else NodeStatus.THOUGHT,
                estimatedMinutes = if (type == NodeType.TASK) 30 else null,
                x = base.x + (220 * Math.cos(angle)).toFloat() + index * 12,
                y = base.y + (150 * Math.sin(angle)).toFloat() + index * 96
            )
            nodes.add(node)
            edges.add(
                Edge(
                    graphId = graphId,
                    sourceNodeId = base.id,
                    targetNodeId = node.id,
                    relationType = template.name
                )
            )
        }
        return nodes to edges
    }

    /** Converts an existing node into a task in place. */
    fun convertToTask(node: Node): Node = node.copy(
        type = NodeType.TASK,
        status = if (node.status == NodeStatus.THOUGHT) NodeStatus.TODO else node.status,
        estimatedMinutes = node.estimatedMinutes ?: 30,
        importance = if (node.importance == Importance.LOW) Importance.MEDIUM else node.importance,
        updatedAt = System.currentTimeMillis()
    )

    // ---- Structure check ----

    data class Issue(val nodeId: String?, val message: String)

    /**
     * Rule-based structural review. Only inspects stored node kinds and edges —
     * nothing is ever transmitted.
     */
    fun structureCheck(snapshot: GraphSnapshot): List<Issue> {
        val issues = ArrayList<Issue>()
        val nodes = snapshot.nodes.filterNot { it.isDraft }
        val edges = snapshot.edges
        val degree = HashMap<String, Int>()
        edges.forEach {
            degree[it.sourceNodeId] = (degree[it.sourceNodeId] ?: 0) + 1
            degree[it.targetNodeId] = (degree[it.targetNodeId] ?: 0) + 1
        }
        val childTitlesBySource = HashMap<String, MutableList<String>>()
        val neighbourTypes = HashMap<String, MutableSet<NodeType>>()
        val byId = nodes.associateBy { it.id }
        edges.forEach { e ->
            byId[e.targetNodeId]?.let { child ->
                childTitlesBySource.getOrPut(e.sourceNodeId) { mutableListOf() }.add(child.title)
                neighbourTypes.getOrPut(e.sourceNodeId) { mutableSetOf() }.add(child.type)
            }
            byId[e.sourceNodeId]?.let { parent ->
                neighbourTypes.getOrPut(e.targetNodeId) { mutableSetOf() }.add(parent.type)
            }
        }

        for (node in nodes) {
            when (node.type) {
                NodeType.GOAL -> {
                    val hasCriteria = (childTitlesBySource[node.id] ?: emptyList())
                        .any { it.contains("기준") || it.contains("완료") }
                    if (!hasCriteria) {
                        issues.add(Issue(node.id, "목표 '${node.title}'에 완료 기준이 없습니다."))
                    }
                }
                NodeType.PROBLEM -> {
                    val kinds = neighbourTypes[node.id] ?: emptySet()
                    if (NodeType.CAUSE !in kinds && NodeType.RESULT !in kinds && NodeType.STEP !in kinds && NodeType.TASK !in kinds) {
                        issues.add(Issue(node.id, "문제 '${node.title}'에 원인 또는 해결 노드가 없습니다."))
                    }
                }
                NodeType.TASK -> {
                    if (node.estimatedMinutes == null || node.status == NodeStatus.THOUGHT) {
                        issues.add(Issue(node.id, "할 일 '${node.title}'에 예상 시간 또는 상태가 없습니다."))
                    }
                }
                else -> Unit
            }
            if ((degree[node.id] ?: 0) == 0 && nodes.size > 1) {
                issues.add(Issue(node.id, "'${node.title}'은(는) 어떤 노드와도 연결되어 있지 않습니다."))
            }
        }

        // Duplicate titles.
        nodes.groupBy { it.title.trim() }
            .filter { it.key.isNotEmpty() && it.value.size > 1 }
            .forEach { (title, dupes) ->
                issues.add(Issue(dupes.first().id, "제목이 같은 노드가 ${dupes.size}개 있습니다: '$title'"))
            }

        return issues
    }

    /**
     * Simple deterministic auto-layout: a radial arrangement with the most
     * connected node placed at the centre. Returns new coordinates per node id.
     */
    fun autoLayout(snapshot: GraphSnapshot): Map<String, Pair<Float, Float>> {
        val nodes = snapshot.nodes.filterNot { it.isDraft }
        if (nodes.isEmpty()) return emptyMap()
        val degree = HashMap<String, Int>()
        snapshot.edges.forEach {
            degree[it.sourceNodeId] = (degree[it.sourceNodeId] ?: 0) + 1
            degree[it.targetNodeId] = (degree[it.targetNodeId] ?: 0) + 1
        }
        val centre = nodes.maxByOrNull { degree[it.id] ?: 0 } ?: nodes.first()
        val others = nodes.filter { it.id != centre.id }
        val result = HashMap<String, Pair<Float, Float>>()
        val cx = 600f
        val cy = 460f
        result[centre.id] = cx to cy
        val radius = 320f
        others.forEachIndexed { i, node ->
            val angle = 2 * Math.PI * i / others.size.coerceAtLeast(1)
            result[node.id] = (cx + radius * Math.cos(angle)).toFloat() to
                (cy + radius * Math.sin(angle)).toFloat()
        }
        return result
    }
}
