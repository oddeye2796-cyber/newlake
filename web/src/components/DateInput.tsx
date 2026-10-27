import { useEffect, useRef, useState, type ChangeEvent } from 'react';
import { CalendarDays, ChevronLeft, ChevronRight } from 'lucide-react';
import { locale, t } from '../i18n';

/* 날짜 입력. <input type="date"> 는 빈 칸의 '연도-월-일' 과 달력을 브라우저 언어로 그려서, 화면 언어를 바꿔도 그대로 남는다.
   그래서 글자 입력(YYYY-MM-DD) + 화면 언어로 그린 달력으로 바꾼다. 값은 type="date" 와 같은 'YYYY-MM-DD' 문자열이다. */
const pad = (n: number) => String(n).padStart(2, '0');
const iso = (y: number, m: number, d: number) => `${y}-${pad(m + 1)}-${pad(d)}`;
const parse = (v: string) => {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(v);
  if (!m) return null;
  const d = new Date(+m[1], +m[2] - 1, +m[3]);
  return d.getMonth() === +m[2] - 1 ? d : null;
};
/* 숫자만 쳐도 2026-10-27 꼴로 맞춘다 */
const shape = (raw: string) => {
  const s = raw.replace(/[^\d]/g, '').slice(0, 8);
  return s.length > 6 ? `${s.slice(0, 4)}-${s.slice(4, 6)}-${s.slice(6)}` : s.length > 4 ? `${s.slice(0, 4)}-${s.slice(4)}` : s;
};

interface Props { value: string; onChange: (e: ChangeEvent<HTMLInputElement>) => void; required?: boolean; className?: string; id?: string }

export function DateInput({ value, onChange, required, className = 'input', id }: Props) {
  const [open, setOpen] = useState(false);
  const box = useRef<HTMLDivElement>(null);
  const inp = useRef<HTMLInputElement>(null);
  const cur = parse(value);
  const base = cur ?? new Date();
  const [view, setView] = useState({ y: base.getFullYear(), m: base.getMonth() });

  useEffect(() => {
    if (!open) return;
    const b = cur ?? new Date();
    setView({ y: b.getFullYear(), m: b.getMonth() });
    const off = (e: MouseEvent) => { if (box.current && !box.current.contains(e.target as Node)) setOpen(false); };
    const esc = (e: KeyboardEvent) => { if (e.key === 'Escape') setOpen(false); };
    document.addEventListener('mousedown', off);
    document.addEventListener('keydown', esc);
    return () => { document.removeEventListener('mousedown', off); document.removeEventListener('keydown', esc); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  // 부모의 onChange(e.target.value) 를 그대로 쓰도록 실제 input 에 값을 넣고 input 이벤트를 낸다
  const emit = (v: string) => {
    const el = inp.current;
    if (!el) return;
    const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')?.set;
    setter?.call(el, v);
    el.dispatchEvent(new Event('input', { bubbles: true }));
  };
  const pick = (d: string) => { emit(d); setOpen(false); inp.current?.focus(); };

  const lc = locale();
  const title = new Intl.DateTimeFormat(lc, { year: 'numeric', month: 'long' }).format(new Date(view.y, view.m, 1));
  const wd = Array.from({ length: 7 }, (_, i) => new Intl.DateTimeFormat(lc, { weekday: 'narrow' }).format(new Date(2024, 0, 7 + i)));
  const first = new Date(view.y, view.m, 1).getDay();
  const days = new Date(view.y, view.m + 1, 0).getDate();
  const cells: (number | null)[] = [...Array(first).fill(null), ...Array.from({ length: days }, (_, i) => i + 1)];
  const now = new Date();
  const today = iso(now.getFullYear(), now.getMonth(), now.getDate());
  const move = (k: number) => setView((v) => { const d = new Date(v.y, v.m + k, 1); return { y: d.getFullYear(), m: d.getMonth() }; });

  return (
    <div className="dateinput" ref={box}>
      <input ref={inp} id={id} className={`${className} mono`} type="text" inputMode="numeric" autoComplete="off" maxLength={10}
        pattern="\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])" placeholder={t('연도-월-일')} required={required} value={value}
        onChange={(e) => { const s = shape(e.target.value); if (s !== e.target.value) e.target.value = s; onChange(e); }} />
      <button type="button" className="dateinput-btn" aria-label={t('달력 열기')} title={t('달력 열기')} aria-expanded={open} onClick={() => setOpen((o) => !o)}>
        <CalendarDays aria-hidden="true" />
      </button>
      {open && (
        <div className="datepop" role="dialog" aria-label={t('날짜 고르기')}>
          <div className="dp-head">
            <button type="button" className="btn icon" aria-label={t('이전 달')} onClick={() => move(-1)}><ChevronLeft aria-hidden="true" /></button>
            <b>{title}</b>
            <button type="button" className="btn icon" aria-label={t('다음 달')} onClick={() => move(1)}><ChevronRight aria-hidden="true" /></button>
          </div>
          <div className="dp-grid">
            {wd.map((w, i) => <span key={`w${i}`} className={`dp-wd${i === 0 ? ' sun' : i === 6 ? ' sat' : ''}`}>{w}</span>)}
            {cells.map((d, i) => d == null ? <span key={i} /> : (() => {
              const v = iso(view.y, view.m, d);
              return <button key={i} type="button" className={`dp-day${v === value ? ' on' : ''}${v === today ? ' today' : ''}`} onClick={() => pick(v)}>{d}</button>;
            })())}
          </div>
          <div className="dp-foot">
            <button type="button" className="linkbtn" onClick={() => pick('')}>{t('지우기')}</button>
            <button type="button" className="linkbtn" onClick={() => pick(today)}>{t('오늘')}</button>
          </div>
        </div>
      )}
    </div>
  );
}
