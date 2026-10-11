"""Serve only the design and documentation on loopback for local review."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]


class PreviewHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def send_head(self):
        raw_path = unquote(urlsplit(self.path).path)
        if raw_path == "/":
            self.send_response(302)
            self.send_header("Location", "/design/")
            self.end_headers()
            return None
        candidate = (ROOT / raw_path.lstrip("/")).resolve()
        if not candidate.is_relative_to(ROOT):
            self.send_error(404)
            return None
        relative = candidate.relative_to(ROOT)
        if not relative.parts or relative.parts[0] not in {"design", "docs"}:
            self.send_error(404)
            return None
        if any(part.startswith(".") for part in relative.parts):
            self.send_error(404)
            return None
        if candidate.is_dir() and not (candidate / "index.html").is_file():
            self.send_error(404)
            return None
        return super().send_head()

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        super().end_headers()


if __name__ == "__main__":
    print("Preview: http://127.0.0.1:4173/design/", flush=True)
    ThreadingHTTPServer(("127.0.0.1", 4173), PreviewHandler).serve_forever()
