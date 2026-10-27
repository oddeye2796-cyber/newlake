/* 용어집: 현장마다 다른 컬럼명·확장 속성명처럼 사전에 없는 한국어 라벨을 단어 단위로 풀어 번역하는 마지막 보루.
   tl() 이 사전에서 못 찾았을 때만 쓰며, 사전에 있는 문장은 사전이 우선한다. [한국어, 영어, 일본어] */
const G: [string, string, string][] = [
  ['구분', 'category', '区分'], ['미입고', 'outstanding', '未入庫'], ['입고', 'receipt', '入庫'], ['출고', 'issue', '出庫'],
  ['수량', 'quantity', '数量'], ['업체', 'vendor', '取引先'], ['거래처', 'vendor', '取引先'], ['공급사', 'supplier', '仕入先'], ['고객사', 'customer', '顧客'],
  ['발주', 'PO', '発注'], ['기준', 'basis', '基準'], ['폭', 'width', '幅'], ['두께', 'thickness', '厚さ'], ['길이', 'length', '長さ'], ['높이', 'height', '高さ'],
  ['중량', 'weight', '重量'], ['무게', 'weight', '重さ'], ['달성율', 'achievement rate', '達成率'], ['달성률', 'achievement rate', '達成率'],
  ['시간가동율', 'time availability', '時間稼働率'], ['시간가동률', 'time availability', '時間稼働率'], ['가동율', 'availability', '稼働率'], ['가동률', 'availability', '稼働率'],
  ['성능가동율', 'performance rate', '性能稼働率'], ['양품율', 'yield', '良品率'], ['양품률', 'yield', '良品率'], ['불량율', 'defect rate', '不良率'], ['불량률', 'defect rate', '不良率'],
  ['캐비티', 'cavity', 'キャビティ'], ['세부공정', 'detailed process', '詳細工程'], ['세부', 'detail', '詳細'], ['공정', 'process', '工程'], ['본부', 'division', '本部'],
  ['사업소', 'business site', '事業所'], ['사업장', 'plant', '事業場'], ['공장', 'plant', '工場'], ['라인', 'line', 'ライン'], ['설비', 'equipment', '設備'], ['장비', 'equipment', '装置'],
  ['외관', 'appearance', '外観'], ['검사자', 'inspector', '検査者'], ['검사', 'inspection', '検査'], ['검수', 'acceptance', '検収'], ['담당자', 'person in charge', '担当者'],
  ['담당', 'in charge', '担当'], ['작업조', 'work shift', '作業班'], ['작업자', 'operator', '作業者'], ['작업', 'work', '作業'], ['납품', 'delivery', '納品'], ['납기', 'due date', '納期'],
  ['장소', 'location', '場所'], ['위치', 'location', '位置'], ['품번', 'part number', '品番'], ['품명', 'part name', '品名'], ['품목', 'item', '品目'], ['품질', 'quality', '品質'],
  ['자재', 'material', '資材'], ['원자재', 'raw material', '原材料'], ['재질', 'material', '材質'], ['제품', 'product', '製品'], ['모델', 'model', 'モデル'], ['규격', 'spec', '規格'],
  ['사양', 'specification', '仕様'], ['단위', 'unit', '単位'], ['단가', 'unit price', '単価'], ['금액', 'amount', '金額'], ['가격', 'price', '価格'], ['비용', 'cost', 'コスト'],
  ['생산', 'production', '生産'], ['실적', 'result', '実績'], ['계획', 'plan', '計画'], ['지시', 'order', '指示'], ['목표', 'target', '目標'], ['진행상태', 'status', '進行状態'],
  ['상태', 'status', '状態'], ['진행', 'progress', '進行'], ['완료', 'completed', '完了'], ['시작', 'start', '開始'], ['종료', 'end', '終了'], ['일시', 'date/time', '日時'],
  ['일자', 'date', '日付'], ['날짜', 'date', '日付'], ['시간', 'time', '時間'], ['요일', 'weekday', '曜日'], ['년', 'year', '年'], ['월', 'month', '月'], ['일', 'day', '日'],
  ['주간', 'day shift', '昼勤'], ['야간', 'night shift', '夜勤'], ['번호', 'number', '番号'], ['코드', 'code', 'コード'], ['명', 'name', '名'], ['이름', 'name', '名前'],
  ['비고', 'remarks', '備考'], ['사유', 'reason', '理由'], ['원인', 'cause', '原因'], ['조치', 'action', '措置'], ['불량', 'defect', '不良'], ['양품', 'good', '良品'],
  ['합격', 'pass', '合格'], ['불합격', 'fail', '不合格'], ['판정', 'judgment', '判定'], ['결과', 'result', '結果'], ['값', 'value', '値'], ['측정', 'measurement', '測定'],
  ['온도', 'temperature', '温度'], ['압력', 'pressure', '圧力'], ['속도', 'speed', '速度'], ['전류', 'current', '電流'], ['전압', 'voltage', '電圧'], ['습도', 'humidity', '湿度'],
  ['재고', 'stock', '在庫'], ['안전재고', 'safety stock', '安全在庫'], ['창고', 'warehouse', '倉庫'], ['로트', 'lot', 'ロット'], ['배치', 'batch', 'バッチ'], ['공급', 'supply', '供給'],
  ['주문', 'order', '注文'], ['수주', 'sales order', '受注'], ['출하', 'shipment', '出荷'], ['반품', 'return', '返品'], ['배송', 'shipping', '配送'], ['운송', 'transport', '運送'],
  ['총', 'total', '総'], ['합계', 'total', '合計'], ['평균', 'average', '平均'], ['최대', 'max', '最大'], ['최소', 'min', '最小'], ['누적', 'cumulative', '累計'], ['일평균', 'daily average', '日平均'],
  ['비율', 'ratio', '比率'], ['율', 'rate', '率'], ['률', 'rate', '率'], ['횟수', 'count', '回数'], ['건수', 'count', '件数'], ['개수', 'count', '個数'], ['수', 'count', '数'],
  ['부서', 'department', '部署'], ['팀', 'team', 'チーム'], ['직급', 'rank', '役職'], ['직원', 'employee', '従業員'], ['사원', 'employee', '社員'], ['관리', 'management', '管理'],
  ['승인', 'approval', '承認'], ['요청', 'request', '依頼'], ['등록', 'registration', '登録'], ['수정', 'modified', '修正'], ['변경', 'change', '変更'], ['생성', 'created', '作成'],
  ['금형', 'mold', '金型'], ['공구', 'tool', '工具'], ['설계', 'design', '設計'], ['도면', 'drawing', '図面'], ['버전', 'version', 'バージョン'], ['표준', 'standard', '標準'],
  ['외주', 'outsourcing', '外注'], ['협력사', 'partner', '協力会社'], ['입력', 'input', '入力'], ['출력', 'output', '出力'], ['투입', 'input', '投入'], ['사용', 'usage', '使用'],
  ['잔량', 'remaining quantity', '残量'], ['잔여', 'remaining', '残'], ['가입고', 'provisional receipt', '仮入庫'], ['예정', 'scheduled', '予定'], ['요청일', 'request date', '依頼日'],
  ['첫', 'first', '初回'], ['최종', 'final', '最終'], ['현재', 'current', '現在'], ['이전', 'previous', '前回'], ['전체', 'all', '全体'], ['기타', 'other', 'その他'],
  ['내용', 'details', '内容'], ['설명', 'description', '説明'], ['종류', 'type', '種類'], ['유형', 'type', 'タイプ'], ['등급', 'grade', '等級'], ['레벨', 'level', 'レベル'],
  ['그룹', 'group', 'グループ'], ['조', 'shift', '班'], ['기', 'unit', '機'], ['호기', 'unit no.', '号機'], ['차', 'th', '回目'], ['회', 'times', '回'],
  ['원', 'KRW', 'ウォン'], ['개', 'pcs', '個'], ['대', 'units', '台'], ['장', 'sheets', '枚'], ['매', 'sheets', '枚'],
  ['비가동', 'downtime', '非稼働'], ['가동시간', 'run time', '稼働時間'], ['유무', 'presence', '有無'], ['여부', 'flag', '要否'], ['설정', 'setting', '設定'],
  ['교대조', 'shift', '交代班'], ['교대', 'shift', '交代'], ['파트', 'part', 'パート'], ['샘플', 'sample', 'サンプル'], ['사이클타임', 'cycle time', 'サイクルタイム'],
  ['종합효율', 'overall efficiency', '総合効率'], ['효율', 'efficiency', '効率'], ['분당', 'per minute', '毎分'], ['분', 'min', '分'], ['생산량', 'output', '生産量'],
  ['편차', 'deviation', '偏差'], ['순번', 'sequence no.', '順番'], ['순', 'net', '純'], ['수출', 'export', '輸出'], ['배정', 'assignment', '割当'], ['메모', 'memo', 'メモ'],
  ['솔더볼', 'solder ball', 'ソルダーボール'], ['트레이', 'tray', 'トレー'], ['종료시간', 'end time', '終了時間'], ['시작시간', 'start time', '開始時間'],
  ['투입유무', 'input presence', '投入有無'], ['비가동시간', 'downtime', '非稼働時間'],
];

