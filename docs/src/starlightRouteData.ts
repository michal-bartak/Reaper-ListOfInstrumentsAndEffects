import { defineRouteMiddleware } from '@astrojs/starlight/route-data';

// Label the table-of-contents' top entry with the page title instead of Starlight's generic
// "Overview" UI string. Starlight prepends this entry itself (slug `_top` -> the page `<h1>`);
// without it there is no way back to the top and the intro text above the first `##` is
// unreachable from the ToC. NOTE: `src/middleware.ts` is Astro's own middleware path and is
// rejected here -- hence this filename, which `routeMiddleware` in astro.config.mjs points at.
export const onRequest = defineRouteMiddleware(({ locals }) => {
  const { toc, entry } = locals.starlightRoute;
  const top = toc?.items[0];
  if (top?.slug === '_top') top.text = entry.data.title;
});
