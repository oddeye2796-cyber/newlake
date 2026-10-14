import { useEffect, useState, type FormEvent } from 'react';
import { Link, NavLink, Navigate, Route, Routes, useLocation, useNavigate } from 'react-router-dom';
import {
  Bell, Languages, ChevronRight, CircleCheck, Database, Factory, GitBranch, House, Inbox, KeyRound, Layers, LayoutDashboard,
  MapPin, MessageSquareText, Moon, Network, Search, ShieldCheck, Sun, TerminalSquare, type LucideIcon,
} from 'lucide-react';
import { USERS, useAuth } from './auth';
import { lsGet, lsSet } from './storage';
import { LANGS, t, tk } from './i18n';
import { useLang } from './i18n/react';
import Home from './pages/Home';
import Ask from './pages/Ask';
import Find from './pages/Find';
import Kpi from './pages/Kpi';
import InboxPage from './pages/Inbox';
import { isAdminUser } from './api';
import { AdminOnly } from './pages/admin/common';
import Overview from './pages/admin/Overview';
import Catalog from './pages/admin/Catalog';
import Ontology from './pages/admin/Ontology';
import Lineage from './pages/admin/Lineage';
import Quality from './pages/admin/Quality';
import Workbench from './pages/admin/Workbench';
import Access from './pages/admin/Access';

const ROLE_KO: Record<string, string> = { analyst: tk('분석가'), quality_engineer: tk('품질 엔지니어'), production_manager: tk('생산 관리자'), admin: tk('플랫폼 관리자'), data_steward: tk('데이터 스튜어드'), data_engineer: tk('데이터 엔지니어'), ontology_manager: tk('온톨로지 관리자') };

type NavItem = { to: string; label: string; sub: string; icon: LucideIcon; end?: boolean };
const WORK: NavItem[] = [
  { to: '/', label: tk('홈'), sub: tk('오늘 확인할 일'), icon: House, end: true },
  { to: '/ask', label: tk('질문하기'), sub: tk('자연어로 묻고 근거 보기'), icon: MessageSquareText },
  { to: '/find', label: tk('찾아보기'), sub: tk('로트·설비·주문 한 화면'), icon: Search },
  { to: '/kpi', label: tk('공장 현황'), sub: tk('양품률·PPM·납기·재공'), icon: Factory },
  { to: '/inbox', label: tk('요청함'), sub: tk('승인·반려'), icon: Inbox },
];
const ADMIN: NavItem[] = [
  { to: '/admin', label: tk('오늘의 레이크'), sub: tk('존·파이프라인 상태'), icon: LayoutDashboard, end: true },
  { to: '/admin/catalog', label: tk('데이터 카탈로그'), sub: tk('데이터셋·스키마·매핑'), icon: Database },
  { to: '/admin/ontology', label: tk('온톨로지'), sub: tk('KS X 9101 클래스·관계'), icon: Network },
  { to: '/admin/lineage', label: tk('계보'), sub: tk('원천 → 활용 흐름'), icon: GitBranch },
  { to: '/admin/quality', label: tk('품질 검증'), sub: tk('SHACL 규칙·위반'), icon: ShieldCheck },
  { to: '/admin/query', label: tk('질의 작업대'), sub: tk('SQL 실행'), icon: TerminalSquare },
  { to: '/admin/access', label: tk('권한·감사'), sub: tk('이용 신청·역할·기록'), icon: KeyRound },
];

function titleOf(path: string): [string, string] {
  const all = [...ADMIN, ...WORK].sort((a, b) => b.to.length - a.to.length);
  const hit = all.find((n) => (n.end ? path === n.to : path === n.to || path.startsWith(n.to + '/')));
  return [ADMIN.includes(hit as NavItem) ? t('데이터 관리') : t('업무'), hit ? t(hit.label) : t('홈')];
}

function applyTheme(t: string | null) { document.documentElement.dataset.theme = t === 'light' ? 'light' : 'dark'; }

function NavGroup({ title, items, badge }: { title: string; items: NavItem[]; badge?: number }) {
  return (
    <nav className="nav" aria-label={title}>
      <div className="sec">{title}</div>
      {items.map((n) => {
        const Icon = n.icon;
        return (
          <NavLink key={n.to} to={n.to} end={n.end}>
            <Icon aria-hidden="true" />
            <span className="nl"><span>{t(n.label)}</span><small>{t(n.sub)}</small></span>
            {n.to === '/inbox' && badge != null && badge > 0 && <span className="badge-n" aria-label={t('승인할 일 {n}건', { n: badge })}>{badge}</span>}
          </NavLink>
        );
      })}
    </nav>
  );
}

