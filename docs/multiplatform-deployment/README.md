# 多端部署方案调研（免费 / 付费）

> 调研时间：2026-08 · 适用对象：uniygopro（Flutter 游戏应用）多端发布：iOS / Android / Web / macOS / Windows / Linux
> 目标：梳理各端官方商店与第三方分发渠道的成本、资质要求与流程，给出免费起步与正式上线的完整路径。

---

## 一、结论速览（TL;DR）

| 目标端 | 免费起步 | 正式上线（付费） | 成本门槛 |
|---|---|---|---|
| **iOS / iPadOS** | TestFlight 内测（需开发者账号） | App Store 上架 | **$99/年**（Apple Developer） |
| **Android（海外）** | GitHub Releases / 侧载 APK | Google Play | **$25 一次性**（2026 起新账号需 12 名测试者规则） |
| **Android（国内）** | 蒲公英等内测分发 | 华为/小米/OPPO/vivo/应用宝等 | **¥0~1000**（软著 + APP 备案） |
| **Web** | GitHub Pages / Cloudflare Pages / Vercel（免费） | 自定义域名 + 国内备案（可选） | **¥0**（域名除外） |
| **macOS** | 自签名 dmg / GitHub Releases | Mac App Store / 公证 | **$99/年**（公证需开发者账号） |
| **Windows** | 免签 exe / GitHub Releases | Microsoft Store（MSIX） | **$0~19**（商店注册费） |
| **Linux** | AppImage / Flatpak / Snap（免费） | 各发行版仓库 | **¥0** |
| **Steam**（可选） | — | Steam Direct | **$100/款** |

**一句话**：Flutter 项目多端发布，**Web 端几乎零成本**、Android 海外 $25 买断、iOS/macOS 需 $99/年、国内安卓核心成本是**软著 + APP 备案**（钱少但周期长）。

---

## 二、各端详细方案

### 2.1 iOS / iPadOS

| 项目 | 说明 |
|---|---|
| 开发者账号 | **$99/年**（个人或公司）；公司需 D-U-N-S 编码 |
| 内测 | **TestFlight**（免费，随账号含 100 台设备/90 天，公开测试链接可 1 万人） |
| 正式上架 | App Store Connect 提交审核（1~7 天）；需截图、隐私政策、App 隐私标签 |
| 免费替代 | **无**——iOS 必须开发者账号才能安装到真机/上架；Ad-hoc 也需账号 |
| 注意 | 游戏类需在 App Store Connect 声明分级（IARC 问卷免费）；有内购需走 IAP（苹果抽成 30%/15%） |

### 2.2 Android（海外：Google Play）

| 项目 | 说明 |
|---|---|
| 开发者账号 | **$25 一次性**；2026 新规：新账号需 **12 名测试者连续 14 天测试**才能上架 |
| 签名 | 自备 keystore 或 Play App Signing（推荐后者，密钥由 Google 托管） |
| 内测 | Play Console 内部测试/封闭测试/开放测试（免费，随账号） |
| 正式上架 | 上架审核数小时~数天；需隐私政策、数据安全表单 |
| 免费替代 | GitHub Releases 发 APK / AAB 侧载（无商店分发），或第三方商店（APKPure 等） |

> 本项目现状：已配置 `apps/uniygopro/android/app/upload-keystore.jks` + `key.properties` 发布签名材料，CI 可自动签名，符合 Play 上架条件。

### 2.3 Android（国内渠道）

| 渠道 | 核心资质要求 | 费用 |
|---|---|---|
| 华为应用市场 | 软著 + APP 备案 | ¥0（资质办理费另计） |
| 小米应用商店 | 软著 + APP 备案 | ¥0 |
| OPPO / vivo / 荣耀 | 软著 + APP 备案 | ¥0 |
| 应用宝（腾讯） | 软著 + APP 备案 | ¥0 |
| 360 / 百度等 | 软著 + APP 备案（部分要求 ICP 许可证） | ¥0 |

