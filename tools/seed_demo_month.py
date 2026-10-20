#!/usr/bin/env python3
"""시연용 한 달치 목업 데이터 — 가상 회사 '에이크미 반도체'(ACME) 본사 사업장의 후공정 1·2공장.

화면마다 볼거리가 생기도록 최근 30일(+수주 리드타임만큼 앞쪽)의 업무 데이터와 관리 기록을 함께 만든다.
  · 기준 정보: 공장·부서·사람·공정·설비·측정 파라미터·품목(완제품·원자재)·BOM·창고·공급사·고객
  · 업무: 수주 → 생산지시 → 로트 → 공정 착공·완료 → 생산실적(불량 유형·설비 가동) → 출하,
          설비 파라미터 15분 간격 측정(규격 이탈 사건 포함), 발주 → 입고 → 재고, 설비 상태·알람
  · 관리: 원천 시스템, 적재 배치(원천 존 행 그대로)와 표준 변환 기록, 데이터셋·필드·계보·매핑,
          파이프라인 실행 이력, 품질 규칙·검사 이력·위반, 온톨로지 확장 제안, 데이터 접근 요청, 리스크·조치, 감사 기록
이름·회사·사람은 모두 지어낸 것이다. 실제 현장 데이터를 넣지 않는다.

사용:  PGHOST=… PGPORT=… PGUSER=… PGDATABASE=lake python3 tools/seed_demo_month.py
       [--anchor 2026-10-20] [--days 30] [--seed 7]
  · db/apply.sh·db/seed/dev_seed.sql 다음에 스키마 소유 계정으로 돌린다 (RLS 를 지나야 하므로).
  · 다시 돌리면 지난번 시드를 지우고 오늘(한국 날짜) 기준으로 새로 만든다. 같은 날짜·같은 --seed 면 같은 결과.
  · 표 열 목록을 실행 때 DB 에서 읽어, 없는 열은 건너뛴다 (표준 개정으로 열이 바뀌어도 버티도록).
  · 감사 기록은 지울 수 없어서, 다시 돌릴 때는 지난 시드 이후 날짜만 더 쌓는다.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import os
import random
import sys
import uuid
import zlib
from collections import defaultdict
from zoneinfo import ZoneInfo

import psycopg
from psycopg.types.json import Jsonb

KST = ZoneInfo("Asia/Seoul")
MARK = "demo-seed"                       # ksx 행의 creator_id, 적재 배치의 scenario_id
NS = uuid.UUID("5d0c1a7e-2b7f-4c55-9a51-6d656d6f7365")
ENT, SITE = "ACME", "HQ"
AUDIT_NET = "10.77."                     # 시드가 쌓은 감사 기록의 client_ip 대역
DATA = "https://data.impix.co.kr/ACME/{}/{}"
KSX = "https://ontology.impix.co.kr/ksx9101/"
ARCON = "https://ontology.impix.co.kr/arcon/"


def uid(*parts) -> uuid.UUID:
    return uuid.uuid5(NS, "/".join(str(p) for p in parts))


# ── 기준 정보 ────────────────────────────────────────────────────────────────

DEPTS = [("D-PRD1", "생산1팀"), ("D-PRD2", "생산2팀"), ("D-QA", "품질보증팀"), ("D-PUR", "구매팀"), ("D-EQ", "설비기술팀")]
PEOPLE = [  # personnel_id, 이름, 부서, 공장
    ("E2002", "강현우", "D-PRD1", "P1"), ("E2003", "윤서진", "D-PRD1", "P1"), ("E2004", "조민재", "D-PRD1", "P1"),
    ("E2005", "임하늘", "D-PRD2", "P2"), ("E2006", "한도윤", "D-PRD2", "P2"), ("E1002", "송지아", "D-QA", "P1"),
    ("E1003", "배준호", "D-QA", "P2"), ("E3001", "문채원", "D-PUR", "P1"), ("E3002", "신우석", "D-PUR", "P2"),
    ("E4001", "오태경", "D-EQ", "P1"), ("E4002", "남궁별", "D-EQ", "P2"),
]
OPS = [  # operation_id, 이름, 공장
    ("OP-10", "웨이퍼 소잉", "P1"), ("OP-50", "몰딩", "P1"), ("OP-70", "최종 검사", "P1"),
    ("OP-210", "웨이퍼 소잉", "P2"), ("OP-220", "다이 본딩", "P2"), ("OP-240", "리플로우", "P2"), ("OP-270", "최종 검사", "P2"),
]
EQUIP = [  # equipment_id, 이름, 공정, 공장, 유형, 제조사(가상), 담당
    ("EQ-01", "소잉기 1호기", "OP-10", "P1", "PROD", "한솔정밀", "E4001"),
    ("EQ-02", "다이 본더 2호기", "OP-20", "P1", "PROD", "대명기계", "E4001"),
    ("EQ-04", "와이어 본더 4호기", "OP-30", "P1", "PROD", "대명기계", "E4001"),
    ("EQ-05", "몰딩 프레스 5호기", "OP-50", "P1", "PROD", "세움테크", "E4001"),
    ("EQ-06", "리플로우 오븐 6호기", "OP-40", "P1", "PROD", "누리열기술", "E4001"),
    ("EQ-09", "최종 검사기 9호기", "OP-70", "P1", "INSP", "비전온", "E4001"),
    ("EQ-21", "소잉기 21호기", "OP-210", "P2", "PROD", "한솔정밀", "E4002"),
    ("EQ-22", "다이 본더 22호기", "OP-220", "P2", "PROD", "대명기계", "E4002"),
    ("EQ-24", "리플로우 오븐 24호기", "OP-240", "P2", "PROD", "누리열기술", "E4002"),
    ("EQ-25", "최종 검사기 25호기", "OP-270", "P2", "INSP", "비전온", "E4002"),
]
# 설비 파라미터: id, 이름, 단위, 설비, 공장, 기준값, 흔들림, LSL, USL  (TEMP01 은 예시 데이터에 이미 있다)
PARAMS = [
    ("TEMP01", "존3 온도", "℃", "EQ-07", "P1", 245.0, 2.2, 235, 255),
    ("EQ06-T3", "존3 온도", "℃", "EQ-06", "P1", 244.0, 2.0, 235, 255),
    ("EQ02-BT", "본딩 온도", "℃", "EQ-02", "P1", 160.0, 1.6, 150, 170),
    ("EQ03-BF", "본딩 하중", "gf", "EQ-03", "P1", 21.0, 0.6, 18, 24),
    ("EQ04-BF", "본딩 하중", "gf", "EQ-04", "P1", 21.0, 0.6, 18, 24),
    ("EQ05-MP", "금형 압력", "MPa", "EQ-05", "P1", 7.5, 0.18, 6.8, 8.2),
    ("EQ01-SP", "스핀들 회전수", "krpm", "EQ-01", "P1", 30.0, 0.35, 28.5, 31.5),
    ("EQ24-T3", "존3 온도", "℃", "EQ-24", "P2", 246.0, 2.1, 235, 255),
    ("EQ22-BT", "본딩 온도", "℃", "EQ-22", "P2", 158.0, 1.5, 150, 170),
    ("EQ21-SP", "스핀들 회전수", "krpm", "EQ-21", "P2", 30.0, 0.35, 28.5, 31.5),
]
# 규격 이탈 사건: 설비, 파라미터, 며칠 전, 시작 시, 지속 시간, 기준값에서 벗어나는 양, 그 공정 불량률
EPISODES = [
    ("EQ-05", "EQ05-MP", 25, 14, 2, +0.9, 0.012),
    ("EQ-06", "EQ06-T3", 18, 9, 4, +14.0, 0.038),
    ("EQ-04", "EQ04-BF", 9, 14, 3, -3.6, 0.021),
    ("EQ-24", "EQ24-T3", 2, 8, 3, +13.0, 0.041),
]
ROUTES = {
    "P1": [("OP-10", ["EQ-01"]), ("OP-20", ["EQ-02"]), ("OP-30", ["EQ-03", "EQ-04"]), ("OP-40", ["EQ-06", "EQ-07"]),
           ("OP-50", ["EQ-05"]), ("OP-70", ["EQ-09"])],
    "P2": [("OP-210", ["EQ-21"]), ("OP-220", ["EQ-22"]), ("OP-240", ["EQ-24"]), ("OP-270", ["EQ-25"])],
}
# 공정별 평소 불량 (유형, 세부)
OP_DEFECTS = {
    "OP-10": [("APP", "CHIPPING"), ("DIM", "KERF")], "OP-20": [("ASSY", "DIE_TILT"), ("MAT", "EPOXY_VOID")],
    "OP-30": [("ASSY", "WIRE_SWEEP"), ("ASSY", "NON_STICK")], "OP-40": [("ASSY", "VOID"), ("ASSY", "BRIDGE")],
    "OP-50": [("APP", "INCOMPLETE_FILL"), ("APP", "FLASH")], "OP-70": [("FUNC", "OPEN_SHORT"), ("APP", "MARK_ERR")],
    "OP-210": [("APP", "CHIPPING")], "OP-220": [("ASSY", "DIE_TILT")], "OP-240": [("ASSY", "VOID"), ("ASSY", "BRIDGE")],
    "OP-270": [("FUNC", "OPEN_SHORT"), ("PKG", "TRAY_MIX")],
}
FG = {  # 완제품: 이름, 공장, 주 고객 후보, 수주 수량 범위, 단가(원)
    "ITM-A100": ("BGA 패키지 A100", "P1", ["C-77", "C-81"], (2000, 5200), 820),
    "ITM-A120": ("BGA 패키지 A120", "P1", ["C-81", "C-77"], (1500, 4000), 940),
    "ITM-B200": ("QFN 패키지 B200", "P1", ["C-85"], (1500, 3600), 410),
    "ITM-C300": ("QFN 패키지 C300", "P2", ["C-85", "C-90"], (1500, 3600), 450),
    "ITM-D400": ("LGA 모듈 D400", "P2", ["C-90"], (1000, 2600), 1650),
}
RM = {  # 원자재: 이름, 공장, 단위, 주 공급사, 단가, 안전재고, 완제품 1개당 소요량
    "RM-SUB-A": ("BGA 기판 14x14", "P1", "EA", "V-101", 180, 9000, {"ITM-A100": 1, "ITM-A120": 1}),
    "RM-LF-Q":  ("QFN 리드프레임", "P1", "EA", "V-102", 45, 6000, {"ITM-B200": 1}),
    "RM-WIRE":  ("금 와이어 0.8mil", "P1", "M", "V-103", 95, 40000, {"ITM-A100": 2.4, "ITM-A120": 2.8, "ITM-B200": 1.6}),
    "RM-SB":    ("솔더볼 0.3mm", "P1", "EA", "V-103", 0.4, 1200000, {"ITM-A100": 196, "ITM-A120": 256}),
    "RM-EMC":   ("몰딩 컴파운드", "P1", "KG", "V-104", 21000, 120, {"ITM-A100": 0.0042, "ITM-A120": 0.0048, "ITM-B200": 0.0021}),
    "RM-DIE-1": ("다이 A계열(웨이퍼 소잉 전)", "P1", "EA", "V-106", 260, 12000, {"ITM-A100": 1, "ITM-A120": 1, "ITM-B200": 1}),
    "RM-LF-Q2": ("QFN 리드프레임 2형", "P2", "EA", "V-102", 48, 5000, {"ITM-C300": 1}),
    "RM-SUB-L": ("LGA 기판", "P2", "EA", "V-101", 320, 3000, {"ITM-D400": 1}),
    "RM-DIE-2": ("다이 C계열", "P2", "EA", "V-106", 280, 6000, {"ITM-C300": 1, "ITM-D400": 2}),
    "RM-TRAY":  ("JEDEC 트레이", "P2", "EA", "V-105", 650, 1500, {"ITM-C300": 0.0122, "ITM-D400": 0.025}),
}
VENDORS = [("V-101", "대성기판"), ("V-102", "한결리드텍"), ("V-103", "세진메탈"), ("V-104", "동원케미칼"),
           ("V-105", "미래패키징"), ("V-106", "가람웨이퍼")]
CUSTOMERS = [("C-81", "누리모바일"), ("C-85", "세온오토모티브"), ("C-90", "다온네트웍스")]  # C-77 한빛전자는 예시 데이터에 있다
WAREHOUSES = [("WH-RM1", "1공장 자재창고", "RM", "P1"), ("WH-FG1", "1공장 완제품창고", "FG", "P1"),
              ("WH-RM2", "2공장 자재창고", "RM", "P2"), ("WH-FG2", "2공장 완제품창고", "FG", "P2")]
PLANT_WH = {"P1": ("WH-RM1", "WH-FG1"), "P2": ("WH-RM2", "WH-FG2")}
APP_USERS = [  # user_id, 이름, 역할, 공장 범위(None=회사 전체), personnel_id
    ("u-han", "한설비", "data_engineer", None, "E4001"),
    ("u-yoon", "윤온톨", "ontology_manager", None, None),
    ("u-oh", "오이공", "production_manager", "P2", "E2005"),
]


class Seeder:
    def __init__(self, conn: psycopg.Connection, anchor: dt.date, days: int, seed: int):
        self.c = conn
        self.T = anchor
        self.days = days
        self.rnd = random.Random(f"{seed}:{anchor.isoformat()}")
        today = dt.datetime.now(KST).date()
        self.now = dt.datetime.now(KST).replace(tzinfo=None) if anchor == today else dt.datetime.combine(anchor, dt.time(17, 30))
        self.start = anchor - dt.timedelta(days=days - 1)     # 화면에서 보는 첫날
        self.lead = 12                                        # 그보다 앞선 수주·생산 (리드타임)
        self._cols: dict[str, dict[str, str]] = {}
        self.dropped: dict[str, set[str]] = defaultdict(set)
        self.counts: dict[str, int] = defaultdict(int)
        self.batches: list[dict] = []

    # ── 쓰기 도우미 ──────────────────────────────────────────────────────────
    def cols(self, table: str) -> dict[str, str]:
        if table not in self._cols:
            s, t = table.split(".")
            self._cols[table] = {r[0]: r[1] for r in self.c.execute(
                "SELECT column_name, udt_name FROM information_schema.columns WHERE table_schema = %s AND table_name = %s"
                " AND is_generated = 'NEVER'",
                (s, t)).fetchall()}
        return self._cols[table]

    def has(self, table: str) -> bool:
        return bool(self.cols(table))

    def _fit(self, table: str, rows: list[dict]) -> tuple[list[str], list[tuple]]:
        cols = self.cols(table)
        if not cols:
            self.dropped[table].add("(표 없음)")
            return [], []
        names: list[str] = []
        for r in rows:
            for k in r:
                if k not in names:
                    if k in cols:
                        names.append(k)
                    else:
                        self.dropped[table].add(k)
        out = []
        for r in rows:
            out.append(tuple(Jsonb(r[k]) if cols[k] == "jsonb" and r.get(k) is not None and not isinstance(r[k], Jsonb) else r.get(k)
                             for k in names))
        return names, out

    def ksx(self, table: str, plant: str | None, row: dict, src: str, at: dt.datetime | None = None) -> dict:
        """ksx 행 공통 열: 회사·사업장·공장, 시드 표시(creator_id), 원천 시스템, 적재 시각."""
        at = at or self.now
        base = {"enterprise_id": ENT, "site_id": SITE, "plant_id": plant, "creator_id": MARK,
                "creation_date_time": at, "lake_source_system": src,
                "lake_loaded_at": min(at + dt.timedelta(minutes=self.rnd.randint(3, 40)), self.now).replace(tzinfo=KST)}
        base.update(row)
        return base

    @staticmethod
    def _groups(rows: list[dict]) -> list[list[dict]]:
        """열 구성이 같은 행끼리 묶는다 (빠진 열은 NULL 이 아니라 기본값을 받도록)."""
        g: dict[tuple, list[dict]] = {}
        for r in rows:
            g.setdefault(tuple(r), []).append(r)
        return list(g.values())

    def insert(self, table: str, rows: list[dict], conflict: str = "DO NOTHING") -> int:
        if not rows:
            return 0
        if len(self._groups(rows)) > 1:
            return sum(self.insert(table, g, conflict) for g in self._groups(rows))
        names, vals = self._fit(table, rows)
        if not names:
            return 0
        sql = f"INSERT INTO {table} ({', '.join(names)}) VALUES ({', '.join(['%s'] * len(names))})"
        if conflict:
            sql += f" ON CONFLICT {conflict}"
        with self.c.cursor() as cur:
            cur.executemany(sql, vals)
        self.counts[table] += len(rows)
        return len(rows)

    def copy(self, table: str, rows: list[dict]) -> int:
        if not rows:
            return 0
        if len(self._groups(rows)) > 1:
            return sum(self.copy(table, g) for g in self._groups(rows))
        names, vals = self._fit(table, rows)
        if not names:
            return 0
        with self.c.cursor() as cur, cur.copy(f"COPY {table} ({', '.join(names)}) FROM STDIN") as cp:
            for v in vals:
                cp.write_row(v)
        self.counts[table] += len(rows)
        return len(rows)

    def day(self, d: int) -> dt.date:
        """d: 기준일로부터 며칠 전(양수) / 후(음수)."""
        return self.T - dt.timedelta(days=d)

    def at(self, day: dt.date, hour: float) -> dt.datetime:
        return dt.datetime.combine(day, dt.time(0)) + dt.timedelta(hours=hour)

    # ── 지난 시드 지우기 ─────────────────────────────────────────────────────
    def reset(self):
        c = self.c
        seeded_batches = [r[0] for r in c.execute(
            "SELECT batch_id FROM raw.ingest_batch WHERE scenario_id = %s", (MARK,)).fetchall()]
        tables = [r[0] for r in c.execute(
            "SELECT c.table_name FROM information_schema.columns c JOIN pg_class k ON k.relname = c.table_name"
            "  JOIN pg_namespace n ON n.oid = k.relnamespace AND n.nspname = c.table_schema"
            " WHERE c.table_schema = 'ksx' AND c.column_name = 'creator_id' AND NOT k.relispartition"
            "   AND k.relkind IN ('r', 'p') ORDER BY 1").fetchall()]
        masters = {"enterprise", "site", "plant", "department", "personnel", "operation", "equipment", "equipment_parameter",
                   "item_master", "bom_header", "bom", "warehouse_location", "vendor_party_master", "customer_party_master"}
        n = 0
        for t in tables:
            if t in masters:    # 기준 정보는 지우지 않는다 (다른 적재가 참조할 수 있다). 다시 넣을 때 그대로 둔다.
                continue
            has_batch = "lake_batch_id" in self.cols(f"ksx.{t}")
            cur = c.execute(f"DELETE FROM ksx.{t} WHERE creator_id = %s"
                            + (" OR lake_batch_id = ANY(%s)" if has_batch else ""),
                            (MARK, seeded_batches) if has_batch else (MARK,))
            n += cur.rowcount
        if self.has("ksx.extension_attribute") and "batch_id" in self.cols("ksx.extension_attribute"):
            c.execute("DELETE FROM ksx.extension_attribute WHERE batch_id = ANY(%s)", (seeded_batches,))
        if self.has("raw.std_preimage") and "batch_id" in self.cols("raw.std_preimage"):
            c.execute("DELETE FROM raw.std_preimage WHERE batch_id = ANY(%s)", (seeded_batches,))
        c.execute("DELETE FROM onto.extension_proposal WHERE batch_id = ANY(%s)", (seeded_batches,))
        c.execute("DELETE FROM raw.landing_record WHERE batch_id = ANY(%s)", (seeded_batches,))
        c.execute("DELETE FROM raw.landing_file WHERE batch_id = ANY(%s)", (seeded_batches,))
        runs = [r[0] for r in c.execute("SELECT run_id FROM catalog.job_run WHERE code_version = %s", (MARK,)).fetchall()]
        qruns = [r[0] for r in c.execute(
            "SELECT quality_run_id FROM catalog.quality_run WHERE report_uri LIKE %s", (f"%{MARK}%",)).fetchall()]
        c.execute("DELETE FROM catalog.quality_violation WHERE quality_run_id = ANY(%s)", (qruns,))
        c.execute("DELETE FROM catalog.quality_run WHERE quality_run_id = ANY(%s) OR job_run_id = ANY(%s)", (qruns, runs))
        c.execute("DELETE FROM raw.ingest_batch WHERE batch_id = ANY(%s)", (seeded_batches,))
        c.execute("DELETE FROM catalog.job_run WHERE run_id = ANY(%s)", (runs,))
        c.execute("DELETE FROM gov.action_execution WHERE requested_by LIKE %s OR execution_id IN"
                  " (SELECT execution_id FROM gov.action_execution e JOIN sem.risk_event r ON r.event_id = e.risk_event_id"
                  "   WHERE r.derived_by LIKE %s)", (f"%{MARK}%", f"%{MARK}%"))
        c.execute("DELETE FROM sem.risk_event WHERE derived_by LIKE %s", (f"%{MARK}%",))
        c.execute("DELETE FROM gov.access_request WHERE purpose LIKE %s", ("%(시연)%",))
        print(f"-- 지난 시드 정리: ksx {n}행, 배치 {len(seeded_batches)}개, 실행 기록 {len(runs)}건")

    # ── 기준 정보 ────────────────────────────────────────────────────────────
    def masters(self):
        T0 = self.at(self.day(self.days + self.lead + 30), 9)
        k = lambda table, plant, row, src="ERP-S": self.ksx(table, plant, row, src, T0)
        self.insert("ksx.plant", [k("ksx.plant", "P2", {"plant_name": "후공정 2공장"})], "(enterprise_id, plant_id) DO NOTHING")
        self.insert("ksx.department", [k("ksx.department", "P2" if d == "D-PRD2" else "P1",
                                         {"department_id": d, "department_name": nm}) for d, nm in DEPTS])
        self.insert("ksx.personnel", [k("ksx.personnel", p, {"personnel_id": e, "personnel_name": nm, "department_id": d,
                                                             "employment_status_type": "ACTIVE"}) for e, nm, d, p in PEOPLE])
        self.insert("ksx.operation", [k("ksx.operation", p, {"operation_id": o, "operation_name": nm}, "MES-A" if p == "P1" else "MES-B")
                                      for o, nm, p in OPS])
        self.insert("ksx.equipment", [k("ksx.equipment", p, {
            "equipment_id": e, "equipment_name": nm, "operation_id": o, "equipment_type": ty, "manufacturer": mk,
            "person_in_charge_id": who, "department_in_charge_id": "D-EQ", "use_indicator": True, "country_of_origin": "KR",
            "acquisition_date": dt.date(2019 + i % 5, 1 + i % 12, 10), "model_number": f"{e.replace('EQ-', 'M')}-{2019 + i % 5}",
            "serial_number": f"SN{hashlib.md5(e.encode()).hexdigest()[:8].upper()}", "location": f"{p} {o} 구역"},
            "MES-A" if p == "P1" else "MES-B") for i, (e, nm, o, p, ty, mk, who) in enumerate(EQUIP)])
        self.insert("ksx.equipment_parameter", [k("ksx.equipment_parameter", p, {
            "parameter_id": pid, "parameter_name": nm, "parameter_uom_code": u, "equipment_id": e, "lsl": lsl, "usl": usl})
            for pid, nm, u, e, p, *_rest, lsl, usl in PARAMS if pid != "TEMP01"])
        self.insert("ksx.warehouse_location", [k("ksx.warehouse_location", p, {
            "warehouse_id": w, "warehouse_name": nm, "warehouse_type": ty, "use_indicator": True}) for w, nm, ty, p in WAREHOUSES])
        self.insert("ksx.vendor_party_master", [k("ksx.vendor_party_master", "P1", {
            "vendor_id": v, "vendor_name": nm, "country_id": "KR", "use_indicator": True,
            "business_registration_number": f"{100 + i * 7:03d}-8{i}-{40000 + i * 1311:05d}",
            "person_in_charge_name": f"{nm} 영업담당", "person_in_charge_email": f"sales@{v.lower()}.example"})
            for i, (v, nm) in enumerate(VENDORS)])
        self.insert("ksx.customer_party_master", [k("ksx.customer_party_master", "P1", {
            "customer_id": cid, "customer_name": nm, "country_id": "KR", "use_indicator": True,
            "person_in_charge_email": f"buyer@{cid.lower()}.example"}) for cid, nm in CUSTOMERS])
        items = []
        for iid, (nm, p, custs, _q, _price) in FG.items():
            items.append(k("ksx.item_master", p, {
                "item_id": iid, "item_name": nm, "item_type": "FG", "item_uom_code": "EA", "use_indicator": True,
                "item_large_class": "패키지", "item_medium_class": nm.split()[0], "lot_control_indicator": True,
                "main_customer_id": custs[0], "safety_stock": 3000 if p == "P1" else 1500, "lot_size": 1500,
                "receipt_warehouse_id": PLANT_WH[p][1], "issue_warehouse_id": PLANT_WH[p][1],
                "final_inspection_indicator": True, "outgoing_inspection_indicator": True,
                "production_lead_time": dt.timedelta(days=3)}))
        for iid, (nm, p, uom, ven, _price, safety, _use) in RM.items():
            items.append(k("ksx.item_master", p, {
                "item_id": iid, "item_name": nm, "item_type": "RM", "item_uom_code": uom, "use_indicator": True,
                "item_large_class": "원자재", "main_vendor_id": ven, "safety_stock": safety,
                "receipt_warehouse_id": PLANT_WH[p][0], "issue_warehouse_id": PLANT_WH[p][0],
                "incoming_inspection_indicator": True, "purchase_lead_time": dt.timedelta(days=5)}))
        self.insert("ksx.item_master", items)
        heads, lines = [], []
        for fg, (nm, p, *_r) in FG.items():
            bom_id = f"BOM-{fg}"
            heads.append(k("ksx.bom_header", p, {"bom_id": bom_id, "bom_revision_number": 1}))
            for rm, (rnm, rp, uom, *_x, use) in RM.items():
                if fg in use:
                    lines.append(k("ksx.bom", p, {
                        "bom_id": bom_id, "bom_revision_number": 1, "bom_type": "PRODUCTION", "item_id": fg, "bom_quantity": 1,
                        "item_uom_code": "EA", "child_item_id": rm, "child_item_uom_code": uom,
                        "actual_requirement_quantity": use[fg], "valid_start_date_time": T0, "back_flushed_indicator": True}))
        self.insert("ksx.bom_header", heads)
        self.insert("ksx.bom", lines)

    # ── 수주·생산 ────────────────────────────────────────────────────────────
    def production(self):
        rnd = self.rnd
        first = self.days + self.lead
        orders, wos, lots, starts, ends, perf, perf_q, perf_eq, releases = [], [], [], [], [], [], [], [], []
        # 이탈 구간은 그날 그 시각 뒤 그 설비에 처음 들어온 로트에 맞춘다 (사건마다 영향 로트가 생기도록)
        ep_windows = []
        for eq, pid, ago, h, dur, _shift, rate in EPISODES:
            s = self.at(self.day(ago), h)
            ep_windows.append([eq, s, s + dt.timedelta(hours=dur), rate, False, pid])
        self.consumed = defaultdict(float)            # (원자재, 날짜) → 소요량
        self.produced_fg = defaultdict(float)
        self.released_fg = defaultdict(float)
        self.lot_info = {}
        n_order = defaultdict(int)
        busy = defaultdict(lambda: dt.datetime.min)   # 설비가 다음 로트를 받을 수 있는 시각
        for ago in range(first, -1, -1):
            sd = self.day(ago)
            for plant, per_day in (("P1", 2), ("P2", 1)):
                k = per_day + (1 if rnd.random() < 0.35 else 0) - (1 if rnd.random() < 0.15 else 0)
                for _ in range(max(k, 0)):
                    fg = rnd.choice([i for i, v in FG.items() if v[1] == plant])
                    nm, _p, custs, (qlo, qhi), price = FG[fg]
                    n_order[sd] += 1
                    seq = n_order[sd]
                    tag = sd.strftime("%y%m%d")
                    so_id, sd_no = f"SO-{tag}-{seq:02d}", f"SD-{tag}-{seq:02d}"
                    qty = int(round(rnd.randint(qlo, qhi), -2))
                    tight = rnd.random() < 0.25
                    due = sd + dt.timedelta(days=rnd.randint(3, 5) if tight else rnd.randint(8, 16))
                    cust = rnd.choice(custs)
                    so = {"sales_order_id": so_id, "sales_document_number": sd_no, "sales_document_sequence": 1,
                          "sales_order_type": "NORMAL", "customer_id": cust, "sales_date": sd, "requested_delivery_date": due,
                          "sales_status": "CONFIRMED", "item_id": fg, "item_name": nm, "item_quantity": qty, "item_uom_code": "EA",
                          "export_indicator": False}
                    orders.append([plant, so, self.at(sd, 10 + rnd.random() * 6)])
                    wo = f"WO-{tag}-{seq:02d}"
                    wo_start = self.at(sd + dt.timedelta(days=1), 7 + rnd.random() * 3)
                    wos.append(self.ksx("ksx.production_order", plant, {
                        "production_order_id": wo, "production_order_sequence": 1, "item_id": fg, "item_uom_code": "EA",
                        "production_order_quantity": qty, "bom_id": f"BOM-{fg}", "bom_revision_number": 1,
                        "schedule_start_date_time": wo_start, "schedule_end_date_time": self.at(due, 12) - dt.timedelta(days=1),
                        "production_due_date_time": self.at(due, 9), "sales_document_number": sd_no, "sales_document_sequence": 1},
                        "ERP-S", wo_start - dt.timedelta(hours=14)))
                    n_lots = max(1, math.ceil(qty / 1500))
                    left = qty
                    done_times = []
                    for li in range(n_lots):
                        lq = min(left, int(round(qty / n_lots, -1)) if li < n_lots - 1 else left)
                        left -= lq
                        lq_in = math.ceil(lq * 1.04)             # 공정 불량을 감안해 조금 더 투입
                        lot_id = f"LT{tag}{plant[1]}{seq:02d}{li + 1}"
                        t = wo_start + dt.timedelta(hours=li * rnd.uniform(2, 5))
                        qty_now, lot_def, cur_op, state, started = lq_in, 0, None, "RELEASE", None
                        held = False
                        route = ROUTES[plant]
                        for oi, (op, eqs) in enumerate(route):
                            eq = min(eqs, key=lambda e: busy[e]) if len(eqs) > 1 else eqs[0]
                            st = max(t + dt.timedelta(hours=0 if oi == 0 else rnd.uniform(0.4, 5)), busy[eq])
                            if st >= self.now:
                                cur_op = op
                                break
                            if started is None:
                                started = st
                            dur = dt.timedelta(hours=rnd.uniform(1.6, 4.2) * (lq_in / 1500))
                            en = st + dur
                            busy[eq] = en + dt.timedelta(minutes=rnd.randint(10, 40))
                            setup = dt.timedelta(minutes=rnd.randint(10, 45))
                            who = rnd.choice([p for p in PEOPLE if p[3] == plant and p[2].startswith("D-PRD")])[0]
                            starts.append(self.ksx("ksx.operation_start", plant, {
                                "lot_id": lot_id, "operation_id": op, "equipment_id": eq, "operation_start_time": st,
                                "personnel_id": who}, "MES-A" if plant == "P1" else "MES-B", st))
                            if en > self.now:          # 지금 진행 중
                                cur_op, state = op, "START"
                                break
                            rate = rnd.uniform(0.001, 0.006)
                            for w in ep_windows:
                                if w[0] == eq and not w[4] and w[1] <= st < w[1] + dt.timedelta(hours=10):
                                    w[1], w[2], w[4] = st - dt.timedelta(minutes=20), st - dt.timedelta(minutes=20) + (w[2] - w[1]), True
                            for weq, ws, we, wrate, _fixed, _pid in ep_windows:
                                if weq == eq and st < we and en > ws:
                                    rate = wrate * rnd.uniform(0.9, 1.15)
                            dq = int(round(qty_now * rate))
                            ends.append(self.ksx("ksx.operation_end", plant, {
                                "lot_id": lot_id, "operation_id": op, "equipment_id": eq, "operation_end_time": en,
                                "produced_quantity": qty_now, "defect_quantity": dq, "personnel_id": who},
                                "MES-A" if plant == "P1" else "MES-B", en))
                            pp_id = f"PP-{lot_id}-{op.replace('OP-', '')}"
                            pday = en.date()
                            perf.append(self.ksx("ksx.production_performance", plant, {
                                "production_performance_id": pp_id, "production_performance_sequence": 1,
                                "production_order_id": wo, "production_order_sequence": 1, "item_id": fg, "item_uom_code": "EA",
                                "produced_quantity": qty_now, "defect_quantity": dq, "operation_id": op, "personnel_id": who,
                                "production_performance_date": pday, "execution_start_date_time": st, "execution_end_date_time": en,
                                "cancel_indicator": False, "lot_id": lot_id}, "MES-A" if plant == "P1" else "MES-B", en))
                            perf_eq.append(self.ksx("ksx.production_performance_equipment", plant, {
                                "production_performance_id": pp_id, "production_performance_sequence": 1,
                                "production_order_id": wo, "production_order_sequence": 1, "item_uom_code": "EA",
                                "produced_quantity": qty_now, "defect_quantity": dq, "operation_id": op, "personnel_id": who,
                                "execution_start_date_time": st - setup, "execution_end_date_time": en, "cancel_indicator": False,
                                "equipment_id": eq, "setup_time": setup, "run_time": dur, "inspection_finished_indicator": True},
                                "MES-A" if plant == "P1" else "MES-B", en))
                            if dq:
                                kinds = OP_DEFECTS[op]
                                split = [dq] if len(kinds) == 1 or dq < 4 else [dq - dq // 3, dq // 3]
                                for (code, detail), q in zip(kinds, split):
                                    if q:
                                        perf_q.append(self.ksx("ksx.production_performance_quality", plant, {
                                            "production_performance_id": pp_id, "production_performance_sequence": 1,
                                            "production_order_id": wo, "production_order_sequence": 1, "item_id": fg,
                                            "operation_id": op, "lot_id": lot_id, "defect_type_quantity": q,
                                            "defect_type_code": code, "defect_type_detail_code": detail},
                                            "MES-A" if plant == "P1" else "MES-B", en))
                            if oi == 0:
                                for rm, (_n, rp, *_x, use) in RM.items():
                                    if fg in use:
                                        self.consumed[(rm, en.date())] += use[fg] * qty_now
                            qty_now -= dq
                            lot_def += dq
                            t = en
                            # 최근 사흘 안에 불량 3% 를 넘긴 로트는 다음 공정 앞에서 보류 (품질 판정 대기)
                            if lot_def / lq_in > 0.03 and self.now - en < dt.timedelta(days=3) and oi < len(route) - 1:
                                cur_op, state, held = route[oi + 1][0], "HOLD", True
                                break
                        else:
                            state = "CLOSING"
                            done_times.append((t, lot_id, qty_now))
                            self.produced_fg[(fg, t.date())] += qty_now
                        if state == "RELEASE" and started is not None:
                            state = "START"
                        hold = held
                        if held and due > self.T + dt.timedelta(days=5) or held and due <= self.T:
                            due = self.T + dt.timedelta(days=self.rnd.randint(3, 5))   # 보류 로트의 수주는 곧 납기 (리스크 후보)
                            so["requested_delivery_date"] = due
                            wos[-1]["production_due_date_time"] = self.at(due, 9)
                        lots.append(self.ksx("ksx.lot", plant, {
                            "lot_id": lot_id, "lot_name": f"{nm.split()[-1]} 로트", "lot_type": "PROD", "item_id": fg,
                            "production_order_id": wo, "production_order_sequence": 1, "scheduled_due_date": due,
                            "lot_priority": 1 if tight else 3, "current_operation_id": cur_op or route[-1][0],
                            "lot_state": "HOLD" if hold else state, "hold_indicator": hold, "hot_indicator": tight,
                            "rework_indicator": False, "lot_created_quantity": lq_in,
                            "produced_quantity": qty_now if state == "CLOSING" else None,
                            "defect_quantity": lot_def or (0 if state == "CLOSING" else None),
                            "lot_started_date_time": started, "personnel_id": rnd.choice([p[0] for p in PEOPLE if p[3] == plant])},
                            "MES-A" if plant == "P1" else "MES-B", wo_start))
                        self.lot_info[lot_id] = (plant, fg, wo, due, lq_in, lot_def, so_id, cust)
                    # 출하: 로트가 끝난 다음 날(가끔 이틀 뒤) 출하. 수주 수량만큼만.
                    remain = qty
                    for i, (tdone, lot_id, good) in enumerate(sorted(done_times)):
                        ship_day = (tdone + dt.timedelta(hours=rnd.uniform(8, 40) + (48 if rnd.random() < 0.06 else 0))).date()
                        if ship_day > self.T or remain <= 0:
                            continue
                        q = min(good, remain)
                        remain -= q
                        releases.append(self.ksx("ksx.product_release", plant, {
                            "product_release_id": f"PR-{lot_id}", "product_release_sequence": 1,
                            "sales_document_number": sd_no, "sales_document_sequence": 1, "inventory_transaction_date": ship_day,
                            "item_id": fg, "item_name": nm, "order_quantity": qty, "sales_quantity": q, "item_uom_code": "EA",
                            "return_indicator": False, "customer_id": cust, "lot_id": lot_id, "warehouse_id": PLANT_WH[plant][1]},
                            "ERP-S", self.at(ship_day, 15)))
                        self.released_fg[(fg, ship_day)] += q
                    status = "SHIPPED" if remain <= 0 else ("PART_SHIPPED" if remain < qty else "CONFIRMED")
                    so["sales_status"] = status
        self.copy("ksx.sales_order", [self.ksx("ksx.sales_order", p, so, "ERP-S", t) for p, so, t in orders])
        self.copy("ksx.production_order", wos)
        self.copy("ksx.lot", lots)
        self.copy("ksx.operation_start", starts)
        self.copy("ksx.operation_end", ends)
        self.copy("ksx.production_performance", perf)
        self.copy("ksx.production_performance_equipment", perf_eq)
        self.copy("ksx.production_performance_quality", perf_q)
        self.copy("ksx.product_release", releases)
        self.perf_rows = perf
        self.ep_win = {w[5]: (w[1], w[2]) for w in ep_windows}
        self.perf_q_rows = perf_q
        self.orders = orders

    # ── 설비 측정값·상태·알람 ────────────────────────────────────────────────
    def equipment_signals(self):
        rnd = self.rnd
        rows, alarms = [], []
        t0 = self.at(self.day(self.days + 4), 0)
        steps = int((self.now - t0).total_seconds() // 900)
        for pid, nm, uom, eq, plant, base, sd, lsl, usl in PARAMS:
            drift = 0.0
            eps = [(*self.ep_win[p2], shift) for e2, p2, ago, h, dur, shift, _r in EPISODES if p2 == pid]
            for i in range(steps):
                t = t0 + dt.timedelta(minutes=15 * i + 2 + zlib.crc32(pid.encode()) % 9, seconds=17)  # 예시 데이터의 정각 측정값과 겹치지 않게
                drift = drift * 0.9 + rnd.gauss(0, sd * 0.25)
                v = base + drift + rnd.gauss(0, sd * 0.6)
                for s, e, shift in eps:
                    if s <= t <= e:
                        mid = (t - s) / (e - s)
                        v = base + shift * (0.75 + 0.25 * math.sin(math.pi * mid)) + rnd.gauss(0, sd * 0.4)
                v = round(v, 2 if abs(base) < 100 else 1)
                code = "OVER_USL" if v > usl else ("UNDER_LSL" if v < lsl else "NORMAL")
                rows.append({"enterprise_id": ENT, "site_id": SITE, "plant_id": plant, "creator_id": MARK,
                             "equipment_id": eq, "parameter_id": pid, "event_date_time": t, "parameter_uom_code": uom,
                             "parameter_value": v, "validation_result_code": code, "lake_source_system": f"EAP-{eq[-2:]}",
                             "lake_loaded_at": (t + dt.timedelta(seconds=40)).replace(tzinfo=KST)})
                if code != "NORMAL" and (not alarms or alarms[-1]["equipment_id"] != eq
                                         or t - alarms[-1]["event_date_time"] > dt.timedelta(hours=1)):
                    alarms.append(self.ksx("ksx.alarm", plant, {
                        "equipment_id": eq, "alarm_state": "ALARM", "error_code": f"{pid}-{code}",
                        "error_message": f"{nm} {v}{uom} — 규격({lsl}~{usl}) 이탈", "event_date_time": t,
                        "current_location": eq}, f"EAP-{eq[-2:]}", t))
        # 일상 알람(가벼운 경고·점검)
        for ago in range(self.days, -1, -1):
            for _ in range(rnd.randint(0, 2)):
                e = rnd.choice(EQUIP)
                t = self.at(self.day(ago), rnd.uniform(6, 22))
                if t >= self.now:
                    continue
                kind = rnd.choice([("WARNING", "DOOR-OPEN", "도어 열림 감지"), ("WARNING", "VAC-LOW", "진공 압력 낮음"),
                                   ("MAINTENANCE", "PM-DUE", "예방보전 주기 도래"), ("WARNING", "TOOL-LIFE", "공구 수명 90% 도달")])
                alarms.append(self.ksx("ksx.alarm", e[3], {
                    "equipment_id": e[0], "alarm_state": kind[0], "error_code": kind[1], "error_message": kind[2],
                    "event_date_time": t, "current_location": e[0]}, "MES-A" if e[3] == "P1" else "MES-B", t))
        self.copy("ksx.trace_parameter", rows)
        seen = set()
        self.copy("ksx.alarm", [a for a in alarms if not ((a["equipment_id"], a["event_date_time"], a["error_code"]) in seen
                                                          or seen.add((a["equipment_id"], a["event_date_time"], a["error_code"])))])
        states = []
        last = {}
        for s in self.c.execute("SELECT equipment_id, lot_id, operation_id FROM ksx.operation_start WHERE creator_id = %s"
                                " ORDER BY operation_start_time", (MARK,)).fetchall():
            last[s[0]] = s
        for e, nm, op, plant, ty, *_ in EQUIP + [("EQ-03", "", "OP-30", "P1", "PROD"), ("EQ-07", "", "OP-40", "P1", "PROD")]:
            st = "RUN" if rnd.random() < 0.7 else rnd.choice(["IDLE", "SETUP", "PM"])
            if e == "EQ-24":
                st = "ENG"
            ls = last.get(e)
            states.append(self.ksx("ksx.equipment_state", plant, {
                "equipment_id": e, "equipment_state": st, "equipment_control_mode": "REMOTE", "equipment_operation_mode": "AUTO",
                "processed_lot_quantity": rnd.randint(40, 200), "last_processed_lot_id": ls[1] if ls else None,
                "last_processed_operation_id": ls[2] if ls else None,
                "error_code": "EQ24-T3-OVER_USL" if e == "EQ-24" else None,
                "error_message": "존3 온도 이탈 후 엔지니어 점검 중" if e == "EQ-24" else None}, "MES-A" if plant == "P1" else "MES-B"))
        self.insert("ksx.equipment_state", states, "(enterprise_id, equipment_id) DO NOTHING")

    # ── 구매·입고·재고 ──────────────────────────────────────────────────────
    def purchasing(self):
        rnd = self.rnd
        po_lines, receipts = [], []
        per_day = defaultdict(list)          # 발주일 → 발주 라인 (SCM 파일 단위)
        n_doc = defaultdict(int)
        first = self.days + self.lead
        stock = {rm: v[5] * rnd.uniform(1.4, 2.2) for rm, v in RM.items()}
        for ago in range(first, -1, -1):
            d = self.day(ago)
            if d.weekday() == 6:
                continue
            for plant in ("P1", "P2"):
                rms = [rm for rm, v in RM.items() if v[1] == plant]
                picks = [rm for rm in rms if rnd.random() < 0.35]
                if not picks:
                    continue
                n_doc[d] += 1
                doc = f"PO{d.strftime('%y%m%d')}{plant[1]}{n_doc[d]:02d}"
                for seq, rm in enumerate(picks, 1):
                    nm, _p, uom, ven, price, safety, _use = RM[rm]
                    if rnd.random() < 0.2:
                        ven = rnd.choice([v for v, _ in VENDORS])
                    qty = round(safety * rnd.uniform(0.5, 1.1), -1 if safety < 1000 else -2) or 10
                    exp = d + dt.timedelta(days=rnd.randint(3, 7))
                    who = "E3001" if plant == "P1" else "E3002"
                    line = {"purchase_order_id": f"{doc}-{seq}", "purchase_document_number": doc, "purchase_document_sequence": seq,
                            "vendor_id": ven, "currency_code": "KRW", "purchase_order_date": d, "purchase_approval_date": d,
                            "purchase_order_type_code": "NB", "personnel_id": who, "item_purchase_type": "RM", "item_id": rm,
                            "item_name": nm, "item_uom_code": uom, "purchase_order_uom_code": uom, "purchase_order_quantity": qty,
                            "purchase_order_unit_price": price, "purchase_order_price": round(qty * price),
                            "vat_price": round(qty * price * 0.1), "expected_delivery_date": exp,
                            "incoming_inspection_indicator": True, "purchase_order_closing_indicator": False}
                    # 입고: 납기 전후 0~2일, 가끔 분할·검사 불합격
                    rec_day = exp + dt.timedelta(days=rnd.choice([-1, 0, 0, 0, 1, 2]))
                    got = 0
                    if rec_day <= self.T:
                        got = qty if rnd.random() > 0.12 else round(qty * 0.6, -1)
                        rej = round(got * rnd.uniform(0.01, 0.04)) if rnd.random() < 0.15 else 0
                        receipts.append(self.ksx("ksx.goods_receipt", plant, {
                            "goods_receipt_id": f"GR-{doc}", "goods_receipt_sequence": seq, "warehouse_id": PLANT_WH[plant][0],
                            "personnel_id": who, "goods_receipt_type": "PO", "goods_receipt_date": rec_day, "item_id": rm,
                            "item_name": nm, "inventory_transaction_document_number": doc, "inventory_transaction_document_sequence": seq,
                            "incoming_inspection_indicator": True, "vendor_id": ven, "purchase_order_uom_code": uom,
                            "goods_receipt_quantity": got, "incoming_inspection_accepted_quantity": got - rej,
                            "incoming_inspection_rejected_quantity": rej, "item_uom_code": uom}, "SCM-P", self.at(rec_day, 11)))
                        stock[rm] += got - rej
                    line["purchase_goods_receipt_quantity"] = got
                    line["purchase_order_line_status_code"] = "RECEIVED" if got >= qty else ("PART_RECEIVED" if got else "OPEN")
                    po_lines.append((plant, d, line))
                    per_day[(d, plant)].append(line)
            for rm in RM:
                stock[rm] -= self.consumed.get((rm, d), 0)
        # 재고 스냅숏: 대부분 안전재고의 1.2~2.4배, 두 품목만 일부러 안전재고 밑 (재고 부족 화면·품질 규칙·공급 리스크용)
        for rm in RM:
            stock[rm] = RM[rm][5] * (rnd.uniform(0.35, 0.6) if rm in ("RM-SB", "RM-TRAY") else rnd.uniform(1.2, 2.4))
        inv = []
        for rm, (nm, plant, uom, *_r) in RM.items():
            inv.append(self.ksx("ksx.inventory", plant, {"warehouse_id": PLANT_WH[plant][0], "item_id": rm,
                                                         "inventory_quantity": round(stock[rm], -1 if stock[rm] > 1000 else 0), "item_uom_code": uom}, "ERP-S"))
        for fg, (nm, plant, *_r) in FG.items():
            q = sum(v for (f, _d), v in self.produced_fg.items() if f == fg) - sum(v for (f, _d), v in self.released_fg.items() if f == fg)
            inv.append(self.ksx("ksx.inventory", plant, {"warehouse_id": PLANT_WH[plant][1], "item_id": fg,
                                                         "inventory_quantity": max(round(q + 2500), 0), "item_uom_code": "EA"}, "ERP-S"))
        self.insert("ksx.inventory", inv, "(enterprise_id, warehouse_id, item_id) DO UPDATE SET inventory_quantity = EXCLUDED.inventory_quantity")
        self.po_by_day = per_day
        self.po_lines = po_lines
        self.copy("ksx.goods_receipt", receipts)

    # ── 적재 배치: 원천 파일 → 원천 존 → 표준 존 ─────────────────────────────
    def ingest_batches(self):
        """SCM 발주 파일(일 단위), 1·2공장 MES 생산실적 일보를 원천 존에 그대로 남기고 표준 존 행과 잇는다."""
        rnd = self.rnd
        c = self.c
        sources = [
            ("SCM-P", "구매 포털(SCM) 발주", "SCM", "FILE", False, "구매팀"),
            ("MES-B", "2공장 MES", "MES", "JDBC", True, "생산기술팀"),
            ("QMS-Q", "품질관리 시스템", "QMS", "REST", False, "품질보증팀"),
        ]
        self.insert("catalog.source_system", [dict(zip(["source_system_id", "label_ko", "system_type", "connection_kind",
                                                        "ksx_compliant", "owner_dept"], s)) | {"enterprise_id": ENT} for s in sources],
                    "(source_system_id) DO NOTHING")
        self.insert("catalog.source_connection", [
            {"source_system_id": "MES-B", "db_kind": "POSTGRESQL", "host": "mes-b.acme.example", "port": 5432,
             "database_name": "mesb", "username": "lake_reader", "secret_ref": "vault:lake/mes-b", "status": "OK",
             "last_tested_at": self.at(self.day(1), 9).replace(tzinfo=KST), "created_by": "u-han", "enterprise_id": ENT},
            {"source_system_id": "QMS-Q", "db_kind": "REST", "host": "qms.acme.example", "port": 443,
             "secret_ref": "vault:lake/qms", "status": "FAILED", "last_tested_at": self.at(self.day(3), 14).replace(tzinfo=KST),
             "last_error": "인증서 만료 (qms.acme.example)", "created_by": "u-han", "enterprise_id": ENT}],
            "(source_system_id) DO NOTHING")
        defs = [  # 데이터셋, 원천, 제목, 표준 표, 파일 이름 틀
            ("raw.scm-p.purchase_order_export", "SCM-P", "SCM 발주 내보내기", "purchase_order", "SCM_발주_{d}.xlsx"),
            ("raw.mes-a.production_result", "MES-A", "1공장 MES 생산실적 일보", "production_performance", "MES1_생산실적_{d}.xlsx"),
            ("raw.mes-b.production_result", "MES-B", "2공장 MES 생산실적 일보", "production_performance", "MES2_생산실적_{d}.csv"),
        ]
        scm_cols = {"발주번호": "purchase_document_number", "순번": "purchase_document_sequence", "발주일자": "purchase_order_date",
                    "공급사코드": "vendor_id", "품목코드": "item_id", "품목명": "item_name", "단위": "purchase_order_uom_code",
                    "발주수량": "purchase_order_quantity", "단가": "purchase_order_unit_price", "금액": "purchase_order_price",
                    "납기요청일": "expected_delivery_date", "통화": "currency_code", "담당자": "personnel_id"}
        mes_cols = {"실적번호": "production_performance_id", "작업지시": "production_order_id", "로트번호": "lot_id",
                    "품목코드": "item_id", "공정": "operation_id", "생산수량": "produced_quantity", "불량수량": "defect_quantity",
                    "작업일자": "production_performance_date", "시작시각": "execution_start_date_time",
                    "종료시각": "execution_end_date_time", "작업자": "personnel_id"}
        extras = {"SCM-P": ["납품장소", "검수담당"], "MES-A": ["작업조", "라인속도"], "MES-B": ["작업조", "외관검사자"]}
        for ds, src, title, std, _f in defs:
            cmap = scm_cols if src == "SCM-P" else mes_cols
            self.insert("catalog.dataset", [{
                "dataset_id": ds, "title_ko": title, "zone_id": "RAW", "represents_class_iri": KSX + ("PurchaseOrder" if std == "purchase_order" else "ProductionPerformance"),
                "source_system_id": src, "location_uri": f"upload://{src}/{ds.split('.')[-1]}/", "format": "xlsx" if "xlsx" in _f else "csv",
                "ingest_mode": "file", "schedule_cron": "0 7 * * *", "owner_user_id": "u-han", "steward_user_id": "u-choi",
                "tags": ["console", "daily"], "sensitivity": "INTERNAL", "enterprise_id": ENT,
                "description": f"{title}. 매일 아침 7시 전후로 전날 분이 올라온다 (시연 데이터)."}], "(dataset_id) DO NOTHING")
            self.insert("catalog.dataset_field", [{
                "dataset_id": ds, "field_name": f, "label_ko": f, "data_type": "text", "is_pk": f in ("발주번호", "순번", "실적번호"),
                "mapping_method": "human" if i % 3 else "rule", "mapping_confidence": 1 if i % 3 else 0.93,
                "mapping_status": "APPROVED", "maps_to_property_iri": None,
                "description": f"→ ksx.{std}.{col}"} for i, (f, col) in enumerate(cmap.items())]
                + [{"dataset_id": ds, "field_name": f, "label_ko": f, "data_type": "text", "mapping_status": "PROPOSED",
                    "description": "표준 열 없음 → 확장 속성으로 보관"} for f in extras[src]],
                "(dataset_id, field_name) DO NOTHING")
            self.insert("catalog.lineage_edge", [{
                "from_dataset_id": ds, "to_dataset_id": f"std.{std}", "pipeline_id": "p-console-std",
                "field_map": Jsonb({v: [k] for k, v in cmap.items()}), "enterprise_id": ENT}]
                + ([{"from_dataset_id": ds, "to_dataset_id": "std.production_performance_quality", "pipeline_id": "p-console-std",
                     "field_map": Jsonb({"defect_type_quantity": ["불량수량"]}), "enterprise_id": ENT}] if std != "purchase_order" else []),
                "(from_dataset_id, to_dataset_id, pipeline_id) DO NOTHING")
            self.insert("catalog.mapping", [{
                "mapping_id": f"console/{ds}@v1", "source_dataset_id": ds, "target_class_iri": KSX + (
                    "PurchaseOrder" if std == "purchase_order" else "ProductionPerformance"), "kind": "SQL", "version_no": 1,
                "artifact_uri": f"db://catalog.mapping/{ds}", "status": "APPROVED", "approved_by": "u-choi",
                "approved_at": self.at(self.day(self.days + 2), 10).replace(tzinfo=KST), "f1_score": 0.97}], "(mapping_id) DO NOTHING")

        # 일 단위 파일
        perf_by = defaultdict(list)
        for r in self.perf_rows:
            perf_by[(r["production_performance_date"], r["plant_id"])].append(r)
        batch_rows = []          # raw.ingest_batch
        files, records, runs = [], [], []
        link = {}                # (표, 키) → batch_id  (표준 행의 lake_batch_id)
        for ago in range(self.days - 1, -1, -1):
            d = self.day(ago)
            recv = self.at(d + dt.timedelta(days=1), 7 + rnd.uniform(0, 0.8))
            if recv >= self.now:     # 오늘 분은 아직 안 올라왔다
                continue
            jobs = []
            po = self.po_by_day.get((d, "P1"), []) + self.po_by_day.get((d, "P2"), [])
            if po:
                jobs.append(("raw.scm-p.purchase_order_export", "SCM-P", "purchase_order", "SCM_발주_{d}.xlsx", [
                    {"발주번호": l["purchase_document_number"], "순번": l["purchase_document_sequence"],
                     "발주일자": l["purchase_order_date"].isoformat(), "공급사코드": l["vendor_id"], "품목코드": l["item_id"],
                     "품목명": l["item_name"], "단위": l["item_uom_code"], "발주수량": l["purchase_order_quantity"],
                     "단가": l["purchase_order_unit_price"], "금액": l["purchase_order_price"],
                     "납기요청일": l["expected_delivery_date"].isoformat() if l["expected_delivery_date"] else "",
                     "통화": "KRW", "담당자": l["personnel_id"], "납품장소": "1공장 자재창고" if l["purchase_document_number"][8] == "1" else "2공장 자재창고",
                     "검수담당": rnd.choice(["송지아", "배준호", "문채원"])} for l in po],
                    [("ksx.purchase_order", l["purchase_order_id"]) for l in po]))
            for plant, ds, src, fn in (("P1", "raw.mes-a.production_result", "MES-A", "MES1_생산실적_{d}.xlsx"),
                                       ("P2", "raw.mes-b.production_result", "MES-B", "MES2_생산실적_{d}.csv")):
                rows = perf_by.get((d, plant), [])
                if rows:
                    jobs.append((ds, src, "production_performance", fn, [
                        {"실적번호": r["production_performance_id"], "작업지시": r["production_order_id"], "로트번호": r["lot_id"],
                         "품목코드": r["item_id"], "공정": r["operation_id"], "생산수량": r["produced_quantity"],
                         "불량수량": r["defect_quantity"], "작업일자": d.isoformat(),
                         "시작시각": r["execution_start_date_time"].strftime("%Y-%m-%d %H:%M"),
                         "종료시각": r["execution_end_date_time"].strftime("%Y-%m-%d %H:%M"), "작업자": r["personnel_id"],
                         "작업조": "주간" if 6 <= r["execution_start_date_time"].hour < 18 else "야간",
                         ("라인속도" if plant == "P1" else "외관검사자"): (round(rnd.uniform(0.8, 1.1), 2) if plant == "P1" else rnd.choice(["배준호", "한도윤"]))}
                        for r in rows], [("ksx.production_performance", r["production_performance_id"]) for r in rows]))
            for j, (ds, src, std, fn, payload, keys) in enumerate(jobs):
                b = uid("batch", ds, d)
                t_in = recv + dt.timedelta(minutes=j * 4 + rnd.randint(0, 3))
                t_std = t_in + dt.timedelta(minutes=rnd.randint(2, 25))
                rej = 0
                err = None
                # 가끔 사람이 고친 파일: 빈 품목코드 행 → 거부
                if src == "SCM-P" and rnd.random() < 0.12 and len(payload) > 1:
                    payload.append(dict(payload[0], **{"순번": len(payload) + 1, "품목코드": "", "발주수량": 0, "금액": 0}))
                    rej = 1
                    err = f'{{"record_seq": {len(payload)}, "error": "품목코드가 비었습니다 (ksx.purchase_order.item_id 참조 무결성)"}}'
                run_up, run_std = uid("run-up", b), uid("run-std", b)
                data = json.dumps(payload, ensure_ascii=False).encode()
                runs += [{"run_id": run_up, "pipeline_id": "p-console-upload", "started_at": t_in.replace(tzinfo=KST),
                          "ended_at": (t_in + dt.timedelta(seconds=rnd.randint(2, 9))).replace(tzinfo=KST), "status": "SUCCESS",
                          "rows_in": len(payload), "rows_out": len(payload), "rows_rejected": 0, "code_version": MARK, "enterprise_id": ENT},
                         {"run_id": run_std, "pipeline_id": "p-console-std", "mapping_id": f"console/{ds}@v1",
                          "started_at": t_std.replace(tzinfo=KST), "ended_at": (t_std + dt.timedelta(seconds=rnd.randint(3, 20))).replace(tzinfo=KST),
                          "status": "PARTIAL" if rej else "SUCCESS", "rows_in": len(payload), "rows_out": len(payload) - rej,
                          "rows_rejected": rej, "code_version": MARK, "error_message": err, "enterprise_id": ENT}]
                batch_rows.append({"batch_id": b, "source_system_id": src, "dataset_id": ds, "job_run_id": run_up, "scenario_id": MARK,
                                   "received_at": t_in.replace(tzinfo=KST), "record_count": len(payload), "byte_size": len(data) * 3,
                                   "checksum": hashlib.sha256(data).hexdigest(), "status": "STANDARDIZED", "std_job_run_id": run_std,
                                   "std_table": f"ksx.{std}", "columns": list(payload[0].keys())})
                files.append({"batch_id": b, "object_uri": f"upload://{src}/{b}/{fn.format(d=d.strftime('%Y%m%d'))}",
                              "file_name": fn.format(d=d.strftime("%Y%m%d")), "byte_size": len(data) * 3,
                              "mime_type": "text/csv" if fn.endswith(".csv") else "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                              "sha256": hashlib.sha256(data).hexdigest(), "received_at": t_in.replace(tzinfo=KST)})
                for i, p in enumerate(payload, 1):
                    records.append({"batch_id": b, "record_seq": i, "received_at": t_in.replace(tzinfo=KST),
                                    "source_entity": ds.split(".")[-1], "source_key": str(p.get("발주번호", p.get("실적번호"))), "op": "I",
                                    "payload": p})
                for key in keys:
                    link[key] = (b, t_std)
                self.batches.append({"batch_id": b, "dataset_id": ds, "src": src, "day": d, "rows": len(payload), "rej": rej,
                                     "at": t_in, "std": std, "extras": [k for k in payload[0] if k in extras[src]],
                                     "samples": {k: [p.get(k) for p in payload[:5]] for k in extras[src]}})
        self.copy("catalog.job_run", runs)
        self.copy("raw.ingest_batch", batch_rows)
        self.copy("raw.landing_file", files)
        self.copy("raw.landing_record", records)
        # 표준 행: 생산실적은 이미 들어가 있으니 배치만 잇고, 발주는 여기서 넣는다
        for plant, d, line in self.po_lines:
            b = link.get(("ksx.purchase_order", line["purchase_order_id"]))
            line["_b"] = b
        self.copy("ksx.purchase_order", [self.ksx("ksx.purchase_order", plant, {k: v for k, v in line.items() if k != "_b"} | (
            {"lake_batch_id": line["_b"][0], "lake_loaded_at": line["_b"][1].replace(tzinfo=KST)} if line["_b"] else {}),
            "SCM-P", self.at(d, 16)) for plant, d, line in self.po_lines])
        pp = [(b, t.replace(tzinfo=KST), key[1]) for key, (b, t) in link.items() if key[0] == "ksx.production_performance"]
        if pp and "lake_batch_id" in self.cols("ksx.production_performance"):
            with c.cursor() as cur:
                cur.executemany("UPDATE ksx.production_performance SET lake_batch_id = %s, lake_loaded_at = %s"
                                " WHERE enterprise_id = 'ACME' AND production_performance_id = %s", pp)
        for ds, *_ in defs:
            c.execute("UPDATE catalog.dataset d SET record_count = (SELECT coalesce(sum(record_count), 0) FROM raw.ingest_batch b"
                      " WHERE b.dataset_id = d.dataset_id), last_ingested_at = (SELECT max(received_at) FROM raw.ingest_batch b"
                      " WHERE b.dataset_id = d.dataset_id), updated_at = now() WHERE dataset_id = %s", (ds,))

    # ── 온톨로지 확장 제안 ───────────────────────────────────────────────────
    def proposals(self):
        first = {}
        for b in self.batches:
            for col in b["extras"]:
                first.setdefault((b["dataset_id"], col), b)
        plan = {  # 열: (영문 이름, 설명, 범위, 신뢰도, 상태, 근거)
            "납품장소": ("deliveryLocation", "납품 장소", "xsd:string", 0.71, "PROPOSED", "값이 창고 이름 몇 가지로 반복 — 창고(WarehouseLocation) 참조로 바꿀 수도 있음"),
            "검수담당": ("inspectorName", "입고 검수 담당자", "xsd:string", 0.64, "PROPOSED", "사람 이름 — 개인정보 표시 필요"),
            "작업조": ("workShift", "작업조(주간·야간)", "xsd:string", 0.83, "PROPOSED", "값 2종(주간·야간), 1·2공장 공통 — 승격 후보"),
            "라인속도": ("lineSpeedRatio", "라인 속도 비율", "xsd:decimal", 0.58, "REJECTED", "설비 파라미터(trace_parameter)로 받는 게 맞음"),
            "외관검사자": ("visualInspectorName", "외관 검사자", "xsd:string", 0.61, "PROPOSED", "사람 이름 — 개인정보 표시 필요"),
        }
        target = {"SCM-P": KSX + "PurchaseOrder", "MES-A": KSX + "ProductionPerformance", "MES-B": KSX + "ProductionPerformance"}
        rows = []
        for (ds, col), b in first.items():
            name, label, rng, conf, status, why = plan[col]
            seen = sum(x["rows"] for x in self.batches if x["dataset_id"] == ds)
            decided = status != "PROPOSED"
            rows.append({"enterprise_id": ENT, "dataset_id": ds, "batch_id": b["batch_id"], "std_table": b["std"], "column_name": col,
                         "sample_values": [v for v in b["samples"][col] if v not in (None, "")][:5], "profile": "text" if rng == "xsd:string" else "number",
                         "kind": "PROPERTY", "target_class_iri": target[b["src"]], "suggested_local_name": name,
                         "suggested_label": label, "suggested_range_iri": rng.replace("xsd:", "http://www.w3.org/2001/XMLSchema#"),
                         "confidence": conf, "rationale": why + " (시연)", "status": status, "rows_seen": seen,
                         "created_at": b["at"].replace(tzinfo=KST),
                         "decided_by": "u-yoon" if decided else None,
                         "decided_at": (b["at"] + dt.timedelta(days=2)).replace(tzinfo=KST) if decided else None})
        self.insert("onto.extension_proposal", rows, "")

    # ── 파이프라인 실행 이력 ─────────────────────────────────────────────────
    def pipeline_runs(self):
        rnd = self.rnd
        runs = []
        lot_per_hour = max(1, len(self.lot_info) // (self.days * 24))
        for ago in range(self.days - 1, -1, -1):
            d = self.day(ago)
            for h in range(24):
                t = self.at(d, h + 0.08)
                if t >= self.now - dt.timedelta(minutes=20):
                    break
                fail = rnd.random() < 0.012
                n = rnd.randint(lot_per_hour * 40, lot_per_hour * 90)
                runs.append({"run_id": uid("p-std-lot", d, h), "pipeline_id": "p-std-lot", "mapping_id": "ksx9101/lot.rml.ttl@v3",
                             "started_at": t.replace(tzinfo=KST), "ended_at": (t + dt.timedelta(seconds=rnd.randint(30, 140))).replace(tzinfo=KST),
                             "status": "FAILED" if fail else "SUCCESS", "rows_in": n, "rows_out": 0 if fail else n, "rows_rejected": 0,
                             "code_version": MARK, "enterprise_id": ENT,
                             "error_message": "MES-A 연결 시간 초과 (30s) — 다음 주기에 재시도" if fail else None})
                if h % 2 == 0:
                    tk = t + dt.timedelta(minutes=12)
                    part = rnd.random() < 0.06
                    n2 = rnd.randint(30000, 52000)
                    runs.append({"run_id": uid("p-kg", d, h), "pipeline_id": "p-kg-materialize", "mapping_id": "ksx9101/lot.rml.ttl@v3",
                                 "started_at": tk.replace(tzinfo=KST), "ended_at": (tk + dt.timedelta(minutes=rnd.randint(4, 11))).replace(tzinfo=KST),
                                 "status": "PARTIAL" if part else "SUCCESS", "rows_in": n2, "rows_out": n2 - (rnd.randint(3, 40) if part else 0),
                                 "rows_rejected": rnd.randint(3, 40) if part else 0, "code_version": MARK, "enterprise_id": ENT,
                                 "error_message": "lot_state 코드 미등록 행 (예: HOLD 사유 없음)" if part else None})
            tk = self.at(d, 2)
            if tk < self.now:
                fail = ago in (11,)
                runs.append({"run_id": uid("p-kpi", d), "pipeline_id": "p-kpi", "started_at": tk.replace(tzinfo=KST),
                             "ended_at": (tk + dt.timedelta(minutes=rnd.randint(4, 9))).replace(tzinfo=KST),
                             "status": "FAILED" if fail else "SUCCESS", "rows_in": rnd.randint(800, 1400), "rows_out": 0 if fail else rnd.randint(40, 90),
                             "rows_rejected": 0, "code_version": MARK, "enterprise_id": ENT,
                             "error_message": "dbt test 실패: v_kpi_otd 납기일 NULL 2건" if fail else None})
                tt = self.at(d, 0.02)
                runs.append({"run_id": uid("p-trace", d), "pipeline_id": "p-trace-promote", "started_at": tt.replace(tzinfo=KST),
                             "ended_at": (tt + dt.timedelta(hours=23.9)).replace(tzinfo=KST) if ago > 0 else None,
                             "status": "SUCCESS" if ago > 0 else "RUNNING", "rows_in": 960 if ago > 0 else None,
                             "rows_out": 960 if ago > 0 else None, "rows_rejected": 0, "code_version": MARK, "enterprise_id": ENT})
        self.copy("catalog.job_run", runs)

    # ── 품질 규칙·검사 이력·위반 ─────────────────────────────────────────────
    def quality(self):
        rnd = self.rnd
        rules = [
            ("q-po-due-date", "발주 납기요청일 누락", "완전성", KSX + "PurchaseOrder", "std.purchase_order", "Warning", 99.0,
             "SELECT purchase_order_id AS focus_node, 'expected_delivery_date' AS result_path, '납기요청일이 비었습니다' AS message"
             " FROM ksx.purchase_order WHERE expected_delivery_date IS NULL"),
            ("q-perf-defect-le-produced", "생산실적 불량수량 ≤ 생산수량", "일관성", KSX + "ProductionPerformance", "std.production_performance",
             "Violation", 100.0,
             "SELECT production_performance_id AS focus_node, 'defect_quantity' AS result_path,"
             " '불량 ' || defect_quantity || ' > 생산 ' || produced_quantity AS message"
             " FROM ksx.production_performance WHERE defect_quantity > produced_quantity"),
            ("q-lot-hold-note", "보류 로트 사유 기록", "완전성", KSX + "Lot", "std.lot", "Warning", 95.0,
             "SELECT lot_id AS focus_node, 'note' AS result_path, '보류 중인데 사유(비고)가 없습니다' AS message"
             " FROM ksx.lot WHERE hold_indicator AND coalesce(note, '') = ''"),
            ("q-inv-safety", "자재 재고 안전재고 이상", "값", KSX + "Inventory", "std.inventory", "Warning", 90.0,
             "SELECT i.item_id AS focus_node, 'inventory_quantity' AS result_path,"
             " im.item_name || ' 재고 ' || i.inventory_quantity || ' < 안전재고 ' || im.safety_stock AS message"
             " FROM ksx.inventory i JOIN ksx.item_master im ON im.enterprise_id = i.enterprise_id AND im.item_id = i.item_id"
             " WHERE im.safety_stock IS NOT NULL AND i.inventory_quantity < im.safety_stock"),
            ("q-trace-in-spec", "설비 파라미터 규격 이내", "정확성", KSX + "TraceParameter", "std.trace_parameter", "Info", 99.5,
             "SELECT equipment_id || '/' || parameter_id || '@' || to_char(event_date_time, 'MM-DD HH24:MI') AS focus_node,"
             " 'parameter_value' AS result_path, '측정값 ' || parameter_value || ' 규격 이탈' AS message"
             " FROM ksx.trace_parameter WHERE validation_result_code <> 'NORMAL'"
             "   AND event_date_time >= (now() AT TIME ZONE 'Asia/Seoul') - interval '1 day'"),
        ]
        self.insert("catalog.quality_rule", [dict(zip(["rule_id", "label_ko", "dimension", "target_class_iri", "target_dataset_id",
                                                       "severity", "threshold", "sql_check"], r)) | {"enabled": True} for r in rules],
                    "(rule_id) DO NOTHING")
        # 몇 군데 일부러 흠: 납기 비운 발주 3건, 불량>생산 1건, 보류 로트 하나엔 사유
        c = self.c
        c.execute("UPDATE ksx.purchase_order SET expected_delivery_date = NULL WHERE purchase_order_id IN"
                  " (SELECT purchase_order_id FROM ksx.purchase_order WHERE creator_id = %s ORDER BY purchase_order_date DESC"
                  "  OFFSET 4 LIMIT 3)", (MARK,))
        c.execute("UPDATE ksx.production_performance SET defect_quantity = produced_quantity + 12 WHERE production_performance_id ="
                  " (SELECT production_performance_id FROM ksx.production_performance WHERE creator_id = %s AND plant_id = 'P2'"
                  "  ORDER BY production_performance_date DESC OFFSET 7 LIMIT 1)", (MARK,))
        c.execute("UPDATE ksx.lot SET note = 'EQ-24 존3 온도 이탈 — 품질 판정 대기' WHERE lot_id ="
                  " (SELECT lot_id FROM ksx.lot WHERE creator_id = %s AND hold_indicator ORDER BY lot_id LIMIT 1)", (MARK,))
        qruns, viols = [], []
        today = {}
        # 검사식이 있는 규칙은 모두 (이 시드 것 + 마이그레이션·사용자가 만든 것) 실제로 돌려 오늘 결과로 쓰고, 지난 30일은 그 언저리로 채운다
        rules = c.execute(
            "SELECT r.rule_id, r.label_ko, r.dimension, r.target_class_iri,"
            "       coalesce(r.target_dataset_id, (SELECT d.dataset_id FROM catalog.dataset d WHERE d.zone_id = 'STANDARD'"
            "                 AND d.represents_class_iri = r.target_class_iri ORDER BY d.dataset_id LIMIT 1)),"
            "       r.severity, r.threshold, r.sql_check FROM catalog.quality_rule r"
            " WHERE r.enabled AND r.sql_check IS NOT NULL ORDER BY r.rule_id").fetchall()
        rules = [r for r in rules if r[4] and r[4].startswith("std.")]
        for rid, label, _dim, _cls, ds, sev, thr, sql in rules:
            try:
                with c.transaction():
                    found = [tuple(x) + (None, None) for x in c.execute(sql).fetchmany(5000)]
            except psycopg.Error as e:
                print(f"!! 품질 규칙 {rid} 실행 실패, 건너뜀: {e.diag.message_primary}", file=sys.stderr)
                continue
            table = "ksx." + ds.split(".", 1)[1]
            focus = c.execute(f"SELECT count(*) FROM {table}").fetchone()[0] if self.has(table) else len(found)
            focus = focus or len(found)
            today[rid] = (found, focus)
            for ago in range(self.days - 1, -1, -1):
                t = self.at(self.day(ago), 7.6 + rnd.uniform(0, 0.3))
                if t >= self.now:
                    continue
                if ago == 0 or (ago == 1 and self.now.hour < 8):
                    n = len(found)
                else:
                    n = max(0, len(found) + rnd.choice([-2, -1, 0, 0, 1, 2])) if rid != "q-perf-defect-le-produced" else (1 if ago < 8 else 0)
                f = focus if n == len(found) else int(focus * (0.96 + 0.04 * (self.days - ago) / self.days))
                n = min(n, f)
                qid = uid("qrun", rid, ago)
                qruns.append({"quality_run_id": qid, "dataset_id": ds, "rule_id": rid, "executed_at": t.replace(tzinfo=KST),
                              "focus_count": f, "violation_count": n,
                              "report_uri": f"db://catalog.quality_run/{MARK}/{rid}/{self.day(ago)}"})
                is_last = ago == 0 or (ago == 1 and self.now.hour < 8)
                if is_last:
                    for i, r in enumerate(found[:200]):
                        viols.append({"quality_run_id": qid, "rule_id": rid, "focus_node": str(r[0]), "result_path": r[1],
                                      "message": r[2] or label, "severity": sev, "status": "ACK" if i % 4 == 3 else "OPEN",
                                      "assignee_user_id": "u-choi" if i % 4 == 3 else None})
                elif n and ago in (6, 13, 20):
                    for i in range(min(n, 3)):
                        viols.append({"quality_run_id": qid, "rule_id": rid, "focus_node": f"{rid}#{ago}-{i}", "result_path": None,
                                      "message": f"{label} — {self.day(ago)} 검사에서 발견, 원천 수정 후 해소", "severity": sev,
                                      "status": "FIXED" if i % 3 else "WAIVED", "assignee_user_id": "u-choi",
                                      "resolved_at": (t + dt.timedelta(days=1)).replace(tzinfo=KST)})
        self.copy("catalog.quality_run", qruns)
        self.copy("catalog.quality_violation", viols)
        for rid, (found, focus) in today.items():
            ds = next(r[4] for r in rules if r[0] == rid)
            if ds is None:
                continue
            score = round(100 * (1 - len(found) / focus), 2) if focus else None
            thr = float(next(r[6] for r in rules if r[0] == rid) or 0)
            c.execute("UPDATE catalog.dataset SET quality_score = %s, quality_status = %s WHERE dataset_id = %s",
                      (score, "PASS" if score is None or score >= thr else ("WARN" if score >= thr - 5 else "FAIL"), ds))

    # ── 리스크·조치 ──────────────────────────────────────────────────────────
    def risks(self):
        rnd = self.rnd
        events, actions = [], []
        by_eq = defaultdict(list)
        for s in self.c.execute(
                "SELECT s.equipment_id, s.lot_id, s.operation_start_time FROM ksx.operation_start s WHERE s.creator_id = %s",
                (MARK,)).fetchall():
            by_eq[s[0]].append(s)
        for i, (eq, pid, ago, h, dur, shift, rate) in enumerate(EPISODES):
            ws, we = self.ep_win[pid]
            hit = sorted({s[1] for s in by_eq[eq] if ws - dt.timedelta(hours=4) <= s[2] <= we})
            p = next(x for x in PARAMS if x[0] == pid)
            plant = p[4]
            open_ = ago <= 3
            ev = uid("risk", "spec", i)
            events.append({"event_id": ev, "event_class_iri": ARCON + "SpecOutEvent", "enterprise_id": ENT, "site_id": SITE,
                           "plant_id": plant, "source_iri": DATA.format("equipment", eq),
                           "affected_iris": [DATA.format("lot", l) for l in hit[:6]],
                           "risk_level": "HIGH" if rate > 0.03 else "MEDIUM",
                           "detail": {"equipment_id": eq, "parameter_id": pid, "parameter_name": p[1],
                                      "window": f"{ws:%m-%d %H:%M}~{we:%H:%M}", "limit": f"{p[7]}~{p[8]}{p[2]}",
                                      "lots": hit[:6], "cause": f"{eq} {p[1]} 규격 이탈 {dur}시간"},
                           "derived_by": ARCON + f"rules/spec-out#{MARK}", "detected_at": (ws + dt.timedelta(minutes=17)).replace(tzinfo=KST),
                           "status": "ACTIONED" if open_ else "CLOSED"})   # 담당 엔지니어 알림까지 끝난 사건
            actions.append({"execution_id": uid("act", "notify", i), "policy_id": "spec-out", "risk_event_id": ev,
                            "enterprise_id": ENT, "site_id": SITE, "plant_id": plant, "action_iri": ARCON + "NotifyEngineer",
                            "target_iri": DATA.format("equipment", eq), "verb": "Notify", "noun": "Equipment",
                            "receiver_system": "MES-A" if plant == "P1" else "MES-B", "status": "ACKNOWLEDGED",
                            "requested_by": f"agent:spec-out ({MARK})", "approved_by": None,
                            "rationale": {"rule": "spec-out", "facts": [{"tier": "OBSERVED", "text": f"{eq} {p[1]} {p[7]}~{p[8]}{p[2]} 이탈"}]},
                            "created_at": (ws + dt.timedelta(minutes=18)).replace(tzinfo=KST),
                            "sent_at": (ws + dt.timedelta(minutes=18)).replace(tzinfo=KST),
                            "acknowledged_at": (ws + dt.timedelta(minutes=31)).replace(tzinfo=KST)})
            if rate > 0.03 and hit:
                lot = hit[0]
                info = self.lot_info.get(lot)
                ev2 = uid("risk", "otd", i)
                events.append({"event_id": ev2, "event_class_iri": ARCON + "OTDRiskEvent", "enterprise_id": ENT, "site_id": SITE,
                               "plant_id": plant, "source_iri": DATA.format("lot", lot),
                               "affected_iris": [DATA.format("salesOrder", info[6]), DATA.format("customer", info[7])] if info else [],
                               "risk_level": "CRITICAL" if open_ else "HIGH",
                               "detail": {"lot_id": lot, "defect_rate_pct": round(100 * info[5] / info[4], 2) if info else None,
                                          "sales_order_id": info[6] if info else None, "customer_id": info[7] if info else None,
                                          "requested_delivery_date": str(info[3]) if info else None,
                                          "cause": f"{eq} {p[1]} 규격 이탈 구간({ws:%m-%d %H:%M}~{we:%H:%M})에 처리된 로트"},
                               "derived_by": ARCON + f"rules/otd-risk#{MARK}", "detected_at": (we + dt.timedelta(hours=1)).replace(tzinfo=KST),
                               "status": "OPEN" if open_ else "ACTIONED"})
                actions.append({"execution_id": uid("act", "hold", i), "policy_id": "otd-risk", "risk_event_id": ev2,
                                "enterprise_id": ENT, "site_id": SITE, "plant_id": plant, "action_iri": ARCON + "HoldLot",
                                "target_iri": DATA.format("lot", lot), "verb": "Change", "noun": "Lot",
                                "receiver_system": "MES-A" if plant == "P1" else "MES-B",
                                "status": "PROPOSED" if open_ else "ACKNOWLEDGED",
                                "requested_by": f"agent:otd-risk ({MARK})", "approved_by": None if open_ else "u-kim",
                                "rationale": {"rule": "otd-risk", "facts": [
                                    {"tier": "OBSERVED", "text": f"{eq} {p[1]} 규격 이탈 ({ws:%m-%d %H:%M}~{we:%H:%M})"},
                                    {"tier": "ASSERTED", "text": f"{lot} 는 그 구간에 {eq} 에서 처리됨"},
                                    {"tier": "INFERRED", "text": "불량률 3% 초과 → 납기 리스크, 로트 보류 권고"}]},
                                "created_at": (we + dt.timedelta(hours=1, minutes=2)).replace(tzinfo=KST),
                                "sent_at": None if open_ else (we + dt.timedelta(hours=2)).replace(tzinfo=KST),
                                "acknowledged_at": None if open_ else (we + dt.timedelta(hours=2, minutes=5)).replace(tzinfo=KST)})
        # 공급 리스크 (구매팀이 긴급 발주로 처리)
        events.append({"event_id": uid("risk", "supply", 0), "event_class_iri": ARCON + "SupplyRiskEvent", "enterprise_id": ENT,
                       "site_id": SITE, "plant_id": "P1", "source_iri": DATA.format("item", "RM-SB"),
                       "affected_iris": [DATA.format("vendor", "V-103")], "risk_level": "MEDIUM",
                       "detail": {"item_id": "RM-SB", "cause": "솔더볼 재고가 안전재고의 절반 밑", "vendor_id": "V-103"},
                       "derived_by": ARCON + f"rules/supply-risk#{MARK}", "detected_at": self.at(self.day(1), 8.2).replace(tzinfo=KST),
                       "status": "ACTIONED"})
        self.insert("sem.risk_event", events, "(event_id) DO NOTHING")
        self.insert("gov.action_execution", actions, "(execution_id) DO NOTHING")

    # ── 사용자·접근 요청 ─────────────────────────────────────────────────────
    def people_and_access(self):
        c = self.c
        self.insert("gov.app_user", [{"user_id": u, "display_name": nm, "email": f"{u[2:]}@acme.example", "personnel_id": pe,
                                      "enterprise_id": ENT} for u, nm, _r, _p, pe in APP_USERS], "(user_id) DO NOTHING")
        self.insert("gov.role_assignment", [{"user_id": u, "role_id": r, "enterprise_id": ENT, "site_id": SITE if p else None,
                                             "plant_id": p, "granted_by": MARK} for u, _n, r, p, _e in APP_USERS], "DO NOTHING")
        reqs = [  # 요청자, 데이터셋, 목적, 동작, 며칠 전, 상태, 결정자, 메모
            ("u-park", "raw.mes-b.production_result", "2공장 불량 유형 추이 분석", ["read"], 26, "APPROVED", "u-choi", "2공장 범위로 승인"),
            ("u-jung", "raw.scm-p.purchase_order_export", "솔더볼 발주 리드타임 분석", ["read", "download"], 21, "APPROVED", "u-choi", "다운로드는 30일만"),
            ("u-lee", "raw.eap07.trace", "EQ-07 온도 추이 확인", ["read"], 15, "REJECTED", "u-choi", "원본 대신 표준 존 trace_parameter 를 쓰세요"),
            ("u-oh", "raw.mes-a.production_result", "1·2공장 수율 비교", ["read"], 9, "APPROVED", "u-choi", None),
            ("u-han", "raw.mes.lot_history", "로트 이력 적재 지연 원인 조사", ["read"], 6, "CANCELLED", None, None),
            ("u-park", "raw.scm-p.purchase_order_export", "2공장 트레이 재고 부족 원인 파악", ["read"], 2, "REQUESTED", None, None),
            ("u-jung", "raw.mes-b.production_result", "EQ-24 이탈 로트 불량 영향 분석", ["read", "download"], 1, "REQUESTED", None, None),
            ("u-oh", "raw.eap07.trace", "리플로우 온도 프로파일 비교 (1·2공장)", ["read"], 0, "REQUESTED", None, None),
        ]
        rows = []
        for i, (who, ds, purpose, acts, ago, st, by, note) in enumerate(reqs):
            t = self.at(self.day(ago), 9 + i % 7 + 0.3)
            if t > self.now:
                t = self.now - dt.timedelta(minutes=30 + i)
            rows.append({"request_id": uid("access", i), "requester_id": who, "dataset_id": ds, "purpose": purpose + " (시연)",
                         "requested_actions": acts, "period_from": t.date(), "period_to": t.date() + dt.timedelta(days=30),
                         "status": st, "approver_id": by, "enterprise_id": ENT,
                         "decided_at": (t + dt.timedelta(hours=5)).replace(tzinfo=KST) if by else None, "decision_note": note,
                         "created_at": t.replace(tzinfo=KST)})
        self.insert("gov.access_request", rows, "(request_id) DO NOTHING")

    # ── 감사 기록 ────────────────────────────────────────────────────────────
    def audit(self):
        rnd = self.rnd
        last = self.c.execute("SELECT max(occurred_at) FROM gov.audit_log WHERE host(client_ip) LIKE %s",
                              (AUDIT_NET + "%",)).fetchone()[0]
        since = last.astimezone(KST).replace(tzinfo=None) if last else self.at(self.start, 0)
        lots = sorted(self.lot_info)
        users = {"u-jung": 21, "u-kim": 31, "u-lee": 41, "u-park": 51, "u-choi": 61, "u-han": 71, "u-oh": 81, "u-yoon": 91}
        questions = ["지난주 공정별 불량 PPM 상위 3개", "2공장 이번 달 수율 추이", "납기 7일 안 수주 중 진행 로트",
                     "EQ-06 리플로우 온도 이탈 시간대", "안전재고 밑으로 내려간 자재", "고객별 납기 준수율"]
        rows = []
        for ago in range(self.days - 1, -1, -1):
            d = self.day(ago)
            n = rnd.randint(6, 14) if d.weekday() < 5 else rnd.randint(1, 4)
            for _ in range(n):
                t = self.at(d, rnd.uniform(8, 19))
                if t <= since or t >= self.now:
                    continue
                u = rnd.choice(list(users))
                kind = rnd.random()
                row = {"occurred_at": t.replace(tzinfo=KST), "enterprise_id": ENT, "user_id": u,
                       "client_ip": f"{AUDIT_NET}{users[u] // 10}.{users[u]}", "channel": "UI", "result": "OK"}
                if kind < 0.45:
                    row |= {"action": "read", "object_ref": f"ksx.lot:{rnd.choice(lots)}", "row_count": 1}
                elif kind < 0.6:
                    row |= {"action": "read", "object_ref": f"ksx.equipment:{rnd.choice(EQUIP)[0]}", "row_count": 1}
                elif kind < 0.8:
                    q = rnd.choice(questions)
                    denied = u == "u-park" and rnd.random() < 0.3
                    row |= {"channel": "MCP", "action": "agent_query", "query_text": f"-- {q}\nSELECT …",
                            "row_count": 0 if denied else rnd.randint(3, 40), "result": "DENIED" if denied else "OK"}
                elif kind < 0.9:
                    row |= {"action": "export", "dataset_id": rnd.choice(["cur.kpi_process_ppm", "raw.mes-a.production_result"]),
                            "row_count": rnd.randint(50, 900)}
                else:
                    row |= {"channel": "API", "action": "read", "object_ref": "mart.v_kpi_otd", "row_count": rnd.randint(20, 120)}
                rows.append(row)
        for b in self.batches:
            if b["at"] <= since:
                continue
            ip = f"{AUDIT_NET}6.61"
            rows.append({"occurred_at": b["at"].replace(tzinfo=KST), "enterprise_id": ENT, "user_id": "u-han", "client_ip": ip,
                         "channel": "UI", "action": "ingest", "dataset_id": b["dataset_id"],
                         "object_ref": f"raw.ingest_batch:{b['batch_id']}", "row_count": b["rows"], "result": "OK"})
            rows.append({"occurred_at": (b["at"] + dt.timedelta(minutes=6)).replace(tzinfo=KST), "enterprise_id": ENT,
                         "user_id": "u-han", "client_ip": ip, "channel": "UI", "action": "standardize", "dataset_id": b["dataset_id"],
                         "object_ref": f"raw.ingest_batch:{b['batch_id']}", "query_text": f"ksx.{b['std']}",
                         "row_count": b["rows"] - b["rej"], "result": "OK"})
        rows.sort(key=lambda r: r["occurred_at"])
        self.copy("gov.audit_log", rows)

    def finish(self):
        c = self.c
        # 표준 존 데이터셋의 행 수·마지막 적재 시각을 실제 표에 맞춘다
        for ds, loc in c.execute("SELECT dataset_id, location_uri FROM catalog.dataset WHERE zone_id = 'STANDARD'"
                                 " AND location_uri LIKE 'postgresql://lake/ksx.%%'").fetchall():
            table = loc.rsplit("/", 1)[1]
            if not self.has(table):
                continue
            has_loaded = "lake_loaded_at" in self.cols(table)
            n, last = c.execute(f"SELECT count(*), {'max(lake_loaded_at)' if has_loaded else 'NULL::timestamptz'} FROM {table}").fetchone()
            c.execute("UPDATE catalog.dataset SET record_count = %s, last_ingested_at = coalesce(%s, last_ingested_at) WHERE dataset_id = %s",
                      (n, last, ds))
        c.execute("UPDATE catalog.dataset SET last_ingested_at = %s, record_count = %s WHERE dataset_id = 'raw.mes.lot_history'",
                  (self.now.replace(tzinfo=KST) - dt.timedelta(minutes=24), 1250000 + 40 * len(self.lot_info)))

    def run(self):
        self.c.execute("SET CONSTRAINTS ALL DEFERRED")
        self.reset()
        self.masters()
        self.production()
        self.equipment_signals()
        self.purchasing()
        self.ingest_batches()
        self.proposals()
        self.pipeline_runs()
        self.quality()
        self.risks()
        self.people_and_access()
        self.audit()
        self.finish()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dsn", default=os.environ.get("DATABASE_URL", ""), help="생략하면 PG* 환경변수")
    ap.add_argument("--anchor", type=dt.date.fromisoformat, default=dt.datetime.now(KST).date(), help="기준일 (기본: 오늘, 한국 날짜)")
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--seed", type=int, default=7)
    a = ap.parse_args()
    with psycopg.connect(a.dsn, autocommit=False) as conn:
        conn.execute("SET TIME ZONE 'Asia/Seoul'")
        s = Seeder(conn, a.anchor, a.days, a.seed)
        s.run()
        conn.commit()
    print(f"== 시연 데이터 ({a.anchor} 기준 {a.days}일)")
    for t, n in sorted(s.counts.items()):
        print(f"   {t:45s} {n:>7,}")
    for t, cols in sorted(s.dropped.items()):
        print(f"!! {t}: 없는 열은 건너뜀 → {', '.join(sorted(cols))}", file=sys.stderr)


if __name__ == "__main__":
    main()
