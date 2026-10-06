import urllib.request
import json
import time

req = urllib.request.Request("https://api.github.com/rate_limit", headers={"User-Agent": "Mozilla/5.0"})
try:
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        core = data["resources"]["core"]
        now = time.time()
        print(f"Remaining: {core['remaining']}/{core['limit']}, Resets in: {int(core['reset'] - now)}s")
except urllib.error.HTTPError as e:
    reset = e.headers.get("x-ratelimit-reset")
    now = time.time()
    diff = int(float(reset) - now) if reset else "?"
    print(f"Rate limited! Resets in: {diff}s")
