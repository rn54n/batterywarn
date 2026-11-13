"""Small App Store Connect API client. The key file is only passed to openssl, never read or printed here.

  python3 -I asc.py GET  /v1/apps?filter[bundleId]=...
  python3 -I asc.py POST /v1/bundleIds body.json

Credentials stay outside the repo, in the environment: ASC_KEY_ID, ASC_ISSUER and optionally ASC_KEY
(path to the .p8 file, default ~/.private_keys/AuthKey_<ASC_KEY_ID>.p8).
"""
import base64, json, os, pathlib, subprocess, sys, time, urllib.error, urllib.request

KEY_ID = os.environ.get("ASC_KEY_ID") or sys.exit("Set ASC_KEY_ID and ASC_ISSUER")
ISSUER = os.environ.get("ASC_ISSUER") or sys.exit("Set ASC_KEY_ID and ASC_ISSUER")
KEY = pathlib.Path(os.environ.get("ASC_KEY") or pathlib.Path.home() / ".private_keys" / f"AuthKey_{KEY_ID}.p8")


def b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def token() -> str:
    now = int(time.time())
    head = b64(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}).encode())
    body = b64(json.dumps({"iss": ISSUER, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"}).encode())
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", str(KEY)], input=f"{head}.{body}".encode(),
                         capture_output=True, check=True).stdout
    # DER ECDSA signature -> raw r||s, 32 bytes each.
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    parts = []
    for _ in range(2):
        assert der[i] == 2
        n = der[i + 1]
        parts.append(der[i + 2:i + 2 + n].lstrip(b"\x00").rjust(32, b"\x00"))
        i += 2 + n
    return f"{head}.{body}.{b64(parts[0] + parts[1])}"


def call(method: str, path: str, body=None):
    req = urllib.request.Request("https://api.appstoreconnect.apple.com" + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, {"raw": raw.decode(errors="replace")[:400]}


if __name__ == "__main__":
    body = json.load(open(sys.argv[3])) if len(sys.argv) > 3 else None
    status, data = call(sys.argv[1], sys.argv[2], body)
    print(status)
    print(json.dumps(data, indent=1)[:6000])
