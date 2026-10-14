/* 작은 인라인 SVG 차트. 의존성 없음. */
export function Spark({ vals, color }: { vals: number[]; color: string }) {
  if (vals.length < 2) return null;
  const w = 120, h = 30, mn = Math.min(...vals), mx = Math.max(...vals), sx = w / (vals.length - 1);
  const sy = (v: number) => h - 3 - ((v - mn) / (mx - mn || 1)) * (h - 6);
  const pts = vals.map((v, i) => `${(i * sx).toFixed(1)},${sy(v).toFixed(1)}`).join(' ');
  const last = vals.length - 1;
  return (
    <svg viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none" aria-hidden="true">
      <polygon points={`0,${h} ${pts} ${w},${h}`} fill={color} opacity=".12" />
      <polyline points={pts} fill="none" stroke={color} strokeWidth="1.6" vectorEffect="non-scaling-stroke" />
      <circle cx={last * sx} cy={sy(vals[last])} r="2.6" fill={color} />
    </svg>
  );
}

export interface TracePt { t: string; v: number }
const toMs = (s: string) => { const m = /(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})/.exec(s); return m ? Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5]) : 0; };
const lbl = (ms: number) => { const d = new Date(ms); const p = (n: number) => String(n).padStart(2, '0'); return `${p(d.getUTCMonth() + 1)}-${p(d.getUTCDate())} ${p(d.getUTCHours())}:${p(d.getUTCMinutes())}`; };

/** 파라미터 시계열 + 규격 상·하한. 시각은 서버 값 그대로(UTC 필드로 읽기만 함, 변환 없음). */
export function TraceChart({ pts, lsl, usl, unit, name }: { pts: TracePt[]; lsl: number | null; usl: number | null; unit: string; name: string }) {
  if (!pts.length) return <p className="muted small">이 기간에 측정값이 없어요.</p>;
  const W = 640, H = 220, l = 48, r = 40, t = 14, b = 30;
  const xs = pts.map((p) => toMs(p.t));
  const x0 = Math.min(...xs), x1 = Math.max(...xs);
  const vals = pts.map((p) => p.v).concat([lsl, usl].filter((v): v is number => v != null));
  const lo = Math.min(...vals), hi = Math.max(...vals), pad = (hi - lo || 10) * 0.12;
  const ymin = lo - pad, ymax = hi + pad;
  const x = (ms: number) => l + (x1 === x0 ? 0.5 : (ms - x0) / (x1 - x0)) * (W - l - r);
  const y = (v: number) => t + ((ymax - v) / (ymax - ymin)) * (H - t - b);
  const ticks = Array.from({ length: 5 }, (_, i) => ymin + ((ymax - ymin) * i) / 4);
  const xt = x1 === x0 ? [x0] : [0, 1, 2].map((i) => x0 + ((x1 - x0) * i) / 2);
  const out = (v: number) => (usl != null && v > usl) || (lsl != null && v < lsl);
  const sorted = pts.map((p, i) => ({ ...p, ms: xs[i] })).sort((a, b2) => a.ms - b2.ms);
  return (
    <div className="chartbox">
      <svg viewBox={`0 0 ${W} ${H}`} role="img" aria-label={`${name} 추이. 규격 ${lsl ?? '—'}~${usl ?? '—'}${unit}`}>
        {lsl != null && usl != null && <rect x={l} y={y(usl)} width={W - l - r} height={Math.max(0, y(lsl) - y(usl))} fill="var(--ok)" opacity=".08" />}
        {ticks.map((v, i) => <g key={i}><line x1={l} x2={W - r} y1={y(v)} y2={y(v)} stroke="var(--line)" /><text x={l - 6} y={y(v) + 4} textAnchor="end" className="ax">{v.toFixed(0)}</text></g>)}
        {xt.map((ms, i) => <text key={i} x={i === xt.length - 1 && xt.length > 1 ? W - 4 : x(ms)} y={H - 10} textAnchor={xt.length === 1 ? 'middle' : i === 0 ? 'start' : i === xt.length - 1 ? 'end' : 'middle'} className="ax">{lbl(ms)}</text>)}
        {usl != null && <g><line x1={l} x2={W - r} y1={y(usl)} y2={y(usl)} stroke="var(--crit)" strokeDasharray="5 4" /><text x={W - r} y={y(usl) - 5} textAnchor="end" className="ax" style={{ fill: "var(--crit)" }}>상한 {usl}{unit}</text></g>}
        {lsl != null && <g><line x1={l} x2={W - r} y1={y(lsl)} y2={y(lsl)} stroke="var(--muted)" strokeDasharray="5 4" /><text x={W - r} y={y(lsl) - 5} textAnchor="end" className="ax">하한 {lsl}{unit}</text></g>}
        <polyline fill="none" stroke="var(--accent)" strokeWidth="2" points={sorted.map((p) => `${x(p.ms)},${y(p.v)}`).join(' ')} />
        {sorted.map((p, i) => <g key={i}><circle cx={x(p.ms)} cy={y(p.v)} r={out(p.v) ? 5 : 3} fill={out(p.v) ? 'var(--crit)' : 'var(--accent)'} />
          {out(p.v) && <text x={x(p.ms) + 8} y={y(p.v) - 6} className="ax" style={{ fill: "var(--crit)" }}>{p.v}{unit}</text>}</g>)}
      </svg>
    </div>
  );
}
