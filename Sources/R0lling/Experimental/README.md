# Experimental helpers (P1-04)

Wave-B helpers remain gated and are not full product features. The Obsidian watcher is the limited exception: AppState starts a debounced monitor for the selected vault and existing nested directories; directory additions/removals and root/nested replacements at the same path are reconciled by directory identity after an event. A reconciliation failure now stops the sources and reports an error in Settings. It reports directory-entry activity only. It does not read/import vault content, synchronize changes, or reliably observe edits to file contents within existing directories. Readiness remains false until Apple Files-provider and device behavior are verified.

| File | Flag (`FeatureReadinessRegistry`) | Status |
|---|---|---|
| `SpatialAudioProcessor.swift` | `spatialAudio` · ready=false | orphan math |
| `MetalFrameBufferPool.swift` | `metalPool` · ready=false | orphan · όχι MetalKit |
| `ClipWatermarkExporter.swift` | `watermark` · ready=false | AVFoundation/Core Animation overlay export and MediaViewer share path implemented; readiness stays gated pending Apple build and rendered-video verification |
| `ObsidianFileWatcher.swift` | `fileWatcher` · ready=false | AppState status-only recursive directory-entry hint · focused lifecycle/tree tests pass 14/14; Darwin dispatch and Files-provider behavior unverified |

**Policy:** other Wave-B modules remain frozen until their device proof (`docs/DECISIONS.md` §5). The watcher stays Experimental and `ready=false` until its Apple filesystem, security-scope, and UI behavior are verified.
