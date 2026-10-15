import { cloudflare } from "@cloudflare/vite-plugin";
import react from "@vitejs/plugin-react";
import { resolve } from "node:path";
import { defineConfig, type Plugin } from "vite";

// Cloudflare Web Analytics site token (dashboard → Analytics & Logs → Web Analytics → yingxia.getmegaportal.com).
// It is public: it ends up in every page. Empty means no beacon.
const WEB_ANALYTICS_TOKEN = "";

// Adds Cloudflare's cookieless beacon to the built pages (the homepage template, which the prerender
// copies per language, and /intro/); `vite dev` and local previews of a build without a token stay clean.
function webAnalytics(token: string): Plugin {
  return {
    name: "cloudflare-web-analytics",
    apply: "build",
    transformIndexHtml: () =>
      token
        ? [
            {
              tag: "script",
              attrs: {
                defer: true,
                src: "https://static.cloudflareinsights.com/beacon.min.js",
                "data-cf-beacon": JSON.stringify({ token, spa: true }),
              },
              injectTo: "body",
            },
          ]
        : [],
  };
}

export default defineConfig({
  plugins: [react(), cloudflare(), webAnalytics(WEB_ANALYTICS_TOKEN)],
  build: {
    rollupOptions: {
      // The intro film is also its own page at /intro/.
      input: {
        main: resolve(import.meta.dirname, "index.html"),
        intro: resolve(import.meta.dirname, "intro/index.html"),
      },
    },
  },
});
