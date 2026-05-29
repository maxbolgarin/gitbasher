import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));

const files = {
  layout: join(root, 'src/layouts/Base.astro'),
  home: join(root, 'src/pages/index.astro'),
  robots: join(root, 'public/robots.txt'),
  manifest: join(root, 'public/manifest.webmanifest'),
};

const read = async (file) => readFile(file, 'utf8');

const checks = [
  {
    name: 'layout includes crawl-friendly robots metadata',
    run: async () => {
      const layout = await read(files.layout);
      return layout.includes('name="robots"') && layout.includes('max-image-preview:large');
    },
  },
  {
    name: 'layout exposes complete social image metadata',
    run: async () => {
      const layout = await read(files.layout);
      return (
        layout.includes('og:image:width') &&
        layout.includes('og:image:height') &&
        layout.includes('twitter:image:alt')
      );
    },
  },
  {
    name: 'layout emits WebSite and BreadcrumbList structured data',
    run: async () => {
      const layout = await read(files.layout);
      return layout.includes("'@type': 'WebSite'") && layout.includes("'@type': 'BreadcrumbList'");
    },
  },
  {
    name: 'home page targets high-intent gitbasher SEO terms',
    run: async () => {
      const home = await read(files.home);
      return (
        home.includes('git CLI wrapper') &&
        home.includes('AI commit messages') &&
        home.includes('conventional commits')
      );
    },
  },
  {
    name: 'robots advertises the canonical GitHub Pages sitemap',
    run: async () => {
      const robots = await read(files.robots);
      return robots.includes('Sitemap: https://maxbolgarin.github.io/gitbasher/sitemap-index.xml');
    },
  },
  {
    name: 'site has a web app manifest for search result enrichment',
    run: async () => {
      const manifest = await read(files.manifest);
      const parsed = JSON.parse(manifest);
      return parsed.name === 'Gitbasher' && parsed.start_url === '/gitbasher/';
    },
  },
];

const failures = [];

for (const check of checks) {
  try {
    if (!(await check.run())) {
      failures.push(check.name);
    }
  } catch (error) {
    failures.push(`${check.name}: ${error.message}`);
  }
}

if (failures.length > 0) {
  console.error('SEO checks failed:');
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log(`SEO checks passed (${checks.length})`);
