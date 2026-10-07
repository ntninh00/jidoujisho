'use strict';

// The strings page: every string of the app in one language, with its
// English, to search and fix. A string saves when its box loses focus, or
// with Ctrl+Enter.

const TOKEN_KEY = 'jdj-strings-token';
const LANGUAGE_KEY = 'jdj-strings-language';
const PLACEHOLDER = /\$[A-Za-z_][A-Za-z0-9_]*/g;
const GROWS_ITSELF = typeof CSS !== 'undefined' && CSS.supports && CSS.supports('field-sizing', 'content');

const state = {
  token: null,
  role: null,
  languages: [],
  code: null,
  rows: [],
  filter: 'all',
  query: '',
};

const $ = (id) => document.getElementById(id);

function remember(key, value) {
  try {
    if (value == null) localStorage.removeItem(key);
    else localStorage.setItem(key, value);
  } catch (_) { /* private window: nothing kept */ }
}

function recall(key) {
  try { return localStorage.getItem(key); } catch (_) { return null; }
}

function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text != null) node.textContent = text;
  return node;
}

async function api(path, options = {}) {
  const headers = { Authorization: `Bearer ${state.token}` };
  if (options.body) headers['Content-Type'] = 'application/json';
  const response = await fetch(path, { ...options, headers });
  const text = await response.text();
  let body = null;
  try { body = text ? JSON.parse(text) : null; } catch (_) { body = null; }
  if (!response.ok) {
    const error = new Error((body && body.error) || `The server answered ${response.status}.`);
    error.status = response.status;
    throw error;
  }
  return body;
}

let toastTimer = null;
function toast(message) {
  const node = $('toast');
  node.textContent = message;
  node.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { node.hidden = true; }, 3200);
}

function saveFile(name, text) {
  const blob = new Blob([text], { type: 'text/plain;charset=utf-8' });
  const link = document.createElement('a');
  link.href = URL.createObjectURL(blob);
  link.download = name;
  document.body.append(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(link.href), 4000);
}

/* ---------- the token ---------- */

function showGate(message) {
  $('app').hidden = true;
  $('gate').hidden = false;
  $('gate-error').hidden = !message;
  $('gate-error').textContent = message || '';
  $('gate-token').focus();
}

function gateMessage(error) {
  return error.status === 401 ? "That token isn't right." : error.message;
}

async function openPage() {
  const me = await api('/api/me');
  state.role = me.role;
  await loadLanguages();
  $('gate').hidden = true;
  $('app').hidden = false;
  const codes = state.languages.map((language) => language.code);
  const saved = recall(LANGUAGE_KEY);
  const first = codes.includes(saved) ? saved : codes.find((code) => code !== 'en') || 'en';
  await selectLanguage(first);
}

$('gate-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  state.token = $('gate-token').value.trim();
  try {
    await openPage();
    remember(TOKEN_KEY, state.token);
  } catch (error) {
    showGate(gateMessage(error));
  }
});

/* ---------- languages ---------- */

function languageOf(code) {
  return state.languages.find((language) => language.code === code);
}

async function loadLanguages() {
  const body = await api('/api/strings');
  state.languages = body.languages;
  const options = state.languages.map((language) => {
    const option = element('option', null, `${language.name} (${language.code})`);
    option.value = language.code;
    return option;
  });
  $('language').replaceChildren(...options);
  if (state.code) $('language').value = state.code;
}

async function selectLanguage(code) {
  state.code = code;
  $('language').value = code;
  remember(LANGUAGE_KEY, code);
  const body = await api(`/api/strings/${encodeURIComponent(code)}`);
  state.rows = body.strings;
  render();
  updateRemoveButton();
}

$('language').addEventListener('change', async (event) => {
  try {
    await selectLanguage(event.target.value);
  } catch (error) {
    toast(error.message);
  }
});

/* ---------- rows ---------- */

