package hammerfest;

import hammerfest.LevelGen.GPt;
import hammerfest.LevelGen.GSeg;

// The ways of Igor in a level: from where he lands at the start, the fewest moves to every place (walks, jumps, falls,
// teleporters), and how much each case is gone through by the ways to every platform and to the way down (the
// traffic). The bads that shoot, the ball of the strawberries, the spikes and the lasers are put where it is high:
// where Igor has to go, not in the corners he never passes by.
@:access(hammerfest.LevelGen)
class LevelRoutes {
	static inline var W = Data.LEVEL_WIDTH;
	static inline var H = Data.LEVEL_HEIGHT;

	var g:LevelGen;

	// (cases: x * H + y)
	public var dist:Array<Int>; // moves from the start to a standing case, -1: not reached
	public var par:Array<Int>; // the standing case before it on a shortest way
	public var traffic:Array<Float>; // how many ways go through the case
	public var start:Int;
	public var exitCell:Int = -1; // the nearest standing case Igor falls out of the level from
	public var total:Float = 0;

	public function new(g:LevelGen) {
		this.g = g;
	}

	public function compute() {
		g.buildMoves();
		var sy = g.py;
		while (sy < H - 1 && !g.canStand(g.px, sy))
			sy++;
		start = g.px * H + sy;
		bfs(start);
		traffic = [for (i in 0...W * H) 0.0];
		total = 0;
		// the ways to every platform reached (its middle), each counted once
		for (s in g.segments()) {
			var best = -1;
			var bd = 99.0;
			for (x in s.x0...s.x1 + 1) {
				var c = x * H + s.y;
				if (dist[c] < 0)
					continue;
				var d = Math.abs(x - (s.x0 + s.x1) / 2);
				if (d < bd) {
					bd = d;
					best = c;
				}
			}
			if (best >= 0)
				addWay(best, 1.0);
		}
		// the way down: the nearest place falling out of the level, and the fall
		exitCell = -1;
		var ed = 9999;
		for (c in 0...W * H)
			if (dist[c] >= 0 && g.moveOut[c] && dist[c] < ed) {
				ed = dist[c];
				exitCell = c;
			}
		if (exitCell >= 0) {
			addWay(exitCell, 2.0);
			var x = Std.int(exitCell / H);
			var y = exitCell % H;
			// (off the edge of its platform, down to the bottom)
			var fx = x;
			for (d in [-1, 1])
				if (g.passable(x + d, y) && !g.canStand(x + d, y))
					fx = x + d;
			for (yy in y...H)
				if (g.inb(fx, yy) && g.m[fx][yy] <= 0)
					traffic[fx * H + yy] += 2.0;
		}
	}

	function bfs(s0:Int) {
		dist = [for (i in 0...W * H) -1];
		par = [for (i in 0...W * H) -1];
		dist[s0] = 0;
		var q = [s0];
		var i = 0;
		while (i < q.length) {
			var c = q[i++];
			var n = g.moveTo[c];
			if (n == null)
				continue;
			for (t in n)
				if (dist[t] < 0) {
					dist[t] = dist[c] + 1;
					par[t] = c;
					q.push(t);
				}
		}
	}

	function addWay(c:Int, w:Float) {
		var seen = new Map<Int, Bool>();
		for (k in way(c))
			if (!seen.exists(k)) {
				seen.set(k, true);
				traffic[k] += w;
			}
		total += w;
	}

	// the cases a shortest way from the start to the standing case c goes through: the standing cases and the air
	// between them (up then across for the jumps up, a little up then across then down for the jumps across, across then
	// down for the falls); through a teleporter, nothing in between
	public function way(c:Int):Array<Int> {
		var chain:Array<Int> = [];
		var k = c;
		var guard = 0;
		while (k >= 0 && guard++ < 400) {
			chain.push(k);
			if (k == start)
				break;
			k = par[k];
		}
		chain.reverse();
		var out:Array<Int> = [];
		for (i in 0...chain.length) {
			if (i == 0) {
				out.push(chain[0]);
				continue;
			}
			var a = chain[i - 1];
			var b = chain[i];
			if (g.moveTeleTo != null && g.moveTeleTo[a] != null && g.moveTeleTo[a].indexOf(b) >= 0) {
				out.push(b);
				continue;
			}
			step(Std.int(a / H), a % H, Std.int(b / H), b % H, out);
		}
		return out;
	}

