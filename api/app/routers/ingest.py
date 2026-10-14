"""데이터 넣기 (관리자용) — 원천 연결 등록·연결 시험, 파일(CSV·엑셀)·DB 표를 원천 존에 적재, 표준 존 변환.

쓰기는 모두 DB 함수(gov.register_source·ingest_records·standardize_batch)로 한다. 함수가 역할과 범위를 다시 확인한다.
외부 DB 비밀번호는 요청 하나에만 쓰고 어디에도 저장하지 않는다.
"""
import csv
import hashlib
import io
import ipaddress
import json
import socket
from datetime import date, datetime, time
from decimal import Decimal
from pathlib import PurePath
from typing import Any
from uuid import UUID

import psycopg
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from psycopg import sql
from pydantic import BaseModel, Field

from .. import automap, extsuggest
from ..config import settings
from ..deps import Scoped
from .admin import admin_scoped
from .steward import run_rule_now

router = APIRouter(prefix="/api/admin", tags=["admin-ingest"])

SYSTEM_TYPES = ("ERP", "MES", "SCM", "QMS", "WMS", "PLM", "SCADA", "SECS_GEM", "EDMS", "SENSOR", "FILE")
DB_KINDS = ("POSTGRESQL", "MYSQL", "MSSQL", "ORACLE", "REST", "SFTP", "FILE")
HIDDEN_TARGET_COLS = {"enterprise_id"}


# ── 원천 연결 ───────────────────────────────────────────────────────────────

@router.get("/sources")
def sources(s: Scoped = Depends(admin_scoped)):
    return s.conn.execute(
        "SELECT ss.source_system_id, ss.label_ko, ss.system_type, ss.connection_kind, ss.owner_dept,"
        "       c.db_kind, c.host, c.port, c.database_name, c.username, c.status, c.last_tested_at, c.last_error,"
        "       (SELECT count(*) FROM catalog.dataset d WHERE d.source_system_id = ss.source_system_id) AS datasets,"
        "       (SELECT max(d.last_ingested_at) FROM catalog.dataset d WHERE d.source_system_id = ss.source_system_id) AS last_ingested_at"
        "  FROM catalog.source_system ss LEFT JOIN catalog.source_connection c ON c.source_system_id = ss.source_system_id"
        " ORDER BY ss.source_system_id").fetchall()


class SourceIn(BaseModel):
    source_system_id: str = Field(pattern=r"^[A-Za-z0-9][A-Za-z0-9_-]{1,49}$")
    label: str = Field(min_length=1, max_length=100)
    system_type: str = "FILE"
    db_kind: str = "FILE"
    host: str | None = Field(default=None, max_length=255)
    port: int | None = Field(default=None, ge=1, le=65535)
    database: str | None = Field(default=None, max_length=128)
    username: str | None = Field(default=None, max_length=128)
    owner_dept: str | None = Field(default=None, max_length=100)


def _save_source(body: SourceIn, s: Scoped) -> dict:
    if body.system_type not in SYSTEM_TYPES or body.db_kind not in DB_KINDS:
        raise HTTPException(400, "원천 종류나 연결 방식이 올바르지 않습니다")
    if body.db_kind not in ("FILE", "REST", "SFTP") and not (body.host and body.database):
        raise HTTPException(400, "DB 연결에는 호스트와 데이터베이스 이름이 필요합니다")
    sid = s.conn.execute(
        "SELECT gov.register_source(%s, %s, %s, %s, %s, %s, %s, %s, NULL, %s) AS id",
        (body.source_system_id, body.label, body.system_type, body.db_kind, body.host,
         body.port or (5432 if body.db_kind == "POSTGRESQL" else None), body.database, body.username,
         body.owner_dept)).fetchone()["id"]
    return {"source_system_id": sid}


def _exists(s: Scoped, sid: str) -> bool:
    return s.conn.execute("SELECT 1 FROM catalog.source_system WHERE source_system_id = %s", (sid,)).fetchone() is not None


@router.post("/sources")
def register_source(body: SourceIn, s: Scoped = Depends(admin_scoped)):
    if _exists(s, body.source_system_id):
        raise HTTPException(409, f"원천 ID {body.source_system_id} 는 이미 있습니다. 바꾸려면 수정을 쓰세요")
    return _save_source(body, s)


