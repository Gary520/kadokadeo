package hammerfest;

import hammerfest.GenGrid.GenField;

// The analysis of a level drawn by the generator (Gen):
// - where Igor goes and with which bombs: he walks, steps off an edge (drifting one case a row at the start of the
//   fall), jumps 3 cases going through the platforms from under them (4 with two bombs from GenRules.JUMP_BOMBS_FROM,
//   6 bouncing on a red bomb), jumps over a hole of 1 to 3 cases, a ground beside him stops him in the air; the lasers
//   change his bombs, the teleporters move him; the states (case, bombs) he can no longer get out of the level from;
// - where each fruit goes (the moves of the original: Jumper.setJumpUp / setJumpDown / setJumpH / setClimb / setFall,
//   IA_HJUMP = 2, IA_VJUMP = 2): jump a hole of 1 or 2 cases, jump up on the ground 3 rows over, jump down through its
//   platform, climb a wall, fall off an edge;
// - where the ice of a frozen fruit goes when bombs push it (slides to a wall or an edge, falls; a red bomb throws it
//   up in the open air, a blue one drops it under its platform): out of the level or not.
class GenAnalysis {
	static inline var W = Data.LEVEL_WIDTH;
	static inline var H = Data.LEVEL_HEIGHT;
	public static inline var EXIT = -1;
	public static inline var NW = 6;
	public static inline var WHITE = 0;
	public static inline var GREEN = 1;
	public static inline var RED = 2;
	public static inline var BLACK = 3;
	public static inline var BLUE = 4;
	public static inline var NONE = 5;
	// how far across a jump goes for its height
	static var JUMP_DX = [0, 4, 3, 2, 1, 2, 2];

	public var lv:GenGrid;

	var depth:Int;
	var trick:Bool;

	public var special:Array<Int>; // laser of the case (< 0), 0: none
	public var spike:Array<Bool>; // spikes: they kill Igor, and the bads (walking or frozen) touching them
	var landing:Array<Int>; // teleporter case: where Igor comes out of the other one
	var fallCache:Array<Array<Int>>;
	var moveCache:Array<Array<Int>>;

	// states of Igor: case * NW + bombs
	public var seen:Array<Bool>;
	public var states:Array<Int>;
	public var parent:Array<Int>;
	public var dist:Array<Int>;
	public var edges:Array<Array<Int>>;
	public var exitState:Array<Bool>;
	public var exitCount:Int = 0;
	public var canExit:Array<Bool>;
	public var traps:Int = 0;
	public var reach:Array<Bool>; // cases Igor stands on (or goes through, lasers in the air)
	public var weaponsAt:Array<Int>; // bit mask of his bombs there
	public var cellDist:Array<Int>;

	public function new(lv:GenGrid, depth:Int) {
		this.lv = lv;
		this.depth = depth;
		trick = depth >= GenRules.JUMP_BOMBS_FROM;
		special = [for (i in 0...W * H) 0];
		spike = [for (i in 0...W * H) false];
		for (b in lv.bads)
			if (b.id == Data.BAD_SPEAR) {
				spike[b.x * H + b.y] = true;
				// spikes of a ceiling: the head of Igor standing just under them touches them
				if (lv.ground(b.x, b.y - 1) && !lv.ground(b.x, b.y + 1) && b.y + 1 < H)
					spike[b.x * H + b.y + 1] = true;
			}
		landing = [for (i in 0...W * H) -1];
		for (f in lv.fields)
			for (c in f.cells)
				special[c] = f.v;
		for (p in lv.teles) {
			var la = base(p[0]);
			var lb = base(p[1]);
			// (two of the same length: Igor comes out at the same place in the other one, the game keeps it)
			var same = p[0].cells.length == p[1].cells.length;
			for (i in 0...p[0].cells.length) {
				special[p[0].cells[i]] = Data.FIELD_TELEPORT;
				landing[p[0].cells[i]] = same ? p[1].cells[i] : lb;
			}
			for (i in 0...p[1].cells.length) {
				special[p[1].cells[i]] = Data.FIELD_TELEPORT;
				landing[p[1].cells[i]] = same ? p[0].cells[i] : la;
			}
		}
		fallCache = [for (i in 0...W * H) null];
		moveCache = [for (i in 0...W * H) null];
		reachIgor();
	}

