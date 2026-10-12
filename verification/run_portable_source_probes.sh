#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/r0lling-source-probes.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
cd "$repo_root"

cat > "$tmp_dir/ImageIO.swift" <<'SWIFT'
public enum ImageIOHarnessModule {}
SWIFT
swiftc -emit-module -module-name ImageIO \
  "$tmp_dir/ImageIO.swift" \
  -emit-module-path "$tmp_dir/ImageIO.swiftmodule"

swiftc -strict-concurrency=complete -I "$tmp_dir" \
  Sources/R0lling/Core/Models.swift \
  Sources/R0lling/AI/AIConnectorProtocol.swift \
  Sources/R0lling/AI/AIHTTPClient.swift \
  Sources/R0lling/AI/AIErrorTaxonomy.swift \
  Sources/R0lling/AI/HermesEndpointAsfaleia.swift \
  Sources/R0lling/AI/OutboundPIIRedactor.swift \
  Sources/R0lling/AI/OpenAIChatRequestBuilder.swift \
  Sources/R0lling/AI/AIRouter.swift \
  verification/ai_privacy_flow_probe.swift \
  -o "$tmp_dir/ai-privacy-flow"
"$tmp_dir/ai-privacy-flow"

swiftc -strict-concurrency=complete \
  Sources/R0lling/AI/AIConnectorProtocol.swift \
  Sources/R0lling/AI/AIHTTPClient.swift \
  Sources/R0lling/AI/AIErrorTaxonomy.swift \
  Sources/R0lling/AI/OutboundPIIRedactor.swift \
  Sources/R0lling/AI/OpenAIChatRequestBuilder.swift \
  verification/ai_request_size_probe.swift \
  -o "$tmp_dir/ai-request-size"
"$tmp_dir/ai-request-size"

swiftc -strict-concurrency=complete \
  Sources/R0lling/Core/BoundedRegularFileReader.swift \
  Sources/R0lling/Persistence/BackupRestoreEngine.swift \
  Sources/R0lling/Persistence/MediaStorageService.swift \
  verification/backup_restore_capacity_probe.swift \
  -o "$tmp_dir/backup-restore-capacity"
"$tmp_dir/backup-restore-capacity"

python3 - "$repo_root/Sources/R0lling/Core/SovereignOSServices.swift" "$tmp_dir/DeepWorkSessionManager.swift" <<'PY'
from pathlib import Path
import sys

source_path, output_path = map(Path, sys.argv[1:])
source = source_path.read_text(encoding="utf-8")
start_marker = "public enum DeepWorkSessionTiming {"
end_marker = "// MARK: - [14] Decision Journal & Bias Auditor"
start = source.index(start_marker)
end = source.index(end_marker, start)
output_path.write_text("import Foundation\n\n" + source[start:end], encoding="utf-8")
PY
swiftc -strict-concurrency=complete \
  "$tmp_dir/DeepWorkSessionManager.swift" \
  verification/deep_work_persistence_probe.swift \
  -o "$tmp_dir/deep-work-persistence"
"$tmp_dir/deep-work-persistence"

swiftc -strict-concurrency=complete \
  Sources/R0lling/Core/HealthMetricDisplayScale.swift \
  verification/health_metric_display_scale_probe.swift \
  -o "$tmp_dir/health-metric-scale"
"$tmp_dir/health-metric-scale"

swiftc -strict-concurrency=complete \
  Sources/R0lling/Glasses/MetaDATStreamBridge.swift \
  verification/meta_dat_bridge_probe.swift \
  -o "$tmp_dir/meta-dat-bridge"
"$tmp_dir/meta-dat-bridge"

swiftc -strict-concurrency=complete \
  Sources/R0lling/Glasses/MetaGlassesProtocol.swift \
  verification/glasses_primary_action_probe.swift \
  -o "$tmp_dir/glasses-primary-action"
"$tmp_dir/glasses-primary-action"

swiftc -strict-concurrency=complete \
  Sources/R0lling/AI/AIErrorTaxonomy.swift \
  Sources/R0lling/AI/HermesEndpointAsfaleia.swift \
  verification/hermes_endpoint_security_probe.swift \
  -o "$tmp_dir/hermes-endpoint-security"
"$tmp_dir/hermes-endpoint-security"

swiftc -strict-concurrency=complete \
  Sources/R0lling/AI/AssociativeKnowledgeGraphEngine.swift \
  verification/knowledge_graph_probe.swift \
  -o "$tmp_dir/knowledge-graph"
"$tmp_dir/knowledge-graph"

swiftc -strict-concurrency=complete \
  Sources/R0lling/Core/HealthKitAccessPresentation.swift \
  Sources/R0lling/Core/JournalTimeZoneIdentifier.swift \
  Sources/R0lling/Core/JournalSearchRequestGate.swift \
  Sources/R0lling/Core/FitnessActivitySnapshot.swift \
  verification/ui_state_probe.swift \
  -o "$tmp_dir/ui-state"
"$tmp_dir/ui-state"

swiftc -strict-concurrency=complete \
  Sources/R0lling/Obsidian/VaultDirectoryFileAccess.swift \
  verification/obsidian_vault_no_follow_probe.swift \
  -o "$tmp_dir/obsidian-no-follow"
"$tmp_dir/obsidian-no-follow"