@router.put("/sources/{source_id}")
def update_source(source_id: str, body: SourceIn, s: Scoped = Depends(admin_scoped)):
    if body.source_system_id != source_id:
        raise HTTPException(400, "원천 ID 는 바꿀 수 없습니다")
    if not _exists(s, source_id):
        raise HTTPException(404, f"원천 {source_id} 가 없습니다")
    return _save_source(body, s)


@router.delete("/sources/{source_id}")
def delete_source(source_id: str, purge: bool = False, s: Scoped = Depends(admin_scoped)):
    return s.conn.execute("SELECT gov.delete_source(%s, %s) AS r", (source_id, purge)).fetchone()["r"]


def _connection(s: Scoped, source_id: str) -> dict:
    c = s.conn.execute("SELECT * FROM catalog.source_connection WHERE source_system_id = %s", (source_id,)).fetchone()
    if c is None:
        raise HTTPException(404, f"원천 {source_id} 의 연결 정보가 없습니다")
    if c["db_kind"] != "POSTGRESQL":
        raise HTTPException(400, "지금은 PostgreSQL 만 직접 연결할 수 있습니다. 다른 DB 는 CSV·엑셀로 내보내 파일 올리기를 써 주세요")
    return c


def _check_host(host: str) -> None:
    """서버리스 시연 환경에서 내부망·루프백 주소로 연결하지 못하게 막는다 (SSRF)."""
    if settings.ingest_allow_private_hosts:
        return
    try:
        infos = socket.getaddrinfo(host, None)
    except OSError:
        raise HTTPException(400, f"호스트 {host} 를 찾을 수 없습니다")
    for info in infos:
        ip = ipaddress.ip_address(info[4][0])
        if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved or ip.is_multicast:
            raise HTTPException(400, "이 환경에서는 사내망·로컬 주소로 연결할 수 없습니다")


def _external(c: dict, password: str) -> psycopg.Connection:
    _check_host(c["host"])
    return psycopg.connect(
        host=c["host"], port=c["port"] or 5432, dbname=c["database_name"], user=c["username"], password=password,
        connect_timeout=5, sslmode="prefer", autocommit=False,
        options="-c statement_timeout=15000 -c default_transaction_read_only=on")


class Secret(BaseModel):
    password: str = Field(default="", max_length=500)


@router.post("/sources/{source_id}/test")
def test_source(source_id: str, body: Secret, s: Scoped = Depends(admin_scoped)):
    c = _connection(s, source_id)
    try:
        with _external(c, body.password) as ext:
            tables = ext.execute(
                "SELECT table_schema, table_name, table_type FROM information_schema.tables"
                " WHERE table_schema NOT IN ('pg_catalog', 'information_schema') AND table_schema NOT LIKE 'pg\\_%%'"
                " ORDER BY 1, 2 LIMIT 500").fetchall()
    except psycopg.Error as e:
        msg = str(e).strip().splitlines()[0] if str(e).strip() else type(e).__name__
        s.conn.execute("SELECT gov.record_connection_test(%s, false, %s)", (source_id, msg))
        return {"ok": False, "error": msg, "tables": []}
    s.conn.execute("SELECT gov.record_connection_test(%s, true)", (source_id,))
    return {"ok": True, "error": None,
            "tables": [{"schema": t[0], "name": t[1], "kind": "view" if t[2] == "VIEW" else "table"} for t in tables]}


class ImportIn(Secret):
    table: str = Field(pattern=r"^[^.\s]+\.[^.\s]+$", max_length=200)   # schema.table
    limit: int = Field(default=1000, ge=1, le=5000)


