#!/usr/bin/env python3
import json
import os
import sqlite3
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Optional
from urllib.parse import unquote, urlparse


PORT = int(os.environ.get("PORT", "8080"))
DATABASE_PATH = Path(
    os.environ.get(
        "VOCAB_HILL_SYNC_DB",
        Path.cwd() / ".dart_tool" / "vocab_hill_sync.db",
    )
)


def utc_now_iso8601() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def create_connection() -> sqlite3.Connection:
    DATABASE_PATH.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(DATABASE_PATH, check_same_thread=False)
    connection.row_factory = sqlite3.Row
    return connection


DATABASE = create_connection()


def create_schema(connection: sqlite3.Connection) -> None:
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS learners(
          sync_key TEXT PRIMARY KEY,
          created_at TEXT NOT NULL
        )
        """
    )
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS app_state(
          sync_key TEXT PRIMARY KEY,
          selected_day INTEGER,
          updated_at TEXT
        )
        """
    )
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS word_progress(
          sync_key TEXT NOT NULL,
          day INTEGER NOT NULL,
          word TEXT NOT NULL,
          status TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          PRIMARY KEY(sync_key, day, word)
        )
        """
    )
    connection.commit()


def ensure_learner(connection: sqlite3.Connection, sync_key: str) -> None:
    connection.execute(
        """
        INSERT INTO learners(sync_key, created_at)
        VALUES(?, ?)
        ON CONFLICT(sync_key) DO NOTHING
        """,
        (sync_key, utc_now_iso8601()),
    )


def is_incoming_newer(incoming: Optional[str], existing: Optional[str]) -> bool:
    if not incoming:
        return False
    if not existing:
        return True
    return datetime.fromisoformat(incoming.replace("Z", "+00:00")) > datetime.fromisoformat(
        existing.replace("Z", "+00:00")
    )


def read_snapshot(connection: sqlite3.Connection, sync_key: str) -> dict:
    ensure_learner(connection, sync_key)

    selected_day_row = connection.execute(
        """
        SELECT selected_day, updated_at
        FROM app_state
        WHERE sync_key = ?
        LIMIT 1
        """,
        (sync_key,),
    ).fetchone()

    status_rows = connection.execute(
        """
        SELECT day, word, status, updated_at
        FROM word_progress
        WHERE sync_key = ?
        ORDER BY day ASC, word ASC
        """,
        (sync_key,),
    ).fetchall()

    return {
        "selectedDay": None if selected_day_row is None else selected_day_row["selected_day"],
        "selectedDayUpdatedAt": None
        if selected_day_row is None
        else selected_day_row["updated_at"],
        "statuses": [
            {
                "day": row["day"],
                "word": row["word"],
                "status": row["status"],
                "updatedAt": row["updated_at"],
            }
            for row in status_rows
        ],
    }


def merge_snapshot(connection: sqlite3.Connection, sync_key: str, payload: dict) -> dict:
    ensure_learner(connection, sync_key)

    incoming_selected_day = payload.get("selectedDay")
    incoming_selected_day_updated_at = payload.get("selectedDayUpdatedAt")
    incoming_statuses = payload.get("statuses", [])

    selected_day_row = connection.execute(
        """
        SELECT selected_day, updated_at
        FROM app_state
        WHERE sync_key = ?
        LIMIT 1
        """,
        (sync_key,),
    ).fetchone()
    existing_selected_day_updated_at = (
        None if selected_day_row is None else selected_day_row["updated_at"]
    )

    if is_incoming_newer(
        incoming_selected_day_updated_at,
        existing_selected_day_updated_at,
    ):
        connection.execute(
            """
            INSERT INTO app_state(sync_key, selected_day, updated_at)
            VALUES(?, ?, ?)
            ON CONFLICT(sync_key) DO UPDATE SET
              selected_day = excluded.selected_day,
              updated_at = excluded.updated_at
            """,
            (sync_key, incoming_selected_day, incoming_selected_day_updated_at),
        )

    for record in incoming_statuses:
        existing_row = connection.execute(
            """
            SELECT updated_at
            FROM word_progress
            WHERE sync_key = ? AND day = ? AND word = ?
            LIMIT 1
            """,
            (sync_key, record["day"], record["word"]),
        ).fetchone()
        existing_updated_at = None if existing_row is None else existing_row["updated_at"]

        if not is_incoming_newer(record.get("updatedAt"), existing_updated_at):
            continue

        connection.execute(
            """
            INSERT INTO word_progress(sync_key, day, word, status, updated_at)
            VALUES(?, ?, ?, ?, ?)
            ON CONFLICT(sync_key, day, word) DO UPDATE SET
              status = excluded.status,
              updated_at = excluded.updated_at
            """,
            (
                sync_key,
                record["day"],
                record["word"],
                record["status"],
                record["updatedAt"],
            ),
        )

    connection.commit()
    return read_snapshot(connection, sync_key)


class SyncRequestHandler(BaseHTTPRequestHandler):
    server_version = "VocabHillSync/1.0"

    def do_OPTIONS(self) -> None:
        self._send_json(200, {})

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"

        if path == "/health":
            self._send_json(200, {"status": "ok"})
            return

        sync_key = self._progress_sync_key(path)
        if sync_key is None:
            self._send_json(404, {"error": "Not found"})
            return

        self._send_json(200, read_snapshot(DATABASE, sync_key))

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        sync_key = self._merge_sync_key(path)
        if sync_key is None:
            self._send_json(404, {"error": "Not found"})
            return

        content_length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(content_length).decode("utf-8") if content_length else ""
        payload = {} if not raw_body else json.loads(raw_body)
        merged = merge_snapshot(DATABASE, sync_key, payload)
        self._send_json(200, merged)

    def log_message(self, format: str, *args) -> None:
        print("%s - - [%s] %s" % (self.address_string(), self.log_date_time_string(), format % args))

    def _progress_sync_key(self, path: str) -> Optional[str]:
        prefix = "/api/progress/"
        if not path.startswith(prefix):
            return None
        remainder = path[len(prefix) :]
        if not remainder or "/" in remainder:
            return None
        return unquote(remainder)

    def _merge_sync_key(self, path: str) -> Optional[str]:
        prefix = "/api/progress/"
        suffix = "/merge"
        if not path.startswith(prefix) or not path.endswith(suffix):
            return None
        remainder = path[len(prefix) : -len(suffix)]
        remainder = remainder.strip("/")
        if not remainder or "/" in remainder:
            return None
        return unquote(remainder)

    def _send_json(self, status_code: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "content-type")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)


def main() -> None:
    create_schema(DATABASE)
    server = ThreadingHTTPServer(("0.0.0.0", PORT), SyncRequestHandler)
    print(f"Vocab Hill sync server listening on http://0.0.0.0:{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    main()