const BY_KO = new Map(G.map((g) => [g[0], g] as const));
const MAXLEN = Math.max(...G.map((g) => g[0].length));
const HANGUL = /[가-힣]/;

/** 한글 덩어리 하나를 용어집으로 끝까지 풀 수 있으면 [단어…] 를, 하나라도 못 풀면 null 을 돌려준다. */
function segment(run: string, i: 1 | 2): string[] | null {
  const out: string[] = [];
  for (let p = 0; p < run.length;) {
    let hit: string | null = null;
    for (let n = Math.min(MAXLEN, run.length - p); n > 0; n--) if (BY_KO.has(run.slice(p, p + n))) { hit = run.slice(p, p + n); break; }
    if (!hit) return null;
    out.push(BY_KO.get(hit)![i]);
    p += hit.length;
  }
  return out;
}

/** 사전에 없는 한국어 라벨을 단어 단위로 번역한다. 용어집으로 끝까지 풀리는 한글 덩어리만 바꾸고, 못 푸는 덩어리는 원문 그대로 둔다. */
export function glossTranslate(ko: string, lang: 'en' | 'ja'): string {
  if (!HANGUL.test(ko)) return ko;
  const i = lang === 'en' ? 1 : 2;
  const out = ko.replace(/[가-힣]+/g, (run) => { const w = segment(run, i); return w ? w.join(lang === 'en' ? ' ' : '') : run; });
  if (lang === 'ja') return out.replace(/(?<=[぀-ヿ一-鿿]) (?=[぀-ヿ一-鿿])/g, '');
  if (lang !== 'en') return out;
  const t = out.replace(/([A-Za-z])\(/g, '$1 (').replace(/\s+/g, ' ').trim();
  return t.charAt(0).toUpperCase() + t.slice(1);
}