function fold(text) {
  return (text || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[đĐ]/g, 'd')
    .toLowerCase();
}

function placeholdersOf(text) {
  return [...new Set(text.match(PLACEHOLDER) || [])];
}

function grow(input) {
  if (GROWS_ITSELF) return;
  input.style.height = 'auto';
  input.style.height = `${input.scrollHeight + 2}px`;
}

function guessRows(text) {
  return Math.max(1, text.split('\n').reduce((rows, line) => rows + Math.ceil((line.length || 1) / 64), 0));
}

function setNote(row, text, kind) {
  row.note.textContent = text || '';
  row.note.className = `note${kind ? ` is-${kind}` : ''}`;
  row.element.classList.toggle('is-error', kind === 'error');
  clearTimeout(row.noteTimer);
  if (kind === 'ok') {
    row.noteTimer = setTimeout(() => setNote(row, ''), 2200);
  }
}

function updateRowState(row) {
  const labels = { edit: 'Edited', upload: 'Uploaded' };
  const label = row.value == null ? 'Missing' : labels[row.source];
  row.pill.hidden = !label;
  row.pill.textContent = label || '';
  row.pill.className = `pill ${row.value == null ? 'missing' : row.source}`;
  row.revert.hidden = row.source !== 'edit';
  row.search = fold(`${row.key}\n${row.english}\n${row.value || ''}`);
}

function buildRow(row) {
  const article = element('article', 'row');
  const head = element('div', 'row-head');
  head.append(element('code', 'key', row.key));
  for (const name of placeholdersOf(row.english)) {
    const chip = element('span', 'placeholder', name);
    chip.title = 'The app fills this in; keep it in the text.';
    head.append(chip);
  }
  row.pill = element('span', 'pill');
  head.append(row.pill);

  const english = element('p', 'english', row.english);
  english.lang = 'en';

  const input = document.createElement('textarea');
  input.value = row.value ?? '';
  input.rows = guessRows(input.value || row.english);
  input.lang = state.code;
  input.setAttribute('aria-label', row.key);

  const foot = element('div', 'row-foot');
  row.note = element('p', 'note');
  row.revert = element('button', 'revert', 'Revert to the original');
  row.revert.type = 'button';
  foot.append(row.note, row.revert);

  article.append(head, english, input, foot);
  row.element = article;
  row.input = input;
  row.saved = input.value;

  input.addEventListener('focus', () => grow(input));
  input.addEventListener('input', () => {
    grow(input);
    if (input.value !== row.saved) setNote(row, 'Saves when you leave the box');
    else setNote(row, '');
  });
  input.addEventListener('blur', () => save(row));
  input.addEventListener('keydown', (event) => {
    if (event.key === 'Enter' && (event.ctrlKey || event.metaKey)) {
      event.preventDefault();
      save(row);
    } else if (event.key === 'Escape') {
      input.value = row.saved;
      grow(input);
      setNote(row, '');
    }
  });
  row.revert.addEventListener('click', () => revert(row));
  updateRowState(row);
  return article;
}

function render() {
  const fragment = document.createDocumentFragment();
  for (const row of state.rows) fragment.append(buildRow(row));
  $('rows').replaceChildren(fragment);
  applyFilter();
}

function isTodo(row) {
  return row.value == null || (state.code !== 'en' && row.value === row.english);
}

function applyFilter() {
  const query = fold(state.query.trim());
  let shown = 0;
  for (const row of state.rows) {
    const inFilter = state.filter === 'all'
      || (state.filter === 'edited' && row.source === 'edit')
      || (state.filter === 'todo' && isTodo(row));
    const visible = inFilter && (!query || row.search.includes(query));
    row.element.hidden = !visible;
    if (visible) shown += 1;
  }
  const translated = state.rows.filter((row) => row.value != null).length;
  $('count').textContent = `${shown} shown · ${translated}/${state.rows.length} translated`;
  $('empty').hidden = shown > 0;
}

