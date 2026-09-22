#!/usr/bin/env python3
"""Preview the static web build with correct WebAssembly MIME type."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm", ".pck": "application/octet-stream"}

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8060)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--directory", default=str(Path(__file__).resolve().parents[1] / "builds/web"))
    args = parser.parse_args()
    if not (Path(args.directory) / "index.html").is_file():
        raise SystemExit("Build first: python3 tools/build_web.py")
    server = ThreadingHTTPServer((args.host, args.port), partial(Handler, directory=args.directory))
    print(f"Breakfast Balls: http://{args.host}:{args.port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.server_close()
