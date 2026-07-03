import 'dart:collection';

/// A cell coordinate on the *padded* board (see [PathFinder]).
class Coord {
  const Coord(this.row, this.col);
  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is Coord && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row,$col)';
}

/// Result of a successful connection: the polyline (list of corner points)
/// linking two tiles, plus the number of turns used.
class ConnectionPath {
  ConnectionPath(this.points, this.turns);

  /// Corner points in *padded* coordinates, from tile A to tile B.
  final List<Coord> points;
  final int turns;
}

/// Modified BFS pathfinder for the classic Onet / "Pao Pao" matching rule.
///
/// Two identical tiles can be linked by a line that has **at most 2 turns**
/// (90° angles), i.e. up to 3 straight segments. The search runs on a grid
/// that is padded with an empty one-cell border so that connecting lines are
/// allowed to travel *around* the outside edge of the board.
class PathFinder {
  /// Empty cell marker.
  static const int empty = 0;

  // Direction vectors: up, down, left, right.
  static const List<List<int>> _dirs = [
    [-1, 0],
    [1, 0],
    [0, -1],
    [0, 1],
  ];

  /// Finds a valid connection between [a] and [b] on the [padded] grid.
  ///
  /// [padded] must already include the empty border. Returns `null` when the
  /// two tiles cannot be connected within the 2-turn budget.
  static ConnectionPath? findPath(
    List<List<int>> padded,
    Coord a,
    Coord b,
  ) {
    if (a == b) return null;
    final rows = padded.length;
    final cols = padded[0].length;

    // best[r][c][dir] = minimum turns to arrive at (r,c) travelling in `dir`.
    final best = List.generate(
      rows,
      (_) => List.generate(cols, (_) => List<int>.filled(4, 1 << 30)),
    );
    // Predecessor for path reconstruction: stores [pr, pc, pdir].
    final prev = List.generate(
      rows,
      (_) => List.generate(cols, (_) => List<List<int>?>.filled(4, null)),
    );

    // 0-1 BFS deque: straight moves cost 0 turns, direction changes cost 1.
    final deque = DoubleLinkedQueue<List<int>>();
    for (var d = 0; d < 4; d++) {
      best[a.row][a.col][d] = 0;
      deque.addFirst([a.row, a.col, d]);
    }

    int? arrivalDir;
    while (deque.isNotEmpty) {
      final state = deque.removeFirst();
      final r = state[0], c = state[1], dir = state[2];
      final turns = best[r][c][dir];

      for (var nd = 0; nd < 4; nd++) {
        final nr = r + _dirs[nd][0];
        final nc = c + _dirs[nd][1];
        if (nr < 0 || nc < 0 || nr >= rows || nc >= cols) continue;

        final newTurns = turns + (nd == dir ? 0 : 1);
        if (newTurns > 2) continue;

        final isTarget = nr == b.row && nc == b.col;
        // Intermediate cells must be empty; the target tile is the exception.
        if (!isTarget && padded[nr][nc] != empty) continue;

        if (isTarget) {
          if (newTurns < best[b.row][b.col][nd]) {
            best[b.row][b.col][nd] = newTurns;
            prev[b.row][b.col][nd] = [r, c, dir];
            arrivalDir = nd;
          }
          continue;
        }

        if (newTurns < best[nr][nc][nd]) {
          best[nr][nc][nd] = newTurns;
          prev[nr][nc][nd] = [r, c, dir];
          if (nd == dir) {
            deque.addFirst([nr, nc, nd]);
          } else {
            deque.addLast([nr, nc, nd]);
          }
        }
      }
    }

    // Find the cheapest arrival direction into b.
    var bestTurns = 1 << 30;
    var bestDir = -1;
    for (var d = 0; d < 4; d++) {
      if (best[b.row][b.col][d] < bestTurns) {
        bestTurns = best[b.row][b.col][d];
        bestDir = d;
      }
    }
    if (bestDir == -1 || bestTurns > 2) return null;
    arrivalDir = bestDir;

    // Reconstruct the full cell-by-cell path, then simplify to corners.
    final cells = <Coord>[];
    var cr = b.row, cc = b.col, cdir = arrivalDir;
    cells.add(Coord(cr, cc));
    while (!(cr == a.row && cc == a.col)) {
      final p = prev[cr][cc][cdir];
      if (p == null) break;
      cr = p[0];
      cc = p[1];
      cdir = p[2];
      cells.add(Coord(cr, cc));
    }
    final ordered = cells.reversed.toList();
    return ConnectionPath(_simplify(ordered), bestTurns);
  }

  /// True when [a] and [b] can be connected under the 2-turn rule.
  static bool canConnect(List<List<int>> padded, Coord a, Coord b) =>
      findPath(padded, a, b) != null;

  /// Collapse collinear points so only real corners remain.
  static List<Coord> _simplify(List<Coord> pts) {
    if (pts.length <= 2) return pts;
    final out = <Coord>[pts.first];
    for (var i = 1; i < pts.length - 1; i++) {
      final prev = pts[i - 1];
      final cur = pts[i];
      final next = pts[i + 1];
      final dr1 = cur.row - prev.row;
      final dc1 = cur.col - prev.col;
      final dr2 = next.row - cur.row;
      final dc2 = next.col - cur.col;
      // Keep the point only if the direction changes (a corner).
      if (dr1 != dr2 || dc1 != dc2) out.add(cur);
    }
    out.add(pts.last);
    return out;
  }
}
