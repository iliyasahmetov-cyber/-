import 'dart:math';

import 'package:flutter/foundation.dart';

import 'path_finder.dart';

/// Outcome categories for a tap on the board.
enum MoveType {
  none,
  firstSelection,
  deselect,
  switchSelection,
  matched,
  invalid,
}

/// The result of a single [GameEngine.select] call.
class MoveResult {
  MoveResult(this.type, {this.path, this.a, this.b, this.tileId});

  final MoveType type;

  /// Populated for [MoveType.matched]: the connecting polyline (logical coords).
  final ConnectionPath? path;
  final Coord? a;
  final Coord? b;
  final int? tileId;
}

/// Core logical matrix + rules for the "Pao Pao" (Onet Connect) board.
///
/// Holds an 8×12 grid, tile generation, selection/matching, scoring, lives,
/// the countdown clock, hint search and deadlock shuffling. It is a
/// [ChangeNotifier] so screens can rebuild reactively.
class GameEngine extends ChangeNotifier {
  GameEngine({
    this.cols = 8,
    this.rows = 12,
    this.tileTypes = 12,
    this.startLives = 3,
    this.startSeconds = 180,
    Random? random,
  })  : _random = random ?? Random(),
        _grid = List.generate(rows, (_) => List<int>.filled(cols, 0));

  /// 8 columns wide, 12 rows tall.
  final int cols;
  final int rows;

  /// Number of distinct, structurally-similar tile designs (1..tileTypes).
  final int tileTypes;
  final int startLives;
  final int startSeconds;

  final Random _random;
  final List<List<int>> _grid;

  Coord? _selected;
  int _score = 0;
  int _lives = 0;
  int _secondsRemaining = 0;
  int _maxSeconds = 0;
  int _remainingTiles = 0;
  bool _isRunning = false;

  // Tiles the hint system is currently highlighting.
  Coord? _hintA;
  Coord? _hintB;

  // --- Public read-only state ---
  List<List<int>> get grid => _grid;
  Coord? get selected => _selected;
  int get score => _score;
  int get lives => _lives;
  int get secondsRemaining => _secondsRemaining;
  int get maxSeconds => _maxSeconds;

  /// Remaining time as a 0..1 fraction, for the visual time bar.
  double get timeProgress =>
      _maxSeconds == 0 ? 0 : (_secondsRemaining / _maxSeconds).clamp(0.0, 1.0);

  int get remainingTiles => _remainingTiles;
  bool get isRunning => _isRunning;
  Coord? get hintA => _hintA;
  Coord? get hintB => _hintB;
  bool get isComplete => _remainingTiles == 0;

  int tileAt(int r, int c) => _grid[r][c];
  bool isHinted(int r, int c) =>
      (_hintA != null && _hintA!.row == r && _hintA!.col == c) ||
      (_hintB != null && _hintB!.row == r && _hintB!.col == c);

