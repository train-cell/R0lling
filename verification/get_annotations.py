import urllib.request
import json
import sys

run_id = sys.argv[1] if len(sys.argv) > 1 else "37495375974"

req = urllib.request.Request(
    f"https://api.github.com/repos/train-cell/R0lling/actions/runs/{run_id}/jobs",
    headers={"User-Agent": "Mozilla/5.0"}
)
jobs = json.loads(urllib.request.urlopen(req).read().decode("utf-8"))["jobs"]
swift_job = [j for j in jobs if "Swift" in j["name"]][0]
job_id = swift_job["id"]
print(f"Checking Job ID: {job_id} ({swift_job['name']}) - {swift_job['conclusion']}")

ann_req = urllib.request.Request(
    f"https://api.github.com/repos/train-cell/R0lling/check-runs/{job_id}/annotations",
    headers={"User-Agent": "Mozilla/5.0"}
)
ann = json.loads(urllib.request.urlopen(ann_req).read().decode("utf-8"))
print(f"Total annotations: {len(ann)}")
for a in ann:
    print(f"{a.get('path')}:{a.get('start_line')}: [{a.get('annotation_level')}] {a.get('message')}")
