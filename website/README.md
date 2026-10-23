# Yingxia website

The website for Yingxia: React 19 + TypeScript, built with Vite and deployed to Cloudflare as a static-assets Worker (`@cloudflare/vite-plugin` + Wrangler). There is no server code.

```sh
npm install
npm run dev        # Vite dev server with hot reload
npm run preview    # production build served by workerd, Cloudflare's runtime
npm run typecheck
npm run deploy     # build, then `wrangler deploy` (run `npx wrangler login` once first)
```

The Worker is named `yingxia-website` in `wrangler.jsonc` and serves https://yingxia.getmegaportal.com. Unknown paths get `public/404.html` with a 404 status (`not_found_handling: 404-page`).

## SEO and prerendering

`npm run build:site` (used by `build`, `preview` and `deploy`) runs `vite build`, then `scripts/prerender.mjs`, which renders the homepage once per language into `dist/` (`/`, `/ja/`, `/ko/`, `/zh-hant/`; paths in `src/site.ts`). Each page gets its own title, description, canonical URL, hreflang links, Open Graph tags and JSON-LD (`SoftwareApplication` and `FAQPage`), and the client hydrates it. The root page is English and switches to a saved or browser language after load, moving the address to that language's page; `?lang=` links still work. The script also writes `sitemap.xml` and `llms.txt` from the same strings and download links, so bumping `MAC_DOWNLOAD`/`DOWNLOADS` or editing the FAQ updates them. `public/robots.txt` points to the sitemap. `vite dev` serves the unrendered app.

## Layout

| Path | Purpose |
| --- | --- |
| `src/i18n/strings.ts` | All copy for English, Japanese, Korean, and Traditional Chinese |
| `src/i18n/I18nProvider.tsx` | Language detection (`?lang=`, saved choice, browser languages) and the `useI18n` hook |
| `src/components/` | Page sections (`Nav`, `Hero`, `Features`, `Details`, `Faq`, `Footer`) and shared pieces (`Headline`, `Stage`, `Reveal`, `controls`) |
| `src/styles.css` | All styles |
| `src/components/Device.tsx`, `mock-*.tsx`, `src/mockups.css` | Device mockups: HTML app screens on Apple's product bezels |
| `public/devices/`, `public/film/` | The bezels (empty screens) and the CC0 photos used as posters |

Fonts (Inter, Instrument Serif) are self-hosted through Fontsource. Japanese, Korean, and Chinese headlines use the system's Mincho, Myungjo, or Song serif.

The source repository (`REPO` in `src/components/controls.tsx`) is linked from the nav, the footer, the install guide, the JSON-LD and `llms.txt`.

## Device mockups

The page shows no real screenshots: the app's UI changes too often for captures to stay current. Every device on the page is an HTML mockup of the app (`src/components/mock-tv.tsx` for Apple TV, `mock-apple.tsx` for Mac, iPad and iPhone) under Apple's product bezels from [Apple Design Resources](https://developer.apple.com/design/resources/).

- `public/devices/{tv,mac,ipad,iphone}.webp` are the bezels with transparent screens, exported by `build/website-shots/frames.sh` (not in git). `Device.tsx` records where each screen sits in its image; the mockup is laid out in points of the real screen (`--pt`), so it scales with the image.
- UI labels follow the app's own strings (`mock-i18n.ts`); titles, sources and categories stay in Chinese, as a TVBox subscription serves them.
- Posters and the live preview are CC0 or public-domain photos in `public/film/`, listed in `public/film/SOURCES.txt`. Titles are made up.
- When the app's UI changes in a way worth showing, edit the mockup markup and styles; there is nothing to recapture.
- `public/og/<language>.jpg`, the social preview images, are the Apple TV mockup rendered by `node scripts/og-images.mjs` against `vite preview --port 4199`. Rerun it after changing that mockup.
