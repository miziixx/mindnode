package com.thoughtgraph.app.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.thoughtgraph.app.ai.AiAction
import com.thoughtgraph.app.ai.AiClient
import com.thoughtgraph.app.ai.AiResult
import com.thoughtgraph.app.data.Edge
import com.thoughtgraph.app.data.GraphMeta
import com.thoughtgraph.app.data.GraphSnapshot
import com.thoughtgraph.app.data.Node
import com.thoughtgraph.app.data.NodeStatus
import com.thoughtgraph.app.data.NodeType
import com.thoughtgraph.app.data.repo.GraphRepository
import com.thoughtgraph.app.localtools.ThinkingTools
import com.thoughtgraph.app.settings.SecureCredentialStore
import com.thoughtgraph.app.settings.SettingsStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

enum class MainView { GRAPH, LIST, PLAN }

data class SaveState(val saving: Boolean = false, val savedAt: Long = System.currentTimeMillis())

data class AiPreviewState(
    val action: AiAction,
    val contextText: String,
    val endpoint: String,
    val model: String,
    val provider: String
)

data class UiState(
    val snapshot: GraphSnapshot,
    val recentGraphs: List<GraphMeta> = emptyList(),
    val selectedNodeId: String? = null,
    val mainView: MainView = MainView.GRAPH,
    val focusMode: Boolean = false,
    val searchQuery: String = "",
    val canUndo: Boolean = false,
    val canRedo: Boolean = false,
    val saveState: SaveState = SaveState(),
    val aiPreview: AiPreviewState? = null,
    val aiBusy: Boolean = false,
    val message: String? = null
)

class AppViewModel(app: Application) : AndroidViewModel(app) {

    private val repo = GraphRepository(app)
    val settings = SettingsStore(app)
    val credentials = SecureCredentialStore(app)
    val ai = AiClient(settings, credentials)

    private val undoStack = ArrayDeque<GraphSnapshot>()
    private val redoStack = ArrayDeque<GraphSnapshot>()
    private val maxHistory = 50

    private val _state: MutableStateFlow<UiState>
    val state: StateFlow<UiState>

    init {
        val initial = loadInitialGraph()
        _state = MutableStateFlow(
            UiState(
                snapshot = initial,
                recentGraphs = repo.listGraphs(),
                selectedNodeId = initial.nodes.firstOrNull { it.type == NodeType.CENTRAL }?.id
                    ?: initial.nodes.firstOrNull()?.id
            )
        )
        state = _state.asStateFlow()
    }

    private fun loadInitialGraph(): GraphSnapshot {
        if (!settings.seeded) {
            val seeded = repo.seedSampleGraph()
            settings.seeded = true
            settings.lastGraphId = seeded.meta.id
            return seeded
        }
        val last = settings.lastGraphId?.let { repo.loadGraph(it) }
        if (last != null) return last
        val first = repo.listGraphs().firstOrNull()?.let { repo.loadGraph(it.id) }
        if (first != null) return first
        val created = repo.createGraph("새 그래프")
        settings.lastGraphId = created.meta.id
        return created
    }

    // ---- History ----

    private fun pushHistory() {
        undoStack.addLast(current().snapshot)
        if (undoStack.size > maxHistory) undoStack.removeFirst()
        redoStack.clear()
    }

    fun undo() {
        if (undoStack.isEmpty()) return
        redoStack.addLast(current().snapshot)
        val prev = undoStack.removeLast()
        applySnapshot(prev, persist = true)
    }

    fun redo() {
        if (redoStack.isEmpty()) return
        undoStack.addLast(current().snapshot)
        val next = redoStack.removeLast()
        applySnapshot(next, persist = true)
    }

    private fun current() = _state.value

    private fun applySnapshot(snapshot: GraphSnapshot, persist: Boolean) {
        _state.value = current().copy(
            snapshot = snapshot,
            canUndo = undoStack.isNotEmpty(),
            canRedo = redoStack.isNotEmpty()
        )
        if (persist) autoSave()
    }

