using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace R0lling.Windows.Core.Models;

/// <summary>
/// Pigi proelefsis kataxwrisis hmerologiou (1:1 me to r0lling-exchange-v1.schema.json).
/// </summary>
[JsonConverter(typeof(JsonStringEnumConverter))]
public enum EntrySource
{
    [JsonPropertyName("manual")]
    Manual,
    [JsonPropertyName("glasses")]
    Glasses,
    [JsonPropertyName("glasses_clip")]
    GlassesClip,
    [JsonPropertyName("voice")]
    Voice,
    [JsonPropertyName("import")]
    Import,
    [JsonPropertyName("ai")]
    Ai
}

/// <summary>
/// Typos synimennou arxeiou.
/// </summary>
[JsonConverter(typeof(JsonStringEnumConverter))]
public enum MediaType
{
    [JsonPropertyName("photo")]
    Photo,
    [JsonPropertyName("video")]
    Video,
    [JsonPropertyName("clip")]
    Clip,
    [JsonPropertyName("audio")]
    Audio
}

/// <summary>
/// Synimmeno polymeso me aystira validation patterns.
/// </summary>
public record MediaAttachment(
    [property: JsonPropertyName("id")] string Id,
    [property: JsonPropertyName("relativePath")] string RelativePath,
    [property: JsonPropertyName("mediaType")] MediaType MediaType,
    [property: JsonPropertyName("byteSize")] long ByteSize,
    [property: JsonPropertyName("captureTimestamp")] string CaptureTimestamp,
    [property: JsonPropertyName("hasAudio")] bool HasAudio,
    [property: JsonPropertyName("originalFilename")] string? OriginalFilename = null,
    [property: JsonPropertyName("durationSeconds")] double? DurationSeconds = null,
    [property: JsonPropertyName("width")] int? Width = null,
    [property: JsonPropertyName("height")] int? Height = null
)
{
    public static readonly Regex UuidPattern = new(@"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$", RegexOptions.Compiled);
    public static readonly Regex TimestampPattern = new(@"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", RegexOptions.Compiled);

    public bool IsValid()
    {
        if (!UuidPattern.IsMatch(Id)) return false;
        if (!TimestampPattern.IsMatch(CaptureTimestamp)) return false;
        if (ByteSize < 0) return false;

        return MediaType switch
        {
            MediaType.Photo => RelativePath.StartsWith("Photos/"),
            MediaType.Video => RelativePath.StartsWith("Videos/"),
            MediaType.Clip => RelativePath.StartsWith("Clips/"),
            MediaType.Audio => RelativePath.StartsWith("Audio/"),
            _ => false
        };
    }
}

/// <summary>
/// Kataxwrish Hmerologiou sto R0lling Windows Core.
/// </summary>
public record JournalEntry(
    [property: JsonPropertyName("id")] string Id,
    [property: JsonPropertyName("timestamp")] string Timestamp,
    [property: JsonPropertyName("timeZoneIdentifier")] string TimeZoneIdentifier,
    [property: JsonPropertyName("content")] string Content,
    [property: JsonPropertyName("source")] EntrySource Source,
    [property: JsonPropertyName("isFavorite")] bool IsFavorite,
    [property: JsonPropertyName("lastModified")] string LastModified,
    [property: JsonPropertyName("title")] string? Title = null,
    [property: JsonPropertyName("tags")] IReadOnlyList<string>? Tags = null,
    [property: JsonPropertyName("locationName")] string? LocationName = null,
    [property: JsonPropertyName("attachments")] IReadOnlyList<MediaAttachment>? Attachments = null
);

/// <summary>
/// Mnimi tou AI Agent sto Windows Core.
/// </summary>
public record AgentMemory(
    [property: JsonPropertyName("memoryNotes")] string MemoryNotes,
    [property: JsonPropertyName("userPreferences")] string UserPreferences,
    [property: JsonPropertyName("openLoops")] string OpenLoops,
    [property: JsonPropertyName("lastUpdated")] string LastUpdated
);

/// <summary>
/// Topiko arxeio hmerologiou (journal_v1.json).
/// </summary>
public record JournalFile(
    [property: JsonPropertyName("schemaVersion")] int SchemaVersion,
    [property: JsonPropertyName("appVersion")] string AppVersion,
    [property: JsonPropertyName("lastUpdated")] string LastUpdated,
    [property: JsonPropertyName("entries")] IReadOnlyList<JournalEntry> Entries
);

/// <summary>
/// Manifest Antigrafou Asfaleias (manifest.json).
/// </summary>
public record BackupManifest(
    [property: JsonPropertyName("schemaVersion")] int SchemaVersion,
    [property: JsonPropertyName("backupTimestamp")] string BackupTimestamp,
    [property: JsonPropertyName("appVersion")] string AppVersion,
    [property: JsonPropertyName("entriesCount")] int EntriesCount,
    [property: JsonPropertyName("entries")] IReadOnlyList<JournalEntry> Entries,
    [property: JsonPropertyName("agentMemory")] AgentMemory? AgentMemory = null
);