	// the lowest case of a laser: Igor comes out of a teleporter there
	static function base(f:GenField):Int {
		var b = f.cells[0];
		for (c in f.cells)
			if (GenGrid.cy(c) > GenGrid.cy(b))
				b = c;
		return b;
	}

	public static function weaponOf(v:Int):Int {
		return switch (v) {
			case -1: WHITE;
			case -2: BLACK;
			case -3: BLUE;
			case -4: GREEN;
			case -5: RED;
			case Data.FIELD_PEACE: NONE;
			default: WHITE;
		}
	}

	// ---------------------------------------------------------------- Igor

	// Igor in the air in the case (x, y): where he lands (standing cells, lasers he goes through, EXIT)
	public function fallFrom(x:Int, y:Int):Array<Int> {
		var key = x * H + y;
		if (fallCache[key] != null)
			return fallCache[key];
		var g = lv.g;
		var out:Array<Int> = [];
		function add(c:Int) {
			if (out.indexOf(c) < 0)
				out.push(c);
		}
		var frontier = [x];
		var row = y;
		var k = 0;
		while (frontier.length > 0 && row < H) {
			var next:Array<Int> = [];
			for (fx in frontier) {
				var ds = (k < 3 || k % 2 == 0) ? [-1, 0, 1] : [0];
				for (d in ds) {
					var nx = fx + d;
					if (nx < 0 || nx >= W)
						continue;
					if (d != 0) {
						if (g[nx * H + row] == 1 || spike[nx * H + row])
							continue;
						if (special[nx * H + row] != 0 || lv.stand(nx, row)) {
							add(nx * H + row);
							continue;
						}
					}
					var ny = row + 1;
					if (ny >= H) {
						add(EXIT);
						continue;
					}
					if (g[nx * H + ny] == 1 || spike[nx * H + ny])
						continue;
					if (special[nx * H + ny] != 0 || lv.stand(nx, ny)) {
						add(nx * H + ny);
						continue;
					}
					if (next.indexOf(nx) < 0)
						next.push(nx);
				}
			}
			frontier = next;
			row++;
			k++;
		}
		fallCache[key] = out;
		return out;
	}

