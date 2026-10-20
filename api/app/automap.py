"""원천 열 → KS X 9101 표준 열 자동 대응.

열 이름(영문·한글), 표준 열의 한글 설명(col_description), 표본 값의 모양(날짜·숫자·코드)을 함께 보고
열마다 0~1 신뢰도를 매긴다. 모든 표준 표에 대해 같은 계산을 해 가장 잘 맞는 표를 고른다.
"""
from __future__ import annotations

import re
from datetime import date, datetime

# 현장 용어 → 표준 한글 설명에 쓰이는 말. 앞쪽이 원천 열 이름에 들어 있으면 뒤쪽으로 바꿔 본 변형도 비교한다.
# 셋째 값은 그 바꿔 읽기를 얼마나 믿는지 (없으면 0.9).
SYNONYMS: list[tuple] = [
    ("품번", "품목식별자"), ("품목번호", "품목식별자"), ("품목코드", "품목식별자"), ("자재코드", "품목식별자"),
    ("자재번호", "품목식별자"), ("부품번호", "품목식별자"), ("제품코드", "품목식별자"), ("partno", "품목식별자"),
    ("품명", "품목명"), ("자재명", "품목명"), ("부품명", "품목명"), ("제품명", "품목명"),
    ("규격", "품목사양"), ("사양", "품목사양"),
    # 발주번호는 문서 번호(구매문서번호)로 받는다: 한 발주에 품목 줄이 여럿이면 순번은 변환이 매기고 구매발주식별자는 "문서번호-순번" 이 된다
    ("발주번호", "구매문서번호", 0.95), ("po번호", "구매문서번호", 0.95), ("발주no", "구매문서번호", 0.95),
    ("발주번호", "구매발주식별자"), ("po번호", "구매발주식별자"), ("발주no", "구매발주식별자"),
    ("발주순번", "구매문서순번"), ("라인번호", "구매문서순번", 0.8), ("발주라인", "구매문서순번", 0.8),
    ("발주일자", "구매발주일"), ("발주일", "구매발주일"), ("발주수량", "구매발주수량"), ("발주량", "구매발주수량"),
    ("발주단가", "발주단가"), ("발주금액", "발주금액"), ("발주상태", "발주라인상태코드"), ("진행상태", "발주라인상태코드", 0.7),
    ("가입고수량", "구매입고수량", 0.75), ("입고수량", "입고처리수량"), ("입고량", "입고처리수량"),
    ("입고일자", "입고처리일"), ("입고일", "입고처리일"), ("입고번호", "입고식별자"),
    ("납품요청일", "납기예정일", 0.85), ("납기요청일", "납기예정일"), ("납기일", "납기예정일"), ("요청납기", "납기예정일"),
    ("납품일", "납기예정일", 0.7),
    ("업체코드", "공급사식별자"), ("거래처코드", "공급사식별자"), ("협력사코드", "공급사식별자"), ("공급업체코드", "공급사식별자"),
    ("업체명", "공급사명"), ("거래처명", "공급사명"), ("협력사명", "공급사명"), ("공급업체명", "공급사명"),
    ("고객코드", "고객사식별자"), ("고객명", "고객사명"),
    ("수주번호", "수주오더식별자"), ("주문번호", "수주오더식별자"), ("수주수량", "품목수량", 0.75),
    ("작업지시번호", "생산지시식별자"), ("지시번호", "생산지시식별자"), ("wo번호", "생산지시식별자"),
    ("로트번호", "로트식별자"), ("lot번호", "로트식별자"), ("lotno", "로트식별자"),
    ("설비코드", "설비식별자"), ("설비번호", "설비식별자"), ("호기", "설비식별자", 0.8),
    ("공정코드", "공정식별자"), ("창고코드", "창고식별자"), ("사번", "사원식별자"), ("담당자", "사원식별자", 0.7),
    ("단위", "단위코드"), ("통화", "환종코드"), ("두께", "두께"), ("폭", "너비"), ("길이", "길이"),
    ("불량수량", "불량수량"), ("양품수량", "생산수량", 0.85), ("생산수량", "생산수량"), ("실적수량", "생산수량"),
    ("비고", "비고"), ("메모", "비고"),
    # MES 생산실적 내보내기 (실제 현장 파일에서 본 머리글)
    ("배정번호", "생산실적식별자", 0.8), ("실적번호", "생산실적식별자"), ("작업번호", "생산실적식별자", 0.7),
    ("작업일자", "생산실적일자"), ("작업일", "생산실적일자"), ("생산일자", "생산실적일자"), ("생산일", "생산실적일자"),
    ("실적일자", "생산실적일자"), ("실적일", "생산실적일자"),
    ("작업시작", "생산시작일시"), ("시작시간", "생산시작일시", 0.8), ("시작일시", "생산시작일시"),
    ("작업종료", "생산종료일시"), ("종료시간", "생산종료일시", 0.8), ("종료일시", "생산종료일시"),
    ("작업자", "사원식별자", 0.7), ("재작업수량", "재작업수량"),
]

