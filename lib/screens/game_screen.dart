import 'dart:async';

import 'package:flutter/material.dart';

import '../ad_manager.dart';
import '../game_engine.dart';
import '../localization.dart';
import '../path_finder.dart';
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
      setState(() => _activeLine = result.path!.points);
      _lineCtrl.forward(from: 0);
      await _afterMatch();
    } else if (result.type == MoveType.invalid) {
      if (_engine.lives <= 0) {
        await _handleOutOfLives();
      }
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
        await _ads.offerRewardedVideo(context, AdRewardKind.extraTimeAndLife);
    if (!mounted) return;
    if (watched) {
      _engine.addTime(60);
      _engine.addLife(1);
      _engine.resume();
      _busy = false;
    } else {
      _busy = false;
      await _showEndDialog(win: false);
    }
  }

  Future<void> _handleOutOfLives() async {
    if (_busy) return;
    _busy = true;
    _engine.pause();
    final watched =
        await _ads.offerRewardedVideo(context, AdRewardKind.extraTimeAndLife);
    if (!mounted) return;
    if (watched) {
      _engine.addLife(1);
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
      final pair = _engine.revealHint();
      if (pair != null) {
        Future<void>.delayed(const Duration(seconds: 4), () {
          if (mounted) _engine.clearHint();
        });
      }
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
                  _engine.newGame();
                  _activeLine = null;
                });
                _busy = false;
                _startClock();
              },
              child: Text(_loc.t('playAgain')),
            ),
          ],
        ),
      ),
    );
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
              animation: _engine,
              builder: (context, _) => Column(
                children: [
                  _buildHud(),
                  Expanded(child: _buildBoard()),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHud() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _confirmQuit,
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppTheme.textPrimary),
              ),
              const Spacer(),
              _LangMiniToggle(loc: _loc),
            ],
          ),
          Row(
            children: [
              _StatCard(
                icon: Icons.star_rounded,
                label: _loc.t('score'),
                value: '${_engine.score}',
              ),
              const SizedBox(width: 8),
              _StatCard(
                icon: Icons.timer_outlined,
                label: _loc.t('time'),
                value: _engine.formattedTime,
                highlight: _engine.secondsRemaining <= 15,
              ),
              const SizedBox(width: 8),
              _StatCard(
                icon: Icons.favorite_rounded,
                label: _loc.t('lives'),
                value: '${_engine.lives}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          // Reserve half a cell of margin on each side so connection lines can
          // travel around the outside border.
          final cell = (w / (_engine.cols + 1))
              .clamp(0.0, h / (_engine.rows + 1));
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

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_loc.t('tilesLeft')}: ${_engine.remainingTiles}',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accentSoft,
              foregroundColor: Colors.black87,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _useHint,
            icon: const Icon(Icons.lightbulb_outline_rounded),
            label: Text(
              _loc.t('hint'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlight ? AppTheme.accent : AppTheme.surfaceHigh,
            width: highlight ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16,
                    color: highlight ? AppTheme.accent : AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: highlight ? AppTheme.accent : AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangMiniToggle extends StatelessWidget {
  const _LangMiniToggle({required this.loc});
  final LocaleController loc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceHigh),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip('РУС', AppLanguage.ru),
          _chip('ENG', AppLanguage.en),
        ],
      ),
    );
  }

  Widget _chip(String label, AppLanguage lang) {
    final selected = loc.language == lang;
    return GestureDetector(
      onTap: () => loc.setLanguage(lang),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black87 : AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
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
