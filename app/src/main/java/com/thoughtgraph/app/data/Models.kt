package com.thoughtgraph.app.data

import java.util.UUID

/**
 * Node kinds required by the spec. [accent] is only a thin point colour used to
 * distinguish the kind — nodes are never fully filled with it.
 */
enum class NodeType(val label: String, val accent: Long) {
    CENTRAL("중심 주제", 0xFFEF7657),
    IDEA("아이디어", 0xFFD6A94F),
    QUESTION("질문", 0xFF8175BA),
    GOAL("목표", 0xFF628F76),
    PROBLEM("문제", 0xFFC85151),
    CAUSE("원인", 0xFFB07C4A),
    RESULT("결과", 0xFF4F8FA6),
    STEP("단계", 0xFF8175BA),
    TASK("할 일", 0xFF628F76),
    DECISION("결정", 0xFFC75437),
    RESOURCE("자료", 0xFF6F8CC0),
    HOLD("보류", 0xFF8B8378);

    companion object {
        fun fromLabel(label: String): NodeType =
            entries.firstOrNull { it.label == label } ?: IDEA
        fun fromName(name: String?): NodeType =
            entries.firstOrNull { it.name == name } ?: IDEA
    }
}

/** Execution status used by list view and the plan view. */
enum class NodeStatus(val label: String) {
    THOUGHT("생각"),
    TODO("할 일"),
    IN_PROGRESS("진행 중"),
    DONE("완료");

    companion object {
        fun fromName(name: String?): NodeStatus =
            entries.firstOrNull { it.name == name } ?: THOUGHT
    }
}

enum class Importance(val label: String) {
    LOW("낮음"), MEDIUM("보통"), HIGH("높음");

    companion object {
        fun fromName(name: String?): Importance =
            entries.firstOrNull { it.name == name } ?: MEDIUM
    }
}

data class GraphMeta(
    val id: String = UUID.randomUUID().toString(),
    val title: String = "새 그래프",
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val nodeCount: Int = 0
)

data class Node(
    val id: String = UUID.randomUUID().toString(),
    val graphId: String,
    val title: String = "",
    val description: String = "",
    val type: NodeType = NodeType.IDEA,
    val status: NodeStatus = NodeStatus.THOUGHT,
    val importance: Importance = Importance.MEDIUM,
    val dueAt: Long? = null,
    val estimatedMinutes: Int? = null,
    val x: Float = 0f,
    val y: Float = 0f,
    /** true only for unapproved AI suggestion nodes, rendered translucent. */
    val isDraft: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)

data class Edge(
    val id: String = UUID.randomUUID().toString(),
    val graphId: String,
    val sourceNodeId: String,
    val targetNodeId: String,
    val relationType: String = "관계",
    val label: String = "",
    val createdAt: Long = System.currentTimeMillis()
)

/** A full graph snapshot: the unit that is loaded, saved, exported and imported. */
data class GraphSnapshot(
    val meta: GraphMeta,
    val nodes: List<Node>,
    val edges: List<Edge>
)