	// moves from a case: triples (case or EXIT, need: 0 nothing / 1 bombs / 2 a red bomb, bombs given or -1)
	public function movesOf(node:Int):Array<Int> {
		if (moveCache[node] != null)
			return moveCache[node];
		var x = GenGrid.cx(node);
		var y = GenGrid.cy(node);
		var g = lv.g;
		var res:Array<Int> = [];
		if (!lv.stand(x, y)) {
			// a laser in the air: Igor goes on falling
			for (dst in fallFrom(x, y))
				if (dst != node)
					{
					res.push(dst);
					res.push(0);
					res.push(-1);
				}
			moveCache[node] = res;
			return res;
		}
		// walking, stepping off an edge
		for (d in [-1, 1]) {
			var nx = x + d;
			if (nx < 0 || nx >= W || g[nx * H + y] == 1 || spike[nx * H + y])
				continue;
			if (lv.stand(nx, y) || special[nx * H + y] != 0) {
				res.push(nx * H + y);
				res.push(0);
				res.push(-1);
			} else
				for (dst in fallFrom(nx, y))
					{
					res.push(dst);
					res.push(0);
					res.push(-1);
				}
		}
		// jumps up (through the platforms)
		for (dy in 1...GenRules.JUMP_RED + 1) {
			var ay = y - dy;
			if (ay < 0)
				break;
			var need = dy <= GenRules.JUMP ? 0 : (dy <= GenRules.JUMP_BOMBS ? 1 : 2);
			if (need == 1 && !trick)
				need = 2;
			if (g[x * H + ay] == 1 || spike[x * H + ay])
				continue;
			var hurt = false;
			for (k in 1...dy + 1)
				if (spike[x * H + y - k])
					hurt = true;
			if (hurt)
				continue;
			var tele = -1;
			var wcol = -1;
			for (k in 1...dy + 1) {
				var c = x * H + y - k;
				var sp = special[c];
				if (sp == Data.FIELD_TELEPORT) {
					tele = c;
					break;
				}
				if (sp < 0)
					wcol = weaponOf(sp);
			}
			if (tele >= 0) {
				res.push(tele);
				res.push(need);
				res.push(-1);
				continue;
			}
			if (lv.stand(x, ay)) {
				res.push(x * H + ay);
				res.push(need);
				res.push(wcol);
			}
			for (d in [-1, 1]) {
				var ws = wcol;
				for (i in 1...JUMP_DX[dy] + 1) {
					var tx = x + d * i;
					if (tx < 0 || tx >= W || g[tx * H + ay] == 1 || spike[tx * H + ay])
						break;
					var sp = special[tx * H + ay];
					if (sp == Data.FIELD_TELEPORT) {
						res.push(tx * H + ay);
						res.push(need);
						res.push(-1);
						break;
					}
					if (sp < 0)
						ws = weaponOf(sp);
					if (lv.stand(tx, ay)) {
						res.push(tx * H + ay);
						res.push(need);
						res.push(ws);
					}
				}
			}
		}
		// jumps ahead: over a hole, or to fall further
		for (d in [-1, 1]) {
			if (x + d < 0 || x + d >= W || g[(x + d) * H + y] == 1 || y - 1 < 0)
				continue;
			for (i in 1...5) {
				var tx = x + d * i;
				if (tx < 0 || tx >= W || g[tx * H + y - 1] == 1 || spike[tx * H + y - 1])
					break;
				if (i == 1)
					continue;
				if (g[tx * H + y] == 1)
					break;
				if (spike[tx * H + y])
					continue;
				if (lv.stand(tx, y) || special[tx * H + y] != 0) {
					var walked = true;
					for (j in 1...i)
						if (!lv.stand(x + d * j, y))
							walked = false;
					if (!walked) {
						res.push(tx * H + y);
						res.push(0);
						res.push(-1);
					}
					break;
				}
				for (dst in fallFrom(tx, y))
					{
					res.push(dst);
					res.push(0);
					res.push(-1);
				}
			}
		}
		moveCache[node] = res;
		return res;
	}

	function reachIgor() {
		var n = W * H * NW;
		seen = [for (i in 0...n) false];
		parent = [for (i in 0...n) -1];
		dist = [for (i in 0...n) -1];
		exitState = [for (i in 0...n) false];
		edges = [for (i in 0...n) null];
		states = [];
		reach = [for (i in 0...W * H) false];
		weaponsAt = [for (i in 0...W * H) 0];
		cellDist = [for (i in 0...W * H) -1];
		canExit = [for (i in 0...n) false];
		if (lv.sx < 0)
			return;
		var s0 = (lv.sx * H + lv.sy) * NW + WHITE;
		seen[s0] = true;
		dist[s0] = 0;
		states.push(s0);
		var qi = 0;
		while (qi < states.length) {
			var s = states[qi++];
			var node = Std.int(s / NW);
			var w = s % NW;
			var out:Array<Int> = [];
			var mv = movesOf(node);
			var i = 0;
			while (i < mv.length) {
				var dst = mv[i];
				var need = mv[i + 1];
				var wover = mv[i + 2];
				i += 3;
				if (need == 1 && w == NONE)
					continue;
				if (need == 2 && w != RED)
					continue;
				if (dst == EXIT) {
					if (!exitState[s]) {
						exitState[s] = true;
						exitCount++;
					}
					continue;
				}
				var w2 = wover >= 0 ? wover : w;
				var sp = special[dst];
				if (sp == Data.FIELD_TELEPORT)
					dst = landing[dst];
				else if (sp < 0)
					w2 = weaponOf(sp);
				var t = dst * NW + w2;
				out.push(t);
				if (!seen[t]) {
					seen[t] = true;
					parent[t] = s;
					dist[t] = dist[s] + 1;
					states.push(t);
				}
			}
			edges[s] = out;
		}
		for (s in states) {
			var c = Std.int(s / NW);
			reach[c] = true;
			weaponsAt[c] |= 1 << (s % NW);
			if (cellDist[c] < 0 || dist[s] < cellDist[c])
				cellDist[c] = dist[s];
		}
		// the states Igor can still get out of the level from
		var rev:Array<Array<Int>> = [for (i in 0...n) null];
		for (s in states)
			for (t in edges[s]) {
				if (rev[t] == null)
					rev[t] = [];
				rev[t].push(s);
			}
		var q = [];
		for (s in states)
			if (exitState[s]) {
				canExit[s] = true;
				q.push(s);
			}
		var j = 0;
		while (j < q.length) {
			var t = q[j++];
			if (rev[t] != null)
				for (s in rev[t])
					if (!canExit[s]) {
						canExit[s] = true;
						q.push(s);
					}
		}
		traps = 0;
		for (s in states)
			if (!canExit[s])
				traps++;
	}

