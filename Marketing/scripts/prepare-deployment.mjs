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
async function htmlPages(directory, prefix = '') {
  const pages = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = `${prefix}${entry.name}`;
    if (entry.isDirectory()) pages.push(...await htmlPages(resolve(directory, entry.name), `${path}/`));
    else if (entry.name.endsWith('.html')) pages.push(path);
  }
  return pages.sort();
}
const pages = await htmlPages(output);
const routes = pages.filter(page => page === 'index.html' || page.endsWith('/index.html'))
  .map(page => page.slice(0, -'index.html'.length));
await writeFile(resolve(output, 'robots.txt'), preview
  ? 'User-agent: *\nDisallow: /\n'
  : 'User-agent: *\nAllow: /\nSitemap: https://teleprompterpal.com/sitemap.xml\n');
await writeFile(resolve(output, 'sitemap.xml'), '<?xml version="1.0" encoding="UTF-8"?>\n'
  + '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
  + routes.map(path => `  <url><loc>https://teleprompterpal.com/${path}</loc></url>`).join('\n')
  + '\n</urlset>\n');

for (const page of pages) {
  const html = await readFile(resolve(output, page), 'utf8');
  if (/<script\b(?![^>]*\bsrc=)[^>]*>[\s\S]*?\S[\s\S]*?<\/script>/i.test(html)) {
    throw new Error(`The production CSP requires scripts to be separate assets: ${page}`);
  }
  if (page === 'index.html' || page.endsWith('/index.html')) {
    const canonical = `https://teleprompterpal.com/${page.slice(0, -'index.html'.length)}`;
    if (!html.includes(`rel="canonical" href="${canonical}"`)) {
      throw new Error(`Missing production canonical: ${page}`);
    }
  }
}

// Install the public Cloudflare beacon on every production page. Previews and
// the standalone legal-page review bundle do not send visitor measurements.
if (!preview) {
  const beacon = '<script type="module" src="https://static.cloudflareinsights.com/beacon.min.js" data-cf-beacon=\'{"token":"f7d3f127b85d4b23a0b7ed63cb31b62c"}\'></script>';
  const analyticsPolicy = "script-src https://static.cloudflareinsights.com; connect-src https://cloudflareinsights.com";
  for (const page of pages) {
    const path = resolve(output, page);
    let content = await readFile(path, 'utf8');
    // Copied legal pages also enforce a meta CSP, in addition to Vercel headers.
    content = content.replace(/(<meta http-equiv="Content-Security-Policy" content=")([^"]+)(")/,
      (_, start, policy, end) => `${start}${policy}; ${analyticsPolicy}${end}`);
    content = content.replace('</body>', `${beacon}</body>`);
    await writeFile(path, content);
  }
}

// Keep a direct-deployment fallback alongside Git auto-deploy.
// Keep a clean, reproducible CLI input separate from source and credentials.
const staging = resolve(root, '.vercel/static-release');
await rm(staging, { recursive: true, force: true });
await cp(output, staging, { recursive: true });
const config = JSON.parse(await readFile(resolve(root, 'vercel.json'), 'utf8'));
Object.assign(config, { framework: null, buildCommand: '', installCommand: '', outputDirectory: '.' });
await writeFile(resolve(staging, 'vercel.json'), JSON.stringify(config, null, 2) + '\n');
console.log(`Deployment includes ${routes.length} indexable routes, 404, analytics, robots, and sitemap.`);
