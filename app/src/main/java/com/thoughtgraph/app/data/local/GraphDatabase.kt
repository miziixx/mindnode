package com.thoughtgraph.app.data.local

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.thoughtgraph.app.data.Edge
import com.thoughtgraph.app.data.GraphMeta
import com.thoughtgraph.app.data.GraphSnapshot
import com.thoughtgraph.app.data.Importance
import com.thoughtgraph.app.data.Node
import com.thoughtgraph.app.data.NodeStatus
import com.thoughtgraph.app.data.NodeType

/**
 * Local-first store for graphs, nodes and edges.
 *
 * Uses a hand-written [SQLiteOpenHelper] (no annotation processors) so the graph
 * schema is fully owned here with explicit versioning and migrations. API keys
 * are NEVER stored in this database — they live only in secure storage.
 */
class GraphDatabase(context: Context) : SQLiteOpenHelper(
    context.applicationContext, DB_NAME, null, DB_VERSION
) {

    override fun onConfigure(db: SQLiteDatabase) {
        db.setForeignKeyConstraintsEnabled(true)
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE graphs (
                id TEXT PRIMARY KEY NOT NULL,
                title TEXT NOT NULL,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL
            )
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE nodes (
                id TEXT PRIMARY KEY NOT NULL,
                graphId TEXT NOT NULL,
                title TEXT NOT NULL,
                description TEXT NOT NULL,
                type TEXT NOT NULL,
                status TEXT NOT NULL,
                importance TEXT NOT NULL,
                dueAt INTEGER,
                estimatedMinutes INTEGER,
                x REAL NOT NULL,
                y REAL NOT NULL,
                isDraft INTEGER NOT NULL DEFAULT 0,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL,
                FOREIGN KEY(graphId) REFERENCES graphs(id) ON DELETE CASCADE
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX idx_nodes_graph ON nodes(graphId)")
        db.execSQL(
            """
            CREATE TABLE edges (
                id TEXT PRIMARY KEY NOT NULL,
                graphId TEXT NOT NULL,
                sourceNodeId TEXT NOT NULL,
                targetNodeId TEXT NOT NULL,
                relationType TEXT NOT NULL,
                label TEXT NOT NULL,
                createdAt INTEGER NOT NULL,
                FOREIGN KEY(graphId) REFERENCES graphs(id) ON DELETE CASCADE
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX idx_edges_graph ON edges(graphId)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Forward-only migrations. Each block upgrades one version at a time so
        // future schema changes can be appended safely.
        var version = oldVersion
        // Example scaffold for the next migration:
        // if (version < 2) { db.execSQL("ALTER TABLE nodes ADD COLUMN color TEXT"); version = 2 }
        if (version != newVersion) {
            // No destructive fallback: if we ever reach an unknown state we keep
            // data and let onCreate-style guards handle missing columns.
        }
    }

    // ---- Graph level ----

    fun listGraphs(): List<GraphMeta> {
        val out = ArrayList<GraphMeta>()
        readableDatabase.rawQuery(
            """
            SELECT g.id, g.title, g.createdAt, g.updatedAt,
                   (SELECT COUNT(*) FROM nodes n WHERE n.graphId = g.id) AS cnt
            FROM graphs g ORDER BY g.updatedAt DESC
            """.trimIndent(),
            null
        ).use { c ->
            while (c.moveToNext()) {
                out.add(
                    GraphMeta(
                        id = c.getString(0),
                        title = c.getString(1),
                        createdAt = c.getLong(2),
                        updatedAt = c.getLong(3),
                        nodeCount = c.getInt(4)
                    )
                )
            }
        }
        return out
    }

    fun upsertGraphMeta(meta: GraphMeta) {
        val values = ContentValues().apply {
            put("id", meta.id)
            put("title", meta.title)
            put("createdAt", meta.createdAt)
            put("updatedAt", meta.updatedAt)
        }
        writableDatabase.insertWithOnConflict(
            "graphs", null, values, SQLiteDatabase.CONFLICT_REPLACE
        )
    }

    fun deleteGraph(graphId: String) {
        writableDatabase.delete("graphs", "id = ?", arrayOf(graphId))
    }

    fun loadGraph(graphId: String): GraphSnapshot? {
        val db = readableDatabase
        val meta = db.rawQuery(
            "SELECT id, title, createdAt, updatedAt FROM graphs WHERE id = ?",
            arrayOf(graphId)
        ).use { c ->
            if (!c.moveToFirst()) return null
            GraphMeta(
                id = c.getString(0),
                title = c.getString(1),
                createdAt = c.getLong(2),
                updatedAt = c.getLong(3)
            )
        }
        val nodes = queryNodes(db, graphId)
        val edges = queryEdges(db, graphId)
        return GraphSnapshot(meta.copy(nodeCount = nodes.size), nodes, edges)
    }

    private fun queryNodes(db: SQLiteDatabase, graphId: String): List<Node> {
        val out = ArrayList<Node>()
        db.rawQuery(
            "SELECT id, graphId, title, description, type, status, importance, dueAt, estimatedMinutes, x, y, isDraft, createdAt, updatedAt FROM nodes WHERE graphId = ?",
            arrayOf(graphId)
        ).use { c ->
            while (c.moveToNext()) {
                out.add(
                    Node(
                        id = c.getString(0),
                        graphId = c.getString(1),
                        title = c.getString(2),
                        description = c.getString(3),
                        type = NodeType.fromName(c.getString(4)),
                        status = NodeStatus.fromName(c.getString(5)),
                        importance = Importance.fromName(c.getString(6)),
                        dueAt = if (c.isNull(7)) null else c.getLong(7),
                        estimatedMinutes = if (c.isNull(8)) null else c.getInt(8),
                        x = c.getFloat(9),
                        y = c.getFloat(10),
                        isDraft = c.getInt(11) == 1,
                        createdAt = c.getLong(12),
                        updatedAt = c.getLong(13)
                    )
                )
            }
        }
        return out
    }

    private fun queryEdges(db: SQLiteDatabase, graphId: String): List<Edge> {
        val out = ArrayList<Edge>()
        db.rawQuery(
            "SELECT id, graphId, sourceNodeId, targetNodeId, relationType, label, createdAt FROM edges WHERE graphId = ?",
            arrayOf(graphId)
        ).use { c ->
            while (c.moveToNext()) {
                out.add(
                    Edge(
                        id = c.getString(0),
                        graphId = c.getString(1),
                        sourceNodeId = c.getString(2),
                        targetNodeId = c.getString(3),
                        relationType = c.getString(4),
                        label = c.getString(5),
                        createdAt = c.getLong(6)
                    )
                )
            }
        }
        return out
    }

    /**
     * Replaces the persisted contents of one graph with the given snapshot in a
     * single transaction. Draft (unapproved AI) nodes are never persisted.
     */
    fun saveGraph(snapshot: GraphSnapshot) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            upsertGraphMetaInternal(db, snapshot.meta.copy(updatedAt = System.currentTimeMillis()))
            db.delete("nodes", "graphId = ?", arrayOf(snapshot.meta.id))
            db.delete("edges", "graphId = ?", arrayOf(snapshot.meta.id))
            for (n in snapshot.nodes) {
                if (n.isDraft) continue
                db.insert("nodes", null, nodeValues(n))
            }
            val liveIds = snapshot.nodes.filterNot { it.isDraft }.map { it.id }.toHashSet()
            for (e in snapshot.edges) {
                if (e.sourceNodeId in liveIds && e.targetNodeId in liveIds) {
                    db.insert("edges", null, edgeValues(e))
                }
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    private fun upsertGraphMetaInternal(db: SQLiteDatabase, meta: GraphMeta) {
        val values = ContentValues().apply {
            put("id", meta.id)
            put("title", meta.title)
            put("createdAt", meta.createdAt)
            put("updatedAt", meta.updatedAt)
        }
        db.insertWithOnConflict("graphs", null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }

    private fun nodeValues(n: Node) = ContentValues().apply {
        put("id", n.id)
        put("graphId", n.graphId)
        put("title", n.title)
        put("description", n.description)
        put("type", n.type.name)
        put("status", n.status.name)
        put("importance", n.importance.name)
        if (n.dueAt != null) put("dueAt", n.dueAt) else putNull("dueAt")
        if (n.estimatedMinutes != null) put("estimatedMinutes", n.estimatedMinutes) else putNull("estimatedMinutes")
        put("x", n.x)
        put("y", n.y)
        put("isDraft", 0)
        put("createdAt", n.createdAt)
        put("updatedAt", n.updatedAt)
    }

    private fun edgeValues(e: Edge) = ContentValues().apply {
        put("id", e.id)
        put("graphId", e.graphId)
        put("sourceNodeId", e.sourceNodeId)
        put("targetNodeId", e.targetNodeId)
        put("relationType", e.relationType)
        put("label", e.label)
        put("createdAt", e.createdAt)
    }

    fun wipeAll() {
        val db = writableDatabase
        db.beginTransaction()
        try {
            db.delete("edges", null, null)
            db.delete("nodes", null, null)
            db.delete("graphs", null, null)
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    companion object {
        const val DB_NAME = "thoughtgraph.db"
        const val DB_VERSION = 1
    }
}
