import time
import urllib.request
import json
import sys
import subprocess

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

run_id = sys.argv[1] if len(sys.argv) > 1 else "37497525081"
token = get_auth_token()
headers = {"User-Agent": "Mozilla/5.0"}
if token:
    headers["Authorization"] = f"Bearer {token}"

for i in range(25):
    try:
        req = urllib.request.Request(
            f"https://api.github.com/repos/train-cell/R0lling/actions/runs/{run_id}/jobs",
            headers=headers
        )
        data = json.loads(urllib.request.urlopen(req).read().decode("utf-8"))
        jobs = data.get("jobs", [])
        statuses = [f"{j['name']}: {j['status']} ({j['conclusion']})" for j in jobs]
        print(f"[{i+1}/25] " + " | ".join(statuses))
        if jobs and all(j['status'] == 'completed' for j in jobs):
            break
    except Exception as e:
        print(f"[{i+1}/25] Polling error: {e}")
    time.sleep(12)
