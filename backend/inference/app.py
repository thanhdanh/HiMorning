"""Deploy from this directory: python -m modal deploy app.py."""
import json
import subprocess
import time
import urllib.request
from pathlib import Path

import modal
from protocol import MODEL, MAX_BODY_BYTES, completion_request, parse_completion, validate_request

ROOT = Path(__file__).parent
PINS = json.loads((ROOT / "pins.json").read_text())
app = modal.App("himorning-staging")


def download_models():
    import hashlib
    import os
    destination = Path("/models")
    destination.mkdir(exist_ok=True)
    for kind in ("model", "projector"):
        artifact = PINS[kind]
        target = destination / artifact["file"]
        digest = hashlib.sha256()
        url = f"https://huggingface.co/{PINS['repository']}/resolve/{PINS['revision']}/{artifact['file']}"
        temporary = target.with_suffix(".partial")
        with urllib.request.urlopen(url, timeout=120) as response, temporary.open("wb") as output:
            while chunk := response.read(1024 * 1024):
                digest.update(chunk)
                output.write(chunk)
        if digest.hexdigest() != artifact["sha256"]:
            temporary.unlink(missing_ok=True)
            raise RuntimeError("Model checksum mismatch")
        os.replace(temporary, target)


inference_image = (
    modal.Image.from_registry(PINS["runtimeImage"], add_python="3.11")
    .dockerfile_commands("ENTRYPOINT []")
    .pip_install("Pillow==12.3.0")
    .run_function(download_models, timeout=1800)
    .add_local_file(ROOT / "protocol.py", "/root/protocol.py")
    .add_local_file(ROOT / "verdict.schema.json", "/root/verdict.schema.json")
)


@app.cls(image=inference_image, gpu="L4", cpu=2, memory=16384, region="ap-southeast",
         min_containers=0, max_containers=1, scaledown_window=60, timeout=180,
         startup_timeout=180, retries=0)
class Qwen:
    @modal.enter()
    def load(self):
        self.process = subprocess.Popen([
            "/app/llama-server", "-m", "/models/" + PINS["model"]["file"],
            "--mmproj", "/models/" + PINS["projector"]["file"],
            "--alias", MODEL, "--host", "127.0.0.1", "--port", "8080",
            "--ctx-size", "32768", "--parallel", "1", "--n-gpu-layers", "99", "--jinja",
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        deadline = time.monotonic() + 150
        while time.monotonic() < deadline:
            if self.process.poll() is not None:
                raise RuntimeError("Model server exited during startup")
            try:
                with urllib.request.urlopen("http://127.0.0.1:8080/health", timeout=2):
                    return
            except OSError:
                time.sleep(1)
        self.process.terminate()
        raise TimeoutError("Model startup deadline exceeded")

    @modal.exit()
    def stop(self):
        self.process.terminate()

    @modal.method()
    def verify(self, payload):
        validate_request(payload)
        remaining = (payload["deadlineAt"] - int(time.time() * 1000)) / 1000
        request = urllib.request.Request(
            "http://127.0.0.1:8080/v1/chat/completions",
            data=json.dumps(completion_request(payload)).encode(),
            headers={"Content-Type": "application/json"}, method="POST",
        )
        started = time.monotonic()
        with urllib.request.urlopen(request, timeout=min(remaining, 120)) as response:
            raw = response.read(65537)
        if len(raw) > 65536:
            raise ValueError("Model response too large")
        output = json.loads(raw)
        verdict = parse_completion(output)
        usage = output.get("usage", {})
        print(json.dumps({"event": "inference_finished", "model": MODEL,
                          "revision": PINS["revision"], "durationMs": int((time.monotonic()-started)*1000),
                          "inputTokens": usage.get("prompt_tokens"), "outputTokens": usage.get("completion_tokens")}))
        return verdict


gateway_image = modal.Image.debian_slim(python_version="3.11").pip_install_from_requirements(str(ROOT / "requirements.lock"))


@app.function(image=gateway_image, region="ap-southeast", routing_region="ap-south",
              min_containers=0, max_containers=1, scaledown_window=60, timeout=20)
@modal.asgi_app(requires_proxy_auth=True)
def gateway():
    import re
    from fastapi import FastAPI, HTTPException, Request
    service = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)

    def job(call_id):
        if not re.fullmatch(r"fc-[a-zA-Z0-9_-]{1,200}", call_id):
            raise HTTPException(400, "Invalid job ID")
        return modal.FunctionCall.from_id(call_id)

    @service.post("/jobs")
    async def start(request: Request):
        body = bytearray()
        async for chunk in request.stream():
            body.extend(chunk)
            if len(body) > MAX_BODY_BYTES:
                raise HTTPException(413, "Request too large")
        try:
            payload = validate_request(json.loads(body))
        except (ValueError, TypeError, OSError):
            raise HTTPException(400, "Invalid inference request") from None
        try:
            call = await Qwen().verify.spawn.aio(payload)
        except Exception:
            raise HTTPException(503, "Inference dispatch unavailable") from None
        return {"jobID": call.object_id}

    @service.get("/jobs/{call_id}")
    async def result(call_id: str):
        try:
            verdict = await job(call_id).get.aio(timeout=0)
            return {"status": "completed", "verdict": verdict}
        except TimeoutError:
            return {"status": "pending"}
        except modal.exception.OutputExpiredError:
            raise HTTPException(410, "Job expired") from None
        except HTTPException:
            raise
        except Exception:
            raise HTTPException(503, "Inference unavailable") from None

    @service.delete("/jobs/{call_id}")
    async def cancel(call_id: str):
        try:
            await job(call_id).cancel.aio()
        except HTTPException:
            raise
        except Exception:
            raise HTTPException(503, "Cancellation unavailable") from None
        return {"status": "cancelled"}

    return service
