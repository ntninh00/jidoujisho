"""The HTTP API.

Every route but /api/health needs `Authorization: Bearer <token>`. Read
tokens can list, search and download; admin tokens can also upload, relabel
and delete. Repeated wrong tokens from one address are refused for a while.

    GET    /api/health
    GET    /api/me                               -> {"role": "admin" | "read"}
    GET    /api/dictionaries                     -> [dictionary, ...]
    GET    /api/dictionaries/{id}
    GET    /api/dictionaries/{id}/search?q=&limit=
    GET    /api/dictionaries/{id}/download       -> the original zip
    GET    /api/dictionaries/{id}/media?path=    -> a picture used by an entry
    GET    /api/dictionaries/{id}/styles         -> the dictionary's styles.css
    PUT    /api/dictionaries?name=&replace=      -> 202, body is the zip
    PATCH  /api/dictionaries/{id}                -> any of {"sourceLanguage", "targetLanguage", "note"}
    DELETE /api/dictionaries/{id}
"""

import hashlib
import hmac
import os
import queue
import re
import shutil
import threading
import time
import traceback
import uuid
import zipfile
from collections import defaultdict, deque
from contextlib import asynccontextmanager
from pathlib import Path, PurePosixPath

from starlette.applications import Starlette
from starlette.concurrency import run_in_threadpool
from starlette.datastructures import MutableHeaders
from starlette.middleware import Middleware
from starlette.requests import Request
from starlette.responses import FileResponse, JSONResponse, Response
from starlette.routing import Route

from . import config, indexer, search
from .checks import LANGUAGE, MEDIA_TYPES, Limits, Rejected, check_zip
from .store import Catalog

ID = re.compile(r"^[0-9a-f]{12}$")
MAX_MEDIA_BYTES = 16 * 1024 * 1024
MAX_STYLES_BYTES = 1024 * 1024
MAX_NOTE_LENGTH = 1000
FAILURE_WINDOW = 600
MAX_FAILURES = 10

# Nothing here is meant to run in a browser; refuse to if someone tries.
SECURITY_HEADERS = {
    "Content-Security-Policy": "default-src 'none'; sandbox",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "Cache-Control": "private, no-store",
}


class Problem(Exception):
    """A request that can't be served, with the status and a message for the
    person using the app."""

    def __init__(self, status: int, message: str) -> None:
        super().__init__(message)
        self.status = status
        self.message = message


