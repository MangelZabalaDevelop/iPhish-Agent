#!/usr/bin/env python3
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from http.client import HTTPConnection
from urllib.parse import urlsplit


UPSTREAM_HOST = os.environ.get("GOPHISH_UPSTREAM_HOST", "127.0.0.1")
UPSTREAM_PORT = int(os.environ.get("GOPHISH_UPSTREAM_PORT", "3333"))
PROXY_PREFIX = os.environ.get("PROXY_PREFIX", "/projects/iphish-agent/applications/GoPhish").rstrip("/")
LISTEN_HOST = os.environ.get("GOPHISH_PROXY_HOST", "0.0.0.0")
LISTEN_PORT = int(os.environ.get("GOPHISH_PROXY_PORT", "3334"))


class GoPhishProxy(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def upstream_path(self):
        path = urlsplit(self.path).path
        query = urlsplit(self.path).query
        if path == PROXY_PREFIX:
            path = "/"
        elif path.startswith(PROXY_PREFIX + "/"):
            path = path[len(PROXY_PREFIX):]
        if not path:
            path = "/"
        return path + (("?" + query) if query else "")

    def rewrite_location(self, value):
        if value.startswith("/"):
            return PROXY_PREFIX + value
        return value

    def rewrite_body(self, body, content_type):
        if not content_type.startswith("text/html"):
            return body
        text = body.decode("utf-8", errors="replace")
        replacements = {
            'href="/': f'href="{PROXY_PREFIX}/',
            'src="/': f'src="{PROXY_PREFIX}/',
            'action="/': f'action="{PROXY_PREFIX}/',
            'url(/': f'url({PROXY_PREFIX}/',
        }
        for old, new in replacements.items():
            text = text.replace(old, new)
        return text.encode("utf-8")

    def proxy(self, include_body=True):
        body = None
        if "Content-Length" in self.headers:
            body = self.rfile.read(int(self.headers["Content-Length"]))

        headers = {k: v for k, v in self.headers.items() if k.lower() not in {"host", "accept-encoding", "connection"}}
        headers["Host"] = f"{UPSTREAM_HOST}:{UPSTREAM_PORT}"
        headers["X-Forwarded-Prefix"] = PROXY_PREFIX

        conn = HTTPConnection(UPSTREAM_HOST, UPSTREAM_PORT, timeout=30)
        try:
            conn.request(self.command, self.upstream_path(), body=body, headers=headers)
            resp = conn.getresponse()
            data = resp.read()
            content_type = resp.getheader("Content-Type", "")
            data = self.rewrite_body(data, content_type)

            self.send_response(resp.status, resp.reason)
            for key, value in resp.getheaders():
                lower = key.lower()
                if lower in {"content-length", "connection", "transfer-encoding"}:
                    continue
                if lower == "location":
                    value = self.rewrite_location(value)
                self.send_header(key, value)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Connection", "close")
            self.end_headers()
            if include_body:
                self.wfile.write(data)
        finally:
            conn.close()

    def do_HEAD(self):
        self.proxy(include_body=False)

    def do_GET(self):
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
    print(f"GoPhish Workbench proxy listening on {LISTEN_HOST}:{LISTEN_PORT} -> {UPSTREAM_HOST}:{UPSTREAM_PORT}", flush=True)
    server.serve_forever()