# 영문 약어 → 표준 영문 열 이름 조각
ABBR = {
    "no": "number", "num": "number", "nbr": "number", "qty": "quantity", "dt": "date", "ymd": "date", "cd": "code",
    "nm": "name", "desc": "description", "amt": "price", "prc": "price", "uom": "uom", "po": "purchase order",
    "so": "sales order", "wo": "production order", "mo": "production order", "part": "item", "mat": "item",
    "material": "item", "matnr": "item id", "sku": "item id", "vend": "vendor", "supplier": "vendor",
    "cust": "customer", "eqp": "equipment", "eq": "equipment", "equip": "equipment", "wh": "warehouse",
    "seq": "sequence", "req": "request", "del": "delivery", "dlv": "delivery", "rcv": "receipt", "rcpt": "receipt",
    "gr": "goods receipt", "lotno": "lot id", "op": "operation", "oper": "operation", "emp": "personnel",
    "temp": "temperature", "stat": "status", "sts": "status",
}
GENERIC_EN = {"id", "code", "number", "name", "date", "time", "type", "quantity"}

ID_LIKE = re.compile(r"^(?=.*[A-Za-z])(?=.*\d)[A-Za-z0-9][A-Za-z0-9_\-./]{2,49}$")
NUM = re.compile(r"^[+-]?(\d{1,3}(,\d{3})+|\d+)(\.\d+)?$")
DATE = re.compile(r"^(\d{4})[-./](\d{1,2})[-./](\d{1,2})([ T]\d{1,2}:\d{2}(:\d{2}(\.\d+)?)?)?$")
YMD8 = re.compile(r"^(19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])$")
BOOL = {"y", "n", "yes", "no", "true", "false", "t", "f", "예", "아니오", "o", "x"}


def norm(x: str | None) -> str:
    return re.sub(r"[^0-9a-z가-힣]", "", (x or "").lower())


def _bigrams(s: str) -> set[str]:
    return {s[i:i + 2] for i in range(len(s) - 1)} if len(s) > 1 else {s}


def _dice(a: str, b: str) -> float:
    if not a or not b:
        return 0.0
    if a == b:
        return 1.0
    x, y = _bigrams(a), _bigrams(b)
    return 2 * len(x & y) / (len(x) + len(y))


def _en_tokens(name: str) -> list[str]:
    s = re.sub(r"([a-z])([A-Z])", r"\1_\2", name)
    out: list[str] = []
    for p in re.split(r"[^A-Za-z0-9]+", s.lower()):
        if p:
            out.extend(ABBR.get(p, p).split())
    return out


def _variants(src: str) -> dict[str, float]:
    """원천 열 이름의 비교용 변형과 그 믿음 정도 (동의어를 바꿔 끼운 것 포함)."""
    n = norm(src)
    vs = {n: 1.0}
    for a, b, *w in SYNONYMS:
        for v, p in list(vs.items()):
            if a in v:
                nv = v.replace(a, b)
                vs[nv] = max(vs.get(nv, 0.0), p * (w[0] if w else 0.9))
    return {v: p for v, p in vs.items() if v}


def _kind(c: str) -> str:
    """열이 무엇을 뜻하는지: id(식별자·코드·번호), name(이름), 그 밖."""
    n = norm(c)
    if n.endswith(("식별자", "코드", "번호", "id", "code", "no", "number")):
        return "id"
    if n.endswith(("명", "name", "nm")) and not n.endswith("설명"):
        return "name"
    return "other"


