export function lsGet(key: string): string | null { try { return localStorage.getItem(key); } catch { return null; } }
export function lsSet(key: string, v: string) { try { localStorage.setItem(key, v); } catch { /* 저장 불가 환경 */ } }
