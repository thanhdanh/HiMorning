import asyncio
import json
import time
import unittest
from unittest.mock import AsyncMock, patch
import app
from test_protocol import request


async def call(service, method, path, body=b""):
    messages = []
    delivered = False

    async def receive():
        nonlocal delivered
        if not delivered:
            delivered = True
            return {"type": "http.request", "body": body, "more_body": False}
        return {"type": "http.disconnect"}

    async def send(message):
        messages.append(message)

    await service({"type": "http", "asgi": {"version": "3.0"}, "http_version": "1.1",
                   "method": method, "scheme": "https", "path": path, "raw_path": path.encode(),
                   "query_string": b"", "root_path": "", "headers": [(b"content-type", b"application/json")],
                   "client": ("127.0.0.1", 1), "server": ("test", 443)}, receive, send)
    status = next(x["status"] for x in messages if x["type"] == "http.response.start")
    payload = b"".join(x.get("body", b"") for x in messages if x["type"] == "http.response.body")
    return status, json.loads(payload)


class GatewayTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.service = app.gateway.local()

    async def test_dispatch_get_and_cancel_use_existing_job_handle(self):
        data = request()
        data["deadlineAt"] = int(time.time() * 1000) + 180000
        with patch.object(app, "Qwen") as gpu:
            gpu.return_value.verify.spawn.aio = AsyncMock()
            gpu.return_value.verify.spawn.aio.return_value.object_id = "fc-test"
            status, result = await call(self.service, "POST", "/jobs", json.dumps(data).encode())
            self.assertEqual((status, result), (200, {"jobID": "fc-test"}))
            gpu.return_value.verify.spawn.aio.assert_awaited_once_with(data)
        with patch.object(app.modal.FunctionCall, "from_id") as handle:
            handle.return_value.get.aio = AsyncMock(side_effect=TimeoutError())
            self.assertEqual(await call(self.service, "GET", "/jobs/fc-test"), (200, {"status": "pending"}))
            handle.return_value.get.aio = AsyncMock(return_value={"status": "uncertain", "reps": [], "cue": "none"})
            status, result = await call(self.service, "GET", "/jobs/fc-test")
            self.assertEqual(status, 200)
            self.assertEqual(result["status"], "completed")
            handle.return_value.cancel.aio = AsyncMock()
            self.assertEqual(await call(self.service, "DELETE", "/jobs/fc-test"), (200, {"status": "cancelled"}))
            handle.return_value.cancel.aio.assert_awaited_once()

    async def test_invalid_expired_and_oversized_payloads_never_allocate_a_gpu(self):
        with patch.object(app, "Qwen") as gpu:
            for payload in (b"{", b"{}", json.dumps(request()).encode()):
                status, body = await call(self.service, "POST", "/jobs", payload)
                self.assertEqual(status, 400)
                self.assertEqual(body, {"detail": "Invalid inference request"})
            status, _ = await call(self.service, "POST", "/jobs", b"x" * (app.MAX_BODY_BYTES + 1))
            self.assertEqual(status, 413)
            gpu.assert_not_called()

    async def test_missing_jobs_and_provider_errors_are_sanitized(self):
        with patch.object(app.modal.FunctionCall, "from_id") as handle:
            handle.return_value.get.aio = AsyncMock(side_effect=RuntimeError("secret photo"))
            self.assertEqual(await call(self.service, "GET", "/jobs/fc-test"), (503, {"detail": "Inference unavailable"}))
            handle.return_value.get.aio = AsyncMock(side_effect=app.modal.exception.OutputExpiredError())
            self.assertEqual(await call(self.service, "GET", "/jobs/fc-test"), (410, {"detail": "Job expired"}))
            self.assertEqual((await call(self.service, "GET", "/jobs/forged"))[0], 400)