@router.post("/sources/{source_id}/import")
def import_table(source_id: str, body: ImportIn, s: Scoped = Depends(admin_scoped)):
    c = _connection(s, source_id)
    schema, table = body.table.split(".", 1)
    try:
        with _external(c, body.password) as ext:
            cur = ext.execute(sql.SQL("SELECT * FROM {}.{} LIMIT {}").format(
                sql.Identifier(schema), sql.Identifier(table), sql.Literal(body.limit)))
            cols = [d.name for d in cur.description or []]
            rows = [{k: _jsonable(v) for k, v in zip(cols, r)} for r in cur.fetchall()]
    except psycopg.Error as e:
        raise HTTPException(400, f"원천 DB 에서 읽지 못했습니다: {str(e).strip().splitlines()[0] if str(e).strip() else e}")
    if not rows:
        raise HTTPException(400, "표에 행이 없습니다")
    payload = json.dumps(rows, ensure_ascii=False)
    batch = s.conn.execute(
        "SELECT gov.ingest_records(%s, %s, %s::jsonb, NULL, 'table', NULL, %s, %s, NULL, %s) AS b",
        (source_id, table, payload, len(payload.encode()), hashlib.sha256(payload.encode()).hexdigest(), cols)).fetchone()["b"]
    return {"batch_id": batch, "rows": len(rows), "columns": cols}


# ── 파일 올리기 ─────────────────────────────────────────────────────────────

def _jsonable(v: Any) -> Any:
    if v is None or isinstance(v, (bool, int, float, str)):
        return v
    if isinstance(v, (datetime, date, time)):
        return v.isoformat()
    if isinstance(v, Decimal):
        return str(v)
    if isinstance(v, (bytes, bytearray, memoryview)):
        return None
    return str(v)


def _headers(raw: list[Any]) -> list[str]:
    out: list[str] = []
    for i, h in enumerate(raw):
        name = str(h).strip() if h is not None else ""
        name = name or f"col_{i + 1}"
        base, n = name, 2
        while name in out:
            name, n = f"{base}_{n}", n + 1
        out.append(name)
    return out


def _parse_csv(data: bytes) -> list[dict]:
    text = _decode(data)
    sample = text[:4096]
    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=",\t;|")
    except csv.Error:
        dialect = csv.excel
    reader = csv.reader(io.StringIO(text), dialect)
    rows = [r for r in reader if any(c.strip() for c in r)]
    if len(rows) < 2:
        raise HTTPException(400, "머리글 한 줄과 데이터가 한 줄 이상 있어야 합니다")
    head = _headers(rows[0])
    return [{h: (r[i] if i < len(r) else None) for i, h in enumerate(head)} for r in rows[1:]]


def _rows_to_records(rows: list[list[Any]]) -> list[dict]:
    rows = [r for r in rows if any(c not in (None, "") for c in r)]
    if not rows:
        raise HTTPException(400, "시트가 비어 있습니다")
    head = _headers(list(rows[0]))
    out = [{h: _jsonable(r[i]) if i < len(r) else None for i, h in enumerate(head)} for r in rows[1:]]
    if not out:
        raise HTTPException(400, "머리글 아래에 데이터가 없습니다")
    return out


_MIN_STYLES = (
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">{numfmts}'
    '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>'
    '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>'
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="{n}">{xfs}</cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>'
)


def _repair_xlsx_styles(data: bytes) -> bytes:
    """MES·ERP 가 만든 .xlsx 는 styles.xml 이 규격에 어긋나 openpyxl 이 거부하는 일이 있다.
    글꼴·채우기·테두리는 버리고 숫자 서식(날짜 구분에 필요)만 남긴 최소 스타일로 바꿔 끼운다."""
    import re
    import zipfile
    from xml.sax.saxutils import quoteattr

    src = zipfile.ZipFile(io.BytesIO(data))
    name = next((n for n in src.namelist() if n.lower() == "xl/styles.xml"), None)
    numfmts, xfs = "", ['<xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>']
    if name:
        raw = src.read(name).decode("utf-8", "replace")
        fmts = re.findall(r'<numFmt\b[^>]*?numFmtId="(\d+)"[^>]*?formatCode="([^"]*)"', raw)
        if fmts:
            numfmts = f'<numFmts count="{len(fmts)}">' + "".join(
                f'<numFmt numFmtId="{i}" formatCode={quoteattr(c.replace("&quot;", chr(34)))}/>' for i, c in fmts) + "</numFmts>"
        m = re.search(r"<cellXfs\b[^>]*>(.*?)</cellXfs>", raw, re.S)
        if m:
            ids = [re.search(r'numFmtId="(\d+)"', x) for x in re.findall(r"<xf\b[^>]*?/?>", m.group(1))]
            if ids:
                xfs = [f'<xf numFmtId="{i.group(1) if i else 0}" fontId="0" fillId="0" borderId="0" applyNumberFormat="1"/>' for i in ids]
    styles = _MIN_STYLES.format(numfmts=numfmts, n=len(xfs), xfs="".join(xfs)).encode()
    out = io.BytesIO()
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for n in src.namelist():
            if n == name:
                continue
            z.writestr(n, src.read(n))
        z.writestr(name or "xl/styles.xml", styles)
    return out.getvalue()


