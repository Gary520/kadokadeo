package hammerfest;

import hammerfest.LevelGen.GSeg;

// what a platform offers to a bad
typedef SegInfo = {
	len:Int,
	reached:Bool, // Igor stands on it
	escape:Bool, // a bad frozen there can be kicked out of the level (LevelGen.iceEscapes)
	wallL:Bool, // ground at its ends (a wall, the side of the screen)
	wallR:Bool,
	edge:Int, // cases between it and the nearest side of the screen
	hop:Int, // platforms of its row a jump away (a hole of 1 or 2 cases): the oranges jump over the holes
	around:Int, // cases where Igor stands around it (4 cases at most), not on it: Igor's places near it
	zone:Int, // cases where a bad can go from there by itself (walking, jumping, climbing, falling): its moves
	head:Int, // free cases over its middle
	own:Float, // Igor going along it (LevelRoutes)
	far:Int, // the moves of Igor from the start to it (99: not reached)
	above:Int, // places of Igor over it a bomb reaches it from (kicked off an edge, dropped falling): bombed from above
	steps:Int, // pushes its ice takes to go out of the level (1: off an end straight out; 99: never)
	line:Array<Int> // the cases its ice goes through at the first push (both ways): a bad there dies with it (surf)
}

// The bads of a level placed for what they do, like the levels of the original Hammerfest are made around their bads:
// - cherries: they walk on their platform, no more: on the floors where Igor walks, the long ones;
// - oranges: they jump over the holes of their row: on rows of platforms cut by small holes;
// - apples: their pips fly along their row through the walls: on the rows Igor crosses, one row each;
// - bananas: they jump, climb and fall everywhere: where their moves take them to the most places;
// - lemons: their zests fly up or down to Igor through the floors: under (or over) the places of Igor, the floors
//   of the bottom, each its columns;
// - bombs: they blow up 5 cases around when they are hit: on the small ledges and steps by the ways of Igor, several of
//   them (shut in, they blow up by themselves: no need to kick them out);
// - pears: they throw their bombs high in front of them: up in the level, over the open places Igor walks below;
// - strawberries: they pass their ball to each other across the level, the ball kills Igor on its way: alone on
//   ledges far apart, facing each other (the sides, the corners), the ball crossing the places of Igor; one alone
//   throws its ball at Igor: on a high ledge away from his ways, seeing the level;
// - apricots: two small ones fall from the top when one dies: in the rooms and shafts of the lower half;
// - kiwis: they leave mines on their way: on the floors Igor has to walk on;
// - litchis: two hits (the shell, then the litchi): on the long floors, room to fight them;
// - pineapples: they make the ground shake under Igor: on a wide floor of the middle, open over it;
// - raspberries: they burst into pieces flying far away: anywhere Igor goes.
// The kind leading the level is placed first (the best places for it), then the others; the bads of a symmetric
// level go by pairs; rows of the same bads on long floors make combos (the original puts lemons, cherries...
// side by side). How well each bad fits its place is kept for the rating of the level (LevelGen.rate).
@:access(hammerfest.LevelGen)
class LevelBads {
	static inline var W = Data.LEVEL_WIDTH;
	static inline var H = Data.LEVEL_HEIGHT;

	var g:LevelGen;
	var segs:Array<GSeg>;
	var inf:Array<SegInfo>;
	var used:Array<Int>;
	var landY:Int;
	var topLand:Int;
	var killer:Bool;
	var placed:Array<{id:Int, x:Int, y:Int}>;
	var placedK:Array<Int>; // (the platform of each one)
	var colIgor:Array<Int>;
	var rowIgor:Array<Int>;

	// how well the bads fit their places (0..1 each): all of them, the ones of the leading kind
	public var fit:Float = 0;
	public var leadFit:Float = 0;
	public var count:Int = 0;
	// (strawberries guarded by the ball of the others: test harness)
	public var guardedN:Int = 0;
	// (remade levels of the original: where its bads were, better places)
	public var hints:Array<{x:Int, y:Int}> = null;
	// the bads drawn for places of the level (the room shut reached by a teleporter): put there first
	public var spots:Array<{id:Int, x:Int, y:Int}> = [];

	public function new(g:LevelGen) {
		this.g = g;
	}

	// ---------------------------------------------------------------- the level seen by the bads

	function analyse() {
		var m = g.m;
		segs = [for (s in g.segments()) if (g.segReached(s) || g.segNear(s)) s];
		landY = g.py;
		while (landY < H - 1 && !g.canStand(g.px, landY))
			landY++;
		topLand = H;
		for (x in 0...W)
			topLand = Std.int(Math.min(topLand, g.landRow(x)));
		colIgor = [for (x in 0...W) 0];
		rowIgor = [for (y in 0...H) 0];
		for (x in 0...W)
			for (y in 0...H)
				if (g.reach[x][y]) {
					colIgor[x]++;
					rowIgor[y]++;
				}
		inf = [];
		for (s in segs) {
			var len = s.x1 - s.x0 + 1;
			var hop = 0;
			for (o in segs)
				if (o.y == s.y && o != s) {
					var gap = o.x0 > s.x1 ? o.x0 - s.x1 - 1 : s.x0 - o.x1 - 1;
					if (gap >= 1 && gap <= 2 && !g.gr(o.x0 > s.x1 ? s.x1 + 1 : s.x0 - 1, s.y))
						hop++;
				}
			var around = 0;
			for (x in s.x0 - 4...s.x1 + 5)
				for (y in s.y - 4...s.y + 5)
					if (g.inb(x, y) && g.reach[x][y] && !(y == s.y && x >= s.x0 && x <= s.x1))
						around++;
			var far = 99;
			for (x in s.x0...s.x1 + 1) {
				var d = g.routes.dist[x * H + s.y];
				if (d >= 0 && d < far)
					far = d;
			}
			var cx = (s.x0 + s.x1) >> 1;
			var head = 0;
			var yy = s.y - 1;
			while (yy >= 0 && m[cx][yy] <= 0) {
				head++;
				yy--;
			}
			inf.push({
				len: len,
				reached: g.segReached(s),
				escape: g.iceEscapes(s),
				wallL: g.gr(s.x0 - 1, s.y),
				wallR: g.gr(s.x1 + 1, s.y),
				edge: Std.int(Math.min(s.x0, W - 1 - s.x1)),
				hop: hop,
				around: around,
				zone: zoneSize(s),
				head: head,
				own: ownExposure(s),
				far: far,
				above: aboveExposure(s),
				steps: iceSteps(s),
				line: iceLine(s)
			});
		}
		used = [for (s in segs) 0];
	}

