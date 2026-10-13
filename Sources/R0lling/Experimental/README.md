# Experimental helpers (P1-04 / FREEZE)

The helpers below remain outside product surfaces and are not full product features. Their types are retained for possible future work; moving them here does not add feeds, callers, UI, or readiness. The Obsidian watcher is the limited exception: AppState starts a debounced monitor for the selected vault and existing nested directories; directory additions/removals and root/nested replacements at the same path are reconciled by directory identity after an event. A reconciliation failure now stops the sources and reports an error in Settings. It reports directory-entry activity only. It does not read/import vault content, synchronize changes, or reliably observe edits to file contents within existing directories. Readiness remains false until Apple Files-provider and device behavior are verified.

| File | Flag (`FeatureReadinessRegistry`) | Status |
|---|---|---|
| `SpatialAudioProcessor.swift` | `spatialAudio` · ready=false | orphan math |
| `MetalFrameBufferPool.swift` | `metalPool` · ready=false | orphan · όχι MetalKit |
| `ClipWatermarkExporter.swift` | `watermark` · ready=false | AVFoundation/Core Animation overlay export and MediaViewer share path implemented; readiness stays gated pending Apple build and rendered-video verification |
| `HyperlapseTripCompressor.swift` | `hyperlapse` · ready=false | GPS-sample route/frame selector only; no location/camera capture, video mux, or product UI |
| `LocalWhisperOfflineService.swift` | `whisperStub` · ready=false | fail-closed stub without model weights or product caller; no UI claims offline Whisper |
| `ProximityAlertManager.swift` | `proximity` · ready=false | no location/vision feed or product caller |
| `PseudoLexicalVectorSearchEngine.swift` | `pseudoVectorSearch` · ready=false | FNV pseudo-embeddings only; no product caller or CLIP model |
| `TurnTakingGuard.swift` | `turnTaking` · ready=false | no VAD/microphone feed or speech caller |
| `ObsidianFileWatcher.swift` | `fileWatcher` · ready=false | AppState status-only recursive directory-entry hint · focused lifecycle/tree tests pass 19/19; Darwin dispatch and Files-provider behavior unverified |

**Policy:** frozen helpers stay out of product surfaces until their documented inputs and acceptance gates exist. The watcher stays Experimental and `ready=false` until its Apple filesystem, security-scope, and UI behavior are verified.
