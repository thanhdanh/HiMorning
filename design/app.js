'use strict';

const $ = (selector) => document.querySelector(selector);
const clone = (value) => JSON.parse(JSON.stringify(value));
const escapeHTML = (value) => String(value).replace(/[&<>"']/g, (character) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[character]));
const icon = (name, extra = '') => `<svg class="icon ${extra}" aria-hidden="true"><use href="#i-${name}"/></svg>`;
const modes = {
  gentle: { name: 'Nhẹ nhàng', icon: 'leaf', snoozes: 2, description: 'Thức dậy thoải mái. Có thể báo lại 2 lần, mỗi lần 5 phút.' },
  balanced: { name: 'Cân bằng', icon: 'sun', snoozes: 1, description: 'Một nhiệm vụ nhỏ để tỉnh táo. Báo lại 1 lần, sau 5 phút.' },
  focused: { name: 'Quyết tâm', icon: 'bolt', snoozes: 0, description: 'Giữ lời hẹn với mình. Không báo lại; nhiệm vụ do bạn chọn.' }
};
const sounds = [
  {id:'sunrise', name:'Nắng sớm', detail:'Trong trẻo · mở đầu mềm', family:'Êm dịu', icon:'rise', wave:'sine', notes:[523.25,659.25,783.99,659.25]},
  {id:'warm', name:'Chuông ấm', detail:'Trầm ấm · ngân nhẹ', family:'Êm dịu', icon:'music', wave:'sine', notes:[261.63,329.63,392,329.63]},
  {id:'morning', name:'Ban mai', detail:'Tươi vui · nhịp vừa', family:'Tươi sáng', icon:'sun', wave:'triangle', notes:[392,523.25,659.25,783.99,659.25]},
  {id:'clear', name:'Trong veo', detail:'Thanh thoát · đều đặn', family:'Tươi sáng', icon:'music', wave:'sine', notes:[659.25,783.99,659.25,523.25]},
  {id:'rhythm', name:'Nhịp sáng', detail:'Rõ nhịp · dễ nhận biết', family:'Rõ ràng', icon:'bolt', wave:'triangle', notes:[440,440,587.33,440,440,587.33]},
  {id:'steady', name:'Rõ nhịp', detail:'Chắc nhịp · âm đầy', family:'Rõ ràng', icon:'alarm', wave:'triangle', notes:[349.23,523.25,349.23,523.25,349.23]}
];
const initialAlarms = [
  {id:'work', label:'Đi làm', hour:6, minute:30, days:[1,2,3,4,5], mode:'balanced', mission:'pushup', target:3, sound:'sunrise', enabled:true, guidance:true, missionCustomized:false},
  {id:'weekend', label:'Cuối tuần', hour:7, minute:30, days:[6,0], mode:'gentle', mission:'none', target:3, sound:'warm', enabled:true, missionCustomized:false}
];
const screenNames = {home:'Báo thức', editor:'Đặt báo thức', sounds:'Âm thanh', missions:'Nhiệm vụ', ringing:'Thức dậy', camera:'Thực hiện', complete:'Hoàn thành', progress:'Tiến độ'};
let state = {
  view:'screens', screen:'home', theme:'light', alarms:clone(initialAlarms), activeID:'work', draft:null,
  volume:35, playing:null, session:null, aiConsent:false, verificationStatus:'idle', reps:0, lowConfidence:false, formIssue:false, rehearsal:false, completed:new Set(),
  formError:'', toastTimer:null, audioTimer:null, module:'ui'
};
let audioContext, previewGain, audioNodes = [], audioToken = 0, dialogLastFocus;
const currentAlarm = () => state.alarms.find((alarm) => alarm.id === state.activeID) || state.alarms[0];
const draftAlarm = () => state.draft || currentAlarm();
const soundName = (id) => sounds.find((sound) => sound.id === id)?.name || 'Nắng sớm';
const timeText = (alarm) => `${String(alarm.hour).padStart(2,'0')}:${String(alarm.minute).padStart(2,'0')}`;
const missionName = (alarm) => alarm.mission === 'pushup' ? `Chống đẩy ${alarm.target} lần` : alarm.mission === 'qr' ? 'Quét mã QR' : 'Tắt bằng thao tác';
const dayName = (days) => {
  const sorted = [...days].sort().join(',');
  if (!days.length) return 'Một lần';
  if (days.length === 7) return 'Mỗi ngày';
  if (sorted === '1,2,3,4,5') return 'Thứ 2 – Thứ 6';
  if (sorted === '0,6') return 'Thứ 7, Chủ nhật';
  return [1,2,3,4,5,6,0].filter((day) => days.includes(day)).map((day) => day === 0 ? 'CN' : `T${day+1}`).join(', ');
};
function ensureDraft() { if (!state.draft) state.draft = clone(currentAlarm()); return state.draft; }
function sunArt() { return `<div class="sun-art" aria-hidden="true"><div class="sun-core"></div>${Array.from({length:16},(_,i)=>`<i class="ray" style="transform:rotate(${i*22.5}deg)"></i>`).join('')}<div class="horizon"></div></div>`; }
function bigSun(success = false) {
  return `<div class="big-sun" aria-hidden="true"><svg viewBox="0 0 160 160"><g stroke="#D1A737" stroke-width="2" stroke-linecap="round">${Array.from({length:12},(_,i)=>`<path d="M80 7v13" transform="rotate(${i*30} 80 80)"/>`).join('')}</g><circle cx="80" cy="80" r="48" fill="#F5C842"/><circle cx="65" cy="75" r="2.3" fill="#765819"/><circle cx="95" cy="75" r="2.3" fill="#765819"/><path d="M69 88q11 10 22 0" fill="none" stroke="#765819" stroke-width="2.3" stroke-linecap="round"/>${success?'<circle cx="122" cy="117" r="18" fill="#FFFCF6"/><path d="m114 117 5 5 10-12" stroke="#54734F" fill="none" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>':''}</svg></div>`;
}
function sessionClock() {
  const alarm=state.session?.alarm || currentAlarm();
  const minutes=alarm.hour*60+alarm.minute+(state.session?.snoozes||0)*5;
  return {hour:Math.floor(minutes/60)%24,minute:minutes%60};
}
function statusbar(morning = false) { return `<div class="statusbar"><span>${morning?timeText(sessionClock()):'22:15'}</span><div class="island"></div><div class="status-icons"><span class="signal" aria-hidden="true">▂▄▆█</span><span aria-hidden="true">⌁</span><span class="battery" aria-hidden="true"></span></div></div>`; }
function nextAlarmOffset(alarm) {
  if(!alarm.enabled)return Infinity;
  for(let day=0;day<=7;day++) {
    const minutes=day*1440+alarm.hour*60+alarm.minute-1335;
    if(minutes>0&&(!alarm.days.length||alarm.days.includes(day%7)))return minutes;
  }
  return Infinity;
}
function pageTitle(title, back = 'home') { return `<div class="app-page-title"><button class="icon-button" data-route="${back}" aria-label="Quay lại">${icon('left')}</button><h2>${title}</h2><span class="spacer"></span></div>`; }
function bottomNav(active) { return `<nav class="bottom-nav" aria-label="Điều hướng ứng dụng"><button data-route="home" class="${active==='home'?'selected':''}">${icon('alarm')}<span>Báo thức</span></button><button data-route="progress" class="${active==='progress'?'selected':''}">${icon('chart')}<span>Nhịp của bạn</span></button><button data-action="settings">${icon('settings')}<span>Cài đặt</span></button></nav>`; }
function progressWeek(complete = 4) { return `<div class="week-progress">${['T2','T3','T4','T5','T6','T7','CN'].map((name,i)=>`<div class="day-dot ${i<complete?'complete':''}"><span>${i<complete?icon('check'):i>4?'–':'·'}</span>${name}</div>`).join('')}</div>`; }
function renderHome() {
  const next = [...state.alarms].sort((a,b)=>nextAlarmOffset(a)-nextAlarmOffset(b))[0];
  const other = state.alarms.find((alarm)=>alarm.id!==next.id);
  return `<div class="phone-page"><div class="app-top"><div class="app-logo">${icon('rise')}HiMorning.</div><span class="app-date">Chủ nhật<br>11 tháng 10</span></div><h2 class="greeting">Sáng mai, thật nhẹ.</h2><p class="small-copy">Một khởi đầu tốt đang đợi bạn.</p><div class="hero-alarm">${sunArt()}<div style="display:flex;justify-content:space-between;align-items:center;position:relative;z-index:2"><p class="hero-label">${next.enabled?'BÁO THỨC TIẾP THEO':'BÁO THỨC ĐANG TẮT'}</p><button data-action="edit-alarm" data-id="${next.id}" style="font-size:10px;padding:3px" aria-label="Sửa báo thức ${timeText(next)}">Sửa</button></div><div class="time">${timeText(next)}</div><p class="hero-meta">${escapeHTML(next.label)} · ${dayName(next.days)}</p><div class="hero-divider"></div><div class="hero-bottom"><span>${icon(modes[next.mode].icon)}${modes[next.mode].name}</span><button class="mini-pill" role="switch" aria-checked="${next.enabled}" aria-label="Bật báo thức ${escapeHTML(next.label)}" data-action="toggle-alarm" data-id="${next.id}">${next.enabled?'✓ Đã bật':'Đang tắt'}</button></div></div><div class="section-row"><h3>Những buổi sáng khác</h3><span>${state.alarms.length} báo thức</span></div>${other?`<div class="alarm-row"><button data-action="edit-alarm" data-id="${other.id}" style="text-align:left;padding:0;flex:1"><div class="alarm-title">${icon(other.mode==='gentle'?'leaf':'sun')}${escapeHTML(other.label)}</div><div class="alarm-row-time">${timeText(other)}</div><div class="alarm-row-meta">${dayName(other.days)} · ${modes[other.mode].name}</div></button><button class="switch ${other.enabled?'on':''}" role="switch" aria-checked="${other.enabled}" aria-label="Bật báo thức ${escapeHTML(other.label)}" data-action="toggle-alarm" data-id="${other.id}"></button></div>`:''}${state.alarms.length>2?`<button class="advanced" data-action="all-alarms">Xem ${state.alarms.length-2} báo thức khác</button>`:''}<button class="primary-button home-add" data-action="new-alarm">${icon('plus')}Thêm báo thức</button></div>${bottomNav('home')}`;
}
function renderEditor(scope) {
  const alarm = draftAlarm();
  return `<div class="phone-page">${pageTitle('Đặt báo thức')}<div class="time-picker"><input type="number" id="hour-${scope}" name="hour" aria-label="Giờ báo thức" min="0" max="23" value="${String(alarm.hour).padStart(2,'0')}" inputmode="numeric"><span class="colon">:</span><input type="number" id="minute-${scope}" name="minute" aria-label="Phút báo thức" min="0" max="59" value="${String(alarm.minute).padStart(2,'0')}" inputmode="numeric"></div><div class="week-picker" aria-label="Ngày lặp lại">${[1,2,3,4,5,6,0].map((day)=>`<button data-action="day" data-day="${day}" class="${alarm.days.includes(day)?'chosen':''}" aria-pressed="${alarm.days.includes(day)}" aria-label="${day===0?'Chủ nhật':'Thứ '+(day+1)}">${day===0?'CN':'T'+(day+1)}</button>`).join('')}</div><label class="name-field" for="label-${scope}"><span>Tên báo thức</span><input id="label-${scope}" name="label" maxlength="24" value="${escapeHTML(alarm.label)}" aria-label="Tên báo thức"></label><p class="field-label">Bạn muốn thức dậy thế nào?</p><div class="mode-tabs" aria-label="Cách thức dậy">${Object.entries(modes).map(([id,mode])=>`<button data-action="mode" data-mode="${id}" class="${alarm.mode===id?'chosen':''}" aria-pressed="${alarm.mode===id}">${icon(mode.icon)}${mode.name}</button>`).join('')}</div><p class="mode-description">${modes[alarm.mode].description}</p><button class="setting-row" data-route="missions">${icon(alarm.mission==='qr'?'qr':'move')}<span class="row-text">Nhiệm vụ</span><span class="row-value">${missionName(alarm)}</span>${icon('right','chevron')}</button><button class="setting-row" data-route="sounds">${icon('music')}<span class="row-text">Âm thanh</span><span class="row-value">${soundName(alarm.sound)}</span>${icon('right','chevron')}</button>${state.formError?`<p class="form-error" role="alert">${state.formError}</p>`:''}<button class="primary-button editor-save" data-action="save-alarm">Lưu báo thức ${icon('check')}</button><button class="advanced" data-action="advanced">Tùy chỉnh thêm</button></div><div class="home-indicator"></div>`;
}
function renderSounds(scope) {
  const alarm = draftAlarm();
  return `<div class="phone-page">${pageTitle('Âm thanh','editor')}<h2 class="app-intro">Âm thanh của<br>một ngày mới.</h2><p class="small-copy">Chọn một âm khiến bạn muốn thức dậy.</p><div class="sound-groups">${['Êm dịu','Tươi sáng','Rõ ràng'].map((family)=>`<p class="sound-group-title">${family}</p>${sounds.filter((sound)=>sound.family===family).map((sound)=>`<div class="sound-row ${alarm.sound===sound.id?'chosen':''}"><button class="sound-select" data-action="select-sound" data-sound="${sound.id}" aria-pressed="${alarm.sound===sound.id}" aria-label="Chọn âm ${sound.name}"><span class="sound-orb">${icon(sound.icon)}</span><span><span class="sound-name">${sound.name}</span><span class="sound-description" style="display:block">${sound.detail}</span></span>${alarm.sound===sound.id?icon('check','sound-tick'):''}</button><button class="play-button ${state.playing===sound.id?'playing':''}" data-action="play-sound" data-sound="${sound.id}" aria-label="${state.playing===sound.id?'Dừng':'Nghe thử'} ${sound.name}">${icon(state.playing===sound.id?'stop':'play')}</button></div>`).join('')}`).join('')}</div><div class="volume-block"><label class="volume-title" for="volume-${scope}">${icon('volume')}Âm lượng nghe thử<output>${state.volume}%</output></label><input type="range" id="volume-${scope}" name="volume" min="0" max="70" value="${state.volume}" aria-label="Âm lượng nghe thử"><p class="volume-help">Âm lượng báo thức thực tế theo thiết bị.<br>Hãy thử chuông trước buổi sáng đầu tiên.</p></div><button class="primary-button sound-done" data-route="editor">Chọn âm này ${icon('check')}</button></div><div class="home-indicator"></div>`;
}
function renderMissions() {
  const alarm = draftAlarm();
  const options = [{id:'none', name:'Thức dậy nhẹ nhàng', description:'Tắt bằng thao tác, theo nhịp của bạn.', icon:'leaf'}, {id:'pushup', name:'Chống đẩy', description:'Vận động một chút để bắt đầu ngày mới.', icon:'move'}, {id:'qr', name:'Quét mã QR', description:'Đặt mã ở một nơi xa giường.', icon:'qr'}];
  return `<div class="phone-page">${pageTitle('Chọn nhiệm vụ','editor')}<h2 class="app-intro">Một bước nhỏ.<br>Một khởi đầu tốt.</h2><p class="small-copy">Chọn điều phù hợp với bạn và căn phòng.</p><div style="margin-top:20px">${options.map((option)=>`<button class="mission-option ${alarm.mission===option.id?'chosen':''}" data-action="mission" data-mission="${option.id}" aria-pressed="${alarm.mission===option.id}"><span class="mission-symbol">${icon(option.icon)}</span><span><h3>${option.name}</h3><p>${option.description}</p></span>${alarm.mission===option.id?icon('check'):''}</button>`).join('')}</div>${alarm.mission==='pushup'?`<div class="target-row"><span>Mục tiêu của bạn</span><div class="stepper"><button data-action="decrement" aria-label="Giảm số lần chống đẩy" ${alarm.target<=1?'disabled':''}>−</button><span>${alarm.target} lần</span><button data-action="increment" aria-label="Tăng số lần chống đẩy" ${alarm.target>=10?'disabled':''}>+</button></div></div>`:alarm.mission==='qr'?'<p class="small-copy" style="margin-top:20px">Thử quét mã trước. Sáng mai, bạn chỉ cần đến đúng nơi đã đặt mã.</p>':'<p class="small-copy" style="margin-top:20px">Một lựa chọn đơn giản cho những buổi sáng bạn muốn nhẹ nhàng hơn.</p>'}${alarm.mission==='pushup'?`<div class="setting-row guidance-setting"><span class="row-text">Gợi ý động tác<small>Mỗi lần một gợi ý nhẹ nhàng</small></span><button class="switch ${alarm.guidance?'on':''}" role="switch" aria-checked="${!!alarm.guidance}" aria-label="Gợi ý động tác" data-action="toggle-guidance"></button></div>`:''}<div class="privacy-line">${icon('shield')}<span>${alarm.mission==='none'?'Bạn có thể thay đổi nhiệm vụ bất cứ lúc nào cho lần báo tiếp theo.':alarm.mission==='qr'?'Mã QR được kiểm tra trên điện thoại.':'Cần mạng. Một số khung hình được gửi đến OpenAI để xác minh.'}</span></div>${alarm.mission!=='none'?`<button class="secondary-button trial-button" data-action="rehearse">${icon('play')}Thử trước cho yên tâm</button>`:''}<button class="primary-button" data-route="editor" style="margin-top:12px">Chọn nhiệm vụ này ${icon('check')}</button></div><div class="home-indicator"></div>`;
}
function renderRinging() {
  const alarm = state.session?.alarm || currentAlarm();
  const remaining = Math.max(0,modes[alarm.mode].snoozes-(state.session?.snoozes||0));
  if (state.session?.snoozed) return `<div class="phone-page ringing-page"><span class="ringing-mode">${icon('moon')}Đã báo lại</span>${bigSun()}<div class="ringing-time">${timeText(sessionClock())}</div><h2>Thêm một chút nghỉ ngơi.</h2><p>Báo thức sẽ nhắc lại sau 5 phút.</p><div class="ringing-actions"><button class="primary-button" data-action="wake-now">Mình dậy luôn ${icon('arrow')}</button><button class="text-button" data-action="stop-session">Dừng báo thức hôm nay</button></div></div><div class="home-indicator"></div>`;
  return `<div class="phone-page ringing-page"><span class="ringing-mode">${icon(modes[alarm.mode].icon)}${modes[alarm.mode].name}</span>${bigSun()}<div class="ringing-time">${timeText(sessionClock())}</div><h2>Chào một ngày mới.</h2><p>${alarm.mission==='none'?'Thức dậy theo nhịp của bạn.':alarm.mission==='qr'?'Đến nơi đặt mã QR để bắt đầu buổi sáng.':`Bắt đầu bằng ${alarm.target} lần chống đẩy nhẹ nhàng.`}</p><div class="ringing-actions"><button class="primary-button" data-action="start-mission">${alarm.mission==='none'?'Mình dậy rồi':'Bắt đầu nhiệm vụ'} ${icon('arrow')}</button>${remaining>0?`<button class="secondary-button" data-action="snooze">${icon('moon')}Thêm 5 phút · còn ${remaining} lần</button>`:''}<button class="text-button" data-action="stop-session">Dừng báo thức hôm nay</button></div></div><div class="home-indicator"></div>`;
}
function personIllustration() {
  return `<svg class="person-illustration" viewBox="0 0 300 190" aria-label="Minh họa vị trí đặt máy khi chống đẩy" role="img"><path d="M27 156h247" stroke="#B7AE98" stroke-width="2"/><path d="m45 137 43-43 80-15" fill="none" stroke="#6B715D" stroke-width="18" stroke-linecap="round" stroke-linejoin="round"/><path d="m164 80 53 19" fill="none" stroke="#D6AC35" stroke-width="35" stroke-linecap="round"/><path d="m207 99 11 25-4 24m-42-58 2 34 17 25" fill="none" stroke="#C89469" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/><circle cx="243" cy="84" r="19" fill="#C89469"/><path d="M226 74q17-24 34 0l-11 3-20 3Z" fill="#393B32"/><path d="m32 145 21-3m151 11 21-2m-45 1h23" stroke="#40463B" stroke-width="9" stroke-linecap="round"/><g stroke="#7E836C" stroke-width="1.5" fill="#FBF7EB"><path d="m48 136 42-43 80-12 39 18 9 25-4 24" fill="none" opacity=".6"/><circle cx="90" cy="93" r="4"/><circle cx="170" cy="81" r="4"/><circle cx="209" cy="99" r="4"/><circle cx="218" cy="124" r="4"/><circle cx="214" cy="148" r="4"/></g></svg>`;
}
function renderCamera() {
  const alarm = state.session?.alarm || draftAlarm();
  const isQR = alarm.mission==='qr';
  const verifying = !isQR && state.verificationStatus!=='idle';
  const recovery = ['uncertain','unavailable'].includes(state.verificationStatus);
  const hint = verifying ? {pending:'Đang xác minh động tác…',uncertain:'Chưa nhìn rõ toàn bộ động tác.',unavailable:'Chưa kết nối được để xác minh.'}[state.verificationStatus] : state.lowConfidence?'Chưa nhìn rõ. Thử đặt lại điện thoại một chút nhé.':state.formIssue&&alarm.guidance?'Thử giữ thân người thẳng hơn nhé.':isQR?'Quét mã bạn đã chọn trước đó.':state.reps===0?'Đặt máy nằm ngang, để thấy rõ động tác.':`Đã ghi nhận ${state.reps} lần. Còn ${Math.max(0,alarm.target-state.reps)} lần nữa.`;
  return `<div class="phone-page camera-page">${pageTitle(state.rehearsal?'Thử nhiệm vụ':isQR?'Quét mã QR':'Chống đẩy',state.rehearsal?'missions':'ringing')}<div class="camera-view ${state.lowConfidence?'low-confidence':''}"><span class="camera-caption">${verifying?'Đã ghi nhận chuyển động':state.rehearsal?'Làm quen với nhiệm vụ':'Giữ điện thoại cố định'}</span>${isQR?`<svg class="qr-illustration" fill="none" stroke="currentColor" stroke-width="1.4"><use href="#i-qr"/></svg>`:personIllustration()}<i class="frame-corner tl"></i><i class="frame-corner tr"></i><i class="frame-corner bl"></i><i class="frame-corner br"></i></div>${isQR?'<h2 class="app-intro" style="margin-top:26px">Đưa mã vào khung hình.</h2>':`<div class="camera-count">${state.reps}<span> / ${alarm.target}</span></div><div class="camera-progress">${Array.from({length:alarm.target},(_,i)=>`<i class="${i<state.reps?'done':''}"></i>`).join('')}</div><p class="counter-caption">${verifying?'Chờ kết quả xác minh':'Số lần tạm ghi nhận'}</p>`}<p class="camera-hint ${!verifying&&state.formIssue&&alarm.guidance&&!state.lowConfidence?'form-cue':''}" role="status">${hint}</p>${recovery?`<div class="recovery-actions"><button class="secondary-button" data-action="retry-verification">${state.verificationStatus==='uncertain'?'Thử ghi nhận lại':'Thử kết nối lại'}</button><button class="text-button" data-action="self-fallback">${state.rehearsal?'Kết thúc buổi thử':'Mình đã dậy · tự xác nhận'}</button></div>`:''}<button class="privacy-link" data-action="ai-privacy">${icon('shield')}<span>${isQR?'Mã QR được kiểm tra trên điện thoại.':'Khung hình được gửi đến OpenAI để xác minh.'}</span></button><button class="text-button" data-action="${state.rehearsal?'end-rehearsal':'stop-session'}">${state.rehearsal?'Kết thúc thử nhiệm vụ':'Hôm nay mình dừng ở đây'}</button></div><div class="home-indicator"></div>`;
}
function renderComplete(gallery = false) {
  const alarm = state.session?.alarm || currentAlarm();
  const stopped = !gallery && state.session?.outcome==='dismissed';
  const rehearsed = !gallery && state.rehearsal;
  const count = gallery?4:Math.min(5,4+state.completed.size);
  return `<div class="phone-page completion-page"><p class="completion-kicker">${rehearsed?'ĐÃ THỬ NHIỆM VỤ':stopped?'ĐÃ DỪNG BÁO THỨC':'CHÀO NGÀY MỚI'}</p>${bigSun(!stopped)}<h2>${rehearsed?'Sẵn sàng cho<br>sáng mai.':stopped?'Hẹn bạn vào<br>buổi sáng tới.':'Một khởi đầu<br>thật tốt.'}</h2><p class="small-copy">${rehearsed?'Bạn đã biết cách thực hiện. Chọn mục tiêu vừa sức với mình nhé.':stopped?'Bạn có thể chọn cách thức dậy nhẹ nhàng hơn cho lần sau.':'Một chút chủ động, một ngày nhiều năng lượng hơn.'}</p>${!rehearsed?`<div class="completion-time">${gallery?timeText(alarm):timeText(sessionClock())}</div><div class="verified-label">${icon(stopped?'moon':'check')}${stopped?'Không ghi nhận hoàn thành nhiệm vụ':alarm.mission==='none'||state.session?.outcome==='self-confirmed'?'Bạn đã tự xác nhận thức dậy':alarm.mission==='pushup'?missionName(alarm)+' · AI xác nhận':missionName(alarm)+' · đã xác nhận'}</div>${progressWeek(count)}<p class="week-copy">${count} buổi sáng hoàn thành trong tuần</p>`:'<div class="privacy-line" style="justify-content:center;margin-top:24px">Buổi thử không được tính vào tiến độ.</div>'}<button class="primary-button" data-route="${rehearsed?'missions':'home'}">${rehearsed?'Về chọn nhiệm vụ':stopped?'Về báo thức':'Bắt đầu ngày mới'} ${icon('arrow')}</button></div><div class="home-indicator"></div>`;
}
function renderProgress() {
  const count = Math.min(5,4+state.completed.size);
  return `<div class="phone-page"><div class="app-top"><div class="app-logo">${icon('rise')}HiMorning.</div><span class="app-date">Tuần của bạn</span></div><h2 class="greeting">Từng sáng một.</h2><p class="small-copy">Một nhịp đều đặn, theo cách của bạn.</p><div class="progress-total">${count}<small> / 5 buổi</small></div><p class="small-copy">Hoàn thành trong tuần này</p>${progressWeek(count)}<div class="section-row"><h3>Nhịp bốn tuần gần đây</h3></div><div class="progress-bars">${[45,65,52,80].map((height,i)=>`<div style="height:${height}%"><span>T${i+1}</span></div>`).join('')}</div><p class="progress-note">Ngày nghỉ vẫn là một phần của nhịp sống.<br>Mỗi buổi sáng bạn hoàn thành đều được giữ lại.</p><button class="secondary-button" style="margin-top:25px" data-action="progress-detail">Xem cách tính tiến độ ${icon('right')}</button></div>${bottomNav('progress')}`;
}
function renderPhone(screen, scope = 'live', gallery = false) {
  const content = {home:()=>renderHome(),editor:()=>renderEditor(scope),sounds:()=>renderSounds(scope),missions:()=>renderMissions(),ringing:()=>renderRinging(),camera:()=>renderCamera(),complete:()=>renderComplete(gallery),progress:()=>renderProgress()};
  return `<div class="screen" ${gallery?'inert':''}>${statusbar(['ringing','camera','complete'].includes(screen))}${(content[screen]||content.home)()}</div>`;
}
function renderGallery() {
  const screens = [{id:'home', name:'Báo thức của bạn'},{id:'editor', name:'Chọn nhịp thức dậy'},{id:'sounds', name:'Âm thanh buổi sáng'},{id:'missions', name:'Một nhiệm vụ vừa sức'},{id:'camera', name:'Bắt đầu chuyển động'},{id:'complete', name:'Ghi nhận mỗi buổi sáng'}];
  $('#screen-gallery').innerHTML = screens.map((screen,i)=>`<article class="gallery-item"><div class="gallery-label"><span>0${i+1}</span><h2>${screen.name}</h2><button data-open-screen="${screen.id}" aria-label="Bấm thử màn hình ${screen.name}">Bấm thử ${icon('arrow')}</button></div><div role="button" tabindex="0" data-open-screen="${screen.id}" aria-label="Mở prototype ${screen.name}"><div class="device">${renderPhone(screen.id,screen.id,true)}</div></div></article>`).join('');
}
const contexts = {
  home:{title:'Một cái nhìn là đủ.',text:'Giờ báo thức là điểm nhìn đầu tiên. Chế độ, trạng thái và các buổi sáng khác luôn nằm trong tầm tay.',tags:['Giờ lớn','Một thao tác chính','Nền kem dịu']},
  editor:{title:'Linh hoạt, vừa đủ.',text:'Ba cấu hình dễ hiểu. Người dùng tự chọn mức cam kết; nhiệm vụ và âm thanh luôn có thể thay đổi riêng.',tags:['Không phân loại tính cách','Ngày lặp rõ ràng']},
  sounds:{title:'Nghe rồi hãy chọn.',text:'Sáu tính cách âm để so sánh. Bấm biểu tượng phát để nghe; bấm tên âm để chọn. Không tự phát khi mở trang.',tags:['Âm phác thảo','Một âm mỗi lần','Offline']},
  missions:{title:'Vừa sức với mình.',text:'Vận động là một lựa chọn. Có thể dùng thao tác thường, chống đẩy hoặc QR, và thử trước khi đến buổi sáng.',tags:['Tự nguyện','Có bước thử','Không cần tài khoản']},
  ringing:{title:'Một bước tiếp theo.',text:'Nút chính rõ ràng. Số lần báo lại theo cấu hình đã chọn. Hành động dừng luôn dễ tìm.',tags:['Ít quyết định','Tôn trọng quyền dừng']},
  camera:{title:'Hướng dẫn, không thúc ép.',text:'Counter trên máy phản hồi ngay; OpenAI xác minh chuỗi khung hình trước khi ghi hoàn thành AI. Các nút bên dưới chỉ mô phỏng, không gọi API.',tags:['Camera + AI mô phỏng','OpenAI verification']},
  complete:{title:'Một lời ghi nhận nhỏ.',text:'Một buổi sáng được ghi nhận. Ngày nghỉ trung tính; dừng hoặc thử nhiệm vụ không được tính thành hoàn thành thật.',tags:['Lịch sử được giữ lại','Không phán xét']},
  progress:{title:'Đều đặn theo thời gian.',text:'Tiến độ dựa trên những buổi có lịch. Tự xác nhận và nhiệm vụ được kiểm chứng là hai loại kết quả riêng.',tags:['Ngày nghỉ trung tính','Không suy diễn dữ liệu']}
};
function renderContext() {
  const context = contexts[state.screen];
  $('#context-panel').innerHTML = `<p class="context-label">GÓC NHÌN THIẾT KẾ</p><h2>${context.title}</h2><p>${context.text}</p><div class="context-tags">${context.tags.map((tag)=>`<span>${tag}</span>`).join('')}</div>`;
  let controls='';
  if(['home','editor'].includes(state.screen)) controls=`<p class="simulation-note">Chạy thử báo thức đã lưu trong bản mẫu.</p><button class="review-action" data-action="simulate-alarm">${icon('alarm')}Mô phỏng đến giờ</button>`;
  if(state.screen==='ringing'&&state.session?.snoozed) controls=`<p class="simulation-note">Thời gian chỉ được mô phỏng.</p><button class="review-action" data-action="ring-again">${icon('alarm')}Mô phỏng sau 5 phút</button>`;
  if(state.screen==='camera') {
    const alarm=state.session?.alarm||draftAlarm();
    controls=`<p class="context-label">TÍN HIỆU CAMERA GIẢ LẬP</p><button class="review-action" data-action="valid-rep" ${state.lowConfidence||state.verificationStatus!=='idle'?'disabled':''}>${icon('check')}${alarm.mission==='qr'?'Xác nhận đúng mã QR':'+1 chuyển động ghi nhận'}</button><button class="review-action secondary" data-action="low-confidence" ${state.verificationStatus!=='idle'?'disabled':''}>${icon(state.lowConfidence?'camera':'info')}${state.lowConfidence?'Khung hình rõ trở lại':'Mô phỏng không nhận diện được'}</button>${alarm.mission==='pushup'?`<button class="review-action secondary" data-action="form-feedback" ${state.verificationStatus!=='idle'||!alarm.guidance?'disabled':''}>${icon('move')}${state.formIssue?'Kết thúc gợi ý tư thế':'Mô phỏng gợi ý tư thế'}</button><p class="simulation-note">Gợi ý tư thế là advisory, không tự chặn rep. Có thể bật/tắt trong phần nhiệm vụ.</p>`:''}`;
  }
  if(state.screen==='camera'&&state.verificationStatus==='pending')controls=`<p class="context-label">KẾT QUẢ OPENAI GIẢ LẬP</p><button class="review-action" data-action="ai-verified">${icon('check')}AI xác nhận hoàn thành</button><button class="review-action secondary" data-action="ai-uncertain">${icon('camera')}AI chưa đủ dữ liệu</button><button class="review-action secondary" data-action="ai-unavailable">${icon('cloud')}Mô phỏng lỗi kết nối</button><p class="simulation-note">Không có dữ liệu nào được gửi trong bản mẫu. Hoàn thành chỉ được ghi sau bước xác nhận.</p>`;
  $('#simulation-controls').innerHTML=controls;
}
function renderPrototype() {
  $('#interactive-device').innerHTML=renderPhone(state.screen);
  $('#flow-nav').innerHTML=Object.entries(screenNames).filter(([id])=>id!=='camera').map(([id,name],i)=>`<button data-screen-nav="${id}" class="${state.screen===id?'active':''}" ${state.screen===id?'aria-current="page"':''}><span>0${i+1}</span>${name}</button>`).join('');
  renderContext();
}
const modules = {
  ui:{number:'01 / EXPERIENCE',title:'Một ngôn ngữ thiết kế.',description:'SwiftUI hiển thị trạng thái từ view model. Cùng một cấu trúc giao diện đáp ứng cả ba mức cam kết; màu vàng chỉ nhấn nơi cần thao tác.',responsibilities:['Hiển thị giờ, quyền và trạng thái lưu chính xác.','Hỗ trợ VoiceOver, chữ lớn, sáng/tối và reduced motion.','PreviewPlayer độc lập với volume hệ thống.'],boundary:'UI không tự đếm rep, tự chạy timer nền hay suy diễn rằng người dùng đã thức.'},
  domain:{number:'02 / DOMAIN',title:'Quy tắc có thể kiểm thử.',description:'WakePolicy và session coordinator quyết định các chuyển trạng thái. Mỗi phiên dùng snapshot cấu hình; mọi completion có khóa chống xử lý trùng.',responsibilities:['Giới hạn số lần báo lại theo preset.','Phân biệt hoàn thành, tự xác nhận, dừng và chưa có dữ liệu.','Lưu kế hoạch thay đổi cho lần báo tới.'],boundary:'Lỗi camera, mạng hoặc thuê bao không được chặn quyền dừng báo thức.'},
  alarm:{number:'03 / NATIVE INTEGRATION',title:'Để hệ điều hành giữ lịch.',description:'AlarmScheduler là ranh giới giữa domain và AlarmKit. Ghi lệnh, nhận kết quả từ hệ điều hành và đối chiếu trạng thái sau gián đoạn.',responsibilities:['Kiểm tra quyền trước khi schedule.','Quản lý ID và revision để retry không tạo lịch trùng.','App Intents mở đúng phiên; Live Activity cho snooze khi cần.'],boundary:'Nút Stop hệ thống không chứng minh nhiệm vụ đã hoàn thành. Hành vi mở app, volume và camera khi khóa phải qua spike thiết bị.'},
  vision:{number:'04 / LOCAL MOVEMENT',title:'Phản hồi ngay khi chuyển động.',description:'Camera foreground cung cấp frame cho Vision. Quality gate và bộ đếm tạm chạy trên máy; chuỗi ảnh qua backend đến OpenAI sau consent.',responsibilities:['Counter tạm không đồng nghĩa OpenAI đã xác minh.','Confidence thấp: hướng dẫn, không tự cộng rep.','Ngừng camera khi background; reset partial rep khi quay lại.'],boundary:'Prototype minh họa thao tác. Accuracy, replay và các điều kiện phòng thật vẫn cần benchmark trên thiết bị.'},
  data:{number:'05 / LOCAL PERSISTENCE',title:'Lưu lại điều cần thiết.',description:'SwiftData sau Repository lưu lịch và kết quả. Command journal phục hồi các thao tác dang dở; không coi DB và AlarmKit là một transaction.',responsibilities:['Alarm, WakePolicy, SystemRegistration, WakeSession.','Schema migration và journal idempotent.','Không lưu video, landmarks hoặc QR payload vào analytics.'],boundary:'Backend AI lưu session, quota và metadata tối thiểu trong Cloud Firestore. Không lưu ảnh mặc định; retention phía OpenAI được giải thích riêng.'}
  ,cloud:{number:'06 / OPENAI VERIFICATION',title:'Xác minh có bằng chứng.',description:'Cloud Functions for Firebase bằng TypeScript gửi ảnh theo thứ tự đến OpenAI Responses. Structured Outputs trả kết quả để policy kiểm tra trước khi ghi hoàn thành.',responsibilities:['Firebase Auth + App Check; API key ở Secret Manager.','Firestore lưu session/quota; verdict do Functions ghi.','Giữ quyền dừng; bỏ qua kết quả đến muộn sau khi hủy.'],boundary:'Model baseline: GPT-5.6 Terra, cần benchmark. store:false không đồng nghĩa zero retention. Prototype chưa gọi API.'}
};
function renderModule() {
  const module=modules[state.module];
  $('#module-detail').innerHTML=`<p class="module-number">${module.number}</p><h2>${module.title}</h2><p>${module.description}</p><h3>Trách nhiệm chính</h3><ul>${module.responsibilities.map((item)=>`<li>${item}</li>`).join('')}</ul><div class="boundary-note">${module.boundary}</div>`;
  document.querySelectorAll('[data-module]').forEach((element)=>{element.classList.toggle('active',element.dataset.module===state.module);element.setAttribute('aria-pressed',String(element.dataset.module===state.module));});
}
function renderAll() {
  document.body.classList.toggle('dark-phone',state.theme==='dark');
  document.querySelectorAll('.studio-view').forEach((element)=>{element.hidden=element.id!==`view-${state.view}`;});
  document.querySelectorAll('[data-view]').forEach((element)=>{element.classList.toggle('active',element.dataset.view===state.view);if(element.dataset.view===state.view)element.setAttribute('aria-current','page');else element.removeAttribute('aria-current');});
  if(state.view==='screens')renderGallery();
  if(state.view==='prototype')renderPrototype();
  if(state.view==='architecture')renderModule();
}
function setView(view) {
  stopSound(false);state.view=view;
  if(view==='prototype'&&['editor','sounds','missions'].includes(state.screen))ensureDraft();
  history.replaceState(null,'',`#${view}`);renderAll();
}
function route(screen, fromNav=false) {
  stopSound(false);state.formError='';
  if(['editor','sounds','missions'].includes(screen))ensureDraft();
  if(screen==='home'){state.draft=null;state.rehearsal=false;state.session=null;state.verificationStatus='idle';}
  if(screen==='ringing'&&!state.session)startSession(currentAlarm(),false);
  if(screen==='camera'&&(!state.session||fromNav))startSession(draftAlarm(),true);
  if(screen==='complete'&&fromNav){state.session={alarm:clone(currentAlarm()),outcome:'preview',snoozes:0};state.rehearsal=false;}
  if(screen==='missions'&&state.rehearsal){state.rehearsal=false;state.session=null;state.verificationStatus='idle';}
  state.screen=screen;renderAll();
}
function toast(message) { clearTimeout(state.toastTimer);$('#toast').textContent=message;$('#toast').classList.add('visible');state.toastTimer=setTimeout(()=>$('#toast').classList.remove('visible'),3300); }
function startSession(alarm,rehearsal) { state.session={alarm:clone(alarm),snoozes:0,snoozed:false,outcome:null,key:`${alarm.id}:sample-morning`};state.reps=0;state.lowConfidence=false;state.formIssue=false;state.verificationStatus='idle';state.rehearsal=rehearsal; }
function completeSession(outcome) {
  if(!state.session)startSession(currentAlarm(),false);
  state.session.outcome=outcome;
  if(['self-confirmed','qr-verified','openai-verified'].includes(outcome)&&!state.rehearsal)state.completed.add(state.session.key);
  route('complete');
}
function beginMission() {
  if(state.session.alarm.mission==='none'){completeSession('self-confirmed');return;}
  if(state.session.alarm.mission==='pushup'&&!state.aiConsent){
    showDialog('Xác minh động tác bằng AI','Một số khung hình sẽ được gửi qua máy chủ ứng dụng đến OpenAI để xác minh. Bạn có thể chọn QR hoặc tắt bằng thao tác. Dữ liệu chịu chính sách lưu giữ của OpenAI; bản mẫu này không gửi ảnh.',[{label:'Đồng ý và tiếp tục',action:'consent-ai'},{label:'Để lúc khác',action:'decline-ai',secondary:true}]);
    return;
  }
  route('camera');
}
function closeDialog() { $('#dialog-root').innerHTML='';dialogLastFocus?.focus(); }
function showDialog(title,body,buttons) {
  dialogLastFocus=document.activeElement;
  $('#dialog-root').innerHTML=`<div class="dialog-overlay"><section class="dialog" role="dialog" aria-modal="true" aria-labelledby="dialog-title"><h2 id="dialog-title">${title}</h2><p>${body}</p>${buttons.map((button)=>`<button class="${button.secondary?'secondary-button':'primary-button'}" data-dialog-action="${button.action}">${button.label}</button>`).join('')}</section></div>`;
  $('#dialog-root button')?.focus();
}
function stopSound(refresh=true) {
  audioToken++;clearTimeout(state.audioTimer);audioNodes.forEach((node)=>{try{node.stop();}catch(_){}});audioNodes=[];
  try{previewGain?.disconnect();}catch(_){} previewGain=null;
  state.playing=null;
  if(refresh&&state.view==='prototype'&&state.screen==='sounds')renderPrototype();
}
async function playSound(id) {
  if(state.playing===id){stopSound();return;}
  stopSound(false);const token=audioToken;
  try {
    const AudioAPI=window.AudioContext||window.webkitAudioContext;
    if(!AudioAPI)throw new Error('unsupported');
    if(!audioContext)audioContext=new AudioAPI();
    await audioContext.resume();
    if(token!==audioToken||state.screen!=='sounds'||document.hidden)return;
    const sound=sounds.find((item)=>item.id===id);state.playing=id;
    previewGain=audioContext.createGain();previewGain.gain.value=state.volume/100*0.18;previewGain.connect(audioContext.destination);
    const start=audioContext.currentTime+.03, spacing=sound.family==='Rõ ràng'?.34:.46;
    sound.notes.forEach((frequency,index)=>{
      const oscillator=audioContext.createOscillator(), envelope=audioContext.createGain();
      const at=start+index*spacing;oscillator.type=sound.wave;oscillator.frequency.value=frequency;
      envelope.gain.setValueAtTime(0,at);envelope.gain.linearRampToValueAtTime(.5,at+.045);envelope.gain.exponentialRampToValueAtTime(.001,at+.62);
      oscillator.connect(envelope);envelope.connect(previewGain);oscillator.start(at);oscillator.stop(at+.65);audioNodes.push(oscillator);
      oscillator.onended=()=>{oscillator.disconnect();envelope.disconnect();};
    });
    renderPrototype();state.audioTimer=setTimeout(()=>{if(token===audioToken)stopSound();},(sound.notes.length-1)*spacing*1000+730);
  } catch(error) { stopSound(false);toast('Trình duyệt chưa phát được âm. Hãy kiểm tra quyền âm thanh rồi thử lại.');renderPrototype(); }
}
function saveAlarm() {
  const alarm=ensureDraft();
  if(!Number.isInteger(alarm.hour)||alarm.hour<0||alarm.hour>23||!Number.isInteger(alarm.minute)||alarm.minute<0||alarm.minute>59){state.formError='Giờ từ 00–23 và phút từ 00–59 nhé.';renderPrototype();return;}
  alarm.label=alarm.label.trim()||'Báo thức';alarm.enabled=true;
  const index=state.alarms.findIndex((item)=>item.id===alarm.id);
  if(index===-1)state.alarms.push(clone(alarm));else state.alarms[index]=clone(alarm);
  state.activeID=alarm.id;state.session=null;state.draft=null;route('home');toast('Đã lưu trong bản mẫu · '+timeText(alarm));
}
document.addEventListener('input',(event)=>{
  const element=event.target;
  if(element.name==='volume'){state.volume=Number(element.value);if(previewGain)previewGain.gain.setTargetAtTime(state.volume/100*.18,audioContext.currentTime,.03);element.closest('.volume-block').querySelector('output').textContent=`${state.volume}%`;}
  if(['hour','minute'].includes(element.name)){ensureDraft()[element.name]=element.value===''?NaN:Number(element.value);}
  if(element.name==='label')ensureDraft().label=element.value;
});
document.addEventListener('click',async(event)=>{
  const element=event.target.closest('button,[data-open-screen],[data-module],a.studio-brand');
  if(!element)return;
  if(element.matches('a.studio-brand')){event.preventDefault();setView('screens');return;}
  if(element.dataset.view){setView(element.dataset.view);return;}
  if(element.dataset.openScreen){state.view='prototype';route(element.dataset.openScreen,true);history.replaceState(null,'','#prototype');return;}
  if(element.dataset.screenNav){route(element.dataset.screenNav,true);return;}
  if(element.dataset.route){route(element.dataset.route);return;}
  if(element.dataset.module){state.module=element.dataset.module;renderModule();return;}
  if(element.dataset.dialogAction){const action=element.dataset.dialogAction;closeDialog();if(action==='confirm-stop')completeSession('dismissed');if(action==='consent-ai'){state.aiConsent=true;route('camera');}if(action==='decline-ai'){if(state.rehearsal){state.session=null;state.rehearsal=false;route('missions');}else completeSession('dismissed');}if(action.startsWith('edit:')){state.activeID=action.slice(5);state.draft=clone(currentAlarm());route('editor');}if(action==='theme'){state.theme=state.theme==='light'?'dark':'light';renderAll();}return;}
  const action=element.dataset.action;
  switch(action){
    case 'theme':state.theme=state.theme==='light'?'dark':'light';renderAll();break;
    case 'reset':stopSound(false);state.alarms=clone(initialAlarms);state.activeID='work';state.draft=null;state.session=null;state.screen='home';state.aiConsent=false;state.verificationStatus='idle';state.reps=0;state.lowConfidence=false;state.rehearsal=false;state.completed.clear();state.formError='';renderAll();toast('Đã đặt lại bản mẫu.');break;
    case 'edit-alarm':state.activeID=element.dataset.id;state.draft=clone(currentAlarm());route('editor');break;
    case 'new-alarm':state.draft={id:'new-'+Date.now(),label:'Buổi sáng',hour:7,minute:0,days:[1,2,3,4,5],mode:'gentle',mission:'none',target:3,sound:'sunrise',enabled:true,missionCustomized:false};route('editor');break;
    case 'toggle-alarm':{const alarm=state.alarms.find((item)=>item.id===element.dataset.id);alarm.enabled=!alarm.enabled;renderAll();toast(alarm.enabled?'Đã bật trong bản mẫu.':'Đã tắt trong bản mẫu.');break;}
    case 'day':{const alarm=ensureDraft(),day=Number(element.dataset.day);alarm.days=alarm.days.includes(day)?alarm.days.filter((value)=>value!==day):[...alarm.days,day];renderPrototype();break;}
    case 'mode':{const alarm=ensureDraft();alarm.mode=element.dataset.mode;if(!alarm.missionCustomized){alarm.mission=alarm.mode==='gentle'?'none':'pushup';alarm.target=alarm.mode==='focused'?5:3;}renderPrototype();break;}
    case 'mission':{const alarm=ensureDraft();alarm.mission=element.dataset.mission;alarm.missionCustomized=true;renderPrototype();break;}
    case 'toggle-guidance':ensureDraft().guidance=!draftAlarm().guidance;renderPrototype();break;
    case 'form-feedback':if(state.session?.alarm.guidance&&state.verificationStatus==='idle'){state.formIssue=!state.formIssue;renderPrototype();}break;
    case 'increment':ensureDraft().target=Math.min(10,draftAlarm().target+1);ensureDraft().missionCustomized=true;renderPrototype();break;
    case 'decrement':ensureDraft().target=Math.max(1,draftAlarm().target-1);ensureDraft().missionCustomized=true;renderPrototype();break;
    case 'select-sound':ensureDraft().sound=element.dataset.sound;renderPrototype();break;
    case 'play-sound':await playSound(element.dataset.sound);break;
    case 'save-alarm':saveAlarm();break;
    case 'simulate-alarm':{const alarm=currentAlarm();if(!alarm.enabled){toast('Bật báo thức trước khi mô phỏng nhé.');break;}startSession(alarm,false);route('ringing');break;}
    case 'rehearse':startSession(draftAlarm(),true);beginMission();break;
    case 'end-rehearsal':state.rehearsal=false;state.session=null;route('missions');break;
    case 'start-mission':if(!state.session)startSession(currentAlarm(),false);beginMission();break;
    case 'wake-now':state.session.snoozed=false;beginMission();break;
    case 'snooze':if(state.session&&state.session.snoozes<modes[state.session.alarm.mode].snoozes){state.session.snoozes++;state.session.snoozed=true;renderPrototype();}break;
    case 'ring-again':if(state.session){state.session.snoozed=false;renderPrototype();}break;
    case 'stop-session':showDialog('Dừng báo thức hôm nay?','Lịch cho những buổi sáng tiếp theo vẫn được giữ nguyên. Bạn có thể bắt đầu lại theo nhịp của mình.',[{label:'Tiếp tục nhiệm vụ',action:'close'},{label:'Dừng hôm nay',action:'confirm-stop',secondary:true}]);break;
    case 'valid-rep':if(state.lowConfidence||state.verificationStatus!=='idle')break;if(state.session?.alarm.mission==='qr')completeSession('qr-verified');else{state.reps++;if(state.reps>=(state.session?.alarm.target||3))state.verificationStatus='pending';renderPrototype();}break;
    case 'ai-verified':if(state.verificationStatus==='pending'){state.verificationStatus='idle';completeSession('openai-verified');}break;
    case 'ai-uncertain':if(state.verificationStatus==='pending'){state.verificationStatus='uncertain';renderPrototype();}break;
    case 'ai-unavailable':if(state.verificationStatus==='pending'){state.verificationStatus='unavailable';renderPrototype();}break;
    case 'retry-verification':if(state.verificationStatus==='uncertain'){state.reps=0;state.lowConfidence=false;state.formIssue=false;state.verificationStatus='idle';}else state.verificationStatus='pending';renderPrototype();break;
    case 'self-fallback':if(state.rehearsal){state.rehearsal=false;state.session=null;state.verificationStatus='idle';route('missions');}else completeSession('self-confirmed');break;
    case 'ai-privacy':showDialog('Camera và quyền riêng tư','QR được kiểm tra trên điện thoại. Với chống đẩy AI, khung hình đi qua máy chủ ứng dụng đến OpenAI sau khi bạn đồng ý. App không lưu video mặc định; OpenAI có chính sách lưu giữ dữ liệu riêng. Bản mẫu không dùng camera và không gửi ảnh.',[{label:'Đã hiểu',action:'close'}]);break;
    case 'low-confidence':state.lowConfidence=!state.lowConfidence;renderPrototype();break;
    case 'settings':showDialog('Theo nhịp của bạn','Trong bản mẫu, bạn có thể đổi giao diện sáng/tối. Báo thức và nhiệm vụ hoạt động độc lập với tài khoản.',[{label:state.theme==='light'?'Chuyển sang giao diện tối':'Chuyển sang giao diện sáng',action:'theme'},{label:'Đóng',action:'close',secondary:true}]);break;
    case 'advanced':showDialog('Tùy chỉnh thêm','Bản MVP dự kiến có bỏ qua lần tới và điều chỉnh báo lại. Trong mockup, ba chế độ đang dùng số lần báo lại mặc định để bạn dễ so sánh.',[{label:'Đã hiểu',action:'close'}]);break;
    case 'progress-detail':showDialog('Mỗi buổi sáng đều có giá trị','Tiến độ hiển thị dữ liệu mẫu. Tự xác nhận và hoàn thành nhiệm vụ được ghi riêng. Buổi thử, ngày nghỉ hoặc dừng giữa chừng không tự cộng thành tích.',[{label:'Đã hiểu',action:'close'}]);break;
    case 'all-alarms':showDialog('Các báo thức đã lưu','Chọn báo thức để chỉnh lại.',[...state.alarms.map(alarm=>({label:`${escapeHTML(alarm.label)} · ${timeText(alarm)}`,action:'edit:'+alarm.id,secondary:true})),{label:'Đóng',action:'close'}]);break;
  }
});
document.addEventListener('keydown',(event)=>{
  if(event.key==='Escape'&&$('#dialog-root').children.length){closeDialog();return;}
  if(event.key==='Tab'&&$('#dialog-root').children.length){const buttons=[...$('#dialog-root').querySelectorAll('button')];if(event.shiftKey&&document.activeElement===buttons[0]){event.preventDefault();buttons.at(-1).focus();}else if(!event.shiftKey&&document.activeElement===buttons.at(-1)){event.preventDefault();buttons[0].focus();}}
  if(['Enter',' '].includes(event.key)&&event.target.matches('[role="button"][data-open-screen],[role="button"][data-module]')){event.preventDefault();event.target.click();}
});
document.addEventListener('visibilitychange',()=>{if(document.hidden)stopSound();});
window.addEventListener('pagehide',()=>stopSound(false));
const initialView=location.hash.slice(1);if(['screens','prototype','architecture'].includes(initialView))state.view=initialView;
renderAll();
