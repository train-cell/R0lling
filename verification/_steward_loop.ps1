$purpose = "r0lling_gemini_steward"
$root = "C:\Users\skyd3\antigarvity\R0lling"
$promptPaths = @(
  "C:\Users\skyd3\.codex\.chatgpt-projects\g-p-6ac3f4632f388191b09477f82d69c31a"
)
$baseline = Get-Date
$ticks = 0
while ($true) {
  Start-Sleep -Seconds 180
  $ticks++
  $newMd = @()
  foreach ($base in @($root) + $promptPaths) {
    if (-not (Test-Path $base)) { continue }
    $newMd += Get-ChildItem -Path $base -Recurse -File -Filter "*.md" -ErrorAction SilentlyContinue |
      Where-Object {
        $_.LastWriteTime -gt $baseline -and (
          $_.Name -match 'GEMINI|gemini|Gemini|ANALYSIS|SuperFeature|handoff|HANDOFF' -or
          ($_.DirectoryName -match 'R0lling' -and $_.LastWriteTime -gt $baseline)
        )
      }
  }
  $newSwift = Get-ChildItem -Path "$root\Sources" -Recurse -File -Filter "*.swift" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt $baseline }
  $payload = @{
    prompt = "R0lling steward tick: review any new Gemini MD/diff, fix defects, re-verify, update docs if needed. Stop loop if stable and no new Gemini writes for 2 ticks."
    tick = $ticks
    new_md_count = @($newMd).Count
    new_swift_count = @($newSwift).Count
    new_md = @($newMd | Select-Object -First 15 -ExpandProperty FullName)
    newest_swift = @($newSwift | Sort-Object LastWriteTime -Descending | Select-Object -First 10 -ExpandProperty Name)
  } | ConvertTo-Json -Compress
  Write-Output "AGENT_LOOP_TICK_r0lling_gemini_steward $payload"
}
