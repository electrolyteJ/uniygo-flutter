import 'package:flutter/material.dart';

import '../../theme/cyber_side_tokens.dart';

/// 换备页顶条（设计稿 531:2 / 531:147 / 531:245 的顶条同构）。
///
/// 三个画板的顶条只有几处随状态变：SIDE 徽标的颜色（编辑=青、已提交=青绿）、
/// 标题与副标文字、右侧区域（编辑时给倒计时 / 等待时给状态提示）。
///
/// 中段是 match 比分：`GAME n / 3` + `我方名 1 — 0 对手名`。比分来自
/// [DuelRoomState.myMatchWins] / [DuelRoomState.opponentMatchWins]，由
/// 房间页按局累计（协议只给单局 MSG_WIN，不给本场汇总，见 biz 侧注释）。
class SideTopBar extends StatelessWidget {
  const SideTopBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.gameLabel,
    this.myName,
    this.opponentName,
    this.myScore,
    this.opponentScore,
    this.showScore = true,
    this.timerText,
    this.timerCritical = false,
    this.timerHint = '换备计时',
    this.timerSubHint = '本地计时 · 仅供参考',
    this.alertLabel,
    this.alertValue,
  });

  final String title;
  final String subtitle;

  /// SIDE 徽标、GAME 标与描边色。
  final Color accent;

  /// `GAME 2 / 3`；null 时不显示中段。
  final String? gameLabel;

  final String? myName;
  final String? opponentName;

  /// 我方 / 对手已赢局数。二者都为 null 或 [showScore] 为 false 时不画比分
  /// （观战局没有立场，比分对他们无意义）。
  final int? myScore;
  final int? opponentScore;
  final bool showScore;

  /// `01:33`；null 时右侧改为显示 [alertLabel] / [alertValue]。
  final String? timerText;

  /// 剩余时间不足时倒计时转品红（设计稿 531:147 的 `00:41`）。
  final bool timerCritical;

  final String timerHint;
  final String timerSubHint;

  /// 无倒计时时的右侧提示（设计稿 531:245：比分本机统计 / GAME 3）。
  final String? alertLabel;
  final String? alertValue;

  @override
  Widget build(BuildContext context) {
    final bracket = SideBracketLabel(text: 'SIDE', color: accent);
    final hasRight = timerText != null || alertValue != null;

    return Container(
      height: CyberSideTokens.topBarHeight,
      decoration: const BoxDecoration(
        color: CyberSideTokens.barBg,
        border: Border(
          bottom: BorderSide(color: CyberSideTokens.rule, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: CyberSideTokens.pagePadding),
      // ── 布局分配策略 ──
      //
      // 三段固定 + 一段弹性，**不让 Row 按固有宽度自己摸**：
      //
      //   徽标(58) + 12 + [标题 弹性] + [比分 固定] + [右段 固定]
      //
      // 原来的写法（标题 Expanded(flex:3) + 比分 Expanded(flex:5) + 右段
      // Flexible）踩过两个坑，都是真机/窄屏才暴露：
      //
      // 1. **右段做成柔性，「够不够用」就由 Row 事后裁定**，而内部倒计时框
      //    有最小尺寸。分到 32px 时它缩不下去，直接溢出（线上那条 12px）。
      // 2. **比分格被 flex 均分压垮**：390 宽下只剩 73px，`kaiba 1 — 0
      //    muto·游戏` 放不下；768 宽时反而也不够——因为右段先按固有宽度
      //    占位，剩下的才轮到两个 Expanded 分。
      //
      // 现在：比分与右段都用**明确宽度**（SizedBox 直接给定），标题吃剩下
      // 的全部。空间不够时先压标题（它本身带 ellipsis），不压比分/计时
      // 这些不可替代的信息。宽度数值按档给，见下方 wide 分支。写死像素
      // 曾被 0.25px 的浮点零头反咬，所以窄屏档用**比例**而非绝对值。
      child: LayoutBuilder(
        builder: (context, outer) {
          final total = outer.maxWidth;
          // 左端固定开销：徽标 58 + 间隙 12。
          const leftFixed = 58.0 + 12.0;
          // 右段与比分的宽度：宽屏给**确定像素**（够放完整内容），
          // 窄屏给**比例**（天然不会超出总宽）。
          //
          // 窄屏为什么用比例：写死像素时 390 宽下 58+12+76+84 正好把可用
          // 宽度吃光，标题被压到 0 仍差 0.25px（浮点舍入）→ 溢出；而且不同
          // DPI / 系统字号下这个零头还会变。
          final available = (total - leftFixed).clamp(0.0, double.infinity);
          final hasScoreBlock = gameLabel != null;
          // 「宽屏」阈值定在 480：常见手机竖屏是 360~430，横屏/平板 ≥ 640。
          // 定得太高（曾用 520）会让 390 的手机也走窄屏分支——明明放得下
          // 名字和说明，却被降级，属于修复溢出时引入的功能回退。
          final wide = total >= 480;
          // 比分：宽屏 200（名字 + 比分），窄屏按比例（纯比分）。
          final scoreWidth = !hasScoreBlock
              ? 0.0
              : (wide ? 200.0 : available * 0.34);
          // 右段：宽屏 172（计时框 + 两行说明），窄屏按比例。
          final rightWidth = !hasRight ? 0.0 : (wide ? 172.0 : available * 0.32);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 徽标与标题在垂直方向有 6px 的错位（设计稿徽标 y=16，标题 y=10）。
              Padding(padding: const EdgeInsets.only(top: 16), child: bracket),
              const SizedBox(width: 12),
              // 标题：吃掉剩余全部宽度，最窄可缩到 0（文字 ellipsis）。
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SideText(
                        title,
                        size: CyberSideTokens.fsTitle,
                        color: CyberSideTokens.textPrimary,
                        weight: FontWeight.w700,
                      ),
                      const SizedBox(height: 3),
                      SideText(
                        subtitle,
                        size: CyberSideTokens.fsLabel,
                        color: CyberSideTokens.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              if (scoreWidth > 0)
                SizedBox(width: scoreWidth, child: _gameBlock()),
              if (hasRight) SizedBox(width: rightWidth, child: _rightBlock()),
            ],
          );
        },
      ),
    );
  }
  /// 中段：`GAME 2 / 3` 一行 + `我方 1 — 0 对手` 一行。
  ///
  /// 设计稿（531:2）的比分是等宽大字：名字在两侧小字、数字加粗放大、
  /// 中间用一道横线分隔。比分数字的颜色跟随 [accent]，与顶条状态一致。
  Widget _gameBlock() {
    final hasScore =
        showScore && myScore != null && opponentScore != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        if (gameLabel != null)
          SideText(
            gameLabel!,
            size: CyberSideTokens.fsLabel,
            color: accent,
            weight: FontWeight.w500,
          ),
        const SizedBox(height: 2),
        if (hasScore)
          // 比分行的开销是**固定**的：两个 15px 等宽数字 + 10px 虚线 +
          // 两侧各 6px 内距 ≈ 50px；再加两个名字（各留 24px 才不显得被切）
          // 合计 ≈ 100px。阈值取 96 而不是 110——390 宽的手机上这格实际
          // 只有约 96px，定 110 会把明明放得下名字的机型也降级掉。
          //   ≥ 96px：名字 + 比分（完整设计稿样式）
          //   < 96px：只留比分（`1 — 0`），名字让位
          // 比分是语义主体，名字是陪衬——砍名字不砍比分。
          LayoutBuilder(
            builder: (context, constraints) {
              final showNames = constraints.maxWidth >= 96;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showNames && myName != null) ...[
                    Flexible(
                      child: SideText(
                        myName!,
                        size: CyberSideTokens.fsSmall,
                        color: CyberSideTokens.textSecondary,
                        align: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  SideText(
                    '$myScore',
                    size: 15,
                    color: accent,
                    weight: FontWeight.w700,
                    mono: true,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Container(
                      width: 10,
                      height: 1,
                      color: CyberSideTokens.textRule,
                    ),
                  ),
                  SideText(
                    '$opponentScore',
                    size: 15,
                    color: CyberSideTokens.textRule,
                    weight: FontWeight.w700,
                    mono: true,
                  ),
                  if (showNames && opponentName != null) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: SideText(
                        opponentName!,
                        size: CyberSideTokens.fsSmall,
                        color: CyberSideTokens.textSecondary,
                      ),
                    ),
                  ],
                ],
              );
            },
          )
        else
          // 无比分（观战等）：退回「名字 vs 名字」，保持中段不空。
          //
          // 两个名字都必须 Flexible——和上面对比分行同样的道理：这格宽度
          // 是外部给定的（可能只有几十像素），两个按固有宽度排的文本
          // 加起来超过格子宽度就直接溢出（实测 1.6px，就是这条）。
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (myName != null)
                Flexible(
                  child: SideText(
                    myName!,
                    size: CyberSideTokens.fsMicro,
                    color: CyberSideTokens.textSecondary,
                    align: TextAlign.right,
                  ),
                ),
              if (myName != null && opponentName != null)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: SideText(
                    'vs',
                    size: CyberSideTokens.fsMicro,
                    color: CyberSideTokens.textRule,
                  ),
                ),
              if (opponentName != null)
                Flexible(
                  child: SideText(
                    opponentName!,
                    size: CyberSideTokens.fsMicro,
                    color: CyberSideTokens.textSecondary,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  /// 右段：有计时显示计时框，否则显示比分统计提示。
  Widget _rightBlock() {
    if (timerText == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          if (alertLabel != null)
            SideText(
              alertLabel!,
              size: CyberSideTokens.fsBody,
              color: CyberSideTokens.danger,
              align: TextAlign.right,
            ),
          const SizedBox(height: 2),
          if (alertValue != null)
            SideText(
              alertValue!,
              size: CyberSideTokens.fsLabel,
              color: CyberSideTokens.textPrimary,
              weight: FontWeight.w500,
              align: TextAlign.right,
            ),
        ],
      );
    }
    final timerColor = timerCritical
        ? CyberSideTokens.danger
        : CyberSideTokens.acid;
    // 用 LayoutBuilder 明确感知本段拿到的宽度，按空间分三级降级：
    //
    //   ① ≥ 110px：完整（计时框 + 两行说明）
    //   ② ≥  62px：只留计时框（说明文字全部让位）
    //   ③ <  62px：整段隐藏
    //
    // 计时框本身要 padding 8+8 与 13px 字号的 "05:32"（约 38px 文字），
    // 合计约 54px 才不被裁，所以 62 是隐藏线。说明文字的阈值取 110 而不是
    // 130：390 宽的手机上这格约 91px（够放「换备计时」），定 130 会把说明
    // 无谓地砍掉。
    //
    // 宁可少显示说明文字，也不要黄黑条纹 + 异常日志（线上报的就是这个）。
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth < 62) return const SizedBox.shrink();
        final showHints = maxWidth >= 110;
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 计时框：用 Flexible 包住，极端情况下允许被压到比文字更窄
            // （SideText 自带 ellipsis，会截断而不是崩）。
            Flexible(
              child: Container(
                height: 28,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: CyberSideTokens.barBg,
                  border: Border.all(color: CyberSideTokens.controlLine),
                  borderRadius: BorderRadius.circular(CyberSideTokens.radius),
                ),
                child: SideText(
                  timerText!,
                  size: CyberSideTokens.fsTimer,
                  color: timerColor,
                  weight: FontWeight.w700,
                  mono: true,
                ),
              ),
            ),
            if (showHints) ...[
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 18),
                    SideText(
                      timerHint,
                      size: CyberSideTokens.fsBody,
                      color: CyberSideTokens.textSecondary,
                    ),
                    const SizedBox(height: 2),
                    SideText(
                      timerSubHint,
                      size: CyberSideTokens.fsSmall,
                      color: timerCritical
                          ? CyberSideTokens.danger
                          : CyberSideTokens.textDim,
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 描边方块徽标（SIDE / IN / OUT 都用它）。
class SideBracketLabel extends StatelessWidget {
  const SideBracketLabel({
    super.key,
    required this.text,
    required this.color,
    this.width = 58,
    this.height = 20,
  });

  final String text;
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(border: Border.all(color: color)),
      child: SideText(
        text,
        size: 8,
        color: color,
        weight: FontWeight.w500,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// 换备界面统一文字样式。
///
/// 设计稿字号普遍在 6~13 之间且多数带字距，直接写 `TextStyle` 会让
/// 每个组件重复 5 个属性，这里收敛成一个构造器。[mono] 用于比分与读数。
class SideText extends StatelessWidget {
  const SideText(
    this.text, {
    super.key,
    required this.size,
    required this.color,
    this.weight = FontWeight.w400,
    this.mono = false,
    this.letterSpacing,
    this.maxLines = 1,
    this.align,
  });

  final String text;
  final double size;
  final Color color;
  final FontWeight weight;
  final bool mono;
  final double? letterSpacing;
  final int maxLines;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
      style: TextStyle(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: 1.15,
        fontFamily: mono ? CyberSideTokens.monoFamily : null,
      ),
    );
  }
}
