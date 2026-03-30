'use strict';
// ═══════════════════════════════════════════════
// مصاريفي — SPA JavaScript
// ═══════════════════════════════════════════════

// Register Service Worker (PWA)
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/sw.js').then(reg => reg.update()).catch(() => {});
}

// ── PWA Install Prompt ────────────────────────────────────────
let _installPrompt = null;

// Hide install buttons if already running as installed PWA
if (window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone) {
  document.addEventListener('DOMContentLoaded', () => {
    const btn     = document.getElementById('pwa-install-btn');
    const sideBtn = document.getElementById('sidebar-install-btn');
    if (btn)     btn.style.display = 'none';
    if (sideBtn) sideBtn.style.display = 'none';
  });
}

window.addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault();
  _installPrompt = e;
  // Upgrade button to green on Android when native prompt is ready
  const btn = document.getElementById('pwa-install-btn');
  if (btn) { btn.textContent = ''; btn.innerHTML = '<i class="fas fa-download me-2"></i>تثبيت مصاريفي الآن — اضغط هنا!'; }
});

window.addEventListener('appinstalled', () => {
  _installPrompt = null;
  const btn = document.getElementById('pwa-install-btn');
  if (btn) { btn.disabled = true; btn.innerHTML = '<i class="fas fa-check me-2"></i>تم التثبيت ✅'; }
  const sideBtn = document.getElementById('sidebar-install-btn');
  if (sideBtn) sideBtn.style.display = 'none';
  toast('تم تثبيت مصاريفي على شاشتك! 🎉');
});

const API = '/api/v1';
const SUPPORT_WHATSAPP = '9647755669961';

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

