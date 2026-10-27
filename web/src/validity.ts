import { t } from './i18n';

/* 입력 검사 말풍선(필수·형식·길이·범위)은 브라우저 언어로 나와서 화면 언어와 어긋난다. 화면 언어 문장으로 바꿔 끼운다. */
type Field = HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement;

function message(el: Field): string {
  const v = el.validity;
  if (v.valueMissing) return el instanceof HTMLSelectElement ? t('목록에서 하나를 고르세요.') : t('이 칸을 채워 주세요.');
  if (v.patternMismatch) return el.closest('.dateinput') ? t('날짜는 YYYY-MM-DD 형식으로 입력하세요.') : t('형식이 맞지 않아요.');
  if (v.tooShort) return t('{n}자 이상 입력하세요. (지금 {k}자)', { n: (el as HTMLInputElement).minLength, k: el.value.length });
  if (v.tooLong) return t('{n}자 이하로 입력하세요.', { n: (el as HTMLInputElement).maxLength });
  if (v.rangeUnderflow) return t('{n} 이상이어야 해요.', { n: (el as HTMLInputElement).min });
  if (v.rangeOverflow) return t('{n} 이하여야 해요.', { n: (el as HTMLInputElement).max });
  if (v.stepMismatch) return t('입력할 수 있는 단위가 아니에요.');
  if (v.badInput || v.typeMismatch) return t('값이 올바르지 않아요.');
  return '';
}

export function installValidityMessages() {
  if (typeof document === 'undefined') return;
  document.addEventListener('invalid', (e) => {
    const el = e.target as Field;
    if (!el || typeof el.setCustomValidity !== 'function') return;
    el.setCustomValidity('');
    if (!el.validity.valid) el.setCustomValidity(message(el));
  }, true);
  const clear = (e: Event) => { const el = e.target as Field; if (el && typeof el.setCustomValidity === 'function') el.setCustomValidity(''); };
  document.addEventListener('input', clear, true);
  document.addEventListener('change', clear, true);
}
