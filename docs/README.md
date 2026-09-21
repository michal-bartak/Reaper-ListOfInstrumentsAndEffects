# List of Instruments and Effects — docs

The user documentation, built with [Astro](https://astro.build/) +
[Starlight](https://starlight.astro.build/) and published to GitHub Pages at
<https://michal-bartak.github.io/ListOfInstrumentsAndEffects/>.

```bash
npm install
npm run dev      # http://localhost:4321/ListOfInstrumentsAndEffects/
npm run build    # static site into dist/
```

## Layout

```
astro.config.mjs       site config, the sidebar, and the lightbox script
src/content/docs/      the pages, as Markdown
src/styles/custom.css  accent colour, figures, the lightbox, the theme picker
public/                favicons, rendered by `make icon` in the repo root
```

The theme is [starlight-theme-rapide](https://github.com/HiDeoo/starlight-theme-rapide),
the same one the AutoColor docs use, with Starlight's own Dark/Light/Auto picker
put back in place of rapide's two-state button. That override logs one build
warning; it is expected.

The logo is `../icon/icon.svg`, outside this project: it belongs to the script,
not to the site. Astro bundles it from there.