def profile(values: list) -> dict:
    """표본 값의 모양."""
    vals = [v for v in values if v is not None and str(v).strip() != ""]
    if not vals:
        return {"kind": "empty", "n": 0, "unique": 0.0, "maxlen": 0, "idlike": 0.0}
    k = {"date": 0, "num": 0, "bool": 0, "text": 0}
    idl = 0
    for v in vals:
        if isinstance(v, bool):
            k["bool"] += 1
            continue
        if isinstance(v, (int, float)):
            k["num"] += 1
            continue
        if isinstance(v, (date, datetime)):
            k["date"] += 1
            continue
        s = str(v).strip()
        if DATE.match(s) or YMD8.match(s):
            k["date"] += 1
        elif NUM.match(s):
            k["num"] += 1
        elif s.lower() in BOOL:
            k["bool"] += 1
        else:
            k["text"] += 1
        if ID_LIKE.match(s):
            idl += 1
    kind = max(k, key=lambda x: k[x])
    if k[kind] < 0.8 * len(vals):
        kind = "mixed"   # 모양이 섞여 있으면 이름만 믿고 신뢰도를 조금 낮춘다
    return {"kind": kind, "n": len(vals), "unique": len({str(v) for v in vals}) / len(vals),
            "maxlen": max(len(str(v)) for v in vals), "idlike": idl / len(vals)}


def _family(pg_type: str) -> tuple[str, int | None]:
    t = pg_type.lower()
    if t.startswith(("date", "timestamp")):
        return "date", None
    if t.startswith(("numeric", "integer", "bigint", "smallint", "double", "real")):
        return "num", None
    if t.startswith("boolean"):
        return "bool", None
    m = re.search(r"\((\d+)\)", t)
    return "text", int(m.group(1)) if m else None


_FIT = {  # (원천 값 모양, 표준 열 형) → 배율
    ("date", "date"): 1.0, ("date", "text"): 0.6, ("date", "num"): 0.05, ("date", "bool"): 0.05,
    ("num", "num"): 1.0, ("num", "text"): 0.8, ("num", "date"): 0.1, ("num", "bool"): 0.3,
    ("text", "text"): 1.0, ("text", "num"): 0.05, ("text", "date"): 0.05, ("text", "bool"): 0.2,
    ("bool", "bool"): 1.0, ("bool", "text"): 0.8, ("bool", "num"): 0.2, ("bool", "date"): 0.05,
}


def name_score(src: str, col: dict) -> float:
    """이름·한글 설명만 본 유사도 (0~1)."""
    tn, tl = norm(col["name"]), norm(col.get("label_ko"))
    best = 0.0
    for v, p in _variants(src).items():
        if v in (tn, tl):
            best = max(best, p)
        elif tl:
            best = max(best, p * _dice(v, tl))
    # 영문 열 이름끼리: 낱말 겹침
    st, ct = set(_en_tokens(src)), set(_en_tokens(col["name"]))
    if st and ct and (st - GENERIC_EN):
        j = len(st & ct) / len(st | ct)
        if st & ct - GENERIC_EN:
            best = max(best, j)
    # 의미가 다르면 깎는다: 이름(…명) ↔ 식별자(…코드·번호)
    sk, ck = _kind(src), _kind(col.get("label_ko") or col["name"])
    if {sk, ck} == {"id", "name"}:
        best *= 0.4
    return best


def score(src: str, prof: dict, col: dict) -> float:
    s = name_score(src, col)
    if s <= 0:
        return 0.0
    fam, length = _family(col["type"])
    if prof["kind"] != "empty":
        s *= 0.8 if prof["kind"] == "mixed" else _FIT.get((prof["kind"], fam), 1.0)
        if fam == "text" and length and prof["maxlen"] > length:
            s *= 0.3
        if prof["idlike"] > 0.8 and _kind(col["name"]) == "id":
            s = min(1.0, s + 0.05)
    return round(min(s, 1.0), 2)


MAP_MIN = 0.55


