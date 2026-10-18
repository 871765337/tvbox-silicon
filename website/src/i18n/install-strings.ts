// Copy for the "How to install" section, per site language.
import type { Lang } from "./strings";

export type Platform = "mac" | "ios" | "tv";
export type Sideload = Exclude<Platform, "mac">;
export type Mode = "agent" | "cli" | "app";

export interface Step {
  t: string;
  b: string;
}

export interface InstallCopy {
  nav: string;
  l1: string;
  l2: string;
  sub: string;
  device: Record<Platform, string>;
  req: Record<Platform, string>;
  tag: Record<Platform, string>;
  dl: Record<Platform, string>;
  /** Product-style title per platform, e.g. "Yingxia for Mac". */
  title: Record<Platform, string>;
  /** Short download button label. */
  get: string;
  /** The link to the Intel Mac package, beside the Mac Download button (which is Apple silicon). */
  intel: string;
  /** Heading above the steps. */
  how: string;
  steps: Record<Platform, Step[]>;
  /** The Terminal card: title, intro, the comment above each command, and the Windows note. */
  cli: { t: string; b: string; install: string; login: string; pair: string; pairTv: string; sign: string; win: string };
  /** The AI agent card. In the prompts, {skill} is the install skill's URL and {ipa} the download. */
  agent: { t: string; b: string; works: string; web: string; prompt: Record<Sideload, string> };
  copy: string;
  copied: string;
  /** The install-mode switcher; AI agent is the recommended mode. */
  modes: { label: string; rec: string } & Record<Mode, string>;
  /** Shown when choosing AI agent copies the prompt. */
  copiedPrompt: string;
  /** Steps for the AI agent and App modes (the Terminal mode uses `steps`). */
  agentSteps: Record<Sideload, Step[]>;
  appSteps: Record<Sideload, Step[]>;
  /** The App mode's card: each app's platforms. */
  apps: { t: string; b: string; impactor: string; iloader: string; sideloadly: string };
  keep: { t: string; b: string; free: string; freeTime: string; paid: string; paidTime: string; tip: string };
  guide: string;
}

