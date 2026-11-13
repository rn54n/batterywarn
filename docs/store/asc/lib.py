from asc import call
def ok(label, s, j):
    good = s in (200, 201, 204)
    print(("OK  " if good else "ERR ") + label, s, "" if good else [e.get("detail") for e in j.get("errors", [])] or j)
    return j if good else None
def get_all(path):
    out, inc, url = [], [], path
    while url:
        s, j = call("GET", url if url.startswith("/") else url.replace("https://api.appstoreconnect.apple.com", ""))
        if s != 200: raise SystemExit(f"GET {url}: {s} {j}")
        out += j.get("data", []); inc += j.get("included", [])
        url = j.get("links", {}).get("next")
    return out, inc