SCOPE = ("enterprise_id", "site_id", "plant_id")
_INT = ("integer", "smallint", "bigint")


def auto_keys(table: dict, mapped: set[str]) -> dict[str, dict[str, list[str]]]:
    """원천에 없어도 변환(gov.auto_key_columns)이 채워 주는 키 열. 같은 규칙을 파이썬에서 되풀이한다.
    seq: 기본키·고유키에 든 정수 …_sequence 열 → 같은 키의 다른 열이 모두 대응돼 있으면 문서별 1,2,3… 번호.
    derived: 대응 안 된 문자 기본키 열 → 다른 고유키의 열이 모두 채워지면 그 값들을 '-' 로 이은 식별자."""
    types = {c["name"]: c["type"].lower() for c in table["columns"]}
    pk = [c["name"] for c in table["columns"] if c["pk"]]
    keys = [pk] + [list(k) for k in table.get("unique_keys") or []]
    seq: dict[str, list[str]] = {}
    for k in keys:
        for c in k:
            if c in mapped or c in seq or not c.endswith("_sequence") or types.get(c) not in _INT:
                continue
            sib = [x for x in k if x != c and x not in SCOPE]
            if all(x in mapped for x in sib):
                seq[c] = sib
    derived: dict[str, list[str]] = {}
    for c in pk:
        if c in mapped or c in SCOPE or c in seq:
            continue
        for k in keys[1:]:
            sib = [x for x in k if x not in SCOPE]
            if sib and c not in sib and all(x in mapped or x in seq for x in sib):
                derived[c] = sib
                break
    return {"seq": seq, "derived": derived}


def missing_keys(table: dict, mapped: set[str]) -> list[str]:
    """원천이 꼭 대응시켜야 하는데 아직 안 된 기본키 열 (회사·사업장·공장과 자동으로 채워지는 열은 뺀다)."""
    auto = auto_keys(table, mapped)
    filled = mapped | set(auto["seq"]) | set(auto["derived"])
    return [c["name"] for c in table["columns"] if c["pk"] and c["name"] not in SCOPE and c["name"] not in filled]


def map_table(cols: list[str], profs: dict[str, dict], table: dict) -> tuple[dict[str, str], dict[str, float]]:
    """한 표에 대해 원천 열마다 가장 맞는 표준 열을 하나씩 (겹치지 않게) 고른다."""
    pairs = []
    for c in cols:
        for tc in table["columns"]:
            if tc["name"] in ("site_id", "plant_id") and _kind(c) != "id":
                continue
            sc = score(c, profs.get(c, {"kind": "empty"}), tc)
            if sc >= MAP_MIN:
                pairs.append((sc, tc["pk"], c, tc["name"]))
    pairs.sort(key=lambda p: (-p[0], not p[1]))
    m: dict[str, str] = {}
    conf: dict[str, float] = {}
    taken: set[str] = set()
    for sc, _, c, tn in pairs:
        if c in m or tn in taken:
            continue
        m[c], conf[c] = tn, sc
        taken.add(tn)
    return m, conf


def pick(cols: list[str], profs: dict[str, dict], entity: str | None, targets: dict[str, dict]) -> list[dict]:
    """모든 표준 표를 점수 순으로. 기본키를 다 채울 수 있는 표를 앞에 둔다."""
    ent = norm(entity)
    out = []
    for name, t in targets.items():
        m, conf = map_table(cols, profs, t)
        if not m:
            continue
        missing = missing_keys(t, set(m.values()))
        pk_ok = not missing
        sc = sum(conf.values()) + (1.0 if pk_ok else -1.5 * len(missing))
        base = re.sub(r"_(line|header)$", "", name)   # 헤더-라인 명사: 엔터티 이름은 보통 명사 이름(purchase_order)으로 온다
        if ent and (norm(name) in ent or norm(base) == ent or (t["label_ko"] and norm(t["label_ko"]) in ent)):
            sc += 1.5
        out.append({"table": name, "label_ko": t["label_ko"], "score": round(sc, 2), "pk_ok": pk_ok,
                    "map": m, "confidence": conf})
    out.sort(key=lambda x: (-x["score"], x["table"]))
    return out