def _parse_xlsx(data: bytes, sheet: str | None) -> list[dict]:
    from openpyxl import load_workbook

    try:
        wb = load_workbook(io.BytesIO(data), read_only=True, data_only=True)
    except Exception as first:  # noqa: BLE001 - 스타일 문제면 보정해서 한 번 더, 아니면 사용자에게 짧게 알린다
        try:
            wb = load_workbook(io.BytesIO(_repair_xlsx_styles(data)), read_only=True, data_only=True)
        except Exception:  # noqa: BLE001
            raise HTTPException(400, f"엑셀(.xlsx) 파일을 열지 못했습니다: {type(first).__name__}: {str(first)[:120]}")
    ws = wb[sheet] if sheet and sheet in wb.sheetnames else wb.worksheets[0]
    return _rows_to_records([list(r) for r in ws.iter_rows(values_only=True)])


def _parse_xls(data: bytes, sheet: str | None) -> list[dict]:
    """옛 엑셀(.xls, BIFF). MES·ERP 가 .xlsx 라는 이름으로 내보내는 경우가 많다."""
    try:
        import xlrd
    except ImportError:
        raise HTTPException(400, "옛 엑셀(.xls) 형식입니다. 엑셀에서 .xlsx 로 다시 저장해 올려 주세요")
    try:
        wb = xlrd.open_workbook(file_contents=data)
    except Exception as e:  # noqa: BLE001
        raise HTTPException(400, f"엑셀(.xls) 파일을 열지 못했습니다: {type(e).__name__}: {str(e)[:120]}")
    ws = wb.sheet_by_name(sheet) if sheet and sheet in wb.sheet_names() else wb.sheet_by_index(0)
    rows: list[list[Any]] = []
    for i in range(ws.nrows):
        row = []
        for c in ws.row(i):
            if c.ctype == xlrd.XL_CELL_DATE:
                row.append(datetime(*xlrd.xldate_as_tuple(c.value, wb.datemode)).isoformat())
            elif c.ctype == xlrd.XL_CELL_NUMBER and float(c.value).is_integer():
                row.append(int(c.value))
            elif c.ctype in (xlrd.XL_CELL_EMPTY, xlrd.XL_CELL_BLANK):
                row.append(None)
            else:
                row.append(c.value)
        rows.append(row)
    return _rows_to_records(rows)


def _parse_html_table(text: str) -> list[dict]:
    """웹 MES 의 '엑셀로 저장' 은 실제로는 HTML 표인 경우가 많다. 첫 번째 <table> 을 읽는다."""
    from html.parser import HTMLParser

    class P(HTMLParser):
        def __init__(self) -> None:
            super().__init__()
            self.rows: list[list[Any]] = []
            self.row: list[Any] | None = None
            self.cell: list[str] | None = None
            self.done = False

        def handle_starttag(self, tag, attrs):
            if self.done:
                return
            if tag == "tr":
                self.row = []
            elif tag in ("td", "th") and self.row is not None:
                self.cell = []

        def handle_endtag(self, tag):
            if self.done:
                return
            if tag in ("td", "th") and self.cell is not None and self.row is not None:
                self.row.append("".join(self.cell).strip() or None)
                self.cell = None
            elif tag == "tr" and self.row is not None:
                self.rows.append(self.row)
                self.row = None
            elif tag == "table" and self.rows:
                self.done = True

        def handle_data(self, d):
            if self.cell is not None:
                self.cell.append(d)

    p = P()
    p.feed(text)
    if not p.rows:
        raise HTTPException(400, "HTML 안에 표(<table>)가 없습니다")
    return _rows_to_records(p.rows)


