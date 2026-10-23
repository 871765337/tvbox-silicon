// Shared pieces of the device mockups: made-up titles on CC0 / public-domain photos (public/film/SOURCES.txt),
// sources and categories the way a Chinese TVBox subscription names them, and the poster tile.
import { SFSymbol } from "./SFSymbol";
import { useMockText } from "./mock-i18n";

export interface Title {
  img: string;
  name: string;
  /** The source's remark: year, episode count or quality. */
  note: string;
}

export const TITLES: Title[] = [
  { img: "peaks", name: "山海之间", note: "2026" },
  { img: "neon", name: "霓虹小巷", note: "更新至12集" },
  { img: "aurora", name: "極光之夜", note: "4K" },
  { img: "bowl", name: "一碗人间烟火", note: "更新至8集" },
  { img: "lighthouse", name: "灯塔守望者", note: "2026" },
  { img: "blossom", name: "樱花季", note: "全24集" },
  { img: "balloon", name: "热气球飞行家", note: "2025" },
  { img: "cat", name: "猫的午后", note: "全10集" },
  { img: "city", name: "夜色城市", note: "更新至6集" },
  { img: "falls", name: "森林瀑布", note: "4K" },
  { img: "wheel", name: "摩天轮之约", note: "全16集" },
  { img: "dunes", name: "沙丘旅人", note: "2024" },
  { img: "lanterns", name: "灯笼小巷", note: "更新至3集" },
  { img: "kayak", name: "冰川湖", note: "2025" },
  { img: "space", name: "星河漫游", note: "4K" },
  { img: "drama", name: "雨中漫步", note: "更新至20集" },
  { img: "train", name: "高山列车", note: "2023" },
  { img: "sea", name: "海边的夏天", note: "2026" },
  { img: "tower", name: "东京塔下", note: "全12集" },
  { img: "forest", name: "林间小屋", note: "2024" },
  { img: "balloons2", name: "千塔之城", note: "更新至5集" },
];

/** `count` titles starting at `from`, wrapping around. */
export const titles = (from: number, count: number) => Array.from({ length: count }, (_, i) => TITLES[(from + i) % TITLES.length]);

export const SOURCES = ["🚀 荐影 · 预告片", "🌞 光影 · 不卡", "🌟 立播 · 不卡", "👀 瓜子 · 不卡", "🍄 比特 · 不卡", "🍓 糯米 · 秒播", "🧀 奶酪 · 秒播"];

export const CATEGORIES = ["电影", "剧集", "动漫", "纪录片", "综艺", "短剧", "少儿"];

export function Poster({ title, focus = false }: { title: Title; focus?: boolean }) {
  return (
    <div className={focus ? "pst focus" : "pst"}>
      <div className="pst-art">
        <img src={`/film/${title.img}.webp`} alt="" loading="lazy" decoding="async" />
        <span className="pst-note">{title.note}</span>
      </div>
      <span className="pst-name">{title.name}</span>
    </div>
  );
}

/** The source picker chips, one selected, and the category chips under them. */
export function SourceChips({ selected = 3 }: { selected?: number }) {
  return (
    <div className="m-chips scroll">
      {SOURCES.map((s, i) => (
        <span key={s} className={i === selected ? "m-chip acc" : "m-chip"}>
          {s}
        </span>
      ))}
    </div>
  );
}

export function CategoryChips({ selected = -1 }: { selected?: number }) {
  const m = useMockText();
  return (
    <div className="m-chips scroll">
      <span className={selected < 0 ? "m-chip acc" : "m-chip"}>
        {selected < 0 && <SFSymbol name="checkmark" />}
        {m("Recommendations")}
      </span>
      {CATEGORIES.map((c, i) => (
        <span key={c} className={i === selected ? "m-chip acc" : "m-chip"}>
          {i === selected && <SFSymbol name="checkmark" />}
          {c}
        </span>
      ))}
    </div>
  );
}
