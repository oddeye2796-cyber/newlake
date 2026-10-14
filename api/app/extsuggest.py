"""표준 표에 자리가 없는 원천 열 → 온톨로지 확장 제안.

열 이름·값 모양을 보고 (1) 이미 등록된 회사 확장 속성(arcon)과 맞추거나, (2) 대상 클래스에 붙일 새 확장 속성을
이름·형·단위까지 제안한다. 이름 마스터(…명)는 참조 속성(REF) 후보로 낸다. LLM·임베딩 없이 규칙만으로 하고,
최종 결정은 스튜어드가 확장 제안 화면에서 한다.
"""
import re

from . import automap

XSD = "http://www.w3.org/2001/XMLSchema#"
ARCON = "https://ontology.impix.co.kr/arcon/"
# 한글 열 이름 조각 → (영문 이름, 한글 이름, xsd 형, 단위). 앞에서부터 가장 긴 조각이 이긴다.
HINTS: list[tuple[str, str, str, str, str | None]] = [
    ("업체명", "vendorName", "업체명", "string", None), ("거래처명", "partnerName", "거래처명", "string", None), ("협력사명", "supplierName", "협력사명", "string", None),
    ("고객명", "customerName", "고객명", "string", None), ("담당자명", "contactName", "담당자명", "string", None), ("담당자", "contactName", "담당자", "string", None),
    ("두께", "thickness", "두께", "decimal", "mm"), ("폭", "width", "폭", "decimal", "mm"), ("너비", "width", "너비", "decimal", "mm"),
    ("길이", "length", "길이", "decimal", "mm"), ("높이", "height", "높이", "decimal", "mm"), ("무게", "weight", "무게", "decimal", "kg"),
    ("중량", "weight", "중량", "decimal", "kg"), ("직경", "diameter", "직경", "decimal", "mm"), ("온도", "temperature", "온도", "decimal", "℃"),
    ("습도", "humidity", "습도", "decimal", "%"), ("압력", "pressure", "압력", "decimal", "bar"), ("전압", "voltage", "전압", "decimal", "V"),
    ("단가", "unitPrice", "단가", "decimal", "KRW"), ("금액", "amount", "금액", "decimal", "KRW"), ("세액", "taxAmount", "세액", "decimal", "KRW"),
    ("할인", "discount", "할인", "decimal", None), ("수량", "quantity", "수량", "decimal", None), ("비율", "ratio", "비율", "decimal", "%"),
    ("색상", "color", "색상", "string", None), ("재질", "material", "재질", "string", None), ("등급", "grade", "등급", "string", None),
    ("비고", "remark", "비고", "string", None), ("메모", "memo", "메모", "string", None), ("설명", "description", "설명", "string", None),
    ("일자", "date", "일자", "date", None), ("일시", "dateTime", "일시", "dateTime", None), ("시각", "dateTime", "시각", "dateTime", None),
    ("여부", "flag", "여부", "boolean", None), ("코드", "code", "코드", "string", None), ("번호", "number", "번호", "string", None),
    ("명", "name", "이름", "string", None),
]
RANGE_BY_KIND = {"num": "decimal", "date": "date", "bool": "boolean"}
MATCH_MIN = 0.7


def _ascii_name(src: str) -> str:
    """영문 열 이름이면 camelCase 로, 아니면 None."""
    toks = [t for t in re.split(r"[^A-Za-z0-9]+", src) if t]
    if not toks or not re.search(r"[A-Za-z]", src) or re.search(r"[가-힣]", src):
        return ""
    words = []
    for t in toks:
        words.extend(re.sub(r"([a-z])([A-Z])", r"\1 \2", t).split())
    return words[0].lower() + "".join(w[:1].upper() + w[1:].lower() for w in words[1:])


def suggest(column: str, prof: dict, samples: list, ext_props: list[dict], target_class_iri: str | None, rows_seen: int,
            taken: set[str] | None = None) -> dict:
    """ext_props: [{property_iri, local_name, label_ko, kind, range_iri, unit, domain_class_iri}] — 이미 있는 확장 속성.
    taken: 이번 배치에서 이미 제안한 영문 이름 (겹치면 숫자를 붙인다)."""
    n = automap.norm(column)
    taken = taken if taken is not None else set()
    # 1) 이미 있는 확장 속성과 맞추기 (이름·한글 이름 유사도)
    best, best_s = None, 0.0
    for p in ext_props:
        s = automap.name_score(column, {"name": p["local_name"], "label_ko": p.get("label_ko")})
        if p.get("domain_class_iri") and target_class_iri and p["domain_class_iri"] != target_class_iri:
            s *= 0.85
        if s > best_s:
            best, best_s = p, s
    if best and best_s >= MATCH_MIN:
        return {"column_name": column, "sample_values": samples, "profile": prof["kind"], "kind": "REF" if best["kind"] == "OBJECT" else "PROPERTY",
                "target_class_iri": best.get("domain_class_iri") or target_class_iri, "suggested_local_name": best["local_name"], "suggested_label": best.get("label_ko"),
                "suggested_range_iri": best.get("range_iri"), "unit": best.get("unit"), "confidence": round(best_s, 3), "matched_property_iri": best["property_iri"],
                "rationale": f"이미 등록된 확장 속성 arcon:{best['local_name']} 과 이름이 맞습니다", "rows_seen": rows_seen}
    # 2) 새 속성 제안
    local, label, rng, unit, conf, why = "", column, None, None, 0.3, "표준 표에 맞는 열이 없어 확장 속성으로 제안합니다"
    for frag, en, ko, r, u in HINTS:
        if frag in n:
            prefix = n.split(frag)[0]
            local = en if not prefix else _ascii_name(prefix) + en[:1].upper() + en[1:] if _ascii_name(prefix) else en
            label, rng, unit, conf = column, r, u, 0.6
            why = f"열 이름의 '{frag}' 로 보아 {ko} 성격의 값입니다"
            break
    if not local:
        local = _ascii_name(column) or "attr" + re.sub(r"[^0-9a-z]", "", n)[:20].capitalize() or "attr"
    if prof["kind"] in RANGE_BY_KIND:
        if not rng or rng == "string":
            rng = RANGE_BY_KIND[prof["kind"]]
        conf = min(1.0, conf + 0.15)
    # 이름이 이미 있는 속성(표준·확장)과 겹치면 클래스 이름을 앞에 붙이고, 그래도 겹치면 숫자를 붙인다
    used = taken | {p["local_name"] for p in ext_props}
    if local in used and target_class_iri:
        cls = target_class_iri.rstrip("/").split("/")[-1]
        local = cls[:1].lower() + cls[1:] + local[:1].upper() + local[1:]
    base, i = local, 2
    while local in used:
        local, i = f"{base}{i}", i + 1
    taken.add(local)
    kind = "PROPERTY"
    if n.endswith("명") and prof["kind"] in ("text", "mixed") and prof.get("unique", 0) < 0.9:
        kind = "REF"
        why += ". 이름 마스터로 보이면 마스터 코드로 바꾸는 참조 속성으로 두는 편이 좋습니다"
    return {"column_name": column, "sample_values": samples, "profile": prof["kind"], "kind": kind, "target_class_iri": target_class_iri,
            "suggested_local_name": local, "suggested_label": label, "suggested_range_iri": XSD + (rng or "string"), "unit": unit,
            "confidence": round(conf, 3), "matched_property_iri": None, "rationale": why, "rows_seen": rows_seen}