def _parse_spreadsheetml(text: str, sheet: str | None) -> list[dict]:
    """엑셀 2003 XML 스프레드시트 (<?xml …><Workbook xmlns=urn:schemas-microsoft-com:office:spreadsheet>)."""
    import xml.etree.ElementTree as ET

    ns = {"ss": "urn:schemas-microsoft-com:office:spreadsheet"}
    try:
        root = ET.fromstring(text)
    except ET.ParseError as e:
        raise HTTPException(400, f"XML 스프레드시트를 읽지 못했습니다: {str(e)[:120]}")
    sheets = root.findall("ss:Worksheet", ns)
    if not sheets:
        raise HTTPException(400, "XML 안에 Worksheet 가 없습니다")
    ws = next((w for w in sheets if sheet and w.get(f"{{{ns['ss']}}}Name") == sheet), sheets[0])
    rows: list[list[Any]] = []
    for r in ws.iter(f"{{{ns['ss']}}}Row"):
        row: list[Any] = []
        for c in r.findall("ss:Cell", ns):
            idx = c.get(f"{{{ns['ss']}}}Index")
            if idx:
                row.extend([None] * (int(idx) - 1 - len(row)))
            d = c.find("ss:Data", ns)
            row.append(None if d is None else (d.text or "").strip() or None)
        rows.append(row)
    return _rows_to_records(rows)


def _decode(data: bytes) -> str:
    for enc in ("utf-8-sig", "cp949", "utf-16"):
        try:
            return data.decode(enc)
        except UnicodeDecodeError:
            continue
    raise HTTPException(400, "파일 인코딩을 읽지 못했습니다 (UTF-8 또는 CP949 로 저장해 주세요)")


def _parse_table(data: bytes, name: str, sheet: str | None) -> tuple[list[dict], str]:
    """확장자가 아니라 내용으로 형식을 가린다. MES·ERP 가 .xlsx 라고 내보내도 실제로는 .xls·HTML·XML 인 경우가 흔하다."""
    head = data[:8]
    if head.startswith(b"PK\x03\x04"):
        return _parse_xlsx(data, sheet), "xlsx"
    if head.startswith(b"\xd0\xcf\x11\xe0"):
        return _parse_xls(data, sheet), "xls"
    probe = data[:2048].lstrip(b"\xef\xbb\xbf \t\r\n")
    if probe[:1] == b"<" or probe[:2] in (b"\xff\xfe", b"\xfe\xff"):
        text = _decode(data)
        lead = text.lstrip()[:400].lower()
        if "urn:schemas-microsoft-com:office:spreadsheet" in text[:4000]:
            return _parse_spreadsheetml(text, sheet), "xml"
        if lead.startswith("<") and ("<table" in text.lower() or lead.startswith("<html") or lead.startswith("<!doctype")):
            return _parse_html_table(text), "html"
    ext = PurePath(name).suffix.lower()
    if ext in (".xlsx", ".xlsm", ".xls"):
        raise HTTPException(400, "엑셀 파일이 아닌 내용입니다 (압축된 .xlsx 도, 옛 .xls 도, HTML 표도 아니에요). 엑셀에서 다른 이름으로 저장 → .xlsx 로 올려 주세요")
    return _parse_csv(data), "csv"


@router.post("/upload")
async def upload(file: UploadFile = File(...), source_system_id: str = Form(...), entity: str | None = Form(default=None),
                 sheet: str | None = Form(default=None), s: Scoped = Depends(admin_scoped)):
    data = await file.read(settings.ingest_max_bytes + 1)
    if len(data) > settings.ingest_max_bytes:
        raise HTTPException(413, f"파일이 너무 큽니다 (최대 {settings.ingest_max_bytes // (1024 * 1024)}MB)")
    name = PurePath(file.filename or "upload.csv").name[:200]
    if PurePath(name).suffix.lower() not in (".xlsx", ".xlsm", ".xls", ".csv", ".tsv", ".txt", ".xml", ".html", ".htm"):
        raise HTTPException(400, "CSV·TSV·엑셀(.xlsx/.xls) 파일만 올릴 수 있습니다")
    rows, fmt = _parse_table(data, name, sheet)
    if len(rows) > settings.ingest_max_rows:
        raise HTTPException(413, f"행이 너무 많습니다 (최대 {settings.ingest_max_rows:,}행)")
    ent = (entity or "").strip() or PurePath(name).stem
    batch = s.conn.execute(
        "SELECT gov.ingest_records(%s, %s, %s::jsonb, %s, %s, %s, %s, %s, NULL, %s) AS b",
        (source_system_id, ent[:100], json.dumps(rows, ensure_ascii=False), name, fmt, file.content_type,
         len(data), hashlib.sha256(data).hexdigest(), list(rows[0].keys()))).fetchone()["b"]
    return {"batch_id": batch, "rows": len(rows), "columns": list(rows[0].keys()), "entity": ent}