    /** Mutates the current live graph, recording history and auto-saving. */
    private fun mutate(record: Boolean = true, block: (GraphSnapshot) -> GraphSnapshot) {
        if (record) pushHistory()
        val updated = block(current().snapshot)
        _state.value = current().copy(
            snapshot = updated,
            canUndo = undoStack.isNotEmpty(),
            canRedo = redoStack.isNotEmpty()
        )
        autoSave()
    }

    private fun autoSave() {
        if (!settings.autoSave) return
        val snap = current().snapshot
        _state.value = current().copy(saveState = SaveState(saving = true))
        viewModelScope.launch(Dispatchers.IO) {
            repo.save(snap)
            settings.lastGraphId = snap.meta.id
            withContext(Dispatchers.Main) {
                _state.value = current().copy(
                    saveState = SaveState(saving = false),
                    recentGraphs = repo.listGraphs()
                )
            }
        }
    }

    // ---- Selection / view ----

    fun select(nodeId: String?) {
        _state.value = current().copy(selectedNodeId = nodeId)
    }

    fun selectedNode(): Node? =
        current().snapshot.nodes.firstOrNull { it.id == current().selectedNodeId }

    fun setMainView(view: MainView) {
        _state.value = current().copy(mainView = view)
    }

    fun toggleFocus() {
        _state.value = current().copy(focusMode = !current().focusMode)
    }

    fun setSearch(query: String) {
        _state.value = current().copy(searchQuery = query)
    }

    fun setTitle(title: String) {
        mutate(record = false) { it.copy(meta = it.meta.copy(title = title)) }
    }

    fun consumeMessage() {
        _state.value = current().copy(message = null)
    }

    private fun toast(msg: String) {
        _state.value = current().copy(message = msg)
    }

    /** Public entry for one-off UI messages (e.g. from the settings sheet). */
    fun postMessage(msg: String) = toast(msg)

    // ---- Node ops ----

    fun addNode(title: String, type: NodeType, description: String = ""): Node {
        val gid = current().snapshot.meta.id
        val node = Node(
            graphId = gid,
            title = title,
            description = description,
            type = type,
            x = 560f + (Math.random() * 240).toFloat(),
            y = 300f + (Math.random() * 320).toFloat(),
            status = if (type == NodeType.TASK) NodeStatus.TODO else NodeStatus.THOUGHT
        )
        mutate { it.copy(nodes = it.nodes + node) }
        select(node.id)
        return node
    }

    /** Adds a node at explicit graph-space coordinates (e.g. double-tap on canvas). */
    fun addNodeAt(x: Float, y: Float, title: String = "새 노드", type: NodeType = NodeType.IDEA): Node {
        val gid = current().snapshot.meta.id
        val node = Node(
            graphId = gid,
            title = title,
            type = type,
            x = x,
            y = y,
            status = if (type == NodeType.TASK) NodeStatus.TODO else NodeStatus.THOUGHT
        )
        mutate { it.copy(nodes = it.nodes + node) }
        select(node.id)
        return node
    }

    fun updateNode(node: Node) {
        mutate { snap ->
            snap.copy(nodes = snap.nodes.map { if (it.id == node.id) node.copy(updatedAt = System.currentTimeMillis()) else it })
        }
    }

    fun moveNode(id: String, x: Float, y: Float, record: Boolean) {
        mutate(record = record) { snap ->
            snap.copy(nodes = snap.nodes.map { if (it.id == id) it.copy(x = x, y = y) else it })
        }
    }

    fun deleteNode(id: String) {
        mutate { snap ->
            snap.copy(
                nodes = snap.nodes.filterNot { it.id == id },
                edges = snap.edges.filterNot { it.sourceNodeId == id || it.targetNodeId == id }
            )
        }
        if (current().selectedNodeId == id) select(current().snapshot.nodes.firstOrNull()?.id)
    }

