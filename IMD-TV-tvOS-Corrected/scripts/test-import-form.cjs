const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');
const source = readFileSync(resolve(__dirname, '../IMDTV/Networking/LocalImportServer.swift'), 'utf8');
const script = source.match(/<script>([\s\S]*?)<\/script>/)[1];

function setup() {
  function element(value = '') {
    return { value, disabled: false, hidden: false, textContent: '', files: [], handlers: {},
      addEventListener(name, handler) { this.handlers[name] = handler; } };
  }
  const fields = Object.fromEntries(['playlistURL', 'serverURL', 'epgURL', 'username', 'password'].map(name => [name, element()]));
  const ids = Object.fromEntries(['p', 'm', 'x', 'file', 'content', 'message'].map(name => [name, element()]));
  ids.p.value = 'm3u';
  ids.m.querySelectorAll = () => [fields.playlistURL, fields.epgURL, ids.file, ids.content];
  ids.x.querySelectorAll = () => [fields.serverURL, fields.username, fields.password];
  const button = element();
  const form = element();
  form.elements = { namedItem: name => fields[name] };
  form.querySelector = () => button;
  form.submitted = 0;
  const context = { document: { querySelector: () => form, getElementById: id => ids[id] },
    HTMLFormElement: { prototype: { submit() { this.submitted++; } } } };
  // No browser named-element globals: the script must resolve elements explicitly.
  vm.runInNewContext(script, context);
  return { fields, ids, button, form, submit: () => form.handlers.submit({ preventDefault() {} }) };
}

test('URL import works with optional fields blank', async () => {
  const s = setup(); s.fields.playlistURL.value = 'https://example.com/list.m3u';
  await s.submit(); assert.equal(s.form.submitted, 1);
  assert.equal(s.fields.serverURL.disabled, true);
});
test('file import reads the selected file including after replacement', async () => {
  const s = setup(); s.ids.file.files = [{ size: 50, text: async () => '\uFEFF\n#EXTM3U\nfirst' }];
  await s.submit(); assert.equal(s.ids.content.value, '#EXTM3U\nfirst');
  s.ids.file.files = [{ size: 50, text: async () => '#EXTM3U\nsecond' }];
  s.ids.file.handlers.change(); await s.submit();
  assert.equal(s.ids.content.value, '#EXTM3U\nsecond');
});
test('switching to Xtream disables and clears stale file data', async () => {
  const s = setup(); s.ids.content.value = '#EXTM3U\nold';
  s.ids.p.value = 'xtream'; s.ids.p.handlers.change();
  s.fields.serverURL.value = 'https://example.com'; s.fields.username.value = 'u'; s.fields.password.value = 'p';
  await s.submit(); assert.equal(s.form.submitted, 1);
  assert.equal(s.ids.content.value, ''); assert.equal(s.ids.file.disabled, true);
  assert.equal(s.fields.serverURL.disabled, false);
});
test('empty source, unreadable file, invalid file and large file remain retryable', async () => {
  for (const file of [null, { size: 10, text: async () => { throw new Error('Read failed'); } },
    { size: 10, text: async () => '<html>Error</html>' }, { size: 5000001 }]) {
    const s = setup(); s.ids.file.files = file ? [file] : [];
    await s.submit(); assert.equal(s.form.submitted, 0);
    assert.equal(s.button.disabled, false); assert.ok(s.ids.message.textContent);
  }
});