export const INSTALL: Record<Lang, InstallCopy> = {
  en: {
    nav: "Install",
    l1: "Get Yingxia",
    l2: "on every screen.",
    sub: "The Mac app is a signed download. The iPhone, iPad and Apple TV apps are in preview: sign and install them with cider, a free command-line tool, and your own Apple account, free or paid. Or hand the job to your AI agent.",
    device: { mac: "Mac", ios: "iPhone & iPad", tv: "Apple TV" },
    req: { mac: "macOS 15+ · Apple silicon or Intel", ios: "iOS & iPadOS 18+", tv: "tvOS 26+" },
    tag: { mac: "Signed & notarized", ios: "Preview · Sideload", tv: "Preview · Sideload" },
    dl: { mac: "Download for Mac", ios: "Download the iPhone & iPad IPA", tv: "Download the Apple TV IPA" },
    title: { mac: "Yingxia for Mac", ios: "Yingxia for iPhone and iPad", tv: "Yingxia for Apple TV" },
    get: "Download",
    intel: "Download for Intel Mac",
    how: "Install in a few steps.",
    steps: {
      mac: [
        { t: "Download", b: "Get the disk image. It's signed and notarized by Apple." },
        { t: "Drag to Applications", b: "Open the DMG and drag Yingxia into your Applications folder." },
        { t: "Open and subscribe", b: "Launch Yingxia and paste your TVBox subscription URL." },
      ],
      ios: [
        { t: "Get the IPA and cider", b: "Download the iPhone & iPad IPA, then install cider, a free sideloading tool for macOS, Windows and Linux." },
        { t: "Sign in", b: "Run cider account login with your Apple account. A free account works, and you type the password yourself." },
        { t: "Plug in and trust", b: "Connect with a USB cable, unlock the device, tap Trust, then run cider device trust." },
        { t: "Sign and install", b: "cider signs the IPA with your account and installs it in one go." },
        { t: "Trust and play", b: "On the device, trust your Apple account in Settings → General → VPN & Device Management, turn on Developer Mode if asked, and open Yingxia." },
      ],
      tv: [
        { t: "Get the IPA and cider", b: "Download the Apple TV IPA and install cider on a Mac on the same network as your Apple TV. Apple TV installs need a Mac." },
        { t: "Sign in", b: "Run cider account login with your Apple account. A free account works, and you type the password yourself." },
        { t: "Pair once with Xcode", b: "On Apple TV, open Settings → Remotes and Devices → Remote App and Devices. On the Mac, open Xcode → Window → Devices and Simulators, select the Apple TV, click Pair and type the PIN." },
        { t: "Sign and install", b: "cider signs the IPA and sends it over Wi-Fi. The first install takes a few minutes." },
        { t: "Press play", b: "Open Yingxia on your Apple TV and add your subscription." },
      ],
    },
    cli: { t: "Run it yourself", b: "In Terminal, from the folder with the IPA:", install: "Install cider (macOS, Homebrew)", login: "Sign in to your Apple account", pair: "Pair your device", sign: "Sign and install", pairTv: "Pair Apple TV once in Xcode › Devices and Simulators, then check it's listed", win: "On Windows, download cider.exe from its releases and install iTunes or Apple Devices; the other commands are the same." },
    agent: {
      t: "Let your AI agent do it",
      b: "Paste this into an agent that can run commands on your computer. It reads Yingxia's install guide for agents and runs cider for you.",
      works: "Works with",
      web: "Web chats can't run the install. Use the agent's desktop or terminal app.",
      prompt: {
        ios: "Install Yingxia on my iPhone or iPad. First read {skill} and follow it. Use cider to sign the latest iOS IPA ({ipa}) with my Apple account and install it. Let me type my own password, and ask me before anything that could revoke a certificate.",
        tv: "Install Yingxia on my Apple TV from this Mac. First read {skill} and follow it. Use cider to sign the latest Apple TV IPA ({ipa}) with my Apple account and install it over Wi-Fi. Let me type my own password, and ask me before anything that could revoke a certificate.",
      },
    },
    copy: "Copy",
    copied: "Copied",
    modes: { label: "How to install", rec: "Recommended", agent: "AI agent", cli: "Terminal", app: "App" },
    copiedPrompt: "Prompt copied. Paste it into your agent.",
    agentSteps: {
      ios: [
        { t: "Copy the prompt", b: "Choosing AI agent copies it for you. It points your agent at Yingxia's install guide for agents." },
        { t: "Paste it into your agent", b: "Any agent that can run commands on your Mac, Windows or Linux computer, such as Claude Code, WorkBuddy, Doubao, Grok Build, Gemini CLI or Codex. It downloads the IPA and sets up cider." },
        { t: "Plug in and sign in", b: "Connect the device by USB and tap Trust. When cider asks, type your Apple account password yourself." },
        { t: "Trust and play", b: "On the device, trust your Apple account in Settings → General → VPN & Device Management, turn on Developer Mode if asked, and open Yingxia." },
      ],
      tv: [
        { t: "Copy the prompt", b: "Choosing AI agent copies it for you. It points your agent at Yingxia's install guide for agents." },
        { t: "Paste it into your agent", b: "Use an agent on a Mac on the same network as your Apple TV; Apple TV installs need a Mac. It downloads the IPA and sets up cider." },
        { t: "Pair and sign in", b: "On Apple TV, open Settings → Remotes and Devices → Remote App and Devices; the first time, pair it in Xcode on the Mac with the PIN the TV shows. Type your Apple account password into cider yourself." },
        { t: "Press play", b: "The first install takes a few minutes over Wi-Fi. Then open Yingxia on your Apple TV." },
      ],
    },
    appSteps: {
      ios: [
        { t: "Download the IPA", b: "Get the iPhone & iPad IPA above." },
        { t: "Get a sideloading app", b: "Impactor, iloader or Sideloadly, all free. Links below." },
        { t: "Sign in and add the IPA", b: "Connect the device by USB and tap Trust, sign in with your Apple account, add the IPA and start the install." },
        { t: "Trust and play", b: "On the device, trust your Apple account in Settings → General → VPN & Device Management, turn on Developer Mode if asked, and open Yingxia." },
      ],
      tv: [
        { t: "Download the IPA", b: "Get the Apple TV IPA above." },
        { t: "Get a sideloading app", b: "Impactor, or Sideloadly on a Mac. iloader doesn't support Apple TV." },
        { t: "Pair and install", b: "Keep Remote App and Devices open on Apple TV, pair with the PIN, sign in with your Apple account and add the IPA." },
        { t: "Press play", b: "Open Yingxia on your Apple TV." },
      ],
    },
    apps: { t: "Sideloading apps", b: "Free apps that sign the IPA with your Apple account. Download them only from these official links.", impactor: "macOS, Windows, Linux · iPhone, iPad, Apple TV", iloader: "macOS, Windows, Linux · iPhone, iPad", sideloadly: "macOS, Windows · Apple TV from a Mac" },
    keep: {
      t: "Keep it signed",
      b: "Sideloaded apps stop opening when their signature expires. Renew it before then: run cider refresh run if you signed with --refresh, or use your sideloading app's refresh.",
      free: "Free Apple account",
      freeTime: "7 days",
      paid: "Apple Developer Program",
      paidTime: "1 year",
      tip: "Reinstall with the same Apple account to keep your favorites and history.",
    },
    guide: "Full guide and troubleshooting",
  },
  ja: {
    nav: "インストール",
    l1: "どの画面にも、",
    l2: "映匣を。",
    sub: "Mac 版は署名済みアプリとしてダウンロードできます。iPhone、iPad、Apple TV 版はプレビューです。無料のコマンドラインツール cider とご自身の Apple アカウント（無料・有料どちらでも可）で署名してインストールします。AI エージェントに任せることもできます。",
    device: { mac: "Mac", ios: "iPhone・iPad", tv: "Apple TV" },
    req: { mac: "macOS 15 以降 · Apple シリコンまたは Intel", ios: "iOS・iPadOS 18 以降", tv: "tvOS 26 以降" },
    tag: { mac: "署名・公証済み", ios: "プレビュー · サイドロード", tv: "プレビュー · サイドロード" },
    dl: { mac: "Mac 版をダウンロード", ios: "iPhone・iPad 用 IPA をダウンロード", tv: "Apple TV 用 IPA をダウンロード" },
    title: { mac: "Mac 版 映匣", ios: "iPhone・iPad 版 映匣", tv: "Apple TV 版 映匣" },
    get: "ダウンロード",
    intel: "Intel 搭載 Mac 用をダウンロード",
    how: "数ステップでインストール。",
    steps: {
      mac: [
        { t: "ダウンロード", b: "Apple による署名・公証済みのディスクイメージを入手します。" },
        { t: "アプリケーションへ", b: "DMG を開き、映匣を「アプリケーション」フォルダにドラッグします。" },
        { t: "開いて登録", b: "映匣を起動し、TVBox のサブスクリプション URL を貼り付けます。" },
      ],
      ios: [
        { t: "IPA と cider を入手", b: "iPhone・iPad 用 IPA をダウンロードし、macOS・Windows・Linux 用の無料サイドロードツール cider をインストールします。" },
        { t: "サインイン", b: "cider account login を実行し、Apple アカウントでサインインします。無料アカウントで構いません。パスワードはご自身で入力します。" },
        { t: "接続して信頼", b: "USB ケーブルで接続し、ロックを解除して「信頼」をタップしてから cider device trust を実行します。" },
        { t: "署名してインストール", b: "cider があなたのアカウントで IPA に署名し、そのままインストールします。" },
        { t: "信頼して再生", b: "デバイスの「設定」→「一般」→「VPN とデバイス管理」で自分の Apple アカウントを信頼し、求められたらデベロッパモードをオンにして映匣を開きます。" },
      ],
      tv: [
        { t: "IPA と cider を入手", b: "Apple TV 用 IPA をダウンロードし、Apple TV と同じネットワークにある Mac に cider をインストールします。Apple TV へのインストールには Mac が必要です。" },
        { t: "サインイン", b: "cider account login を実行し、Apple アカウントでサインインします。無料アカウントで構いません。パスワードはご自身で入力します。" },
        { t: "Xcode で一度ペアリング", b: "Apple TV で「設定」→「リモコンとデバイス」→「Remote App とデバイス」を開きます。Mac で Xcode の「Window」→「Devices and Simulators」を開き、Apple TV を選んで「Pair」をクリックし、PIN を入力します。" },
        { t: "署名してインストール", b: "cider が IPA に署名し、Wi-Fi 経由で送ります。初回のインストールには数分かかります。" },
        { t: "再生しよう", b: "Apple TV で映匣を開き、サブスクリプションを追加します。" },
      ],
    },
    cli: { t: "自分で実行する", b: "IPA のあるフォルダでターミナルを開いて：", install: "cider をインストール（macOS・Homebrew）", login: "Apple アカウントにサインイン", pair: "デバイスをペアリング", sign: "署名してインストール", pairTv: "Apple TV は先に Xcode の「Devices and Simulators」で一度ペアリングし、表示を確認", win: "Windows では cider.exe をリリースページからダウンロードし、iTunes か Apple Devices をインストールしてください。ほかのコマンドは同じです。" },
    agent: {
      t: "AI エージェントに任せる",
      b: "お使いのコンピュータでコマンドを実行できるエージェントに貼り付けてください。映匣のエージェント向けインストールガイドを読み、cider を実行してくれます。",
      works: "対応エージェント",
      web: "Web 版のチャットではインストールできません。エージェントのデスクトップ版かターミナル版を使ってください。",
      prompt: {
        ios: "iPhone か iPad に映匣をインストールしてください。まず {skill} を読み、その手順に従ってください。cider で最新の iOS 用 IPA（{ipa}）を私の Apple アカウントで署名してインストールしてください。パスワードは私が自分で入力します。証明書を失効させる可能性がある操作の前には必ず確認してください。",
        tv: "この Mac から Apple TV に映匣をインストールしてください。まず {skill} を読み、その手順に従ってください。cider で最新の Apple TV 用 IPA（{ipa}）を私の Apple アカウントで署名し、Wi-Fi 経由でインストールしてください。パスワードは私が自分で入力します。証明書を失効させる可能性がある操作の前には必ず確認してください。",
      },
    },
    copy: "コピー",
    copied: "コピーしました",
    modes: { label: "インストール方法", rec: "おすすめ", agent: "AI エージェント", cli: "ターミナル", app: "アプリ" },
    copiedPrompt: "プロンプトをコピーしました。エージェントに貼り付けてください。",
    agentSteps: {
      ios: [
        { t: "プロンプトをコピー", b: "「AI エージェント」を選ぶと自動でコピーされます。エージェント向けの映匣インストールガイドを読ませるプロンプトです。" },
        { t: "エージェントに貼り付け", b: "Mac、Windows、Linux でコマンドを実行できるエージェント（Claude Code、WorkBuddy、豆包、Grok Build、Gemini CLI、Codex など）に貼り付けます。IPA のダウンロードと cider の準備はエージェントが行います。" },
        { t: "接続してサインイン", b: "USB でデバイスを接続して「信頼」をタップします。cider に聞かれたら、Apple アカウントのパスワードはご自身で入力します。" },
        { t: "信頼して再生", b: "デバイスの「設定」→「一般」→「VPN とデバイス管理」で自分の Apple アカウントを信頼し、求められたらデベロッパモードをオンにして映匣を開きます。" },
      ],
      tv: [
        { t: "プロンプトをコピー", b: "「AI エージェント」を選ぶと自動でコピーされます。エージェント向けの映匣インストールガイドを読ませるプロンプトです。" },
        { t: "エージェントに貼り付け", b: "Apple TV と同じネットワークにある Mac のエージェントを使います（Apple TV へのインストールには Mac が必要です）。IPA のダウンロードと cider の準備はエージェントが行います。" },
        { t: "ペアリングしてサインイン", b: "Apple TV で「設定」→「リモコンとデバイス」→「Remote App とデバイス」を開きます。初回は Mac の Xcode で、TV に表示された PIN を使ってペアリングします。Apple アカウントのパスワードはご自身で cider に入力します。" },
        { t: "再生しよう", b: "初回は Wi-Fi 経由で数分かかります。その後 Apple TV で映匣を開きます。" },
      ],
    },
    appSteps: {
      ios: [
        { t: "IPA をダウンロード", b: "上のボタンから iPhone・iPad 用 IPA を入手します。" },
        { t: "サイドロードアプリを入手", b: "Impactor、iloader、Sideloadly のいずれか（すべて無料）。リンクは下にあります。" },
        { t: "サインインして IPA を追加", b: "USB で接続して「信頼」をタップし、Apple アカウントでサインインして IPA を追加し、インストールを開始します。" },
        { t: "信頼して再生", b: "デバイスの「設定」→「一般」→「VPN とデバイス管理」で自分の Apple アカウントを信頼し、求められたらデベロッパモードをオンにして映匣を開きます。" },
      ],
      tv: [
        { t: "IPA をダウンロード", b: "上のボタンから Apple TV 用 IPA を入手します。" },
        { t: "サイドロードアプリを入手", b: "Impactor、または Mac 版 Sideloadly。iloader は Apple TV に対応していません。" },
        { t: "ペアリングしてインストール", b: "Apple TV で「Remote App とデバイス」を開いたまま PIN でペアリングし、Apple アカウントでサインインして IPA を追加します。" },
        { t: "再生しよう", b: "Apple TV で映匣を開きます。" },
      ],
    },
    apps: { t: "サイドロードアプリ", b: "あなたの Apple アカウントで IPA に署名する無料アプリです。必ず以下の公式リンクからダウンロードしてください。", impactor: "macOS・Windows・Linux · iPhone、iPad、Apple TV", iloader: "macOS・Windows・Linux · iPhone、iPad", sideloadly: "macOS・Windows · Apple TV は Mac から" },
    keep: {
      t: "署名を保つ",
      b: "サイドロードしたアプリは署名の期限が切れると起動しなくなります。期限前に更新しましょう。--refresh 付きで署名した場合は cider refresh run、アプリで入れた場合はそのアプリの更新機能を使います。",
      free: "無料の Apple アカウント",
      freeTime: "7 日間",
      paid: "Apple Developer Program",
      paidTime: "1 年間",
      tip: "同じ Apple アカウントで再インストールすれば、お気に入りや履歴はそのまま残ります。",
    },
    guide: "詳しい手順とトラブルシューティング",
  },
  ko: {
    nav: "설치",
    l1: "모든 화면에",
    l2: "Yingxia를.",
    sub: "Mac 버전은 서명된 앱으로 바로 다운로드할 수 있습니다. iPhone, iPad, Apple TV 버전은 프리뷰로, 무료 명령줄 도구 cider와 본인의 Apple 계정(무료 또는 유료)으로 서명해 설치합니다. AI 에이전트에게 맡길 수도 있습니다.",
    device: { mac: "Mac", ios: "iPhone·iPad", tv: "Apple TV" },
    req: { mac: "macOS 15 이상 · Apple 실리콘 또는 Intel", ios: "iOS·iPadOS 18 이상", tv: "tvOS 26 이상" },
    tag: { mac: "서명 및 공증 완료", ios: "프리뷰 · 사이드로드", tv: "프리뷰 · 사이드로드" },
    dl: { mac: "Mac용 다운로드", ios: "iPhone·iPad용 IPA 다운로드", tv: "Apple TV용 IPA 다운로드" },
    title: { mac: "Mac용 Yingxia", ios: "iPhone·iPad용 Yingxia", tv: "Apple TV용 Yingxia" },
    get: "다운로드",
    intel: "Intel 기반 Mac용 다운로드",
    how: "몇 단계면 설치 완료.",
    steps: {
      mac: [
        { t: "다운로드", b: "Apple의 서명과 공증을 받은 디스크 이미지를 받습니다." },
        { t: "응용 프로그램으로", b: "DMG를 열고 Yingxia를 응용 프로그램 폴더로 드래그합니다." },
        { t: "열고 구독 추가", b: "Yingxia를 실행하고 TVBox 구독 URL을 붙여 넣습니다." },
      ],
      ios: [
        { t: "IPA와 cider 받기", b: "iPhone·iPad용 IPA를 다운로드하고, macOS·Windows·Linux용 무료 사이드로드 도구 cider를 설치합니다." },
        { t: "로그인", b: "cider account login을 실행해 Apple 계정으로 로그인합니다. 무료 계정도 되며, 암호는 직접 입력합니다." },
        { t: "연결하고 신뢰", b: "USB 케이블로 연결하고 잠금을 해제해 '신뢰'를 탭한 뒤 cider device trust를 실행합니다." },
        { t: "서명하고 설치", b: "cider가 본인 계정으로 IPA에 서명하고 바로 설치합니다." },
        { t: "신뢰하고 재생", b: "기기의 설정 → 일반 → VPN 및 기기 관리에서 본인의 Apple 계정을 신뢰하고, 요청하면 개발자 모드를 켠 뒤 Yingxia를 엽니다." },
      ],
      tv: [
        { t: "IPA와 cider 받기", b: "Apple TV용 IPA를 다운로드하고, Apple TV와 같은 네트워크에 있는 Mac에 cider를 설치합니다. Apple TV 설치에는 Mac이 필요합니다." },
        { t: "로그인", b: "cider account login을 실행해 Apple 계정으로 로그인합니다. 무료 계정도 되며, 암호는 직접 입력합니다." },
        { t: "Xcode로 한 번 페어링", b: "Apple TV에서 설정 → 리모컨 및 기기 → 리모트 앱 및 기기를 엽니다. Mac에서 Xcode → Window → Devices and Simulators를 열고 Apple TV를 선택해 Pair를 클릭한 뒤 PIN을 입력합니다." },
        { t: "서명하고 설치", b: "cider가 IPA에 서명해 Wi-Fi로 보냅니다. 처음 설치는 몇 분 걸립니다." },
        { t: "재생 시작", b: "Apple TV에서 Yingxia를 열고 구독을 추가합니다." },
      ],
    },
    cli: { t: "직접 실행", b: "IPA가 있는 폴더에서 터미널로:", install: "cider 설치(macOS, Homebrew)", login: "Apple 계정 로그인", pair: "기기 페어링", sign: "서명하고 설치", pairTv: "Apple TV는 먼저 Xcode의 Devices and Simulators에서 한 번 페어링한 뒤 확인", win: "Windows에서는 릴리스 페이지에서 cider.exe를 받고 iTunes 또는 Apple Devices를 설치하세요. 나머지 명령은 같습니다." },
    agent: {
      t: "AI 에이전트에게 맡기기",
      b: "컴퓨터에서 명령을 실행할 수 있는 에이전트에 붙여 넣으세요. Yingxia의 에이전트용 설치 가이드를 읽고 cider를 대신 실행합니다.",
      works: "지원 에이전트",
      web: "웹 채팅으로는 설치할 수 없습니다. 에이전트의 데스크톱 앱이나 터미널 버전을 사용하세요.",
      prompt: {
        ios: "내 iPhone 또는 iPad에 Yingxia를 설치해 줘. 먼저 {skill}을 읽고 그대로 따라 줘. cider로 최신 iOS용 IPA({ipa})를 내 Apple 계정으로 서명해서 설치해 줘. 암호는 내가 직접 입력할게. 인증서를 취소할 수 있는 작업은 하기 전에 꼭 물어봐 줘.",
        tv: "이 Mac에서 내 Apple TV에 Yingxia를 설치해 줘. 먼저 {skill}을 읽고 그대로 따라 줘. cider로 최신 Apple TV용 IPA({ipa})를 내 Apple 계정으로 서명해서 Wi-Fi로 설치해 줘. 암호는 내가 직접 입력할게. 인증서를 취소할 수 있는 작업은 하기 전에 꼭 물어봐 줘.",
      },
    },
    copy: "복사",
    copied: "복사됨",
    modes: { label: "설치 방법", rec: "추천", agent: "AI 에이전트", cli: "터미널", app: "앱" },
    copiedPrompt: "프롬프트를 복사했습니다. 에이전트에 붙여 넣으세요.",
    agentSteps: {
      ios: [
        { t: "프롬프트 복사", b: "'AI 에이전트'를 선택하면 자동으로 복사됩니다. 에이전트용 Yingxia 설치 가이드를 읽게 하는 프롬프트입니다." },
        { t: "에이전트에 붙여 넣기", b: "Mac, Windows, Linux에서 명령을 실행할 수 있는 에이전트(Claude Code, WorkBuddy, Doubao, Grok Build, Gemini CLI, Codex 등)에 붙여 넣습니다. IPA 다운로드와 cider 준비는 에이전트가 합니다." },
        { t: "연결하고 로그인", b: "USB로 기기를 연결하고 '신뢰'를 탭합니다. cider가 물으면 Apple 계정 암호는 직접 입력합니다." },
        { t: "신뢰하고 재생", b: "기기의 설정 → 일반 → VPN 및 기기 관리에서 본인의 Apple 계정을 신뢰하고, 요청하면 개발자 모드를 켠 뒤 Yingxia를 엽니다." },
      ],
      tv: [
        { t: "프롬프트 복사", b: "'AI 에이전트'를 선택하면 자동으로 복사됩니다. 에이전트용 Yingxia 설치 가이드를 읽게 하는 프롬프트입니다." },
        { t: "에이전트에 붙여 넣기", b: "Apple TV와 같은 네트워크에 있는 Mac의 에이전트를 사용합니다(Apple TV 설치에는 Mac이 필요합니다). IPA 다운로드와 cider 준비는 에이전트가 합니다." },
        { t: "페어링하고 로그인", b: "Apple TV에서 설정 → 리모컨 및 기기 → 리모트 앱 및 기기를 엽니다. 처음에는 Mac의 Xcode에서 TV에 표시된 PIN으로 페어링합니다. Apple 계정 암호는 cider에 직접 입력합니다." },
        { t: "재생 시작", b: "처음 설치는 Wi-Fi로 몇 분 걸립니다. 그런 다음 Apple TV에서 Yingxia를 엽니다." },
      ],
    },
    appSteps: {
      ios: [
        { t: "IPA 다운로드", b: "위에서 iPhone·iPad용 IPA를 받습니다." },
        { t: "사이드로드 앱 받기", b: "Impactor, iloader, Sideloadly 중 하나(모두 무료). 링크는 아래에 있습니다." },
        { t: "로그인하고 IPA 추가", b: "USB로 연결해 '신뢰'를 탭하고, Apple 계정으로 로그인한 뒤 IPA를 추가해 설치를 시작합니다." },
        { t: "신뢰하고 재생", b: "기기의 설정 → 일반 → VPN 및 기기 관리에서 본인의 Apple 계정을 신뢰하고, 요청하면 개발자 모드를 켠 뒤 Yingxia를 엽니다." },
      ],
      tv: [
        { t: "IPA 다운로드", b: "위에서 Apple TV용 IPA를 받습니다." },
        { t: "사이드로드 앱 받기", b: "Impactor 또는 Mac용 Sideloadly. iloader는 Apple TV를 지원하지 않습니다." },
        { t: "페어링하고 설치", b: "Apple TV에서 리모트 앱 및 기기를 열어 둔 채 PIN으로 페어링하고, Apple 계정으로 로그인해 IPA를 추가합니다." },
        { t: "재생 시작", b: "Apple TV에서 Yingxia를 엽니다." },
      ],
    },
    apps: { t: "사이드로드 앱", b: "본인 Apple 계정으로 IPA에 서명하는 무료 앱입니다. 아래 공식 링크에서만 다운로드하세요.", impactor: "macOS·Windows·Linux · iPhone, iPad, Apple TV", iloader: "macOS·Windows·Linux · iPhone, iPad", sideloadly: "macOS·Windows · Apple TV는 Mac에서" },
    keep: {
      t: "서명 유지",
      b: "사이드로드한 앱은 서명이 만료되면 열리지 않습니다. 만료 전에 갱신하세요. --refresh로 서명했다면 cider refresh run을, 앱으로 설치했다면 그 앱의 갱신 기능을 쓰면 됩니다.",
      free: "무료 Apple 계정",
      freeTime: "7일",
      paid: "Apple Developer Program",
      paidTime: "1년",
      tip: "같은 Apple 계정으로 다시 설치하면 즐겨찾기와 기록이 그대로 유지됩니다.",
    },
    guide: "전체 가이드 및 문제 해결",
  },
  "zh-Hant": {
    nav: "安裝",
    l1: "每一塊螢幕，",
    l2: "都有映匣。",
    sub: "Mac 版提供已簽署的下載檔。iPhone、iPad 與 Apple TV 版以預覽形式提供，用免費的命令列工具 cider 和你自己的 Apple 帳號（免費或付費皆可）簽署並安裝。也可以交給你的 AI 代理處理。",
    device: { mac: "Mac", ios: "iPhone 與 iPad", tv: "Apple TV" },
    req: { mac: "macOS 15 以上 · Apple 晶片或 Intel", ios: "iOS 與 iPadOS 18 以上", tv: "tvOS 26 以上" },
    tag: { mac: "已簽署並公證", ios: "預覽 · 側載", tv: "預覽 · 側載" },
    dl: { mac: "下載 Mac 版", ios: "下載 iPhone 與 iPad 版 IPA", tv: "下載 Apple TV 版 IPA" },
    title: { mac: "映匣 Mac 版", ios: "映匣 iPhone 與 iPad 版", tv: "映匣 Apple TV 版" },
    get: "下載",
    intel: "下載 Intel 處理器 Mac 版",
    how: "幾個步驟就能安裝。",
    steps: {
      mac: [
        { t: "下載", b: "取得經 Apple 簽署與公證的磁碟映像檔。" },
        { t: "拖進應用程式", b: "打開 DMG，把映匣拖到「應用程式」檔案夾。" },
        { t: "打開並加入訂閱", b: "啟動映匣，貼上你的 TVBox 訂閱網址。" },
      ],
      ios: [
        { t: "取得 IPA 與 cider", b: "下載 iPhone 與 iPad 版 IPA，再安裝 cider：適用 macOS、Windows 與 Linux 的免費側載工具。" },
        { t: "登入", b: "執行 cider account login，用你的 Apple 帳號登入。免費帳號也可以，密碼由你自己輸入。" },
        { t: "連接並信任", b: "用 USB 線連接裝置，解鎖後點一下「信任」，再執行 cider device trust。" },
        { t: "簽署並安裝", b: "cider 會用你的帳號簽署 IPA，並直接安裝。" },
        { t: "信任並播放", b: "在裝置的「設定」→「一般」→「VPN 與裝置管理」信任你的 Apple 帳號，若有提示請開啟「開發者模式」，然後打開映匣。" },
      ],
      tv: [
        { t: "取得 IPA 與 cider", b: "下載 Apple TV 版 IPA，並在與 Apple TV 同一個網路的 Mac 上安裝 cider。安裝到 Apple TV 需要 Mac。" },
        { t: "登入", b: "執行 cider account login，用你的 Apple 帳號登入。免費帳號也可以，密碼由你自己輸入。" },
        { t: "用 Xcode 配對一次", b: "在 Apple TV 前往「設定」→「遙控器與裝置」→「Remote App 與裝置」。在 Mac 上打開 Xcode →「Window」→「Devices and Simulators」，選擇 Apple TV、按「Pair」並輸入 PIN 碼。" },
        { t: "簽署並安裝", b: "cider 會簽署 IPA 並透過 Wi-Fi 傳送。第一次安裝需要幾分鐘。" },
        { t: "開始播放", b: "在 Apple TV 上打開映匣，加入你的訂閱。" },
      ],
    },
    cli: { t: "自己動手", b: "在 IPA 所在的檔案夾開啟終端機：", install: "安裝 cider（macOS、Homebrew）", login: "登入 Apple 帳號", pair: "配對裝置", sign: "簽署並安裝", pairTv: "先在 Xcode 的「Devices and Simulators」配對 Apple TV 一次，再確認已列出", win: "在 Windows 上，請從發佈頁面下載 cider.exe，並安裝 iTunes 或 Apple Devices；其他指令相同。" },
    agent: {
      t: "交給 AI 代理",
      b: "把這段提示貼到能在你電腦上執行指令的代理。它會先讀映匣給代理看的安裝指南，再替你執行 cider。",
      works: "支援的代理",
      web: "網頁版聊天無法安裝，請使用代理的桌面版或終端機版本。",
      prompt: {
        ios: "幫我把映匣安裝到我的 iPhone 或 iPad。請先閱讀 {skill} 並照著做：用 cider 以我的 Apple 帳號簽署並安裝最新的 iOS 版 IPA（{ipa}）。密碼由我自己輸入；任何可能撤銷憑證的操作，請先問我。",
        tv: "幫我從這台 Mac 把映匣安裝到我的 Apple TV。請先閱讀 {skill} 並照著做：用 cider 以我的 Apple 帳號簽署最新的 Apple TV 版 IPA（{ipa}），並透過 Wi-Fi 安裝。密碼由我自己輸入；任何可能撤銷憑證的操作，請先問我。",
      },
    },
    copy: "拷貝",
    copied: "已拷貝",
    modes: { label: "安裝方式", rec: "推薦", agent: "AI 代理", cli: "終端機", app: "App" },
    copiedPrompt: "已拷貝提示，貼到你的代理即可。",
    agentSteps: {
      ios: [
        { t: "拷貝提示", b: "選擇「AI 代理」就會自動拷貝。這段提示會讓代理去讀映匣給代理看的安裝指南。" },
        { t: "貼到你的代理", b: "貼到能在 Mac、Windows 或 Linux 上執行指令的代理，例如 Claude Code、WorkBuddy、豆包、Grok Build、Gemini CLI 或 Codex。下載 IPA、準備 cider 都由代理處理。" },
        { t: "連接並登入", b: "用 USB 連接裝置並點「信任」。cider 詢問時，Apple 帳號密碼由你自己輸入。" },
        { t: "信任並播放", b: "在裝置的「設定」→「一般」→「VPN 與裝置管理」信任你的 Apple 帳號，若有提示請開啟「開發者模式」，然後打開映匣。" },
      ],
      tv: [
        { t: "拷貝提示", b: "選擇「AI 代理」就會自動拷貝。這段提示會讓代理去讀映匣給代理看的安裝指南。" },
        { t: "貼到你的代理", b: "請使用與 Apple TV 同一網路的 Mac 上的代理（安裝到 Apple TV 需要 Mac）。下載 IPA、準備 cider 都由代理處理。" },
        { t: "配對並登入", b: "在 Apple TV 前往「設定」→「遙控器與裝置」→「Remote App 與裝置」。第一次需要在 Mac 的 Xcode 用電視上的 PIN 碼配對。Apple 帳號密碼由你自己輸入到 cider。" },
        { t: "開始播放", b: "第一次透過 Wi-Fi 安裝需要幾分鐘，完成後在 Apple TV 上打開映匣。" },
      ],
    },
    appSteps: {
      ios: [
        { t: "下載 IPA", b: "從上方取得 iPhone 與 iPad 版 IPA。" },
        { t: "取得側載 App", b: "Impactor、iloader 或 Sideloadly，全都免費，連結在下方。" },
        { t: "登入並加入 IPA", b: "用 USB 連接並點「信任」，用 Apple 帳號登入，加入 IPA 後開始安裝。" },
        { t: "信任並播放", b: "在裝置的「設定」→「一般」→「VPN 與裝置管理」信任你的 Apple 帳號，若有提示請開啟「開發者模式」，然後打開映匣。" },
      ],
      tv: [
        { t: "下載 IPA", b: "從上方取得 Apple TV 版 IPA。" },
        { t: "取得側載 App", b: "Impactor，或 Mac 版 Sideloadly。iloader 不支援 Apple TV。" },
        { t: "配對並安裝", b: "在 Apple TV 開著「Remote App 與裝置」畫面，用 PIN 碼配對，以 Apple 帳號登入並加入 IPA。" },
        { t: "開始播放", b: "在 Apple TV 上打開映匣。" },
      ],
    },
    apps: { t: "側載 App", b: "用你的 Apple 帳號簽署 IPA 的免費 App。請只從以下官方連結下載。", impactor: "macOS、Windows、Linux · iPhone、iPad、Apple TV", iloader: "macOS、Windows、Linux · iPhone、iPad", sideloadly: "macOS、Windows · Apple TV 需使用 Mac" },
    keep: {
      t: "保持簽署有效",
      b: "側載的 App 在簽署到期後就無法開啟。請在到期前續簽：用 --refresh 簽署的話執行 cider refresh run，用 App 安裝的話使用該 App 的更新功能。",
      free: "免費 Apple 帳號",
      freeTime: "7 天",
      paid: "Apple Developer Program",
      paidTime: "1 年",
      tip: "用同一個 Apple 帳號重新安裝，收藏與紀錄都會保留。",
    },
    guide: "完整指南與疑難排解",
  },
};
