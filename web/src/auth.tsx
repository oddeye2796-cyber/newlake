import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { get, setApiUser, type Me } from './api';
import { lsGet, lsSet } from './storage';

export const USERS = [
  { id: 'u-jung', name: '정품질', label: '정품질 · 분석가 (승인 권한 없음)' },
  { id: 'u-kim', name: '김품질', label: '김품질 · 품질 책임자 (승인자)' },
  { id: 'u-lee', name: '이생산', label: '이생산 · 생산 관리자' },
];
const KEY = 'newlake.user';

interface Ctx { userId: string; setUserId: (id: string) => void; me: Me | null; meError: string | null; badge: number; refreshBadge: () => void; toast: (m: string) => void; toastMsg: string }
const AuthCtx = createContext<Ctx>(null as unknown as Ctx);
export const useAuth = () => useContext(AuthCtx);

function initial(): string {
  const v = lsGet(KEY);
  const id = USERS.some((u) => u.id === v) ? (v as string) : 'u-jung';
  setApiUser(id); // 첫 렌더의 자식 요청보다 먼저 헤더 사용자를 맞춘다
  return id;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [userId, setId] = useState(initial);
  const [me, setMe] = useState<Me | null>(null);
  const [meError, setMeError] = useState<string | null>(null);
  const [badge, setBadge] = useState(0);
  const [toastMsg, setToastMsg] = useState('');

  const setUserId = useCallback((id: string) => { setApiUser(id); lsSet(KEY, id); setMe(null); setId(id); }, []);
  const refreshBadge = useCallback(() => {
    get<{ status: string; can_decide: boolean }[]>('/api/inbox').then((r) => setBadge(r.filter((x) => x.status === 'PROPOSED' && x.can_decide).length)).catch(() => setBadge(0));
  }, []);
  const toast = useCallback((m: string) => { setToastMsg(m); window.setTimeout(() => setToastMsg(''), 3500); }, []);

  useEffect(() => {
    setMeError(null);
    get<Me>('/api/me').then(setMe).catch((e: Error) => setMeError(e.message));
    refreshBadge();
  }, [userId, refreshBadge]);

  const value = useMemo(() => ({ userId, setUserId, me, meError, badge, refreshBadge, toast, toastMsg }), [userId, setUserId, me, meError, badge, refreshBadge, toast, toastMsg]);
  return <AuthCtx.Provider value={value}>{children}</AuthCtx.Provider>;
}
