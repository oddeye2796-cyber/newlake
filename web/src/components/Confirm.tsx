import { useEffect, useRef, useState } from 'react';
import { t } from '../i18n';

/* window.confirm 대신 쓰는 확인 창. 브라우저 확인 창은 버튼(확인·취소)과 제목을 브라우저 언어로 그려서 화면 언어와 어긋난다.
   사용: if (!(await confirmDialog('지울까요?'))) return;   화면 어딘가에 <ConfirmHost /> 가 하나 있어야 한다. */
type Req = { msg: string; resolve: (ok: boolean) => void };
let push: ((r: Req) => void) | null = null;

export function confirmDialog(msg: string): Promise<boolean> {
  return new Promise((resolve) => (push ? push({ msg, resolve }) : resolve(window.confirm(msg))));
}

export function ConfirmHost() {
  const [req, setReq] = useState<Req | null>(null);
  const ok = useRef<HTMLButtonElement>(null);
  useEffect(() => { push = setReq; return () => { push = null; }; }, []);
  useEffect(() => {
    if (!req) return;
    ok.current?.focus();
    const esc = (e: KeyboardEvent) => { if (e.key === 'Escape') done(false); };
    document.addEventListener('keydown', esc);
    return () => document.removeEventListener('keydown', esc);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [req]);
  const done = (v: boolean) => { req?.resolve(v); setReq(null); };
  if (!req) return null;
  return (
    <div className="dlg-back" onMouseDown={(e) => { if (e.target === e.currentTarget) done(false); }}>
      <div className="dlg" role="alertdialog" aria-modal="true" aria-labelledby="dlg-msg">
        <p id="dlg-msg">{req.msg}</p>
        <div className="acts">
          <button type="button" className="btn" onClick={() => done(false)}>{t('취소')}</button>
          <button type="button" className="btn primary" ref={ok} onClick={() => done(true)}>{t('확인')}</button>
        </div>
      </div>
    </div>
  );
}