function toast(msg, type = 'ok', delay = 3200) {
  const el = document.getElementById('app-toast');
  el.className = `toast align-items-center border-0 t-${type}`;
  document.getElementById('toast-msg').textContent = msg;
  bootstrap.Toast.getOrCreateInstance(el, { delay }).show();
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

  // 10-second timeout for non-file requests (prevents cold-start hangs)
  let controller, _tid;
  if (!formData) {
    controller = new AbortController();
    _tid = setTimeout(() => controller.abort(), 10000);
    opts.signal = controller.signal;
  }

  let res;
  try {
    res = await fetch(API + path, opts);
  } catch(fetchErr) {
    clearTimeout(_tid);
    throw fetchErr;  // network error or abort — propagate to caller
  }
  clearTimeout(_tid);

  if (res.status === 401 && S.refreshToken) {
    const ok = await tryRefresh();
    if (ok) {
      headers['Authorization'] = `Bearer ${S.token}`;
      res = await fetch(API + path, { ...opts, headers });
    } else { doLogout(); return null; }
  }

  if (res.status === 402) {
    const err = await res.json().catch(() => ({}));
    const det = err.detail || {};
    const msg = typeof det === 'object' ? det.message : String(det);
    showUpgradeModal(msg || null);
    throw new Error('plan_limit');
  }

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    const det = err.detail || {};
    const msg = typeof det === 'object' ? (det.message || JSON.stringify(det)) : String(det);
    throw new Error(msg || 'حدث خطأ في الاتصال');
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
    initApp(true);
  } catch (e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

async function doRegister() {
  const name     = document.getElementById('r-name').value.trim();
  const email    = document.getElementById('r-email').value.trim();
  const phone    = document.getElementById('r-phone').value.trim() || null;
  const pass     = document.getElementById('r-pass').value;
  const currency = document.getElementById('r-currency').value;
  if (!name || !email || !pass) { toast('يرجى ملء جميع الحقول', 'err'); return; }
  if (!phone) { toast('رقم الهاتف مطلوب', 'err'); return; }
  if (pass.length < 8) { toast('كلمة المرور يجب أن تكون 8 أحرف على الأقل', 'err'); return; }
  // Basic email format check on client side
  if (!email.includes('@') || !email.split('@')[1]?.includes('.')) {
    toast('صيغة البريد الإلكتروني غير صحيحة', 'err'); return;
  }

  loading(true);
  try {
    const refCode = document.getElementById('r-ref-code')?.value.trim().toUpperCase() || null;
    const d = await api('POST', '/auth/register', { full_name: name, email, phone_number: phone, password: pass, currency, preferred_language: 'ar', referral_code: refCode });
    await saveSession(d);
    toast('تم إنشاء الحساب بنجاح 🎉');
    initApp(true);
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
  loading(false);
  localStorage.removeItem('access_token');
  localStorage.removeItem('refresh_token');
  localStorage.removeItem('user');
  S.token = S.refreshToken = S.user = null;
  document.getElementById('auth-screen').style.display = '';
  document.getElementById('app-screen').style.display  = 'none';
  showAuthTab('login');
}

// ── App Init ─────────────────────────────────────────────────
async function initApp(freshLogin = false) {
  try {
    document.getElementById('auth-screen').style.display = 'none';
    document.getElementById('app-screen').style.display  = '';
    updateSidebarUser();
    // If token expired during load, api() calls doLogout() which calls loading(false). Stop here.
    await loadCategories();
    if (!S.token) return;
    await loadWalletsData();
    if (!S.token) return;
    const savedPage = freshLogin ? 'dashboard' : (localStorage.getItem('last_page') || location.hash.replace('#', '') || 'dashboard');
    const validPages = Object.keys(PAGE_TITLES);
    goTo(validPages.includes(savedPage) ? savedPage : 'dashboard');
  } catch(e) {
    console.error('initApp error:', e);
  } finally {
    loading(false);
  }
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
  updatePlanUI();
}

function setText(id, val) {
  const el = document.getElementById(id);
  if (el) el.textContent = val;
}

// ── Plan UI ───────────────────────────────────────────────────
function showUpgradeModal(limitMsg) {
  const msgEl = document.getElementById('upgrade-limit-msg');
  if (msgEl) {
    if (limitMsg) {
      msgEl.textContent = limitMsg;
      msgEl.style.display = '';
    } else {
      msgEl.style.display = 'none';
    }
  }
  // Set WhatsApp link
  const waBtn = document.getElementById('upgrade-whatsapp-btn');
  if (waBtn) {
    const text = encodeURIComponent('مرحباً، أريد الاشتراك في تطبيق مصاريفي 🚀');
    waBtn.href = `https://wa.me/${SUPPORT_WHATSAPP}?text=${text}`;
  }
  const modal = document.getElementById('upgradeModal');
  if (modal) bootstrap.Modal.getOrCreateInstance(modal).show();
}

function updatePlanUI() {
  if (!S.user) return;
  const badge = document.getElementById('plan-badge');
  const banner = document.getElementById('plan-banner');
  const bannerText = document.getElementById('plan-banner-text');
  if (!badge) return;

  const plan = S.user.plan || 'trial';
  const trialStarted = S.user.trial_started_at ? new Date(S.user.trial_started_at) : null;
  const now = new Date();

  // Compute effective plan (mirrors backend logic)
  let effectivePlan = plan;
  let trialDaysLeft = 0;
  if (plan === 'trial' && trialStarted) {
    const elapsed = Math.floor((now - trialStarted) / 86400000);
    const bonusDays = S.user.referral_bonus_days || 0;
    trialDaysLeft = (14 + bonusDays) - elapsed;
    if (trialDaysLeft <= 0) effectivePlan = 'free';
  }
  if ((plan === 'pro' || plan === 'business') && S.user.plan_expires_at) {
    if (new Date(S.user.plan_expires_at) < now) effectivePlan = 'free';
  }
  if (S.user.is_admin) effectivePlan = 'business';

  // Badge
  badge.style.display = '';
  badge.className = 'plan-badge';
  if (effectivePlan === 'trial') {
    badge.classList.add('plan-badge-trial');
    badge.textContent = trialDaysLeft > 0 ? `تجربة: ${trialDaysLeft} يوم` : 'تجربة منتهية';
  } else if (effectivePlan === 'free') {
    badge.classList.add('plan-badge-free');
    badge.textContent = '🔒 مجاني';
  } else if (effectivePlan === 'pro') {
    badge.classList.add('plan-badge-pro');
    badge.textContent = '⭐ Pro';
  } else if (effectivePlan === 'business') {
    badge.classList.add('plan-badge-pro');
    badge.textContent = '🏢 Business';
  } else if (effectivePlan === 'custom') {
    badge.classList.add('plan-badge-custom');
    badge.textContent = '🛠️ مخصصة';
  }

  // Trial/plan warning banner
  if (banner && bannerText) {
    if (effectivePlan === 'trial' && trialDaysLeft <= 3 && trialDaysLeft > 0) {
      bannerText.innerHTML = `⚠️ تجربتك المجانية تنتهي خلال <strong>${trialDaysLeft}</strong> ${trialDaysLeft === 1 ? 'يوم' : 'أيام'}! &nbsp;<span style="opacity:.8;font-size:.85em">ادعُ صديقاً واكسب 7 أيام إضافية</span>`;
      banner.style.display = '';
    } else if (effectivePlan === 'free' && plan === 'trial') {
      bannerText.innerHTML = '⚠️ انتهت فترة التجربة المجانية. &nbsp;<span style="opacity:.8;font-size:.85em">ادعُ صديقاً لتمديدها أو اشترك الآن</span>';
      banner.style.display = '';
    } else if (effectivePlan === 'free' && (plan === 'pro' || plan === 'business')) {
      bannerText.innerHTML = `⚠️ انتهى اشتراك <strong>${plan === 'pro' ? 'Pro' : 'Business'}</strong>. &nbsp;<span style="opacity:.8;font-size:.85em">جدّد اشتراكك عبر واتساب أو ادعُ صديقاً</span>`;
      banner.style.display = '';
    } else {
      banner.style.display = 'none';
    }
  }

  // Referral reminder toast — shown once per session when plan expires/trial ends
  const _refReminderKey = 'ref_reminder_shown';
  if ((effectivePlan === 'free') && !sessionStorage.getItem(_refReminderKey)) {
    sessionStorage.setItem(_refReminderKey, '1');
    setTimeout(() => {
      const hasCode = S.user?.referral_code;
      const msg = hasCode
        ? `💡 ادعُ صديقاً واكسب 7 أيام إضافية مجاناً! اذهب إلى الإعدادات لنسخ رابطك.`
        : `💡 يمكنك كسب أيام إضافية مجاناً بدعوة أصدقائك — تحقق من صفحة الإعدادات.`;
      toast(msg, 'info', 6000);
    }, 1500);
  }
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
  closeReferralDropdown();
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

  try {
    const [data, cats, daily, exps] = await Promise.all([
      api('GET', `/statistics/monthly?year=${now.getFullYear()}&month=${now.getMonth() + 1}`),
      api('GET', `/statistics/categories?year=${now.getFullYear()}&month=${now.getMonth() + 1}`),
      api('GET', `/statistics/daily?target_date=${today()}`),
      api('GET', `/expenses?size=5`),
    ]);

    const cur = S.user?.currency || 'IQD';
    setText('kpi-month', fmt(data?.total || 0, cur));
    setText('kpi-today', fmt(daily?.total || 0, cur));
    setText('kpi-count', data?.count || 0);
    renderRecentExps(exps?.items || []);
    if (cats?.length) renderPie('dash-pie', cats);
  } catch (e) { console.error(e); }
}

function renderRecentExps(items) {
  const el = document.getElementById('dash-recent');
  if (!items.length) { el.innerHTML = '<div class="empty-state"><i class="fas fa-receipt"></i><p>لا توجد مصاريف بعد</p></div>'; return; }
  el.innerHTML = items.map(expHtml).join('');
}

function expHtml(exp) {
  const cat = catById(exp.category_id);
  const walletInfo = exp.wallet ? ` · ${exp.wallet.icon} ${esc(exp.wallet.name)}` : '';
  const isIncome = exp.entry_type === 'income';
  const itemClass = isIncome ? 'exp-item income-entry' : 'exp-item';
  const amtClass = isIncome ? 'exp-amt income-amt' : 'exp-amt';
  const amtSign = isIncome ? '+' : '−';
  const icon = isIncome ? '💰' : cat.icon;
  return `<div class="${itemClass}">
    <div class="exp-icon">${icon}</div>
    <div class="exp-info">
      <div class="exp-desc">${esc(exp.description || (isIncome ? 'إيراد' : 'مصروف'))}</div>
      <div class="exp-meta">${cat.name_ar} · ${fmtDate(exp.expense_date)}${walletInfo}</div>
    </div>
    <div class="${amtClass}">${amtSign}${fmt(exp.amount, exp.currency)}</div>
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

  try {
    const data = await api('GET', url);
    S.expTotal = data?.total || 0;
    renderExpList(data?.items || []);
    renderExpPagination(data);
  } catch (e) { toast(e.message, 'err'); }
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
      const isIncome = exp.entry_type === 'income';
      const itemClass = isIncome ? 'exp-item income-entry' : 'exp-item';
      const amtClass = isIncome ? 'exp-amt income-amt' : 'exp-amt';
      const amtSign = isIncome ? '+' : '−';
      return `<div class="${itemClass}" id="ei-${exp.id}">
        <div class="exp-icon">${isIncome ? '💰' : cat.icon}</div>
        <div class="exp-info">
          <div class="exp-desc">${esc(exp.description || (isIncome ? 'إيراد' : 'مصروف'))}</div>
          <div class="exp-meta">${cat.name_ar} · ${fmtDate(exp.expense_date)}${exp.note ? ' · ' + esc(exp.note) : ''} ${walletInfo}</div>
        </div>
        <div class="${amtClass}">${amtSign}${fmt(exp.amount, exp.currency)}</div>
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
      const isIncome = exp.entry_type === 'income';
      const itemClass = isIncome ? 'exp-item income-entry' : 'exp-item';
      const amtClass = isIncome ? 'exp-amt income-amt' : 'exp-amt';
      const amtSign = isIncome ? '+' : '−';
      return `<div class="${itemClass}" id="ei-${exp.id}">
        <div class="exp-icon">${isIncome ? '💰' : cat.icon}</div>
        <div class="exp-info">
          <div class="exp-desc">${esc(exp.description || (isIncome ? 'إيراد' : 'مصروف'))}</div>
          <div class="exp-meta">${cat.name_ar}${exp.note ? ' · ' + esc(exp.note) : ''} ${walletInfo}</div>
        </div>
        <div class="${amtClass}">${amtSign}${fmt(exp.amount, exp.currency)}</div>
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
let _drawerType = 'expense';

function setDrawerType(type) {
  _drawerType = type;
  document.getElementById('drawer-type-expense')?.classList.toggle('active', type === 'expense');
  document.getElementById('drawer-type-income')?.classList.toggle('active', type === 'income');
  const walletLabel = document.getElementById('ae-wallet-label');
  if (walletLabel) walletLabel.textContent = type === 'income' ? 'المحفظة (الإضافة إلى)' : 'المحفظة (الدفع من)';
  const submitBtn = document.getElementById('ae-submit-btn');
  if (submitBtn) submitBtn.innerHTML = type === 'income'
    ? '<i class="fas fa-check me-2"></i>حفظ الإيراد'
    : '<i class="fas fa-check me-2"></i>حفظ المصروف';
  const title = document.getElementById('drawer-header-title');
  if (title) title.innerHTML = type === 'income'
    ? '<i class="fas fa-arrow-trend-down me-2 text-success"></i>إيراد / دخل جديد'
    : '<i class="fas fa-arrow-trend-up me-2 text-danger"></i>مصروف جديد';
}

function openExpenseDrawer(type) {
  _drawerType = type || 'expense';
  closeSidebar();
  prepareForm();
  setDrawerType(_drawerType);
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
      entry_type:   _drawerType || 'expense',
    });
    toast(_drawerType === 'income' ? 'تم إضافة الإيراد ✅' : 'تم إضافة المصروف ✅');
    document.getElementById('expense-form').reset();
    setDrawerType('expense');
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
  try {
    const data = await api('GET', `/budgets?year=${now.getFullYear()}&month=${now.getMonth() + 1}`);
    renderBudgets(data || []);
  } catch (e) { toast(e.message, 'err'); }
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
  try {
    await loadWalletsData();
    renderWalletCards();
    await loadTransfers();
  } catch(e) { toast(e.message, 'err'); }
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

  /* ── Mastercard: dynamic bank name ── */
  const _bankEnMap = {
    'مصرف الرافدين':'RAFIDAIN BANK','بنك الرافدين':'RAFIDAIN BANK',
    'مصرف الرشيد':'RASHEED BANK','بنك الرشيد':'RASHEED BANK',
    'بنك بغداد':'BANK OF BAGHDAD','المصرف التجاري العراقي':'TRADE BANK OF IRAQ',
    'بنك الاستثمار العراقي':'INVESTMENT BANK OF IRAQ','بنك آسيا':'ASIA BANK',
    'بنك الشرق الأوسط':'MIDDLE EAST BANK','بنك الإسكان العراقي':'IRAQ HOUSING BANK',
    'المصرف العراقي للتجارة (TBI)':'TRADE BANK OF IRAQ','بنك كردستان الدولي':'KURDISTAN INTL BANK',
    'بنك الخليج التجاري':'GULF COMMERCIAL BANK','بنك سومر':'SUMER BANK','بنك النهرين':'NAHRAIN BANK',
    'زين كاش':'ZAIN CASH','آسيا حوالة':'ASIA HAWALA',
  };
  if (w.wallet_type === 'mastercard') {
    const bankAr = esc(w.name);
    const bankEn = _bankEnMap[w.name] || w.name.toUpperCase();
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
                <div class="rf-bank-ar">${bankAr}</div>
                <div class="rf-bank-en">${bankEn}</div>
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
              <option value="zaincash"  ${w.wallet_type==='zaincash'  ?'selected':''}>⚫ Zain Cash</option>
              <option value="mastercard"${w.wallet_type==='mastercard'?'selected':''}>🟢 Master Card</option>
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
const _typeIconMap = {
  cash: '💵', zaincash: '⚫', mastercard: '🟢', bank: '🏦', salary: '💼', custom: '💳'
};

function toggleCustomType(sel) {
  const row = document.getElementById('cw-custom-type-row');
  const inp = document.getElementById('cw-custom-type');
  const iconEl = document.getElementById('cw-icon');
  if (!row) return;
  const isCustom = sel.value === 'custom';
  row.style.display = isCustom ? 'block' : 'none';
  if (inp) inp.required = isCustom;
  if (iconEl) iconEl.value = _typeIconMap[sel.value] || '💳';
}

async function addCustomWallet(e) {
  e.preventDefault();
  const name        = document.getElementById('cw-name').value.trim();
  const typeSelect  = document.getElementById('cw-type')?.value || 'custom';
  const customName  = document.getElementById('cw-custom-type')?.value.trim();
  const wallet_type = (typeSelect === 'custom' && customName) ? customName : typeSelect;
  const icon        = document.getElementById('cw-icon')?.value || '💰';
  const balance     = getRaw('cw-balance');
  if (!name) { toast('أدخل اسم المحفظة', 'err'); return; }
  if (typeSelect === 'custom' && !customName) { toast('أدخل اسم نوع المحفظة المخصص', 'err'); return; }
  loading(true);
  try {
    await api('POST', '/wallets', { name, icon, wallet_type, balance, currency: S.user?.currency || 'IQD' });
    toast('تم إضافة المحفظة ✅');
    document.getElementById('cw-name').value = '';
    document.getElementById('cw-balance').value = '0';
    const ctEl = document.getElementById('cw-custom-type');
    if (ctEl) ctEl.value = '';
    const ctRow = document.getElementById('cw-custom-type-row');
    if (ctRow) ctRow.style.display = 'none';
    const cwType = document.getElementById('cw-type');
    if (cwType) cwType.value = 'cash';
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
  try {
    const now = new Date();
    const results = await Promise.all([
      loadCategories(),
      api('GET', `/budgets?year=${now.getFullYear()}&month=${now.getMonth() + 1}`)
    ]);
    S.budgets = results[1] || [];
    renderCategoriesList();
  } catch(e) { toast(e.message, 'err'); }
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
  loadReferral();
}

function showInstallTab(tab) {
  document.getElementById('install-tab-android').style.display = tab === 'android' ? '' : 'none';
  document.getElementById('install-tab-ios').style.display     = tab === 'ios'     ? '' : 'none';
  document.getElementById('itab-android').className = `btn btn-sm ${tab === 'android' ? 'btn-primary' : 'btn-outline-secondary'}`;
  document.getElementById('itab-ios').className     = `btn btn-sm ${tab === 'ios'     ? 'btn-primary' : 'btn-outline-secondary'}`;
}

async function triggerInstall() {
  // Already installed as PWA?
  if (window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone) {
    toast('التطبيق مثبت بالفعل على شاشتك 📱');
    return;
  }
  // Android / Chrome — native install dialog (best case)
  if (_installPrompt) {
    _installPrompt.prompt();
    const { outcome } = await _installPrompt.userChoice;
    if (outcome === 'accepted') {
      _installPrompt = null;
      const btn = document.getElementById('pwa-install-btn');
      if (btn) btn.style.display = 'none';
    }
    return;
  }
  // iOS Safari — show bottom sheet with steps
  if (/iPhone|iPad|iPod/i.test(navigator.userAgent)) {
    _showInstallSheet('ios-install-sheet');
    return;
  }
  // Android but prompt not ready yet — show helper sheet
  if (/Android/i.test(navigator.userAgent)) {
    _showInstallSheet('android-install-sheet');
    return;
  }
  // Desktop fallback
  goTo('settings');
  setTimeout(() => document.getElementById('install-guide-card')?.scrollIntoView({ behavior: 'smooth', block: 'start' }), 150);
}

function _showInstallSheet(id) {
  const sheet = document.getElementById(id);
  if (!sheet) return;
  sheet.style.display = '';
  requestAnimationFrame(() => sheet.classList.add('open'));
}

function closeInstallSheet() {
  ['ios-install-sheet', 'android-install-sheet'].forEach(id => {
    const sheet = document.getElementById(id);
    if (!sheet) return;
    sheet.classList.remove('open');
    setTimeout(() => sheet.style.display = 'none', 300);
  });
}

function openInChrome() {
  const url = window.location.href;
  const scheme = url.startsWith('https') ? 'https' : 'http';
  const intent = 'intent://' + url.replace(/^https?:\/\//, '') + '#Intent;scheme=' + scheme + ';package=com.android.chrome;end';
  window.location.href = intent;
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

// ── Admin Impersonation ────────────────────────────────────────
async function viewAsUser(userId, userName) {
  loading(true);
  try {
    const data = await api('POST', `/admin/users/${userId}/impersonate`);
    // Backup admin session
    localStorage.setItem('admin_backup_token', S.token);
    localStorage.setItem('admin_backup_refresh', S.refreshToken || '');
    localStorage.setItem('admin_backup_user', JSON.stringify(S.user));
    // Switch to target user session
    S.token        = data.access_token;
    S.refreshToken = null;
    S.user         = data.user;
    localStorage.setItem('access_token', data.access_token);
    localStorage.removeItem('refresh_token');
    localStorage.setItem('user', JSON.stringify(data.user));
    // Show banner
    document.getElementById('impersonate-banner').style.display = '';
    document.getElementById('impersonate-name').textContent = `أنت تشاهد حساب: ${userName}`;
    document.getElementById('app-screen').classList.add('impersonating');
    // Re-init app as target user
    await loadCategories();
    await loadWalletsData();
    updateSidebarUser();
    goTo('dashboard');
    toast(`تم فتح حساب ${userName} 👁`);
  } catch(e) { toast(e.message, 'err'); }
  finally { loading(false); }
}

async function exitImpersonation() {
  const backupToken   = localStorage.getItem('admin_backup_token');
  const backupRefresh = localStorage.getItem('admin_backup_refresh');
  const backupUser    = localStorage.getItem('admin_backup_user');
  if (!backupToken || !backupUser) { doLogout(); return; }
  // Restore admin session
  S.token        = backupToken;
  S.refreshToken = backupRefresh || null;
  S.user         = JSON.parse(backupUser);
  localStorage.setItem('access_token', backupToken);
  if (backupRefresh) localStorage.setItem('refresh_token', backupRefresh);
  localStorage.setItem('user', backupUser);
  localStorage.removeItem('admin_backup_token');
  localStorage.removeItem('admin_backup_refresh');
  localStorage.removeItem('admin_backup_user');
  // Hide banner
  document.getElementById('impersonate-banner').style.display = 'none';
  document.getElementById('app-screen').classList.remove('impersonating');
  // Re-init as admin
  await loadCategories();
  await loadWalletsData();
  updateSidebarUser();
  goTo('admin-users');
  toast('عدت إلى حسابك كأدمن ✅');
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
          <th>الهاتف</th>
          <th>العملة</th>
          <th>الباقة</th>
          <th>الحالة</th>
          <th>أدمن</th>
          <th>الإجراءات</th>
        </tr></thead>
        <tbody>
          ${_adminUsers.map(u => {
            const planLabels = { trial: '🆓 تجربة', free: '🔒 مجاني', pro: '⭐ Pro', business: '🏢 Business' };
            const planBadgeClass = { trial: 'bg-info text-dark', free: 'bg-secondary', pro: 'bg-warning text-dark', business: 'bg-success' };
            const pl = u.plan || 'trial';
            return `
            <tr>
              <td>${esc(u.full_name)}</td>
              <td dir="ltr">${esc(u.email)}</td>
              <td dir="ltr">${u.phone_number ? esc(u.phone_number) : '<span class="text-muted">—</span>'}</td>
              <td>${esc(u.currency)}</td>
              <td><span class="badge ${planBadgeClass[pl] || 'bg-secondary'}">${planLabels[pl] || pl}</span></td>
              <td><span class="badge ${u.is_active ? 'bg-success' : 'bg-secondary'}">${u.is_active ? 'مفعّل' : 'معطّل'}</span></td>
              <td>${u.is_admin ? '<span class="badge bg-warning text-dark">أدمن</span>' : ''}</td>
              <td>
                <button class="btn btn-sm btn-primary me-1" onclick="viewAsUser('${u.id}', '${esc(u.full_name)}')" title="مشاهدة الحساب"><i class="fas fa-eye"></i></button>
                <button class="btn btn-sm btn-outline-primary me-1" onclick="openEditUserModal('${u.id}')"><i class="fas fa-edit"></i></button>
                <button class="btn btn-sm btn-outline-danger" onclick="deleteAdminUser('${u.id}', '${esc(u.full_name)}')"><i class="fas fa-trash"></i></button>
              </td>
            </tr>`;
          }).join('')}
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
  document.getElementById('um-phone').value = '';
  document.getElementById('um-pass').value = '';
  document.getElementById('um-pass').placeholder = 'أدخل كلمة المرور (مطلوبة)';
  document.getElementById('um-pass-hint').style.display = 'none';
  document.getElementById('um-currency').value = 'IQD';
  document.getElementById('um-plan').value = 'trial';
  document.getElementById('um-plan-expires').value = '';
  document.getElementById('um-admin').checked = false;
  document.getElementById('um-active').checked = true;
  ['um-c-daily','um-c-wallets','um-c-cats','um-c-budgets','um-c-goals','um-c-voice'].forEach(id => {
    const el = document.getElementById(id); if (el) el.value = '';
  });
  toggleCustomPlanFields();
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
  document.getElementById('um-phone').value = u.phone_number || '';
  document.getElementById('um-pass').value = '';
  document.getElementById('um-pass').placeholder = 'أدخل كلمة مرور جديدة';
  document.getElementById('um-pass-hint').style.display = '';
  document.getElementById('um-currency').value = u.currency || 'IQD';
  document.getElementById('um-plan').value = u.plan || 'trial';
  document.getElementById('um-plan-expires').value = u.plan_expires_at ? u.plan_expires_at.split('T')[0] : '';
  document.getElementById('um-admin').checked = u.is_admin;
  document.getElementById('um-active').checked = u.is_active;
  // Populate custom plan limit fields
  const setNum = (id, val) => { const el = document.getElementById(id); if (el) el.value = val ?? ''; };
  setNum('um-c-daily',   u.custom_daily_expenses);
  setNum('um-c-wallets', u.custom_wallets);
  setNum('um-c-cats',    u.custom_categories);
  setNum('um-c-budgets', u.custom_budgets);
  setNum('um-c-goals',   u.custom_goals);
  setNum('um-c-voice',   u.custom_voice_monthly);
  toggleCustomPlanFields();
  new bootstrap.Modal(document.getElementById('userModal')).show();
}

function togglePass(inputId, btn) {
  const inp  = document.getElementById(inputId);
  const icon = btn.querySelector('i');
  if (!inp) return;
  if (inp.type === 'password') {
    inp.type = 'text';
    icon.className = 'fas fa-eye-slash';
  } else {
    inp.type = 'password';
    icon.className = 'fas fa-eye';
  }
}

function toggleAdminPass(btn) {
  togglePass('um-pass', btn);
}

function toggleCustomPlanFields() {
  const plan = document.getElementById('um-plan')?.value;
  const wrap = document.getElementById('um-custom-limits');
  if (wrap) wrap.style.display = plan === 'custom' ? '' : 'none';
}

async function saveUser() {
  const id       = document.getElementById('um-id').value;
  const name     = document.getElementById('um-name').value.trim();
  const email    = document.getElementById('um-email').value.trim();
  const phone    = document.getElementById('um-phone').value.trim() || null;
  const pass     = document.getElementById('um-pass').value;
  const currency = document.getElementById('um-currency').value;
  const plan     = document.getElementById('um-plan').value;
  const planExpires = document.getElementById('um-plan-expires').value || null;
  const isAdmin  = document.getElementById('um-admin').checked;
  const isActive = document.getElementById('um-active').checked;

  if (!name) { toast('أدخل الاسم', 'err'); return; }

  // Collect custom plan limits (null means "not set")
  const getNum = id => { const v = document.getElementById(id)?.value; return v !== '' && v != null ? parseInt(v, 10) : null; };
  const customLimits = {
    custom_daily_expenses: getNum('um-c-daily'),
    custom_wallets:        getNum('um-c-wallets'),
    custom_categories:     getNum('um-c-cats'),
    custom_budgets:        getNum('um-c-budgets'),
    custom_goals:          getNum('um-c-goals'),
    custom_voice_monthly:  getNum('um-c-voice'),
  };

  loading(true);
  try {
    if (!id) {
      // Create
      if (!email) { toast('أدخل البريد', 'err'); return; }
      if (!pass)  { toast('أدخل كلمة المرور', 'err'); return; }
      await api('POST', '/admin/users', { full_name: name, email, phone_number: phone, password: pass, currency, is_admin: isAdmin, plan, plan_expires_at: planExpires, ...customLimits });
      toast('تم إنشاء الحساب ✅');
    } else {
      // Update
      const body = { full_name: name, phone_number: phone, currency, is_admin: isAdmin, is_active: isActive, plan, plan_expires_at: planExpires, ...customLimits };
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

// ── Referral ─────────────────────────────────────────────────
let _referralLink = '';

function toggleReferralDropdown() {
  const drop = document.getElementById('sidebar-referral-dropdown');
  const chevron = document.getElementById('ref-chevron');
  if (!drop) return;

  const isOpen = drop.style.display !== 'none';
  if (isOpen) { closeReferralDropdown(); return; }

  drop.style.display = '';
  if (chevron) chevron.style.transform = 'rotate(180deg)';

  if (!_referralLink) _fetchReferralLink();
}

function closeReferralDropdown() {
  const drop = document.getElementById('sidebar-referral-dropdown');
  const chevron = document.getElementById('ref-chevron');
  if (drop) drop.style.display = 'none';
  if (chevron) chevron.style.transform = '';
}

async function _fetchReferralLink() {
  try {
    const data = await api('GET', '/auth/referral-info');
    _referralLink = data.referral_link || '';
    const el = document.getElementById('srd-link-text');
    if (el) el.textContent = _referralLink || '—';
    // Also update settings page elements if loaded
    const linkEl  = document.getElementById('ref-link-text');
    const countEl = document.getElementById('ref-count');
    const bonusEl = document.getElementById('ref-bonus-days');
    if (linkEl)  linkEl.textContent  = _referralLink;
    if (countEl) countEl.textContent = data.referral_count || 0;
    if (bonusEl) bonusEl.textContent = data.referral_bonus_days || 0;
    _bindShareButtons(data);
  } catch(e) { console.error('referral fetch:', e); }
}

function _bindShareButtons(data) {
  const link = data.referral_link || '';
  const shareText = `استخدم تطبيق مصاريفي لتتبع مصاريفك بسهولة! سجّل الآن: ${link}`;
  const copyBtn = document.getElementById('ref-copy-btn');
  const waBtn   = document.getElementById('ref-share-wa');
  const tgBtn   = document.getElementById('ref-share-tg');
  const xBtn    = document.getElementById('ref-share-x');
  if (copyBtn) copyBtn.onclick = () => _copyLink(link);
  if (waBtn) waBtn.onclick = (e) => { e.preventDefault(); window.open(`https://wa.me/?text=${encodeURIComponent(shareText)}`, '_blank'); };
  if (tgBtn) tgBtn.onclick = (e) => { e.preventDefault(); window.open(`https://t.me/share/url?url=${encodeURIComponent(link)}&text=${encodeURIComponent('استخدم تطبيق مصاريفي!')}`, '_blank'); };
  if (xBtn)  xBtn.onclick  = (e) => { e.preventDefault(); window.open(`https://x.com/intent/tweet?text=${encodeURIComponent(shareText)}`, '_blank'); };
}

function _copyLink(link) {
  navigator.clipboard.writeText(link)
    .then(() => toast('تم نسخ الرابط ✅'))
    .catch(() => {
      const ta = document.createElement('textarea');
      ta.value = link; document.body.appendChild(ta); ta.select();
      document.execCommand('copy'); document.body.removeChild(ta);
      toast('تم نسخ الرابط ✅');
    });
}

function copyReferralFromSidebar() {
  if (_referralLink) _copyLink(_referralLink);
}

function shareReferral(platform) {
  if (!_referralLink) return;
  const text = `استخدم تطبيق مصاريفي لتتبع مصاريفك بسهولة! سجّل الآن: ${_referralLink}`;
  const urls = {
    wa:    `https://wa.me/?text=${encodeURIComponent(text)}`,
    viber: `viber://forward?text=${encodeURIComponent(text)}`,
    tg:    `https://t.me/share/url?url=${encodeURIComponent(_referralLink)}&text=${encodeURIComponent('استخدم تطبيق مصاريفي!')}`,
  };
  window.open(urls[platform], '_blank');
}

async function loadReferral() {
  if (!_referralLink) await _fetchReferralLink();
}

// ── FAB Voice Assistant code is in inline script in index.html ──

// ── Bootstrap ────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', async () => {
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

  // Close referral dropdown when clicking outside it
  document.addEventListener('click', function(e) {
    const wrap = document.getElementById('sidebar-referral-wrap');
    if (wrap && !wrap.contains(e.target)) closeReferralDropdown();
  });

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

  // Safety net: if boot takes > 10 s, force-dismiss spinner and show login
  const _bootTimeout = setTimeout(() => {
    loading(false);
    if (!S.token) {
      document.getElementById('auth-screen').style.display = '';
      showAuthTab('login');
    }
  }, 10000);

  if (S.token && S.user) {
    try {
      await initApp(true);
      clearTimeout(_bootTimeout);
      // Restore impersonation banner if page was refreshed while impersonating
      if (localStorage.getItem('admin_backup_token') && S.user) {
        document.getElementById('impersonate-banner').style.display = '';
        document.getElementById('impersonate-name').textContent = `أنت تشاهد حساب: ${S.user.full_name}`;
        document.getElementById('app-screen').classList.add('impersonating');
      }
    } catch(e) {
      console.error('Boot error:', e);
      loading(false);
    }
  } else {
    document.getElementById('auth-screen').style.display = '';
    // Auto-detect ?ref=CODE in URL → show register tab with pre-filled referral code
    const urlRef = new URLSearchParams(window.location.search).get('ref');
    if (urlRef) {
      showAuthTab('register');
      const inp = document.getElementById('r-ref-code');
      const wrap = document.getElementById('r-ref-wrap');
      const hint = document.getElementById('r-ref-hint');
      if (inp) inp.value = urlRef.toUpperCase();
      if (wrap) wrap.style.display = '';
      if (hint) hint.style.display = '';
    } else {
      showAuthTab('login');
    }
    loading(false);
    clearTimeout(_bootTimeout);
  }
});
