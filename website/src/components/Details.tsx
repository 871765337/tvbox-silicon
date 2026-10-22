import type { ComponentType } from "react";
import { useI18n } from "../i18n/I18nProvider";
import type { TextKey } from "../i18n/strings";
import { Headline } from "./Headline";
import { DevicesIcon, DownloadIcon, GlobeIcon, LockIcon, PlayIcon, SubscriptionIcon } from "./icons";
import { Reveal } from "./Reveal";

const TILES: { Icon: ComponentType; title: TextKey; body: TextKey }[] = [
  { Icon: SubscriptionIcon, title: "g.sub.t", body: "g.sub.b" },
  { Icon: PlayIcon, title: "g.play.t", body: "g.play.b" },
  { Icon: DownloadIcon, title: "g.dl.t", body: "g.dl.b" },
  { Icon: LockIcon, title: "g.private.t", body: "g.private.b" },
  { Icon: GlobeIcon, title: "g.lang.t", body: "g.lang.b" },
  { Icon: DevicesIcon, title: "g.devices.t", body: "g.devices.b" },
];

export function Details() {
  const { t } = useI18n();
  return (
    <section className="section">
      <Reveal>
        <Headline lines={["more.l1", "more.l2"]} small />
      </Reveal>
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
