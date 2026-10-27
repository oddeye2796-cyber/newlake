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
import { t, tl } from '../i18n';

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
        title: t('주문 {id} 납기가 위험해요 (위험도 {lv})', { id: x.sales_order_id ?? '', lv }),
        body: `${t('납기 {date}{left}인 주문에 들어갈 로트 {lot}에서 불량률 {rate}%가 나왔어요.', { date: x.requested_delivery_date ?? '—', left: left != null ? `(${left >= 0 ? t('{n}일 남음', { n: left }) : t('{n}일 지남', { n: -left })})` : '', lot: x.lot_id ?? '', rate: x.defect_rate_pct ?? '—' })} ${tl(x.cause) ?? ''}`,
        btns: <>
          {x.lot_id && <Link className="btn primary" to={`/find/lot/${x.lot_id}`}>{t('로트 보기')}</Link>}
          {x.sales_order_id && <Link className="btn" to={`/find/order/${x.sales_order_id}`}>{t('주문 보기')}</Link>}
          <Link className="btn" to="/ask">{t('원인 보기')}</Link>
        </>,
      });
    });
    if (d.pending_approvals > 0) {
      out.push({ key: 'pending', sev: 'warn', title: t('승인을 기다리는 요청이 {n}건 있어요', { n: d.pending_approvals }), body: t('요청함에서 근거를 확인하고 승인하거나 반려할 수 있어요.'), btns: <Link className="btn" to="/inbox">{t('요청함 열기')}</Link> });
    }
    groupSpecOuts(d.spec_outs).forEach((g) => {
      const top = g.reduce((a, b) => (Math.abs(b.parameter_value - (b.usl ?? 0)) > Math.abs(a.parameter_value - (a.usl ?? 0)) ? b : a));
      const first = [...g].sort((a, b) => a.event_date_time.localeCompare(b.event_date_time))[0];
      const lots = [...new Set(g.map((s) => s.lot_id).filter(Boolean))].join(', ');
      out.push({
        key: `so-${top.equipment_id}-${top.parameter_id}`, sev: 'crit',
        title: t('설비 {id}에서 기준 이탈이 있었어요 ({param})', { id: top.equipment_id ?? '', param: tl(top.parameter_name) }),
        body: `${t('{ts}부터 {n}회 기준({lsl}~{usl})을 벗어났고, 최대 {max}였어요.', { ts: fmtTs(first.event_date_time), n: g.length, lsl: top.lsl ?? '—', usl: top.usl ?? '—', max: top.parameter_value })}${lots ? ` ${t('그때 진행한 로트: {lots}', { lots })}` : ''}`,
        btns: <>{top.equipment_id && <Link className="btn" to={`/find/equipment/${top.equipment_id}`}>{t('설비 보기')}</Link>}</>,
      });
    });
    return out;
  }, [home.data]);

  const worstPpm = useMemo(() => {
    const rows = ppm.data || []; if (!rows.length) return null;
    const last = rows.reduce((a, b) => (b.perf_date > a ? b.perf_date : a), '');
    return rows.filter((r) => r.perf_date === last).reduce((a, b) => (b.ppm > a.ppm ? b : a));
  }, [ppm.data]);

  useEffect(() => { document.title = t('홈 · ARCON'); }, []);
  const submit = (e: FormEvent) => { e.preventDefault(); if (q.trim()) nav(`/ask?q=${encodeURIComponent(q.trim())}`); };
  const k = home.data?.kpi;
  const tiles: [string, string, string, LucideIcon, string][] = [
    [t('양품률'), pct(k?.yield_7d_pct, 2), t('최근 7일'), Gauge, 'var(--ok)'],
    [t('불량 PPM'), worstPpm ? `${n0(worstPpm.ppm)}` : '—', worstPpm ? `${worstPpm.operation_id} · ${worstPpm.perf_date}` : t('데이터 없음'), Activity, 'var(--crit)'],
    [t('납기 준수'), pct(k?.otd_pct), t('출고 완료 주문 기준'), Truck, 'var(--accent)'],
    [t('진행 중 로트'), k ? t('{n}개', { n: k.wip_lots }) : '—', t('보류 {n}개', { n: k?.hold_lots ?? 0 }), Boxes, 'var(--info)'],
  ];
  const nCrit = tasks.filter((x) => x.sev === 'crit').length;

  return (
    <>
      <section className="hero" aria-label={t('오늘 요약')}>
        <span className="eyebrow"><Sparkles aria-hidden="true" />{me ? `${me.enterprise_id} · ${me.site_ids === '*' ? t('전사') : [me.site_ids, me.plant_ids].flat().join(' / ')}` : t('오늘의 공장')}</span>
        <h1>{me ? t('{name} 님, 오늘 확인할 일이 {n}건 있어요', { name: tl(me.display_name), n: tasks.length }) : t('오늘 확인할 일이 {n}건 있어요', { n: tasks.length })}</h1>
        <p>{t('규칙이 잡아낸 위험, 승인을 기다리는 요청, 기준을 벗어난 설비 값을 한곳에 모았어요. 항목을 열면 근거가 된 기록까지 따라가 볼 수 있어요.')}</p>
        <div className="hstats">
          <span className="hstat" style={{ ['--c' as string]: '#FB7185' }}><i />{t('위험')} <b>{nCrit}</b></span>
          <span className="hstat" style={{ ['--c' as string]: '#FBBF24' }}><i />{t('승인 대기')} <b>{home.data?.pending_approvals ?? 0}</b></span>
          <span className="hstat" style={{ ['--c' as string]: '#34D399' }}><i />{t('진행 로트')} <b>{k?.wip_lots ?? '—'}</b></span>
        </div>
      </section>
      <State loading={home.loading} error={home.error} />
      <section aria-label={t('확인할 일')} className="alerts">
        {tasks.map((tk) => (
          <div key={tk.key} className="alert task" style={{ ['--sc' as string]: `var(--${tk.sev})` }}>
            <span className="sev" /><div><b>{tk.title}</b><p>{tk.body}</p></div><div className="acts">{tk.btns}</div>
          </div>
        ))}
        {home.data && tasks.length === 0 && <div className="panel muted">{t('지금 확인할 일이 없어요.')}</div>}
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
        <section className="panel"><header><h2>{t('무엇이든 물어보세요')}</h2></header>
          <form className="composer" style={{ marginTop: 0 }} onSubmit={submit}>
            <input className="input grow" value={q} onChange={(e) => setQ(e.target.value)} placeholder={t('예: EQ-07 때문에 위험한 주문 있어?')} autoComplete="off" aria-label={t('질문')} />
            <button className="btn primary" type="submit">{t('질문')}</button>
          </form>
          <div className="suggest">{SUGGESTED.slice(0, 3).map((s) => <Link key={s.id} className="chip" to={`/ask?p=${s.id}`}>{s.question}</Link>)}</div>
        </section>
        <section className="panel"><header><h2>{t('최근 본 항목')}</h2><Link className="btn" to="/find">{t('찾아보기')}</Link></header>
          {recent.length === 0 ? <p className="muted small">{t('아직 본 항목이 없어요. 찾아보기에서 로트나 설비를 열어 보세요.')}</p> :
            <div className="recent">{recent.map((r) => (
              <Link key={r.kind + r.id} className="rcard" to={`/find/${r.kind}/${r.id}`} style={{ textDecoration: 'none', color: 'inherit' }}>
                <span className="small muted">{KIND_KO[r.kind]}</span><b>{r.id}</b><span className="small">{tl(r.label)}</span>
              </Link>))}</div>}
        </section>
      </div>
    </>
  );
}