# ── 적재 기록·표준 변환 ─────────────────────────────────────────────────────

@router.get("/batches")
def batches(s: Scoped = Depends(admin_scoped)):
    return s.conn.execute("SELECT * FROM gov.ingest_batches(100)").fetchall()


def _targets(s: Scoped) -> dict[str, dict]:
    rows = s.conn.execute(
        "SELECT c.relname AS tbl, a.attname AS col, col_description(c.oid, a.attnum) AS label, a.attnotnull AS required,"
        "       format_type(a.atttypid, a.atttypmod) AS type,"
        "       EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = c.oid AND i.indisprimary AND a.attnum = ANY (i.indkey)) AS pk,"
        "       a.atthasdef AS has_default"
        "  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = 'ksx'"
        "  JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped"
        " WHERE c.relkind IN ('r', 'p') AND NOT c.relispartition"
        " ORDER BY c.relname, a.attnum").fetchall()
    uniques: dict[str, list[list[str]]] = {}
    for r in s.conn.execute(
        "SELECT c.relname AS tbl, ARRAY(SELECT a.attname::text FROM unnest(k.conkey) WITH ORDINALITY o(n, i)"
        "                              JOIN pg_attribute a ON a.attrelid = k.conrelid AND a.attnum = o.n ORDER BY o.i) AS cols"
        "  FROM pg_constraint k JOIN pg_class c ON c.oid = k.conrelid JOIN pg_namespace n ON n.oid = c.relnamespace"
        " WHERE n.nspname = 'ksx' AND k.contype = 'u' ORDER BY c.relname, k.conname").fetchall():
        uniques.setdefault(r["tbl"], []).append(list(r["cols"]))
    classes = {r["physical_table"]: r for r in s.conn.execute(
        "SELECT DISTINCT ON (physical_table) physical_table, label_ko, local_name, class_iri FROM onto.class"
        " WHERE physical_table IS NOT NULL ORDER BY physical_table, is_standard DESC").fetchall()}
    out: dict[str, dict] = {}
    for r in rows:
        if r["col"] in HIDDEN_TARGET_COLS or r["col"].startswith("lake_"):
            continue
        cl = classes.get(r["tbl"])
        t = out.setdefault(r["tbl"], {"table": r["tbl"], "label_ko": cl["label_ko"] if cl else None,
                                      "class_name": cl["local_name"] if cl else None, "class_iri": cl["class_iri"] if cl else None,
                                      "unique_keys": uniques.get(r["tbl"], []),   # 대체키: 순번 자동 번호·식별자 자동 생성의 근거
                                      "columns": []})
        t["columns"].append({"name": r["col"], "label_ko": r["label"], "type": r["type"],
                             "required": r["required"] and not r["has_default"], "pk": r["pk"]})
    return out


@router.get("/targets")
def targets(s: Scoped = Depends(admin_scoped)):
    return sorted(_targets(s).values(), key=lambda t: (t["label_ko"] is None, t["table"]))


def _dup_keys(rows: list[dict], m: dict[str, str], table: dict) -> int:
    """표본에서 기본키 값이 겹치는 행 수 (겹치면 뒤 행이 앞 행을 덮어쓴다)."""
    inv = {v: k for k, v in m.items()}
    auto = automap.auto_keys(table, set(m.values()))
    if auto["seq"] or auto["derived"]:
        return 0              # 순번을 자동으로 매기므로 같은 키 값의 줄이 겹쳐 덮어쓰지 않는다
    pk = [c["name"] for c in table["columns"] if c["pk"] and c["name"] not in automap.SCOPE]
    if not pk or not all(p in inv for p in pk):
        return 0
    keys = [tuple(str(r.get(inv[p])) for p in pk) for r in rows]
    return len(keys) - len(set(keys))