export default function App() {
  const { userId, setUserId, me, meError, badge, toastMsg } = useAuth();
  const { lang, setLang } = useLang();
  const [theme, setTheme] = useState<string | null>(() => lsGet('newlake.theme'));
  const [q, setQ] = useState('');
  const loc = useLocation();
  const navTo = useNavigate();
  useEffect(() => { applyTheme(theme); }, [theme]);
  const toggleTheme = () => { const next = theme === 'light' ? 'dark' : 'light'; lsSet('newlake.theme', next); setTheme(next); };
  const scope = me ? (me.site_ids === '*' ? t('전사') : [me.site_ids, me.plant_ids].flat().join(' / ')) : '';
  const [group, title] = titleOf(loc.pathname);
  const user = USERS.find((u) => u.id === userId);
  const search = (e: FormEvent) => { e.preventDefault(); const v = q.trim(); if (v) { navTo(`/find?q=${encodeURIComponent(v)}`); setQ(''); } };

  return (
    <div className="app">
      <aside className="rail">
        <div className="brand">
          <span className="logo" aria-hidden="true"><Layers /></span>
          <span className="bt"><b>{t('뉴레이크')}</b><span>{t('온톨로지 데이터레이크')}</span></span>
        </div>
        <div className="tenant">
          <span className="tl1"><span>{t('연결된 범위')}</span><span className="ok"><CircleCheck aria-hidden="true" />{t('정상')}</span></span>
          <span className="tl2">{me ? `${me.enterprise_id} · ${scope}` : t('불러오는 중')}</span>
        </div>
        <NavGroup title={t('업무')} items={WORK} badge={badge} />
        {isAdminUser(me) && <NavGroup title={t('데이터 관리')} items={ADMIN} />}
        <div className="scope">
          <div className="who">
            <span className="avatar" aria-hidden="true">{user?.name.slice(0, 1) ?? '?'}</span>
            <span className="wn"><b>{me?.display_name ?? user?.name ?? ''}</b><small>{me ? me.roles.map((r) => (ROLE_KO[r] ? t(ROLE_KO[r]) : r)).join(', ') : ''}</small></span>
          </div>
          {meError && <span className="err">{meError}</span>}
          <label htmlFor="roleSel">{t('보는 사람 바꾸기')}</label>
          <select className="input" id="roleSel" value={userId} onChange={(e) => setUserId(e.target.value)}>
            {USERS.map((u) => <option key={u.id} value={u.id}>{u.name} · {t(u.desc)}</option>)}
          </select>
        </div>
      </aside>
      <div className="main-col">
        <header className="topbar">
          <div className="crumb"><span>{group}</span><ChevronRight aria-hidden="true" /><b>{title}</b></div>
          <form className="tsearch" onSubmit={search} role="search">
            <Search aria-hidden="true" />
            <input value={q} onChange={(e) => setQ(e.target.value)} placeholder={t('로트·설비·주문 번호나 이름으로 찾기 (예: 0731, 오븐, 한빛)')} aria-label={t('전체 검색')} autoComplete="off" />
          </form>
          <div className="tacts">
            <span className="scopechip"><MapPin aria-hidden="true" />{me ? scope : '—'}</span>
            <div className="langsw" role="group" aria-label={t('언어')}>
              <Languages aria-hidden="true" />
              {LANGS.map((l) => (
                <button key={l.id} type="button" className={l.id === lang ? 'on' : ''} aria-pressed={l.id === lang} title={l.label} lang={l.id} onClick={() => setLang(l.id)}>{l.short}</button>
              ))}
            </div>
            <button className="iconbtn" type="button" onClick={toggleTheme} aria-label={theme === 'light' ? t('다크 모드로') : t('라이트 모드로')} title={t('테마 전환')}>
              {theme === 'light' ? <Moon aria-hidden="true" /> : <Sun aria-hidden="true" />}
            </button>
            <Link className="iconbtn" to="/inbox" aria-label={t('요청함')}><Bell aria-hidden="true" />{badge > 0 && <i className="dot" />}</Link>
          </div>
        </header>
        {import.meta.env.VITE_DEMO === '1' && <div className="demo-banner">{t('미리보기 · 개발 DB에서 녹화한 실제 API 응답으로 동작해요')}</div>}
      <main id="main" key={userId}>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/ask" element={<Ask />} />
          <Route path="/find/*" element={<Find />} />
          <Route path="/kpi" element={<Kpi />} />
          <Route path="/inbox" element={<InboxPage />} />
          <Route path="/admin" element={<AdminOnly><Overview /></AdminOnly>} />
          <Route path="/admin/catalog/:id?" element={<AdminOnly><Catalog /></AdminOnly>} />
          <Route path="/admin/ontology/:name?" element={<AdminOnly><Ontology /></AdminOnly>} />
          <Route path="/admin/lineage" element={<AdminOnly><Lineage /></AdminOnly>} />
          <Route path="/admin/quality" element={<AdminOnly><Quality /></AdminOnly>} />
          <Route path="/admin/query" element={<AdminOnly><Workbench /></AdminOnly>} />
          <Route path="/admin/access" element={<AdminOnly><Access /></AdminOnly>} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </main>
      </div>
      {toastMsg && <div className="toast" role="status">{toastMsg}</div>}
    </div>
  );
}
