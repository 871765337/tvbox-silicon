import { SFSymbol } from "./SFSymbol";
import { useEffect, useState, type ComponentType } from "react";
import { useI18n } from "../i18n/I18nProvider";
import { INSTALL, type InstallCopy, type Platform, type Sideload } from "../i18n/install-strings";
import { CIDER, DOWNLOADS, ILOADER, IMPACTOR, INSTALL_GUIDE, INSTALL_SKILL, SIDELOADLY } from "./controls";
import { AppleTVIcon, IPhoneIPadIcon, MacIcon } from "./icons-devices";
import { Reveal } from "./Reveal";

/** Pixel heights of the 1600px-wide mockup images, so the page reserves their space. */
const MOCKUP_HEIGHT: Record<Platform, number> = { mac: 966, ios: 1886, tv: 994 };

const PLATFORMS: { id: Platform; Icon: ComponentType }[] = [
  { id: "mac", Icon: MacIcon },
  { id: "ios", Icon: IPhoneIPadIcon },
  { id: "tv", Icon: AppleTVIcon },
];

// Links like /#install-tv open a specific tab.
function hashPlatform(): Platform | null {
  const match = /^#install-(mac|ios|tv)$/.exec(location.hash);
  return match ? (match[1] as Platform) : null;
}

// iPadOS reports itself as a Mac, so only phones and older iPads land on the iOS tab.
function initialPlatform(): Platform {
  return hashPlatform() ?? (/iPhone|iPad|iPod/.test(navigator.userAgent) ? "ios" : "mac");
}

export function Install() {
  const { lang, locale } = useI18n();
  const copy = INSTALL[lang];
  // Starts on the Mac tab, as prerendered, then picks the visitor's tab after hydration.
  const [platform, setPlatform] = useState<Platform>("mac");
  const sideload = platform !== "mac";

  useEffect(() => {
    setPlatform(initialPlatform());
    const onHash = () => {
      const next = hashPlatform();
      if (next) setPlatform(next);
    };
    addEventListener("hashchange", onHash);
    return () => removeEventListener("hashchange", onHash);
  }, []);

  return (
    <section className="section install" id="install">
      <Reveal>
        <h2 className="headline small">
          <span className="sans">{copy.l1}</span>
          <span className="serif">{copy.l2}</span>
        </h2>
      </Reveal>
      <Reveal as="p" className="lead">
        {copy.sub}
      </Reveal>

      <Reveal>
        <div className="tabnav" role="tablist" aria-label={copy.nav}>
          {PLATFORMS.map(({ id, Icon }) => (
            <button
              key={id}
              type="button"
              role="tab"
              id={`install-${id}`}
              aria-selected={platform === id}
              aria-controls="install-panel"
              className={platform === id ? "tab on" : "tab"}
              onClick={() => setPlatform(id)}
            >
              <span className="tab-icon">
                <Icon />
              </span>
              <span>{copy.device[id]}</span>
            </button>
          ))}
        </div>
      </Reveal>

      <div className="install-panel" id="install-panel" role="tabpanel" aria-labelledby={`install-${platform}`}>
        <div className="showcase" key={platform}>
          <div className={`showcase-art art-${platform}`}>
            {/* Real app screenshots composited into Apple's product bezels (developer.apple.com/design/resources). */}
            <img src={`/devices/${platform}-${locale.shots}.webp`} alt={copy.title[platform]} width={1600} height={MOCKUP_HEIGHT[platform]} />
          </div>
          <p className={sideload ? "eyebrow" : "eyebrow signed"}>{copy.tag[platform]}</p>
          <h3 className="product">{copy.title[platform]}</h3>
          <p className="product-req">{copy.req[platform]}</p>
          <div className="product-actions">
            <a className="btn-blue" href={DOWNLOADS[platform]}>
              {copy.get}
            </a>
            {sideload && (
              <a className="link-blue" href={CIDER} target="_blank" rel="noreferrer">
                {copy.cider} <SFSymbol name="chevron.right" />
              </a>
            )}
          </div>
        </div>

        <div className="how">
          <h3 className="how-title">{copy.how}</h3>
          <ol className={`steps n${copy.steps[platform].length}`} key={platform}>
            {copy.steps[platform].map((step, i) => (
              <li className="step" key={i}>
                <span className="step-n">{i + 1}</span>
                <h4>{step.t}</h4>
                <p>{step.b}</p>
              </li>
            ))}
          </ol>
        </div>

        {sideload && <RunCards copy={copy} platform={platform} />}

        {sideload && (
          <div className="keep">
            <h3 className="how-title">{copy.keep.t}</h3>
            <div className="keep-stats">
              <div className="stat">
                <span className="stat-value">{copy.keep.freeTime}</span>
                <span className="stat-label">{copy.keep.free}</span>
              </div>
              <div className="stat">
                <span className="stat-value">{copy.keep.paidTime}</span>
                <span className="stat-label">{copy.keep.paid}</span>
              </div>
            </div>
            <p className="keep-body">
              {copy.keep.b} {copy.keep.tip}
            </p>
            <a className="link-blue" href={INSTALL_GUIDE} target="_blank" rel="noreferrer">
              {copy.guide} <SFSymbol name="chevron.right" />
            </a>
          </div>
        )}
      </div>
    </section>
  );
}

