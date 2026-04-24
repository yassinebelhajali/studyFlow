import json
import sqlite3
import sys
from pathlib import Path


TABLES = [
    "users",
    "tasks",
    "schedule_sessions",
    "ai_agent_sessions",
]


def fetch_table(cursor, table_name):
    try:
        rows = cursor.execute(f"SELECT * FROM {table_name}").fetchall()
    except sqlite3.OperationalError:
        return []

    result = []
    for row in rows:
        result.append({key: row[key] for key in row.keys()})
    return result


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python export_sqlite_legacy.py <sqlite-path>")

    sqlite_path = Path(sys.argv[1]).resolve()
    if not sqlite_path.exists():
        raise SystemExit(f"SQLite database not found: {sqlite_path}")

    connection = sqlite3.connect(str(sqlite_path))
    connection.row_factory = sqlite3.Row
    cursor = connection.cursor()

    payload = {
        "sqlitePath": str(sqlite_path),
        "tables": {table: fetch_table(cursor, table) for table in TABLES},
    }

    connection.close()
    print(json.dumps(payload, ensure_ascii=False))


if __name__ == "__main__":
    main()
