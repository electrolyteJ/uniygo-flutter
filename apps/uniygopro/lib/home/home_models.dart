/// 主页的展示位数据（公告 / 精选卡面）。
///
/// 对战模式条目在 mode_models.dart；这里只保留主页左栏与中央面板的常量，
/// 后续接服务端时替换数据源即可。
library;

/// 精选卡面（主页主视觉面板）。
class HomeFeature {
  const HomeFeature({required this.name, required this.subtitle});

  final String name;
  final String subtitle;
}

const HomeFeature kHomeFeature = HomeFeature(
  name: '青眼白龙',
  subtitle: '混沌龙 · 光/龙',
);

/// 公告大图（左侧首条）。
class HomeHighlight {
  const HomeHighlight({
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final String title;
  final String subtitle;
  final String action;
}

const HomeHighlight kHomeHighlight = HomeHighlight(
  title: '2026.01 新禁卡表已生效',
  subtitle: '查看被限制的 12 张卡与适用赛制',
  action: '查看卡表 ›',
);

/// 公告列表（左侧列表卡）。
const List<String> kHomeAnnouncements = [
  '· 2026.01 禁卡表已生效 · 适用 OCG',
  '· S12 赛季结算倒计时 6 天',
  '· 新手引导上线 · 3 分钟上手',
];
