import re

_ALLOWED_STARTS = {"SELECT", "SHOW", "DESCRIBE", "DESC", "EXPLAIN", "WITH"}

_BLOCKED_KEYWORDS = {
    "INSERT", "UPDATE", "DELETE", "DROP", "CREATE", "ALTER", "TRUNCATE",
    "GRANT", "REVOKE", "CALL", "LOAD", "HANDLER", "LOCK", "UNLOCK",
    "REPLACE", "RENAME", "USE", "SET", "COMMIT", "ROLLBACK", "SAVEPOINT",
    "START", "BEGIN", "FLUSH", "RESET", "KILL", "SHUTDOWN",
}

_OUTFILE_PATTERN = re.compile(r"\binto\s+(outfile|dumpfile)\b", re.IGNORECASE)


def _strip_comments(sql: str) -> str:
    sql = re.sub(r"/\*.*?\*/", " ", sql, flags=re.DOTALL)
    sql = re.sub(r"--[^\n]*", " ", sql)
    sql = re.sub(r"(^|\s)#[^\n]*", " ", sql)
    return sql


def _strip_string_literals(sql: str) -> str:
    sql = re.sub(r"'(?:''|\\.|[^'\\])*'", "''", sql)
    sql = re.sub(r'"(?:""|\\.|[^"\\])*"', '""', sql)
    return sql


def validate(sql: str) -> tuple[bool, str, str]:
    if not sql or not sql.strip():
        return False, "", "Query is empty."

    cleaned = _strip_comments(sql).strip().rstrip(";").strip()
    if not cleaned:
        return False, "", "Query is empty after stripping comments."

    if ";" in cleaned:
        return False, "", "Only a single statement is allowed."

    first_token = cleaned.split(None, 1)[0].upper()
    if first_token not in _ALLOWED_STARTS:
        return False, "", (
            f"Only read-only statements are allowed. "
            f"Got '{first_token}'. Allowed: {', '.join(sorted(_ALLOWED_STARTS))}."
        )

    scan_text = _strip_string_literals(cleaned)
    words = set(re.findall(r"[A-Za-z_]+", scan_text.upper()))
    blocked = words & _BLOCKED_KEYWORDS
    if blocked:
        return False, "", f"Blocked keyword(s) present: {', '.join(sorted(blocked))}."

    if _OUTFILE_PATTERN.search(scan_text):
        return False, "", "INTO OUTFILE / DUMPFILE is not allowed."

    return True, cleaned, ""
