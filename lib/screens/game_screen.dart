import 'dart:async';

import 'package:flutter/material.dart';

import '../ad_manager.dart';
import '../audio_manager.dart';
import '../game_engine.dart';
import '../localization.dart';
import '../path_finder.dart';
import '../sound_button.dart';
import '../theme.dart';
import '../tile_art.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  final GameEngine _engine = GameEngine();
  final AdManager _ads = AdManager();
  final LocaleController _loc = LocaleController.instance;

  Timer? _clock;
  late final AnimationController _lineCtrl;
  late final AnimationController _hintCtrl;

  List<Coord>? _activeLine;
  bool _busy = false; // an ad/dialog is on screen

  @override
  void initState() {
    super.initState();
    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() => _activeLine = null);
        }
      });
    _hintCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _engine.newGame();
    _startClock();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _lineCtrl.dispose();
    _hintCtrl.dispose();
    _engine.dispose();
    super.dispose();
  }

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_busy || !_engine.isRunning) return;
      final timeUp = _engine.tickSecond();
      if (timeUp) _handleTimeUp();
    });
  }

  // --- Tile interaction ---------------------------------------------------

  Future<void> _onTileTap(int r, int c) async {
    if (_busy || !_engine.isRunning) return;
    final result = _engine.select(r, c);
    if (result.type == MoveType.matched && result.path != null) {
      AudioManager.instance.playMatch();
      setState(() => _activeLine = result.path!.points);
      _lineCtrl.forward(from: 0);
      await _afterMatch();
    } else if (result.type == MoveType.firstSelection ||
        result.type == MoveType.switchSelection ||
        result.type == MoveType.invalid) {
      // Mistakes are free — just a soft tap sound.
      AudioManager.instance.playSelect();
    }
  }

  Future<void> _afterMatch() async {
    if (_engine.isComplete) {
      _engine.stop();
      await _showEndDialog(win: true);
      return;
    }
    if (!_engine.hasMoves()) {
      _showShuffleNotice();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      _engine.shuffleBoard();
    }
  }

  void _showShuffleNotice() {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.surfaceHigh,
          content: Text(
            _loc.t('shuffling'),
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          duration: const Duration(milliseconds: 1400),
        ),
      );
  }

  // --- Reward loops -------------------------------------------------------

  Future<void> _handleTimeUp() async {
    if (_busy) return;
    _busy = true;
    _engine.pause();
    final watched =
        await _ads.offerRewardedVideo(context, AdRewardKind.extraTime);
    if (!mounted) return;
    if (watched) {
      _engine.addTime(60);
      _engine.resume();
      _busy = false;
    } else {
      _busy = false;
      await _showEndDialog(win: false);
    }
  }

  Future<void> _useHint() async {
    if (_busy || !_engine.isRunning) return;
    _busy = true;
    _engine.pause();
    final watched = await _ads.offerRewardedVideo(context, AdRewardKind.hint);
    if (!mounted) return;
    _engine.resume();
    _busy = false;
    if (watched) {
      // The highlighted pair persists until the player taps a tile
      // (GameEngine.select clears the hint on the next interaction).
      _engine.revealHint();
    }
  }

  // --- End states ---------------------------------------------------------

  Future<void> _showEndDialog({required bool win}) async {
    _busy = true;
    _clock?.cancel();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AnimatedBuilder(
        animation: _loc,
        builder: (ctx, _) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            _loc.t(win ? 'youWinTitle' : 'gameOverTitle'),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            _loc.tp(win ? 'youWinBody' : 'gameOverBody', {'n': _engine.score}),
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: Text(
                _loc.t('mainMenu'),
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  // Winning advances to the next (harder) level and keeps the
                  // score; losing restarts from level 1.
                  if (win) {
                    _engine.nextLevel();
                  } else {
                    _engine.newGame();
                  }
                  _activeLine = null;
                });
                _busy = false;
                _startClock();
              },
              child: Text(_loc.t(win ? 'nextLevel' : 'playAgain')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pauseGame() async {
    if (_busy || !_engine.isRunning) return;
    _busy = true;
    _engine.pause(); // freezes the countdown (clock is gated on _busy too)
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AnimatedBuilder(
        animation: _loc,
        builder: (ctx, _) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.pause_circle_outline_rounded,
                  color: AppTheme.accent),
              const SizedBox(width: 10),
              Text(
                _loc.t('paused'),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Text(
            '${_loc.t('time')}: ${_engine.formattedTime}   •   '
            '${_loc.t('level')} ${_engine.level}',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(); // leave to main menu
              },
              child: Text(
                _loc.t('mainMenu'),
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(_loc.t('resume')),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return; // chose Main Menu → screen already popped
    _busy = false;
    _engine.resume();
  }

  Future<void> _confirmQuit() async {
    _busy = true;
    _engine.pause();
    final quit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(_loc.t('quitTitle'),
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(_loc.t('quitBody'),
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(_loc.t('no'),
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(_loc.t('yes')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (quit == true) {
      Navigator.of(context).pop();
    } else {
      _busy = false;
      _engine.resume();
    }
  }

  // --- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.backgroundAlt, AppTheme.background],
            ),
          ),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: Listenable.merge([_engine, _loc]),
              builder: (context, _) => LayoutBuilder(
                builder: (context, c) {
                  // Landscape → controls in a side panel so the board can use
                  // the full height and the tiles are as large as possible.
                  final landscape = c.maxWidth > c.maxHeight;
                  if (landscape) {
                    return Row(
                      children: [
                        Expanded(child: _buildBoard()),
                        _buildSidePanel(c.maxWidth),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _buildHud(),
                      Expanded(child: _buildBoard()),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHud() {
    final low = _engine.secondsRemaining <= 15;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compact single-row status bar (landscape friendly).
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _confirmQuit,
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(width: 4),
              _PauseButton(onTap: _pauseGame, label: _loc.t('pause')),
              const SizedBox(width: 8),
              _pill(Icons.layers_rounded, '${_engine.level}',
                  label: _loc.t('level')),
              const SizedBox(width: 8),
              _pill(Icons.star_rounded, '${_engine.score}',
                  label: _loc.t('score')),
              const SizedBox(width: 8),
              _pill(
                Icons.timer_outlined,
                _engine.formattedTime,
                highlight: low,
              ),
              const Spacer(),
              const SoundToggleButton(),
            ],
          ),
          const SizedBox(height: 6),
          // Time bar + Hint together on one thin row.
          Row(
            children: [
              Expanded(
                child: _TimeBar(progress: _engine.timeProgress, low: low),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentSoft,
                  foregroundColor: Colors.black87,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _useHint,
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                label: Text(
                  _loc.t('hint'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Vertical control/status panel shown in landscape.
  Widget _buildSidePanel(double screenWidth) {
    final low = _engine.secondsRemaining <= 15;
    final panelW = screenWidth * 0.24 < 150
        ? 150.0
        : (screenWidth * 0.24 > 240 ? 240.0 : screenWidth * 0.24);
    return Container(
      width: panelW,
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _confirmQuit,
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppTheme.textPrimary),
              ),
              const Spacer(),
              // Emphasized pause control.
              _PauseButton(onTap: _pauseGame, label: _loc.t('pause')),
            ],
          ),
          const SizedBox(height: 8),
          _pill(Icons.layers_rounded, '${_engine.level}',
              label: _loc.t('level'), stretch: true),
          const SizedBox(height: 6),
          _pill(Icons.star_rounded, '${_engine.score}',
              label: _loc.t('score'), stretch: true),
          const SizedBox(height: 6),
          _pill(Icons.timer_outlined, _engine.formattedTime,
              label: _loc.t('time'), highlight: low, stretch: true),
          const SizedBox(height: 6),
          _TimeBar(progress: _engine.timeProgress, low: low),
          const Spacer(),
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentSoft,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              onPressed: _useHint,
              icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
              label: Text(_loc.t('hint')),
            ),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: SoundToggleButton(),
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String value,
      {String? label, bool highlight = false, bool stretch = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: stretch ? 11 : 7),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? AppTheme.accent : AppTheme.surfaceHigh,
          width: highlight ? 1.6 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon,
              size: stretch ? 18 : 16,
              color: highlight ? AppTheme.accent : AppTheme.textSecondary),
          const SizedBox(width: 6),
          if (label != null)
            Text(
              '$label ',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: stretch ? 13 : 12,
              ),
            ),
          if (stretch) const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: highlight ? AppTheme.accent : AppTheme.textPrimary,
              fontSize: stretch ? 19 : 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 4, 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          // Reserve a small margin on each side so connection lines can still
          // travel around the border, while keeping the tiles as large as
          // possible.
          final cell = (w / (_engine.cols + 0.5))
              .clamp(0.0, h / (_engine.rows + 0.5));
          final gridW = cell * _engine.cols;
          final gridH = cell * _engine.rows;
          final marginX = (w - gridW) / 2;
          final marginY = (h - gridH) / 2;

          final tiles = <Widget>[];
          for (var r = 0; r < _engine.rows; r++) {
            for (var c = 0; c < _engine.cols; c++) {
              final id = _engine.tileAt(r, c);
              if (id == PathFinder.empty) continue;
              final selected = _engine.selected?.row == r &&
                  _engine.selected?.col == c;
              final hinted = _engine.isHinted(r, c);
              tiles.add(Positioned(
                left: marginX + c * cell,
                top: marginY + r * cell,
                width: cell,
                height: cell,
                child: GestureDetector(
                  onTap: () => _onTileTap(r, c),
                  child: _TileView(
                    tileId: id,
                    state: selected
                        ? TileVisualState.selected
                        : hinted
                            ? TileVisualState.hint
                            : TileVisualState.normal,
                    hintCtrl: _hintCtrl,
                  ),
                ),
              ));
            }
          }

          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.background.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.surfaceHigh.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              ...tiles,
              if (_activeLine != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _lineCtrl,
                      builder: (context, _) => CustomPaint(
                        painter: ConnectionPainter(
                          points: _activeLine!,
                          cell: cell,
                          marginX: marginX,
                          marginY: marginY,
                          progress: _lineCtrl.value,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

}

class _TileView extends StatelessWidget {
  const _TileView({
    required this.tileId,
    required this.state,
    required this.hintCtrl,
  });

  final int tileId;
  final TileVisualState state;
  final Animation<double> hintCtrl;

  @override
  Widget build(BuildContext context) {
    if (state == TileVisualState.hint) {
      return AnimatedBuilder(
        animation: hintCtrl,
        builder: (context, _) => CustomPaint(
          painter: TilePainter(
            tileId: tileId,
            state: state,
            glow: hintCtrl.value,
          ),
        ),
      );
    }
    return CustomPaint(
      painter: TilePainter(tileId: tileId, state: state),
    );
  }
}

/// Horizontal time gauge (slider-style) so remaining time is obvious at a
/// glance. Fills from full down to empty and shifts colour as time runs low.
class _TimeBar extends StatelessWidget {
  const _TimeBar({required this.progress, required this.low});

  final double progress;
  final bool low;

  Color get _color {
    if (progress <= 0.2) return const Color(0xFFB5654B); // muted red
    if (progress <= 0.45) return AppTheme.accent; // amber
    return AppTheme.accentSoft; // muted sage
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: progress, end: progress),
      duration: const Duration(milliseconds: 900),
      curve: Curves.linear,
      builder: (context, value, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            return Container(
              height: 14,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.surfaceHigh),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: (w * value).clamp(0.0, w),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_color.withValues(alpha: 0.85), _color],
                          ),
                          boxShadow: low
                              ? [
                                  BoxShadow(
                                    color: _color.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      LocaleController.instance.t('time'),
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Emphasized pause control (amber pill) so it clearly stands out.
class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.accent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pause_rounded, color: Colors.black87, size: 18),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws the connecting polyline between two matched tiles with a grow + fade.
class ConnectionPainter extends CustomPainter {
  ConnectionPainter({
    required this.points,
    required this.cell,
    required this.marginX,
    required this.marginY,
    required this.progress,
  });

  final List<Coord> points;
  final double cell;
  final double marginX;
  final double marginY;
  final double progress;

  Offset _center(Coord p) => Offset(
        marginX + (p.col + 0.5) * cell,
        marginY + (p.row + 0.5) * cell,
      );

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final full = Path()..moveTo(_center(points.first).dx, _center(points.first).dy);
    for (var i = 1; i < points.length; i++) {
      final o = _center(points[i]);
      full.lineTo(o.dx, o.dy);
    }

    // Grow the line for the first 60% then fade it out.
    final grow = (progress / 0.6).clamp(0.0, 1.0);
    final fade = progress <= 0.6 ? 1.0 : (1 - (progress - 0.6) / 0.4);

    final metrics = full.computeMetrics().toList();
    final drawn = Path();
    for (final m in metrics) {
      drawn.addPath(m.extractPath(0, m.length * grow), Offset.zero);
    }

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.22
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppTheme.accent.withValues(alpha: 0.25 * fade)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppTheme.accent.withValues(alpha: fade);

    canvas.drawPath(drawn, glow);
    canvas.drawPath(drawn, line);

    for (final p in [points.first, points.last]) {
      canvas.drawCircle(
        _center(p),
        cell * 0.12,
        Paint()..color = AppTheme.accent.withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ConnectionPainter old) =>
      old.progress != progress || old.points != points;
}
