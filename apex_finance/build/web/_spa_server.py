"""Tiny SPA-fallback HTTP server."""
import os, sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

_ASSET_EXT = {".js",".css",".html",".json",".map",".png",".jpg",".jpeg",".gif",".svg",".webp",".ico",".woff",".woff2",".ttf",".otf",".wasm",".txt",".xml",".mp3",".mp4"}

class SpaHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        abs_path = self.translate_path(self.path.split("?", 1)[0])
        if not os.path.exists(abs_path) or (os.path.isdir(abs_path) and not os.path.exists(os.path.join(abs_path, "index.html"))):
            _, ext = os.path.splitext(abs_path)
            if ext.lower() not in _ASSET_EXT:
                self.path = "/index.html"
        return super().do_GET()
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        return super().end_headers()

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 9090
    with ThreadingHTTPServer(("0.0.0.0", port), SpaHandler) as srv:
        print(f"SPA server listening on http://localhost:{port}/")
        srv.serve_forever()