let searchTimer = null;
$('search').addEventListener('input', (event) => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    state.query = event.target.value;
    applyFilter();
  }, 90);
});

for (const button of document.querySelectorAll('.filter')) {
  button.addEventListener('click', () => {
    state.filter = button.dataset.filter;
    for (const other of document.querySelectorAll('.filter')) {
      other.setAttribute('aria-pressed', String(other === button));
    }
    applyFilter();
  });
}

function takeUpdate(row, updated) {
  row.value = updated.value;
  row.source = updated.source;
  row.updatedAt = updated.updatedAt;
  row.saved = updated.value ?? '';
  updateRowState(row);
}

async function save(row) {
  const value = row.input.value;
  if (value === row.saved || value === row.pending) return;
  if (!value.trim()) {
    setNote(row, 'Write some text, or revert to the original.', 'error');
    return;
  }
  row.pending = value;
  setNote(row, 'Saving…');
  try {
    const updated = await api(
      `/api/strings/${encodeURIComponent(state.code)}/${encodeURIComponent(row.key)}`,
      { method: 'PUT', body: JSON.stringify({ value }) },
    );
    takeUpdate(row, updated);
    if (row.input.value === value) row.input.value = row.saved;
    setNote(row, 'Saved', 'ok');
    refreshCounts();
  } catch (error) {
    setNote(row, error.message, 'error');
  } finally {
    row.pending = null;
  }
}

async function revert(row) {
  try {
    const updated = await api(
      `/api/strings/${encodeURIComponent(state.code)}/${encodeURIComponent(row.key)}`,
      { method: 'DELETE' },
    );
    takeUpdate(row, updated);
    row.input.value = row.saved;
    grow(row.input);
    setNote(row, 'Back to the original', 'ok');
    refreshCounts();
  } catch (error) {
    setNote(row, error.message, 'error');
  }
}

let countsTimer = null;
function refreshCounts() {
  clearTimeout(countsTimer);
  countsTimer = setTimeout(async () => {
    try {
      await loadLanguages();
      updateRemoveButton();
      applyFilter();
    } catch (_) { /* the counts can wait */ }
  }, 600);
}

window.addEventListener('beforeunload', (event) => {
  if (state.rows.some((row) => row.input && row.input.value !== row.saved)) {
    event.preventDefault();
    event.returnValue = '';
  }
});

/* ---------- panels ---------- */

function togglePanel(button, panel) {
  const open = panel.hidden;
  for (const [otherButton, otherPanel] of [[$('open-add'), $('panel-add')], [$('open-prompts'), $('panel-prompts')]]) {
    otherPanel.hidden = true;
    otherButton.setAttribute('aria-expanded', 'false');
  }
  panel.hidden = !open;
  button.setAttribute('aria-expanded', String(open));
}

$('open-add').addEventListener('click', () => togglePanel($('open-add'), $('panel-add')));
$('open-prompts').addEventListener('click', () => togglePanel($('open-prompts'), $('panel-prompts')));

$('up-files').addEventListener('change', () => {
  const files = [...$('up-files').files];
  $('up-chosen').textContent = files.length
    ? files.map((file) => file.name).join(', ')
    : 'Choose reply files';
});

function showReport(lines) {
  const report = $('up-report');
  report.replaceChildren(...lines);
  report.hidden = false;
}

function reportOf(result) {
  const lines = [];
  const first = element('p');
  first.append(element('strong', null, `${result.name} (${result.code})`));
  first.append(`: ${result.taken} strings taken.`);
  lines.push(first);
  if (result.keptEdits) {
    lines.push(element('p', null, `Your ${result.keptEdits} edited strings stayed as they were.`));
  }
  if (result.missing.length) {
    lines.push(element('p', null, `${result.missing.length} strings are still missing and show in English. Pick Not translated to fill them in.`));
  }
  if (result.unreadable) {
    lines.push(element('p', null, `${result.unreadable} of the replies had no JSON in them.`));
  }
  if (result.skipped.length) {
    lines.push(element('p', null, `${result.skipped.length} strings were left out:`));
    const list = element('ul');
    for (const skipped of result.skipped) {
      const item = element('li');
      item.append(element('code', null, skipped.key), ` ${skipped.reason}`);
      list.append(item);
    }
    lines.push(list);
  }
  return lines;
}

