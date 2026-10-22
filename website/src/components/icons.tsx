// Tile icons: SF Symbols at their natural size, centred in a fixed-height row (`.tile-icon`) so the
// tile titles line up whatever the symbol's shape.
import { SFSymbol } from "./SFSymbol";

const tile = (name: string) => () => (
  <span className="tile-icon">
    <SFSymbol name={name} />
  </span>
);

export const SubscriptionIcon = tile("link.badge.plus");
export const PlayIcon = tile("play.rectangle");
export const LockIcon = tile("lock");
export const GlobeIcon = tile("globe");
export const DevicesIcon = tile("laptopcomputer.and.iphone");
export const SearchIcon = tile("magnifyingglass");
export const ListIcon = tile("list.bullet");
export const UpdateIcon = tile("arrow.down.circle");
export const DownloadIcon = UpdateIcon;