	// ---------------------------------------------------------------- what Igor can do against a bad of a platform

	// the places of Igor from which he bombs a bad of the platform from above, staying up there (LevelGen.bombExposure)
	function aboveExposure(s:GSeg):Int {
		return g.bombExposure(s.x0, s.x1, s.y);
	}

	// the pushes the ice of a bad of this platform takes to go out of the level or onto spikes: kicked from a side Igor
	// reaches, it slides to a wall (pushed back from there) or off an edge onto a lower platform (pushed again there)
	function iceSteps(s:GSeg):Int {
		var m = g.m;
		var seen = new Map<Int, Bool>();
		var q:Array<{x:Int, y:Int, d:Int}> = [for (x in s.x0...s.x1 + 1) {x: x, y: s.y, d: 0}];
		for (p in q)
			seen.set(p.x * 32 + p.y, true);
		var i = 0;
		while (i < q.length && i < 300) {
			var p = q[i++];
			for (dir in [-1, 1]) {
				var kx = p.x - dir;
				if (!(g.inb(kx, p.y) && g.reach[kx][p.y]) && !g.reach[p.x][p.y])
					continue;
				var x = p.x;
				var y = p.y;
				var stop:{x:Int, y:Int} = null;
				var guard = 0;
				while (guard++ < 40) {
					var nx = x + dir;
					if (nx < 0 || nx >= W || m[nx][y] > 0) {
						stop = {x: x, y: y};
						break;
					}
					if (g.spikeAt(nx, y))
						return p.d + 1;
					if (y + 1 < H && m[nx][y + 1] > 0) {
						x = nx;
						continue;
					}
					var fy = y;
					while (fy + 1 < H && m[nx][fy + 1] <= 0) {
						fy++;
						if (g.spikeAt(nx, fy))
							return p.d + 1;
					}
					if (fy + 1 >= H)
						return p.d + 1;
					stop = {x: nx, y: fy};
					break;
				}
				if (stop != null && !seen.exists(stop.x * 32 + stop.y)) {
					seen.set(stop.x * 32 + stop.y, true);
					q.push({x: stop.x, y: stop.y, d: p.d + 1});
				}
			}
		}
		return 99;
	}

	// the cases the ice of a bad of this platform goes through at the first push, both ways: along its row, down off an
	// edge, on along the platform it lands on (it keeps going) until a wall or out of the level
	function iceLine(s:GSeg):Array<Int> {
		var m = g.m;
		var out:Array<Int> = [];
		for (dir in [-1, 1]) {
			var x = dir < 0 ? s.x1 : s.x0;
			var y = s.y;
			var guard = 0;
			while (guard++ < 60) {
				out.push(x * 32 + y);
				var nx = x + dir;
				if (nx < 0 || nx >= W || m[nx][y] > 0)
					break;
				if (y + 1 < H && m[nx][y + 1] > 0) {
					x = nx;
					continue;
				}
				var fy = y;
				while (fy + 1 < H && m[nx][fy + 1] <= 0) {
					fy++;
					out.push(nx * 32 + fy);
				}
				if (fy + 1 >= H)
					break;
				x = nx;
				y = fy;
			}
		}
		return out;
	}

	// dangerous bads: two of them where the ice of one goes are killed by one push
	static function dangerous(id:Int):Bool {
		return id != Data.BAD_CERISE && id != Data.BAD_ORANGE && id != Data.BAD_BANANE && id != Data.BAD_ABRICOT
			&& id != Data.BAD_CRAWLER;
	}

	// the cases a bad can go to from a platform (walking, falling from the edges, jumping down through a floor of one
	// case, up 3 rows, over a hole of 2 cases, climbing a wall of 3 cases: LevelGen.badZone)
	function zoneSize(s:GSeg):Int {
		var m = g.m;
		var seen = new Map<Int, Bool>();
		var q = [for (x in s.x0...s.x1 + 1) x * 32 + s.y];
		for (c in q)
			seen.set(c, true);
		inline function stand(x:Int, y:Int):Bool
			return x >= 0 && x < W && y >= 0 && y + 1 < H && m[x][y] <= 0 && m[x][y + 1] > 0;
		function landing(x:Int, y:Int):Int {
			while (y + 1 < H && !stand(x, y)) {
				if (m[x][y] > 0)
					return -1;
				y++;
			}
			return stand(x, y) ? y : -1;
		}
		var i = 0;
		while (i < q.length && q.length < 200) {
			var c = q[i++];
			var x = Std.int(c / 32);
			var y = c % 32;
			var next = [];
			for (d in [-1, 1]) {
				var nx = x + d;
				if (nx < 0 || nx >= W)
					continue;
				if (m[nx][y] > 0) {
					var h = 0;
					while (y - h >= 0 && m[nx][y - h] > 0)
						h++;
					if (h <= 3 && stand(nx, y - h))
						next.push(nx * 32 + y - h);
					continue;
				}
				if (stand(nx, y))
					next.push(nx * 32 + y);
				else {
					var ly = landing(nx, y);
					if (ly >= 0)
						next.push(nx * 32 + ly);
					if (stand(x + 3 * d, y) && m[x + 2 * d][y] <= 0)
						next.push((x + 3 * d) * 32 + y);
				}
			}
			if (y + 2 < H && m[x][y + 2] <= 0) {
				var ly = landing(x, y + 2);
				if (ly >= 0)
					next.push(x * 32 + ly);
			}
			if (y >= 3 && m[x][y - 1] <= 0 && m[x][y - 2] > 0 && m[x][y - 3] <= 0)
				next.push(x * 32 + y - 3);
			for (n in next)
				if (!seen.exists(n)) {
					seen.set(n, true);
					q.push(n);
				}
		}
		return q.length;
	}