	// shortest way from the landing of Igor to a state of the list (states, the first one first)
	public function pathTo(pred:Int->Bool):Array<Int> {
		var best = -1;
		for (s in states)
			if (pred(s) && (best < 0 || dist[s] < dist[best]))
				best = s;
		var out = [];
		var t = best;
		while (t >= 0) {
			out.push(t);
			t = parent[t];
		}
		out.reverse();
		return out;
	}

	// ---------------------------------------------------------------- where Igor can hit the bads (with which bombs)

	var attack:Array<Array<Bool>> = null;

	public var attackAny:Array<Bool>;

	public function attackSets():Array<Array<Bool>> {
		if (attack != null)
			return attack;
		attack = [for (w in 0...NW) [for (i in 0...W * H) false]];
		var done = new Map<Int, Bool>();
		for (s in states) {
			var c = Std.int(s / NW);
			var w = s % NW;
			var x = GenGrid.cx(c);
			var y = GenGrid.cy(c);
			if (w == NONE || !lv.stand(x, y))
				continue;
			var seg = lv.segmentOf(x, y);
			var key = (seg[0] * H + seg[2]) * NW + w;
			if (done.exists(key))
				continue;
			done.set(key, true);
			var a = attack[w];
			for (sx in seg[0]...seg[1] + 1)
				a[sx * H + y] = true;
			// a bomb kicked off the edge falls and goes off where it lands
			for (ex in [seg[0] - 1, seg[1] + 1]) {
				if (ex < 0 || ex >= W || lv.g[ex * H + y] == 1)
					continue;
				var land = dropPoint(ex, y);
				if (land < 0)
					continue;
				var bx = GenGrid.cx(land);
				var by = GenGrid.cy(land);
				for (xx in bx - 2...bx + 3)
					if (lv.stand(xx, by))
						a[xx * H + by] = true;
			}
		}
		// a bomb kicked in a teleporter comes out of the other one and slides on its platform
		for (p in lv.teles)
			for (k in 0...2) {
				var src = base(p[k]);
				var dst = base(p[1 - k]);
				var mask = 0;
				for (d in [-1, 1]) {
					var nx = GenGrid.cx(src) + d;
					if (nx >= 0 && nx < W)
						mask |= weaponsAt[nx * H + GenGrid.cy(src)];
				}
				mask &= ~(1 << NONE);
				if (mask == 0)
					continue;
				var dy = GenGrid.cy(dst);
				for (d in [-1, 1]) {
					var xx = GenGrid.cx(dst) + d;
					while (xx >= 0 && xx < W && lv.stand(xx, dy)) {
						for (w in 0...NW)
							if (mask & (1 << w) != 0)
								attack[w][xx * H + dy] = true;
						xx += d;
					}
				}
			}
		attackAny = [for (i in 0...W * H) false];
		for (w in 0...NW)
			if (w != NONE)
				for (i in 0...W * H)
					if (attack[w][i])
						attackAny[i] = true;
		// the green bombs push the ice like the white ones
		for (i in 0...W * H)
			if (attack[GREEN][i])
				attack[WHITE][i] = true;
		return attack;
	}

	// a bomb (or an ice) let go in (x, y) falls straight: the standing case where it stops, -1 out of the level
	public function dropPoint(x:Int, y:Int):Int {
		var g = lv.g;
		while (y + 1 < H) {
			if (g[x * H + y + 1] == 1)
				return g[x * H + y] == 1 ? -1 : x * H + y;
			y++;
		}
		return -1;
	}

	// ---------------------------------------------------------------- fruits: where they go

