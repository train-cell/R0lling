import time
import urllib.request
import json
import sys

run_id = sys.argv[1] if len(sys.argv) > 1 else "37495375974"

for i in range(12):
    try:
        req = urllib.request.Request(
            f"https://api.github.com/repos/train-cell/R0lling/actions/runs/{run_id}/jobs",
            headers={"User-Agent": "Mozilla/5.0"}
        )
        data = json.loads(urllib.request.urlopen(req).read().decode("utf-8"))
        jobs = data.get("jobs", [])
        statuses = [f"{j['name']}: {j['status']} ({j['conclusion']})" for j in jobs]
        print(f"[{i+1}/12] " + " | ".join(statuses))
        if jobs and all(j['status'] == 'completed' for j in jobs):
            break
    except Exception as e:
        print(f"[{i+1}/12] Polling error: {e}")
    time.sleep(10)
