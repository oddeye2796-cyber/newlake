import { useEffect, useMemo, useState, type FormEvent, type ReactNode } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Activity, Boxes, Gauge, Sparkles, Truck, type LucideIcon } from 'lucide-react';
import type { Home as HomeT, PpmRow, SpecOut } from '../api';
import { useAuth } from '../auth';
import { State } from '../components/ui';
import { daysLeft, fmtTs, n0, pct, riskPill, KIND_KO } from '../format';
import { getRecent } from '../recent';
import { useApi } from '../useApi';
import { SUGGESTED } from '../askPresets';

interface Task { key: string; sev: 'crit' | 'warn'; title: string; body: string; btns: ReactNode }

function groupSpecOuts(rows: SpecOut[]) {
  const m = new Map<string, SpecOut[]>();
  rows.forEach((r) => { const k = `${r.equipment_id}|${r.parameter_id}`; m.set(k, [...(m.get(k) || []), r]); });
  return [...m.values()];
}

export default function Home() {
  const { me } = useAuth();
  const nav = useNavigate();
  const home = useApi<HomeT>('/api/home');
  const ppm = useApi<PpmRow[]>('/api/kpi/ppm');
  const [q, setQ] = useState('');
  const [recent] = useState(getRecent);

  const tasks = useMemo<Task[]>(() => {
    const d = home.data; if (!d) return [];
    const out: Task[] = [];
    d.risks.forEach((r) => {
      const x = r.detail, left = daysLeft(x.requested_delivery_date);
      const [lv] = riskPill(r.risk_level);
      out.push({
        key: r.event_id, sev: 'crit',
        title: `주문 ${x.sales_order_id ?? ''} 납기가 위험해요 (위험도 ${lv})`,
        body: `납기 ${x.requested_delivery_date ?? '—'}${left != null ? `(${left >= 0 ? `${left}일 남음` : `${-left}일 지남`})` : ''}인 주문에 들어갈 로트 ${x.lot_id ?? ''}에서 불량률 ${x.defect_rate_pct ?? '—'}%가 나왔어요. ${x.cause ?? ''}`,
        btns: <>
          {x.lot_id && <Link className="btn primary" to={`/find/lot/${x.lot_id}`}>로트 보기</Link>}
          {x.sales_order_id && <Link className="btn" to={`/find/order/${x.sales_order_id}`}>주문 보기</Link>}
          <Link className="btn" to="/ask">원인 보기</Link>
        </>,
      });
    });
    if (d.pending_approvals > 0) {
      out.push({ key: 'pending', sev: 'warn', title: `승인을 기다리는 요청이 ${d.pending_approvals}건 있어요`, body: '요청함에서 근거를 확인하고 승인하거나 반려할 수 있어요.', btns: <Link className="btn" to="/inbox">요청함 열기</Link> });
    }
    groupSpecOuts(d.spec_outs).forEach((g) => {
      const top = g.reduce((a, b) => (Math.abs(b.parameter_value - (b.usl ?? 0)) > Math.abs(a.parameter_value - (a.usl ?? 0)) ? b : a));
      const first = [...g].sort((a, b) => a.event_date_time.localeCompare(b.event_date_time))[0];
      const lots = [...new Set(g.map((s) => s.lot_id).filter(Boolean))].join(', ');
      out.push({
        key: `so-${top.equipment_id}-${top.parameter_id}`, sev: 'crit',
        title: `설비 ${top.equipment_id}에서 기준 이탈이 있었어요 (${top.parameter_name})`,
        body: `${fmtTs(first.event_date_time)}부터 ${g.length}회 기준(${top.lsl}~${top.usl})을 벗어났고, 최대 ${top.parameter_value}였어요.${lots ? ` 그때 진행한 로트: ${lots}` : ''}`,
        btns: <>{top.equipment_id && <Link className="btn" to={`/find/equipment/${top.equipment_id}`}>설비 보기</Link>}</>,
      });
    });
    return out;
  }, [home.data]);

  const worstPpm = useMemo(() => {
    const rows = ppm.data || []; if (!rows.length) return null;
    const last = rows.reduce((a, b) => (b.perf_date > a ? b.perf_date : a), '');
    return rows.filter((r) => r.perf_date === last).reduce((a, b) => (b.ppm > a.ppm ? b : a));
  }, [ppm.data]);

  useEffect(() => { document.title = '홈 · 뉴레이크'; }, []);
  const submit = (e: FormEvent) => { e.preventDefault(); if (q.trim()) nav(`/ask?q=${encodeURIComponent(q.trim())}`); };
  const k = home.data?.kpi;
  const tiles: [string, string, string, LucideIcon, string][] = [
    ['양품률', pct(k?.yield_7d_pct, 2), '최근 7일', Gauge, 'var(--ok)'],
    ['불량 PPM', worstPpm ? `${n0(worstPpm.ppm)}` : '—', worstPpm ? `${worstPpm.operation_id} · ${worstPpm.perf_date}` : '데이터 없음', Activity, 'var(--crit)'],
    ['납기 준수', pct(k?.otd_pct), '출고 완료 주문 기준', Truck, 'var(--accent)'],
    ['진행 중 로트', k ? `${k.wip_lots}개` : '—', `보류 ${k?.hold_lots ?? 0}개`, Boxes, 'var(--info)'],
  ];
  const nCrit = tasks.filter((t) => t.sev === 'crit').length;

  return (
    <>
      <section className="hero" aria-label="오늘 요약">
        <span className="eyebrow"><Sparkles aria-hidden="true" />{me ? `${me.enterprise_id} · ${me.site_ids === '*' ? '전사' : [me.site_ids, me.plant_ids].flat().join(' / ')}` : '오늘의 공장'}</span>
        <h1>{me ? `${me.display_name} 님, ` : ''}오늘 확인할 일이 {tasks.length}건 있어요</h1>
        <p>규칙이 잡아낸 위험, 승인을 기다리는 요청, 기준을 벗어난 설비 값을 한곳에 모았어요. 항목을 열면 근거가 된 기록까지 따라가 볼 수 있어요.</p>
        <div className="hstats">
          <span className="hstat" style={{ ['--c' as string]: '#FB7185' }}><i />위험 <b>{nCrit}</b></span>
          <span className="hstat" style={{ ['--c' as string]: '#FBBF24' }}><i />승인 대기 <b>{home.data?.pending_approvals ?? 0}</b></span>
          <span className="hstat" style={{ ['--c' as string]: '#34D399' }}><i />진행 로트 <b>{k?.wip_lots ?? '—'}</b></span>
        </div>
      </section>
      <State loading={home.loading} error={home.error} />
      <section aria-label="확인할 일" className="alerts">
        {tasks.map((t) => (
          <div key={t.key} className="alert task" style={{ ['--sc' as string]: `var(--${t.sev})` }}>
            <span className="sev" /><div><b>{t.title}</b><p>{t.body}</p></div><div className="acts">{t.btns}</div>
          </div>
        ))}
        {home.data && tasks.length === 0 && <div className="panel muted">지금 확인할 일이 없어요.</div>}
      </section>
      <div className="grid g4" style={{ marginTop: 20 }}>
        {tiles.map(([label, value, desc, Icon, color]) => (
          <Link key={label} className="kcard" to="/kpi" style={{ ['--kc' as string]: color }}>
            <span className="ki" aria-hidden="true"><Icon /></span>
            <span className="kl">{label}</span><span className="kv num">{value}</span><span className="kd">{desc}</span>
          </Link>
        ))}
      </div>
      <div className="grid g2" style={{ marginTop: 16 }}>
        <section className="panel"><header><h2>무엇이든 물어보세요</h2></header>
          <form className="composer" style={{ marginTop: 0 }} onSubmit={submit}>
            <input className="input grow" value={q} onChange={(e) => setQ(e.target.value)} placeholder="예: EQ-07 때문에 위험한 주문 있어?" autoComplete="off" aria-label="질문" />
            <button className="btn primary" type="submit">질문</button>
          </form>
          <div className="suggest">{SUGGESTED.slice(0, 3).map((s) => <Link key={s.id} className="chip" to={`/ask?p=${s.id}`}>{s.question}</Link>)}</div>
        </section>
        <section className="panel"><header><h2>최근 본 항목</h2><Link className="btn" to="/find">찾아보기</Link></header>
          {recent.length === 0 ? <p className="muted small">아직 본 항목이 없어요. 찾아보기에서 로트나 설비를 열어 보세요.</p> :
            <div className="recent">{recent.map((r) => (
              <Link key={r.kind + r.id} className="rcard" to={`/find/${r.kind}/${r.id}`} style={{ textDecoration: 'none', color: 'inherit' }}>
                <span className="small muted">{KIND_KO[r.kind]}</span><b>{r.id}</b><span className="small">{r.label}</span>
              </Link>))}</div>}
        </section>
      </div>
    </>
  );
}
