package com.lifetrace.execute.data.repository

import com.lifetrace.execute.domain.project.ExecutionProject
import com.lifetrace.execute.domain.project.ExecutionProjectStatus
import org.json.JSONObject

object ProjectWireMapper {
    fun toPayload(project: ExecutionProject): String {
        val meta = JSONObject()
            .put("id", project.id)
            .put("userId", project.userId)
            .put("createdAt", project.createdAt)
            .put("updatedAt", project.updatedAt)
            .put("deletedAt", JSONObject.NULL)
            .put("localVersion", project.localVersion)
            .put("serverVersion", project.serverVersion ?: JSONObject.NULL)
            .put("modifiedByDevice", project.modifiedByDevice ?: JSONObject.NULL)

        return JSONObject()
            .put("meta", meta)
            .put("name", project.name)
            .put("description", project.description ?: JSONObject.NULL)
            .put("status", project.status.wireValue)
            .put("dueAt", project.dueAt ?: JSONObject.NULL)
            .toString()
    }

    fun fromPayload(payloadJson: String, serverVersion: String): ExecutionProject {
        val root = JSONObject(payloadJson)
        val meta = root.getJSONObject("meta")
        return ExecutionProject(
            id = meta.getString("id"),
            userId = meta.getString("userId"),
            name = root.getString("name"),
            description = root.optNullableString("description"),
            status = ExecutionProjectStatus.fromWire(root.optString("status", "active")),
            dueAt = root.optNullableString("dueAt"),
            createdAt = meta.getString("createdAt"),
            updatedAt = meta.getString("updatedAt"),
            localVersion = meta.optLong("localVersion", 1L),
            serverVersion = serverVersion,
            modifiedByDevice = meta.optNullableString("modifiedByDevice"),
        )
    }
}

private fun JSONObject.optNullableString(name: String): String? {
    if (!has(name) || isNull(name)) return null
    return optString(name).takeIf { it.isNotBlank() }
}
