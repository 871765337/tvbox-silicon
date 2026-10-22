import test from 'node:test';
import assert from 'node:assert/strict';
import worker from './worker.mjs';

const request = (route, body) => new Request('https://review.example' + route, body === undefined ? {} : { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
const api = async (route, body) => (await worker.fetch(request(route, body), {})).json();

test('guest can discover the fixture and browse all 125 files without pagination', async () => {
  assert.equal((await api('/api/public/settings')).code, 200);
  const root = await api('/api/fs/list', { path: '/', per_page: 0 });
  assert(root.data.content.some(x => x.name === 'Samples' && x.is_dir));
  const all = await api('/api/fs/list', { path: '/Samples/Large Folder', per_page: 0 });
  assert.equal(all.data.total, 125);
  assert.equal(new Set(all.data.content.map(x => x.name)).size, 125);
  const paged = await api('/api/fs/list', { path: '/Samples/Large Folder', page: 2, per_page: 100 });
  assert.equal(paged.data.content.length, 25);
  assert.equal(paged.data.content[0].name, 'File 101.txt');
});
test('empty and missing folders have distinct results; traversal is rejected', async () => {
  assert.deepEqual((await api('/api/fs/list', { path: '/Samples/Empty' })).data.content, []);
  assert.equal((await api('/api/fs/list', { path: '/missing' })).code, 404);
  assert.equal((await api('/api/fs/list', { path: '/Samples/../secret' })).code, 400);
});
test('protected folder rejects absent or incorrect passwords and accepts the demo value', async () => {
  for (const password of ['', 'wrong']) assert.equal((await api('/api/fs/list', { path: '/Samples/Protected', password })).code, 403);
  const answer = await api('/api/fs/list', { path: '/Samples/Protected', password: 'yingxia-demo' });
  assert.equal(answer.code, 200);
  assert.equal(answer.data.content[0].name, 'Protected Sample.mp4');
  assert.equal((await api('/api/fs/get', { path: '/Samples/Protected/Protected Sample.mp4' })).code, 403);
});
test('Unicode paths resolve to playable links with precise byte ranges', async () => {
  const path = '/Samples/Nested/中文 文件夹';
  const file = (await api('/api/fs/list', { path })).data.content[0];
  const link = await api('/api/fs/get', { path: path + '/' + file.name });
  assert.equal(link.code, 200);
  let forwarded;
  const response = await worker.fetch(new Request(link.data.raw_url, { headers: { Range: 'bytes=1-2' } }), { ASSETS: { fetch: async r => { forwarded = r; return new Response('test', { headers: { 'Content-Type': 'video/mp4' } }); } } });
  assert.equal(response.status, 206);
  assert.equal(new URL(forwarded.url).pathname, '/samples/review.mp4');
  assert.equal(response.headers.get('Content-Range'), 'bytes 1-2/4');
  assert.equal(response.headers.get('Content-Length'), '2');
  assert.equal(await response.text(), 'es');
});
test('suffix, open-ended and invalid ranges follow HTTP range semantics', async () => {
  const url = 'https://review.example/d/Samples/Sample%20Video.mp4';
  const env = { ASSETS: { fetch: async () => new Response('0123456789') } };
  for (const [range, expected] of [['bytes=-3', '789'], ['bytes=8-', '89'], ['bytes=8-999', '89']]) {
    const r = await worker.fetch(new Request(url, { headers: { Range: range } }), env);
    assert.equal(r.status, 206);
    assert.equal(await r.text(), expected);
  }
  for (const range of ['bytes=10-', 'bytes=3-2', 'bytes=-0', 'bytes=-', 'bytes=0-1,3-4']) {
    assert.equal((await worker.fetch(new Request(url, { headers: { Range: range } }), env)).status, 416);
  }
  const head = await worker.fetch(new Request(url, { method: 'HEAD' }), env);
  assert.equal(head.headers.get('Content-Length'), '10');
  assert.equal(await head.text(), '');
});
test('listed text metadata matches content and write methods do not work', async () => {
  const files = (await api('/api/fs/list', { path: '/Samples/Mixed Files' })).data.content;
  for (const file of files.filter(f => /\.(txt|srt)$/.test(f.name))) {
    const path = '/Samples/Mixed Files/' + file.name;
    const info = await api('/api/fs/get', { path });
    const body = await worker.fetch(new Request(info.data.raw_url), {});
    assert.equal((await body.arrayBuffer()).byteLength, file.size);
    assert.equal((await worker.fetch(new Request(info.data.raw_url, { method: 'DELETE' }), {})).status, 405);
  }
  assert.equal((await api('/api/fs/get', { path: '/Samples' })).code, 404);
});