  String get formattedTime {
    final m = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Start a fresh level.
  void newGame() {
    _score = 0;
    _lives = startLives;
    _secondsRemaining = startSeconds;
    _maxSeconds = startSeconds;
    _selected = null;
    _clearHint();
    _generateBoard();
    _isRunning = true;
    notifyListeners();
  }

  /// Fill the board with evenly distributed, randomly placed pairs and make
  /// sure the opening position already has at least one legal move.
  void _generateBoard() {
    final total = rows * cols;
    assert(total.isEven, 'Board must contain an even number of cells.');

    final values = <int>[];
    // Each design must appear an even number of times so everything can pair.
    final pairsPerType = (total ~/ 2) ~/ tileTypes;
    for (var t = 1; t <= tileTypes; t++) {
      for (var p = 0; p < pairsPerType * 2; p++) {
        values.add(t);
      }
    }
    // Top up any remainder (when total/2 is not divisible by tileTypes).
    var next = 1;
    while (values.length < total) {
      values.add(next);
      values.add(next);
      next = next % tileTypes + 1;
    }
    values.length = total;

    _placeValues(values);
    _remainingTiles = total;

    // Guarantee a solvable opening.
    var guard = 0;
    while (!hasMoves() && guard++ < 200) {
      values.shuffle(_random);
      _placeValues(values);
    }
  }

  void _placeValues(List<int> values) {
    values.shuffle(_random);
    var i = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        _grid[r][c] = values[i++];
      }
    }
  }

  /// Build a grid padded with an empty one-cell border for the pathfinder.
  List<List<int>> _paddedGrid() {
    final padded = List.generate(
      rows + 2,
      (_) => List<int>.filled(cols + 2, PathFinder.empty),
    );
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        padded[r + 1][c + 1] = _grid[r][c];
      }
    }
    return padded;
  }

  Coord _toPadded(Coord logical) => Coord(logical.row + 1, logical.col + 1);
  Coord _toLogical(Coord padded) => Coord(padded.row - 1, padded.col - 1);

  /// Handle a tap on the tile at ([row], [col]).
  MoveResult select(int row, int col) {
    if (!_isRunning) return MoveResult(MoveType.none);
    _clearHint();

    if (_grid[row][col] == PathFinder.empty) {
      return MoveResult(MoveType.none);
    }

    final tapped = Coord(row, col);

    if (_selected == null) {
      _selected = tapped;
      notifyListeners();
      return MoveResult(MoveType.firstSelection, a: tapped);
    }

    if (_selected == tapped) {
      _selected = null;
      notifyListeners();
      return MoveResult(MoveType.deselect, a: tapped);
    }

    final first = _selected!;
    final sameType = _grid[first.row][first.col] == _grid[row][col];

    if (!sameType) {
      _selected = tapped;
      notifyListeners();
      return MoveResult(MoveType.switchSelection, a: tapped);
    }

    // Same design → test the 2-turn connection rule.
    final padded = _paddedGrid();
    final path = PathFinder.findPath(
      padded,
      _toPadded(first),
      _toPadded(tapped),
    );

    if (path == null) {
      // Correct guess of identity but no legal line → costs a life.
      _lives = (_lives - 1).clamp(0, startLives);
      _selected = tapped;
      notifyListeners();
      return MoveResult(MoveType.invalid, a: first, b: tapped);
    }

    // Valid match.
    final tileId = _grid[first.row][first.col];
    _grid[first.row][first.col] = PathFinder.empty;
    _grid[row][col] = PathFinder.empty;
    _remainingTiles -= 2;
    _score += 10;
    _selected = null;

    final logicalPoints = path.points.map(_toLogical).toList();
    notifyListeners();

    return MoveResult(
      MoveType.matched,
      path: ConnectionPath(logicalPoints, path.turns),
      a: first,
      b: tapped,
      tileId: tileId,
    );
  }

  /// Is there at least one connectable pair remaining?
  bool hasMoves() => findHint() != null;

  /// Return one valid connectable pair (logical coords), or `null` if none.
  List<Coord>? findHint() {
    final padded = _paddedGrid();
    final positions = <Coord>[];
    final byType = <int, List<Coord>>{};
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final v = _grid[r][c];
        if (v == PathFinder.empty) continue;
        final coord = Coord(r, c);
        positions.add(coord);
        byType.putIfAbsent(v, () => []).add(coord);
      }
    }
    for (final group in byType.values) {
      for (var i = 0; i < group.length; i++) {
        for (var j = i + 1; j < group.length; j++) {
          if (PathFinder.canConnect(
            padded,
            _toPadded(group[i]),
            _toPadded(group[j]),
          )) {
            return [group[i], group[j]];
          }
        }
      }
    }
    return null;
  }

  /// Reveal a hint pair on the board (used after a rewarded video).
  List<Coord>? revealHint() {
    final pair = findHint();
    if (pair != null) {
      _hintA = pair[0];
      _hintB = pair[1];
      notifyListeners();
    }
    return pair;
  }

  void _clearHint() {
    if (_hintA != null || _hintB != null) {
      _hintA = null;
      _hintB = null;
    }
  }

  void clearHint() {
    _clearHint();
    notifyListeners();
  }

  void clearSelection() {
    _selected = null;
    notifyListeners();
  }

  /// Reshuffle the remaining tiles, guaranteeing at least one legal move.
  void shuffleBoard() {
    final remaining = <int>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (_grid[r][c] != PathFinder.empty) remaining.add(_grid[r][c]);
      }
    }
    if (remaining.isEmpty) return;

    var guard = 0;
    do {
      remaining.shuffle(_random);
      var i = 0;
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          if (_grid[r][c] != PathFinder.empty) {
            _grid[r][c] = remaining[i++];
          }
        }
      }
    } while (!hasMoves() && guard++ < 200);

    _selected = null;
    _clearHint();
    notifyListeners();
  }

  /// Decrement the clock by one second. Returns `true` when it hits zero.
  bool tickSecond() {
    if (!_isRunning || _secondsRemaining <= 0) return _secondsRemaining <= 0;
    _secondsRemaining -= 1;
    notifyListeners();
    return _secondsRemaining <= 0;
  }

  void addTime(int seconds) {
    _secondsRemaining += seconds;
    // Keep the bar accurate when time is extended past its previous maximum.
    if (_secondsRemaining > _maxSeconds) _maxSeconds = _secondsRemaining;
    notifyListeners();
  }

  void addLife(int amount) {
    _lives = (_lives + amount).clamp(0, startLives + amount);
    notifyListeners();
  }

  void pause() {
    _isRunning = false;
    notifyListeners();
  }

  void resume() {
    if (!isComplete && _lives > 0 && _secondsRemaining > 0) {
      _isRunning = true;
      notifyListeners();
    }
  }

  void stop() {
    _isRunning = false;
    notifyListeners();
  }
}
