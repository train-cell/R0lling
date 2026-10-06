import sys
import subprocess
import urllib.request
import zipfile
import io
import os
import json

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

run_id = sys.argv[1] if len(sys.argv) > 1 else "37542180604"
token = get_auth_token()
headers = {"User-Agent": "Mozilla/5.0"}
if token:
    headers["Authorization"] = f"Bearer {token}"

req = urllib.request.Request(
    f"https://api.github.com/repos/train-cell/R0lling/actions/runs/{run_id}/artifacts",
    headers=headers
)

try:
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode("utf-8"))
except Exception as e:
    print(f"Failed to fetch artifacts for run {run_id}: {e}")
    sys.exit(1)

artifacts = data.get("artifacts", [])
print(f"Found {len(artifacts)} artifacts for run {run_id}.")
target_art = None
for a in artifacts:
    print(f" - {a.get('name')} (id={a.get('id')}, size={a.get('size_in_bytes')} bytes)")
    if "ipa" in a.get("name", "").lower():
        target_art = a
        break

if not target_art and artifacts:
    target_art = artifacts[0]

if not target_art:
    print("No artifact available yet.")
    sys.exit(0)

artifact_id = target_art["id"]
print(f"Downloading artifact {target_art['name']} (id={artifact_id})...")

class NoRedirectHandler(urllib.request.HTTPRedirectHandler):
    def http_error_302(self, req, fp, code, msg, headers):
        return headers

opener = urllib.request.build_opener(NoRedirectHandler)
down_req = urllib.request.Request(
    f"https://api.github.com/repos/train-cell/R0lling/actions/artifacts/{artifact_id}/zip",
    headers=headers
)

res = opener.open(down_req)
loc = res.get("Location")
if loc:
    print("Fetching artifact zip from storage...")
    storage_req = urllib.request.Request(loc, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(storage_req) as resp:
        zip_data = resp.read()
    print(f"Downloaded {len(zip_data)} bytes.")
    os.makedirs("build_artifacts", exist_ok=True)
    with open("build_artifacts/R0lling-iOS-IPA.zip", "wb") as f:
        f.write(zip_data)
    with zipfile.ZipFile(io.BytesIO(zip_data)) as z:
        print("Zip contents:", z.namelist())
        z.extractall("build_artifacts")
    print("Extracted successfully to build_artifacts/")
else:
    print(f"No redirect location returned. Headers: {res.headers}")
