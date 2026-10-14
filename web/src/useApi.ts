import { useCallback, useEffect, useRef, useState } from 'react';
import { get } from './api';

/** GET 한 번 호출. path 가 null 이면 호출하지 않는다. */
export function useApi<T>(path: string | null) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(path !== null);
  const seq = useRef(0);
  const load = useCallback((): Promise<void> => {
    if (path === null) { setLoading(false); return Promise.resolve(); }
    const my = ++seq.current;
    setLoading(true);
    return get<T>(path).then((d) => { if (my === seq.current) { setData(d); setError(null); } })
      .catch((e: Error) => { if (my === seq.current) { setError(e.message); setData(null); } })
      .finally(() => { if (my === seq.current) setLoading(false); });
  }, [path]);
  useEffect(() => { load(); return () => { seq.current++; }; }, [load]);
  return { data, error, loading, reload: load };
}
