// Standalone film pages (/intro/ and /whats-new/): the film, a back link, and ?t= / ?lang= support.
import "@fontsource/inter/400.css";
import "@fontsource/inter/500.css";
import "@fontsource/inter/600.css";
import "@fontsource/inter/700.css";
import "./page.css";
import { detectLang } from "../i18n/detect";
import { type FilmName, mountFilm } from "./film";
import { tr } from "./film-i18n";

const lang = detectLang();
const brand = lang === "ja" || lang === "zh-Hant" ? "映匣" : "Yingxia";
document.documentElement.lang = lang;
const host = document.getElementById("film-host")!;
const film = (host.dataset.film ?? "intro") as FilmName;
const [title, label] = film === "whats-new" ? ["What’s new in Yingxia 1.1", "What’s new"] : ["How Yingxia works", "How it works"];
document.title = tr(lang, title).replace("Yingxia", brand);
document.querySelector("#back")!.textContent = `← ${brand}`;
document.querySelector("#how")!.textContent = tr(lang, label);

const at = new URLSearchParams(location.search).get("t");
mountFilm(host, {
  lang,
  film,
  keys: true,
  startAt: at === null ? undefined : Number(at) || 0,
});