	// moves of each kind: jump across (holes of 1-2), jump up, jump down, climb (height), fall, teleport
	public static function caps(id:Int):Array<Int> {
		return switch (id) {
			case Data.BAD_ORANGE, Data.BAD_CITRON, Data.BAD_ANANAS: [1, 0, 0, 0, 0, 0];
			case Data.BAD_POIRE: [1, 0, 0, 1, 0, 0];
			case Data.BAD_POMME: [1, 1, 0, 1, 1, 0];
			case Data.BAD_ABRICOT: [1, 1, 0, 3, 1, 0];
			case Data.BAD_BANANE: [1, 1, 1, 4, 1, 0];
			case Data.BAD_BOMBE, Data.BAD_KIWI: [1, 1, 1, 3, 0, 0];
			case Data.BAD_LITCHI: [1, 1, 1, 3, 1, 0];
			case Data.BAD_FRAMBOISE: [1, 1, 1, 3, 1, 1];
			default: [0, 0, 0, 0, 0, 0]; // cherry, strawberry: back and forth on their platform
		}
	}

	public static inline function walks(id:Int):Bool {
		return id != Data.BAD_CRAWLER && id != Data.BAD_SAW && id != Data.BAD_BALEINE && id != Data.BAD_SPEAR;
	}

	function fruitMoves(x:Int, y:Int, cp:Array<Int>, out:Array<Int>) {
		var g = lv.g;
		for (d in [-1, 1]) {
			var nx = x + d;
			if (nx < 0 || nx >= W)
				continue;
			if (g[nx * H + y] == 1) {
				// climbing a wall
				var c = cp[3];
				if (c > 0) {
					var h = 0;
					while (y - h >= 0 && lv.ground(nx, y - h))
						h++;
					if (h <= c && lv.stand(nx, y - h)) {
						var free = true;
						for (k in 1...h + 1)
							if (lv.ground(x, y - k))
								free = false;
						if (free)
							out.push(nx * H + y - h);
					}
				}
				continue;
			}
			if (lv.stand(nx, y)) {
				out.push(nx * H + y);
				continue;
			}
			// edge of the platform
			if (cp[0] == 1)
				for (gap in 1...3) {
					var lx = x + d * (gap + 1);
					var ok = true;
					for (i in 1...gap + 1) {
						var ix = x + d * i;
						if (ix < 0 || ix >= W || g[ix * H + y] == 1 || lv.stand(ix, y))
							ok = false;
					}
					if (ok && lv.stand(lx, y)) {
						out.push(lx * H + y);
						break;
					}
				}
			if (cp[4] == 1 || cp[3] > 0) {
				var land = dropPoint(nx, y);
				if (land >= 0 && (cp[4] == 1 || GenGrid.cy(land) - y <= cp[3]))
					out.push(land);
			}
		}
		if (cp[1] == 1 && y - 3 >= 0 && lv.ground(x, y - 2) && !lv.ground(x, y - 3))
			out.push(x * H + y - 3);
		if (cp[2] == 1 && lv.ground(x, y + 1) && y + 2 < H && !lv.ground(x, y + 2)) {
			var land = dropPoint(x, y + 2);
			if (land >= 0)
				out.push(land);
		}
	}

	var zoneCache = new Map<String, Array<Int>>();

	// standing cells a bad put in the case can go to (in the air for a leaper, around its block for a crawler)
	public function zone(id:Int, cell:Int):Array<Int> {
		var x = GenGrid.cx(cell);
		var y = GenGrid.cy(cell);
		if (id == Data.BAD_BALEINE)
			return airZone(cell);
		if (id == Data.BAD_CRAWLER || id == Data.BAD_SAW)
			return crawlZone(cell);
		var seg = lv.segmentOf(x, y);
		if (seg == null)
			return [];
		var cp = caps(id);
		var key = cp.join("") + ":" + seg.join(",");
		if (zoneCache.exists(key))
			return zoneCache.get(key);
		var z:Array<Int> = [];
		var has = [for (i in 0...W * H) false];
		if (cp[5] == 1) {
			// the raspberry teleports: every platform of 2 cases or more
			for (s in lv.segments())
				if (s[1] > s[0])
					for (sx in s[0]...s[1] + 1) {
						z.push(sx * H + s[2]);
						has[sx * H + s[2]] = true;
					}
		} else {
			for (sx in seg[0]...seg[1] + 1) {
				z.push(sx * H + y);
				has[sx * H + y] = true;
			}
			var i = 0;
			var buf:Array<Int> = [];
			while (i < z.length) {
				var c = z[i++];
				buf.resize(0);
				fruitMoves(GenGrid.cx(c), GenGrid.cy(c), cp, buf);
				for (n in buf)
					if (!has[n]) {
						has[n] = true;
						z.push(n);
					}
			}
		}
		zoneCache.set(key, z);
		return z;
	}

