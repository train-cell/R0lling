# Experimental / Orphans (P1-04)

Wave-B modules **χωρίς product caller**. Κρατιούνται για μελλοντικό wire · **όχι** UI surface.

| File | Flag (`FeatureReadinessRegistry`) | Status |
|---|---|---|
| `SpatialAudioProcessor.swift` | `spatialAudio` · ready=false | orphan math |
| `MetalFrameBufferPool.swift` | `metalPool` · ready=false | orphan · όχι MetalKit |
| `ClipWatermarkExporter.swift` | `watermark` · ready=false | orphan schema |
| `ObsidianFileWatcher.swift` | `fileWatcher` · ready=false | orphan · όχι bridge |

**Policy:** FREEZE μέχρι A05/A10 device proof (`docs/DECISIONS.md` §5).  
**DoD closed:** αρχεία σε `Experimental/` + `ready=false` + 0 AppState holds.
