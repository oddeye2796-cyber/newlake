import { lsGet, lsSet } from './storage';
import type { Kind } from './api';

export interface RecentItem { kind: Kind; id: string; label: string }
const KEY = 'newlake.recent';
export function getRecent(): RecentItem[] {
  try { const v = JSON.parse(lsGet(KEY) || '[]'); return Array.isArray(v) ? v : []; } catch { return []; }
}
export function pushRecent(it: RecentItem) {
  lsSet(KEY, JSON.stringify([it, ...getRecent().filter((x) => !(x.kind === it.kind && x.id === it.id))].slice(0, 6)));
}
