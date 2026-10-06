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

job_id = sys.argv[1] if len(sys.argv) > 1 else "112381778977"

# Check annotations
ann_req = urllib.request.Request(f"https://api.github.com/repos/train-cell/R0lling/check-runs/{job_id}/annotations", headers=headers)
try:
    ann = json.loads(urllib.request.urlopen(ann_req).read().decode("utf-8"))
    print(f"Total annotations for {job_id}: {len(ann)}")
    for a in ann:
        print(f"{a.get('path')}:{a.get('start_line')}: [{a.get('annotation_level')}] {a.get('message')}")
except Exception as e:
    print(f"Annotation error: {e}")

# Check job logs if annotations are empty
log_req = urllib.request.Request(f"https://api.github.com/repos/train-cell/R0lling/actions/jobs/{job_id}/logs", headers=headers)
try:
    with urllib.request.urlopen(log_req) as resp:
        log_text = resp.read().decode("utf-8", errors="ignore")
        lines = [l.strip() for l in log_text.splitlines() if l.strip()]
        print(f"\n--- Tail of Job Log (last 60 lines) ---")
        for l in lines[-60:]:
            print(l)
except Exception as e:
    print(f"Log error: {e}")
