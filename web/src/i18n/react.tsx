import { createContext, useCallback, useContext, useState, type ReactNode } from 'react';
import { getLang, setLang as setGlobal, type Lang } from '.';

const LangCtx = createContext<{ lang: Lang; setLang: (l: Lang) => void }>({ lang: 'ko', setLang: () => {} });
export const useLang = () => useContext(LangCtx);

/** 언어를 바꾸면 아래 트리를 통째로 다시 그린다 (모듈 수준 t() 와 서식 함수까지 새 언어로). */
export function LangProvider({ children }: { children: ReactNode }) {
  const [lang, set] = useState<Lang>(getLang);
  const setLang = useCallback((l: Lang) => { setGlobal(l); set(l); }, []);
  return <LangCtx.Provider value={{ lang, setLang }}><div key={lang} style={{ display: 'contents' }}>{children}</div></LangCtx.Provider>;
}