	var compCache:{comp:Array<Int>, sizes:Array<Int>} = null;

	public function comps():{comp:Array<Int>, sizes:Array<Int>} {
		if (compCache == null)
			compCache = lv.components();
		return compCache;
	}

	// a crawler goes around the block of grounds by it: the empty cases around the block
	public function crawlZone(cell:Int):Array<Int> {
		var x = GenGrid.cx(cell);
		var y = GenGrid.cy(cell);
		var cc = comps();
		var k = -1;
		for (d in [[0, 1], [-1, 0], [1, 0], [0, -1]])
			if (lv.ground(x + d[0], y + d[1])) {
				k = cc.comp[(x + d[0]) * H + y + d[1]];
				break;
			}
		var z:Array<Int> = [];
		if (k < 0)
			return z;
		var has = [for (i in 0...W * H) false];
		for (c in 0...W * H)
			if (cc.comp[c] == k) {
				var px = GenGrid.cx(c);
				var py = GenGrid.cy(c);
				for (d in GenGrid.DIRS) {
					var nx = px + d[0];
					var ny = py + d[1];
					if (lv.inb(nx, ny) && lv.g[nx * H + ny] == 0 && !has[nx * H + ny]) {
						has[nx * H + ny] = true;
						z.push(nx * H + ny);
					}
				}
			}
		return z;
	}

	public function airZone(cell:Int):Array<Int> {
		var z = [cell];
		var has = [for (i in 0...W * H) false];
		has[cell] = true;
		var i = 0;
		while (i < z.length) {
			var c = z[i++];
			var px = GenGrid.cx(c);
			var py = GenGrid.cy(c);
			for (d in GenGrid.DIRS) {
				var nx = px + d[0];
				var ny = py + d[1];
				if (lv.inb(nx, ny) && lv.g[nx * H + ny] == 0 && !has[nx * H + ny]) {
					has[nx * H + ny] = true;
					z.push(nx * H + ny);
				}
			}
		}
		return z;
	}

	// ---------------------------------------------------------------- ice

	// the ice in (x, y) pushed toward d: where it ends (cases or EXIT), the cases it goes through
	public function push(x:Int, y:Int, d:Int, path:Array<Int>):Array<Int> {
		var cx = x;
		if (path != null)
			path.push(x * H + y);
		for (k in 0...W) {
			var nx = cx + d;
			if (lv.solid(nx, y))
				return [cx * H + y];
			if (path != null)
				path.push(nx * H + y);
			if (spike[nx * H + y])
				return [EXIT];
			if (lv.stand(nx, y)) {
				cx = nx;
				continue;
			}
			var outs = [iceFall(nx, y, path)];
			if (nx + d >= 0 && nx + d < W && !lv.ground(nx + d, y) && !lv.ground(nx + d, y + 1)) {
				var o = iceFall(nx + d, y, null);
				if (outs.indexOf(o) < 0)
					outs.push(o);
			}
			return outs;
		}
		return [cx * H + y];
	}

	function iceFall(x:Int, y:Int, path:Array<Int>):Int {
		var g = lv.g;
		while (true) {
			if (spike[x * H + y])
				return EXIT;
			if (y + 1 >= H)
				return EXIT;
			if (g[x * H + y + 1] == 1)
				return x * H + y;
			y++;
			if (path != null)
				path.push(x * H + y);
		}
	}