@router.get("/batches/{batch_id}")
def batch(batch_id: UUID, table: str | None = None, s: Scoped = Depends(admin_scoped)):
    """배치 미리보기와 자동 대응 제안. 표를 안 정하면 모든 표준 표를 견줘 가장 맞는 표를 고른다."""
    info = s.conn.execute("SELECT * FROM gov.ingest_batches(500) WHERE batch_id = %s", (batch_id,)).fetchone()
    if info is None:
        raise HTTPException(404, "배치가 없거나 볼 수 있는 범위 밖입니다")
    sample = [p["payload"] for p in s.conn.execute("SELECT * FROM gov.ingest_batch_preview(%s, 200)", (batch_id,)).fetchall()]
    cols: list[str] = list(info["columns"] or [])
    for p in sample:
        for k in p:
            if k not in cols:
                cols.append(k)
    profs = {c: automap.profile([r.get(c) for r in sample]) for c in cols}
    tg = _targets(s)
    ranked = automap.pick(cols, profs, info["source_entity"], tg)
    if table and table in tg:
        m, conf = automap.map_table(cols, profs, tg[table])
        chosen = table
    elif ranked:
        chosen, m, conf = ranked[0]["table"], ranked[0]["map"], ranked[0]["confidence"]
    else:
        chosen, m, conf = None, {}, {}
    return {"batch": info, "columns": cols, "rows": sample[:20],
            "suggested_table": chosen, "suggested_map": m, "confidence": conf,
            "profiles": {c: p["kind"] for c, p in profs.items()},
            "candidates": [{k: x[k] for k in ("table", "label_ko", "score", "pk_ok")} | {"mapped": len(x["map"])}
                           for x in ranked[:3]],
            "sample_rows": len(sample), "dup_keys": _dup_keys(sample, m, tg[chosen]) if chosen else 0,
            "auto_keys": automap.auto_keys(tg[chosen], set(m.values())) if chosen else {"seq": {}, "derived": {}}}


class StandardizeIn(BaseModel):
    table: str = Field(pattern=r"^[a-z][a-z0-9_]{0,62}$")
    column_map: dict[str, str]
    site_id: str | None = Field(default=None, max_length=50)
    plant_id: str | None = Field(default=None, max_length=50)
    create_refs: bool = False
    keep_extras: bool = True      # 대응 안 된 원천 열을 확장 속성(ksx.extension_attribute)으로 보관하고 온톨로지 확장을 제안
    auto_quality: bool = True     # 변환 뒤 대상 데이터셋·클래스에 걸린 검사식(SQL) 규칙을 바로 돌린다


