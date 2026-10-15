"""One paid, synthetic remote compatibility check; requires configured budgets."""
import base64
import io
import json
import os
import time
import urllib.error
import urllib.request
from urllib.parse import urlparse
from PIL import Image
from protocol import MODEL


def synthetic_request(count=5):
    if count not in (5, 15, 25, 50, 100, 250):
        raise ValueError("Use 5, 15, 25, 50, 100 or 250 frames")
    frames = []
    for i in range(count):
        output = io.BytesIO()
        Image.new("RGB", (128, 128), ((i * 9) % 256, i, 80)).save(output, format="JPEG")
        frames.append({"id": f"f{i}", "timestampMs": i * 300,
                       "dataURL": "data:image/jpeg;base64," + base64.b64encode(output.getvalue()).decode()})
    return {"model": MODEL, "target": count // 5, "deadlineAt": int(time.time()*1000)+180000, "frames": frames}


def main():
    origin = os.environ["AI_BASE_URL"].rstrip("/")
    url = urlparse(origin)
    if url.scheme != "https" or not url.hostname.endswith(".modal.run") or url.path or url.query or url.fragment or url.username or url.password:
        raise ValueError("AI_BASE_URL must be a Modal HTTPS origin")
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, request, fp, code, message, headers, new_url):
            raise RuntimeError("Unexpected inference redirect")

    opener = urllib.request.build_opener(NoRedirect())
    headers = {"Content-Type": "application/json", "Modal-Key": os.environ["MODAL_PROXY_KEY"], "Modal-Secret": os.environ["MODAL_PROXY_SECRET"]}

    def call(method, path, body=None, authenticated=True):
        request = urllib.request.Request(origin+path, method=method, headers=headers if authenticated else {},
                                         data=json.dumps(body).encode() if body is not None else None)
        with opener.open(request, timeout=20) as response:
            raw = response.read(65537)
        if len(raw) > 65536:
            raise ValueError("Response too large")
        return json.loads(raw)

    try:
        call("GET", "/jobs/fc-auth-check", authenticated=False)
    except urllib.error.HTTPError as error:
        if error.code not in (401, 403):
            raise RuntimeError("Authentication preflight failed") from None
    else:
        raise RuntimeError("Unauthenticated gateway access was not rejected")
    job_id = None
    started = time.monotonic()
    try:
        job_id = call("POST", "/jobs", synthetic_request())["jobID"]
        delay = 2
        while time.monotonic()-started < 180:
            time.sleep(delay)
            response = call("GET", "/jobs/"+job_id)
            if response["status"] == "completed":
                verdict = response["verdict"]
                if verdict.get("status") not in ("uncertain", "incomplete") or verdict.get("reps") != []:
                    raise RuntimeError("Non-movement evidence was not conservatively rejected")
                print(json.dumps({"status": "passed", "durationSeconds": round(time.monotonic()-started, 2), "model": MODEL}))
                return
            delay = delay*2 if delay < 8 else 10
        raise TimeoutError("Cold-start smoke exceeded 180 seconds")
    finally:
        if job_id:
            try:
                call("DELETE", "/jobs/"+job_id)
            except Exception:
                pass  # Cleanup must not hide the original test result.


if __name__ == "__main__":
    main()