	function step(ax:Int, ay:Int, bx:Int, by:Int, out:Array<Int>) {
		inline function add(x:Int, y:Int)
			if (x >= 0 && x < W && y >= 0 && y < H)
				out.push(x * H + y);
		var dir = bx > ax ? 1 : (bx < ax ? -1 : 0);
		if (by < ay) {
			// up, then across
			var y = ay;
			while (y > by) {
				add(ax, y);
				y--;
			}
			var x = ax;
			while (x != bx) {
				add(x, by);
				x += dir;
			}
			add(bx, by);
		} else if (Math.abs(bx - ax) <= 1) {
			// a step, a fall
			add(ax, ay);
			var y = ay;
			while (y <= by) {
				add(bx, y);
				y++;
			}
		} else {
			// a jump across: a row up, across, down
			add(ax, ay);
			var x = ax;
			while (x != bx) {
				add(x, ay - 1);
				x += dir;
			}
			var y = ay - 1;
			while (y <= by) {
				add(bx, y);
				y++;
			}
		}
	}

	public inline function at(x:Int, y:Int):Float {
		return (x < 0 || x >= W || y < 0 || y >= H) ? 0 : traffic[x * H + y];
	}

	// the traffic of the cases of a box
	public function sum(x0:Int, y0:Int, x1:Int, y1:Int):Float {
		var s = 0.0;
		for (x in x0...x1 + 1)
			for (y in y0...y1 + 1)
				s += at(x, y);
		return s;
	}

	// the shortest way from the start to a standing case near these cases (Igor close enough to drop a bomb there:
	// dx <= rx, dy from -ry to 1), null when none is reached
	public function wayNear(cells:Array<GPt>, rx:Int, ry:Int):Array<Int> {
		var best = -1;
		var bd = 99999;
		for (p in cells)
			for (x in p.x - rx...p.x + rx + 1)
				for (y in p.y - ry...p.y + 2) {
					if (x < 0 || x >= W || y < 0 || y >= H)
						continue;
					var c = x * H + y;
					if (dist[c] >= 0 && dist[c] < bd) {
						bd = dist[c];
						best = c;
					}
				}
		return best < 0 ? null : way(best);
	}

	// the cases of a way within d cases of the line from a to b (the ball of the strawberries): how many
	public static function nearLine(cells:Array<Int>, ax:Float, ay:Float, bx:Float, by:Float, d:Float):Int {
		var n = 0;
		var vx = bx - ax;
		var vy = by - ay;
		var l2 = vx * vx + vy * vy;
		for (c in cells) {
			var x = Std.int(c / H);
			var y = c % H;
			var t = l2 == 0 ? 0 : ((x - ax) * vx + (y - ay) * vy) / l2;
			if (t < 0)
				t = 0;
			if (t > 1)
				t = 1;
			var px = ax + t * vx - x;
			var py = ay + t * vy - y;
			if (px * px + py * py <= d * d)
				n++;
		}
		return n;
	}

	// the traffic along the line from a to b (within a case of it)
	public function lineTraffic(ax:Int, ay:Int, bx:Int, by:Int):Float {
		var s = 0.0;
		var steps = Std.int(Math.max(Math.abs(bx - ax), Math.abs(by - ay)));
		if (steps == 0)
			return 0;
		var seen = new Map<Int, Bool>();
		for (i in 0...steps + 1) {
			var x = Math.round(ax + (bx - ax) * i / steps);
			var y = Math.round(ay + (by - ay) * i / steps);
			for (dx in -1...2)
				for (dy in -1...2) {
					var cx = x + dx;
					var cy = y + dy;
					if (cx < 0 || cx >= W || cy < 0 || cy >= H || seen.exists(cx * H + cy))
						continue;
					seen.set(cx * H + cy, true);
					s += traffic[cx * H + cy];
				}
		}
		return s;
	}
}