@router.post("/batches/{batch_id}/standardize")
def standardize(batch_id: UUID, body: StandardizeIn, s: Scoped = Depends(admin_scoped)):
    """표준 존 변환. 변환 자체는 gov.standardize_batch 가 하고, 그 뒤에

    1) keep_extras: 표준 표에 자리가 없던 열을 확장 속성으로 보관하고(gov.store_extension_attributes) 온톨로지 확장 제안을 쌓는다
       (extsuggest + gov.propose_extensions). 이미 등록된 회사 확장 속성과 이름이 맞으면 그 속성에 바로 연결한다.
    2) auto_quality: 대상 데이터셋 또는 대상 클래스에 걸린 켜진 SQL 규칙을 바로 돌려 결과를 함께 돌려준다.
    """
    cmap = {k: v for k, v in body.column_map.items() if v}
    out = s.conn.execute(
        "SELECT gov.standardize_batch(%s, %s, %s::jsonb, %s, %s, %s) AS r",
        (batch_id, body.table, json.dumps(cmap), body.site_id or None, body.plant_id or None, body.create_refs)).fetchone()["r"]
    out["extensions"] = None
    out["proposals"] = 0
    out["quality"] = []
    if not out.get("rows_out"):
        return out
    tg = _targets(s).get(body.table)
    class_iri = tg["class_iri"] if tg else None

    if body.keep_extras:
        info = s.conn.execute("SELECT columns FROM gov.ingest_batches(500) WHERE batch_id = %s", (batch_id,)).fetchone()
        sample = [p["payload"] for p in s.conn.execute("SELECT * FROM gov.ingest_batch_preview(%s, 200)", (batch_id,)).fetchall()]
        cols: list[str] = list((info and info["columns"]) or [])
        for p in sample:
            for k in p:
                if k not in cols:
                    cols.append(k)
        extras = [c for c in cols if c not in cmap]
        if extras and tg:
            key_map = {v: k for k, v in cmap.items()}   # 표준→원천 전체 대응표: 레코드 키와 자동 키(순번·'문서번호-순번')를 같은 규칙으로 만든다
            if key_map:
                ext_props = s.conn.execute(
                    "SELECT property_iri, local_name, label_ko, kind, range_iri, unit, domain_class_iri FROM onto.property"
                    " WHERE property_iri LIKE %s AND domain_class_iri IS NOT NULL", (extsuggest.ARCON + "%",)).fetchall()
                # 같은 표준 표에서 같은 열 이름을 이미 승인했으면 그 속성에 바로 잇는다 (다시 묻지 않는다)
                accepted = {r["column_name"]: r["result_iri"] for r in s.conn.execute(
                    "SELECT DISTINCT ON (x.column_name) x.column_name, x.result_iri FROM onto.extension_proposal x"
                    "  JOIN onto.property p ON p.property_iri = x.result_iri"
                    " WHERE x.std_table = %s AND x.status = 'ACCEPTED' AND x.kind <> 'CLASS'"
                    " ORDER BY x.column_name, x.decided_at DESC", (body.table,)).fetchall()}
                # 표준·확장 속성과 겹치는 영문 이름은 제안하지 않는다 (겹치면 클래스 이름을 앞에 붙인다)
                taken = {r["local_name"] for r in s.conn.execute("SELECT local_name FROM onto.property").fetchall()}
                items, attrs = [], {}
                for c in extras:
                    vals = [r.get(c) for r in sample]
                    prof = automap.profile(vals)
                    if prof["kind"] == "empty":
                        continue
                    if c in accepted:
                        attrs[c] = accepted[c]
                        continue
                    samples = [str(v) for v in vals if v is not None and str(v).strip() != ""][:5]
                    sg = extsuggest.suggest(c, prof, samples, ext_props, class_iri, len(sample), taken)
                    attrs[c] = sg["matched_property_iri"]
                    if not sg["matched_property_iri"]:
                        items.append(sg)
                if attrs:
                    out["extensions"] = s.conn.execute("SELECT gov.store_extension_attributes(%s, %s, %s::jsonb, %s::jsonb) AS r",
                                                       (batch_id, body.table, json.dumps(key_map), json.dumps(attrs))).fetchone()["r"]
                    out["extensions"]["matched"] = sum(1 for v in attrs.values() if v)
                if items:
                    out["proposals"] = s.conn.execute("SELECT gov.propose_extensions(%s, %s::jsonb) AS n",
                                                      (batch_id, json.dumps(items, ensure_ascii=False, default=str))).fetchone()["n"]

    if body.auto_quality:
        rules = s.conn.execute(
            "SELECT rule_id, label_ko, sql_check, target_dataset_id FROM catalog.quality_rule"
            " WHERE enabled AND sql_check IS NOT NULL AND (target_dataset_id = %s OR (target_class_iri IS NOT NULL AND target_class_iri = %s))"
            " ORDER BY rule_id", (out.get("std_dataset_id"), class_iri)).fetchall()
        for rule in rules:
            try:
                r = run_rule_now(s, rule, out.get("std_dataset_id"), inline=True)
                out["quality"].append({"rule_id": rule["rule_id"], "label_ko": rule["label_ko"], "status": "OK" if not r.get("violation_count") else "VIOLATED",
                                       "conformance_rate": r.get("conformance_rate"), "violation_count": r.get("violation_count"),
                                       "focus_count": r.get("focus_count"), "quality_run_id": r.get("quality_run_id")})
            except HTTPException as e:
                out["quality"].append({"rule_id": rule["rule_id"], "label_ko": rule["label_ko"], "status": "ERROR", "error": e.detail})
    return out