**资质办理成本与周期**：

| 资质 | 费用 | 周期 | 说明 |
|---|---|---|---|
| **软件著作权（软著）** | 自办 ¥0；代理约 **¥300~1000** | 30 个工作日左右（加急另计） | 上架硬性门槛，个人/公司均可申请 |
| **APP 备案**（工信部） | **¥0** | 1~2 周 | 需域名 + 大陆服务器；2023 年起强制 |
| **ICP 备案** | ¥0（域名 + 服务器费用自理） | 1~2 周 | APP 备案的前置/并列要求 |
| **ICP 许可证** | 办理费 + 代理约 **¥1~3 万**（公司需注册资本 100 万+） | 40~60 工作日 | **仅经营性**业务需要（含广告/付费/会员）；非经营性可豁免 |

> ⚠️ 重要区分：**非经营性** APP 上架只需要 软著 + APP 备案；一旦涉及收费/广告/会员等**经营性**业务才需要 ICP 许可证。游戏含内购 → 通常按经营性准备。

### 2.4 内测 / 分发工具（免费为主）

| 工具 | 免费额度 | 说明 |
|---|---|---|
| **TestFlight** | 100 台内测设备、公开链接 1 万人 | iOS 官方内测 |
| **Google Play 内部测试** | 100 人 | Android 官方内测 |
| **蒲公英（PGYER）** | 免费版基础分发（有次数/数量限制） | 国内常用，本项目 CI 已接入（见 `.github/workflows/upload-pgyer.yml`） |
| **Firebase App Distribution** | 免费 | Android/iOS 内测，接入 CI 方便 |
| **GitHub Releases** | 免费 | 任意平台安装包直链 |

### 2.5 Web（Flutter Web）

| 方案 | 免费额度 | 说明 |
|---|---|---|
| **GitHub Pages** | 1GB 站点、100GB 流量/月、10 个站点/账号 | 免费 HTTPS + 自定义域名 |
| **Cloudflare Pages** | 无限静态请求、500 构建/月 | 全球 CDN，配 Workers 可做后端 |
| **Vercel / Netlify** | 免费额度充裕 | 一键 Git 部署 |
| 国内访问 | 海外免费托管国内访问不稳；要稳需**备案 + 大陆 CDN/OSS** | 备案免费但需域名+服务器 |

> 本项目：Flutter Web 产物 `build/web` 可直接部署到上述任意平台；无后端时纯静态，成本 ¥0。

### 2.6 macOS

| 方案 | 费用 | 说明 |
|---|---|---|
| **Mac App Store** | **$99/年**（开发者账号） | 沙盒 + 审核 |
| **公证（Notarization）** | **$99/年**（需要开发者账号） | 非商店分发 dmg 需公证才可无警告安装 |
| 自签名 dmg / zip | ¥0 | 用户需右键打开（Gatekeeper 警告） |
| GitHub Releases | ¥0 | 配合自签名或公证 |

### 2.7 Windows

| 方案 | 费用 | 说明 |
|---|---|---|
| **Microsoft Store** | 个人开发者注册 **$19 一次性** | 需 MSIX 打包 + 代码签名证书（EV 证书约 ¥2000+/年，OV 证书约 ¥800~1500/年，可选） |
| 免签 exe / zip | ¥0 | SmartScreen 警告（"未知发布者"），可接受 |
| GitHub Releases | ¥0 | 最简路径 |
| 安装器 | Inno Setup / NSIS（免费） | 生成正式安装包 |

### 2.8 Linux

| 方案 | 费用 | 说明 |
|---|---|---|
| **AppImage** | ¥0 | 单文件免安装，最常用 |
| **Flatpak**（Flathub） | ¥0 | 需要上架审核 |
| **Snap**（Snapcraft） | ¥0 | Canonical 托管 |
| 发行版仓库（deb/rpm） | ¥0 | 各发行版规则不同 |

### 2.9 Steam（可选）

