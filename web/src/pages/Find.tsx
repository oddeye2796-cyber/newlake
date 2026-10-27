import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { get, type Kind, type SearchHit } from '../api';
import { KIND_KO, LOT_STATE } from '../format';
import { t, tl } from '../i18n';
import { getRecent } from '../recent';
import { EquipmentPage, LotPage, OrderPage, SimplePage } from './entities';

// 빈 검색어는 API 가 허용하지 않아서, 전체 보기는 번호 접두어별로 나눠 조회해 합친다.
const BROWSE = ['LOT-', 'EQ-', 'SO-', 'ITM-', 'C-'];

export default function Find() {
  const FILTERS: [string, Kind | null][] = [[t('전체'), null], [t('로트'), 'lot'], [t('설비'), 'equipment'], [t('주문'), 'order'], [t('품목'), 'item'], [t('고객'), 'customer']];
  const splat = useParams()['*'] || '';
  const [kind, id] = splat.split('/').map(decodeURIComponent);
  const nav = useNavigate();
  const [sp] = useSearchParams();
  const [fq, setFq] = useState(() => sp.get('q') ?? '');
  // 상단 검색창에서 넘어오면 검색어를 이어받는다
  useEffect(() => { const v = sp.get('q'); if (v != null) setFq(v); }, [sp]);
  const [ft, setFt] = useState<Kind | null>(null);
  const [hits, setHits] = useState<SearchHit[] | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    const q = fq.trim();
    let alive = true;
    const h = window.setTimeout(() => {
      const qs = q ? [q] : BROWSE;
      Promise.all(qs.map((x) => get<{ results: SearchHit[] }>(`/api/search?q=${encodeURIComponent(x)}`)))
        .then((rs) => {
          if (!alive) return;
          const seen = new Set<string>(); const all: SearchHit[] = [];
          rs.flatMap((r) => r.results).forEach((x) => { const k = x.kind + x.id; if (!seen.has(k)) { seen.add(k); all.push(x); } });
          setHits(all); setErr(null);
        }).catch((e: Error) => { if (alive) { setErr(e.message); setHits(null); } });
    }, q ? 250 : 0);
    return () => { alive = false; window.clearTimeout(h); };
  }, [fq]);

  const shown = (hits || []).filter((x) => !ft || x.kind === ft);
  const recent = getRecent();

  return (
    <>
      <div className="head"><div><h1>{t('찾아보기')}</h1>
        <p className="lede">{t('로트, 설비, 주문, 품목, 고객 번호나 이름으로 찾으면 관련된 것까지 한 화면에 모아 보여 드려요.')}</p></div></div>
      <div className="toolbar">
        <input className="input grow" type="search" value={fq} onChange={(e) => setFq(e.target.value)} placeholder={t('번호나 이름 입력 (예: 0731, 오븐, 한빛)')} autoComplete="off" aria-label={t('검색어')} />
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          {FILTERS.map(([label, k]) => <button key={label} className="chip" type="button" aria-pressed={ft === k} onClick={() => setFt(k)}>{label}</button>)}
        </div>
      </div>
      <div className="findwrap">
        <section className="panel results" aria-label={t('검색 결과')}>
          {err && <p className="small" style={{ color: 'var(--crit)' }}>{err}</p>}
          {!err && hits === null && <p className="muted small">{t('찾는 중이에요…')}</p>}
          {hits && shown.length === 0 && <p className="muted small">{t('찾는 항목이 없어요. 번호 일부만 넣어 보세요.')}</p>}
          {shown.map((x) => (
            <button key={x.kind + x.id} type="button" className="ritem" aria-current={x.kind === kind && x.id === id} onClick={() => nav(`/find/${x.kind}/${encodeURIComponent(x.id)}`)}>
              <span><b>{x.id}</b><span className="small muted"> {KIND_KO[x.kind]}</span><br /><span className="small">{tl(x.label)}</span></span>
              {x.sub && <span className="small muted">{(x.kind === 'lot' && LOT_STATE[x.sub]) || tl(x.sub)}</span>}
            </button>
          ))}
        </section>
        <section>
          {!kind || !id ? (
            <div className="panel muted">
              {t('왼쪽에서 항목을 고르세요.')}
              {recent.length > 0 && <div style={{ marginTop: 10 }}><span className="small">{t('최근 본 항목:')} </span>{recent.map((r) => <Link key={r.kind + r.id} className="lchip" to={`/find/${r.kind}/${r.id}`}>{r.id}</Link>)}</div>}
            </div>
          ) : kind === 'lot' ? <LotPage key={id} id={id} />
            : kind === 'equipment' ? <EquipmentPage key={id} id={id} />
            : kind === 'order' ? <OrderPage key={id} id={id} />
            : <SimplePage key={kind + id} kind={kind as Kind} id={id} />}
        </section>
      </div>
    </>
  );
}
