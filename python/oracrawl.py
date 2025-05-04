r"""
Oracle View Crawler — Dependency Extractor for SQL Nerds

Accelerates Oracle migrations & impact analysis by extracting nested dependencies
of views into clear, actionable artifacts.

Audience:
- DB engineers, data architects, Python-savvy analysts

Value:
- Saves hours decoding legacy Oracle views
- Reduces risk by surfacing all tables, views, and UDFs involved
- Enables faster migrations, clean impact analysis, and confident changes

Usage:
1. Ensure Python 3.9+ is installed.
2. Install required libraries:
      pip install oracledb sqlglot
3. Install Oracle Instant Client:
   - Download: https://www.oracle.com/database/technologies/instant-client.html
   - Extract to: C:\\Oracle\\instantclient_23_7
   - Add to PATH.
4. Run:
      python oracrawl.py <host> <port> <service> <user> <password> <schema.view>
"""

import sys
import os
import re
import logging
from collections import defaultdict

import oracledb
import sqlglot
from sqlglot.expressions import Table, Func

# Configure Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s: %(message)s",
)

OUTPUT_BASE_DIR = "output"

ORACLE_BUILTINS = {...}  # Unchanged (truncated for brevity)
SQL_KEYWORDS = {...}  # Unchanged (truncated for brevity)

SEEN_OBJECTS = set()
found_views = set()
found_tables = set()
found_functions = {}
view_ddl_map = {}
dependency_graph = defaultdict(list)


def clean_sql(sql):
    """Remove comments and normalize whitespace."""
    sql = re.sub(r"/\*.*?\*/", "", sql, flags=re.DOTALL)
    sql = re.sub(r"--.*?$", "", sql, flags=re.MULTILINE)
    return sql.strip()


def classify_function(name):
    """Return 'BUILTIN' if Oracle built-in, else 'UDF', else None."""
    name = name.upper()
    if (
        not name.isidentifier()
        or name in SQL_KEYWORDS
        or name in {"ANONYMOUS", "BLOCK"}
    ):
        return None
    return "BUILTIN" if name in ORACLE_BUILTINS else "UDF"


def strip_alias(name):
    """Extract clean object name without aliases."""
    return name.split()[0]


def extract_objects_from_sql(sql):
    """Extract tables and UDFs from SQL using sqlglot parser."""
    sql = clean_sql(sql)
    try:
        parsed = sqlglot.parse_one(sql, dialect="oracle")
    except Exception:
        return [], {}

    tables, functions = set(), {}

    for node in parsed.walk():
        if isinstance(node, Table):
            tables.add(strip_alias(node.sql(dialect="oracle")))
        elif isinstance(node, Func):
            fname = node.sql_name().upper()
            if classify_function(fname) == "UDF":
                functions[fname] = "UDF"

    return sorted(tables), functions


def get_object_type_and_text(conn, owner, object_name):
    """Fetch object type and DDL if applicable."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT object_type
            FROM all_objects
            WHERE object_name = :obj AND owner = :owner
        """,
            {"obj": object_name.upper(), "owner": owner.upper()},
        )
        row = cur.fetchone()
        if not row:
            return None, None
        obj_type = row[0]
        if obj_type == "VIEW":
            cur.execute(
                """
                SELECT text
                FROM all_views
                WHERE view_name = :obj AND owner = :owner
            """,
                {"obj": object_name.upper(), "owner": owner.upper()},
            )
            rows = cur.fetchall()
            ddl = clean_sql("\n".join(r[0] for r in rows))
            view_ddl_map[f"{owner}.{object_name}"] = ddl
            return "VIEW", ddl
        return "TABLE", None


def fully_qualify(name, default_schema):
    """Add schema if missing."""
    return f"{default_schema}.{name}" if "." not in name else name


def crawl_object(conn, fq_object):
    """Begin recursive crawl."""
    owner, object_name = fq_object.split(".")
    _crawl(conn, owner.upper(), object_name.upper(), owner.upper())