- **Steam Direct**：**$100/款** 一次性（可回收门槛：销售额达 $1000 后退还）
- 适合独立游戏分发；Flutter 桌面版可用 Steamworks SDK，但集成成本较高。

---

## 三、免费 vs 付费总表

| 端 | 完全免费方案 | 付费方案 | 最低付费 |
|---|---|---|---|
| iOS | ❌（无开发者账号无法真机/上架） | Apple Developer + App Store | **$99/年** |
| Android 海外 | GitHub Releases 侧载 | Google Play | **$25** 一次性 |
| Android 国内 | 蒲公英内测 | 渠道上架（软著+备案） | **¥0~1000**（资质） |
| Web | GitHub Pages / CF Pages | 自定义域名（可选） | **¥0** |
| macOS | 自签名分发 | App Store / 公证 | **$99/年** |
| Windows | 免签 exe | Microsoft Store | **$19** 一次性 |
| Linux | AppImage / Flatpak / Snap | — | **¥0** |
| Steam | — | Steam Direct | **$100/款** |

---

## 四、推荐落地路径（结合 uniygopro 现状）

### 路径 A：个人开发者最小成本（~$25）
1. **Android（海外）**：$25 开 Google Play 账号 → AAB + 现有签名材料直接上架
2. **Android（国内）**：办软著（自办 ¥0/代理几百）→ APP 备案 → 上华为/小米等
3. **Web**：GitHub Pages / Cloudflare Pages 免费部署
4. **iOS/macOS**：暂缓（$99/年）或 TestFlight 内测（仍需账号）
5. **成本**：**$25 + 软著费用 + 备案服务器月费（可复用已有）**

### 路径 B：正式商业（推荐）
1. iOS + macOS：Apple Developer **$99/年**，TestFlight 内测 → 双端上架
2. Android：Google Play $25 + 国内主流渠道（软著 + 备案）
3. Web：Cloudflare Pages + 自定义域名（¥50~80/年）
4. Windows：Microsoft Store $19（或先 GitHub Releases 免签版）
5. Linux：AppImage + GitHub Releases
6. **年度成本**：**约 $120 + ¥100~1000（软著/域名）**

### 路径 C：游戏上架 Steam（额外）
- 若做桌面版独立发行：Steam Direct $100/款。

---

## 五、关键注意事项

1. **软著与备案周期长**：国内上架软著 30 工作日 + 备案 1~2 周，**提前 1~2 个月启动**。
2. **经营性 vs 非经营性**：游戏含内购/广告属于经营性，可能被要求 ICP 许可证（成本高），提前咨询渠道商务。
3. **iOS 内购分成**：游戏内购必须走 Apple IAP（30%/15% 抽成），需在定价中考虑。
4. **Google Play 新账号规则**：2026 起需 12 名测试者 14 天测试，预留时间。
5. **Flutter 各端构建**：iOS/macOS 需 macOS 环境（Xcode）；Windows 需 Windows；建议 CI 分平台构建（本项目已用 GitHub Actions）。
6. **签名安全**：keystore 与 key.properties 已入库（私有仓库约定），一旦泄露需重置密钥并重新签包。

---

## 六、参考资料

- Apple Developer Program 费用：https://developer.apple.com/programs/
- Google Play 开发者注册：https://support.google.com/googleplay/android-developer/answer/6112435
- 国内 APP 上架资质说明：https://zhuanlan.zhihu.com/p/31225123905
- 小米开放平台（软著/备案要求）：https://dev.mi.com/
- GitHub Pages 限制：https://docs.github.com/zh/pages/getting-started-with-github-pages/github-pages-limits
- Cloudflare Pages 定价：https://www.cloudflare.com/zh-cn/plans/developer-platform/
- 蒲公英内测分发：https://www.pgyer.com/
- Steam Direct：https://partner.steamgames.com/

> ⚠️ 渠道资质与费用政策会调整，正式办理前以各平台官方最新要求为准。
