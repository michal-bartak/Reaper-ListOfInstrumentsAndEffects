import starlight from '@astrojs/starlight';
import { defineConfig } from 'astro/config';

// GitHub Pages: served at
// https://michal-bartak.github.io/ListOfInstrumentsAndEffects/
// (base matches the repo name). Update both if the repo is renamed.
export default defineConfig({
  site: 'https://michal-bartak.github.io',
  base: '/ListOfInstrumentsAndEffects',
  integrations: [
    starlight({
      title: 'List of Instruments and Effects',
      description: 'List every plugin a REAPER project uses, grouped by category',
      // The master is ../icon/icon.svg, OUTSIDE this project -- it belongs to the
      // script, not to the site. Astro bundles it from there. The favicon is a
      // generated copy in public/, because Astro only serves that verbatim.
      favicon: '/favicon-32.png',
      logo: { src: '../icon/icon.svg', alt: '', replacesTitle: false },
      social: { github: 'https://github.com/michal-bartak/ListOfInstrumentsAndEffects' },
      head: [
        // `favicon` above emits its own <link> and prefixes the base path. These
        // do not, hence the literal /ListOfInstrumentsAndEffects.
        { tag: 'link', attrs: { rel: 'icon', type: 'image/png', sizes: '16x16', href: '/ListOfInstrumentsAndEffects/favicon-16.png' } },
        { tag: 'link', attrs: { rel: 'icon', type: 'image/png', sizes: '48x48', href: '/ListOfInstrumentsAndEffects/favicon-48.png' } },
        { tag: 'link', attrs: { rel: 'icon', type: 'image/svg+xml', href: '/ListOfInstrumentsAndEffects/favicon.svg' } },
      ],
      sidebar: [
        {
          label: 'Introduction',
          items: [
            { label: 'Overview', link: '/' },
            { label: 'Requirements', link: '/requirements/' },
            { label: 'Installation', link: '/installation/' },
          ],
        },
        {
          label: 'Usage',
          items: [
            { label: 'The window', link: '/usage/' },
            { label: 'What gets counted', link: '/counting/' },
            { label: 'Export formats', link: '/formats/' },
          ],
        },
        { label: 'Troubleshooting', link: '/troubleshooting/' },
        { label: 'Development', link: '/development/' },
      ],
    }),
  ],
});
