#!/usr/bin/env python3
import os
import sys
import mimetypes
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from http.client import HTTPConnection
from pathlib import Path
from urllib.parse import unquote, urlsplit


UPSTREAM_HOST = os.environ.get("GOPHISH_UPSTREAM_HOST", "127.0.0.1")
UPSTREAM_PORT = int(os.environ.get("GOPHISH_UPSTREAM_PORT", "3333"))
PHISH_UPSTREAM_PORT = int(os.environ.get("GOPHISH_PHISH_UPSTREAM_PORT", "8080"))
PROXY_PREFIX = os.environ.get("PROXY_PREFIX", "/projects/iphish-agent/applications/GoPhish").rstrip("/")
LANDING_PREFIX = PROXY_PREFIX + "/landing"
ASSET_PREFIX = PROXY_PREFIX + "/assets"
ASSET_ROOT = Path(os.environ.get("GOPHISH_ASSET_ROOT", "/project/data/hermes/generated-images")).resolve()
LISTEN_HOST = os.environ.get("GOPHISH_PROXY_HOST", "0.0.0.0")
LISTEN_PORT = int(os.environ.get("GOPHISH_PROXY_PORT", "3334"))


class GoPhishProxy(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def route(self):
        path = urlsplit(self.path).path
        query = urlsplit(self.path).query
        prefix = PROXY_PREFIX
        port = UPSTREAM_PORT
        if path == LANDING_PREFIX:
            path = "/"
            prefix = LANDING_PREFIX
            port = PHISH_UPSTREAM_PORT
        elif path.startswith(LANDING_PREFIX + "/"):
            path = path[len(LANDING_PREFIX):]
            prefix = LANDING_PREFIX
            port = PHISH_UPSTREAM_PORT
        elif path == PROXY_PREFIX:
            path = "/"
        elif path.startswith(PROXY_PREFIX + "/"):
            path = path[len(PROXY_PREFIX):]
        if not path:
            path = "/"
        return port, prefix, path + (("?" + query) if query else "")

    def rewrite_location(self, value, prefix):
        if value.startswith("/"):
            return prefix + value
        return value

    def rewrite_set_cookie(self, value, prefix):
        parts = [part.strip() for part in value.split(";")]
        rewritten = []
        saw_path = False
        for part in parts:
            if part.lower().startswith("path="):
                rewritten.append(f"Path={prefix}")
                saw_path = True
            else:
                rewritten.append(part)
        if not saw_path:
            rewritten.append(f"Path={prefix}")
        return "; ".join(rewritten)

    def send_legacy_cookie_clear_headers(self):
        expires = "Thu, 01 Jan 1970 00:00:00 GMT"
        for name in ("gophish", "_gorilla_csrf"):
            self.send_header("Set-Cookie", f"{name}=; Path=/; Expires={expires}; Max-Age=0; HttpOnly")

    def rewrite_body(self, body, content_type, prefix):
        is_html = content_type.startswith("text/html")
        is_javascript = "javascript" in content_type
        if not is_html and not is_javascript:
            return body
        text = body.decode("utf-8", errors="replace")
        if is_html:
            replacements = {
                'href="/': f'href="{prefix}/',
                'src="/': f'src="{prefix}/',
                'action="/': f'action="{prefix}/',
                'url(/': f'url({prefix}/',
            }
            for old, new in replacements.items():
                text = text.replace(old, new)

        root_paths = (
            "api",
            "campaigns",
            "groups",
            "templates",
            "landing_pages",
            "sending_profiles",
            "settings",
            "users",
            "webhooks",
            "login",
            "logout",
            "impersonate",
        )
        for root_path in root_paths:
            text = text.replace(f'"/{root_path}', f'"{prefix}/{root_path}')
            text = text.replace(f"'/{root_path}", f"'{prefix}/{root_path}")
        return text.encode("utf-8")

    def serve_asset(self, include_body=True):
        path = urlsplit(self.path).path
        if path == ASSET_PREFIX:
            self.send_error(404)
            return
        rel = unquote(path[len(ASSET_PREFIX):]).lstrip("/")
        target = (ASSET_ROOT / rel).resolve()
        try:
            target.relative_to(ASSET_ROOT)
        except ValueError:
            self.send_error(403)
            return
        if not target.is_file():
            self.send_error(404)
            return
        content_type = mimetypes.guess_type(str(target))[0] or "application/octet-stream"
        data = target.read_bytes() if include_body else b""
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(target.stat().st_size))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Connection", "close")
        self.end_headers()
        if include_body:
            self.wfile.write(data)

    def proxy(self, include_body=True):
        body = None
        if "Content-Length" in self.headers:
            body = self.rfile.read(int(self.headers["Content-Length"]))

        headers = {k: v for k, v in self.headers.items() if k.lower() not in {"host", "accept-encoding", "connection"}}
        port, prefix, path = self.route()
        headers["Host"] = f"{UPSTREAM_HOST}:{port}"
        headers["X-Forwarded-Prefix"] = PROXY_PREFIX
        conn = HTTPConnection(UPSTREAM_HOST, port, timeout=30)
        try:
            conn.request(self.command, path, body=body, headers=headers)
            resp = conn.getresponse()
            data = resp.read()
            content_type = resp.getheader("Content-Type", "")
            no_store = content_type.startswith("text/html") or "javascript" in content_type
            data = self.rewrite_body(data, content_type, prefix)

            self.send_response(resp.status, resp.reason)
            for key, value in resp.getheaders():
                lower = key.lower()
                if lower in {"content-length", "connection", "transfer-encoding"}:
                    continue
                if no_store and lower == "cache-control":
                    continue
                if lower == "location":
                    value = self.rewrite_location(value, prefix)
                elif lower == "set-cookie":
                    value = self.rewrite_set_cookie(value, prefix)
                self.send_header(key, value)
            if no_store:
                self.send_header("Cache-Control", "no-store")
            if prefix == PROXY_PREFIX:
                self.send_legacy_cookie_clear_headers()
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Connection", "close")
            self.end_headers()
            if include_body:
                self.wfile.write(data)
        finally:
            conn.close()

    def do_HEAD(self):
        path = urlsplit(self.path).path
        if path in {"/healthz", PROXY_PREFIX + "/healthz"}:
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", "2")
            self.send_header("Connection", "close")
            self.end_headers()
            return
        if path.startswith(ASSET_PREFIX + "/"):
            self.serve_asset(include_body=False)
            return
        self.proxy(include_body=False)

    def do_GET(self):
        path = urlsplit(self.path).path
        if path in {"/healthz", PROXY_PREFIX + "/healthz"}:
            data = b"ok"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(data)
            return
        if path.startswith(ASSET_PREFIX + "/"):
            self.serve_asset()
            return
        self.proxy()

    def do_POST(self):
        self.proxy()

    def do_PUT(self):
        self.proxy()

    def do_DELETE(self):
        self.proxy()

    def do_PATCH(self):
        self.proxy()


if __name__ == "__main__":
    server = ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), GoPhishProxy)
    print(
        f"GoPhish Workbench proxy listening on {LISTEN_HOST}:{LISTEN_PORT} -> "
        f"admin {UPSTREAM_HOST}:{UPSTREAM_PORT}, landing {UPSTREAM_HOST}:{PHISH_UPSTREAM_PORT}",
        flush=True,
    )
    server.serve_forever()