def _crawl(conn, owner, object_name, default_schema):
    fq_name = f"{owner}.{object_name}"
    if fq_name in SEEN_OBJECTS:
        return
    SEEN_OBJECTS.add(fq_name)

    obj_type, ddl = get_object_type_and_text(conn, owner, object_name)

    if not obj_type:
        logging.error(f"Object not found: {fq_name}")
        sys.exit(3)

    if obj_type == "TABLE":
        found_tables.add(fq_name)
        return

    found_views.add(fq_name)
    tables, functions = extract_objects_from_sql(ddl)

    for t in tables:
        fq = fully_qualify(t, default_schema)
        dependency_graph[fq_name].append(fq)
        if fq.upper() != fq_name.upper():
            _crawl(conn, *fq.split("."), default_schema)

    found_functions.update(functions)


def connect_thin(host, port, service, user, password):
    """Create Oracle connection."""
    dsn = f"{host}:{port}/{service}"
    return oracledb.connect(user=user, password=password, dsn=dsn)


def sanitize_filename(fq_name):
    """Make filenames safe."""
    return fq_name.replace(".", "__").replace("$", "_").replace("/", "_")


def write_summary(output_dir):
    """Save list of found objects."""
    with open(os.path.join(output_dir, "summary.txt"), "w") as f:
        f.write("Views and UDFs:\n")
        for v in sorted(found_views):
            f.write(f" - {v}\n")
        for func in sorted(found_functions):
            f.write(f" - {func} (UDF)\n")
        f.write("\nTables:\n")
        for t in sorted(found_tables):
            f.write(f" - {t}\n")


def write_view_ddls(output_dir):
    """Save each view's DDL."""
    for fq_name, ddl in view_ddl_map.items():
        with open(
            os.path.join(output_dir, f"{sanitize_filename(fq_name)}.sql"),
            "w",
            encoding="utf-8",
        ) as f:
            f.write(ddl)


def render_tree(fq_view):
    """Return ASCII tree string."""
    lines = []

    def _walk(node, prefix="", is_last=True):
        lines.append(f"{prefix}{'└── ' if is_last else '├── '}{node}")
        children = dependency_graph.get(node, [])
        for i, child in enumerate(children):
            is_last_child = i == len(children) - 1
            new_prefix = prefix + ("    " if is_last else "│   ")
            _walk(child, new_prefix, is_last_child)

    _walk(fq_view)
    return "\n".join(lines)


def write_tree(output_dir, fq_view):
    """Save tree.txt."""
    with open(os.path.join(output_dir, "tree.txt"), "w") as f:
        f.write(render_tree(fq_view))


try:
    oracledb.init_oracle_client(lib_dir=r"C:\Oracle\instantclient_23_7")
    logging.info("Oracle Instant Client loaded — using thick mode")
except Exception as e:
    logging.warning(f"Could not load Oracle Client — using thin mode instead: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 7:
        print("Usage:")
        print(
            "  python oracrawl.py <host> <port> <service> <user> <password> <schema.object>"
        )
        sys.exit(1)

    host, port, service, user, password, fq_object = sys.argv[1:]

    try:
        conn = connect_thin(host, port, service, user, password)
    except oracledb.Error as e:
        logging.error("Failed to connect to Oracle: %s", e)
        if "ORA-12520" in str(e):
            logging.error(
                "Tip: ORA-12520 often means your service name is incorrect, misspelled, or missing a handler."
            )
            logging.error("Docs: https://docs.oracle.com/error-help/db/ora-12520/")
        sys.exit(2)

    crawl_object(conn, fq_object)

    output_dir = os.path.join(OUTPUT_BASE_DIR, fq_object)
    os.makedirs(output_dir, exist_ok=True)

    write_view_ddls(output_dir)
    write_summary(output_dir)
    write_tree(output_dir, fq_object)

    logging.info("Dependency crawl complete. Output in: %s", output_dir)
    sys.exit(0)
