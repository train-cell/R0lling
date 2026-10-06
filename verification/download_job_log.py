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
job_id = sys.argv[1] if len(sys.argv) > 1 else "112381778977"

class NoRedirectHandler(urllib.request.HTTPRedirectHandler):
    def http_error_302(self, req, fp, code, msg, headers):
        return headers

opener = urllib.request.build_opener(NoRedirectHandler)
req = urllib.request.Request(
    f"https://api.github.com/repos/train-cell/R0lling/actions/jobs/{job_id}/logs",
    headers={"User-Agent": "Mozilla/5.0", "Authorization": f"Bearer {token}"}
)

try:
    res = opener.open(req)
    loc = res.get("Location")
    if loc:
        # Download log without Authorization header
        log_req = urllib.request.Request(loc, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(log_req) as log_resp:
            log_text = log_resp.read().decode("utf-8", errors="ignore")
            with open("job_log.txt", "w", encoding="utf-8") as f:
                f.write(log_text)
            print(f"Successfully downloaded {len(log_text)} bytes to job_log.txt")
except Exception as e:
    print(f"Error fetching log: {e}")
