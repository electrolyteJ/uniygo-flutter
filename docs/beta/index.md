# uniygopro 版本列表

本页面由 CI 自动生成，列出当前可下载的所有版本及其资产，包括正式发布与内测版本。
页面会随每次发布自动刷新。

!!! info "说明"
    - 所有包均由 GitHub Actions 自动构建并发布到 GitHub Releases。
    - 正式版本：通过 tag (`v*`) 触发，发布到各应用商店 + GitHub Release。
    - 内测版本：通过 beta-release workflow 触发，发布到蒲公英 / Firebase App Distribution + GitHub Release（预发布）。
    - iOS 包为未签名 IPA，需自备 Apple 开发者证书侧载安装。
    - macOS 内测包未公证，首次打开需在「系统设置 → 隐私与安全性」放行；正式包已公证。

<!-- BETA_RELEASE_LIST_START -->
<!-- 由 deploy-mkdocs.yml workflow 注入，请勿手动编辑此区块 -->
## 暂无版本

尚未发布任何版本，请稍后访问。
<!-- BETA_RELEASE_LIST_END -->

---

## 平台与文件说明

| 平台 | 文件 | 说明 |
|---|---|---|
| Android | `*.apk` | 通用 APK，国内商店需各自专用包 |
| Android (AAB) | `*.aab` | Google Play 上传用 |
| iOS / iPadOS | `*.ipa` | 正式版已签名可直装；内测版未签名需自签 |
| Windows | `*-windows-x86_64.zip` | Windows 10/11 x64 |
| Windows (MSIX) | `*.msix` | Microsoft Store 安装包（需签名） |
| Linux | `*-linux-x86_64.tar.gz` | x64 通用包 |
| Linux (deb) | `*.deb` | Debian / Ubuntu 系 |
| Linux (rpm) | `*.rpm` | Fedora / RHEL 系 |
| Linux (snap) | `*.snap` | Snap Store 安装包 |
| macOS | `*.dmg` / `*.tar.gz` | 正式版已公证；内测版未公证 |

## 渠道说明

| 渠道 | 触发方式 | Android | iOS / iPadOS | 桌面端 | Web |
|---|---|---|---|---|---|
| 正式 | tag (`v*`) | Google Play + 国内 8 家商店 + GitHub Release | App Store + GitHub Release | 各商店 + GitHub Release | Cloudflare Pages |
| 内测 | 手动 beta-release | 蒲公英（国内）/ Firebase（海外）+ GitHub Release | 蒲公英 / Firebase + GitHub Release | GitHub Release（预发布） | — |

国内 Android 商店（华为 / 小米 / OPPO / vivo / 荣耀 / 应用宝 / 360 / 百度）由于无统一开放上传 API，需人工上传到各开放平台后台。
