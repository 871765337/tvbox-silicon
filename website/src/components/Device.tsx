import type { ReactNode } from "react";

// Apple's product bezels (developer.apple.com/design/resources) with their screens left empty, exported by
// build/website-shots/frames.sh to public/devices/<kind>.webp. The screen is an HTML mockup laid out under
// the bezel, so it never goes stale when the app's UI changes. `screen` is the opening in percent of the image:
// left, top, width, height.
export type DeviceKind = "tv" | "mac" | "ipad" | "iphone";

const FRAMES: Record<DeviceKind, { w: number; h: number; screen: [number, number, number, number] }> = {
  // TV with the Apple TV 4K box and Siri Remote; screen 3840x2160 of 4166x2588.
  tv: { w: 1600, h: 994, screen: [0.648, 1.236, 92.175, 83.462] },
  // MacBook Pro 14-inch; screen 3024x1964 of 3805x2297, notch drawn by the bezel.
  mac: { w: 1600, h: 966, screen: [10.276, 2.438, 79.474, 85.503] },
  // iPad Pro 11-inch, portrait; screen 1668x2420 of 1854x2606.
  ipad: { w: 1000, h: 1406, screen: [4.908, 3.645, 89.968, 92.863] },
  // iPhone 17 Pro, portrait; screen 1206x2622 of 1318x2717, Dynamic Island drawn by the bezel.
  iphone: { w: 560, h: 1154, screen: [4.249, 1.767, 91.502, 96.503] },
};

interface Props {
  kind: DeviceKind;
  /** What the screen shows, for screen readers. */
  label?: string;
  className?: string;
  children: ReactNode;
}

/** A device bezel with an HTML mockup on its screen. Everything inside scales with the screen width (cqw). */
export function Device({ kind, label, className, children }: Props) {
  const { w, h, screen } = FRAMES[kind];
  const [left, top, width, height] = screen;
  return (
    <div className={`device device-${kind}${className ? ` ${className}` : ""}`} role={label ? "img" : undefined} aria-label={label} aria-hidden={label ? undefined : true}>
      <div className={`screen screen-${kind}`} style={{ left: `${left}%`, top: `${top}%`, width: `${width}%`, height: `${height}%` }}>
        {children}
      </div>
      <img className="device-frame" src={`/devices/${kind}.webp`} alt="" width={w} height={h} loading="lazy" />
    </div>
  );
}
