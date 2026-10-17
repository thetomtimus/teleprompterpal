import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://teleprompterpal.com',
  output: 'static',
  trailingSlash: 'always',
  devToolbar: { enabled: false },
});
