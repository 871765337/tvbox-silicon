import { SF } from "../sf-icons";

/** An SF Symbol (traced from macOS, see sf-icons.ts), sized in em like a glyph of the surrounding text,
 *  so it scales with the font and sits centred on the text line. */
export function SFSymbol({ name, className }: { name: string; className?: string }) {
  const symbol = SF[name];
  if (!symbol) return null;
  const [w, h, transform, d] = symbol;
  return (
    <svg className={className ? `sf ${className}` : "sf"} viewBox={`0 0 ${w} ${h}`} style={{ width: `${w / 800}em`, height: `${h / 800}em` }} aria-hidden="true">
      <path transform={transform} d={d} />
    </svg>
  );
}
