apps/uniygopro/lib 页面域目录（参考 modules/duel_room1 的按域拆分）
apps/uniygopro/lib/create_room 建房页（匹配/好友/练习/自由四页签）+ 模式与房间模型 + MatchStore/MatchService
apps/uniygopro/lib/home 主页、比赛观看、设置弹层 + 观战服务
apps/uniygopro/lib/login 登录页 + MyCard 认证弹窗/门控
apps/uniygopro/lib/splash 开屏页
apps/uniygopro/lib/ui 四个页面共用的设计令牌、画布、交互件与音效
apps/uniygopro/lib/util SnackBar 等通用工具
apps/uniygopro/lib/config 路由与服务器配置
apps/uniygopro/lib/widgets 其他通用组件

## 启动三屏（开屏 → 登录 → 主页）

设计稿：Ardot 文件 744179416852082「uniygopro · 六屏界面（844×390）」的
01 开屏 / 02 登录 / 03 主页（含对战模式、比赛观看、设置弹窗）。

- 路由：`Routes.splash` → `Routes.login` → `Routes.home`（`/home`）；应用以 `/splash` 为初始路由，`/` 重定向到 `/home`。
- 旧版服务器列表页已移除；`/` 即主页。
- 设计令牌：`ui/duel_theme.dart`（颜色、字体回退链、字号）；
  画布与背景装饰：`ui/duel_canvas.dart`（844×390 设计坐标按可用空间铺满）；
  交互件与音效：`ui/duel_controls.dart` / `ui/duel_sound.dart`。
- 页面：`splash/`、`login/`、`home/`。
- 登录：`MyCardAccountApi.signIn`（account_mycard），「记住账号」只持久化用户名；
  游客可直接进入主页，竞技/休闲匹配会要求登录。
- 设置弹窗底部提供「退出账号」（仅登录态显示）：清除本地登录态并回到游客态，
  需要重新登录时点击左上玩家条。
- 「建房」页（`/create-room`，create_room/create_room_page.dart）：底部四页签 +
  左侧模式圆钮 + 中央匹配盘（外圈 24s 顺时针、内圈 18s 逆时针）。
  匹配页签直接调用 MyCard `/ygopro/match`，盘上显示等待秒数、可点击取消，
  成功后带参数进入决斗房间；主页匹配条的「开始匹配」会进入本页并自动开始。
  好友对战：左侧模式 + 规则设置（卡片允许/大师规则/初始 LP/手牌/抽卡/时限/禁限卡表/复选框）；
  408 环境规则由服务端锁定，同一位置改为只读的固定规则文案，不提供改动项；
  练习：对局设置（大师规则/初始 LP/不切洗）；自由房间：环境签 + 环境设置面板，中央盘创建房间。
  页面右上角「加入房间 · 扫码」挂在页壳上（四个页签都可用）：扫好友邀请二维码或粘贴邀码进房，
  移动端取景，桌面/Web 走粘贴。
- 「比赛观看」为页面内弹层（home/watch_sheet.dart，数据来自 SpectateService）；
  「设置」为页面内弹层（画面/音效/对局/账号，账号页可退出登录）。
  对局页覆盖旧版全部选项：决斗场地 2D/3D、连锁1 动画、自动怪兽/魔陷位、
  观战回放模式与速度、2D/3D 场景预览（Web 隐藏 GPU 相关项）。
- 底部页签：比赛观看、卡组、战绩、商店、活动、鉴赏（怪兽动画 / card-live）。
  公告、精选卡、DP/GEM、延迟为展示位常量（`home/home_models.dart`），接服务端时替换数据源。
- 字体：设计稿使用 Noto Serif SC / Noto Sans SC / Inter，仓库未内置这些字体，
  通过系统字体回退链近似；缺少对应衬线字体的平台（如 Web）会落到无衬线体。