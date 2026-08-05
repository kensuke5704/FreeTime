import { migratedState } from "./migrated-data.js";

const STORE_KEY = "freeTimeWebStore.v1";
const MIGRATED_MARK_KEY = "freeTimeWebStore.migrated.v1";
const APPLE_REFERENCE_DATE_MS = Date.UTC(2001, 0, 1, 0, 0, 0);

const planColors = {
  blue: "#2563eb",
  green: "#16a34a",
  orange: "#f97316",
  purple: "#7c3aed",
  red: "#dc2626",
  pink: "#db2777",
  yellow: "#ca8a04",
  teal: "#0d9488",
  cyan: "#0891b2",
  indigo: "#4f46e5",
  mint: "#10b981",
  brown: "#92400e"
};

const colorNames = Object.keys(planColors);
const views = ["home", "week", "tasks", "templates", "stats"];

let state = loadState();
let currentView = viewFromHash();
let modal = null;
let today = startOfDay(new Date());

function uuid() {
  return crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function loadState() {
  const raw = localStorage.getItem(STORE_KEY);
  if (raw) {
    try {
      const parsed = JSON.parse(raw);
      return {
        plans: Array.isArray(parsed.plans) ? parsed.plans : [],
        tasks: Array.isArray(parsed.tasks) ? parsed.tasks : [],
        templates: Array.isArray(parsed.templates) ? parsed.templates : []
      };
    } catch {}
  }
  if (migratedState && !localStorage.getItem(MIGRATED_MARK_KEY)) {
    const normalized = normalizeImportedState(migratedState);
    localStorage.setItem(MIGRATED_MARK_KEY, "1");
    localStorage.setItem(STORE_KEY, JSON.stringify(normalized));
    return normalized;
  }
  return seedState();
}

function seedState() {
  const base = startOfDay(new Date());
  return {
    plans: [
      makePlan("朝の準備", addMinutes(base, 540), addMinutes(base, 600), "off", "brown"),
      makePlan("集中作業", addMinutes(base, 780), addMinutes(base, 900), "on", "blue"),
      makePlan("ジム", addMinutes(base, 1140), addMinutes(base, 1230), "on", "green")
    ],
    tasks: [
      makeTask("課題レポート", "学習", addMinutes(base, 60 * 48), 180, 1, "purple"),
      makeTask("資料作成", "仕事", addMinutes(base, 60 * 72), 120, 2, "orange")
    ],
    templates: []
  };
}

function saveState() {
  localStorage.setItem(STORE_KEY, JSON.stringify(state));
}

function makePlan(title, start, end, kind = "on", color = "blue", memo = "", taskID = null) {
  return {
    id: uuid(),
    title,
    start: start.toISOString(),
    end: end.toISOString(),
    kind,
    color,
    memo,
    taskID
  };
}

function makeTask(title, category, deadline, estimatedMinutes, priority = 1, color = "blue") {
  return {
    id: uuid(),
    title,
    category,
    deadline: deadline ? deadline.toISOString() : null,
    estimatedMinutes,
    completedMinutes: 0,
    priority,
    color,
    memo: "",
    isCompleted: false
  };
}

function startOfDay(date) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

function addMinutes(date, minutes) {
  return new Date(new Date(date).getTime() + minutes * 60000);
}

function minutesBetween(start, end) {
  return Math.max(0, Math.round((new Date(end) - new Date(start)) / 60000));
}

function minutesSinceDayStart(date, day = today) {
  return Math.max(0, Math.min(1440, Math.floor((new Date(date) - startOfDay(day)) / 60000)));
}

function dateInputValue(date) {
  const d = new Date(date);
  const pad = n => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function fromDateInput(value) {
  return new Date(value);
}

function timeText(value) {
  const d = new Date(value);
  return d.toLocaleTimeString("ja-JP", { hour: "2-digit", minute: "2-digit" });
}

function dateText(value) {
  return new Date(value).toLocaleDateString("ja-JP", { month: "numeric", day: "numeric", weekday: "short" });
}

function durationText(minutes) {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h === 0) return `${m}分`;
  if (m === 0) return `${h}時間`;
  return `${h}時間${m}分`;
}

function plansOn(date) {
  const dayStart = startOfDay(date);
  const dayEnd = addMinutes(dayStart, 1440);
  return state.plans
    .filter(plan => new Date(plan.start) < dayEnd && new Date(plan.end) > dayStart)
    .sort((a, b) => new Date(a.start) - new Date(b.start));
}

function mergedBusyIntervals(date) {
  const dayStart = startOfDay(date);
  const dayEnd = addMinutes(dayStart, 1440);
  const ranges = plansOn(date)
    .map(plan => ({
      start: new Date(Math.max(new Date(plan.start), dayStart)),
      end: new Date(Math.min(new Date(plan.end), dayEnd))
    }))
    .filter(range => range.start < range.end)
    .sort((a, b) => a.start - b.start);

  const merged = [];
  for (const range of ranges) {
    const last = merged[merged.length - 1];
    if (last && range.start <= last.end) {
      last.end = new Date(Math.max(last.end, range.end));
    } else {
      merged.push({ ...range });
    }
  }
  return merged;
}

function freeMinutesOn(date) {
  const occupied = mergedBusyIntervals(date).reduce((sum, interval) => sum + minutesBetween(interval.start, interval.end), 0);
  return Math.max(0, 1440 - occupied);
}

function plannedMinutesOn(date, kind = null) {
  return plansOn(date)
    .filter(plan => !kind || plan.kind === kind)
    .reduce((sum, plan) => sum + minutesBetween(
      new Date(Math.max(new Date(plan.start), startOfDay(date))),
      new Date(Math.min(new Date(plan.end), addMinutes(startOfDay(date), 1440)))
    ), 0);
}

function freeIntervalsOn(date) {
  const dayStart = startOfDay(date);
  const dayEnd = addMinutes(dayStart, 1440);
  const slots = [];
  let cursor = dayStart;
  for (const interval of mergedBusyIntervals(date)) {
    if (cursor < interval.start) slots.push({ start: cursor, end: interval.start });
    cursor = new Date(Math.max(cursor, interval.end));
  }
  if (cursor < dayEnd) slots.push({ start: cursor, end: dayEnd });
  return slots;
}

function nextFreeInterval(date = new Date()) {
  const now = new Date(date);
  return freeIntervalsOn(now)
    .map(interval => {
      const start = new Date(Math.max(interval.start, now));
      return {
        start,
        end: selectableFreeEnd(startOfDay(now), interval.end)
      };
    })
    .find(interval => interval.end > interval.start);
}

function selectableFreeEnd(day, end) {
  const dayEnd = addMinutes(startOfDay(day), 1440);
  if (new Date(end).getTime() === dayEnd.getTime()) {
    return addMinutes(dayEnd, -5);
  }
  return end;
}

function freeIntervalContaining(date, selectedDate) {
  const dayStart = startOfDay(date);
  const dayEnd = addMinutes(dayStart, 1440);
  let freeStart = dayStart;
  for (const interval of mergedBusyIntervals(date)) {
    if (selectedDate < interval.start) {
      return { start: freeStart, end: interval.start };
    }
    freeStart = new Date(Math.max(freeStart, interval.end));
  }

  // iOS版の修正と同じ仕様:
  // 空き時間の終了が 0:00 の場合だけ、予定追加画面では前日 23:55 を終了時刻にする。
  const selectableDayEnd = addMinutes(dayEnd, -5);
  return { start: freeStart, end: new Date(Math.max(freeStart, selectableDayEnd)) };
}

function upcomingPlan() {
  const now = new Date();
  return plansOn(now).find(plan => new Date(plan.start) > now);
}

function scheduledMinutesForTask(taskID) {
  const intervals = state.plans
    .filter(plan => plan.taskID === taskID && new Date(plan.end) > new Date(plan.start))
    .map(plan => ({ start: new Date(plan.start), end: new Date(plan.end) }))
    .sort((a, b) => a.start - b.start);
  const merged = [];
  for (const interval of intervals) {
    const last = merged[merged.length - 1];
    if (last && interval.start <= last.end) {
      last.end = new Date(Math.max(last.end, interval.end));
    } else {
      merged.push({ ...interval });
    }
  }
  return merged.reduce((sum, interval) => sum + minutesBetween(interval.start, interval.end), 0);
}

function render() {
  const app = document.querySelector("#app");
  app.innerHTML = `
    <main class="app-shell">
      <aside class="sidebar">
        <div class="brand">
          <h1 class="brand-title">FreeTime</h1>
          <p class="brand-subtitle">予定と空き時間</p>
        </div>
        ${renderTabs("side")}
        <div class="sidebar-actions">
          <button class="button primary" data-action="add-plan">予定を追加</button>
          <button class="button" data-action="add-task">課題を追加</button>
        </div>
      </aside>
      <section class="workspace">
        <header class="topbar">
          <div>
            <p class="eyebrow">${new Date().toLocaleDateString("ja-JP", { year: "numeric", month: "long", day: "numeric", weekday: "long" })}</p>
            <h2>${currentViewTitle()}</h2>
          </div>
          <div class="top-actions">
            <label class="button import-button">
              読み込み
              <input type="file" accept="application/json,.json" data-action="import" hidden />
            </label>
            <button class="button" data-action="export">書き出し</button>
          </div>
        </header>
        ${renderViews()}
      </section>
    </main>
    <button class="fab" data-action="add-plan" aria-label="予定を追加">+</button>
    ${renderTabs("bottom")}
    <div class="modal-backdrop ${modal ? "active" : ""}" data-modal-backdrop>${modal ? renderModal() : ""}</div>
    <div class="toast" id="toast"></div>
  `;
  bindEvents();
}

function currentViewTitle() {
  return {
    home: "今日の空き時間",
    week: "週間スケジュール",
    tasks: "課題",
    templates: "テンプレート",
    stats: "集計"
  }[currentView];
}

function renderViews() {
  return `
    <section class="view ${currentView === "home" ? "active" : ""}">${renderHome()}</section>
    <section class="view ${currentView === "week" ? "active" : ""}">${renderWeek()}</section>
    <section class="view ${currentView === "tasks" ? "active" : ""}">${renderTasks()}</section>
    <section class="view ${currentView === "templates" ? "active" : ""}">${renderTemplates()}</section>
    <section class="view ${currentView === "stats" ? "active" : ""}">${renderStats()}</section>
  `;
}

function renderHome() {
  const plans = plansOn(today);
  const onPlans = plans.filter(plan => plan.kind === "on");
  const upcoming = upcomingPlan();
  const free = nextFreeInterval();
  const urgentTasks = state.tasks
    .filter(task => !task.isCompleted)
    .sort((a, b) => new Date(a.deadline || "2999-01-01") - new Date(b.deadline || "2999-01-01"))
    .slice(0, 2);

  return `
    <div class="dashboard">
      <div class="card hero-card">
        <div class="hero-copy">
          <div class="metric-label">今日の空き時間</div>
          <div class="metric-value">${durationText(freeMinutesOn(today))}</div>
          <p class="muted">${upcoming ? `次は ${timeText(upcoming.start)} の「${escapeHtml(upcoming.title)}」です。` : "この後の未開始予定はありません。"}</p>
        </div>
        <div class="next-card">
          <div class="metric-label">次に使える空き枠</div>
          <strong>${free ? `${timeText(free.start)}–${timeText(free.end)}` : "なし"}</strong>
          <span>${free ? durationText(minutesBetween(free.start, free.end)) : "今日はすべて埋まっています"}</span>
          ${free ? `<button class="button primary compact" data-action="add-plan-from-free" data-start="${free.start.toISOString()}" data-end="${free.end.toISOString()}">この枠に予定を入れる</button>` : ""}
        </div>
        <div class="mini-stats">
          <div><span>${plans.length}</span><small>予定</small></div>
          <div><span>${onPlans.length}</span><small>ON</small></div>
          <div><span>${urgentTasks.length}</span><small>締切近め</small></div>
        </div>
      </div>
      <div class="card timeline-card">
        <div class="section-title"><h2>今日</h2><span class="small muted">空き時間をタップして予定追加</span></div>
        ${renderHourScale()}
        ${renderTimeline(today, plans, "today", "desktop-main")}
      </div>
      <div class="card flat">
        <div class="section-title"><h2>今日の予定</h2><button class="button" data-action="add-plan">予定を追加</button></div>
        ${renderPlanList(onPlans.length ? onPlans : plans)}
      </div>
      <div class="card flat">
        <div class="section-title"><h2>締切が近い課題</h2><button class="button" data-action="add-task">課題を追加</button></div>
        ${urgentTasks.length ? urgentTasks.map(renderTaskRow).join("") : `<div class="empty">未完了の課題はありません</div>`}
      </div>
    </div>
  `;
}

function renderWeek() {
  const dates = weekDates(today);
  const totalFree = dates.reduce((sum, date) => sum + freeMinutesOn(date), 0);
  const totalOn = dates.reduce((sum, date) => sum + plannedMinutesOn(date, "on"), 0);
  const busiest = [...dates].sort((a, b) => freeMinutesOn(a) - freeMinutesOn(b))[0];
  return `
    <div class="card">
      <div class="section-title">
        <h2>週間</h2>
        <span class="small muted">各日の空き時間をクリックすると、その連続空き時間で予定追加します</span>
      </div>
      <div class="week-summary">
        <div><span>${durationText(totalFree)}</span><small>週の空き時間</small></div>
        <div><span>${durationText(totalOn)}</span><small>ON予定</small></div>
        <div><span>${dateText(busiest)}</span><small>一番埋まっている日</small></div>
      </div>
      <div class="week-grid">
        ${dates.map((date, index) => `
          <div class="week-day">
            <div class="week-label">
              <span>${dateText(date)}</span>
              <span>空き ${durationText(freeMinutesOn(date))}</span>
            </div>
            ${renderTimeline(date, plansOn(date), `week-${index}`, "tall")}
          </div>
        `).join("")}
      </div>
    </div>
  `;
}

function renderTasks() {
  const tasks = [...state.tasks].sort((a, b) => Number(a.isCompleted) - Number(b.isCompleted));
  return `
    <div class="card">
      <div class="section-title"><h2>課題</h2><button class="button primary" data-action="add-task">課題を追加</button></div>
      <div class="list">
        ${tasks.length ? tasks.map(renderTaskRow).join("") : `<div class="empty">課題はありません</div>`}
      </div>
    </div>
  `;
}

function renderTemplates() {
  const templates = [...state.templates].sort((a, b) => (a.title || "").localeCompare(b.title || "", "ja"));
  return `
    <div class="card">
      <div class="section-title"><h2>テンプレート</h2></div>
      ${templates.length ? `
        <div class="list">
          ${templates.map(template => `
            <div class="row template-row">
              <span class="row-main">
                <span class="row-title">${escapeHtml(template.title)}</span>
                <span class="row-meta">${weekdayText(template.weekdays)} ・ ${template.items?.length ?? 0}件 ・ ${template.automaticallyApplies ? "自動適用" : "手動"}</span>
              </span>
            </div>
          `).join("")}
        </div>
      ` : `
        <div class="empty">
          テンプレートはまだありません。<br />
          iOS版バックアップを読み込むと、登録済みテンプレートも表示されます。
        </div>
      `}
    </div>
  `;
}

function renderStats() {
  const todayOn = plansOn(today).filter(plan => plan.kind === "on")
    .reduce((sum, plan) => sum + minutesBetween(plan.start, plan.end), 0);
  const todayOff = plansOn(today).filter(plan => plan.kind === "off")
    .reduce((sum, plan) => sum + minutesBetween(plan.start, plan.end), 0);
  const incomplete = state.tasks.filter(task => !task.isCompleted).length;
  return `
    <div class="card">
      <div class="section-title"><h2>集計</h2></div>
      <div class="stat-grid">
        <div class="stat-card"><div class="muted small">今日のON</div><div class="stat-number">${durationText(todayOn)}</div></div>
        <div class="stat-card"><div class="muted small">今日のOFF</div><div class="stat-number">${durationText(todayOff)}</div></div>
        <div class="stat-card"><div class="muted small">今日の空き</div><div class="stat-number">${durationText(freeMinutesOn(today))}</div></div>
        <div class="stat-card"><div class="muted small">未完了課題</div><div class="stat-number">${incomplete}件</div></div>
      </div>
    </div>
  `;
}

function weekDates(date) {
  const d = startOfDay(date);
  const day = d.getDay() || 7;
  const monday = addMinutes(d, -(day - 1) * 1440);
  return Array.from({ length: 7 }, (_, i) => addMinutes(monday, i * 1440));
}

function weekdayText(weekdays = []) {
  const labels = { 1: "日", 2: "月", 3: "火", 4: "水", 5: "木", 6: "金", 7: "土" };
  if (!weekdays.length) return "曜日未設定";
  return weekdays.map(day => labels[day] ?? day).join("・");
}

function renderHourScale() {
  return `<div class="hour-scale">${[0, 6, 12, 18, 24].map(h => `<span style="left:${h / 24 * 100}%">${h}:00</span>`).join("")}</div>`;
}

function renderTimeline(date, plans, id, extraClass = "") {
  const dayStart = startOfDay(date);
  const items = plans.map(plan => {
    const start = Math.max(new Date(plan.start), dayStart);
    const end = Math.min(new Date(plan.end), addMinutes(dayStart, 1440));
    const left = minutesSinceDayStart(start, dayStart) / 1440 * 100;
    const width = Math.max(0.4, (minutesSinceDayStart(end, dayStart) - minutesSinceDayStart(start, dayStart)) / 1440 * 100);
    const compact = width < 10;
    const compactLabel = Array.from(plan.title || "予定").slice(0, 2).join("");
    return `
      <button class="plan-block ${plan.kind === "off" ? "off" : ""} ${compact ? "compact-plan" : ""}"
        data-action="edit-plan"
        data-plan-id="${plan.id}"
        title="${escapeAttr(`${plan.title} ${timeText(plan.start)}–${timeText(plan.end)}`)}"
        style="left:${left}%;width:${width}%;background:${plan.kind === "off" ? "" : planColors[plan.color]}">
        <span>${escapeHtml(compact ? compactLabel : plan.title)}</span>
        ${compact ? "" : `<small>${timeText(plan.start)}–${timeText(plan.end)}</small>`}
      </button>
    `;
  }).join("");

  return `
    <div class="timeline ${extraClass}" data-action="timeline-click" data-date="${date.toISOString()}" data-timeline-id="${id}">
      ${[6, 12, 18].map(h => `<div class="grid-line" style="left:${h / 24 * 100}%"></div>`).join("")}
      ${items}
    </div>
  `;
}

function renderPlanList(plans) {
  if (!plans.length) return `<div class="empty">予定はありません</div>`;
  return `<div class="list">${plans.map(plan => `
    <button class="row" data-action="edit-plan" data-plan-id="${plan.id}">
      <span class="color-bar" style="background:${plan.kind === "off" ? "#475569" : planColors[plan.color]}"></span>
      <span class="row-main">
        <span class="row-title">${escapeHtml(plan.title)}</span>
        <span class="row-meta">${timeText(plan.start)}–${timeText(plan.end)} ・ ${plan.kind.toUpperCase()}</span>
      </span>
      <span class="muted">›</span>
    </button>
  `).join("")}</div>`;
}

function renderTaskRow(task) {
  const scheduled = scheduledMinutesForTask(task.id);
  const remaining = Math.max(0, task.estimatedMinutes - task.completedMinutes - scheduled);
  return `
    <button class="row" data-action="edit-task" data-task-id="${task.id}">
      <span class="color-bar" style="background:${planColors[task.color]}"></span>
      <span class="row-main">
        <span class="row-title">${escapeHtml(task.title)}${task.isCompleted ? " ✓" : ""}</span>
        <span class="row-meta">${escapeHtml(task.category || "未分類")} ・ 残り ${durationText(remaining)} ・ ${task.deadline ? dateText(task.deadline) : "無期限"}</span>
      </span>
      <span class="muted">›</span>
    </button>
  `;
}

function renderTabs(position = "bottom") {
  const labels = { home: "ホーム", week: "週間", tasks: "課題", templates: "テンプレート", stats: "集計" };
  return `<nav class="tabs ${position === "side" ? "side-tabs" : "bottom-tabs"}">${views.map(view => `<button class="tab ${currentView === view ? "active" : ""}" data-view="${view}">${labels[view]}</button>`).join("")}</nav>`;
}

function viewFromHash() {
  const hash = location.hash.replace("#", "");
  return views.includes(hash) ? hash : "home";
}

function renderModal() {
  if (modal.type === "plan") return renderPlanModal(modal.plan, modal.initialInterval);
  if (modal.type === "task") return renderTaskModal(modal.task);
  return "";
}

function renderPlanModal(plan, initialInterval) {
  const isEdit = Boolean(plan);
  const defaultStart = initialInterval?.start ?? addMinutes(today, 18 * 60);
  const defaultEnd = initialInterval?.end ?? addMinutes(defaultStart, 60);
  const data = plan ?? makePlan("", defaultStart, defaultEnd, "on", "blue");
  return `
    <form class="modal" data-form="plan">
      <div class="modal-head">
        <h2>${isEdit ? "予定を編集" : "予定を追加"}</h2>
        <button type="button" class="button" data-action="close-modal">閉じる</button>
      </div>
      <input type="hidden" name="id" value="${data.id}" />
      <div class="form">
        <div class="segmented">
          <button type="button" data-kind="on" class="${data.kind === "on" ? "active" : ""}">ON</button>
          <button type="button" data-kind="off" class="${data.kind === "off" ? "active" : ""}">OFF</button>
        </div>
        <input type="hidden" name="kind" value="${data.kind}" />
        <div class="field"><label>タイトル</label><input name="title" value="${escapeAttr(data.title)}" placeholder="予定" /></div>
        <div class="split">
          <div class="field"><label>開始</label><input type="datetime-local" step="300" name="start" value="${dateInputValue(data.start)}" /></div>
          <div class="field"><label>終了</label><input type="datetime-local" step="300" name="end" value="${dateInputValue(data.end)}" /></div>
        </div>
        <div class="field">
          <label>未完了の課題から選ぶ</label>
          <select name="taskID">
            <option value="">選択しない</option>
            ${state.tasks.filter(t => !t.isCompleted || t.id === data.taskID).map(task => `<option value="${task.id}" ${task.id === data.taskID ? "selected" : ""}>${escapeHtml(task.title)}</option>`).join("")}
          </select>
        </div>
        <div class="field">
          <label>色</label>
          <div class="color-grid">
            ${colorNames.map(color => `<button type="button" class="color-dot ${data.color === color ? "active" : ""}" data-color="${color}" style="background:${planColors[color]}" aria-label="${color}"></button>`).join("")}
          </div>
          <input type="hidden" name="color" value="${data.color}" />
        </div>
        <div class="field"><label>メモ</label><textarea name="memo" rows="3">${escapeHtml(data.memo || "")}</textarea></div>
      </div>
      <div class="modal-actions">
        <div>${isEdit ? `<button type="button" class="button danger" data-action="delete-plan" data-plan-id="${data.id}">削除</button>` : ""}</div>
        <button class="button primary" type="submit">${isEdit ? "保存" : "追加"}</button>
      </div>
    </form>
  `;
}

function renderTaskModal(task) {
  const isEdit = Boolean(task);
  const data = task ?? makeTask("", "", null, 60, 1, nextTaskColor());
  return `
    <form class="modal" data-form="task">
      <div class="modal-head">
        <h2>${isEdit ? "課題を編集" : "課題を追加"}</h2>
        <button type="button" class="button" data-action="close-modal">閉じる</button>
      </div>
      <input type="hidden" name="id" value="${data.id}" />
      <div class="form">
        <div class="field"><label>タイトル</label><input name="title" value="${escapeAttr(data.title)}" placeholder="課題" /></div>
        <div class="split">
          <div class="field"><label>カテゴリ</label><input name="category" value="${escapeAttr(data.category || "")}" placeholder="学習" /></div>
          <div class="field"><label>見積もり（分）</label><input type="number" min="5" step="5" name="estimatedMinutes" value="${data.estimatedMinutes}" /></div>
        </div>
        <div class="split">
          <div class="field"><label>完了済み（分）</label><input type="number" min="0" step="5" name="completedMinutes" value="${data.completedMinutes || 0}" /></div>
          <div class="field"><label>締切</label><input type="datetime-local" step="300" name="deadline" value="${data.deadline ? dateInputValue(data.deadline) : ""}" /></div>
        </div>
        <div class="field">
          <label>状態</label>
          <select name="isCompleted">
            <option value="false" ${!data.isCompleted ? "selected" : ""}>未完了</option>
            <option value="true" ${data.isCompleted ? "selected" : ""}>完了</option>
          </select>
        </div>
      </div>
      <div class="modal-actions">
        <div>${isEdit ? `<button type="button" class="button danger" data-action="delete-task" data-task-id="${data.id}">削除</button>` : ""}</div>
        <button class="button primary" type="submit">${isEdit ? "保存" : "追加"}</button>
      </div>
    </form>
  `;
}

function nextTaskColor() {
  const active = state.tasks.filter(task => !task.isCompleted).map(task => task.color);
  return colorNames.find(color => !active.includes(color)) ?? "blue";
}

function bindEvents() {
  document.querySelectorAll("[data-view]").forEach(button => {
    button.addEventListener("click", () => {
      currentView = button.dataset.view;
      if (location.hash !== `#${currentView}`) {
        history.pushState(null, "", `#${currentView}`);
      }
      render();
    });
  });

  document.querySelectorAll("[data-action]").forEach(el => {
    el.addEventListener("click", event => {
      const action = el.dataset.action;
      if (action === "add-plan") openPlanModal();
      if (action === "add-plan-from-free") {
        openPlanModal(null, { start: new Date(el.dataset.start), end: new Date(el.dataset.end) });
      }
      if (action === "add-task") openTaskModal();
      if (action === "edit-plan") {
        event.stopPropagation();
        openPlanModal(state.plans.find(plan => plan.id === el.dataset.planId));
      }
      if (action === "edit-task") openTaskModal(state.tasks.find(task => task.id === el.dataset.taskId));
      if (action === "close-modal") closeModal();
      if (action === "delete-plan") deletePlan(el.dataset.planId);
      if (action === "delete-task") deleteTask(el.dataset.taskId);
      if (action === "export") exportBackup();
      if (action === "timeline-click") handleTimelineClick(event, el);
    });
  });

  document.querySelector('[data-action="import"]')?.addEventListener("change", importBackupFromInput);

  document.querySelector("[data-modal-backdrop]")?.addEventListener("click", event => {
    if (event.target.matches("[data-modal-backdrop]")) closeModal();
  });

  document.querySelectorAll("[data-kind]").forEach(button => {
    button.addEventListener("click", () => {
      const form = button.closest("form");
      form.kind.value = button.dataset.kind;
      form.querySelectorAll("[data-kind]").forEach(item => item.classList.toggle("active", item === button));
    });
  });

  document.querySelectorAll("[data-color]").forEach(button => {
    button.addEventListener("click", () => {
      const form = button.closest("form");
      form.color.value = button.dataset.color;
      form.querySelectorAll("[data-color]").forEach(item => item.classList.toggle("active", item === button));
    });
  });

  document.querySelector('[data-form="plan"]')?.addEventListener("submit", savePlanFromForm);
  document.querySelector('[data-form="task"]')?.addEventListener("submit", saveTaskFromForm);
}

window.addEventListener("hashchange", () => {
  currentView = viewFromHash();
  render();
});

function handleTimelineClick(event, el) {
  if (event.target.closest(".plan-block")) return;
  const rect = el.getBoundingClientRect();
  const fraction = Math.min(1, Math.max(0, (event.clientX - rect.left) / rect.width));
  const minute = Math.min(1435, Math.floor((fraction * 1440) / 5) * 5);
  const date = new Date(el.dataset.date);
  const dayStart = startOfDay(date);
  const selectedDate = addMinutes(dayStart, minute);
  const isBusy = plansOn(date).some(plan => selectedDate >= new Date(plan.start) && selectedDate < new Date(plan.end));
  if (isBusy) return;
  openPlanModal(null, freeIntervalContaining(date, selectedDate));
}

function openPlanModal(plan = null, initialInterval = null) {
  modal = { type: "plan", plan, initialInterval };
  render();
}

function openTaskModal(task = null) {
  modal = { type: "task", task };
  render();
}

function closeModal() {
  modal = null;
  render();
}

function savePlanFromForm(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const start = fromDateInput(form.start.value);
  const end = fromDateInput(form.end.value);
  if (!(end > start)) {
    toast("終了は開始より後にしてください");
    return;
  }
  const selectedTask = state.tasks.find(task => task.id === form.taskID.value);
  const plan = {
    id: form.id.value,
    title: (form.title.value.trim() || (form.kind.value === "on" ? "予定" : "予定あり")),
    start: start.toISOString(),
    end: end.toISOString(),
    kind: form.kind.value,
    color: selectedTask?.color ?? form.color.value,
    memo: form.memo.value,
    taskID: form.kind.value === "on" ? (form.taskID.value || null) : null
  };
  const index = state.plans.findIndex(item => item.id === plan.id);
  if (index >= 0) state.plans[index] = plan;
  else state.plans.push(plan);
  saveState();
  closeModal();
}

function saveTaskFromForm(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const task = {
    id: form.id.value,
    title: form.title.value.trim() || "課題",
    category: form.category.value.trim() || "未分類",
    deadline: form.deadline.value ? fromDateInput(form.deadline.value).toISOString() : null,
    estimatedMinutes: Number(form.estimatedMinutes.value || 60),
    completedMinutes: Number(form.completedMinutes.value || 0),
    priority: 1,
    color: state.tasks.find(t => t.id === form.id.value)?.color ?? nextTaskColor(),
    memo: "",
    isCompleted: form.isCompleted.value === "true"
  };
  const index = state.tasks.findIndex(item => item.id === task.id);
  if (index >= 0) state.tasks[index] = task;
  else state.tasks.push(task);
  state.plans.forEach(plan => {
    if (plan.taskID === task.id) {
      plan.title = task.title;
      plan.color = task.color;
    }
  });
  saveState();
  closeModal();
}

function deletePlan(id) {
  if (!confirm("この予定を削除しますか？")) return;
  state.plans = state.plans.filter(plan => plan.id !== id);
  saveState();
  closeModal();
}

function deleteTask(id) {
  if (!confirm("この課題と紐づく予定を削除しますか？")) return;
  state.tasks = state.tasks.filter(task => task.id !== id);
  state.plans = state.plans.filter(plan => plan.taskID !== id);
  saveState();
  closeModal();
}

function exportBackup() {
  const blob = new Blob([JSON.stringify(state, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `FreeTime-web-backup-${new Date().toISOString().slice(0, 10)}.json`;
  a.click();
  URL.revokeObjectURL(url);
}

async function importBackupFromInput(event) {
  const file = event.currentTarget.files?.[0];
  if (!file) return;
  try {
    const json = JSON.parse(await file.text());
    state = normalizeImportedState(json);
    saveState();
    closeModal();
    toast("既存データを読み込みました");
    render();
  } catch (error) {
    toast("読み込みに失敗しました");
    console.error(error);
  } finally {
    event.currentTarget.value = "";
  }
}

function normalizeImportedState(input) {
  const payload = input?.payload ?? input;
  const plans = Array.isArray(payload?.plans) ? payload.plans.map(normalizePlan) : [];
  const tasks = Array.isArray(payload?.tasks) ? payload.tasks.map(normalizeTask) : [];
  const templates = Array.isArray(payload?.templates) ? payload.templates.map(normalizeTemplate) : [];
  return { plans, tasks, templates };
}

function normalizePlan(plan) {
  return {
    id: stringID(plan.id),
    title: plan.title ?? "予定",
    start: normalizeDate(plan.start),
    end: normalizeDate(plan.end),
    kind: plan.kind === "OFF" || plan.kind === "off" ? "off" : "on",
    color: normalizeColor(plan.color),
    memo: plan.memo ?? "",
    taskID: plan.taskID ? stringID(plan.taskID) : null,
    sourceTemplateID: plan.sourceTemplateID ? stringID(plan.sourceTemplateID) : null,
    sourceTemplateItemID: plan.sourceTemplateItemID ? stringID(plan.sourceTemplateItemID) : null
  };
}

function normalizeTask(task) {
  return {
    id: stringID(task.id),
    title: task.title ?? "課題",
    category: task.category ?? "未分類",
    deadline: task.deadline ? normalizeDate(task.deadline) : null,
    estimatedMinutes: Number(task.estimatedMinutes ?? 60),
    completedMinutes: Number(task.completedMinutes ?? 0),
    priority: Number(task.priority ?? 1),
    color: normalizeColor(task.color),
    memo: task.memo ?? "",
    isCompleted: Boolean(task.isCompleted)
  };
}

function normalizeTemplate(template) {
  return {
    id: stringID(template.id),
    title: template.title ?? "テンプレート",
    weekdays: Array.isArray(template.weekdays) ? template.weekdays : [],
    items: Array.isArray(template.items) ? template.items.map(item => ({
      id: stringID(item.id),
      title: item.title ?? "予定",
      startMinute: Number(item.startMinute ?? 0),
      endMinute: Number(item.endMinute ?? 60),
      kind: item.kind === "ON" || item.kind === "on" ? "on" : "off",
      color: normalizeColor(item.color)
    })) : [],
    automaticallyApplies: template.automaticallyApplies !== false
  };
}

function normalizeDate(value) {
  if (typeof value === "string") return new Date(value).toISOString();
  if (typeof value === "number") {
    // Swift JSONEncoder の標準 Date は 2001-01-01 00:00:00 UTC からの秒数。
    return new Date(APPLE_REFERENCE_DATE_MS + value * 1000).toISOString();
  }
  return new Date().toISOString();
}

function normalizeColor(color) {
  return colorNames.includes(color) ? color : "blue";
}

function stringID(value) {
  if (!value) return uuid();
  if (typeof value === "string") return value;
  if (value.uuidString) return value.uuidString;
  return String(value);
}

function toast(message) {
  const el = document.querySelector("#toast");
  el.textContent = message;
  el.classList.add("active");
  setTimeout(() => el.classList.remove("active"), 2200);
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function escapeAttr(value) {
  return escapeHtml(value).replaceAll("'", "&#39;");
}

render();
