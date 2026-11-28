import 'dart:async';

import 'package:biz/ygo_sound_service.dart';

import '../../constants.dart';

/// 入场演出与对局开场的音频编排。
///
/// 为什么要单独一层，而不是在页面 `initState` / `dispose` 里各调一次
/// [YgoSoundService]：
///
/// 1. **生命周期跨页**。加载页会被 `_introDone` 换成一棵空子树，但声音
///    要往后延伸到场地页（入场曲还在播），页面级 initState / dispose
///    抓不住这个时间窗。
/// 2. **谁负责停**必须唯一。多个页面各自「进入就播、离开就停」会互相
///    打断：加载页 dispose 停掉音乐，场地页刚挂上还没来得及播，中间就
///    露出一段空白。
///
/// 所以由**房间页**持有一个实例，页面只负责告知阶段：
///
/// ```text
/// 加载页挂上        ──► startAmbient()  氛围曲循环
/// 相位切到 vs       ──► playEnter()     入场曲（替换氛围曲）
/// 演出播完 / 跳过   ──► finish()        淡出收尾，交给对局音效
/// 退出房间          ──► dispose()       立即停止
/// ```
///
/// 关于「叠加」的取舍：本意是氛围曲做底、入场曲叠在上面，但
/// [YgoSoundService] 只维护**一个** BGM 播放器（这是刻意的，见那边注释
/// 里对原生实例泄漏的说明）。要用两个播放器做真正的交叉淡化，得为 BGM
/// 再开一条声道并在退出时保证回收；当前阶段不值得，所以入场曲直接
/// **替换**氛围曲，音色上两段都建立在同一个低音持续音上，切换不突兀。
class DuelIntroAudio {
  DuelIntroAudio(this._sound);

  final YgoSoundService _sound;

  /// 是否已经触发过入场曲，避免时间轴抖动导致重复播放。
  bool _enterStarted = false;

  /// 是否已收尾（演出播完 / 跳过）。收尾后不再响应启动类调用。
  bool _finished = false;

  /// 是否已销毁（房间页 dispose），之后不再动播放器。
  bool _disposed = false;

  /// 是否已触发入场曲（测试观测用）。
  bool get enterStarted => _enterStarted;

  /// 是否已收尾（测试观测用）。
  bool get finished => _finished;

  /// 开始氛围底乐（加载页出现即调用）。
  ///
  /// 幂等：已经播过由 [YgoSoundService.playBgm] 的同曲判重挡掉，热重载
  /// 或页面重建不会把音乐从头打断。
  void startAmbient() {
    if (_disposed || _finished) return;
    unawaited(_sound.playBgm(DuelBgm.fieldAmbient, loop: true, volume: 0.5));
  }

  /// 播入场曲（相位切到 `vs` 时调用）。只触发一次。
  ///
  /// `loop: false`：这是一段 4.2 秒的过场，播完即止。若循环，玩家整个
  /// 对局都会听着同一段冲击音。
  ///
  /// 不在此处 stop 氛围曲：`play` 本身就会接管播放器，多停一次反而
  /// 可能把播放器留在停止态（异步竞态下 play 早于 stop 落地）。
  void playEnter() {
    if (_disposed || _finished || _enterStarted) return;
    _enterStarted = true;
    unawaited(_sound.playBgm(DuelBgm.duelEnter, loop: false, volume: 0.8));
  }

  /// 演出结束（播完或跳过）：把余下的音乐淡出，交给对局音效接场。
  ///
  /// 用淡出而不是硬切：入场曲此时通常还剩 1~1.5 秒，直接 stop 会留一个
  /// 突兀的断口。
  void finish() {
    if (_disposed || _finished) return;
    _finished = true;
    unawaited(_sound.fadeOutBgm());
  }

  /// 立即停止全部音乐（音频不可用 / 需要静默的场景）。
  void stopAll() {
    if (_disposed) return;
    _finished = true;
    unawaited(_sound.stopBgm());
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_sound.stopBgm());
  }
}
