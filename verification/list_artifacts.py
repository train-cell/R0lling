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
run_id = sys.argv[1] if len(sys.argv) > 1 else "37497525081"

req = urllib.request.Request(
    f"https://api.github.com/repos/train-cell/R0lling/actions/runs/{run_id}/artifacts",
    headers={"User-Agent": "Mozilla/5.0", "Authorization": f"Bearer {token}"}
)
data = json.loads(urllib.request.urlopen(req).read().decode("utf-8"))
for a in data.get("artifacts", []):
    size_mb = round(a["size_in_bytes"] / (1024 * 1024), 2)
    print(f"Artifact: {a['name']} | Size: {size_mb} MB ({a['size_in_bytes']} bytes) | ID: {a['id']}")