	// how much Igor goes through a case: a case where he stands counts, a case of his ways (LevelRoutes: the ways to every
	// platform and to the bottom, the air of his jumps) counts more
	inline function wt(x:Int, y:Int):Float {
		return !g.inb(x, y) ? 0 : (g.reach[x][y] ? 0.5 : 0) + Math.min(2.5, g.routes.at(x, y));
	}

	// Igor in a box around (x, y)
	function igorIn(x0:Int, y0:Int, x1:Int, y1:Int):Float {
		var n = 0.0;
		for (x in x0...x1 + 1)
			for (y in y0...y1 + 1)
				n += wt(x, y);
		return n;
	}

	// cases where Igor stands in the columns of a platform, over and under it (not on its row): the zests of a lemon
	function columnsExposure(s:GSeg):Float {
		var n = 0.0;
		for (x in s.x0...s.x1 + 1)
			for (y in 0...H)
				if (y < s.y - 1 || y > s.y)
					n += wt(x, y);
		return n;
	}

	// cases where Igor stands on the row of a platform (and the row over it: his head), out of the platform: the pips
	// of an apple fly along the row through the walls
	function rowExposure(s:GSeg):Float {
		var n = 0.0;
		for (y in s.y - 1...s.y + 1)
			if (y >= 0)
				for (x in 0...W)
					if (!(x >= s.x0 && x <= s.x1))
						n += wt(x, y);
		return n;
	}

	// Igor on the platform itself (walking there: the mines of the kiwis, the cherries in his way)
	function ownExposure(s:GSeg):Float {
		var n = 0.0;
		for (x in s.x0...s.x1 + 1)
			n += wt(x, s.y) + wt(x, s.y - 1) * 0.5;
		return n;
	}

	// a pear throws its bomb up and forward (45 degrees, falling 3 to 9 cases ahead): the cases of Igor under the
	// way of its bombs, on the sides of the platform that are open
	function lobExposure(s:GSeg):Float {
		var m = g.m;
		var n = 0.0;
		for (d in [-1, 1]) {
			var ex = d < 0 ? s.x0 : s.x1;
			// (a wall just in front stops the bomb)
			var open = true;
			for (k in 1...3)
				for (r in s.y - 2...s.y + 1)
					if (g.inb(ex + d * k, r) && m[ex + d * k][r] > 0)
						open = false;
			if (!open)
				continue;
			var xa = ex + d * 2;
			var xb = ex + d * 9;
			n += igorIn(Std.int(Math.min(xa, xb)), s.y - 1, Std.int(Math.max(xa, xb)), s.y + 9);
		}
		return n;
	}