    fun duplicateNode(id: String) {
        val original = current().snapshot.nodes.firstOrNull { it.id == id } ?: return
        val copy = original.copy(
            id = java.util.UUID.randomUUID().toString(),
            title = original.title + " (복제)",
            x = original.x + 40f,
            y = original.y + 40f,
            isDraft = false,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
        mutate { it.copy(nodes = it.nodes + copy) }
        select(copy.id)
    }

    // ---- Edge ops ----

    fun connect(sourceId: String, targetId: String, relationType: String = "관계") {
        if (sourceId == targetId) return
        val exists = current().snapshot.edges.any {
            (it.sourceNodeId == sourceId && it.targetNodeId == targetId) ||
                (it.sourceNodeId == targetId && it.targetNodeId == sourceId)
        }
        if (exists) { toast("이미 연결되어 있습니다."); return }
        val edge = Edge(
            graphId = current().snapshot.meta.id,
            sourceNodeId = sourceId,
            targetNodeId = targetId,
            relationType = relationType
        )
        mutate { it.copy(edges = it.edges + edge) }
    }

    fun disconnect(edgeId: String) {
        mutate { snap -> snap.copy(edges = snap.edges.filterNot { it.id == edgeId }) }
    }

    fun setEdgeLabel(edgeId: String, label: String) {
        mutate { snap ->
            snap.copy(edges = snap.edges.map { if (it.id == edgeId) it.copy(label = label) else it })
        }
    }

    // ---- Local thinking tools ----

    fun applyTemplate(template: ThinkingTools.Template) {
        val base = selectedNode() ?: return
        val (nodes, edges) = ThinkingTools.applyTemplate(template, base, current().snapshot.meta.id)
        mutate { it.copy(nodes = it.nodes + nodes, edges = it.edges + edges) }
        toast("로컬 템플릿으로 노드를 만들었습니다.")
    }

    fun convertSelectedToTask() {
        val base = selectedNode() ?: return
        updateNode(ThinkingTools.convertToTask(base))
        toast("할 일로 바꿨습니다.")
    }

    fun runStructureCheck(): List<ThinkingTools.Issue> =
        ThinkingTools.structureCheck(current().snapshot)

    fun autoLayout() {
        val layout = ThinkingTools.autoLayout(current().snapshot)
        mutate { snap ->
            snap.copy(nodes = snap.nodes.map { n ->
                layout[n.id]?.let { (x, y) -> n.copy(x = x, y = y) } ?: n
            })
        }
        toast("자동 정렬했습니다.")
    }

    // ---- Graph management ----

    fun newGraph() {
        val created = repo.createGraph("새 그래프")
        undoStack.clear(); redoStack.clear()
        _state.value = current().copy(
            snapshot = created,
            selectedNodeId = created.nodes.firstOrNull()?.id,
            recentGraphs = repo.listGraphs(),
            canUndo = false, canRedo = false
        )
        settings.lastGraphId = created.meta.id
    }

    fun openGraph(id: String) {
        val snap = repo.loadGraph(id) ?: return
        undoStack.clear(); redoStack.clear()
        _state.value = current().copy(
            snapshot = snap,
            selectedNodeId = snap.nodes.firstOrNull { it.type == NodeType.CENTRAL }?.id
                ?: snap.nodes.firstOrNull()?.id,
            canUndo = false, canRedo = false
        )
        settings.lastGraphId = id
    }

    fun deleteCurrentGraph() {
        val id = current().snapshot.meta.id
        repo.deleteGraph(id)
        val next = repo.listGraphs().firstOrNull()?.let { repo.loadGraph(it.id) }
            ?: repo.createGraph("새 그래프")
        undoStack.clear(); redoStack.clear()
        _state.value = current().copy(
            snapshot = next,
            selectedNodeId = next.nodes.firstOrNull()?.id,
            recentGraphs = repo.listGraphs()
        )
        settings.lastGraphId = next.meta.id
    }

    fun renameCurrentGraph(title: String) = setTitle(title)

    fun repository(): GraphRepository = repo

    // ---- Optional AI (manual, preview → confirm → call → draft → approve) ----

    /** Builds the preview for the confirmation dialog. Never calls the network. */
    fun prepareAi(action: AiAction) {
        if (!ai.isReady()) { toast("AI 설정을 먼저 완료하세요."); return }
        val base = selectedNode()
        if (base == null) { toast("먼저 노드를 선택하세요."); return }
        val selectedNodes = if (settings.selectedOnly) listOf(base) else current().snapshot.nodes
        val context = com.thoughtgraph.app.exportimport.GraphSerializer
            .toAiContext(current().snapshot, selectedNodes)
        val preview = ai.buildPreview(action, context)
        _state.value = current().copy(
            aiPreview = AiPreviewState(
                action = action,
                contextText = context,
                endpoint = preview.endpoint,
                model = preview.model,
                provider = preview.provider
            )
        )
    }

    fun cancelAiPreview() {
        _state.value = current().copy(aiPreview = null)
    }

    /** Confirms the preview and runs the call off the main thread. */
    fun confirmAi() {
        val preview = current().aiPreview ?: return
        val base = selectedNode() ?: return
        _state.value = current().copy(aiPreview = null, aiBusy = true)
        viewModelScope.launch(Dispatchers.IO) {
            val result = ai.run(preview.action, preview.contextText)
            withContext(Dispatchers.Main) {
                when (result) {
                    is AiResult.Success -> addAiDrafts(base, result.suggestions)
                    is AiResult.Failure -> toast(result.message)
                    AiResult.NotConfigured -> toast("AI 설정을 확인하세요.")
                }
                _state.value = current().copy(aiBusy = false)
            }
        }
    }

    private fun addAiDrafts(base: Node, suggestions: List<String>) {
        if (suggestions.isEmpty()) { toast("제안이 없습니다."); return }
        val gid = current().snapshot.meta.id
        val drafts = suggestions.mapIndexed { i, text ->
            Node(
                graphId = gid,
                title = text.take(60),
                description = "AI 임시 제안 · 승인 전",
                type = NodeType.IDEA,
                isDraft = true,
                x = base.x + 240f,
                y = base.y + i * 120f
            )
        }
        // Draft nodes are added to view state only; DB save skips drafts.
        _state.value = current().copy(
            snapshot = current().snapshot.copy(nodes = current().snapshot.nodes + drafts)
        )
        toast("임시 노드를 추가했습니다. 승인하면 저장됩니다.")
    }

    /** Approves one draft: makes it permanent, links it to the source, saves. */
    fun approveDraft(draftId: String, edited: String? = null) {
        val draft = current().snapshot.nodes.firstOrNull { it.id == draftId && it.isDraft } ?: return
        val base = selectedNode()
        val approved = draft.copy(
            isDraft = false,
            title = edited?.take(80) ?: draft.title,
            description = "AI 제안에서 승인됨",
            updatedAt = System.currentTimeMillis()
        )
        mutate { snap ->
            val newNodes = snap.nodes.map { if (it.id == draftId) approved else it }
            val newEdges = if (base != null)
                snap.edges + Edge(
                    graphId = snap.meta.id,
                    sourceNodeId = base.id,
                    targetNodeId = approved.id,
                    relationType = "AI 제안"
                )
            else snap.edges
            snap.copy(nodes = newNodes, edges = newEdges)
        }
        toast("노드를 추가했습니다.")
    }

    fun dismissDraft(draftId: String) {
        _state.value = current().copy(
            snapshot = current().snapshot.copy(
                nodes = current().snapshot.nodes.filterNot { it.id == draftId && it.isDraft }
            )
        )
    }

    fun dismissAllDrafts() {
        _state.value = current().copy(
            snapshot = current().snapshot.copy(
                nodes = current().snapshot.nodes.filterNot { it.isDraft }
            )
        )
    }

    fun refreshRecents() {
        _state.value = current().copy(recentGraphs = repo.listGraphs())
    }
}
