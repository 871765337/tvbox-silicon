// Apple TV screens for the device mockups (see Device.tsx), laid out like the tvOS app.
import { SFSymbol } from "./SFSymbol";
import { useMockText } from "./mock-i18n";
import { CategoryChips, Poster, titles } from "./mock-parts";

/** The tab's chip in the top-left corner, as tvOS shows it inside a section. */
function Chapter({ icon, label }: { icon: string; label: string }) {
  return (
    <span className="tv-chap">
      <SFSymbol name="chevron.left" className="dim" />
      <SFSymbol name={icon} />
      {label}
    </span>
  );
}

export function TvHome() {
  const m = useMockText();
  return (
    <div className="tv">
      <Chapter icon="play.rectangle" label={m("Watch Now")} />
      <div className="tv-row">
        <span className="m-pick">
          <SFSymbol name="chevron.down" />
          👀 瓜子 · 不卡
        </span>
        <span className="m-round end">
          <SFSymbol name="arrow.clockwise" />
        </span>
      </div>
      <CategoryChips />
      <div className="tv-shelf">
        {titles(0, 5).map((t, i) => (
          <Poster key={t.img} title={t} focus={i === 0} />
        ))}
      </div>
      <div className="tv-shelf">
        {titles(5, 5).map((t) => (
          <Poster key={t.img} title={t} />
        ))}
      </div>
    </div>
  );
}

const CHANNELS = [
  ["1", "CCTV-1 综合", "央视频道"],
  ["2", "CCTV-2 财经", "央视频道"],
  ["湘", "湖南卫视", "卫视频道"],
  ["沪", "东方卫视", "卫视频道"],
  ["浙", "浙江卫视", "卫视频道"],
];

export function TvLive() {
  const m = useMockText();
  return (
    <div className="tv">
      <Chapter icon="antenna.radiowaves.left.and.right" label={m("Live TV")} />
      <div className="tv-row">
        <b className="tv-group">综合直播</b>
        <span className="m-btn focus end">
          <SFSymbol name="magnifyingglass" />
          {m("Search channels")}
        </span>
        <span className="m-round">
          <SFSymbol name="arrow.clockwise" />
        </span>
      </div>
      <div className="live-hero">
        <div>
          <p className="live-kicker">
            <SFSymbol name="antenna.radiowaves.left.and.right" /> {m("Live TV")}
          </p>
          <p className="live-name">CCTV-1 综合</p>
          <p className="dim">央视频道</p>
        </div>
        <div className="live-preview">
          <img src="/film/lake.webp" alt="" loading="lazy" decoding="async" />
          <span className="m-chip acc">LIVE</span>
        </div>
      </div>
      <div className="m-chips">
        <span className="m-chip acc">{m("All")}</span>
        {["央视频道", "卫视频道", "纪录", "少儿", "轮播"].map((g) => (
          <span key={g} className="m-chip">
            {g}
          </span>
        ))}
      </div>
      <div className="tv-row tv-caption">
        <span>{m("Channels: 188")}</span>
        <span className="end">{m("Live TV")}</span>
      </div>
      <div className="live-list">
        {CHANNELS.map(([logo, name, group], i) => (
          <div key={name} className={i === 0 ? "live-row on" : "live-row"}>
            <span className="live-logo">{logo}</span>
            <b>{name}</b>
            <span className="dim end">{group}</span>
            <SFSymbol name="play.fill" />
          </div>
        ))}
      </div>
    </div>
  );
}

const RESULTS = ["🌟 立播 · 12", "👀 瓜子 · 100", "🍓 糯米 · 20", "🌞 光影 · 41", "🍄 比特 · 7", "🧀 奶酪 · 9"];

export function TvSearch() {
  const m = useMockText();
  return (
    <div className="tv">
      <Chapter icon="magnifyingglass" label={m("Global Search")} />
      <div className="srch-line">
        <SFSymbol name="magnifyingglass" />
        <span>旅行</span>
        <i className="m-caret" />
      </div>
      <div className="kbd">
        <span className="key">123</span>
        <span className="key">{m("SPACE")}</span>
        {"abcdefghijklmnopqrstuvwxyz".split("").map((c) => (
          <span key={c} className={c === "a" ? "letter on" : "letter"}>
            {c}
          </span>
        ))}
      </div>
      <div className="m-chips">
        <span className="m-chip">
          <SFSymbol name="magnifyingglass" /> “旅行”
        </span>
        <span className="m-chip">旅行日记</span>
        <span className="m-chip">旅行纪录片</span>
      </div>
      <hr className="tv-rule" />
      <div className="tv-row srch-status">
        <i className="m-spin" />
        <b>{m("325 results")}</b>
        <span className="dim">{m("Searched 20 of 31 sources")}</span>
        <span className="m-btn end">{m("Stop")}</span>
      </div>
      <div className="m-bar">
        <i />
      </div>
      <div className="m-chips">
        <span className="m-chip acc">
          <SFSymbol name="checkmark" />
          {m("All Sources")}
        </span>
        {RESULTS.map((r) => (
          <span key={r} className="m-chip">
            {r}
          </span>
        ))}
      </div>
      <div className="tv-shelf six">
        {titles(17, 6).map((t) => (
          <Poster key={t.img} title={t} />
        ))}
      </div>
    </div>
  );
}

export function TvSite() {
  const m = useMockText();
  return (
    <div className="tv">
      <Chapter icon="square.grid.2x2" label={m("Sources")} />
      <p className="site-title">🌞 光影 · 不卡</p>
      <div className="m-field">
        <SFSymbol name="magnifyingglass" />
        {m("Search videos")}
      </div>
      <CategoryChips selected={0} />
      <div className="tv-shelf">
        {titles(9, 5).map((t, i) => (
          <Poster key={t.img} title={t} focus={i === 1} />
        ))}
      </div>
      <div className="m-pager">
        <span className="m-round">
          <SFSymbol name="chevron.left" />
        </span>
        {m("Page 1 of 50")}
        <span className="m-round">
          <SFSymbol name="chevron.right" />
        </span>
      </div>
    </div>
  );
}