	// a red bomb throws the ice up like a springboard, a little aside: only into the open sky (4 free rows over it
	// at least: under a ceiling it bounces back where it was), over a rim of 2 then falling one or two columns aside
	function redThrow(x:Int, y:Int):Array<Int> {
		var g = lv.g;
		var h = 0;
		for (k in 1...GenRules.JUMP_RED + 1) {
			if (y - k < 0 || g[x * H + y - k] == 1)
				break;
			h = k;
		}
		var outs:Array<Int> = [];
		if (h < 4)
			return outs;
		var ay = y - 3;
		for (d in [-1, 1])
			for (i in 1...3) {
				var tx = x + d * i;
				if (tx < 0 || tx >= W || g[tx * H + ay] == 1 || g[tx * H + ay - 1] == 1)
					break;
				var o = iceFall(tx, ay, null);
				if (outs.indexOf(o) < 0)
					outs.push(o);
			}
		return outs;
	}

	// a blue bomb: the bad goes under its platform and falls on the next one (dead with none under)
	function blueDrop(x:Int, y:Int):Int {
		var g = lv.g;
		var yy = y + 1;
		while (yy < H && g[x * H + yy] == 1)
			yy++;
		if (yy >= H)
			return EXIT;
		return iceFall(x, yy, null);
	}

	var iceCache = new Map<Int, Int>();

	// can the ice of a bad in the case get out of the level with these bombs, Igor hitting it from the cases of
	// att? the pushes it takes (1, 2...), 0: never
	public function iceOut(cell:Int, w:Int, att:Array<Bool>, hypo:Bool):Int {
		var key = (cell * NW + w) * 2 + (hypo ? 1 : 0);
		if (iceCache.exists(key))
			return iceCache.get(key);
		var res = 0;
		if (w == BLACK)
			res = att[cell] ? 1 : 0;
		else {
			var seenC = new Map<Int, Bool>();
			seenC.set(cell, true);
			var q = [cell];
			var qn = [1];
			var i = 0;
			while (i < q.length && res == 0) {
				var c = q[i];
				var n = qn[i];
				i++;
				if (n > 8)
					break;
				if (c != cell && !att[c])
					continue;
				var x = GenGrid.cx(c);
				var y = GenGrid.cy(c);
				var outs:Array<Int> = [];
				if (w == BLUE)
					outs.push(blueDrop(x, y));
				else {
					for (d in [-1, 1])
						for (o in push(x, y, d, null))
							outs.push(o);
					if (w == RED)
						for (o in redThrow(x, y))
							outs.push(o);
				}
				for (o in outs) {
					if (o == EXIT) {
						res = n;
						break;
					}
					if (!seenC.exists(o)) {
						seenC.set(o, true);
						q.push(o);
						qn.push(n + 1);
					}
				}
			}
		}
		iceCache.set(key, res);
		return res;
	}

	public function near(x:Int, y:Int, cells:Array<Bool>, r:Int = 2):Bool {
		for (dx in -r...r + 1)
			for (dy in -r...r + 1)
				if (lv.inb(x + dx, y + dy) && cells[(x + dx) * H + y + dy])
					return true;
		return false;
	}

	// how the bad in the case dies: pushes it takes with white, red, blue, black bombs (0: never), with the bombs
	// Igor really has where he hits it ([0]) and with each kind of bombs everywhere he can hit ([1])
	var killCache = new Map<String, Array<Array<Int>>>();

	public function killInfo(id:Int, cell:Int):Array<Array<Int>> {
		// a walking fruit: the same for every case of its platform (its zone)
		var key:String = null;
		if (walks(id)) {
			var seg = lv.segmentOf(GenGrid.cx(cell), GenGrid.cy(cell));
			if (seg != null) {
				key = (id == Data.BAD_BOMBE ? "B" : caps(id).join("")) + ":" + seg.join(",");
				if (killCache.exists(key))
					return killCache.get(key);
			}
		}
		var res = killInfo0(id, cell);
		if (key != null)
			killCache.set(key, res);
		return res;
	}

