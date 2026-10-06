import subprocess
import urllib.request
import json
import sys

def get_auth_token():
    try:
        proc = subprocess.Popen(
            ["git", "credential", "fill"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        out, _ = proc.communicate("protocol=https\nhost=github.com\n")
        for line in out.splitlines():
            if line.startswith("password="):
                return line.split("=", 1)[1].strip()
    except Exception:
        pass
    return None

token = get_auth_token()
headers = {"User-Agent": "Mozilla/5.0"}
if token:
    headers["Authorization"] = f"Bearer {token}"

run_id = sys.argv[1] if len(sys.argv) > 1 else None

if not run_id:
    # Get latest run
    req = urllib.request.Request("https://api.github.com/repos/train-cell/R0lling/actions/runs?per_page=3", headers=headers)
    runs = json.loads(urllib.request.urlopen(req).read().decode("utf-8"))["workflow_runs"]
    for r in runs:
        print(f"Run #{r['run_number']} (id={r['id']}): commit={r['head_commit']['id'][:7]} status={r['status']} conclusion={r['conclusion']} msg={r['head_commit']['message'].splitlines()[0]}")
    run_id = runs[0]["id"]

req = urllib.request.Request(f"https://api.github.com/repos/train-cell/R0lling/actions/runs/{run_id}/jobs", headers=headers)
jobs = json.loads(urllib.request.urlopen(req).read().decode("utf-8"))["jobs"]
print(f"\n--- Jobs for Run {run_id} ---")
for j in jobs:
    print(f"Job: {j['name']} (id={j['id']}): status={j['status']} conclusion={j['conclusion']}")
    for s in j.get("steps", []):
        if s.get("conclusion") in ["failure", "cancelled"] or s.get("status") == "in_progress":
            print(f"   Step {s['number']} [{s['name']}]: {s['status']} ({s['conclusion']})")