class SecurityHeaders:
    """Adds [SECURITY_HEADERS] to every response that doesn't set its own."""

    def __init__(self, app) -> None:
        self.app = app

    async def __call__(self, scope, receive, send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        async def send_with_headers(message) -> None:
            if message["type"] == "http.response.start":
                headers = MutableHeaders(scope=message)
                for name, value in SECURITY_HEADERS.items():
                    if name not in headers:
                        headers.append(name, value)
            await send(message)

        await self.app(scope, receive, send_with_headers)


def create_app(settings: config.Settings | None = None) -> Starlette:
    settings = settings or config.load()
    settings.incoming_dir.mkdir(parents=True, exist_ok=True)
    catalog = Catalog(settings.catalog_path, settings.dictionaries_dir)
    limits = Limits(
        max_entries=settings.max_entries,
        max_uncompressed_bytes=settings.max_uncompressed_bytes,
        max_bank_bytes=settings.max_bank_bytes,
    )
    jobs: "queue.Queue[str | None]" = queue.Queue()
    failures: dict[str, deque] = defaultdict(deque)
    upload_lock = threading.Lock()

    # ---------- indexing, one dictionary at a time ----------

    def index_one(dictionary_id: str) -> None:
        if catalog.get(dictionary_id) is None:
            return
        catalog.set_status(dictionary_id, "indexing")
        zip_path = catalog.zip_path(dictionary_id)
        try:
            checked = check_zip(str(zip_path), limits)
            summary = indexer.build(str(zip_path), str(catalog.search_path(dictionary_id)), checked)
            if catalog.get(dictionary_id) is None:
                return
            catalog.set_indexed(
                dictionary_id, summary.kinds, summary.counts,
                summary.source_language, summary.target_language,
            )
        except Rejected as error:
            catalog.set_status(dictionary_id, "failed", str(error))
        except Exception:
            traceback.print_exc()
            catalog.set_status(dictionary_id, "failed", "Indexing stopped with an unexpected error.")

    def worker() -> None:
        while True:
            dictionary_id = jobs.get()
            if dictionary_id is None:
                return
            index_one(dictionary_id)

    @asynccontextmanager
    async def lifespan(app):
        for leftover in settings.incoming_dir.glob("*"):
            leftover.unlink(missing_ok=True)
        for dictionary_id in catalog.with_status("waiting", "indexing"):
            jobs.put(dictionary_id)
        thread = threading.Thread(target=worker, name="indexer", daemon=True)
        thread.start()
        yield
        jobs.put(None)

    # ---------- access ----------

    def client_of(request: Request) -> str:
        forwarded = request.headers.get("x-forwarded-for", "")
        return forwarded.split(",")[0].strip() or (request.client.host if request.client else "?")

    def role_of(request: Request) -> str:
        client = client_of(request)
        recent = failures[client]
        now = time.monotonic()
        while recent and now - recent[0] > FAILURE_WINDOW:
            recent.popleft()
        if len(recent) >= MAX_FAILURES:
            raise Problem(429, "Too many wrong tokens. Try again in a few minutes.")

        header = request.headers.get("authorization", "")
        token = header[7:].strip() if header[:7].lower() == "bearer " else ""
        if token:
            for role, tokens in (("admin", settings.admin_tokens), ("read", settings.read_tokens)):
                for known in tokens:
                    if hmac.compare_digest(token.encode(), known.encode()):
                        return role
        recent.append(now)
        raise Problem(401, "A valid token is needed.")

    def require_admin(request: Request) -> None:
        if role_of(request) != "admin":
            raise Problem(403, "Only an admin token can change the catalog.")

    def dictionary_of(request: Request, ready: bool = True) -> dict:
        dictionary_id = request.path_params["id"]
        entry = catalog.get(dictionary_id) if ID.match(dictionary_id) else None
        if entry is None:
            raise Problem(404, "No such dictionary.")
        if ready and entry["status"] != "ready":
            raise Problem(409, "This dictionary is still being prepared.")
        return entry

    # ---------- routes ----------

    async def health(request: Request) -> Response:
        return JSONResponse({"ok": True})

    async def me(request: Request) -> Response:
        return JSONResponse({"role": role_of(request)})

    def list_all(request: Request) -> Response:
        role_of(request)
        return JSONResponse(catalog.all())

    def get_one(request: Request) -> Response:
        role_of(request)
        return JSONResponse(dictionary_of(request, ready=False))

    def lookup(request: Request) -> Response:
        role_of(request)
        entry = dictionary_of(request)
        query = request.query_params.get("q", "")
        try:
            limit = int(request.query_params.get("limit", 20))
        except ValueError:
            limit = 20
        result = search.search(catalog.search_path(entry["id"]), query, limit)
        return JSONResponse({"dictionary": entry["id"], "query": query, **result})

    def download(request: Request) -> Response:
        role_of(request)
        entry = dictionary_of(request)
        name = re.sub(r"[^\w\-. ]+", "_", entry["title"]).strip() or "dictionary"
        return FileResponse(
            catalog.zip_path(entry["id"]),
            media_type="application/zip",
            filename=f"{name}.zip",
            headers={"ETag": f'"{entry["sha256"]}"'},
        )

    def media(request: Request) -> Response:
        role_of(request)
        entry = dictionary_of(request)
        path = request.query_params.get("path", "")
        kind = MEDIA_TYPES.get(PurePosixPath(path).suffix.lower())
        if not kind or not search.has_media(catalog.search_path(entry["id"]), path):
            raise Problem(404, "No such picture in this dictionary.")
        with zipfile.ZipFile(catalog.zip_path(entry["id"])) as archive:
            info = archive.getinfo(path)
            if info.file_size > MAX_MEDIA_BYTES:
                raise Problem(413, "That picture is too large to preview.")
            data = archive.read(info)
        return Response(
            data,
            media_type=kind,
            headers={"Content-Disposition": "attachment", "Cache-Control": "private, max-age=86400"},
        )

    def styles(request: Request) -> Response:
        role_of(request)
        entry = dictionary_of(request)
        with zipfile.ZipFile(catalog.zip_path(entry["id"])) as archive:
            try:
                info = archive.getinfo("styles.css")
            except KeyError:
                raise Problem(404, "This dictionary has no stylesheet.") from None
            if info.file_size > MAX_STYLES_BYTES:
                raise Problem(413, "This dictionary's stylesheet is too large to preview.")
            data = archive.read(info)
        return Response(
            data,
            media_type="text/css; charset=utf-8",
            headers={"Content-Disposition": "attachment", "Cache-Control": "private, max-age=86400"},
        )

    async def upload(request: Request) -> Response:
        require_admin(request)
        try:
            declared = int(request.headers.get("content-length", ""))
        except ValueError:
            raise Problem(411, "The upload needs a Content-Length.") from None
        if declared <= 0:
            raise Problem(400, "The upload is empty.")
        if declared > settings.max_upload_bytes:
            raise Problem(413, f"Dictionaries up to {settings.max_upload_bytes // (1024 * 1024)} MB can be uploaded.")
        free = shutil.disk_usage(settings.data_dir).free
        if free - declared * 3 < settings.min_free_bytes:
            raise Problem(507, "The server is too short of disk space for this dictionary.")
        if not upload_lock.acquire(blocking=False):
            raise Problem(429, "Another upload is in progress. Try again when it finishes.")

        temp = settings.incoming_dir / f"{uuid.uuid4().hex}.part"
        try:
            digest = hashlib.sha256()
            received = 0
            with open(temp, "wb") as out:
                async for chunk in request.stream():
                    received += len(chunk)
                    if received > declared or received > settings.max_upload_bytes:
                        raise Problem(413, "The upload is larger than it said it would be.")
                    digest.update(chunk)
                    out.write(chunk)
            if received != declared:
                raise Problem(400, "The upload was cut short.")

            try:
                checked = await run_in_threadpool(check_zip, str(temp), limits)
            except Rejected as error:
                raise Problem(400, str(error)) from None

            index = checked.index
            existing = catalog.find(index["title"], index["revision"])
            replaces = None
            if existing is not None:
                if request.query_params.get("replace") != "1":
                    raise Problem(409, f"{index['title']} ({index['revision']}) is already on the server.")
                # The one on the server stays until this one is ready, and
                # stays for good if this one fails.
                replaces = existing["id"]

            dictionary_id = uuid.uuid4().hex[:12]
            folder = catalog.folder(dictionary_id)
            folder.mkdir(parents=True)
            os.replace(temp, catalog.zip_path(dictionary_id))
            file_name = re.sub(r"[^\w\-. ()]+", "_", request.query_params.get("name", ""))[:200] or None
            entry = catalog.add(dictionary_id, index, received, digest.hexdigest(), file_name, replaces)
            jobs.put(dictionary_id)
            return JSONResponse(entry, status_code=202)
        finally:
            upload_lock.release()
            temp.unlink(missing_ok=True)

    async def update(request: Request) -> Response:
        """Relabels a dictionary's languages, or sets the admin's own
        description of it. Only what is sent changes."""
        require_admin(request)
        entry = dictionary_of(request, ready=False)
        try:
            body = await request.json()
        except ValueError:
            raise Problem(400, "Send the changes as JSON.") from None
        if not isinstance(body, dict):
            raise Problem(400, "Send the changes as a JSON object.")
        note = entry["note"]
        if "note" in body:
            note = body["note"]
            if note is not None and not isinstance(note, str):
                raise Problem(400, "The description should be text.")
            note = (note or "").strip() or None
            if note is not None and len(note) > MAX_NOTE_LENGTH:
                raise Problem(400, f"A description can be up to {MAX_NOTE_LENGTH} characters.")
        languages = None
        if "sourceLanguage" in body or "targetLanguage" in body:
            languages = []
            for key in ("sourceLanguage", "targetLanguage"):
                value = body.get(key, entry[key])
                if value is not None and (not isinstance(value, str) or not LANGUAGE.match(value)):
                    raise Problem(400, f"{key} should be a language code such as ja or en.")
                languages.append(value)
        if languages is not None:
            catalog.set_languages(entry["id"], *languages)
        if "note" in body:
            catalog.set_note(entry["id"], note)
        return JSONResponse(catalog.get(entry["id"]))

    def delete(request: Request) -> Response:
        require_admin(request)
        entry = dictionary_of(request, ready=False)
        catalog.delete(entry["id"])
        return Response(status_code=204)

    async def collection(request: Request) -> Response:
        if request.method == "PUT":
            return await upload(request)
        return await run_in_threadpool(list_all, request)

    async def item(request: Request) -> Response:
        if request.method == "PATCH":
            return await update(request)
        if request.method == "DELETE":
            return await run_in_threadpool(delete, request)
        return await run_in_threadpool(get_one, request)

    async def problem(request: Request, error: Problem) -> Response:
        return JSONResponse({"error": error.message}, status_code=error.status)

    app = Starlette(
        routes=[
            Route("/api/health", health),
            Route("/api/me", me),
            Route("/api/dictionaries", collection, methods=["GET", "PUT"]),
            Route("/api/dictionaries/{id}", item, methods=["GET", "PATCH", "DELETE"]),
            Route("/api/dictionaries/{id}/search", lookup),
            Route("/api/dictionaries/{id}/download", download),
            Route("/api/dictionaries/{id}/media", media),
            Route("/api/dictionaries/{id}/styles", styles),
        ],
        middleware=[Middleware(SecurityHeaders)],
        exception_handlers={Problem: problem},
        lifespan=lifespan,
    )
    app.state.catalog = catalog
    app.state.jobs = jobs
    return app


def main() -> Starlette:
    """Entry point for uvicorn's --factory."""
    return create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(main, factory=True, host="0.0.0.0", port=int(os.environ.get("PORT", 8000)))
