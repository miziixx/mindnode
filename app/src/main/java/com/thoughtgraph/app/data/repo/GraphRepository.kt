package com.thoughtgraph.app.data.repo

import android.content.Context
import com.thoughtgraph.app.data.Edge
import com.thoughtgraph.app.data.GraphMeta
import com.thoughtgraph.app.data.GraphSnapshot
import com.thoughtgraph.app.data.Importance
import com.thoughtgraph.app.data.Node
import com.thoughtgraph.app.data.NodeStatus
import com.thoughtgraph.app.data.NodeType
import com.thoughtgraph.app.data.local.GraphDatabase

/**
 * Thin persistence facade over [GraphDatabase]. Keeps the graph data completely
 * separate from API credentials.
 */
class GraphRepository(context: Context) {

    private val db = GraphDatabase(context)

    fun listGraphs(): List<GraphMeta> = db.listGraphs()

    fun loadGraph(id: String): GraphSnapshot? = db.loadGraph(id)

    fun save(snapshot: GraphSnapshot) = db.saveGraph(snapshot)

    fun createGraph(title: String = "새 그래프"): GraphSnapshot {
        val meta = GraphMeta(title = title)
        val central = Node(
            graphId = meta.id,
            title = title,
            type = NodeType.CENTRAL,
            importance = Importance.HIGH,
            x = 600f,
            y = 440f
        )
        val snapshot = GraphSnapshot(meta, listOf(central), emptyList())
        db.saveGraph(snapshot)
        return snapshot
    }

    fun deleteGraph(id: String) = db.deleteGraph(id)

    fun allGraphs(): List<GraphSnapshot> =
        db.listGraphs().mapNotNull { db.loadGraph(it.id) }

    fun wipeAll() = db.wipeAll()

    fun restoreBackup(graphs: List<GraphSnapshot>, replace: Boolean) {
        if (replace) db.wipeAll()
        graphs.forEach { db.saveGraph(it) }
    }

    /** Seeds one sample graph on first launch only. */
    fun seedSampleGraph(): GraphSnapshot {
        val meta = GraphMeta(title = "심리학 앱 기획")
        val gid = meta.id
        fun n(title: String, desc: String, type: NodeType, x: Float, y: Float,
              status: NodeStatus = NodeStatus.THOUGHT) =
            Node(graphId = gid, title = title, description = desc, type = type, x = x, y = y, status = status)

        val central = n("심리학 앱 만들기", "고민을 입력하면 이해하기 쉬운 답과 해결 방향을 제시", NodeType.CENTRAL, 600f, 440f)
        val user = n("대상 사용자", "심리학을 몰라도 쉽게 도움받고 싶은 사람", NodeType.IDEA, 240f, 240f)
        val problem = n("사용자 문제", "고민을 적어도 결국 사용자가 직접 답을 골라야 함", NodeType.PROBLEM, 200f, 460f)
        val principle = n("콘텐츠 원칙", "어려운 용어는 바로 풀어서 설명하기", NodeType.IDEA, 260f, 680f)
        val feature = n("핵심 기능", "고민 입력 → 설명 → 해결 방법 → 다음 질문", NodeType.GOAL, 960f, 230f)
        val ux = n("대화 방식", "답을 먼저 주고 필요한 경우에만 선택지 사용", NodeType.IDEA, 980f, 470f)
        val firstTask = n("첫 화면 프로토타입 만들기", "입력창과 답변 영역 배치", NodeType.TASK, 980f, 690f, NodeStatus.TODO)

        val nodes = listOf(central, user, problem, principle, feature, ux,
            firstTask.copy(estimatedMinutes = 60, importance = Importance.HIGH))
        val edges = listOf(
            Edge(graphId = gid, sourceNodeId = central.id, targetNodeId = user.id, relationType = "대상"),
            Edge(graphId = gid, sourceNodeId = central.id, targetNodeId = problem.id, relationType = "문제"),
            Edge(graphId = gid, sourceNodeId = central.id, targetNodeId = principle.id, relationType = "원칙"),
            Edge(graphId = gid, sourceNodeId = central.id, targetNodeId = feature.id, relationType = "기능"),
            Edge(graphId = gid, sourceNodeId = feature.id, targetNodeId = ux.id, relationType = "방식"),
            Edge(graphId = gid, sourceNodeId = feature.id, targetNodeId = firstTask.id, relationType = "할 일")
        )
        val snapshot = GraphSnapshot(meta.copy(nodeCount = nodes.size), nodes, edges)
        db.saveGraph(snapshot)
        return snapshot
    }
}
