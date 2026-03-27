'use strict';
// ═══════════════════════════════════════════════
// مصاريفي — SPA JavaScript
// ═══════════════════════════════════════════════

const API = '/api/v1';

// ── State ────────────────────────────────────────────────────
const S = {
  token:        localStorage.getItem('access_token'),
  refreshToken: localStorage.getItem('refresh_token'),
  user:         JSON.parse(localStorage.getItem('user') || 'null'),
  categories:   [],
  budgets:      [],
  wallets:      [],
  expPage:      1,
  expTotal:     0,
  expView:      'sector', // 'sector' | 'date'
  charts:       {},   // keyed chart instances
  recording:    false,
  mediaRec:     null,
  audioChunks:  [],
};

// ── Utilities ────────────────────────────────────────────────
function loading(on) {
  document.getElementById('loading-overlay').classList.toggle('on', on);
}

function toast(msg, type = 'ok') {
  const el = document.getElementById('app-toast');
  el.className = `toast align-items-center border-0 t-${type}`;
  document.getElementById('toast-msg').textContent = msg;
  bootstrap.Toast.getOrCreateInstance(el, { delay: 3200 }).show();
}

function fmt(amount, currency) {
  const cur = currency || S.user?.currency || 'IQD';
  const n = parseFloat(amount) || 0;
  return n.toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 0 }) + ' ' + cur;
}

// ── Smart Money Input ─────────────────────────────────────────
// Always shows "xxx,000" — user types before the fixed 000 suffix.
function initMoneyInput(el) {
  if (!el || el.dataset.moneyInit) return;
  el.dataset.moneyInit = '1';
  el.setAttribute('inputmode', 'numeric');
  el.setAttribute('autocomplete', 'off');

  let baseDigits = ''; // digits the user typed (without the trailing 000)

  function cursorPos() {
    // Position cursor right after the formatted base part (before the ,00)
    if (!baseDigits) return 0;
    return parseInt(baseDigits, 10).toLocaleString('en-US').length;
  }

  function applyDisplay() {
    if (!baseDigits) { el.value = ''; return; }
    el.value = (parseInt(baseDigits, 10) * 100).toLocaleString('en-US');
    // Place cursor between typed digits and the trailing 00
    const pos = cursorPos();
    requestAnimationFrame(() => el.setSelectionRange(pos, pos));
  }

  function rawValue() {
    return baseDigits ? parseInt(baseDigits, 10) * 100 : 0;
  }

  el.addEventListener('keydown', (e) => {
    if (['ArrowLeft', 'ArrowRight', 'Tab', 'Home', 'End'].includes(e.key)) return;

    if (e.key === 'Backspace' || e.key === 'Delete') {
      e.preventDefault();
      baseDigits = baseDigits.slice(0, -1);
      applyDisplay();
      return;
    }

    if (!/^[0-9]$/.test(e.key)) { e.preventDefault(); return; }
    e.preventDefault();

    if (baseDigits === '' && e.key === '0') return; // no leading zero
    if (baseDigits.length >= 9) return;

    baseDigits += e.key;
    applyDisplay();
  });

  // Always snap cursor back to divider position on click/focus
  el.addEventListener('click', () => {
    if (baseDigits) {
      const pos = cursorPos();
      requestAnimationFrame(() => el.setSelectionRange(pos, pos));
    }
  });

  el.addEventListener('paste', (e) => {
    e.preventDefault();
    const text = (e.clipboardData || window.clipboardData).getData('text');
    const digits = text.replace(/[^0-9]/g, '').replace(/^0+/, '').slice(0, 9);
    if (digits) { baseDigits = digits; applyDisplay(); }
  });

  el.addEventListener('focus', () => {
    // Load existing value when in edit mode
    const current = parseInt(el.value.replace(/,/g, ''), 10);
    if (current && current % 100 === 0) {
      baseDigits = String(current / 100);
    } else if (current) {
      baseDigits = String(current);
    }
    if (baseDigits) requestAnimationFrame(() => {
      const pos = cursorPos();
      el.setSelectionRange(pos, pos);
    });
  });

  el._getRaw = rawValue;
  el._setVal = (n) => { baseDigits = n ? String(Math.round(n / 100)) : ''; applyDisplay(); };
}

function initMoneyInputs(selector) {
  document.querySelectorAll(selector || '[data-money]').forEach(initMoneyInput);
}

function getRaw(idOrEl) {
  const el = typeof idOrEl === 'string' ? document.getElementById(idOrEl) : idOrEl;
  if (!el) return 0;
  if (el._getRaw) return el._getRaw();
  return parseFloat(el.value.replace(/,/g, '')) || 0;
}

function fmtDate(s) {
  if (!s) return '';
  var d = new Date(s);
  return d.getFullYear() + '-' + (d.getMonth() + 1) + '-' + d.getDate();
}

function today() { return new Date().toISOString().split('T')[0]; }

function catById(id) {
  return S.categories.find(c => c.id === id) || { icon: '💸', name_ar: 'أخرى', sector: 'أخرى' };
}

function destroyChart(key) {
  if (S.charts[key]) { S.charts[key].destroy(); delete S.charts[key]; }
}

// ── API Client ───────────────────────────────────────────────
async function api(method, path, body = null, formData = false) {
  const headers = {};
  if (S.token) headers['Authorization'] = `Bearer ${S.token}`;
  if (!formData) headers['Content-Type'] = 'application/json';

  const opts = { method, headers };
  if (body) opts.body = formData ? body : JSON.stringify(body);

  let res = await fetch(API + path, opts);

  if (res.status === 401 && S.refreshToken) {
    const ok = await tryRefresh();
    if (ok) {
      headers['Authorization'] = `Bearer ${S.token}`;
      res = await fetch(API + path, { ...opts, headers });
    } else { doLogout(); return null; }
  }

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail || 'حدث خطأ في الاتصال');
  }
  if (res.status === 204) return null;
  return res.json();
}

