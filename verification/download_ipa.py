import subprocess
import urllib.request
import zipfile
import io
import os

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
artifact_id = "11427938633"

class NoRedirectHandler(urllib.request.HTTPRedirectHandler):
    def http_error_302(self, req, fp, code, msg, headers):
        return headers

opener = urllib.request.build_opener(NoRedirectHandler)
req = urllib.request.Request(
    f"https://api.github.com/repos/train-cell/R0lling/actions/artifacts/{artifact_id}/zip",
    headers={"User-Agent": "Mozilla/5.0", "Authorization": f"Bearer {token}"}
)

res = opener.open(req)
loc = res.get("Location")
if loc:
    print("Downloading IPA zip from storage...")
    down_req = urllib.request.Request(loc, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(down_req) as resp:
        zip_data = resp.read()
        print(f"Downloaded {len(zip_data)} bytes.")
        os.makedirs("build_artifacts", exist_ok=True)
        with open("build_artifacts/R0lling-iOS-IPA.zip", "wb") as f:
            f.write(zip_data)
        
        with zipfile.ZipFile(io.BytesIO(zip_data)) as z:
            print("Zip contents:", z.namelist())
            z.extractall("build_artifacts")
        print("Extracted to build_artifacts/")
