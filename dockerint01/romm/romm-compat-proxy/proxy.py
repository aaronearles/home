#!/usr/bin/env python3
"""
romm-compat-proxy
-----------------
Sidecar proxy for Grout v4.8.x against RomM v4.9.x.

Root cause: RomM 4.9.0 (PR #3425) removed `files` from SimpleRomSchema
(the paginated GET /api/roms response). Grout 4.8.x expects `files` to be
present and crashes on download when the field is missing.

RomM 4.9.0 (PR #3490) re-added it as opt-in via `with_files=true`, but
Grout 4.8.x doesn't know to request it.

Fix: intercept GET /api/roms and inject `with_files=true`.
Everything else is a transparent passthrough.
"""

import os
import logging
from urllib.parse import urlencode, parse_qs

import httpx
from fastapi import FastAPI, Request, Response

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

ROMM_UPSTREAM = os.environ.get("ROMM_UPSTREAM", "http://romm:8080").rstrip("/")
LISTEN_PORT   = int(os.environ.get("LISTEN_PORT", "8888"))
LOG_LEVEL     = os.environ.get("LOG_LEVEL", "INFO").upper()

logging.basicConfig(level=LOG_LEVEL, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("romm-proxy")

app = FastAPI(title="romm-compat-proxy", docs_url=None, redoc_url=None)

# Shared async HTTP client.
# Setting Accept-Encoding to identity means RomM sends raw uncompressed
# responses, which httpx passes through as-is. Without this, httpx
# transparently decompresses gzip but still forwards the Content-Encoding:
# gzip header, causing double-decompression errors on the client side.
_client = httpx.AsyncClient(
    base_url=ROMM_UPSTREAM,
    follow_redirects=True,
    timeout=httpx.Timeout(connect=10, read=300, write=300, pool=10),
    headers={"Accept-Encoding": "identity"},
)

# Headers we must not forward on the way IN (request hop-by-hop)
HOP_BY_HOP_REQUEST = {
    "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
    "te", "trailers", "transfer-encoding", "upgrade", "host",
}

# Headers we must not forward on the way OUT (response hop-by-hop).
# NOTE: set-cookie is NOT here — it's an application header and must be
# forwarded so clients can maintain sessions. content-encoding is stripped
# because httpx decompresses the body but would otherwise still forward the
# header, causing double-decompression on the client.
HOP_BY_HOP_RESPONSE = {
    "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
    "te", "trailers", "transfer-encoding", "upgrade",
    "content-encoding",
}

# ---------------------------------------------------------------------------
# Request rewriting
# ---------------------------------------------------------------------------

def _inject_with_files(url_path: str, query_string: str) -> str:
    """Inject with_files=true into GET /api/roms if not already present."""
    if not url_path.rstrip("/").endswith("/api/roms"):
        return query_string

    params = parse_qs(query_string, keep_blank_values=True)
    if "with_files" not in params:
        params["with_files"] = ["true"]
        log.debug("Injected with_files=true into %s", url_path)

    return urlencode(params, doseq=True)


# ---------------------------------------------------------------------------
# Proxy handler
# ---------------------------------------------------------------------------

@app.api_route(
    "/{path:path}",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"],
)
async def proxy(request: Request, path: str) -> Response:
    url_path     = "/" + path
    query_string = request.url.query

    if request.method == "GET":
        query_string = _inject_with_files(url_path, query_string)

    upstream_url = f"{url_path}?{query_string}" if query_string else url_path

    # Strip request hop-by-hop headers, force identity encoding so upstream
    # never sends compressed responses
    forward_headers = {
        k: v for k, v in request.headers.items()
        if k.lower() not in HOP_BY_HOP_REQUEST
    }
    forward_headers["accept-encoding"] = "identity"

    log.debug("%s %s -> %s%s", request.method, request.url, ROMM_UPSTREAM, upstream_url)

    body = await request.body()

    upstream_resp = await _client.request(
        method=request.method,
        url=upstream_url,
        headers=forward_headers,
        content=body,
    )

    response_headers = {
        k: v for k, v in upstream_resp.headers.items()
        if k.lower() not in HOP_BY_HOP_RESPONSE
    }

    return Response(
        content=upstream_resp.content,
        status_code=upstream_resp.status_code,
        headers=response_headers,
        media_type=upstream_resp.headers.get("content-type"),
    )


# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn
    log.info("romm-compat-proxy starting on port %d -> %s", LISTEN_PORT, ROMM_UPSTREAM)
    uvicorn.run(app, host="0.0.0.0", port=LISTEN_PORT, log_level=LOG_LEVEL.lower())
