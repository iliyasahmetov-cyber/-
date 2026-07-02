import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:paopao/game_engine.dart';
import 'package:paopao/path_finder.dart';

/// Wrap a logical grid with an empty border, matching what the engine feeds
/// the pathfinder.
List<List<int>> pad(List<List<int>> g) {
  final rows = g.length, cols = g[0].length;
  final p = List.generate(
    rows + 2,
    (_) => List<int>.filled(cols + 2, PathFinder.empty),
  );
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      p[r + 1][c + 1] = g[r][c];
    }
  }
  return p;
}

void main() {
  group('PathFinder', () {
    test('connects adjacent tiles with 0 turns', () {
      final grid = pad([
        [1, 1],
      ]);
      final path = PathFinder.findPath(grid, const Coord(1, 1), const Coord(1, 2));
      expect(path, isNotNull);
      expect(path!.turns, 0);
    });

    test('connects tiles separated only by empty cells (straight line)', () {
      final grid = pad([
        [1, 0, 0, 1],
      ]);
      final path = PathFinder.findPath(grid, const Coord(1, 1), const Coord(1, 4));
      expect(path, isNotNull);
      expect(path!.turns, 0);
    });

    test('blocks a straight line interrupted by another tile', () {
      final grid = pad([
        [1, 2, 1],
      ]);
      // The two 1s cannot go straight through the 2, but can route around the
      // top border with 2 turns.
      final path = PathFinder.findPath(grid, const Coord(1, 1), const Coord(1, 3));
      expect(path, isNotNull);
      expect(path!.turns, lessThanOrEqualTo(2));
    });

    test('connects an L-shape with exactly 1 turn', () {
      final grid = pad([
        [1, 0],
        [0, 1],
      ]);
      final path = PathFinder.findPath(grid, const Coord(1, 1), const Coord(2, 2));
      expect(path, isNotNull);
      expect(path!.turns, lessThanOrEqualTo(2));
    });

    test('rejects a connection needing more than 2 turns', () {
      // 1s are boxed so any route requires a long detour (>2 turns).
      final grid = pad([
        [1, 2, 2, 2],
        [2, 2, 2, 2],
        [2, 2, 2, 2],
        [2, 2, 2, 1],
      ]);
      final path = PathFinder.findPath(grid, const Coord(1, 1), const Coord(4, 4));
      expect(path, isNull);
    });

    test('cannot cross a solid 2x2 block diagonally (needs >2 turns)', () {
      final grid = pad([
        [1, 2],
        [2, 1],
      ]);
      // Opposite corners of a filled 2x2 require 3 turns → not connectable.
      final path = PathFinder.findPath(grid, const Coord(1, 1), const Coord(2, 2));
      expect(path, isNull);
    });

    test('routes around the outer border with exactly 2 turns (U-shape)', () {
      final grid = pad([
        [1],
        [2],
        [1],
      ]);
      // Direct vertical line is blocked by the 2, so the route wraps around the
      // left border: left, down, right → 2 turns.
      final path = PathFinder.findPath(grid, const Coord(1, 1), const Coord(3, 1));
      expect(path, isNotNull);
      expect(path!.turns, 2);
    });
  });

  group('GameEngine', () {
    test('generates a solvable, fully-paired board', () {
      final engine = GameEngine(random: Random(1));
      engine.newGame();
      expect(engine.remainingTiles, engine.rows * engine.cols);
      expect(engine.hasMoves(), isTrue);

      // Every tile value must appear an even number of times.
      final counts = <int, int>{};
      for (var r = 0; r < engine.rows; r++) {
        for (var c = 0; c < engine.cols; c++) {
          counts.update(engine.tileAt(r, c), (v) => v + 1, ifAbsent: () => 1);
        }
      }
      for (final entry in counts.entries) {
        expect(entry.value.isEven, isTrue, reason: 'tile ${entry.key}');
      }
    });

    test('a valid match removes two tiles and scores', () {
      final engine = GameEngine(random: Random(2));
      engine.newGame();
      final pair = engine.findHint();
      expect(pair, isNotNull);

      final before = engine.remainingTiles;
      engine.select(pair![0].row, pair[0].col);
      final result = engine.select(pair[1].row, pair[1].col);

      expect(result.type, MoveType.matched);
      expect(engine.remainingTiles, before - 2);
      expect(engine.score, 10);
    });

    test('shuffle keeps tile count and guarantees a move', () {
      final engine = GameEngine(random: Random(3));
      engine.newGame();
      final before = engine.remainingTiles;
      engine.shuffleBoard();
      expect(engine.remainingTiles, before);
      expect(engine.hasMoves(), isTrue);
    });

    test('timer + reward mutate remaining time', () {
      final engine = GameEngine(random: Random(4), fixedSeconds: 5);
      engine.newGame();
      engine.tickSecond();
      expect(engine.secondsRemaining, 4);
      engine.addTime(60);
      expect(engine.secondsRemaining, 64);
    });

    test('levels scale: comfortable time on L1, harder & shorter later', () {
      final engine = GameEngine(random: Random(5));
      engine.newGame();
      expect(engine.level, 1);
      // 48 pairs * 7s = 336s on level 1 (comfortable).
      expect(engine.secondsRemaining, 336);
      final l1Types = engine.tileTypes;

      engine.nextLevel();
      expect(engine.level, 2);
      // Score carries across levels; time shrinks; difficulty (types) grows.
      expect(engine.secondsForLevel(2), lessThan(engine.secondsForLevel(1)));
      expect(engine.tileTypes, greaterThanOrEqualTo(l1Types));
      expect(engine.secondsForLevel(7), lessThan(engine.secondsForLevel(1)));
      expect(engine.hasMoves(), isTrue);
    });

    test('score persists into the next level', () {
      final engine = GameEngine(random: Random(6));
      engine.newGame();
      final pair = engine.findHint()!;
      engine.select(pair[0].row, pair[0].col);
      engine.select(pair[1].row, pair[1].col);
      expect(engine.score, 10);
      engine.nextLevel();
      expect(engine.score, 10);
      expect(engine.lives, engine.startLives);
    });
  });
}
