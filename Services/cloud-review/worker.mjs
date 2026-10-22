// Read-only AList v3-compatible review fixture. This is a demo, not an OpenList installation.
// All media is generated locally; no personal storage, accounts, uploads or third-party catalog.
import sizes from './sample-sizes.json' with { type: 'json' };

const modified = '2026-10-22T00:00:00Z';
const folderPassword = 'yingxia-demo'; // Public demo value, not a security boundary.
const readme = 'Yingxia cloud browsing review demo. All samples are generated for testing.\n';
const captions = '1\n00:00:00,000 --> 00:00:02,000\nDemo caption\n';
const textSize = new TextEncoder().encode(readme).length;
const item = (name, directory = false, size = 0) => ({ name, is_dir: directory, size, modified, created: modified });
const video = name => item(name, false, sizes['review.mp4']);
const audio = name => item(name, false, sizes['review.m4a']);
const folders = {
  '/': [item('Samples', true), item('README.txt', false, textSize)],
  '/Samples': [item('Nested', true), item('Empty', true), item('Large Folder', true), item('Protected', true), item('Mixed Files', true), video('Sample Video.mp4'), audio('Sample Audio.m4a')],
  '/Samples/Nested': [item('中文 文件夹', true), video('Episode 10.mp4'), video('Episode 2.mp4')],
  '/Samples/Nested/中文 文件夹': [video('中文名称 — 这是一段用于测试长文件名显示和文件夹导航的原创测试视频.mp4')],
  '/Samples/Empty': [],
  '/Samples/Large Folder': Array.from({ length: 125 }, (_, n) => item(`File ${n + 1}.txt`, false, textSize)),
  '/Samples/Protected': [video('Protected Sample.mp4')],
  '/Samples/Mixed Files': [video('Video.mp4'), audio('Audio.m4a'), item('Notes.txt', false, textSize), item('Captions.srt', false, new TextEncoder().encode(captions).length)],
};
const answer = (code, data = null, message = code === 200 ? 'success' : 'error') => Response.json({ code, message, data }, { headers: { 'Cache-Control': 'no-store' } });
const clean = path => typeof path === 'string' && path.startsWith('/') && !path.split('/').some(p => p === '.' || p === '..') ? path.replace(/\/+$/, '') || '/' : null;
const protectedPath = path => path === '/Samples/Protected' || path.startsWith('/Samples/Protected/');
const find = path => {
  const slash = path.lastIndexOf('/');
  return folders[path.slice(0, slash) || '/']?.find(file => file.name === path.slice(slash + 1));
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/api/public/settings' && request.method === 'GET') {
      return answer(200, { site_title: 'Yingxia Review Demo (AList compatible)', version: 'review-fixture-1' });
    }
    if (['/api/fs/list', '/api/fs/get'].includes(url.pathname)) {
      if (request.method !== 'POST') return new Response('Use POST', { status: 405, headers: { Allow: 'POST' } });
      if (Number(request.headers.get('Content-Length') || 0) > 4096) return answer(400, null, 'Request too large');
      let body;
      try {
        const raw = await request.text();
        if (raw.length > 4096) return answer(400, null, 'Request too large');
        body = JSON.parse(raw);
      } catch { return answer(400, null, 'Invalid JSON'); }
      const path = clean(body?.path);
      if (!path) return answer(400, null, 'Invalid path');
      if (protectedPath(path) && body.password !== folderPassword) return answer(403, null, 'Wrong password');
      if (url.pathname === '/api/fs/list') {
        if (!Object.hasOwn(folders, path)) return answer(404, null, 'Folder not found');
        const all = folders[path];
        const perPage = Number.isInteger(body.per_page) && body.per_page > 0 ? Math.min(body.per_page, 1000) : all.length;
        const page = Number.isInteger(body.page) && body.page > 0 ? body.page : 1;
        return answer(200, { content: all.slice((page - 1) * perPage, page * perPage), total: all.length, readme: '', write: false, provider: 'Yingxia generated review fixture' });
      }
      const file = find(path);
      if (!file || file.is_dir) return answer(404, null, 'File not found');
      return answer(200, { ...file, raw_url: url.origin + '/d' + path.split('/').map(encodeURIComponent).join('/'), sign: '', provider: 'Yingxia generated review fixture' });
    }
    if (url.pathname.startsWith('/d/')) {
      if (!['GET', 'HEAD'].includes(request.method)) return new Response('Read only', { status: 405 });
      let path;
      try { path = clean(decodeURIComponent(url.pathname.slice(2))); } catch { return new Response('Invalid path', { status: 400 }); }
      const file = path && find(path);
      if (!file || file.is_dir) return new Response('Not found', { status: 404 });
      // Files are intentionally public; the protected folder exercises the client's password UI.
      if (/\.(mp4|m4a)$/.test(file.name)) {
        url.pathname = '/samples/review.' + file.name.split('.').pop();
        // The asset binding may return 200 for a Range request. Serve explicit byte ranges,
        // which AVFoundation needs for seeking and the app's resource loader.
        const stored = await env.ASSETS.fetch(new Request(url, { method: 'GET' }));
        if (!stored.ok) return stored;
        const bytes = await stored.arrayBuffer();
        const headers = new Headers(stored.headers);
        headers.set('Accept-Ranges', 'bytes');
        headers.set('Content-Length', String(bytes.byteLength));
        const range = request.headers.get('Range');
        const ifRange = request.headers.get('If-Range');
        if (range && (!ifRange || ifRange === headers.get('ETag'))) {
          const match = /^bytes=(\d*)-(\d*)$/.exec(range);
          let start = match?.[1] ? Number(match[1]) : 0;
          let end = match?.[2] ? Number(match[2]) : bytes.byteLength - 1;
          if (match && !match[1] && match[2]) {
            start = Math.max(0, bytes.byteLength - Number(match[2]));
            end = bytes.byteLength - 1;
          }
          if (!match || (!match[1] && !match[2]) || start >= bytes.byteLength || end < start || !Number.isSafeInteger(start) || !Number.isSafeInteger(end)) {
            return new Response(null, { status: 416, headers: { 'Content-Range': `bytes */${bytes.byteLength}` } });
          }
          end = Math.min(end, bytes.byteLength - 1);
          headers.set('Content-Range', `bytes ${start}-${end}/${bytes.byteLength}`);
          headers.set('Content-Length', String(end - start + 1));
          return new Response(request.method === 'HEAD' ? null : bytes.slice(start, end + 1), { status: 206, headers });
        }
        return new Response(request.method === 'HEAD' ? null : bytes, { headers });
      }
      const body = file.name.endsWith('.srt') ? captions : readme;
      return new Response(request.method === 'HEAD' ? null : body, { headers: { 'Content-Type': 'text/plain; charset=utf-8', 'Content-Length': String(new TextEncoder().encode(body).length) } });
    }
    if (url.pathname.startsWith('/samples/')) return env.ASSETS.fetch(request);
    if (['GET', 'HEAD'].includes(request.method) && Object.hasOwn(folders, clean(decodeURI(url.pathname)) || '')) {
      url.pathname = '/';
      return env.ASSETS.fetch(new Request(url, request));
    }
    return new Response('Not found', { status: 404 });
  }
};