	function killInfo0(id:Int, cell:Int):Array<Array<Int>> {
		var att = attackSets();
		var z = zone(id, cell);
		var sets = [att[WHITE], att[RED], att[BLUE], att[BLACK]];
		var ws = [WHITE, RED, BLUE, BLACK];
		var real = [0, 0, 0, 0];
		var hypo = [0, 0, 0, 0];
		if (id == Data.BAD_BALEINE || id == Data.BAD_CRAWLER || id == Data.BAD_SAW) {
			// frozen in the air or on a wall, it falls: dead if it falls out of the level, else its ice to push
			var drops:Array<Int> = [];
			var k = 0;
			for (c in z) {
				if (id == Data.BAD_BALEINE && (k++) % 3 != 0)
					continue;
				var x = GenGrid.cx(c);
				var y = GenGrid.cy(c);
				var p = dropPoint(x, y);
				if (p < 0) {
					for (i in 0...4) {
						if (near(x, y, sets[i]))
							real[i] = 1;
						if (near(x, y, attackAny))
							hypo[i] = 1;
					}
				} else if (drops.indexOf(p) < 0)
					drops.push(p);
			}
			z = drops;
		}
		for (i in 0...4) {
			var a = sets[i];
			var best = real[i];
			var hb = hypo[i];
			for (c in z) {
				var v = 0;
				var vh = 0;
				if (id == Data.BAD_BOMBE) {
					v = a[c] ? 1 : 0;
					vh = attackAny[c] ? 1 : 0;
				} else {
					v = a[c] ? iceOut(c, ws[i], a, false) : 0;
					vh = attackAny[c] ? iceOut(c, ws[i], attackAny, true) : 0;
				}
				if (v > 0 && (best == 0 || v < best))
					best = v;
				if (vh > 0 && (hb == 0 || vh < hb))
					hb = vh;
			}
			real[i] = best;
			hypo[i] = hb;
		}
		return [real, hypo];
	}

	// pushes of white bombs the ice of a walking fruit takes to leave the level from its own platform (where it starts),
	// 0: never from there
	public function pushesAt(id:Int, cell:Int):Int {
		var att = attackSets();
		var x = GenGrid.cx(cell);
		var y = GenGrid.cy(cell);
		var seg = lv.segmentOf(x, y);
		if (seg == null || !walks(id))
			return killInfo(id, cell)[0][0];
		if (id == Data.BAD_BOMBE)
			return 1;
		var best = 0;
		for (sx in seg[0]...seg[1] + 1) {
			var c = sx * H + y;
			if (!att[WHITE][c])
				continue;
			var v = iceOut(c, WHITE, att[WHITE], false);
			if (v > 0 && (best == 0 || v < best))
				best = v;
		}
		return best;
	}

	// a place the ice of the bad can be pushed to (or the bad can go to, thawed) where no bomb Igor has there kills it
	// any more: the level would be lost (the case, -1: none)
	public function deadEnd(id:Int, cell:Int):Int {
		if (id == Data.BAD_SAW || id == Data.BAD_SPEAR)
			return -1;
		var att = attackSets();
		var has = new Map<Int, Bool>();
		var q:Array<Int> = [];
		function add(c:Int) {
			if (!has.exists(c)) {
				has.set(c, true);
				q.push(c);
			}
		}
		// where it goes from a case (it falls when frozen in the air or on a wall)
		function goes(c:Int) {
			if (walks(id)) {
				for (z in zone(id, c))
					add(z);
			} else
				for (z in zone(id, c)) {
					var p = dropPoint(GenGrid.cx(z), GenGrid.cy(z));
					if (p >= 0)
						add(p);
				}
		}
		if (!walks(id) && !killable(id, cell))
			return cell;
		goes(cell);
		var i = 0;
		while (i < q.length) {
			var c = q[i++];
			if (!killable(id, c))
				return c;
			if (id == Data.BAD_BOMBE)
				continue;
			var x = GenGrid.cx(c);
			var y = GenGrid.cy(c);
			var outs:Array<Int> = [];
			if (att[WHITE][c] || att[RED][c])
				for (d in [-1, 1])
					for (o in push(x, y, d, null))
						outs.push(o);
			if (att[RED][c])
				for (o in redThrow(x, y))
					outs.push(o);
			if (att[BLUE][c])
				outs.push(blueDrop(x, y));
			for (o in outs)
				if (o != EXIT && !has.exists(o)) {
					add(o);
					goes(o);
				}
		}
		return -1;
	}

	public function killable(id:Int, cell:Int):Bool {
		var r = killInfo(id, cell)[0];
		return r[0] > 0 || r[1] > 0 || r[2] > 0 || r[3] > 0;
	}
}
