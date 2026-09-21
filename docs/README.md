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
astro.config.mjs       site config and the sidebar
src/content/docs/      the pages, as Markdown
public/                favicons, rendered by `npm run icon` in the repo root
```

The logo is `../icon/icon.svg`, outside this project: it belongs to the script,
not to the site. Astro bundles it from there.