async function tryRefresh() {
  try {
    const res = await fetch(`${API}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: S.refreshToken }),
    });
    if (!res.ok) return false;
    const d = await res.json();
    S.token = d.access_token;
    if (d.refresh_token) S.refreshToken = d.refresh_token;
    localStorage.setItem('access_token', S.token);
    if (d.refresh_token) localStorage.setItem('refresh_token', d.refresh_token);
    return true;
  } catch(e) { return false; }
}

// ── Auth ─────────────────────────────────────────────────────
function showAuthTab(tab) {
  document.getElementById('auth-login').style.display    = tab === 'login'    ? '' : 'none';
  document.getElementById('auth-register').style.display = tab === 'register' ? '' : 'none';
  document.querySelectorAll('.auth-tab-btn').forEach(b => b.classList.remove('active'));
  document.getElementById(`tab-btn-${tab}`).classList.add('active');
}

async function doLogin() {
  const email = document.getElementById('l-email').value.trim();
  const pass  = document.getElementById('l-pass').value;
  if (!email || !pass) { toast('يرجى ملء جميع الحقول', 'err'); return; }

  loading(true);
  try {
    const res = await fetch(`${API}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password: pass }),
    });
    if (!res.ok) { const e = await res.json().catch(()=>({})); throw new Error(e.detail || 'بيانات خاطئة'); }
    const d = await res.json();
    await saveSession(d);
    initApp();
  } catch (e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

async function doRegister() {
  const name     = document.getElementById('r-name').value.trim();
  const email    = document.getElementById('r-email').value.trim();
  const pass     = document.getElementById('r-pass').value;
  const currency = document.getElementById('r-currency').value;
  if (!name || !email || !pass) { toast('يرجى ملء جميع الحقول', 'err'); return; }
  if (pass.length < 8) { toast('كلمة المرور يجب أن تكون 8 أحرف على الأقل', 'err'); return; }

  loading(true);
  try {
    const d = await api('POST', '/auth/register', { full_name: name, email, password: pass, currency, preferred_language: 'ar' });
    await saveSession(d);
    toast('تم إنشاء الحساب بنجاح 🎉');
    initApp();
  } catch (e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

async function saveSession(data) {
  S.token        = data.access_token;
  S.refreshToken = data.refresh_token;
  S.user         = data.user;
  localStorage.setItem('access_token', data.access_token);
  localStorage.setItem('refresh_token', data.refresh_token);
  localStorage.setItem('user', JSON.stringify(data.user));
}

function doLogout() {
  localStorage.removeItem('access_token');
  localStorage.removeItem('refresh_token');
  localStorage.removeItem('user');
  S.token = S.refreshToken = S.user = null;
  document.getElementById('auth-screen').style.display = '';
  document.getElementById('app-screen').style.display  = 'none';
  showAuthTab('login');
}

// ── App Init ─────────────────────────────────────────────────
async function initApp() {
  document.getElementById('auth-screen').style.display = 'none';
  document.getElementById('app-screen').style.display  = '';
  updateSidebarUser();
  await loadCategories();
  await loadWalletsData();
  const savedPage = localStorage.getItem('last_page') || location.hash.replace('#', '') || 'dashboard';
  const validPages = Object.keys(PAGE_TITLES);
  goTo(validPages.includes(savedPage) ? savedPage : 'dashboard');
}

function updateSidebarUser() {
  if (!S.user) return;
  const name = S.user.full_name || 'مستخدم';
  setText('s-name',  name);
  setText('s-email', S.user.email || '');
  setText('s-avatar', name.charAt(0));
  setText('dash-name', name);
  // Show admin link only for admins
  document.querySelectorAll('.admin-only').forEach(el => {
    el.style.display = S.user.is_admin ? '' : 'none';
  });
}

function setText(id, val) {
  const el = document.getElementById(id);
  if (el) el.textContent = val;
}

// ── Navigation ───────────────────────────────────────────────
const PAGE_TITLES = {
  'dashboard':       'لوحة التحكم',
  'expenses':        'المصاريف',
  'add-expense':     'إضافة مصروف',
  'categories':      'الفئات والميزانيات',
  'wallets':         'المحافظ',
  'voice-assistant': 'المساعد الصوتي',
  'statistics':      'الإحصائيات',
  'settings':        'الإعدادات',
  'admin-users':     'إدارة المستخدمين',
};

function goTo(page) {
  document.querySelectorAll('.pg').forEach(el => el.style.display = 'none');
  const pg = document.getElementById(`pg-${page}`);
  if (pg) pg.style.display = '';

  const el = document.getElementById('page-title');
  if (el) el.textContent = PAGE_TITLES[page] || '';

  document.querySelectorAll('.s-link').forEach(el => {
    el.classList.toggle('active', el.dataset.page === page);
  });

  closeSidebar();
  location.hash = page;
  localStorage.setItem('last_page', page);

  switch (page) {
    case 'dashboard':        loadDashboard(); break;
    case 'expenses':         loadExpenses();  break;
    case 'categories':       loadCategoriesPage(); break;
    case 'wallets':          loadWallets();   break;
    case 'voice-assistant':  initVoiceAssistant(); break;
    case 'statistics':       initStats();     break;
    case 'settings':         loadSettings();  break;
    case 'admin-users':      loadAdminUsers(); break;
  }
}

// ── Sidebar ──────────────────────────────────────────────────
function toggleSidebar() {
  document.getElementById('sidebar').classList.toggle('open');
  document.getElementById('sidebar-overlay').classList.toggle('on');
}
function closeSidebar() {
  document.getElementById('sidebar').classList.remove('open');
  document.getElementById('sidebar-overlay').classList.remove('on');
}

// ── Theme ────────────────────────────────────────────────────
function toggleTheme() {
  const isDark = document.body.classList.toggle('dark-theme');
  document.body.classList.toggle('light-theme', !isDark);
  localStorage.setItem('theme', isDark ? 'dark' : 'light');
  document.getElementById('theme-btn').innerHTML = isDark ? '<i class="fas fa-moon"></i>' : '<i class="fas fa-sun"></i>';
  const sw = document.getElementById('dark-toggle');
  if (sw) sw.checked = isDark;
}

// ── Categories ───────────────────────────────────────────────
async function loadCategories() {
  try { S.categories = await api('GET', '/categories') || []; }
  catch(e) { S.categories = []; }
  fillCatDropdown('f-cat',  true);
  fillCatDropdown('ae-cat', false);
}

function fillCatDropdown(id, withAll) {
  const el = document.getElementById(id);
  if (!el) return;
  const first = el.options[0]?.textContent;
  el.innerHTML = '';
  const opt0 = document.createElement('option');
  opt0.value = '';
  opt0.textContent = withAll ? 'كل الفئات' : 'بدون فئة';
  el.appendChild(opt0);
  S.categories.forEach(c => {
    const o = document.createElement('option');
    o.value = c.id;
    o.textContent = `${c.icon} ${c.name_ar}`;
    el.appendChild(o);
  });
}

// ── Dashboard ────────────────────────────────────────────────
async function loadDashboard() {
  const now = new Date();
  const dateStr = now.toLocaleDateString('ar-SA', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });
  const dashDate = document.getElementById('dash-date');
  if (dashDate) dashDate.textContent = dateStr;

  loading(true);
  try {
    const data = await api('GET', `/statistics/monthly?year=${now.getFullYear()}&month=${now.getMonth() + 1}`);
    const cats  = await api('GET', `/statistics/categories?year=${now.getFullYear()}&month=${now.getMonth() + 1}`);
    const daily = await api('GET', `/statistics/daily?target_date=${today()}`);
    const exps  = await api('GET', `/expenses?size=5`);

    const cur = S.user?.currency || 'IQD';

    // KPIs
    setText('kpi-month', fmt(data?.total || 0, cur));
    setText('kpi-today', fmt(daily?.total || 0, cur));
    setText('kpi-count', data?.count || 0);
    // (daily average removed from UI)

    // Recent expenses
    renderRecentExps(exps?.items || []);

    // Pie chart
    if (cats?.length) renderPie('dash-pie', cats);

  } catch (e) { console.error(e); }
  finally { loading(false); }
}

function renderRecentExps(items) {
  const el = document.getElementById('dash-recent');
  if (!items.length) { el.innerHTML = '<div class="empty-state"><i class="fas fa-receipt"></i><p>لا توجد مصاريف بعد</p></div>'; return; }
  el.innerHTML = items.map(expHtml).join('');
}

function expHtml(exp) {
  const cat = catById(exp.category_id);
  const walletInfo = exp.wallet ? ` · ${exp.wallet.icon} ${esc(exp.wallet.name)}` : '';
  return `<div class="exp-item">
    <div class="exp-icon">${cat.icon}</div>
    <div class="exp-info">
      <div class="exp-desc">${esc(exp.description || 'مصروف')}</div>
      <div class="exp-meta">${cat.name_ar} · ${fmtDate(exp.expense_date)}${walletInfo}</div>
    </div>
    <div class="exp-amt">−${fmt(exp.amount, exp.currency)}</div>
  </div>`;
}

// ── Expenses ─────────────────────────────────────────────────
async function loadExpenses() {
  const month = document.getElementById('f-month')?.value;
  const catId = document.getElementById('f-cat')?.value;
  const now   = new Date();
  const yr    = now.getFullYear();

  let url = `/expenses?page=${S.expPage}&size=15`;
  if (month) url += `&date_from=${yr}-${String(month).padStart(2,'0')}-01&date_to=${yr}-${String(month).padStart(2,'0')}-31`;
  if (catId) url += `&category_id=${catId}`;

  loading(true);
  try {
    const data = await api('GET', url);
    S.expTotal = data?.total || 0;
    renderExpList(data?.items || []);
    renderExpPagination(data);
  } catch (e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

function renderExpList(items) {
  const el = document.getElementById('exp-list');
  if (!items.length) {
    el.innerHTML = '<div class="empty-state"><i class="fas fa-receipt"></i><p>لا توجد مصاريف في هذه الفترة</p></div>';
    return;
  }
  if (S.expView === 'date') { renderExpByDate(items); return; }

  // Group by sector
  const sectors = {};
  items.forEach(exp => {
    const cat = catById(exp.category_id);
    const sector = cat.sector || 'أخرى';
    if (!sectors[sector]) sectors[sector] = { items: [], total: 0 };
    sectors[sector].items.push(exp);
    sectors[sector].total += parseFloat(exp.amount) || 0;
  });

  const cur = S.user?.currency || 'IQD';
  let html = '';
  for (const [sector, group] of Object.entries(sectors)) {
    html += `<div class="sector-group">
      <div class="sector-header">
        <span class="sector-name">${esc(sector)}</span>
        <span class="sector-total">${fmt(group.total, cur)}</span>
      </div>`;
    html += group.items.map(exp => {
      const cat = catById(exp.category_id);
      const walletInfo = exp.wallet ? `<span class="exp-wallet-badge">${exp.wallet.icon} ${esc(exp.wallet.name)}</span>` : '';
      return `<div class="exp-item" id="ei-${exp.id}">
        <div class="exp-icon">${cat.icon}</div>
        <div class="exp-info">
          <div class="exp-desc">${esc(exp.description || 'مصروف')}</div>
          <div class="exp-meta">${cat.name_ar} · ${fmtDate(exp.expense_date)}${exp.note ? ' · ' + esc(exp.note) : ''} ${walletInfo}</div>
        </div>
        <div class="exp-amt">−${fmt(exp.amount, exp.currency)}</div>
        <button class="exp-del" onclick="deleteExp('${exp.id}')" title="حذف"><i class="fas fa-trash-alt"></i></button>
      </div>`;
    }).join('');
    html += '</div>';
  }
  el.innerHTML = html;
}

function renderExpByDate(items) {
  const el  = document.getElementById('exp-list');
  const cur = S.user?.currency || 'IQD';

  // Group by date
  const days = {};
  items.forEach(exp => {
    const d = exp.expense_date?.split('T')[0] || exp.expense_date || '?';
    if (!days[d]) days[d] = { items: [], total: 0 };
    days[d].items.push(exp);
    days[d].total += parseFloat(exp.amount) || 0;
  });

  // Sort dates descending
  const sorted = Object.entries(days).sort((a, b) => b[0].localeCompare(a[0]));

  let html = '';
  for (const [date, group] of sorted) {
    const d = new Date(date);
    const label = d.toLocaleDateString('ar-IQ', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });
    html += `<div class="sector-group">
      <div class="sector-header">
        <span class="sector-name">${label}</span>
        <span class="sector-total">${fmt(group.total, cur)}</span>
      </div>`;
    html += group.items.map(exp => {
      const cat = catById(exp.category_id);
      const walletInfo = exp.wallet ? `<span class="exp-wallet-badge">${exp.wallet.icon} ${esc(exp.wallet.name)}</span>` : '';
      return `<div class="exp-item" id="ei-${exp.id}">
        <div class="exp-icon">${cat.icon}</div>
        <div class="exp-info">
          <div class="exp-desc">${esc(exp.description || 'مصروف')}</div>
          <div class="exp-meta">${cat.name_ar}${exp.note ? ' · ' + esc(exp.note) : ''} ${walletInfo}</div>
        </div>
        <div class="exp-amt">−${fmt(exp.amount, exp.currency)}</div>
        <button class="exp-del" onclick="deleteExp('${exp.id}')" title="حذف"><i class="fas fa-trash-alt"></i></button>
      </div>`;
    }).join('');
    html += '</div>';
  }
  el.innerHTML = html;
}

function setExpView(view) {
  S.expView = view;
  document.getElementById('btn-view-sector')?.classList.toggle('active', view === 'sector');
  document.getElementById('btn-view-date')?.classList.toggle('active', view === 'date');
  S.expPage = 1;
  loadExpenses();
}

function renderExpPagination(data) {  const pg  = document.getElementById('exp-pagination');
  const inf = document.getElementById('exp-page-info');
  const prv = document.getElementById('exp-prev');
  const nxt = document.getElementById('exp-next');
  if (!data || data.pages <= 1) { pg.style.display = 'none'; return; }
  pg.style.display = '';
  inf.textContent  = `صفحة ${data.page} من ${data.pages}`;
  prv.disabled = data.page <= 1;
  nxt.disabled = data.page >= data.pages;
}

function changePage(delta) {
  S.expPage = Math.max(1, S.expPage + delta);
  loadExpenses();
}

async function deleteExp(id) {
  if (!confirm('هل أنت متأكد من حذف هذا المصروف؟')) return;
  try {
    await api('DELETE', `/expenses/${id}`);
    document.getElementById(`ei-${id}`)?.remove();
    toast('تم الحذف');
  } catch (e) { toast(e.message, 'err'); }
}

// ── Add Expense Form ─────────────────────────────────────────
function prepareForm() {
  document.getElementById('ae-date').value = today();
  pickCurrency('IQD');
  fillCatDropdown('ae-cat', false);
  fillWalletDropdowns();
}

function toggleCurrencyPicker() {
  const el = document.getElementById('currency-picker');
  el.style.display = el.style.display === 'none' ? '' : 'none';
}

function pickCurrency(code) {
  document.getElementById('ae-currency').value = code;
  document.getElementById('ae-currency-label').textContent = code;
  document.querySelectorAll('.cur-chip').forEach(c => c.classList.toggle('active', c.dataset.cur === code));
  document.getElementById('currency-picker').style.display = 'none';
}

// ── Expense Drawer ──────────────────────────────────────────────────
function openExpenseDrawer() {
  closeSidebar();
  prepareForm();
  document.getElementById('expense-drawer-overlay').classList.add('open');
  document.getElementById('expense-drawer').classList.add('open');
  document.body.style.overflow = 'hidden';
  setTimeout(() => initMoneyInputs(), 50);
}

function closeExpenseDrawer() {
  document.getElementById('expense-drawer-overlay').classList.remove('open');
  document.getElementById('expense-drawer').classList.remove('open');
  document.body.style.overflow = '';
}

function refreshActivePage() {
  const dash = document.getElementById('pg-dashboard');
  if (dash && dash.style.display !== 'none') loadDashboard();
  const exp = document.getElementById('pg-expenses');
  if (exp && exp.style.display !== 'none') loadExpenses();
  const wal = document.getElementById('pg-wallets');
  if (wal && wal.style.display !== 'none') loadWallets();
  const stats = document.getElementById('pg-statistics');
  if (stats && stats.style.display !== 'none') initStats();
}

async function submitExpense(e) {
  e.preventDefault();
  const amount   = getRaw('ae-amount');
  const currency = document.getElementById('ae-currency').value;
  const catId    = document.getElementById('ae-cat').value;
  const walletId = document.getElementById('ae-wallet').value;
  const desc     = document.getElementById('ae-desc').value.trim();
  const date     = document.getElementById('ae-date').value;

  if (!amount || !date) { toast('يرجى ملء الحقول المطلوبة', 'err'); return; }

  loading(true);
  try {
    await api('POST', '/expenses', {
      amount, currency,
      category_id:  catId    || null,
      wallet_id:    walletId || null,
      description:  desc || null,
      expense_date: date,
      note:         null,
    });
    toast('تم إضافة المصروف ✅');
    document.getElementById('expense-form').reset();
    closeExpenseDrawer();
    await loadWalletsData();
    refreshActivePage();
  } catch (e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

// ── Voice Input ──────────────────────────────────────────────
async function toggleVoice() {
  if (S.recording) { stopVoice(); return; }
  if (!navigator.mediaDevices?.getUserMedia) { toast('المتصفح لا يدعم التسجيل الصوتي', 'err'); return; }
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    S.audioChunks = [];
    S.mediaRec = new MediaRecorder(stream);
    S.mediaRec.ondataavailable = e => S.audioChunks.push(e.data);
    S.mediaRec.onstop = sendVoice;
    S.mediaRec.start();
    S.recording = true;
    document.getElementById('voice-btn').classList.add('recording');
    document.getElementById('voice-ico').className = 'fas fa-stop';
    document.getElementById('voice-hint').textContent = 'جاري التسجيل... اضغط للإيقاف';
  } catch(e) { toast('لم نتمكن من الوصول للمايكروفون', 'err'); }
}

function stopVoice() {
  if (!S.mediaRec || !S.recording) return;
  S.mediaRec.stop();
  S.mediaRec.stream.getTracks().forEach(t => t.stop());
  S.recording = false;
  document.getElementById('voice-btn').classList.remove('recording');
  document.getElementById('voice-ico').className = 'fas fa-microphone';
  document.getElementById('voice-hint').textContent = 'جاري المعالجة...';
}

async function sendVoice() {
  const blob = new Blob(S.audioChunks, { type: 'audio/webm' });
  const fd   = new FormData();
  fd.append('audio', blob, 'rec.webm');
  loading(true);
  try {
    const data = await api('POST', '/voice/parse-expense', fd, true);
    showVoiceResult(data);
    document.getElementById('voice-hint').textContent = 'اضغط للتسجيل مجدداً';
  } catch (e) {
    toast(e.message, 'err');
    document.getElementById('voice-hint').textContent = 'اضغط للتسجيل وقُل مثل: "دفعت ألفين دينار على الأكل"';
  } finally { loading(false); }
}

function showVoiceResult(data) {
  const out = document.getElementById('voice-output');
  out.style.display = '';
  const items = data.parsed_expenses || [];
  if (!items.length) { out.innerHTML = `<p>النص: "${esc(data.transcript)}"</p><p class="text-muted">لم يتم التعرف على مصاريف.</p>`; return; }

  const item = items[0];   // use first parsed expense
  out.innerHTML = `
    <p class="mb-1"><strong>ما قلته:</strong> "${esc(data.transcript)}"</p>
    ${item.amount    ? `<p class="mb-1">💰 المبلغ: <strong>${item.amount} ${item.currency || ''}</strong></p>` : ''}
    ${item.description ? `<p class="mb-1">📝 الوصف: <strong>${esc(item.description)}</strong></p>` : ''}
    ${item.category_name ? `<p class="mb-2">📁 الفئة: <strong>${esc(item.category_name)}</strong></p>` : ''}
    <button class="btn btn-sm btn-primary" onclick='applyVoice(${JSON.stringify(item)})'>
      <i class="fas fa-check me-1"></i>تطبيق في النموذج
    </button>`;
}

function applyVoice(item) {
  if (item.amount)      document.getElementById('ae-amount').value = item.amount;
  if (item.description) document.getElementById('ae-desc').value   = item.description;
  if (item.expense_date) document.getElementById('ae-date').value  = item.expense_date;
  if (item.category_name) {
    const cat = S.categories.find(c =>
      c.name_ar.includes(item.category_name) || (c.name_en || '').toLowerCase().includes(item.category_name.toLowerCase())
    );
    if (cat) document.getElementById('ae-cat').value = cat.id;
  }
  toast('تم ملء البيانات من الصوت ✅');
  document.getElementById('voice-output').style.display = 'none';
}

// ── Voice Assistant (New Page) ───────────────────────────────
let vaRecognition = null;
let vaParsedItems = [];

function initVoiceAssistant() {
  const input = document.getElementById('va-text-input');
  if (input) {
    input.addEventListener('keydown', e => {
      if (e.key === 'Enter') { e.preventDefault(); vaSendText(); }
    });
  }
}

function vaAddMsg(text, isUser) {
  const chat = document.getElementById('va-chat');
  const div = document.createElement('div');
  div.className = `va-msg ${isUser ? 'va-user' : 'va-bot'}`;
  div.innerHTML = `<div class="va-bubble">${isUser ? esc(text) : text}</div>`;
  chat.appendChild(div);
  chat.scrollTop = chat.scrollHeight;
}

async function vaSendText() {
  const input = document.getElementById('va-text-input');
  const text = input.value.trim();
  if (!text) return;
  input.value = '';

  vaAddMsg(text, true);
  vaAddMsg('<span class="spinner-border spinner-border-sm me-2"></span>جاري التحليل...', false);

  try {
    const data = await api('POST', '/voice/parse-text', { text });
    // Remove loading msg
    const chat = document.getElementById('va-chat');
    chat.removeChild(chat.lastChild);

    if (data.parsed_expenses && data.parsed_expenses.length > 0) {
      vaParsedItems = data.parsed_expenses;
      const cur = S.user?.currency || 'IQD';
      let msg = `تم التعرف على <strong>${vaParsedItems.length}</strong> مصروف:<br>`;
      vaParsedItems.forEach((item, i) => {
        msg += `<div class="va-parsed-item mt-1">${i + 1}. ${esc(item.description || item.category_hint)} — <strong>${Number(item.amount).toLocaleString('ar-IQ')} ${item.currency || cur}</strong></div>`;
      });
      msg += `<br><small class="text-muted">راجع المصاريف في الأسفل ثم اضغط "حفظ الكل"</small>`;
      vaAddMsg(msg, false);
      vaShowResults(vaParsedItems);
    } else {
      vaAddMsg('لم أتمكن من التعرف على مصاريف من النص. حاول مرة أخرى بصيغة مثل: "أكل 5000 وتاكسي 3000"', false);
    }
  } catch (e) {
    const chat = document.getElementById('va-chat');
    if (chat.lastChild) chat.removeChild(chat.lastChild);
    vaAddMsg(`<span class="text-danger">حدث خطأ: ${esc(e.message)}</span>`, false);
  }
}

function vaShowResults(items) {
  const container = document.getElementById('va-results');
  const list = document.getElementById('va-items-list');
  const cur = S.user?.currency || 'IQD';

  list.innerHTML = items.map((item, i) => {
    const cat = S.categories.find(c =>
      c.name_ar === item.category_hint ||
      c.name_ar.includes(item.category_hint) ||
      (c.name_en || '').toLowerCase().includes((item.category_hint || '').toLowerCase())
    ) || { icon: '💸', name_ar: item.category_hint || 'أخرى', id: '' };

    return `<div class="va-result-item" id="va-item-${i}">
      <div class="va-result-icon">${cat.icon}</div>
      <div class="va-result-info">
        <div class="va-result-desc">${esc(item.description || item.category_hint)}</div>
        <div class="va-result-cat">${cat.name_ar} · ${item.expense_date || today()}</div>
      </div>
      <div class="va-result-amount">${Number(item.amount).toLocaleString('ar-IQ')} ${item.currency || cur}</div>
      <button class="va-result-del" onclick="vaRemoveItem(${i})" title="إزالة"><i class="fas fa-times"></i></button>
    </div>`;
  }).join('');

  container.style.display = '';
}

function vaRemoveItem(index) {
  vaParsedItems.splice(index, 1);
  if (vaParsedItems.length === 0) {
    vaClearResults();
    vaAddMsg('تم إلغاء جميع المصاريف.', false);
  } else {
    vaShowResults(vaParsedItems);
  }
}

function vaClearResults() {
  vaParsedItems = [];
  document.getElementById('va-results').style.display = 'none';
  document.getElementById('va-items-list').innerHTML = '';
}

async function vaConfirmAll() {
  if (!vaParsedItems.length) return;

  const cur = S.user?.currency || 'IQD';

  // Detect wallet from voice hint
  let walletHint = null;
  for (const item of vaParsedItems) {
    if (item.wallet_hint) { walletHint = item.wallet_hint; break; }
  }

  const expenses = vaParsedItems.map(item => {
    const cat = S.categories.find(c =>
      c.name_ar === item.category_hint ||
      c.name_ar.includes(item.category_hint) ||
      (c.name_en || '').toLowerCase().includes((item.category_hint || '').toLowerCase())
    );
    return {
      category_id: cat?.id || null,
      amount: item.amount,
      currency: item.currency || cur,
      description: item.description || item.category_hint || 'مصروف صوتي',
      expense_date: item.expense_date || today(),
    };
  });

  // Resolve wallet: hint > default > picker
  let walletId = null;
  if (walletHint) {
    const hw = findWalletByHint(walletHint);
    if (hw) walletId = hw.id;
  }
  if (!walletId) {
    const dw = getDefaultWallet();
    if (dw) walletId = dw.id;
  }
  if (!walletId && S.wallets.length > 0) {
    walletId = await showWalletPicker();
  }

  // Add wallet_id to all expenses
  expenses.forEach(e => e.wallet_id = walletId || null);

  loading(true);
  try {
    await api('POST', '/expenses/bulk', { expenses });
    const count = expenses.length;
    vaAddMsg(`تم حفظ <strong>${count}</strong> مصروف بنجاح! ✅`, false);
    toast(`تم حفظ ${count} مصروف ✅`);
    vaClearResults();
    await loadWalletsData();
    refreshActivePage();
  } catch (e) {
    vaAddMsg(`<span class="text-danger">فشل الحفظ: ${esc(e.message)}</span>`, false);
    toast(e.message, 'err');
  } finally { loading(false); }
}

// ── Voice Assistant: Speech Recognition ──────────────────────
function vaToggleMic() {
  if (vaRecognition) { vaStopMic(); return; }

  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!SpeechRecognition) {
    toast('المتصفح لا يدعم التعرف الصوتي. استخدم Chrome أو Edge.', 'err');
    return;
  }

  vaRecognition = new SpeechRecognition();
  vaRecognition.lang = 'ar';
  vaRecognition.continuous = false;
  vaRecognition.interimResults = true;
  vaRecognition.maxAlternatives = 1;

  const input = document.getElementById('va-text-input');
  const micBtn = document.getElementById('va-mic-btn');
  const micIco = document.getElementById('va-mic-ico');
  const micStatus = document.getElementById('va-mic-status');

  micBtn.classList.add('va-mic-active');
  micIco.className = 'fas fa-stop';
  micStatus.style.display = '';

  vaRecognition.onresult = (event) => {
    let transcript = '';
    for (let i = 0; i < event.results.length; i++) {
      transcript += event.results[i][0].transcript;
    }
    input.value = transcript;
  };

  vaRecognition.onend = () => {
    micBtn.classList.remove('va-mic-active');
    micIco.className = 'fas fa-microphone';
    micStatus.style.display = 'none';
    vaRecognition = null;
    // Auto-send if we got text
    if (input.value.trim()) vaSendText();
  };

  vaRecognition.onerror = (event) => {
    micBtn.classList.remove('va-mic-active');
    micIco.className = 'fas fa-microphone';
    micStatus.style.display = 'none';
    vaRecognition = null;
    if (event.error === 'no-speech') {
      toast('لم يتم التقاط أي كلام. حاول مرة أخرى.', 'err');
    } else if (event.error === 'not-allowed') {
      toast('الرجاء السماح بالوصول للمايكروفون.', 'err');
    } else {
      toast('خطأ في التعرف الصوتي: ' + event.error, 'err');
    }
  };

  vaRecognition.start();
}

function vaStopMic() {
  if (vaRecognition) {
    vaRecognition.stop();
  }
}

// ── Statistics ───────────────────────────────────────────────
function initStats() {
  const now = new Date();
  document.getElementById('st-month').value = now.getMonth() + 1;
  document.getElementById('st-year').value  = now.getFullYear();
  loadStats();
}

async function loadStats() {
  const month = document.getElementById('st-month').value;
  const year  = document.getElementById('st-year').value;

  loading(true);
  try {
    const [monthly, cats, trend] = await Promise.all([
      api('GET', `/statistics/monthly?year=${year}&month=${month}`),
      api('GET', `/statistics/categories?year=${year}&month=${month}`),
      api('GET', `/statistics/trend?year=${year}&month=${month}`),
    ]);

    const cur = S.user?.currency || 'IQD';
    setText('st-total', fmt(monthly?.total || 0, cur));

    if (cats?.length) {
      renderPie('st-pie', cats);
      renderCatBreakdown(cats, monthly?.total || 0);
    } else {
      destroyChart('st-pie');
      document.getElementById('st-cats').innerHTML = '<p class="text-muted text-center py-3">لا توجد بيانات</p>';
    }

    if (trend?.length) renderBar('st-bar', trend);
    else destroyChart('st-bar');

  } catch (e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

async function loadInsights() {
  const month = document.getElementById('st-month').value;
  const year  = document.getElementById('st-year').value;
  const el    = document.getElementById('st-insights');
  el.innerHTML = '<span class="spinner-border spinner-border-sm text-primary me-2"></span>جاري التحليل...';
  try {
    const data = await api('GET', `/statistics/insights?year=${year}&month=${month}`);
    const tips = data?.tips || 'لا توجد بيانات كافية للتحليل.';
    el.innerHTML = `<p style="white-space:pre-line;line-height:1.9">${esc(tips)}</p>`;
  } catch (e) { el.innerHTML = `<p class="text-danger">${esc(e.message)}</p>`; }
}

const CHART_COLORS = ['#6C63FF','#FF6B6B','#4ECDC4','#FFE66D','#A29BFE','#FD79A8','#00B894','#FDCB6E','#E17055','#74B9FF'];

function renderPie(canvasId, cats) {
  const key = canvasId;
  destroyChart(key);
  const ctx = document.getElementById(canvasId);
  if (!ctx) return;
  S.charts[key] = new Chart(ctx, {
    type: 'doughnut',
    data: {
      labels: cats.map(c => c.name_ar),
      datasets: [{ data: cats.map(c => c.total), backgroundColor: CHART_COLORS.slice(0, cats.length), borderWidth: 0 }],
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: { legend: { position: 'bottom', labels: { color: '#8888bb', font: { family: 'Cairo', size: 12 } } } },
    },
  });
}

function renderBar(canvasId, trend) {
  const key = canvasId;
  destroyChart(key);
  const ctx = document.getElementById(canvasId);
  if (!ctx) return;

  // Build a full-month map so every day shows (0 for days with no expenses)
  const cur = S.user?.currency || 'IQD';
  const firstDate = trend[0]?.date || trend[0]?.day || '';
  const refDate   = firstDate ? new Date(firstDate) : new Date();
  const year      = refDate.getFullYear();
  const month     = refDate.getMonth();
  const daysInMonth = new Date(year, month + 1, 0).getDate();

  const dayMap = {};
  trend.forEach(d => {
    const dateStr = d.date || d.day || '';
    const dayNum  = parseInt(dateStr.split('-')[2], 10);
    if (dayNum) dayMap[dayNum] = d.total;
  });

  const labels = [];
  const data   = [];
  for (let i = 1; i <= daysInMonth; i++) {
    labels.push(i);
    data.push(dayMap[i] || 0);
  }

  // Color each bar: grey if zero, purple if positive
  const colors = data.map(v => v > 0 ? 'rgba(108,99,255,.8)' : 'rgba(150,150,180,.25)');

  S.charts[key] = new Chart(ctx, {
    type: 'bar',
    data: {
      labels,
      datasets: [{
        label: 'الإنفاق اليومي',
        data,
        backgroundColor: colors,
        borderRadius: 5,
        borderSkipped: false,
      }],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            title: items => `اليوم ${items[0].label}`,
            label: item => fmt(item.raw, cur),
          },
          titleFont: { family: 'Cairo' },
          bodyFont:  { family: 'Cairo' },
        },
      },
      scales: {
        x: {
          ticks: { color: '#8888bb', font: { size: 10 }, maxRotation: 0 },
          grid:  { display: false },
          title: { display: false },
        },
        y: {
          ticks: { color: '#8888bb', callback: v => v >= 1000 ? (v/1000).toFixed(0)+'K' : v },
          grid:  { color: 'rgba(128,128,180,.1)' },
          beginAtZero: true,
        },
      },
    },
  });
}

function renderCatBreakdown(cats, total) {
  const el  = document.getElementById('st-cats');
  const cur = S.user?.currency || 'IQD';
  el.innerHTML = cats.map(c => {
    const pct      = total > 0 ? Math.min(Math.round((c.total / total) * 100), 100) : 0;
    const barClass = pct >= 100 ? 'over' : pct >= 80 ? 'warn' : '';
    return `<div class="mb-3">
      <div class="d-flex justify-content-between mb-1">
        <span>${c.icon || ''} ${c.name_ar}</span>
        <span class="text-muted small">${fmt(c.total, cur)} (${pct}%)</span>
      </div>
      <div class="progress"><div class="progress-bar ${barClass}" style="width:${pct}%"></div></div>
    </div>`;
  }).join('');
}

// ── Budgets ──────────────────────────────────────────────────
async function loadBudgets() {
  const now = new Date();
  loading(true);
  try {
    const data = await api('GET', `/budgets?year=${now.getFullYear()}&month=${now.getMonth() + 1}`);
    renderBudgets(data || []);
  } catch (e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

function renderBudgets(budgets) {
  const el  = document.getElementById('budgets-list');
  const cur = S.user?.currency || 'IQD';
  if (!budgets.length) {
    el.innerHTML = '<div class="empty-state"><i class="fas fa-wallet"></i><p>لا توجد ميزانيات لهذا الشهر<br><small>أضف ميزانية من الأعلى</small></p></div>';
    return;
  }
  el.innerHTML = `<div class="glass-card">${budgets.map(b => {
    const cat   = catById(b.category_id);
    const spent = parseFloat(b.spent) || 0;
    const limit = parseFloat(b.amount) || 1;
    const pct   = Math.min(Math.round((spent / limit) * 100), 100);
    const barCls = pct >= 100 ? 'over' : pct >= 75 ? 'warn' : '';
    return `<div class="budget-row">
      <div class="budget-hd">
        <span class="budget-name">${cat.icon} ${cat.name_ar}</span>
        <span class="budget-amts">${fmt(spent, cur)} / ${fmt(limit, cur)}</span>
      </div>
      <div class="progress"><div class="progress-bar ${barCls}" style="width:${pct}%"></div></div>
      <div class="budget-foot">
        <small class="text-muted">${pct}% مُنفق</small>
        <small class="${pct >= 100 ? 'text-danger' : 'text-muted'}">${pct >= 100 ? '⚠️ تجاوزت الحد' : 'متبقي: ' + fmt(limit - spent, cur)}</small>
      </div>
    </div>`;
  }).join('')}</div>`;
}

async function addBudget(e) {
  e.preventDefault();
  const catId  = document.getElementById('b-cat').value;
  const amount = parseFloat(document.getElementById('b-amount').value);
  if (!amount || amount <= 0) { toast('أدخل مبلغاً صحيحاً', 'err'); return; }

  const now = new Date();
  loading(true);
  try {
    await api('POST', '/budgets', {
      category_id: catId || null,
      amount,
      month: now.getMonth() + 1,
      year:  now.getFullYear(),
    });
    toast('تمت إضافة الميزانية ✅');
    document.getElementById('b-amount').value = '';
    loadBudgets();
  } catch (e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

// ── Wallets ──────────────────────────────────────────────────
async function loadWalletsData() {
  try { S.wallets = await api('GET', '/wallets') || []; }
  catch(e) { S.wallets = []; }
  fillWalletDropdowns();
}

function fillWalletDropdowns() {
  ['ae-wallet', 'inc-wallet', 'tr-from', 'tr-to'].forEach(id => {
    const el = document.getElementById(id);
    if (!el) return;
    const isForm = id === 'ae-wallet';
    el.innerHTML = '';
    if (isForm) {
      const opt0 = document.createElement('option');
      opt0.value = '';
      opt0.textContent = 'بدون محفظة';
      el.appendChild(opt0);
    }
    S.wallets.forEach(w => {
      const o = document.createElement('option');
      o.value = w.id;
      o.textContent = `${w.icon} ${w.name} (${fmt(w.balance, w.currency)})`;
      if (isForm && w.is_default) o.selected = true;
      el.appendChild(o);
    });
  });
}

async function loadWallets() {
  loading(true);
  try {
    await loadWalletsData();
    renderWalletCards();
    await loadTransfers();
  } catch(e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

function fakeCardLast4(id) {
  const s = String(id).replace(/-/g, '');
  const nums = s.replace(/\D/g, '');
  if (nums.length >= 4) return nums.slice(-4);
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) & 0xffff;
  return String(h % 10000).padStart(4, '0');
}

function walletCardTheme(type) {
  const mcBrand = '<div class="phys-mc-brand">mastercard</div>';
  const mcLogo  = '<div class="mc-logo"><div class="mc-circles"><div class="mc-c mc-red"></div><div class="mc-c mc-yel"></div></div><div class="mc-wordmark">mastercard</div></div>';
  const zcBrand = '<div class="zc-logo"><span class="zc-zain">zain</span><span class="zc-cash">cash</span></div>';
  const themes = {
    zaincash:   { bg: 'linear-gradient(135deg,#0d0d0d 0%,#1a1a1a 45%,#2a2020 100%)', accent: '#e5c060', brand: zcBrand, bottomLogo: '' },
    bank:       { bg: 'linear-gradient(135deg,#0a3d1f 0%,#1a6b35 50%,#0f5229 100%)', accent: '#fde047', brand: '<div class="phys-generic-brand">🏦 بنكي</div>', bottomLogo: '' },
    mastercard: { bg: 'linear-gradient(145deg,#00b530 0%,#00d93e 50%,#00a028 100%)', accent: '#001f08', brand: mcBrand, bottomLogo: mcLogo },
    salary:     { bg: 'linear-gradient(135deg,#0a1628 0%,#1a3a6b 50%,#0d2244 100%)', accent: '#7dd3fc', brand: '<div class="phys-generic-brand">💼 راتب</div>', bottomLogo: '' },
    cash:       { bg: 'linear-gradient(145deg,#1e3a0e 0%,#2d5c1a 40%,#1a3210 100%)', accent: '#86efac', brand: '', bottomLogo: '' },
    custom:     { bg: 'linear-gradient(135deg,#1c1c2e 0%,#2a2a4a 50%,#16162a 100%)', accent: '#a5b4fc', brand: '<div class="phys-generic-brand">💳 محفظة</div>', bottomLogo: '' },
  };
  return themes[type] || themes.custom;
}

function buildCardFace(w, theme, balance, name) {
  const last4   = fakeCardLast4(w.id);
  const wName   = esc(w.name);
  const dfBadge = w.is_default ? '<span class="phys-default-badge">افتراضي ✓</span>' : '';
  const cur     = w.currency;

  /* ── Cash: banknote design ── */
  if (w.wallet_type === 'cash') {
    return `<div class="phys-card phys-banknote" style="background:${theme.bg}">
            <div class="bn-header">
              <div class="bn-title">نقدي &bull; NAQDĪ</div>
              <div class="bn-deco">💵</div>
            </div>
            <div class="bn-main">
              <div class="bn-amount">${fmt(balance, cur)}</div>
              <div class="bn-cur-label">${cur}</div>
            </div>
            <div class="bn-footer">
              <div>
                <div class="bn-owner">— ${name} —</div>
                <div class="bn-wallet-name">${wName}</div>
                ${dfBadge}
              </div>
              <div class="bn-serial">S/N&nbsp;${last4}</div>
            </div>
          </div>`;
  }

  /* ── Mastercard: Rafidain Bank style ── */
  if (w.wallet_type === 'mastercard') {
    return `<div class="phys-card phys-rafidain" style="background:${theme.bg}">
            <div class="rf-top">
              <div class="rf-qi">
                <svg width="42" height="42" viewBox="0 0 42 42">
                  <circle cx="21" cy="21" r="21" fill="#f5c518"/>
                  <circle cx="21" cy="21" r="12.5" fill="none" stroke="#1a3d00" stroke-width="3.2"/>
                  <circle cx="21" cy="21" r="4.2" fill="#1a3d00"/>
                  <line x1="31" y1="10" x2="11" y2="32" stroke="#1a3d00" stroke-width="2.8" stroke-linecap="round"/>
                </svg>
              </div>
              <div class="rf-bank-block">
                <div class="rf-bank-ar">مصرف الرافدين</div>
                <div class="rf-bank-en">RAFIDAIN BANK</div>
                <svg class="rf-nfc-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2">
                  <path d="M12 2a10 10 0 0 1 0 20"/>
                  <path d="M12 6a6 6 0 0 1 0 12"/>
                  <path d="M12 10a2 2 0 0 1 0 4"/>
                </svg>
              </div>
            </div>
            <div class="rf-chip-row">
              <div class="phys-chip">
                <div class="chip-line h"></div>
                <div class="chip-line v"></div>
                <div class="chip-center"></div>
              </div>
              <div class="rf-balance">${fmt(balance, cur)}</div>
            </div>
            <div class="rf-footer">
              <div class="rf-holder-block">
                <div class="rf-name">${name}</div>
                <div class="rf-card-num">**** **** **** ${last4}</div>
                <div class="rf-wallet-sub">${wName}</div>
                ${dfBadge}
              </div>
              <div class="rf-mc-wrap">
                <div class="mc-c mc-red"></div>
                <div class="mc-c mc-yel"></div>
              </div>
            </div>
          </div>`;
  }

  /* ── Default: standard physical card ── */
  return `<div class="phys-card" style="background:${theme.bg}">
            <div class="phys-card-top">
              <div class="phys-brand" style="color:${theme.accent}">${theme.brand}</div>
              <div class="phys-nfc" style="color:${theme.accent}">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                  <path d="M12 2a10 10 0 0 1 0 20"/>
                  <path d="M12 6a6 6 0 0 1 0 12"/>
                  <path d="M12 10a2 2 0 0 1 0 4"/>
                </svg>
              </div>
            </div>
            <div class="phys-mid-row">
              <div class="phys-chip">
                <div class="chip-line h"></div>
                <div class="chip-line v"></div>
                <div class="chip-center"></div>
              </div>
              <div class="phys-card-num">&bull;&bull;&bull;&bull;&nbsp;&bull;&bull;&bull;&bull;&nbsp;&bull;&bull;&bull;&bull;&nbsp;${last4}</div>
            </div>
            <div class="phys-balance">${fmt(balance, cur)}</div>
            <div class="phys-card-bottom">
              <div class="phys-holder-block">
                <div class="phys-holder-label">CARD HOLDER</div>
                <div class="phys-holder">${name}</div>
                <div class="phys-wallet-label">${wName}</div>
                ${dfBadge}
              </div>
              <div class="phys-bottom-logo" style="color:${theme.accent}">${theme.bottomLogo}</div>
            </div>
          </div>`;
}

function renderWalletCards() {
  const el = document.getElementById('wallets-cards');
  const cur = S.user?.currency || 'IQD';
  if (!S.wallets.length) {
    el.innerHTML = '<div class="col-12"><div class="empty-state"><i class="fas fa-wallet"></i><p>لا توجد محافظ</p></div></div>';
    return;
  }
  const totalBal    = S.wallets.reduce((s, w) => s + parseFloat(w.balance), 0);
  const totalIncome = S.wallets.reduce((s, w) => s + parseFloat(w.total_income || 0), 0);
  el.innerHTML = `
    <div class="col-12">
      <div class="wallet-total-card glass-card">
        <div class="d-flex justify-content-between align-items-center">
          <div>
            <div class="text-muted small">إجمالي الرصيد الحالي</div>
            <div class="wallet-total-amt">${fmt(totalBal, cur)}</div>
          </div>
          <div class="text-end">
            <div class="text-muted small">إجمالي ما تم شحنه</div>
            <div class="wallet-total-amt" style="font-size:1rem;color:var(--clr-green)">${fmt(totalIncome, cur)}</div>
          </div>
          <div class="wallet-total-icon">💎</div>
        </div>
      </div>
    </div>
    ${S.wallets.map(w => {
      const income  = parseFloat(w.total_income || 0);
      const balance = parseFloat(w.balance);
      const spent   = Math.max(income - balance, 0);
      const theme   = walletCardTheme(w.wallet_type);
      const name = (S.user?.full_name || 'USER').toUpperCase();
      const cardFace = buildCardFace(w, theme, balance, name);

      return `
      <div class="col-sm-6 col-lg-4">
        <!-- Physical card face -->
        ${cardFace}

        <!-- Card stats + actions below -->
        <div class="phys-card-under">
          <div class="wallet-two-stats">
            <div class="wallet-stat-item">
              <div class="wallet-stat-label">الشحن الكلي</div>
              <div class="wallet-stat-val clr-green">${fmt(income, w.currency)}</div>
            </div>
            <div class="wallet-stat-divider"></div>
            <div class="wallet-stat-item">
              <div class="wallet-stat-label">الصرفيات</div>
              <div class="wallet-stat-val clr-red">${fmt(spent, w.currency)}</div>
            </div>
          </div>

          <!-- Quick income form -->
          <div id="winc-${w.id}" class="wallet-income-form" style="display:none">
            <div class="input-group input-group-sm mt-2">
              <input type="text" data-money class="form-control form-control-sm" id="winc-amt-${w.id}" placeholder="المبلغ المُضاف" dir="ltr">
              <button class="btn btn-success btn-sm" onclick="submitWalletIncome('${w.id}')"><i class="fas fa-check"></i></button>
              <button class="btn btn-outline-secondary btn-sm" onclick="toggleWalletIncome('${w.id}')"><i class="fas fa-times"></i></button>
            </div>
          </div>

          <div class="phys-actions">
            <button class="btn-wallet-add" onclick="toggleWalletIncome('${w.id}')" title="شحن"><i class="fas fa-plus"></i></button>
            ${w.is_default
              ? `<button class="btn btn-outline-secondary btn-xs" onclick="clearDefaultWallet()"><i class="fas fa-times me-1"></i>إلغاء الافتراضي</button>`
              : `<button class="btn btn-outline-success btn-xs" onclick="setDefaultWallet('${w.id}')"><i class="fas fa-check me-1"></i>افتراضية</button>`}
            <select class="form-select form-select-sm wallet-type-sel ms-auto" onchange="changeWalletType('${w.id}',this.value)" title="نوع المحفظة">
              <option value="cash"      ${w.wallet_type==='cash'      ?'selected':''}>💵 نقدي</option>
              <option value="zaincash"  ${w.wallet_type==='zaincash'  ?'selected':''}>⚫ زين كاش</option>
              <option value="mastercard"${w.wallet_type==='mastercard'?'selected':''}>🟢 ماستر كارت</option>
              <option value="bank"      ${w.wallet_type==='bank'      ?'selected':''}>🏦 بنكي</option>
              <option value="salary"    ${w.wallet_type==='salary'    ?'selected':''}>💼 راتب</option>
              <option value="custom"    ${w.wallet_type==='custom'||!['cash','zaincash','mastercard','bank','salary'].includes(w.wallet_type)?'selected':''}>💳 أخرى</option>
            </select>
            <button class="btn btn-outline-danger btn-xs" onclick="deleteWallet('${w.id}')"><i class="fas fa-trash-alt"></i></button>
          </div>
        </div>
      </div>`;
    }).join('')}`;
}

function toggleWalletIncome(walletId) {
  const form = document.getElementById(`winc-${walletId}`);
  if (!form) return;
  const isOpen = form.style.display !== 'none';
  // Close all open forms first
  document.querySelectorAll('.wallet-income-form').forEach(f => f.style.display = 'none');
  if (!isOpen) {
    form.style.display = '';
    const amtEl = document.getElementById(`winc-amt-${walletId}`);
    initMoneyInput(amtEl);
    amtEl?.focus();
  }
}

async function changeWalletType(walletId, newType) {
  try {
    await api('PATCH', `/wallets/${walletId}`, { wallet_type: newType });
    await loadWallets();
  } catch(e) { toast(e.message, 'err'); }
}

async function submitWalletIncome(walletId) {
  const input  = document.getElementById(`winc-amt-${walletId}`);
  const amount = getRaw(input);
  if (!amount || amount <= 0) { toast('أدخل مبلغاً صحيحاً', 'err'); return; }
  loading(true);
  try {
    await api('POST', `/wallets/${walletId}/add-income`, { amount });
    toast('تم شحن المحفظة ✅');
    loadWallets();
  } catch(e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

function walletTypeName(t) {
  const map = { salary: 'راتب شهري', bank: 'حساب بنكي', cash: 'نقدي', zaincash: 'زين كاش', mastercard: 'ماستر كارت' };
  return map[t] || t;
}

async function addIncome(e) {
  e.preventDefault();
  const walletId = document.getElementById('inc-wallet').value;
  const amount   = parseFloat(document.getElementById('inc-amount').value);
  if (!walletId || !amount || amount <= 0) { toast('اختر محفظة وأدخل مبلغ', 'err'); return; }
  loading(true);
  try {
    await api('POST', `/wallets/${walletId}/add-income`, { amount });
    toast('تمت إضافة الدخل ✅');
    document.getElementById('inc-amount').value = '';
    loadWallets();
  } catch(e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

async function doTransfer(e) {
  e.preventDefault();
  const fromId = document.getElementById('tr-from').value;
  const toId   = document.getElementById('tr-to').value;
  const amount = getRaw('tr-amount');
  const note   = document.getElementById('tr-note')?.value.trim() || null;

  if (!fromId || !toId) { toast('اختر المحافظ', 'err'); return; }
  if (fromId === toId)  { toast('لا يمكن التحويل لنفس المحفظة', 'err'); return; }
  if (!amount || amount <= 0) { toast('أدخل مبلغ صحيح', 'err'); return; }

  loading(true);
  try {
    await api('POST', '/wallets/transfer', { from_wallet_id: fromId, to_wallet_id: toId, amount, note });
    toast('تم التحويل بنجاح ✅');
    document.getElementById('tr-amount').value = '';
    document.getElementById('tr-note').value = '';
    loadWallets();
  } catch(e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

async function loadTransfers() {
  try {
    const data = await api('GET', '/wallets/transfers');
    renderTransfers(data || []);
  } catch(e) { /* ignore */ }
}

function renderTransfers(transfers) {
  const el = document.getElementById('transfers-list');
  if (!transfers.length) {
    el.innerHTML = '<div class="empty-state"><i class="fas fa-exchange-alt"></i><p>لا توجد تحويلات</p></div>';
    return;
  }
  const cur = S.user?.currency || 'IQD';
  el.innerHTML = transfers.map(t => `
    <div class="transfer-item">
      <div class="transfer-wallets">
        <span class="transfer-from">${t.from_wallet?.icon || '💰'} ${esc(t.from_wallet?.name || '')}</span>
        <i class="fas fa-arrow-left transfer-arrow"></i>
        <span class="transfer-to">${t.to_wallet?.icon || '💰'} ${esc(t.to_wallet?.name || '')}</span>
      </div>
      <div class="transfer-amt">${fmt(t.amount, cur)}</div>
      <div class="transfer-date text-muted small">${fmtDate(t.created_at)}${t.note ? ' · ' + esc(t.note) : ''}</div>
    </div>
  `).join('');
}

// ── Collapsible Sections ──────────────────────────────────────
function toggleSection(id) {
  const body = document.getElementById(id);
  const icon = document.getElementById(id + '-icon');
  if (!body) return;
  const open = body.style.display !== 'none';
  body.style.display = open ? 'none' : 'block';
  if (icon) icon.style.transform = open ? '' : 'rotate(180deg)';
  if (!open) setTimeout(() => initMoneyInputs(), 30);
}

// ── Custom Wallet ────────────────────────────────────────────
async function addCustomWallet(e) {
  e.preventDefault();
  const name        = document.getElementById('cw-name').value.trim();
  const wallet_type = document.getElementById('cw-type')?.value || 'custom';
  const icon        = document.getElementById('cw-icon').value.trim() || '💰';
  const balance     = getRaw('cw-balance');
  if (!name) { toast('أدخل اسم المحفظة', 'err'); return; }
  loading(true);
  try {
    await api('POST', '/wallets', { name, icon, wallet_type, balance, currency: S.user?.currency || 'IQD' });
    toast('تم إضافة المحفظة ✅');
    document.getElementById('cw-name').value = '';
    document.getElementById('cw-balance').value = '0';
    loadWallets();
  } catch(e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

async function deleteWallet(id) {
  if (!confirm('هل تريد حذف هذه المحفظة؟')) return;
  loading(true);
  try {
    await api('DELETE', `/wallets/${id}`);
    toast('تم حذف المحفظة');
    loadWallets();
  } catch(e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

async function setDefaultWallet(id) {
  loading(true);
  try {
    await api('POST', `/wallets/${id}/set-default`);
    toast('تم تعيين المحفظة الافتراضية ✅');
    await loadWalletsData();
    renderWalletCards();
  } catch(e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

async function clearDefaultWallet() {
  loading(true);
  try {
    await api('POST', '/wallets/clear-default');
    toast('تم إلغاء المحفظة الافتراضية');
    await loadWalletsData();
    renderWalletCards();
  } catch(e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

// ── Categories Page ──────────────────────────────────────────
async function loadCategoriesPage() {
  loading(true);
  try {
    const now = new Date();
    const results = await Promise.all([
      loadCategories(),
      api('GET', `/budgets?year=${now.getFullYear()}&month=${now.getMonth() + 1}`)
    ]);
    S.budgets = results[1] || [];
    renderCategoriesList();
  } catch(e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

function renderCategoriesList() {
  const el  = document.getElementById('categories-list');
  const cur = S.user?.currency || 'IQD';
  if (!S.categories.length) {
    el.innerHTML = '<div class="col-12"><div class="empty-state"><i class="fas fa-tags"></i><p>لا توجد فئات</p></div></div>';
    return;
  }
  el.innerHTML = S.categories.map(c => {
    const budget  = (S.budgets || []).find(b => b.category_id === c.id || b.category_id === c.id);
    let budgetHtml = '';
    if (budget) {
      const spent  = parseFloat(budget.spent) || 0;
      const limit  = parseFloat(budget.amount) || 1;
      const pct    = Math.min(Math.round((spent / limit) * 100), 100);
      const barCls = pct >= 100 ? 'over' : pct >= 75 ? 'warn' : '';
      budgetHtml = `
        <div class="cat-budget-info mt-2 pt-2" style="border-top:1px solid rgba(128,128,128,0.2)">
          <div class="d-flex justify-content-between align-items-center small mb-1">
            <button class="btn btn-xs btn-outline-secondary" onclick="editCatBudget('${c.id}', ${limit})" title="تعديل الميزانية"><i class="fas fa-pencil-alt"></i></button>
            <span class="text-muted" dir="ltr">${fmt(spent, cur)} / ${fmt(limit, cur)}</span>
          </div>
          <div class="progress" style="height:5px">
            <div class="progress-bar ${barCls}" style="width:${pct}%"></div>
          </div>
          ${pct >= 100 ? `<div class="small text-danger mt-1">⚠️ تجاوزت الحد</div>` : ''}
        </div>`;
    } else {
      budgetHtml = `
        <div class="cat-budget-set mt-2 pt-2" style="border-top:1px solid rgba(128,128,128,0.2)">
          <div class="input-group input-group-sm">
            <input type="text" data-money class="form-control form-control-sm" id="cbud-${c.id}" placeholder="ميزانية الشهر..." dir="ltr">
            <button class="btn btn-outline-primary btn-sm" onclick="saveCatBudget('${c.id}')">تعيين</button>
          </div>
        </div>`;
    }
    return `
    <div class="col-sm-6 col-lg-4">
      <div class="cat-card glass-card" style="border-right:4px solid ${c.color}">
        <div class="d-flex align-items-center gap-2">
          <span class="cat-card-icon" style="background:${c.color}22">${c.icon}</span>
          <div class="flex-grow-1">
            <div class="fw-bold">${esc(c.name_ar)}</div>
            <div class="text-muted small">${esc(c.name_en)}${c.sector ? ' · ' + esc(c.sector) : ''}</div>
          </div>
          ${c.is_system ? '<span class="badge bg-secondary badge-sm">نظام</span>' : '<button class="btn btn-outline-danger btn-xs" onclick="deleteCategory(\'' + c.id + '\')"><i class="fas fa-trash-alt"></i></button>'}
        </div>
        ${budgetHtml}
      </div>
    </div>`;
  }).join('');
  // Init smart money inputs inside category cards
  initMoneyInputs();
}

async function saveCatBudget(catId) {
  const el = document.getElementById(`cbud-${catId}`);
  const amount = getRaw(el);
  if (!amount || amount <= 0) { toast('أدخل مبلغاً صحيحاً', 'err'); return; }
  const now = new Date();
  loading(true);
  try {
    await api('POST', '/budgets', {
      category_id: catId,
      amount,
      month: now.getMonth() + 1,
      year:  now.getFullYear(),
    });
    toast('تم تعيين الميزانية ✅');
    const results = await Promise.all([
      loadCategories(),
      api('GET', `/budgets?year=${now.getFullYear()}&month=${now.getMonth() + 1}`)
    ]);
    S.budgets = results[1] || [];
    renderCategoriesList();
  } catch(e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

async function editCatBudget(catId, currentAmount) {
  const newAmt = prompt('أدخل الميزانية الجديدة:', currentAmount);
  if (!newAmt) return;
  const amount = parseFloat(String(newAmt).replace(/,/g, ''));
  if (!amount || amount <= 0) { toast('مبلغ غير صحيح', 'err'); return; }
  const now = new Date();
  loading(true);
  try {
    const existing = (S.budgets || []).find(b => b.category_id === catId);
    if (existing) {
      await api('PUT', `/budgets/${existing.id}`, { amount });
    } else {
      await api('POST', '/budgets', { category_id: catId, amount, month: now.getMonth() + 1, year: now.getFullYear() });
    }
    toast('تم التحديث ✅');
    const results = await Promise.all([
      loadCategories(),
      api('GET', `/budgets?year=${now.getFullYear()}&month=${now.getMonth() + 1}`)
    ]);
    S.budgets = results[1] || [];
    renderCategoriesList();
  } catch(e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

async function addCustomCategory(e) {
  e.preventDefault();
  const name_ar = document.getElementById('cc-name').value.trim();
  const name_en = document.getElementById('cc-name-en').value.trim() || name_ar;
  const icon    = document.getElementById('cc-icon').value.trim() || '💰';
  if (!name_ar) { toast('أدخل اسم الفئة', 'err'); return; }
  loading(true);
  try {
    await api('POST', '/categories', { name_ar, name_en, icon });
    toast('تم إضافة الفئة ✅');
    document.getElementById('cc-name').value = '';
    document.getElementById('cc-name-en').value = '';
    const now = new Date();
    const results = await Promise.all([loadCategories(), api('GET', `/budgets?year=${now.getFullYear()}&month=${now.getMonth() + 1}`)]);
    S.budgets = results[1] || [];
    renderCategoriesList();
  } catch(e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

async function deleteCategory(id) {
  if (!confirm('هل تريد حذف هذه الفئة؟')) return;
  loading(true);
  try {
    await api('DELETE', `/categories/${id}`);
    toast('تم حذف الفئة');
    const now = new Date();
    const results = await Promise.all([loadCategories(), api('GET', `/budgets?year=${now.getFullYear()}&month=${now.getMonth() + 1}`)]);
    S.budgets = results[1] || [];
    renderCategoriesList();
  } catch(e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

// ── Wallet Picker (for voice expenses) ───────────────────────
let _walletPickerResolve = null;

function showWalletPicker() {
  return new Promise(resolve => {
    _walletPickerResolve = resolve;
    const list = document.getElementById('wallet-picker-list');
    list.innerHTML = S.wallets.map(w => `
      <button class="wallet-picker-item" onclick="walletPickerSelect('${w.id}')">
        <span class="wallet-picker-icon">${w.icon}</span>
        <span>${esc(w.name)}</span>
        <span class="text-muted small">${fmt(w.balance, w.currency)}</span>
      </button>
    `).join('');
    document.getElementById('wallet-picker-overlay').style.display = 'flex';
  });
}

function walletPickerSelect(id) {
  document.getElementById('wallet-picker-overlay').style.display = 'none';
  if (_walletPickerResolve) { _walletPickerResolve(id); _walletPickerResolve = null; }
}

function walletPickerCancel() {
  document.getElementById('wallet-picker-overlay').style.display = 'none';
  if (_walletPickerResolve) { _walletPickerResolve(null); _walletPickerResolve = null; }
}

function getDefaultWallet() {
  return S.wallets.find(w => w.is_default) || null;
}

function findWalletByHint(hint) {
  if (!hint) return null;
  return S.wallets.find(w => w.wallet_type === hint) || null;
}

// ── Settings ─────────────────────────────────────────────────
function loadSettings() {
  if (!S.user) return;
  const setVal = (id, val) => { const el = document.getElementById(id); if (el) el.value = val; };
  setVal('set-name',     S.user.full_name || '');
  setVal('set-email',    S.user.email     || '');
  setVal('set-currency', S.user.currency  || 'IQD');
  const sw = document.getElementById('dark-toggle');
  if (sw) sw.checked = !document.body.classList.contains('light-theme');
}

async function saveProfile() {
  const name     = document.getElementById('set-name').value.trim();
  const currency = document.getElementById('set-currency').value;
  if (!name) { toast('أدخل الاسم', 'err'); return; }
  loading(true);
  try {
    const updated = await api('PATCH', '/auth/me', { full_name: name, currency });
    S.user = updated;
    localStorage.setItem('user', JSON.stringify(updated));
    updateSidebarUser();
    toast('تم الحفظ ✅');
  } catch (e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

async function changePass() {
  const cur  = document.getElementById('set-cur-pass').value;
  const nw   = document.getElementById('set-new-pass').value;
  if (!cur || !nw) { toast('أدخل كلمتي المرور', 'err'); return; }
  if (nw.length < 8) { toast('كلمة المرور يجب أن تكون 8 أحرف على الأقل', 'err'); return; }
  loading(true);
  try {
    await api('POST', '/auth/change-password', { current_password: cur, new_password: nw });
    toast('تم تغيير كلمة المرور ✅');
    document.getElementById('set-cur-pass').value = '';
    document.getElementById('set-new-pass').value = '';
  } catch (e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

// ── Security helper ──────────────────────────────────────────
function esc(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

// ── Admin Users ───────────────────────────────────────────────
let _adminUsers = [];

async function loadAdminUsers() {
  const wrap = document.getElementById('admin-users-table');
  if (!wrap) return;
  wrap.innerHTML = '<div class="text-center py-4"><div class="spinner-border text-primary"></div></div>';
  try {
    _adminUsers = await api('GET', '/admin/users');
    renderAdminTable();
  } catch(e) {
    wrap.innerHTML = `<div class="text-danger p-3">${esc(e.message)}</div>`;
  }
}

function renderAdminTable() {
  const wrap = document.getElementById('admin-users-table');
  if (!wrap) return;
  if (!_adminUsers.length) {
    wrap.innerHTML = '<p class="text-muted text-center py-3">لا يوجد مستخدمون</p>';
    return;
  }
  wrap.innerHTML = `
    <div class="table-responsive">
      <table class="table table-dark table-hover align-middle mb-0">
        <thead><tr>
          <th>الاسم</th>
          <th>البريد</th>
          <th>العملة</th>
          <th>الحالة</th>
          <th>أدمن</th>
          <th>الإجراءات</th>
        </tr></thead>
        <tbody>
          ${_adminUsers.map(u => `
            <tr>
              <td>${esc(u.full_name)}</td>
              <td dir="ltr">${esc(u.email)}</td>
              <td>${esc(u.currency)}</td>
              <td><span class="badge ${u.is_active ? 'bg-success' : 'bg-secondary'}">${u.is_active ? 'مفعّل' : 'معطّل'}</span></td>
              <td>${u.is_admin ? '<span class="badge bg-warning text-dark">أدمن</span>' : ''}</td>
              <td>
                <button class="btn btn-sm btn-outline-primary me-1" onclick="openEditUserModal('${u.id}')"><i class="fas fa-edit"></i></button>
                <button class="btn btn-sm btn-outline-danger" onclick="deleteAdminUser('${u.id}', '${esc(u.full_name)}')"><i class="fas fa-trash"></i></button>
              </td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    </div>`;
}

function openAddUserModal() {
  document.getElementById('userModalTitle').textContent = 'مستخدم جديد';
  document.getElementById('um-id').value = '';
  document.getElementById('um-name').value = '';
  document.getElementById('um-email').value = '';
  document.getElementById('um-email').disabled = false;
  document.getElementById('um-pass').value = '';
  document.getElementById('um-pass').placeholder = 'أدخل كلمة المرور (مطلوبة)';
  document.getElementById('um-pass-hint').style.display = 'none';
  document.getElementById('um-currency').value = 'IQD';
  document.getElementById('um-admin').checked = false;
  document.getElementById('um-active').checked = true;
  new bootstrap.Modal(document.getElementById('userModal')).show();
}

function openEditUserModal(userId) {
  const u = _adminUsers.find(x => x.id === userId);
  if (!u) return;
  document.getElementById('userModalTitle').textContent = 'تعديل المستخدم';
  document.getElementById('um-id').value = u.id;
  document.getElementById('um-name').value = u.full_name;
  document.getElementById('um-email').value = u.email;
  document.getElementById('um-email').disabled = true;
  document.getElementById('um-pass').value = '';
  document.getElementById('um-pass').placeholder = 'أدخل كلمة مرور جديدة';
  document.getElementById('um-pass-hint').style.display = '';
  document.getElementById('um-currency').value = u.currency || 'IQD';
  document.getElementById('um-admin').checked = u.is_admin;
  document.getElementById('um-active').checked = u.is_active;
  new bootstrap.Modal(document.getElementById('userModal')).show();
}

function toggleAdminPass(btn) {
  const inp = document.getElementById('um-pass');
  const icon = btn.querySelector('i');
  if (inp.type === 'password') {
    inp.type = 'text';
    icon.className = 'fas fa-eye-slash';
  } else {
    inp.type = 'password';
    icon.className = 'fas fa-eye';
  }
}

async function saveUser() {
  const id       = document.getElementById('um-id').value;
  const name     = document.getElementById('um-name').value.trim();
  const email    = document.getElementById('um-email').value.trim();
  const pass     = document.getElementById('um-pass').value;
  const currency = document.getElementById('um-currency').value;
  const isAdmin  = document.getElementById('um-admin').checked;
  const isActive = document.getElementById('um-active').checked;

  if (!name) { toast('أدخل الاسم', 'err'); return; }

  loading(true);
  try {
    if (!id) {
      // Create
      if (!email) { toast('أدخل البريد', 'err'); return; }
      if (!pass)  { toast('أدخل كلمة المرور', 'err'); return; }
      await api('POST', '/admin/users', { full_name: name, email, password: pass, currency, is_admin: isAdmin });
      toast('تم إنشاء الحساب ✅');
    } else {
      // Update
      const body = { full_name: name, currency, is_admin: isAdmin, is_active: isActive };
      if (pass) body.password = pass;
      await api('PATCH', `/admin/users/${id}`, body);
      toast('تم التحديث ✅');
    }
    bootstrap.Modal.getInstance(document.getElementById('userModal'))?.hide();
    await loadAdminUsers();
  } catch(e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

async function deleteAdminUser(userId, name) {
  if (!confirm(`هل تريد حذف حساب "${name}"؟ سيتم حذف جميع بياناته.`)) return;
  loading(true);
  try {
    await api('DELETE', `/admin/users/${userId}`);
    toast('تم حذف الحساب');
    await loadAdminUsers();
  } catch(e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

// ── FAB Voice Assistant code is in inline script in index.html ──

// ── Bootstrap ────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  // Default is light theme; only apply dark if user explicitly chose it
  if (localStorage.getItem('theme') === 'dark') {
    document.body.classList.add('dark-theme');
    const btn = document.getElementById('theme-btn');
    if (btn) btn.innerHTML = '<i class="fas fa-moon"></i>';
    const sw = document.getElementById('dark-toggle');
    if (sw) sw.checked = true;
  } else {
    document.body.classList.remove('dark-theme');
    document.body.classList.add('light-theme');
    const btn = document.getElementById('theme-btn');
    if (btn) btn.innerHTML = '<i class="fas fa-sun"></i>';
    const sw = document.getElementById('dark-toggle');
    if (sw) sw.checked = false;
  }

  // Swipe to open sidebar (swipe right in RTL = from left edge)
  let touchStartX = 0;
  let touchStartY = 0;
  let swiping = false;
  document.addEventListener('touchstart', function(e) {
    const t = e.touches[0];
    touchStartX = t.clientX;
    touchStartY = t.clientY;
    swiping = true;
  }, { passive: true });

  document.addEventListener('touchmove', function(e) {
    if (!swiping) return;
    const dx = e.touches[0].clientX - touchStartX;
    const dy = Math.abs(e.touches[0].clientY - touchStartY);
    // If vertical scroll, cancel
    if (dy > 40) { swiping = false; }
  }, { passive: true });

  document.addEventListener('touchend', function(e) {
    if (!swiping) return;
    swiping = false;
    const t = e.changedTouches[0];
    const dx = t.clientX - touchStartX;
    // RTL: swipe left (negative dx) opens sidebar from right edge
    // To open sidebar: swipe from right edge to left (or in RTL swipe left means pull from right)
    // Actually in RTL the sidebar is on the right side.
    // "pull left" = swipe left = open sidebar (sidebar slides from right)
    if (dx < -70 && touchStartX > window.innerWidth * 0.6) {
      // Swiped left from right side → open sidebar
      document.getElementById('sidebar').classList.add('open');
      document.getElementById('sidebar-overlay').classList.add('on');
    }
    // Swipe right to close sidebar
    if (dx > 70) {
      closeSidebar();
    }
  }, { passive: true });

  if (S.token && S.user) {
    initApp();
  } else {
    showAuthTab('login');
  }
});
