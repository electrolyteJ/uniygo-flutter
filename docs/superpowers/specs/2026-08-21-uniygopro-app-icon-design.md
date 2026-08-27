# UniYGO Pro 应用图标设计

日期：2026-08-21 · 状态：已确认（用户经可视化对比两轮选定）

## 方向

- 核心意象：**对决场地全景**（B3），落地为「碰撞对角」构图（B）
- 变体：**B2 标准版** —— 青(#00F0FF)/琥珀(#FFB300) 双色对阵 + 中央白色闪电 + 冲击光晕

## 设计定稿（对应 icon-direction-b-v2 标准版）

- 1024×1024 全出血画布，深海军蓝底（#101A30 → #060910 纵向渐变）
- 中央径向冲击光晕（白→青，透明衰减）
- 左上场地板块：圆角矩形旋转 -18°，青色描边 + 格线，一块发光格；深色填充 #0E1830
- 右下场地板块：镜像琥珀色 #FFB300，填充 #1C150A
- 中央闪电：白色 #F2FBFF + 淡青描边，折线 polygon
- 小尺寸策略：48/32px 档加粗描边、省略格线（生成时按尺寸分级渲染）

## 交付物

| 平台 | 内容 |
|---|---|
| iOS | AppIcon.appiconset 18 尺寸全量（全出血无 alpha） |
| macOS | AppIcon.appiconset 10 尺寸全量 |
| Android | 旧版 mipmap 5 密度 + 自适应图标（foreground 分层 + background 纯色 #0B1120 + anydpi-v26 xml） |
| Web | Icon-192/512 + maskable（内容缩至 70% 安全区）+ favicon 48 |
| Windows | app_icon.ico（16/24/32/48/64/128/256 多尺寸） |
| 源文件 | tools/app_icon/icon_master.png（2048）+ 生成脚本 tools/app_icon/generate_app_icon.py |

## 实现方式

PIL 程序化渲染（无 SVG 渲染器依赖）：2048 超采样 → 各尺寸降采样；
发光 = 独立图层 GaussianBlur 合成。脚本可重复运行（幂等覆盖）。

## 验证

- 生成后逐平台核对文件清单与 Contents.json 一致
- 目视检查 512/192/48 三档渲染效果（read_image）
- 不提交构建产物目录之外的多余文件；.superpowers/ 已入 gitignore
