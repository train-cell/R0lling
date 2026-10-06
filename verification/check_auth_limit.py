import subprocess
import urllib.request
import json
import time

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

req = urllib.request.Request("https://api.github.com/rate_limit", headers=headers)
try:
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        core = data["resources"]["core"]
        now = time.time()
        print(f"Authenticated Remaining: {core['remaining']}/{core['limit']}")
except Exception as e:
    print(f"Error checking rate limit: {e}")
