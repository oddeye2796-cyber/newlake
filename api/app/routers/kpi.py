from fastapi import APIRouter, Depends, Query

from ..deps import Scoped, scoped

router = APIRouter(prefix="/api/kpi", tags=["kpi"])

TODAY = "(now() AT TIME ZONE 'Asia/Seoul')::date"


@router.get("/yield")
def kpi_yield(days: int = Query(default=30, ge=1, le=366), s: Scoped = Depends(scoped)):
    return s.conn.execute(
        f"SELECT * FROM mart.v_kpi_yield_daily WHERE perf_date >= {TODAY} - %s ORDER BY perf_date, item_id", (days,)).fetchall()


@router.get("/ppm")
def kpi_ppm(days: int = Query(default=30, ge=1, le=366), s: Scoped = Depends(scoped)):
    return s.conn.execute(
        f"SELECT * FROM mart.v_kpi_process_ppm WHERE perf_date >= {TODAY} - %s ORDER BY perf_date, operation_id",
        (days,)).fetchall()


@router.get("/utilization")
def kpi_util(days: int = Query(default=30, ge=1, le=366), s: Scoped = Depends(scoped)):
    return s.conn.execute(
        f"SELECT * FROM mart.v_kpi_equipment_time_util WHERE perf_date >= {TODAY} - %s ORDER BY perf_date, equipment_id",
        (days,)).fetchall()


@router.get("/otd")
def kpi_otd(s: Scoped = Depends(scoped)):
    rows = s.conn.execute("SELECT * FROM mart.v_kpi_otd ORDER BY requested_delivery_date").fetchall()
    judged = [r for r in rows if r["on_time"] is not None]
    rate = round(100 * sum(1 for r in judged if r["on_time"]) / len(judged), 1) if judged else None
    return {"otd_pct": rate, "orders": rows}


@router.get("/wip")
def kpi_wip(s: Scoped = Depends(scoped)):
    return s.conn.execute("SELECT * FROM mart.v_kpi_wip ORDER BY plant_id, current_operation_id, lot_state").fetchall()


@router.get("/risks")
def risk_candidates(s: Scoped = Depends(scoped)):
    """납기 리스크 후보 (불량률 > 3% 로트 × 7일 내 납기)."""
    return s.conn.execute("SELECT * FROM mart.v_otd_risk_candidate ORDER BY requested_delivery_date").fetchall()
