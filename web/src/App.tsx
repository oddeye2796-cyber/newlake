import { useEffect, useState } from 'react';
import { NavLink, Navigate, Route, Routes } from 'react-router-dom';
import { USERS, useAuth } from './auth';
import { lsGet, lsSet } from './storage';
import Home from './pages/Home';
import Ask from './pages/Ask';
import Find from './pages/Find';
import Kpi from './pages/Kpi';
import Inbox from './pages/Inbox';
import { isAdminUser } from './api';
import { AdminOnly } from './pages/admin/common';
import Overview from './pages/admin/Overview';
import Catalog from './pages/admin/Catalog';
import Ontology from './pages/admin/Ontology';
import Lineage from './pages/admin/Lineage';
import Quality from './pages/admin/Quality';
import Workbench from './pages/admin/Workbench';
import Access from './pages/admin/Access';

const ROLE_KO: Record<string, string> = { analyst: '분석가', quality_engineer: '품질 엔지니어', production_manager: '생산 관리자', admin: '플랫폼 관리자', data_steward: '데이터 스튜어드', data_engineer: '데이터 엔지니어', ontology_manager: '온톨로지 관리자' };
const I = ({ d }: { d: string }) => <svg viewBox="0 0 24 24"><path d={d} /></svg>;

function applyTheme(t: string | null) { if (t === 'light' || t === 'dark') document.documentElement.dataset.theme = t; else delete document.documentElement.dataset.theme; }

export default function App() {
  const { userId, setUserId, me, meError, badge, toastMsg } = useAuth();
  const [theme, setTheme] = useState<string | null>(() => lsGet('newlake.theme'));
  useEffect(() => { applyTheme(theme); }, [theme]);
  const toggleTheme = () => {
    const dark = document.documentElement.dataset.theme === 'dark' || (!document.documentElement.dataset.theme && matchMedia('(prefers-color-scheme: dark)').matches);
    const next = dark ? 'light' : 'dark'; lsSet('newlake.theme', next); setTheme(next);
  };
  const scope = me ? (me.site_ids === '*' ? '전사' : [me.site_ids, me.plant_ids].flat().join(' / ')) : '';

  return (
    <div className="app">
      <aside className="rail">
        <div className="brand"><b>뉴레이크</b><span>온톨로지 기반 데이터레이크</span></div>
        <nav className="nav" aria-label="화면">
          <NavLink to="/" end><I d="M3 11 12 4l9 7v9h-6v-6H9v6H3z" />홈</NavLink>
          <NavLink to="/ask"><I d="M4 5h16v11H9l-5 4z" />질문하기</NavLink>
          <NavLink to="/find"><I d="M20 20l-4.5-4.5M17 11a6 6 0 1 1-12 0 6 6 0 0 1 12 0z" />찾아보기</NavLink>
          <NavLink to="/kpi"><I d="M4 20V10M10 20V4M16 20v-7M22 20H2" />공장 현황</NavLink>
          <NavLink to="/inbox"><I d="M3 13h5l2 3h4l2-3h5M5 5h14l2 8v6H3v-6z" />요청함{badge > 0 && <span className="badge-n" aria-label={`승인할 일 ${badge}건`}>{badge}</span>}</NavLink>
        </nav>
        {isAdminUser(me) && (
          <nav className="nav" aria-label="데이터 관리 (관리자용)">
            <div className="sec">데이터 관리 (관리자용)</div>
            <NavLink to="/admin" end><I d="M3 3h7v9H3zM14 3h7v5h-7zM14 12h7v9h-7zM3 16h7v5H3z" />오늘의 레이크</NavLink>
            <NavLink to="/admin/catalog"><I d="M4 6c0-1.7 3.6-3 8-3s8 1.3 8 3-3.6 3-8 3-8-1.3-8-3zM4 6v12c0 1.7 3.6 3 8 3s8-1.3 8-3V6M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3" />데이터 카탈로그</NavLink>
            <NavLink to="/admin/ontology"><I d="M12 7.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM5 20.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM19 20.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM11 7.3 6.2 15.8M13 7.3l4.8 8.5M7.5 18h9" />온톨로지</NavLink>
            <NavLink to="/admin/lineage"><I d="M3 6h5l3 6h10M11 12l-3 6H3" />계보</NavLink>
            <NavLink to="/admin/quality"><I d="M12 3 4 6v6c0 4.5 3.4 8.3 8 9 4.6-.7 8-4.5 8-9V6zM8.5 12l2.5 2.5 4.5-5" />품질 검증</NavLink>
            <NavLink to="/admin/query"><I d="m8 8-4 4 4 4M16 8l4 4-4 4M13.5 5l-3 14" />질의 작업대</NavLink>
            <NavLink to="/admin/access"><I d="M4 10h16v11H4zM8 10V7a4 4 0 0 1 8 0v3" />권한·감사</NavLink>
          </nav>
        )}
        <div className="scope">
          <b>{me ? `${me.enterprise_id} · ${scope}` : '불러오는 중'}</b>
          {me && <span className="muted">{me.roles.map((r) => ROLE_KO[r] || r).join(', ')}</span>}
          {meError && <span style={{ color: 'var(--crit)' }}>{meError}</span>}
          <label htmlFor="roleSel">보는 사람</label>
          <select className="input" id="roleSel" value={userId} onChange={(e) => setUserId(e.target.value)}>
            {USERS.map((u) => <option key={u.id} value={u.id}>{u.label}</option>)}
          </select>
          <button className="themebtn" type="button" onClick={toggleTheme}>테마 전환</button>
        </div>
      </aside>
      {import.meta.env.VITE_DEMO === '1' && <div className="demo-banner">미리보기 · 개발 DB에서 녹화한 실제 API 응답</div>}
      <main id="main" key={userId}>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/ask" element={<Ask />} />
          <Route path="/find/*" element={<Find />} />
          <Route path="/kpi" element={<Kpi />} />
          <Route path="/inbox" element={<Inbox />} />
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
      {toastMsg && <div className="toast" role="status">{toastMsg}</div>}
    </div>
  );
}
