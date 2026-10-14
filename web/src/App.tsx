import { useEffect, useState } from 'react';
import { NavLink, Navigate, Route, Routes } from 'react-router-dom';
import { USERS, useAuth } from './auth';
import { lsGet, lsSet } from './storage';
import Home from './pages/Home';
import Ask from './pages/Ask';
import Find from './pages/Find';
import Kpi from './pages/Kpi';
import Inbox from './pages/Inbox';

const ROLE_KO: Record<string, string> = { analyst: '분석가', quality_engineer: '품질 엔지니어', production_manager: '생산 관리자' };
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
      <main id="main" key={userId}>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/ask" element={<Ask />} />
          <Route path="/find/*" element={<Find />} />
          <Route path="/kpi" element={<Kpi />} />
          <Route path="/inbox" element={<Inbox />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </main>
      {toastMsg && <div className="toast" role="status">{toastMsg}</div>}
    </div>
  );
}
