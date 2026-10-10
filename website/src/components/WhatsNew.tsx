import { type ComponentType, useEffect, useRef } from "react";
import { useI18n } from "../i18n/I18nProvider";
import type { TextKey } from "../i18n/strings";
import { mountFilm } from "../intro/film";
import { Headline } from "./Headline";
import { CastIcon, ListIcon, QrIcon, QualityIcon, SearchIcon, UpdateIcon } from "./icons";
import { Reveal } from "./Reveal";
import { Stage } from "./Stage";

const CARDS: { shot: string; title: TextKey; body: TextKey }[] = [
  { shot: "bili", title: "n.bili.t", body: "n.bili.b" },
  { shot: "bili-danmaku", title: "n.dm.t", body: "n.dm.b" },
  { shot: "bili-live", title: "n.live.t", body: "n.live.b" },
];

const TILES: { Icon: ComponentType; title: TextKey; body: TextKey }[] = [
  { Icon: CastIcon, title: "n.cast.t", body: "n.cast.b" },
  { Icon: QualityIcon, title: "n.hd.t", body: "n.hd.b" },
  { Icon: QrIcon, title: "n.qr.t", body: "n.qr.b" },
  { Icon: SearchIcon, title: "n.search.t", body: "n.search.b" },
  { Icon: ListIcon, title: "n.list.t", body: "n.list.b" },
  { Icon: UpdateIcon, title: "n.update.t", body: "n.update.b" },
];

/** The “What’s new in 1.1” film. */
function NewFilm() {
  const { lang } = useI18n();
  const host = useRef<HTMLDivElement>(null);
  useEffect(() => (host.current ? mountFilm(host.current, { lang, film: "whats-new" }) : undefined), [lang]);
  return <div ref={host} className="hero-film-host" />;
}

export function WhatsNew() {
  const { t, lang } = useI18n();
  return (
    <section className="section" id="new">
      <Reveal>
        <Headline lines={["new.l1", "new.l2"]} small />
      </Reveal>
      <Reveal as="p" className="lead">
        {t("new.sub")}
      </Reveal>
      <Reveal className="hero-film new-film">
        <NewFilm />
        <a className="link hero-film-link" href={`/whats-new/?lang=${lang}`}>
          {t("new.film")} <span aria-hidden="true">→</span>
        </a>
      </Reveal>

      {CARDS.map(({ shot, title, body }) => (
        <Reveal as="article" className="card" key={shot}>
          <h3>{t(title)}</h3>
          <p>{t(body)}</p>
          <Stage shot={shot} alt={t(title)} />
        </Reveal>
      ))}
      <div className="grid">
        {TILES.map(({ Icon, title, body }) => (
          <Reveal className="tile" key={title}>
            <Icon />
            <h3>{t(title)}</h3>
            <p>{t(body)}</p>
          </Reveal>
        ))}
      </div>
    </section>
  );
}
