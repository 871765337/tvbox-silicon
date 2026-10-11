// Copy for the "How to install" section, per site language.
import type { Lang } from "./strings";

export type Platform = "mac" | "ios" | "tv";
export type Sideload = Exclude<Platform, "mac">;

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
  /** Link to the cider repository. */
  cider: string;
  /** Product-style title per platform, e.g. "Yingxia for Mac". */
  title: Record<Platform, string>;
  /** Short download button label. */
  get: string;
  /** Heading above the steps. */
  how: string;
  steps: Record<Platform, Step[]>;
  /** The Terminal card: title, intro and the comment above each command. */
  cli: { t: string; b: string; install: string; login: string; pair: string; sign: string };
  /** The AI agent card. In the prompts, {skill} is the install skill's URL and {ipa} the download. */
  agent: { t: string; b: string; prompt: Record<Sideload, string> };
  copy: string;
  copied: string;
  /** Sideloading apps that also work. */
  alt: { t: string; note: string };
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
    req: { mac: "macOS 26+ · Apple silicon", ios: "iOS & iPadOS 26+", tv: "tvOS 26+" },
    tag: { mac: "Signed & notarized", ios: "Preview · Sideload", tv: "Preview · Sideload" },
    dl: { mac: "Download for Mac", ios: "Download the iPhone & iPad IPA", tv: "Download the Apple TV IPA" },
    cider: "Get cider",
    title: { mac: "Yingxia for Mac", ios: "Yingxia for iPhone and iPad", tv: "Yingxia for Apple TV" },
    get: "Download",
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
        { t: "Get the IPA and cider", b: "Download the Apple TV IPA and install cider on a computer on the same network as your Apple TV." },
        { t: "Sign in", b: "Run cider account login with your Apple account. A free account works, and you type the password yourself." },
        { t: "Pair over Wi-Fi", b: "On Apple TV, open Settings → Remotes and Devices → Remote App and Devices. Run cider device trust and enter the PIN it shows." },
        { t: "Sign and install", b: "cider signs the IPA and sends it over Wi-Fi. The first install takes a few minutes." },
        { t: "Press play", b: "Open Yingxia on your Apple TV and add your subscription." },
      ],
    },
    cli: { t: "Run it yourself", b: "In Terminal, from the folder with the IPA:", install: "Install cider (macOS, Homebrew)", login: "Sign in to your Apple account", pair: "Pair your device", sign: "Sign and install" },
    agent: {
      t: "Or let your AI agent do it",
      b: "Paste this into Claude Code, Codex or another agent on your computer. It reads Yingxia's install guide for agents and runs cider for you.",
      prompt: {
        ios: "Install Yingxia on my iPhone or iPad. First read {skill} and follow it. Use cider to sign the latest iOS IPA ({ipa}) with my Apple account and install it. Let me type my own password, and ask me before anything that could revoke a certificate.",
        tv: "Install Yingxia on my Apple TV. First read {skill} and follow it. Use cider to sign the latest Apple TV IPA ({ipa}) with my Apple account and install it over Wi-Fi. Let me type my own password, and ask me before anything that could revoke a certificate.",
      },
    },
    copy: "Copy",
    copied: "Copied",
    alt: { t: "Prefer an app?", note: "Impactor and Sideloadly (on a Mac) also install to Apple TV. iloader is for iPhone and iPad." },
    keep: {
      t: "Keep it signed",
      b: "Sideloaded apps stop opening when their signature expires. Sign with --refresh and cider remembers the app: run cider refresh run before it runs out.",
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
    req: { mac: "macOS 26 以降 · Apple シリコン", ios: "iOS・iPadOS 26 以降", tv: "tvOS 26 以降" },
    tag: { mac: "署名・公証済み", ios: "プレビュー · サイドロード", tv: "プレビュー · サイドロード" },
    dl: { mac: "Mac 版をダウンロード", ios: "iPhone・iPad 用 IPA をダウンロード", tv: "Apple TV 用 IPA をダウンロード" },
    cider: "cider を入手",
    title: { mac: "Mac 版 映匣", ios: "iPhone・iPad 版 映匣", tv: "Apple TV 版 映匣" },
    get: "ダウンロード",
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
        { t: "IPA と cider を入手", b: "Apple TV 用 IPA をダウンロードし、Apple TV と同じネットワークにあるコンピュータに cider をインストールします。" },
        { t: "サインイン", b: "cider account login を実行し、Apple アカウントでサインインします。無料アカウントで構いません。パスワードはご自身で入力します。" },
        { t: "Wi-Fi でペアリング", b: "Apple TV で「設定」→「リモコンとデバイス」→「Remote App とデバイス」を開き、cider device trust を実行して表示された PIN を入力します。" },
        { t: "署名してインストール", b: "cider が IPA に署名し、Wi-Fi 経由で送ります。初回のインストールには数分かかります。" },
        { t: "再生しよう", b: "Apple TV で映匣を開き、サブスクリプションを追加します。" },
      ],
    },
    cli: { t: "自分で実行する", b: "IPA のあるフォルダでターミナルを開いて：", install: "cider をインストール（macOS・Homebrew）", login: "Apple アカウントにサインイン", pair: "デバイスをペアリング", sign: "署名してインストール" },
    agent: {
      t: "AI エージェントに任せる",
      b: "Claude Code や Codex など、お使いのコンピュータのエージェントに貼り付けてください。映匣のエージェント向けインストールガイドを読み、cider を実行してくれます。",
      prompt: {
        ios: "iPhone か iPad に映匣をインストールしてください。まず {skill} を読み、その手順に従ってください。cider で最新の iOS 用 IPA（{ipa}）を私の Apple アカウントで署名してインストールしてください。パスワードは私が自分で入力します。証明書を失効させる可能性がある操作の前には必ず確認してください。",
        tv: "Apple TV に映匣をインストールしてください。まず {skill} を読み、その手順に従ってください。cider で最新の Apple TV 用 IPA（{ipa}）を私の Apple アカウントで署名し、Wi-Fi 経由でインストールしてください。パスワードは私が自分で入力します。証明書を失効させる可能性がある操作の前には必ず確認してください。",
      },
    },
    copy: "コピー",
    copied: "コピーしました",
    alt: { t: "アプリで入れたい場合", note: "Impactor と Sideloadly（Mac）は Apple TV にも対応しています。iloader は iPhone・iPad 用です。" },
    keep: {
      t: "署名を保つ",
      b: "サイドロードしたアプリは署名の期限が切れると起動しなくなります。--refresh 付きで署名しておけば、期限前に cider refresh run を実行するだけで更新できます。",
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
    req: { mac: "macOS 26 이상 · Apple 실리콘", ios: "iOS·iPadOS 26 이상", tv: "tvOS 26 이상" },
    tag: { mac: "서명 및 공증 완료", ios: "프리뷰 · 사이드로드", tv: "프리뷰 · 사이드로드" },
    dl: { mac: "Mac용 다운로드", ios: "iPhone·iPad용 IPA 다운로드", tv: "Apple TV용 IPA 다운로드" },
    cider: "cider 받기",
    title: { mac: "Mac용 Yingxia", ios: "iPhone·iPad용 Yingxia", tv: "Apple TV용 Yingxia" },
    get: "다운로드",
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
        { t: "IPA와 cider 받기", b: "Apple TV용 IPA를 다운로드하고, Apple TV와 같은 네트워크에 있는 컴퓨터에 cider를 설치합니다." },
        { t: "로그인", b: "cider account login을 실행해 Apple 계정으로 로그인합니다. 무료 계정도 되며, 암호는 직접 입력합니다." },
        { t: "Wi-Fi로 페어링", b: "Apple TV에서 설정 → 리모컨 및 기기 → 리모트 앱 및 기기를 열고, cider device trust를 실행해 표시된 PIN을 입력합니다." },
        { t: "서명하고 설치", b: "cider가 IPA에 서명해 Wi-Fi로 보냅니다. 처음 설치는 몇 분 걸립니다." },
        { t: "재생 시작", b: "Apple TV에서 Yingxia를 열고 구독을 추가합니다." },
      ],
    },
    cli: { t: "직접 실행", b: "IPA가 있는 폴더에서 터미널로:", install: "cider 설치(macOS, Homebrew)", login: "Apple 계정 로그인", pair: "기기 페어링", sign: "서명하고 설치" },
    agent: {
      t: "AI 에이전트에게 맡기기",
      b: "Claude Code, Codex 등 컴퓨터의 에이전트에 붙여 넣으세요. Yingxia의 에이전트용 설치 가이드를 읽고 cider를 대신 실행합니다.",
      prompt: {
        ios: "내 iPhone 또는 iPad에 Yingxia를 설치해 줘. 먼저 {skill}을 읽고 그대로 따라 줘. cider로 최신 iOS용 IPA({ipa})를 내 Apple 계정으로 서명해서 설치해 줘. 암호는 내가 직접 입력할게. 인증서를 취소할 수 있는 작업은 하기 전에 꼭 물어봐 줘.",
        tv: "내 Apple TV에 Yingxia를 설치해 줘. 먼저 {skill}을 읽고 그대로 따라 줘. cider로 최신 Apple TV용 IPA({ipa})를 내 Apple 계정으로 서명해서 Wi-Fi로 설치해 줘. 암호는 내가 직접 입력할게. 인증서를 취소할 수 있는 작업은 하기 전에 꼭 물어봐 줘.",
      },
    },
    copy: "복사",
    copied: "복사됨",
    alt: { t: "앱이 더 편하다면", note: "Impactor와 Sideloadly(Mac)는 Apple TV도 지원합니다. iloader는 iPhone·iPad용입니다." },
    keep: {
      t: "서명 유지",
      b: "사이드로드한 앱은 서명이 만료되면 열리지 않습니다. --refresh로 서명해 두면 만료 전에 cider refresh run만 실행해 갱신할 수 있습니다.",
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
    req: { mac: "macOS 26 以上 · Apple 晶片", ios: "iOS 與 iPadOS 26 以上", tv: "tvOS 26 以上" },
    tag: { mac: "已簽署並公證", ios: "預覽 · 側載", tv: "預覽 · 側載" },
    dl: { mac: "下載 Mac 版", ios: "下載 iPhone 與 iPad 版 IPA", tv: "下載 Apple TV 版 IPA" },
    cider: "取得 cider",
    title: { mac: "映匣 Mac 版", ios: "映匣 iPhone 與 iPad 版", tv: "映匣 Apple TV 版" },
    get: "下載",
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
        { t: "取得 IPA 與 cider", b: "下載 Apple TV 版 IPA，並在與 Apple TV 同一個網路的電腦上安裝 cider。" },
        { t: "登入", b: "執行 cider account login，用你的 Apple 帳號登入。免費帳號也可以，密碼由你自己輸入。" },
        { t: "透過 Wi-Fi 配對", b: "在 Apple TV 前往「設定」→「遙控器與裝置」→「Remote App 與裝置」，執行 cider device trust 並輸入畫面上的 PIN 碼。" },
        { t: "簽署並安裝", b: "cider 會簽署 IPA 並透過 Wi-Fi 傳送。第一次安裝需要幾分鐘。" },
        { t: "開始播放", b: "在 Apple TV 上打開映匣，加入你的訂閱。" },
      ],
    },
    cli: { t: "自己動手", b: "在 IPA 所在的檔案夾開啟終端機：", install: "安裝 cider（macOS、Homebrew）", login: "登入 Apple 帳號", pair: "配對裝置", sign: "簽署並安裝" },
    agent: {
      t: "或交給 AI 代理",
      b: "把這段提示貼到你電腦上的 Claude Code、Codex 或其他代理。它會先讀映匣給代理看的安裝指南，再替你執行 cider。",
      prompt: {
        ios: "幫我把映匣安裝到我的 iPhone 或 iPad。請先閱讀 {skill} 並照著做：用 cider 以我的 Apple 帳號簽署並安裝最新的 iOS 版 IPA（{ipa}）。密碼由我自己輸入；任何可能撤銷憑證的操作，請先問我。",
        tv: "幫我把映匣安裝到我的 Apple TV。請先閱讀 {skill} 並照著做：用 cider 以我的 Apple 帳號簽署最新的 Apple TV 版 IPA（{ipa}），並透過 Wi-Fi 安裝。密碼由我自己輸入；任何可能撤銷憑證的操作，請先問我。",
      },
    },
    copy: "拷貝",
    copied: "已拷貝",
    alt: { t: "想用 App 安裝？", note: "Impactor 與 Sideloadly（Mac）也支援 Apple TV；iloader 適用 iPhone 與 iPad。" },
    keep: {
      t: "保持簽署有效",
      b: "側載的 App 在簽署到期後就無法開啟。用 --refresh 簽署後，只要在到期前執行 cider refresh run 就能續簽。",
      free: "免費 Apple 帳號",
      freeTime: "7 天",
      paid: "Apple Developer Program",
      paidTime: "1 年",
      tip: "用同一個 Apple 帳號重新安裝，收藏與紀錄都會保留。",
    },
    guide: "完整指南與疑難排解",
  },
};