$('up-go').addEventListener('click', async () => {
  const texts = [];
  for (const file of $('up-files').files) texts.push(await file.text());
  if ($('up-paste').value.trim()) texts.push($('up-paste').value);
  if (!texts.length) {
    showReport([element('p', 'error', 'Choose the reply files or paste a reply first.')]);
    return;
  }
  const button = $('up-go');
  button.disabled = true;
  button.textContent = 'Uploading…';
  try {
    const result = await api('/api/strings/upload', {
      method: 'POST',
      body: JSON.stringify({
        code: $('up-code').value.trim() || null,
        name: $('up-name').value.trim() || null,
        texts,
      }),
    });
    showReport(reportOf(result));
    $('up-files').value = '';
    $('up-chosen').textContent = 'Choose reply files';
    $('up-paste').value = '';
    await loadLanguages();
    await selectLanguage(result.code);
  } catch (error) {
    showReport([element('p', 'error', error.message)]);
  } finally {
    button.disabled = false;
    button.textContent = 'Upload';
  }
});

let removeArmed = false;
function updateRemoveButton() {
  const button = $('remove-language');
  const language = languageOf(state.code);
  const changed = language && (!language.builtIn || language.edited > 0 || language.updatedAt);
  button.hidden = state.role !== 'admin' || !changed || state.code === 'en';
  removeArmed = false;
  if (language) {
    button.textContent = language.builtIn
      ? `Undo every change to ${language.name}`
      : `Remove ${language.name}`;
  }
}

$('remove-language').addEventListener('click', async () => {
  const button = $('remove-language');
  if (!removeArmed) {
    removeArmed = true;
    button.textContent = 'Tap again to confirm';
    return;
  }
  try {
    await api(`/api/strings/${encodeURIComponent(state.code)}`, { method: 'DELETE' });
    toast('Done');
    await loadLanguages();
    const next = languageOf(state.code) ? state.code : 'en';
    await selectLanguage(next);
  } catch (error) {
    toast(error.message);
  }
});

for (const button of document.querySelectorAll('[data-prompt]')) {
  button.addEventListener('click', async () => {
    const language = $('pr-language').value.trim();
    if (!language) {
      $('pr-language').focus();
      toast('Name the target language first.');
      return;
    }
    try {
      const body = await api(`/api/strings/prompts?language=${encodeURIComponent(language)}`);
      const which = button.dataset.prompt;
      if (which === 'system') saveFile('system-prompt.md', body.system);
      else saveFile(`message-part${Number(which) + 1}.txt`, body.messages[Number(which)]);
    } catch (error) {
      toast(error.message);
    }
  });
}

$('download').addEventListener('click', async () => {
  try {
    const body = await api(`/api/strings/${encodeURIComponent(state.code)}/export`);
    const name = state.code === 'en' ? 'strings.i18n.json' : `strings_${state.code}.i18n.json`;
    saveFile(name, `${JSON.stringify(body, null, 4)}\n`);
  } catch (error) {
    toast(error.message);
  }
});

/* ---------- start ---------- */

(async function start() {
  const fromLink = location.hash.slice(1);
  if (fromLink) {
    remember(TOKEN_KEY, decodeURIComponent(fromLink));
    history.replaceState(null, '', location.pathname);
  }
  state.token = recall(TOKEN_KEY);
  if (!state.token) {
    showGate();
    return;
  }
  try {
    await openPage();
  } catch (error) {
    if (error.status === 401) remember(TOKEN_KEY, null);
    showGate(gateMessage(error));
  }
})();
