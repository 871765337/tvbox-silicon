// Illustrations for the intro film's mock screens: poster art, a video frame and a vertical drama.
// The film shows no real app screenshots or real titles; every picture on its TV is drawn here.
// <i data-art="name"></i> placeholders in film.html are replaced by artSvg(name).

let uid = 0;

/** A vertical gradient; `id` must be unique in the shadow root, so each call gets a fresh one. */
function grad(stops: string[], x2 = 0, y2 = 1): [string, string] {
  const id = `a${++uid}`;
  const s = stops.map((c, i) => `<stop offset="${i / (stops.length - 1)}" stop-color="${c}"/>`).join("");
  return [`<linearGradient id="${id}" x1="0" y1="0" x2="${x2}" y2="${y2}">${s}</linearGradient>`, `url(#${id})`];
}

function svg(w: number, h: number, defs: string, body: string) {
  return `<svg viewBox="0 0 ${w} ${h}" preserveAspectRatio="xMidYMid slice" aria-hidden="true"><defs>${defs}</defs>${body}</svg>`;
}

/** Deterministic pseudo-random numbers, so every render draws the same stars and windows. */
function rng(seed: number) {
  return () => ((seed = (seed * 16807) % 2147483647) - 1) / 2147483646;
}

const ART: Record<string, () => string> = {
  // Posters, 2:3
  peaks() {
    const [d, sky] = grad(["#ffd59a", "#f4845f", "#7a4160"]);
    return svg(200, 300, d, `<rect width="200" height="300" fill="${sky}"/>
      <circle cx="132" cy="112" r="30" fill="#fff2d4" opacity=".92"/>
      <path d="M0 190 50 118 82 158 122 100 200 182V300H0Z" fill="#a5526a"/>
      <path d="M0 222 44 176 84 206 136 156 200 210V300H0Z" fill="#73385a"/>
      <path d="M0 256Q60 228 112 250T200 244V300H0Z" fill="#3f2242"/>`);
  },
  city() {
    const [d, sky] = grad(["#1c2756", "#5b3a78", "#e07b62"]);
    const r = rng(7);
    let b = "";
    for (let x = -4; x < 200; x += 22) {
      const h = 70 + r() * 110;
      b += `<rect x="${x}" y="${300 - h}" width="20" height="${h}" fill="#171230"/>`;
      for (let y = 300 - h + 8; y < 292; y += 11) for (let wx = x + 4; wx < x + 17; wx += 6) if (r() > 0.55) b += `<rect x="${wx}" y="${y}" width="3" height="4" fill="#ffd27a" opacity="${0.5 + r() * 0.5}"/>`;
    }
    return svg(200, 300, d, `<rect width="200" height="300" fill="${sky}"/><circle cx="150" cy="62" r="16" fill="#fff6e0"/><circle cx="157" cy="57" r="14" fill="#28305f" opacity=".5"/>${b}`);
  },
  sea() {
    const [d1, sky] = grad(["#ffe3a8", "#ff9f7a", "#e46f6f"]);
    const [d2, water] = grad(["#4a6a99", "#1f3558"]);
    let glints = "";
    for (let i = 0; i < 9; i++) glints += `<rect x="${88 - i * 3}" y="${190 + i * 11}" width="${24 + i * 6}" height="2.5" rx="1" fill="#ffd9a0" opacity="${0.75 - i * 0.07}"/>`;
    return svg(200, 300, d1 + d2, `<rect width="200" height="190" fill="${sky}"/><circle cx="100" cy="186" r="34" fill="#fff0c9"/>
      <rect y="184" width="200" height="116" fill="${water}"/>${glints}
      <path d="M148 176h22l-4 7h-15z" fill="#2a2340"/><path d="M158 175V140l-13 33z" fill="#2a2340"/><path d="M160 175V146l9 27z" fill="#2a2340" opacity=".8"/>`);
  },
  forest() {
    const [d, sky] = grad(["#0d2a36", "#1f5a64", "#3f8a7e"]);
    const pine = (x: number, y: number, s: number, c: string) =>
      `<path d="M${x} ${y - 60 * s}l${18 * s} ${26 * s}h${-8 * s}l${14 * s} ${20 * s}h${-9 * s}l${13 * s} ${18 * s}h${-56 * s}l${13 * s} ${-18 * s}h${-9 * s}l${14 * s} ${-20 * s}h${-8 * s}z" fill="${c}"/>`;
    const r = rng(3);
    let flies = "";
    for (let i = 0; i < 14; i++) flies += `<circle cx="${r() * 200}" cy="${150 + r() * 120}" r="${1 + r() * 1.4}" fill="#ffe58a" opacity="${0.5 + r() * 0.5}"/>`;
    return svg(200, 300, d, `<rect width="200" height="300" fill="${sky}"/><circle cx="60" cy="70" r="20" fill="#f3f0d2"/>
      ${pine(30, 230, 1.3, "#173f48")}${pine(150, 225, 1.5, "#173f48")}${pine(95, 250, 1.1, "#173f48")}
      ${pine(10, 290, 1.6, "#0a2128")}${pine(120, 300, 1.9, "#0a2128")}${pine(190, 290, 1.4, "#0a2128")}
      <rect y="280" width="200" height="20" fill="#0a2128"/>${flies}`);
  },
  dunes() {
    const [d, sky] = grad(["#ffeec4", "#f8bd78"]);
    return svg(200, 300, d, `<rect width="200" height="300" fill="${sky}"/><circle cx="58" cy="96" r="24" fill="#fff8e6"/>
      <path d="M0 200Q70 150 140 196T200 186V300H0Z" fill="#eb9b5c"/>
      <path d="M0 236Q90 198 200 238V300H0Z" fill="#cf7442"/>
      <path d="M0 270Q110 240 200 262V300H0Z" fill="#a4552f"/>
      <g fill="#4a2a1c"><circle cx="121" cy="176" r="3"/><path d="M118 180h6l2 14h-3l-1 10h-2l-1-10h-3z"/><path d="M126 182l7 22" stroke="#4a2a1c" stroke-width="1.4"/></g>`);
  },
  space() {
    const [d1, sky] = grad(["#110b2a", "#3a1b5c"]);
    const [d2, planet] = grad(["#ffc27a", "#e76f51", "#9b3c55"], 1, 1);
    const r = rng(11);
    let stars = "";
    for (let i = 0; i < 40; i++) stars += `<circle cx="${r() * 200}" cy="${r() * 300}" r="${0.4 + r() * 1.2}" fill="#fff" opacity="${0.4 + r() * 0.6}"/>`;
    return svg(200, 300, d1 + d2, `<rect width="200" height="300" fill="${sky}"/>${stars}
      <ellipse cx="100" cy="150" rx="78" ry="18" fill="none" stroke="#ffd9a8" stroke-width="5" opacity=".5" transform="rotate(-16 100 150)"/>
      <circle cx="100" cy="150" r="46" fill="${planet}"/>
      <path d="M24 172a78 18 -16 0 0 152-44" fill="none" stroke="#ffe2b8" stroke-width="5" opacity=".9"/>
      <circle cx="160" cy="240" r="9" fill="#a9b8ff" opacity=".8"/>`);
  },
  bowl() {
    const [d, bg] = grad(["#f9dcb2", "#efb67f"]);
    return svg(200, 300, d, `<rect width="200" height="300" fill="${bg}"/><rect y="205" width="200" height="95" fill="#b9683e"/>
      <g fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round" opacity=".75"><path d="M78 128c-10-14 10-22 0-38"/><path d="M100 122c-10-14 10-22 0-40"/><path d="M122 128c-10-14 10-22 0-38"/></g>
      <ellipse cx="100" cy="160" rx="62" ry="14" fill="#f3c15a"/>
      <g stroke="#ffe08a" stroke-width="3" fill="none"><path d="M58 160q20-8 40 0t40 0"/><path d="M66 164q18-6 34 0t32 0"/></g>
      <circle cx="80" cy="156" r="7" fill="#5d8b3e"/><circle cx="118" cy="154" r="8" fill="#fff6e8"/><circle cx="118" cy="154" r="4" fill="#f2a93b"/>
      <path d="M38 160h124q-6 56-62 56t-62-56z" fill="#fffaf2"/><path d="M44 176h112" stroke="#d9453b" stroke-width="5"/>
      <path d="M130 96l46 106M140 94l44 104" stroke="#6b3a22" stroke-width="4" stroke-linecap="round"/>`);
  },
  blossom() {
    const [d, sky] = grad(["#ffe7ec", "#ffb8c8"]);
    const r = rng(5);
    let petals = "";
    const at = [[60, 92], [84, 80], [104, 110], [128, 96], [150, 124], [40, 126], [170, 150], [116, 140], [76, 118]];
    for (const [x, y] of at) petals += `<circle cx="${x}" cy="${y}" r="${8 + r() * 6}" fill="${r() > 0.5 ? "#ff8fab" : "#fff0f4"}"/>`;
    return svg(200, 300, d, `<rect width="200" height="300" fill="${sky}"/><circle cx="128" cy="200" r="46" fill="#e84a5f"/>
      <path d="M0 70q60 20 100 50t100 46" stroke="#5a3428" stroke-width="7" fill="none" stroke-linecap="round"/><path d="M70 92q10 20 34 18M130 132q-4 20 16 32" stroke="#5a3428" stroke-width="4" fill="none"/>
      ${petals}<path d="M0 300V262q50-20 100-6t100-4V300z" fill="#d76b86" opacity=".6"/>`);
  },

  // A 16:9 video frame: a high-altitude lake under snow peaks, prayer flags on the shore.
  lake() {
    const [d1, sky] = grad(["#4f86d2", "#9fc6ee", "#e6f1fb"]);
    const [d2, water] = grad(["#3d82c4", "#1d4f8a", "#163f73"]);
    const flags = ["#2f6fd6", "#f4f4f4", "#d9453b", "#3c9a4d", "#f2c230"];
    let f = "";
    for (let i = 0; i < 12; i++) {
      const t = (i + 0.5) / 12, x = 1160 + t * 400, y = 480 - 40 * t + 60 * Math.sin(Math.PI * t);
      f += `<path d="M${x - 13} ${y}l26 3-11 34z" fill="${flags[i % 5]}"/>`;
    }
    return svg(1600, 900, d1 + d2, `<rect width="1600" height="900" fill="${sky}"/>
      <g fill="#fff" opacity=".8"><ellipse cx="360" cy="150" rx="170" ry="34"/><ellipse cx="470" cy="128" rx="110" ry="30"/><ellipse cx="1180" cy="190" rx="200" ry="30"/><ellipse cx="1290" cy="168" rx="110" ry="28"/></g>
      <path d="M0 470 180 380 330 430 520 300 700 420 860 340 1040 410 1240 290 1420 390 1600 330V500H0Z" fill="#b9c9e0"/>
      <path d="M380 500 640 260 760 360 900 230 1120 430 1260 500Z" fill="#6d7d95"/>
      <path d="M640 260 590 306 640 296 668 320 700 300 760 360 740 300ZM900 230 850 286 900 270 930 300 960 280 1010 320 960 270Z" fill="#fff"/>
      <rect y="496" width="1600" height="404" fill="${water}"/>
      <path d="M380 498 640 690 760 610 900 720 1120 560 1260 498Z" fill="#8ea6c6" opacity=".22"/>
      <g fill="#fff" opacity=".25"><rect x="300" y="560" width="260" height="3" rx="1.5"/><rect x="900" y="600" width="340" height="3" rx="1.5"/><rect x="520" y="650" width="200" height="3" rx="1.5"/></g>
      <path d="M0 700Q400 640 800 720T1600 690V900H0Z" fill="#c9b48a"/><path d="M0 760Q500 720 900 790T1600 770V900H0Z" fill="#8f9c5a"/>
      <path d="M1160 470V800M1560 430V790" stroke="#5a4632" stroke-width="8"/>
      <path d="M1160 480Q1360 580 1560 440" stroke="#5a4632" stroke-width="2" fill="none"/>${f}`);
  },

  // A 9:16 short-drama frame: dusk on an old street, lanterns lit, a figure under an umbrella.
  drama() {
    const [d1, sky] = grad(["#1b1a33", "#5b3352", "#d98a5c"]);
    const [d2, street] = grad(["#3a2434", "#1a1220"]);
    const lantern = (x: number, y: number, s: number) =>
      `<circle cx="${x}" cy="${y}" r="${70 * s}" fill="#ffb35c" opacity=".18"/><path d="M${x} ${y - 70 * s}v${-30 * s}" stroke="#2a1a20" stroke-width="${4 * s}"/><ellipse cx="${x}" cy="${y}" rx="${30 * s}" ry="${38 * s}" fill="#e5483a"/><rect x="${x - 14 * s}" y="${y - 42 * s}" width="${28 * s}" height="${8 * s}" fill="#3a1f1c"/><rect x="${x - 14 * s}" y="${y + 34 * s}" width="${28 * s}" height="${8 * s}" fill="#3a1f1c"/>`;
    const r = rng(9);
    let petals = "";
    for (let i = 0; i < 18; i++) petals += `<ellipse cx="${r() * 900}" cy="${r() * 1300}" rx="7" ry="4" fill="#ffc2d1" opacity="${0.5 + r() * 0.4}" transform="rotate(${r() * 180})"/>`;
    return svg(900, 1600, d1 + d2, `<rect width="900" height="1600" fill="${sky}"/>
      <path d="M-20 520h300l-40-50H20zM0 520h240v600H0z" fill="#24162a"/><path d="M920 460H600l40-56h240zM900 460H660v660h240z" fill="#24162a"/>
      <path d="M260 760h380l-50-44H310zM300 760h300v360H300z" fill="#2e1c33"/>
      ${lantern(150, 640, 1)}${lantern(760, 580, 1.1)}${lantern(450, 840, 0.7)}
      <path d="M0 1120h900v480H0z" fill="${street}"/>
      <path d="M300 1036q150-120 300 0z" fill="#c84a5a"/><path d="M450 920v20M450 1036v130" stroke="#2a1a20" stroke-width="6"/>
      <g fill="#120c18"><circle cx="450" cy="1068" r="34"/><path d="M410 1100h80l40 330h-160z"/><path d="M372 1430h156v18H372z"/></g>
      <ellipse cx="450" cy="1462" rx="110" ry="14" fill="#000" opacity=".35"/>${petals}`);
  },
};

export function artSvg(name: string): string {
  return ART[name]?.() ?? "";
}
