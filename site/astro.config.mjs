import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://maxbolgarin.github.io',
  base: '/gitbasher',
  trailingSlash: 'always',
  compressHTML: true,
  build: {
    inlineStylesheets: 'auto',
  },
  integrations: [
    sitemap({
      filter: (page) => !page.endsWith('/404/') && page !== 'https://maxbolgarin.github.io/gitbasher',
    }),
  ],
});
