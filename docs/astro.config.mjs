import starlight from '@astrojs/starlight';
import { defineConfig } from 'astro/config';
import starlightThemeRapide from 'starlight-theme-rapide';

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
      plugins: [starlightThemeRapide()],
      // Restore Starlight's own theme picker: a labelled Dark/Light/Auto <select>.
      // starlight-theme-rapide replaces ThemeSelect with a sun/moon icon button whose click
      // handler only flips between dark and light, so "auto" (follow the OS) is unreachable once
      // you click it. Its overrideComponents() yields to an override declared here, logging one
      // build warning as it does so. NOTE that warning is expected, not a misconfiguration.
      // Header spacing then needs two rapide rules undone; see the theme-picker block in
      // src/styles/custom.css.
      components: {
        ThemeSelect: '@astrojs/starlight/components/ThemeSelect.astro',
      },
      // Renames the table-of-contents' top entry from "Overview" to the page title.
      routeMiddleware: './src/starlightRouteData.ts',
      customCss: ['./src/styles/custom.css'],
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
        // Click a screenshot in the docs body to view it full-size in a lightbox.
        // Runs on first load and after every Starlight client-side navigation.
        {
          tag: 'script',
          content: `
            (function () {
              function overlay() {
                var el = document.getElementById('img-lightbox');
                if (el) return el;
                el = document.createElement('div');
                el.id = 'img-lightbox';
                el.className = 'img-lightbox';
                el.innerHTML = '<img alt="">';
                el.addEventListener('click', function () { el.classList.remove('open'); });
                document.addEventListener('keydown', function (e) {
                  if (e.key === 'Escape') el.classList.remove('open');
                });
                document.body.appendChild(el);
                return el;
              }
              function wire() {
                var imgs = document.querySelectorAll('.sl-markdown-content img');
                for (var i = 0; i < imgs.length; i++) {
                  (function (img) {
                    if (img.dataset.lightbox) return;
                    img.dataset.lightbox = '1';
                    img.addEventListener('click', function () {
                      var el = overlay();
                      var big = el.querySelector('img');
                      big.src = img.currentSrc || img.src;
                      big.alt = img.alt || '';
                      el.classList.add('open');
                    });
                  })(imgs[i]);
                }
              }
              document.addEventListener('DOMContentLoaded', wire);
              document.addEventListener('astro:page-load', wire);
            })();
          `,
        },
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
