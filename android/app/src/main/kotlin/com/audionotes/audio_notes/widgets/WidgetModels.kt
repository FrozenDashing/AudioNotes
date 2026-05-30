package com.audionotes.audio_notes.widgets

import org.json.JSONArray
import org.json.JSONObject

data class WidgetSection(
    val title: String,
    val count: Int,
    val items: List<String>,
)

data class WidgetSummary(
    val title: String,
    val subtitle: String,
    val totalCount: Int,
    val pendingCount: Int,
    val completedCount: Int,
    val updatedAt: String,
    val sections: List<WidgetSection>,
)

object WidgetSummaryParser {
    fun fromJson(rawJson: String?): WidgetSummary {
        if (rawJson.isNullOrBlank()) {
            return emptySummary()
        }

        return try {
            val json = JSONObject(rawJson)
            val sectionsJson = json.optJSONArray("sections") ?: JSONArray()
            val sections = buildList {
                for (index in 0 until sectionsJson.length()) {
                    val item = sectionsJson.optJSONObject(index) ?: continue
                    add(
                        WidgetSection(
                            title = item.optString("title", ""),
                            count = item.optInt("count", 0),
                            items = readItems(item.optJSONArray("items")),
                        ),
                    )
                }
            }

            WidgetSummary(
                title = json.optString("title", "今日待办"),
                subtitle = json.optString("subtitle", "暂无更新"),
                totalCount = json.optInt("totalCount", 0),
                pendingCount = json.optInt("pendingCount", 0),
                completedCount = json.optInt("completedCount", 0),
                updatedAt = json.optString("updatedAt", ""),
                sections = if (sections.isEmpty()) defaultSections() else sections,
            )
        } catch (_: Exception) {
            emptySummary()
        }
    }

    private fun emptySummary(): WidgetSummary {
        return WidgetSummary(
            title = "今日待办",
            subtitle = "暂无待办数据",
            totalCount = 0,
            pendingCount = 0,
            completedCount = 0,
            updatedAt = "",
            sections = defaultSections(),
        )
    }

    private fun defaultSections(): List<WidgetSection> {
        return listOf(
            WidgetSection("今天", 0, emptyList()),
            WidgetSection("明天", 0, emptyList()),
            WidgetSection("待办", 0, emptyList()),
        )
    }

    private fun readItems(itemsJson: JSONArray?): List<String> {
        if (itemsJson == null || itemsJson.length() == 0) {
            return emptyList()
        }

        val items = ArrayList<String>(itemsJson.length())
        for (index in 0 until itemsJson.length()) {
            val value = itemsJson.optString(index).trim()
            if (value.isNotEmpty()) {
                items.add(value)
            }
        }
        return items
    }
}