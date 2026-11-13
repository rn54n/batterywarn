"""Waits until Apple has processed a build. Usage: python3 -I wait_build.py <appId> <buildNumber>"""
import sys, time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from asc import call

app, number = sys.argv[1], sys.argv[2]
for attempt in range(60):
    s, b = call("GET", f"/v1/builds?filter[app]={app}&filter[version]={number}&fields[builds]=version,processingState,uploadedDate")
    builds = b.get("data", [])
    state = builds[0]["attributes"]["processingState"] if builds else "NOT_LISTED"
    print(time.strftime("%H:%M:%S"), state, flush=True)
    if state in ("VALID", "FAILED", "INVALID"):
        sys.exit(0 if state == "VALID" else 1)
    time.sleep(30)
sys.exit(2)
