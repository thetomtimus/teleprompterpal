import { execFileSync } from 'node:child_process';
import { cp, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const website = resolve(root, '../Website');
const output = resolve(root, 'dist');
const python = process.env.PYTHON || 'python3';

// Keep the existing policy/support sources authoritative for every deployment.
execFileSync(python, [resolve(website, 'build.py'), '--release'], { stdio: 'inherit' });
execFileSync(python, [resolve(website, 'check.py'), resolve(website, 'release'), '--release'], { stdio: 'inherit' });
for (const entry of ['privacy', 'support', 'assets', '404.html']) {
  await cp(resolve(website, 'release', entry), resolve(output, entry), { recursive: true });
}

// Provenance stays in the repository; only runtime assets are served.
for (const name of await readdir(resolve(output, 'images'))) {
  if (name.endsWith('.json')) await rm(resolve(output, 'images', name));
}

const preview = process.env.VERCEL_ENV === 'preview';
await writeFile(resolve(output, 'robots.txt'), preview
  ? 'User-agent: *\nDisallow: /\n'
  : 'User-agent: *\nAllow: /\nSitemap: https://teleprompterpal.com/sitemap.xml\n');
await writeFile(resolve(output, 'sitemap.xml'), '<?xml version="1.0" encoding="UTF-8"?>\n'
  + '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
  + ['', 'privacy/', 'support/'].map(path => `  <url><loc>https://teleprompterpal.com/${path}</loc></url>`).join('\n')
  + '\n</urlset>\n');

const html = await readFile(resolve(output, 'index.html'), 'utf8');
if (/<script\b(?![^>]*\bsrc=)[^>]*>[\s\S]*?\S[\s\S]*?<\/script>/i.test(html)) {
  throw new Error('The production CSP requires scripts to be served as separate assets.');
}
if (!html.includes('rel="canonical" href="https://teleprompterpal.com/"')) {
  throw new Error('The homepage must declare its production canonical URL.');
}

// Keep a direct-deployment fallback alongside Git auto-deploy.
// Keep a clean, reproducible CLI input separate from source and credentials.
const staging = resolve(root, '.vercel/static-release');
await rm(staging, { recursive: true, force: true });
await cp(output, staging, { recursive: true });
const config = JSON.parse(await readFile(resolve(root, 'vercel.json'), 'utf8'));
Object.assign(config, { framework: null, buildCommand: '', installCommand: '', outputDirectory: '.' });
await writeFile(resolve(staging, 'vercel.json'), JSON.stringify(config, null, 2) + '\n');
console.log('Deployment includes marketing, privacy, support, 404, robots, and sitemap.');
