#!/usr/bin/env python3
import os
import socket
import threading


LISTEN_HOST = os.environ.get("DASHBOARD_PROXY_LISTEN_HOST", "0.0.0.0")
LISTEN_PORT = int(os.environ.get("DASHBOARD_PROXY_LISTEN_PORT", "9120"))
UPSTREAM_HOST = os.environ.get("DASHBOARD_PROXY_UPSTREAM_HOST", "127.0.0.1")
UPSTREAM_PORT = int(os.environ.get("DASHBOARD_PROXY_UPSTREAM_PORT", "9121"))


def pipe(client):
    try:
        upstream = socket.create_connection((UPSTREAM_HOST, UPSTREAM_PORT), timeout=10)
    except OSError:
        client.close()
        return

    def copy(source, target):
        try:
            while True:
                chunk = source.recv(65536)
                if not chunk:
                    break
                target.sendall(chunk)
        except OSError:
            pass
        finally:
            for sock in (source, target):
                try:
                    sock.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass

    threads = [
        threading.Thread(target=copy, args=(client, upstream), daemon=True),
        threading.Thread(target=copy, args=(upstream, client), daemon=True),
    ]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    for sock in (client, upstream):
        try:
            sock.close()
        except OSError:
            pass


def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((LISTEN_HOST, LISTEN_PORT))
    server.listen(128)
    print(
        f"Hermes dashboard proxy listening on {LISTEN_HOST}:{LISTEN_PORT} "
        f"-> {UPSTREAM_HOST}:{UPSTREAM_PORT}",
        flush=True,
    )
    while True:
        client, _ = server.accept()
        thread = threading.Thread(target=pipe, args=(client,), daemon=True)
        thread.start()


if __name__ == "__main__":
    main()
