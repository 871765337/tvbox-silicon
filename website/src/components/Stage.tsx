import type { ReactNode } from "react";
import { Device } from "./Device";

/** An Apple TV screen mockup (mock-tv.tsx) on Apple's Apple TV bezel (TV, Apple TV 4K and Siri Remote). */
export function Stage({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="stage">
      <Device kind="tv" label={label}>
        {children}
      </Device>
    </div>
  );
}