	// cases of Igor near the line between two places (the ball of the strawberries goes straight through the walls)
	function lineExposure(ax:Int, ay:Int, bx:Int, by:Int):Float {
		var n = 0.0;
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
					if (g.inb(cx, cy) && !seen.exists(cx * 32 + cy)) {
						seen.set(cx * 32 + cy, true);
						n += wt(cx, cy);
					}
				}
		}
		return n;
	}

	// ---------------------------------------------------------------- places allowed

	static function shooter(id:Int):Bool {
		return id == Data.BAD_POMME || id == Data.BAD_POIRE || id == Data.BAD_CITRON || id == Data.BAD_FRAISE
			|| id == Data.BAD_KIWI || id == Data.BAD_FRAMBOISE;
	}

	// (never a spot of one case: a walker there walks off it at once, IA_SMALL_SPOT in Bad.onFall; players saw two
	// strawberries put on the tops of two pillars come down)
	static function minLen(id:Int):Int {
		return switch (id) {
			case Data.BAD_ANANAS: 4;
			case Data.BAD_KIWI, Data.BAD_LITCHI: 3;
			case Data.BAD_POMME, Data.BAD_ABRICOT: 3;
			default: 2;
		}
	}

	// the platform k can take a bad of this kind
	function allowed(id:Int, k:Int):Bool {
		var s = segs[k];
		var f = inf[k];
		if (f.len < minLen(id) && id != Data.BAD_CRAWLER)
			return false;
		if (used[k] >= room(f.len))
			return false;
		if (g.isNoBad(s) || g.spikesNear(s))
			return false;
		// (frozen there, it must be kicked out of the level: no bad shut in a cup, unless a laser of black bombs on the
		// way of Igor kills it; the bombs blow up by themselves)
		if (!killer && !f.escape && id != Data.BAD_BOMBE)
			return false;
		// far from the place where Igor lands at the start
		if (Math.abs(s.y - landY) <= 2 && s.x1 >= g.px - 4 && s.x0 <= g.px + 4)
			return false;
		// Igor comes in falling anywhere: no bad on the first ground of the columns of the top, no shooter on its rows
		if (s.y <= topLand + 1 && (shooter(id) || s.y == topLand))
			return false;
		// (a pear in a box: a ceiling low over it and walls at both ends, or a corner of the bottom floor under a ledge:
		// nothing reaches it from outside, Igor has to come into the blast of its bombs (4 cases) to get it out, a life
		// lost: never; pears are high, on balconies)
		if (id == Data.BAD_POIRE && f.head <= 3 && ((f.wallL && f.wallR) || (s.y >= H - 2 && (f.wallL || f.wallR))))
			return false;
		if (id == Data.BAD_CRAWLER && !(s.x0 > 0 && g.gr(s.x0 - 1, s.y) && g.gr(s.x0 - 1, s.y - 1))
			&& !(s.x1 < W - 1 && g.gr(s.x1 + 1, s.y) && g.gr(s.x1 + 1, s.y - 1)))
			return false;
		return true;
	}

	// how many bads a platform can take (a bad every 4 cases)
	static inline function room(len:Int):Int {
		return len <= 6 ? 1 : (len <= 10 ? 2 : (len <= 14 ? 3 : 4));
	}

	// a wall of the level at an end of the platform (not the side of the screen)
	function inner(s:GSeg):Bool {
		return (s.x0 > 0 && g.gr(s.x0 - 1, s.y)) || (s.x1 < W - 1 && g.gr(s.x1 + 1, s.y));
	}

	// ---------------------------------------------------------------- what each kind likes

	// the liking of a kind for a platform; ideal(): a good place gets about it
	function liking(id:Int, k:Int):Float {
		var s = segs[k];
		var f = inf[k];
		var len = f.len;
		var low = s.y >= H / 2 ? 1.0 : 0.0;
		var r = f.reached ? 1.0 : 0.0;
		return switch (id) {
			case Data.BAD_CERISE:
				2 * r + Math.min(6, len - 2) * 0.6 + (len <= 3 ? -1.5 : 0) + (inner(s) ? 0.5 : 0) + 0.08 * Math.min(25, f.own);
			case Data.BAD_ORANGE:
				2.5 * Math.min(2, f.hop) + 1.5 * r + ((len >= 2 && len <= 6) ? 1 : 0) - (f.hop == 0 ? 2 : 0) + 0.05 * Math.min(25, f.own);
			case Data.BAD_POMME:
				0.08 * Math.min(60, rowExposure(s)) + 1.5 * r + (len >= 4 ? 1 : 0);
			case Data.BAD_BANANE:
				0.12 * Math.min(40, f.zone) + low + r;
			case Data.BAD_CITRON:
				0.06 * Math.min(80, columnsExposure(s)) + (s.y >= H - 6 ? 1 : 0) + ((len >= 2 && len <= 9) ? 0.5 : 0);
			case Data.BAD_BOMBE:
				var stairs = false;
				for (o in segs)
					if (o != s && Math.abs(o.y - s.y) >= 1 && Math.abs(o.y - s.y) <= 3 && o.x0 <= s.x1 + 3 && o.x1 >= s.x0 - 3)
						stairs = true;
				// (in a narrow place: walls at its ends, a ceiling low over it: Igor cannot run away from its blast)
				(len <= 4 ? 1.4 : (len <= 6 ? 0.9 : 0)) + 0.04 * Math.min(80, igorIn(s.x0 - 5, s.y - 5, s.x1 + 5, s.y + 5))
					+ (stairs ? 1 : 0) + (f.wallL ? 0.6 : 0) + (f.wallR ? 0.6 : 0) + (f.head <= 3 ? 0.8 : 0);
			case Data.BAD_POIRE:
				0.05 * Math.min(80, lobExposure(s)) + 0.25 * (H - s.y) + ((len >= 2 && len <= 6) ? 1 : 0)
					- Math.min(2, f.above * 0.25) + (f.steps >= 2 ? 0.5 : 0);
			case Data.BAD_FRAISE:
				// (alone: a high ledge away from the ways of Igor, seeing the level; no bomb from above reaching it, its
				// ice not out of the level at the first push)
				(len <= 3 ? 1.5 : (len <= 6 ? 1.2 : 0)) + (f.edge <= 3 ? 1 : 0) + (s.y <= H / 2 ? 1 : 0)
					+ (f.around <= 12 ? 1.5 : (f.around <= 20 ? 0.5 : 0)) + (f.reached ? 0 : 0.5)
					+ (f.above == 0 ? 1.5 : -Math.min(3, f.above * 0.4)) + (f.steps >= 2 ? 0.8 : -1);
			case Data.BAD_ABRICOT:
				1.5 * low + ((len >= 3 && len <= 7) ? 1 : 0) + ((f.wallL || f.wallR) ? 1 : 0) + r;
			case Data.BAD_KIWI:
				3 * r + 0.4 * Math.min(8, len) + low + 0.03 * Math.min(40, f.around) + 0.1 * Math.min(30, f.own);
			case Data.BAD_LITCHI:
				0.4 * Math.min(8, len) + 1.5 * r + ((f.wallL && f.wallR) ? 0.5 : 0) + 0.05 * Math.min(25, f.own);
			case Data.BAD_ANANAS:
				var c = (s.x0 + s.x1) / 2;
				0.5 * Math.min(8, len) + low + 1.5 * (1 - Math.abs(c - 8.5) / 9) + 0.2 * Math.min(5, f.head) + 1.5 * r;
			case Data.BAD_FRAMBOISE:
				r + 0.3 * Math.min(6, len) + 0.5 * low;
			default:
				1 + 0.15 * len;
		}
	}

	// (about the best liking a kind finds in the levels made: measured on 200 levels, the median of the best places
	// a little raised)
	static function ideal(id:Int):Float {
		return switch (id) {
			case Data.BAD_CERISE: 4.3;
			case Data.BAD_ORANGE: 5.5;
			case Data.BAD_POMME: 3.8;
			case Data.BAD_BANANE: 6.5;
			case Data.BAD_CITRON: 3.3;
			case Data.BAD_BOMBE: 4.6;
			case Data.BAD_POIRE: 5.0;
			case Data.BAD_FRAISE: 5.5;
			case Data.BAD_ABRICOT: 5.0;
			case Data.BAD_KIWI: 7.5;
			case Data.BAD_LITCHI: 4.5;
			case Data.BAD_ANANAS: 8.5;
			case Data.BAD_FRAMBOISE: 3.2;
			case Data.BAD_CRAWLER: 1.5;
			default: 3.0;
		}
	}

	// the same kind around: each apple its row, each lemon its columns, the pears and the others apart
	function together(id:Int, k:Int, x:Int):Float {
		var s = segs[k];
		var v = 0.0;
		// (the dangerous ones not where the ice of another one goes, nor the other one where theirs goes: one push would
		// kill both)
		if (dangerous(id))
			for (i in 0...placed.length) {
				var p = placed[i];
				if (!dangerous(p.id))
					continue;
				if (inf[k].line.indexOf(p.x * 32 + p.y) >= 0 || inf[placedK[i]].line.indexOf(x * 32 + s.y) >= 0)
					v -= id == Data.BAD_FRAISE && p.id == Data.BAD_FRAISE ? 6 : 2.5;
			}
		for (p in placed) {
			var mirror = g.sym && p.y == s.y && p.x == W - 1 - x;
			if (!mirror && Math.abs(p.y - s.y) <= 1 && p.x >= s.x0 - 3 && p.x <= s.x1 + 3)
				v -= p.id == id && id == Data.BAD_BOMBE ? 0.5 : 2;
			if (p.id != id || mirror)
				continue;
			switch (id) {
				case Data.BAD_POMME:
					if (Math.abs(p.y - s.y) <= 1)
						v -= 2.5;
				case Data.BAD_CITRON:
					if (p.x >= s.x0 - 1 && p.x <= s.x1 + 1)
						v -= 2.5;
				case Data.BAD_POIRE, Data.BAD_ABRICOT, Data.BAD_KIWI, Data.BAD_LITCHI:
					if (Math.abs(p.x - x) + Math.abs(p.y - s.y) <= 5)
						v -= 1.5;
				default:
			}
		}
		return v;
	}

	// ---------------------------------------------------------------- placing

	#if gentest
	// (test harness: each strawberry placed: bombed from above, pushes of its ice, its row, another strawberry in its ice)
	public static var straw:Array<Array<Int>> = [];
	public static var strawAvail:Array<String> = [];
	#end

	function put(id:Int, k:Int, x:Int, v:Float) {
		var s = segs[k];
		#if gentest
		if (id == Data.BAD_FRAISE) {
			var conflict = 0;
			for (i in 0...placed.length)
				if (placed[i].id == Data.BAD_FRAISE
					&& (inf[k].line.indexOf(placed[i].x * 32 + placed[i].y) >= 0 || inf[placedK[i]].line.indexOf(x * 32 + s.y) >= 0))
					conflict = 1;
			straw.push([inf[k].above, inf[k].steps, s.y, conflict, g.depth]);
		}
		#end
		used[k]++;
		g.bads.push({id: id, x: x, y: s.y});
		g.mark(x, s.y);
		placed.push({id: id, x: x, y: s.y});
		placedK.push(k);
		fitAdd(id, v);
	}

	var leadId:Int = -1;
	var fitN:Int = 0;
	var leadN:Int = 0;

	function fitAdd(id:Int, v:Float) {
		var f = Math.max(0, Math.min(1.2, v / ideal(id)));
		fit += f;
		fitN++;
		if (id == leadId) {
			leadFit += f;
			leadN++;
		}
	}

	// a free case of a platform for a bad, at least 5 cases from the place where Igor lands at the start
	function cell(k:Int, id:Int):Int {
		var s = segs[k];
		var c = [for (x in s.x0...s.x1 + 1)
			if (!g.busy[x][s.y] && !g.busy[x][s.y - 1 >= 0 ? s.y - 1 : 0] && g.m[x][s.y] == 0
				&& Math.abs(x - g.px) + Math.abs(s.y - landY) >= 5 && !crowded(x, s.y)) x];
		if (c.length == 0)
			return -1;
		var len = s.x1 - s.x0 + 1;
		// (a pear at the end of its platform facing the open middle of the level, where its bombs fall; a strawberry
		// at the far end of a long floor, against the side: A69; others in the middle of a small platform)
		if (id == Data.BAD_POIRE || (id == Data.BAD_FRAISE && len >= 4)) {
			var mid = 8.5;
			var best = c[0];
			for (x in c)
				if ((id == Data.BAD_POIRE) == (Math.abs(x - mid) < Math.abs(best - mid)))
					best = x;
			return best;
		}
		if (len <= 4)
			return c[Std.int(c.length / 2)];
		return c[g.rnd(c.length)];
	}

	// another bad standing less than 3 cases away on the row
	function crowded(x:Int, y:Int):Bool {
		for (p in placed)
			if (p.y == y && Math.abs(p.x - x) < 3)
				return true;
		return false;
	}

	// the mirror case of a bad in a symmetric level, when it is free and on a platform allowed
	function mirrorOf(id:Int, k:Int, x:Int):{k:Int, x:Int} {
		var s = segs[k];
		var mx = W - 1 - x;
		if (mx == x || g.busy[mx][s.y] || !g.canStand(mx, s.y))
			return null;
		for (j in 0...segs.length)
			if (segs[j].y == s.y && segs[j].x0 <= mx && segs[j].x1 >= mx) {
				if (j == k && inf[k].len < 9)
					return null;
				if (j != k && !allowed(id, j))
					return null;
				return {k: j, x: mx};
			}
		return null;
	}

	#if gentest
	public static var debugKind:Int = -1;
	public static var debugOut:Array<String> = [];

	function debugTable(id:Int) {
		var rows = [];
		for (k in 0...segs.length) {
			var s = segs[k];
			var f = inf[k];
			var why = allowed(id, k) ? "ok" : "no";
			if (why == "no") {
				if (f.len < minLen(id))
					why = "len";
				else if (!killer && !f.escape)
					why = "shut";
				else if (Math.abs(s.y - landY) <= 2 && s.x1 >= g.px - 4 && s.x0 <= g.px + 4)
					why = "start";
				else if (s.y <= topLand + 1)
					why = "top";
				else if (g.isNoBad(s) || g.spikesNear(s))
					why = "haz";
			}
			rows.push('  y${s.y} x${s.x0}-${s.x1} len${f.len} reach${f.reached ? 1 : 0} esc${f.escape ? 1 : 0} edge${f.edge} hop${f.hop} around${f.around} zone${f.zone} like=${Math.round(liking(id, k) * 100) / 100} $why');
		}
		debugOut.push('kind $id depth ${g.depth} ${g.kind}
' + rows.join("
"));
	}
	#end

	// the best platform for a bad of this kind (-1: none)
	function best(id:Int):{k:Int, v:Float} {
		var bk = -1;
		var bv = -1.0e9;
		for (k in 0...segs.length) {
			if (!allowed(id, k))
				continue;
			var s = segs[k];
			var v = liking(id, k) + together(id, k, (s.x0 + s.x1) >> 1) - used[k] * 2 + g.rnd(100) / 80;
			// (the first levels: the bads spread over the floors, every floor of the level with a use; players: "intérêt
			// des plateformes au-dessus avec les oranges toutes en bas ?")
			if (g.depth <= LevelDesign.EASY_DEPTH)
				for (p in placed)
					if (p.y == s.y)
						v -= 4;
			if (hints != null)
				for (h in hints)
					if (h.y == s.y && h.x >= s.x0 && h.x <= s.x1) {
						v += 1.2;
						break;
					}
			if (v > bv) {
				bv = v;
				bk = k;
			}
		}
		return bk < 0 ? null : {k: bk, v: bv};
	}

	// n bads of a kind, one after the other at the best places (by pairs in the symmetric levels)
	function placeKind(id:Int, n:Int) {
		var i = 0;
		var guard = 0;
		while (i < n && guard++ < 30) {
			var b = best(id);
			if (b == null) {
				g.missing += n - i;
				return;
			}
			var x = cell(b.k, id);
			if (x < 0) {
				used[b.k] = 9;
				continue;
			}
			var v = liking(id, b.k);
			put(id, b.k, x, v);
			i++;
			// (by mirrored pairs on a row; not in the first levels with few of them: one a floor)
			if (g.sym && i < n && id != Data.BAD_ANANAS && (g.depth > LevelDesign.EASY_DEPTH || n >= 4) && g.chance(0.6)) {
				var mr = mirrorOf(id, b.k, x);
				if (mr != null) {
					put(id, mr.k, mr.x, liking(id, mr.k));
					i++;
				}
			}
		}
		if (i < n)
			g.missing += n - i;
	}

	// a place for a strawberry with the ones already there: on the other side of the level
	// (their ball across it), never on the same side less than 6 cases away (the ball along the side), far from the middle
	function formation(x:Int, y:Int):Float {
		var v = 0.0;
		for (p in placed)
			if (p.id == Data.BAD_FRAISE) {
				var dx = Math.abs(p.x - x);
				if (dx <= 5)
					v -= Math.abs(p.y - y) < 4 ? 8 : 4;
				else if (dx >= 10)
					v += 2;
			}
		return v - (x >= 6 && x <= 11 ? 1.5 : 0);
	}

	// strawberries: n of them on ledges far apart, the lines of their ball crossing the places of Igor (one alone: see
	// liking)
	function placeStrawberries(n:Int) {
		if (n <= 1) {
			if (n == 1)
				placeSniper();
			return;
		}
		var c = [for (k in 0...segs.length) if (allowed(Data.BAD_FRAISE, k)) k];
		#if gentest
		var a0 = 0;
		var a2 = 0;
		for (k in c) {
			if (inf[k].above == 0)
				a0++;
			if (inf[k].above <= 2)
				a2++;
		}
		strawAvail.push(g.kind + " " + g.depth + " n" + n + " cand" + c.length + " a0=" + a0 + " a2=" + a2);
		#end
		// (not in the rows where Igor comes in, when there are other places: he would bomb them as he arrives)
		var low = [for (k in c) if (segs[k].y > landY + 3) k];
		if (low.length >= n + 1)
			c = low;
		// one case per platform: the end facing the middle of the level
		var cx = [for (k in c) cell(k, Data.BAD_FRAISE)];
		var ok = [for (i in 0...c.length) cx[i] >= 0];
		// the way of Igor to each of them (to a place he drops a bomb there from), without its end by the strawberry
		var approach:Array<Array<Int>> = [for (i in 0...c.length) {
			var sg = segs[c[i]];
			var w = ok[i] ? g.routes.wayNear([for (x in sg.x0...sg.x1 + 1) {x: x, y: sg.y}], 2, 2) : null;
			w == null ? [] : [for (k in w) if (Math.abs(Std.int(k / H) - cx[i]) > 2 || Math.abs(k % H - sg.y) > 2) k];
		}];
		// (going to the strawberry i, Igor crosses the line of the ball between a and b)
		function crosses(i:Int, a:Int, b:Int):Bool {
			return LevelRoutes.nearLine(approach[i], cx[a], segs[c[a]].y - 0.5, cx[b], segs[c[b]].y - 0.5, 1.0) > 0;
		}
		function own(i:Int):Float {
			var s = segs[c[i]];
			var f = inf[c[i]];
			return formation(cx[i], s.y) + (f.len <= 3 ? 1.5 : (f.len <= 6 ? 1.2 : 0)) + (f.edge <= 1 ? 1.5 : (f.edge <= 3 ? 1 : 0))
				+ (f.around <= 16 ? 1 : 0) + together(Data.BAD_FRAISE, c[i], cx[i]) * 0.5 + Math.min(1.5, f.far / 6)
				// (out of the reach of the bombs from above, far from where Igor comes in (many moves to get there), its ice
				// not out at the first push, rather high)
				+ (f.above == 0 ? 4 : -Math.min(8, 1 + f.above * 0.8)) + (f.steps >= 2 ? 1 : -1.5) + Math.min(3, f.far / 3)
				// (not in the rows where Igor comes in: he would bomb them as he arrives; not at the very bottom either)
				- (s.y <= landY + 3 ? 4 : 0) - (s.y >= H - 2 ? 1.5 : 0);
		}
		function pair(i:Int, j:Int):Float {
			var a = segs[c[i]];
			var b = segs[c[j]];
			if (c[i] == c[j])
				return -100;
			var dx = Math.abs(cx[i] - cx[j]);
			var dy = Math.abs(a.y - b.y);
			var v = 0.18 * Math.min(18, dx + dy * 0.8) + 0.04 * Math.min(80, lineExposure(cx[i], a.y, cx[j], b.y));
			// (they guard each other: to reach one of them, Igor goes across the way of their ball)
			var ci = crosses(i, i, j);
			var cj = crosses(j, i, j);
			v += (ci ? 3.5 : 0) + (cj ? 3.5 : 0) - (!ci && !cj ? 2 : 0);
			// (never one in the way of the ice of the other: frozen and pushed, it would kill it)
			if (inf[c[i]].line.indexOf(cx[j] * 32 + b.y) >= 0 || inf[c[j]].line.indexOf(cx[i] * 32 + a.y) >= 0)
				return -100;
			// (not on the same side of the screen: the ball would fly along a wall; across the level: good)
			if (dx <= 5)
				v -= dy <= 3 ? 6 : 4;
			else if (dx >= 10)
				v += 1.5;
			// (a symmetric level: the mirror ledges)
			if (g.sym && a.y == b.y && cx[i] == W - 1 - cx[j])
				v += 1.5;
			return v;
		}
		var setBest:Array<Int> = null;
		var vBest = -1.0e9;
		for (i in 0...c.length)
			for (j in i + 1...c.length) {
				if (!ok[i] || !ok[j])
					continue;
				var v = own(i) + own(j) + pair(i, j) + g.rnd(100) / 100;
				if (v > vBest) {
					vBest = v;
					setBest = [i, j];
				}
			}
		if (setBest == null) {
			placeKind(Data.BAD_FRAISE, n);
			return;
		}
		// more of them: the one that adds the most to the set
		while (setBest.length < n) {
			var bi = -1;
			var bv = -1.0e9;
			for (i in 0...c.length) {
				if (!ok[i] || setBest.indexOf(i) >= 0)
					continue;
				var same = false;
				for (j in setBest)
					if (c[j] == c[i])
						same = true;
				if (same)
					continue;
				var v = own(i);
				var clash = false;
				for (j in setBest) {
					var pv = pair(i, j);
					if (pv <= -100)
						clash = true;
					v += pv / setBest.length;
				}
				if (clash)
					continue;
				if (v > bv) {
					bv = v;
					bi = i;
				}
			}
			if (bi < 0)
				break;
			setBest.push(bi);
		}
		for (i in setBest) {
			var s = segs[c[i]];
			if (g.busy[cx[i]][s.y])
				continue;
			// (none by a strawberry placed: better one less)
			if (formation(cx[i], s.y) <= -4) {
				g.missing++;
				continue;
			}
			// (its fit: a ledge apart, its ball across the level and across the way to it)
			var v = own(i) + 1.5;
			for (j in setBest)
				if (j != i)
					v += pair(i, j) / (setBest.length - 1);
			var guarded = false;
			for (a in setBest)
				for (b in setBest)
					if (a < b && crosses(i, a, b))
						guarded = true;
			guardedN += guarded ? 1 : 0;
			put(Data.BAD_FRAISE, c[i], cx[i], v);
		}
		g.missing += n - setBest.length;
	}

	// a strawberry alone: it throws its ball at Igor wherever he is (through the walls); on a small perch high up, apart
	// from everything (nobody around, few ways of Igor near it), far from where he comes in (many moves to get there)
	function placeSniper() {
		var bk = -1;
		var bv = -1.0e9;
		for (k in 0...segs.length) {
			if (!allowed(Data.BAD_FRAISE, k))
				continue;
			var s = segs[k];
			var f = inf[k];
			var v = liking(Data.BAD_FRAISE, k) + Math.min(3, f.far / 4) + (s.y <= H / 2 ? 1 : 0) - Math.min(3, f.around * 0.08)
				+ together(Data.BAD_FRAISE, k, (s.x0 + s.x1) >> 1) + g.rnd(100) / 100 + (f.above == 0 ? 3 : -Math.min(4, 1 + f.above * 0.5))
				+ formation((s.x0 + s.x1) >> 1, s.y);
			if (v > bv) {
				bv = v;
				bk = k;
			}
		}
		// (no strawberry by another one: better one less, LevelGen.rate takes the missing ones)
		if (bk < 0 || formation((segs[bk].x0 + segs[bk].x1) >> 1, segs[bk].y) <= -4) {
			g.missing++;
			return;
		}
		var x = cell(bk, Data.BAD_FRAISE);
		if (x < 0) {
			g.missing++;
			return;
		}
		put(Data.BAD_FRAISE, bk, x, liking(Data.BAD_FRAISE, bk) + 1);
	}

	// a row of bads of the same kind on a long floor (a frozen one kicked into the others kills them all: a combo, like
	// the cherries of A10, the lemons of the Hells)
	function placeRow(id:Int, n:Int):Int {
		var cands = [];
		for (k in 0...segs.length) {
			var s = segs[k];
			var f = inf[k];
			if (f.len < 7 || used[k] > 0 || !allowed(id, k) || s.y <= topLand + 1 || (g.sym && s.x0 + s.x1 != W - 1))
				continue;
			if (!f.escape && !killer)
				continue;
			cands.push(k);
		}
		if (cands.length == 0)
			return 0;
		// (the best of them for the kind)
		var bk = cands[0];
		for (k in cands)
			if (liking(id, k) > liking(id, bk))
				bk = k;
		var s = segs[bk];
		var len = s.x1 - s.x0 + 1;
		var cnt = Std.int(Math.min(n, len >= 10 ? 4 : 3));
		var pos:Array<Int> = [];
		if (g.sym) {
			cnt = cnt >= 4 ? 4 : 2;
			var gap = len >= 12 ? 3 : 2;
			for (j in 0...(cnt >> 1)) {
				pos.push(s.x0 + 1 + j * gap);
				pos.push(s.x1 - 1 - j * gap);
			}
		} else {
			var step = (len - 3) / (cnt - 1);
			for (j in 0...cnt)
				pos.push(s.x0 + 1 + Math.round(j * step));
		}
		for (x in pos)
			if (g.busy[x][s.y] || g.m[x][s.y] != 0 || Math.abs(x - g.px) + Math.abs(s.y - landY) < 5)
				return 0;
		var v = liking(id, bk) + 1;
		for (x in pos)
			put(id, bk, x, v);
		used[bk] = 9;
		return pos.length;
	}

	// bads of the lineup in a room (the vault): 2 or 3, the kinds fitting a room
	// first (the ones walking and jumping there, the bombs), then the lead kind
	function placeIn(r:LevelGen.GVault, num:Map<Int, Int>) {
		var ks = [for (k in 0...segs.length) if (segs[k].y >= r.top && segs[k].y <= r.y && segs[k].x0 >= r.x0 && segs[k].x1 <= r.x1) k];
		if (ks.length == 0)
			return;
		var roomy = [Data.BAD_ABRICOT, Data.BAD_KIWI, Data.BAD_LITCHI, Data.BAD_BOMBE, Data.BAD_ANANAS, Data.BAD_CERISE,
			Data.BAD_POMME, Data.BAD_BANANE, Data.BAD_CITRON, Data.BAD_ORANGE, Data.BAD_FRAMBOISE, Data.BAD_POIRE];
		var want = 2 + g.rnd(2);
		var done = 0;
		for (id in roomy) {
			if (done >= want)
				break;
			if (!num.exists(id) || num.get(id) <= 0)
				continue;
			var take = Std.int(Math.min(num.get(id), want - done));
			for (t in 0...take) {
				var bk = -1;
				var bv = -1.0e9;
				for (k in ks) {
					if (!allowed(id, k))
						continue;
					var v = liking(id, k) + together(id, k, (segs[k].x0 + segs[k].x1) >> 1) - used[k] * 2;
					if (v > bv) {
						bv = v;
						bk = k;
					}
				}
				if (bk < 0)
					break;
				var x = cell(bk, id);
				if (x < 0) {
					used[bk] = 9;
					continue;
				}
				put(id, bk, x, ideal(id));
				num.set(id, num.get(id) - 1);
				done++;
			}
		}
	}

	// ---------------------------------------------------------------- the lineup of the level

	public function place(lineup:LevelCast.Cast):Bool {
		analyse();
		placed = [];
		placedK = [];
		leadId = lineup.lead;
		// (with a laser of black bombs on the way, the bads shut between walls can be killed)
		killer = g.killerLaser();
		// the kinds and their numbers, the lead first, then the ones needing the most special places
		var kinds:Array<Int> = [];
		var num = new Map<Int, Int>();
		for (id in lineup.list) {
			if (!num.exists(id)) {
				kinds.push(id);
				num.set(id, 0);
			}
			num.set(id, num.get(id) + 1);
		}
		// the vault: bads shut in there first; the nest: a strawberry (else a pear) up there
		if (g.vault != null)
			placeIn(g.vault, num);
		if (g.nest != null)
			for (id in [Data.BAD_FRAISE, Data.BAD_POIRE])
				if (num.exists(id) && num.get(id) > 0) {
					var k = -1;
					for (j in 0...segs.length)
						if (segs[j].y == g.nest.y && segs[j].x0 <= g.nest.x1 && segs[j].x1 >= g.nest.x0)
							k = j;
					var x = k >= 0 ? cell(k, id) : -1;
					if (x >= 0) {
						put(id, k, x, ideal(id) * 1.2);
						num.set(id, num.get(id) - 1);
					}
					break;
				}
		// the bads drawn for places of the level
		for (p in spots) {
			if (!num.exists(p.id) || num.get(p.id) <= 0)
				continue;
			for (k in 0...segs.length) {
				var s = segs[k];
				if (s.y == p.y && p.x >= s.x0 && p.x <= s.x1 && !g.busy[p.x][p.y]) {
					put(p.id, k, p.x, ideal(p.id));
					num.set(p.id, num.get(p.id) - 1);
					break;
				}
			}
		}
		var order = [Data.BAD_FRAISE, Data.BAD_ANANAS, Data.BAD_POIRE, Data.BAD_CITRON, Data.BAD_KIWI, Data.BAD_ORANGE,
			Data.BAD_POMME, Data.BAD_BOMBE, Data.BAD_ABRICOT, Data.BAD_LITCHI, Data.BAD_BANANE, Data.BAD_FRAMBOISE,
			Data.BAD_CERISE, Data.BAD_CRAWLER];
		var rowDone = false;
		kinds.sort(function(a, b) {
			if ((a == lineup.lead) != (b == lineup.lead))
				return a == lineup.lead ? -1 : 1;
			return order.indexOf(a) - order.indexOf(b);
		});
		for (id in kinds) {
			var n = num.get(id);
			if (n <= 0)
				continue;
			#if gentest
			if (id == debugKind || debugKind == -2)
				debugTable(id);
			#end
			if (id == Data.BAD_FRAISE) {
				placeStrawberries(n);
				continue;
			}
			// (rows of the same bads on a long floor: the cherries, oranges, lemons, bananas, litchis of the original)
			var rowKind = id == Data.BAD_CERISE || id == Data.BAD_ORANGE || id == Data.BAD_CITRON || id == Data.BAD_BANANE
				|| id == Data.BAD_LITCHI;
			if (rowKind && n >= 3 && !rowDone && g.chance(Math.min(0.45, 0.2 + g.depth * 0.02))) {
				var k = placeRow(id, n);
				n -= k;
				rowDone = k > 0;
			}
			placeKind(id, n);
		}
		count = placed.length;
		#if gentest
		if (debugKind == -2)
			debugOut.push('placed ' + [for (p in placed) p.id + "@" + p.x + "," + p.y].join(" ") + ' missing ' + g.missing + ' killer ' + killer);
		#end
		if (fitN > 0)
			fit /= fitN;
		if (leadN > 0)
			leadFit /= leadN;
		return true;
	}
}