/** The cider commands for a platform, with each comment above its command. */
function commands(copy: InstallCopy, platform: Sideload) {
  const ipa = DOWNLOADS[platform].split("/").pop();
  return [
    [copy.cli.install, "brew tap Muonagi/cider-cli https://github.com/Muonagi/cider-cli", "brew install cider"],
    [copy.cli.login, "cider account login"],
    [copy.cli.pair, "cider device trust"],
    [copy.cli.sign, `cider sign ${ipa} --apple-id --install --refresh`],
  ];
}

/** "Run it yourself" (the cider commands) beside "Let your AI agent do it" (a prompt that points at the install skill). */
function RunCards({ copy, platform }: { copy: InstallCopy; platform: Sideload }) {
  const blocks = commands(copy, platform);
  const script = blocks.map(([comment, ...lines]) => [`# ${comment}`, ...lines].join("\n")).join("\n");
  const prompt = copy.agent.prompt[platform].replace("{skill}", INSTALL_SKILL).replace("{ipa}", DOWNLOADS[platform]);
  return (
    <>
      <div className="run">
        <div className="run-card">
          <span className="run-icon"><SFSymbol name="terminal" /></span>
          <h3>{copy.cli.t}</h3>
          <p>{copy.cli.b}</p>
          <pre className="code">
            {blocks.map(([comment, ...lines]) => (
              <span key={comment}>
                <span className="cm"># {comment}</span>
                {"\n" + lines.join("\n") + "\n"}
              </span>
            ))}
          </pre>
          <CopyButton text={script} copy={copy} />
        </div>
        <div className="run-card">
          <span className="run-icon"><SFSymbol name="sparkles" /></span>
          <h3>{copy.agent.t}</h3>
          <p>{copy.agent.b}</p>
          <p className="code prompt">{prompt}</p>
          <CopyButton text={prompt} copy={copy} />
        </div>
      </div>
      <p className="alt">
        {copy.alt.t}{" "}
        <a href={IMPACTOR} target="_blank" rel="noreferrer">Impactor</a> ·{" "}
        <a href={ILOADER} target="_blank" rel="noreferrer">iloader</a> ·{" "}
        <a href={SIDELOADLY} target="_blank" rel="noreferrer">Sideloadly</a>
        <span className="alt-note">{copy.alt.note}</span>
      </p>
    </>
  );
}

function CopyButton({ text, copy }: { text: string; copy: InstallCopy }) {
  const [done, setDone] = useState(false);
  useEffect(() => {
    if (!done) return;
    const timer = setTimeout(() => setDone(false), 2000);
    return () => clearTimeout(timer);
  }, [done]);
  const onClick = async () => {
    try {
      await navigator.clipboard.writeText(text);
    } catch {
      // Older browsers and non-secure contexts: copy through a hidden selection.
      const area = document.createElement("textarea");
      area.value = text;
      area.style.position = "fixed";
      area.style.opacity = "0";
      document.body.append(area);
      area.select();
      document.execCommand("copy");
      area.remove();
    }
    setDone(true);
  };
  return (
    <button type="button" className={done ? "copy-btn done" : "copy-btn"} onClick={onClick}>
      <SFSymbol name={done ? "checkmark" : "doc.on.doc"} />
      <span aria-live="polite">{done ? copy.copied : copy.copy}</span>
    </button>
  );
}
