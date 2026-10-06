import urllib.request
import json
import sys

job_id = sys.argv[1] if len(sys.argv) > 1 else "112378434854"

req = urllib.request.Request(
    f"https://api.github.com/repos/train-cell/R0lling/actions/jobs/{job_id}",
    headers={"User-Agent": "Mozilla/5.0"}
)
job = json.loads(urllib.request.urlopen(req).read().decode("utf-8"))
print(f"Job: {job['name']} - {job['status']} ({job['conclusion']})")
for s in job.get("steps", []):
    print(f"Step {s['number']}: {s['name']} -> {s['status']} ({s['conclusion']})")
