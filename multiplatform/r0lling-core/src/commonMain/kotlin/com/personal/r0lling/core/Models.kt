package com.personal.r0lling.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Pigi proelefsis tis katagrafis tou hmerologiou (EntrySource).
 * 1:1 Parity me to Swift enum EntrySource kai to r0lling-exchange-v1.schema.json.
 */
@Serializable
enum class EntrySource {
    @SerialName("manual")
    MANUAL,

    @SerialName("glasses")
    GLASSES,

    @SerialName("glasses_clip")
    GLASSES_CLIP,

    @SerialName("voice")
    VOICE,

    @SerialName("import")
    IMPORT,

    @SerialName("ai")
    AI
}

/**
 * Typos synimennou polymesou (MediaType).
 * 1:1 Parity me to Swift enum MediaType.
 */
@Serializable
enum class MediaType {
    @SerialName("photo")
    PHOTO,

    @SerialName("video")
    VIDEO,

    @SerialName("clip")
    CLIP,

    @SerialName("audio")
    AUDIO
}

/**
 * Synimmeno polymeso (MediaAttachment).
 * Ypoxreotika pedia: id, relativePath, mediaType, byteSize, captureTimestamp, hasAudio.
 */
@Serializable
data class MediaAttachment(
    val id: String,
    val relativePath: String,
    val originalFilename: String? = null,
    val mediaType: MediaType,
    val byteSize: Long,
    val durationSeconds: Double? = null,
    val captureTimestamp: String,
    val width: Int? = null,
    val height: Int? = null,
    val hasAudio: Boolean
) {
    init {
        // Enforce exchange schema invariant patterns
        require(id.matches(Regex("^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$"))) {
            "To id tou attachment prepei na einai uppercase hex canonical UUID"
        }
        require(captureTimestamp.matches(Regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))) {
            "To captureTimestamp prepei na einai ISO-8601 UTC me whole seconds"
        }
        when (mediaType) {
            MediaType.PHOTO -> require(relativePath.startsWith("Photos/")) { "Photo prepei na einai sto Photos/" }
            MediaType.VIDEO -> require(relativePath.startsWith("Videos/")) { "Video prepei na einai sto Videos/" }
            MediaType.CLIP -> require(relativePath.startsWith("Clips/")) { "Clip prepei na einai sto Clips/" }
            MediaType.AUDIO -> require(relativePath.startsWith("Audio/")) { "Audio prepei na einai sto Audio/" }
        }
        require(byteSize >= 0) { "To byteSize prepei na einai >= 0" }
    }
}

/**
 * Kataxwrish Hmerologiou (JournalEntry).
 * 1:1 Parity me to Swift struct JournalEntry.
 */
@Serializable
data class JournalEntry(
    val id: String,
    val timestamp: String,
    val timeZoneIdentifier: String,
    val title: String? = null,
    val content: String,
    val source: EntrySource,
    val tags: List<String> = emptyList(),
    val locationName: String? = null,
    val attachments: List<MediaAttachment> = emptyList(),
    val isFavorite: Boolean = false,
    val lastModified: String
) {
    init {
        require(id.matches(Regex("^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$"))) {
            "To id tou entry prepei na einai uppercase hex canonical UUID"
        }
        require(timestamp.matches(Regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))) {
            "To timestamp prepei na einai ISO-8601 UTC me whole seconds"
        }
        require(lastModified.matches(Regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))) {
            "To lastModified prepei na einai ISO-8601 UTC me whole seconds"
        }
        require(timeZoneIdentifier.isNotBlank()) {
            "To timeZoneIdentifier den prepei na einai keno"
        }
    }
}

/**
 * Mnimi tou AI Agent (AgentMemory).
 * Katagrafi simeiwsewn, protimiseon kai anoixtwn thematwn (open loops).
 */
@Serializable
data class AgentMemory(
    val memoryNotes: String,
    val userPreferences: String,
    val openLoops: String,
    val lastUpdated: String
) {
    init {
        require(lastUpdated.matches(Regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))) {
            "To lastUpdated prepei na einai ISO-8601 UTC me whole seconds"
        }
    }
}

/**
 * Topiko Arxeio Hmerologiou (journal_v1.json).
 */
@Serializable
data class JournalFile(
    val schemaVersion: Int = 1,
    val appVersion: String,
    val lastUpdated: String,
    val entries: List<JournalEntry>
) {
    init {
        require(schemaVersion == 1) { "To schemaVersion prepei na einai akribos 1" }
        require(lastUpdated.matches(Regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))) {
            "To lastUpdated prepei na einai ISO-8601 UTC me whole seconds"
        }
    }
}

/**
 * Manifest Antigrafou Asfaleias (manifest.json).
 */
@Serializable
data class BackupManifest(
    val schemaVersion: Int = 1,
    val backupTimestamp: String,
    val appVersion: String,
    val entriesCount: Int,
    val entries: List<JournalEntry>,
    val agentMemory: AgentMemory? = null
) {
    init {
        require(schemaVersion == 1) { "To schemaVersion prepei na einai akribos 1" }
        require(backupTimestamp.matches(Regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))) {
            "To backupTimestamp prepei na einai ISO-8601 UTC me whole seconds"
        }
        require(entriesCount in 0..50000) { "To entriesCount prepei na einai metaxy 0 kai 50000" }
        require(entries.size <= 50000) { "Yperbasi oriou 50000 entries sto backup manifest" }
    }
}
