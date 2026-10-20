package hammerfest;

// The ways of building a level (Gen): one idea a level, drawn with measures at random.
// Rules of the game kept by all of them: two platforms one over the other leave 2 free cases at least (Igor goes
// through), no piece of one case, the two rows of the top free for Igor coming in, the bottom open somewhere (the way
// out). So that a level looks drawn by hand: few pieces, long ones, their ends on the same columns from a row to the
// next, mirrored more often than not, a row every 3 lines.
class GenShapes {
	static inline var W = Data.LEVEL_WIDTH;
	static inline var H = Data.LEVEL_HEIGHT;
	// the lowest row of the floors (the rows under it: the way out)
	static var BOTTOM = Data.LEVEL_HEIGHT - 3;
	// the lowest row of any ground (a floor at the very bottom needs two free rows over it)
	static var LOWEST = Data.LEVEL_HEIGHT - 2;

	static var HALF(get, never):Int;

	static inline function get_HALF():Int {
		return GenGrid.HALF;
	}

	public static function build(name:String, depth:Int, closedBottom:Bool = false):GenGrid {
		// (a floor at the very bottom: the structure stays a row higher)
		BOTTOM = Data.LEVEL_HEIGHT - (closedBottom ? 4 : 3);
		LOWEST = Data.LEVEL_HEIGHT - (closedBottom ? 4 : 2);
		var lv = switch (name) {
			case "briques": briques(depth);
			case "coupes": coupes(depth);
			case "colonnes": colonnes(depth);
			case "escaliers": escaliers(depth);
			case "iles": iles(depth);
			case "pyramide": pyramide(depth);
			case "serpentin": serpentin(depth);
			case "salles": salles(depth);
			case "labyrinthe": labyrinthe(depth);
			case "dedale": dedale(depth);
			default: etages(depth);
		}
		clearTop(lv, 2);
		fixHeadroom(lv);
		removeStubs(lv);
		return lv;
	}

	// ---------------------------------------------------------------- tools

	static function runsRow(lv:GenGrid, y:Int):Array<Array<Int>> {
		var out = [];
		var x = 0;
		while (x < W) {
			if (lv.ground(x, y)) {
				var x0 = x;
				while (x + 1 < W && lv.ground(x + 1, y))
					x++;
				out.push([x0, x]);
			}
			x++;
		}
		return out;
	}

	static function runAt(lv:GenGrid, x:Int, y:Int):Array<Int> {
		if (!lv.ground(x, y))
			return null;
		var x0 = x;
		var x1 = x;
		while (lv.ground(x0 - 1, y))
			x0--;
		while (lv.ground(x1 + 1, y))
			x1++;
		return [x0, x1];
	}

	// two grounds with one free case between them: the shorter piece of the two goes
	public static function fixHeadroom(lv:GenGrid) {
		for (k in 0...60) {
			var f = lv.headroomFaults();
			if (f.length == 0)
				return;
			var x = GenGrid.cx(f[0]);
			var y = GenGrid.cy(f[0]);
			var up = runAt(lv, x, y - 1);
			var lo = runAt(lv, x, y + 1);
			var lu = up != null ? up[1] - up[0] + 1 : 99;
			var ll = lo != null ? lo[1] - lo[0] + 1 : 99;
			if (lu <= ll) {
				if (lu == 1)
					lv.set(x, y - 1, 0);
				else
					lv.hline(up[0], up[1], y - 1, 0);
			} else {
				if (ll == 1)
					lv.set(x, y + 1, 0);
				else
					lv.hline(lo[0], lo[1], y + 1, 0);
			}
		}
	}

	// a floor across the whole level on a row of platforms, with one trapdoor of 2 (in the middle of a level drawn
	// symmetric, else where the row had a hole): the only way down, a gate goes in it (GenDevices.planGate)
	public static function addFloor(lv:GenGrid):Bool {
		var rows = [];
		for (y in 7...H - 6) {
			var any = false;
			var ok = true;
			for (x in 0...W) {
				if (lv.ground(x, y))
					any = true;
				for (dy in [-2, -1, 1, 2])
					if (lv.ground(x, y + dy))
						ok = false;
			}
			if (any && ok)
				rows.push(y);
		}
		if (rows.length == 0)
			return false;
		var y = Gen.pick(rows);
		var gaps = [for (x in 2...W - 3) if (!lv.ground(x, y) && !lv.ground(x + 1, y)) x];
		var hx = lv.symmetric() ? HALF - 1 : (gaps.length > 0 ? Gen.pick(gaps) : Gen.ri(3, W - 5));
		lv.hline(0, W - 1, y);
		lv.set(hx, y, 0);
		lv.set(hx + 1, y, 0);
		lv.notes.push("plancher à trappe");
		return true;
	}

	// grounds alone (one case) go
	public static function removeStubs(lv:GenGrid) {
		for (x in 0...W)
			for (y in 0...H)
				if (lv.ground(x, y) && !lv.ground(x + 1, y) && !lv.ground(x - 1, y) && !lv.ground(x, y + 1) && !lv.ground(x, y - 1))
					lv.set(x, y, 0);
	}

	public static function clearTop(lv:GenGrid, rows:Int) {
		for (x in 0...W)
			for (y in 0...rows)
				lv.set(x, y, 0);
	}

	static function rowsFrom(n:Int, step:Int, topLo:Int, topHi:Int, ?bottom:Int):Array<Int> {
		var b = bottom == null ? BOTTOM : bottom;
		while (n > 1 && (n - 1) * step > b - topLo)
			n--;
		var hi = Std.int(Math.max(topLo, Math.min(topHi, b - (n - 1) * step)));
		var top = Gen.ri(topLo, hi);
		return [for (i in 0...n) top + i * step];
	}

	// breaks the mirror a little: one case less at the end of a long platform
	static function asym(lv:GenGrid, amount:Int) {
		var ys = [];
		for (y in 0...H)
			for (x in 0...W)
				if (lv.ground(x, y)) {
					ys.push(y);
					break;
				}
		for (k in 0...amount) {
			if (ys.length == 0)
				return;
			var y = Gen.pick(ys);
			var rs = [for (r in runsRow(lv, y)) if (r[1] - r[0] >= 4) r];
			if (rs.length == 0)
				continue;
			var r = Gen.pick(rs);
			var x = Gen.chance(0.5) ? r[0] : r[1];
			if (!lv.ground(x, y - 1) && !lv.ground(x, y + 1))
				lv.set(x, y, 0);
		}
	}

	// ---------------------------------------------------------------- prisons

	// prisons drawn on platforms of the level, where fruits that neither climb nor jump up stay shut in (their ice
	// never goes out with white bombs, a laser of the right bombs goes at their mouth): a cup (rims of 2 at the ends of
	// a platform of 5 to 8, open at the top: red bombs throw the ice out) or a cell (the same with a lid 2 rows over
	// its floor and a hatch of 2 in it: Igor drops in, jumps back out through the lid)
	static var cupsMade = 0;

	public static function addPrisons(lv:GenGrid, n:Int) {
		cupsMade = 0;
		// (a whole platform of 5 to 8: the rims at its ends, a true cup; a platform over it covering it all: a closed
		// box with a hatch in its roof; anything else is left alone: no post in the middle of a platform, no pillar)
		// (not in the room of a teleporter nor in a vault: they are shut already)
		function taken(s:Array<Int>):Bool {
			for (x in s[0] - 1...s[1] + 2) {
				if (lv.room != null && (lv.room.indexOf(x * H + s[2]) >= 0 || lv.room.indexOf(x * H + s[2] + 1) >= 0))
					return true;
				var v = lv.vault;
				if (v != null && x >= v[0] - 1 && x <= v[2] + 1 && s[2] >= v[1] - 3 && s[2] <= v[3])
					return true;
			}
			return false;
		}
		var segs = [for (s in lv.segments()) if (s[1] - s[0] + 1 >= 5 && s[1] - s[0] + 1 <= 8 && s[2] >= 4 && s[2] <= H - 3 && !taken(s)) s];
		Gen.shuffle(segs);
		var sym = lv.symmetric();
		var made = 0;
		for (s in segs) {
			if (made >= n)
				break;
			var x0 = s[0];
			var x1 = s[1];
			var y = s[2];
			if (sym && x0 > W - 1 - x1)
				continue; // (the left one of a mirrored pair, its mirror made with it)
			var t = lv.copy();
			var kind = prison(t, x0, x1, y);
			if (kind == 0)
				continue;
			var mirrored = sym && x0 != W - 1 - x1;
			if (mirrored && prison(t, W - 1 - x1, W - 1 - x0, y) != kind)
				continue;
			if (t.headroomFaults().length > lv.headroomFaults().length)
				continue;
			for (p in (mirrored ? [[x0, x1], [W - 1 - x1, W - 1 - x0]] : [[x0, x1]])) {
				// (what it changes, to take it back if no fruit goes in: an ice falling in would stay there for good)
				var u = [];
				for (x in p[0]...p[1] + 1)
					for (yy in 0...H)
						if (t.g[x * H + yy] != lv.g[x * H + yy]) {
							u.push(x * H + yy);
							u.push(lv.g[x * H + yy]);
						}
				lv.undo.push(u);
				if (kind == 1)
					lv.cups.push([p[0], p[1], y + 1, lv.undo.length - 1]);
				else
					lv.cells.push([p[0] + 1, p[1] - 1, y, lv.undo.length - 1]);
			}
			lv.g = t.g;
			made += mirrored ? 2 : 1;
		}
	}

	// draws a prison on the platform x0..x1 (standing row y): 1 a cup, 2 a box with a hatch, 0 none possible
	static function prison(t:GenGrid, x0:Int, x1:Int, y:Int):Int {
		// over it: free (a cup, or a box with its own roof now and then), or a platform covering it all (a box)
		var roof = -1;
		for (k in 2...4) {
			var all = true;
			var any = false;
			for (x in x0...x1 + 1)
				if (t.ground(x, y - k))
					any = true;
				else
					all = false;
			if (any) {
				if (!all)
					return 0;
				roof = k;
				break;
			}
		}
		for (x in x0...x1 + 1)
			if (t.ground(x, y - 1))
				return 0;
		var hx = x0 + Std.int((x1 - x0 - 1) / 2);
		if (roof > 0) {
			t.vline(x0, y - roof + 1, y);
			t.vline(x1, y - roof + 1, y);
			t.set(hx, y - roof, 0);
			t.set(hx + 1, y - roof, 0);
			return 2;
		}
		if (!free(t, x0, x1, y - 2, y - 4))
			return 0;
		t.vline(x0, y - 1, y);
		t.vline(x1, y - 1, y);
		// (a closed room with a hatch more often than a cup: the cups in rows read as a pattern)
		if (cupsMade > 0 || Gen.chance(0.7)) {
			t.hline(x0, x1, y - 2);
			t.set(hx, y - 2, 0);
			t.set(hx + 1, y - 2, 0);
			return 2;
		}
		cupsMade++;
		return 1;
	}

	// nothing in x0..x1 from the row a up to the row b (b < a)
	static function free(lv:GenGrid, x0:Int, x1:Int, a:Int, b:Int):Bool {
		if (b < 0)
			return false;
		for (x in x0...x1 + 1)
			for (y in b...a + 1)
				if (lv.ground(x, y))
					return false;
		return true;
	}

	// ---------------------------------------------------------------- ÉTAGES: rows of the middle and of the sides one
	// after the other, like the start of the well of the original (or a zigzag of long platforms)
	static function etages(depth:Int):GenGrid {
		var lv = new GenGrid();
		var light = depth <= 3;
		var n = light ? Gen.pick([3, 4, 4]) : Gen.pick([4, 4, 5]);
		var step = (light || Gen.chance(0.75)) ? 3 : 4;
		var ys = rowsFrom(n, step, light ? 5 : 3, light ? 8 : 5, light ? BOTTOM - 1 : BOTTOM);
		n = ys.length;
		var m = Gen.pick([0, 0, 1, 2]);
		var a = Gen.ri(m + 3, HALF - 3); // side piece: m..a-1
		var c = Gen.ri(2, HALF - 4); // middle piece: HALF-c..HALF-1 and its mirror
		var t0 = Gen.ri(1, 3); // twin pieces: t0..t1
		var t1 = Std.int(Math.min(HALF - 2, t0 + Gen.ri(3, 4)));
		var phrases = [
			"CSC", "SCS", "CTC", "TCT", "SCF", "CSF", "TCF", "CSCS", "SCSC", "CTCS", "TCTC", "SCTC", "CSTF", "SCSF", "TCSF",
			"CSCSC", "SCSCS", "CTCTC", "SCTCS", "CSCTF", "TCSCF"
		];
		var ph = [for (p in phrases) if (p.length == n) p];
		var seq = Gen.pick(ph);
		var zig = Gen.chance(light ? 0.3 : 0.35);
		if (zig) {
			var side = Gen.rnd(2);
			var L = Gen.ri(6, 10);
			for (i in 0...n) {
				var y = ys[i];
				var x0 = Gen.pick([0, 0, 1, 2]);
				if (i == n - 1) {
					var LL = Gen.pick([8, 10, 12]);
					lv.hsym(HALF - Std.int(LL / 2), HALF - 1, y);
					break;
				}
				var li = L + Gen.pick([-1, 0, 0, 1]);
				if (side == 0) {
					lv.hline(x0, x0 + li - 1, y);
					if (Gen.chance(0.35))
						lv.hline(W - Gen.ri(3, 4), W - 1, y);
				} else {
					lv.hline(W - x0 - li, W - 1 - x0, y);
					if (Gen.chance(0.35))
						lv.hline(0, Gen.ri(2, 3), y);
				}
				side ^= 1;
			}
			seq = "zigzag";
		} else {
			for (i in 0...n) {
				var y = ys[i];
				var k = seq.charAt(i);
				var last = i == n - 1;
				var cc = c + (last ? Gen.pick([0, 1, 2]) : 0);
				if (light && last)
					cc = Std.int(Math.max(cc, 4));
				cc = Std.int(Math.min(cc, HALF - 1));
				switch (k) {
					case "C":
						lv.hsym(HALF - cc, HALF - 1, y);
						if (!last && HALF - cc - 2 >= 3 && Gen.chance(0.25))
							lv.hsym(0, Gen.ri(2, HALF - cc - 3), y);
					case "S":
						lv.hsym(m, a - 1, y);
					case "T":
						lv.hsym(t0, t1, y);
					default:
						var hole = Gen.pick([1, 2]);
						lv.hsym(m, HALF - 1 - hole, y);
				}
			}
		}
		var label = "etages " + seq;
		// a box: a wall joining the ends of two rows on the same column
		if (!light && !zig && Gen.chance(Math.min(0.5, 0.1 + depth * 0.015))) {
			var pairs = [for (i in 0...n - 1) i];
			Gen.shuffle(pairs);
			var done = false;
			for (i in pairs) {
				var ya = ys[i];
				var yb = ys[i + 1];
				for (x in 1...HALF)
					if (lv.ground(x, ya) && lv.ground(x, yb) && (!lv.ground(x - 1, ya) || !lv.ground(x + 1, ya))) {
						lv.vsym(x, ya, yb);
						label += " murs";
						done = true;
						break;
					}
				if (done)
					break;
			}
		}
		// rims of a cup on the bottom row
		if (!light && Gen.chance(0.25)) {
			var y = ys[ys.length - 1];
			for (r in runsRow(lv, y)) {
				if (r[0] >= HALF || r[1] - r[0] < 4)
					continue;
				var free = true;
				for (xx in [r[0], r[1]])
					for (k in 1...6)
						if (lv.ground(xx, y - k))
							free = false;
				if (free) {
					lv.vsym(r[0], y - 2, y - 1);
					label += " coupe";
					break;
				}
			}
		}
		if (!light && Gen.chance(0.3))
			asym(lv, Gen.ri(1, 2));
		lv.shape = "etages";
		lv.label = label;
		lv.rows = ys;
		return lv;
	}

	// ---------------------------------------------------------------- BRIQUES: rows of even pieces, shifted half a
	// period from a row to the next (a brick wall)
	static function briques(depth:Int):GenGrid {
		var lv = new GenGrid();
		var pl = Gen.pick([[6, 3], [6, 4], [7, 4], [7, 5], [8, 5], [9, 6]]);
		var P = pl[0];
		var L = pl[1];
		var n = Gen.pick([4, 4, 5]);
		var step = Gen.chance(0.8) ? 3 : 4;
		var ys = rowsFrom(n, step, 3, 6);
		var off0 = Gen.rnd(P);
		var sym = Gen.chance(0.6);
		for (i in 0...ys.length) {
			var y = ys[i];
			var off = off0 + (i % 2) * Std.int(P / 2);
			var x = off - P;
			while (x < W) {
				var x0 = Std.int(Math.max(0, x));
				var x1 = Std.int(Math.min(W - 1, x + L - 1));
				if (x1 - x0 + 1 >= 2)
					lv.hline(x0, x1, y);
				x += P;
			}
		}
		if (sym) {
			lv.mirror();
			// the mirror may join two pieces in the middle: a hole of 2 there
			for (y in ys)
				for (r in runsRow(lv, y))
					if (r[1] - r[0] + 1 > L + 3 && r[0] < HALF && HALF <= r[1]) {
						lv.set(HALF - 1, y, 0);
						lv.set(HALF, y, 0);
					}
		}
		lv.shape = "briques";
		lv.label = "briques " + L + "/" + P;
		lv.rows = ys;
		return lv;
	}

	// ---------------------------------------------------------------- COUPES: cups (U) in rows
	static function coupes(depth:Int):GenGrid {
		var lv = new GenGrid();
		var cw = Gen.pick([5, 6]);
		var rim = 2;
		var gap = 6;
		var nrows = 2;
		var ys = rowsFrom(nrows, gap, 6, 8, BOTTOM - 1);
		var holesP = depth < 6 ? 0.75 : (depth < 15 ? 0.45 : 0.3);
		for (i in 0...ys.length) {
			var y = ys[i];
			var three = cw == 5 && Gen.chance(0.5);
			var xs:Array<Int>;
			if (three) {
				var xc = Std.int((W - cw) / 2);
				xs = [xc - 1 - cw, xc, xc + cw + 1];
			} else {
				var g = Gen.ri(2, 4);
				xs = [HALF - Std.int(g / 2) - cw, HALF + (g - Std.int(g / 2))];
			}
			for (x0 in xs) {
				var x1 = x0 + cw - 1;
				if (x0 < 0 || x1 > W - 1)
					continue;
				lv.hline(x0, x1, y);
				lv.vline(x0, y - rim, y - 1);
				lv.vline(x1, y - rim, y - 1);
				if (Gen.chance(holesP)) {
					var hx = Std.int((x0 + x1) / 2);
					lv.set(hx, y, 0);
					lv.set((x1 - x0) % 2 == 1 ? hx + 1 : hx - 1, y, 0);
				}
				lv.cups.push([x0, x1, y]);
			}
		}
		if (Gen.chance(0.7))
			lv.mirror();
		// a platform under them
		var yb = ys[ys.length - 1] + 3;
		if (yb <= LOWEST && Gen.chance(0.75)) {
			var L = Gen.pick([8, 10, 12]);
			lv.hsym(HALF - Std.int(L / 2), HALF - 1, yb);
		}
		lv.shape = "coupes";
		lv.label = "coupes " + nrows + "x" + cw;
		lv.rows = ys;
		return lv;
	}

	// ---------------------------------------------------------------- COLONNES: walls cutting the level in shafts,
	// ledges in zigzag
	static function colonnes(depth:Int):GenGrid {
		var lv = new GenGrid();
		var r = Gen.rnd(100);
		var variant = r < 30 ? "spine" : (r < 78 ? "two" : "three");
		var yTop = Gen.ri(3, 5);
		var step = 3;
		var nled = Gen.ri(3, 4);
		var yBot = Std.int(Math.min(BOTTOM - 1, yTop + 2 + nled * step - 1));
		var walls:Array<Int> = [];
		if (variant == "spine") {
			walls = [HALF - 1];
			lv.vline(HALF - 1, yTop, yBot);
			lv.vline(HALF, yTop, yBot);
		} else if (variant == "two") {
			var a = Gen.ri(4, 6);
			walls = [a];
			lv.vsym(a, yTop, yBot);
		} else {
			var a = Gen.ri(3, 4);
			walls = [a, HALF - 1];
			lv.vsym(a, yTop, yBot);
			lv.vline(HALF - 1, yTop + 3, yBot);
			lv.vline(HALF, yTop + 3, yBot);
		}
		var bounds = [-1].concat(walls);
		if (variant == "two")
			bounds.push(HALF);
		var lanes = [];
		for (i in 0...bounds.length - 1) {
			var lo = bounds[i] + 1;
			var hi = bounds[i + 1] - 1;
			if (hi - lo + 1 >= 3)
				lanes.push([lo, hi]);
		}
		for (ln in lanes) {
			var lo = ln[0];
			var hi = ln[1];
			var width = hi - lo + 1;
			var centre = hi >= HALF - 1 && variant == "two";
			var L = width >= 4 ? width - 2 : width - 1;
			if (centre)
				L = width - 1;
			if (L < 2)
				L = 2;
			var side = Gen.rnd(2);
			var y = yTop + Gen.pick([2, 3]);
			while (y <= yBot) {
				if (centre) {
					if (side == 0)
						lv.hline(lo, lo + L - 1, y);
					else
						lv.hline(hi - Std.int(L / 2), hi, y);
				} else if (side == 0)
					lv.hline(lo, lo + L - 1, y);
				else
					lv.hline(hi - L + 1, hi, y);
				side ^= 1;
				y += step;
			}
		}
		lv.mirror();
		if (Gen.chance(0.65)) {
			var yb = yBot + 3;
			if (yb <= LOWEST) {
				var L = Gen.pick([6, 8, 10]);
				lv.hsym(HALF - Std.int(L / 2), HALF - 1, yb);
			}
		}
		lv.shape = "colonnes";
		lv.label = "colonnes " + variant;
		return lv;
	}

	// ---------------------------------------------------------------- ESCALIERS: steps in diagonals

	static function stair(lv:GenGrid, x:Int, y:Int, s:Int, dx:Int, n:Int, step:Int = 3) {
		for (i in 0...n) {
			var x0 = x + i * dx;
			var lo = Std.int(Math.min(x0, x0 + s - 1));
			var hi = Std.int(Math.max(x0, x0 + s - 1));
			if (hi < 0 || lo >= W)
				break;
			lv.hline(Std.int(Math.max(0, lo)), Std.int(Math.min(W - 1, hi)), y + i * step);
		}
	}

	static function escaliers(depth:Int):GenGrid {
		var lv = new GenGrid();
		var r = Gen.rnd(35);
		var shape = r < 10 ? "V" : (r < 20 ? "A" : (r < 28 ? "Z" : "X"));
		var s = Gen.pick([3, 3, 4]);
		var shift = s >= 4 ? s - Gen.pick([0, 1]) : s;
		var y0 = Gen.ri(4, 6);
		if (shape == "V") {
			var n = Std.int(Math.min(4, Math.max(3, Std.int((HALF - 1) / shift) + 1)));
			stair(lv, 0, y0, s, shift, n);
			lv.mirror();
			var yb = y0 + n * 3;
			if (yb <= LOWEST && Gen.chance(0.7))
				lv.hsym(HALF - Gen.pick([2, 3]), HALF - 1, yb);
		} else if (shape == "A") {
			var n = Std.int(Math.min(4, Math.max(3, Std.int((HALF - 1) / shift) + 1)));
			stair(lv, HALF - s + 1, y0, s, -shift, n);
			lv.mirror();
			var yb = y0 + n * 3 + 1;
			if (yb <= LOWEST && Gen.chance(0.7))
				lv.hsym(0, Gen.ri(2, 3), yb);
		} else if (shape == "Z") {
			var n = 3;
			stair(lv, 1, y0, s, shift, n);
			var xEnd = 1 + (n - 1) * shift;
			stair(lv, xEnd - shift + 1, y0 + n * 3, s, -shift, n - 1);
			if (Gen.chance(0.5)) {
				var g2 = lv.g.copy();
				for (x in 0...W)
					for (y in 0...H)
						lv.g[x * H + y] = g2[(W - 1 - x) * H + y];
			}
		} else {
			var n = 2;
			stair(lv, 0, y0, s, shift, n);
			stair(lv, HALF - s, y0 + n * 3 + 1, s, -shift, n);
			lv.mirror();
		}
		lv.shape = "escaliers";
		lv.label = "escaliers " + shape + s;
		return lv;
	}

	// ---------------------------------------------------------------- ÎLES: small platforms in quincunx, much air
	static function iles(depth:Int):GenGrid {
		var lv = new GenGrid();
		var P = Gen.pick([5, 6, 7]);
		var L = P <= 6 ? Gen.pick([2, 3]) : Gen.pick([3, 4]);
		var dy = Gen.pick([4, 4, 5]);
		var n = 3;
		var ys = rowsFrom(n, dy, 4, 6);
		var block = false;
		var off0 = Gen.ri(1, P - 1);
		for (i in 0...ys.length) {
			var y = ys[i];
			var off = off0 + (i % 2) * Std.int(P / 2);
			var x = off - P;
			while (x < HALF) {
				var x0 = Std.int(Math.max(0, x));
				var x1 = Std.int(Math.min(HALF - 1, x + L - 1));
				if (x1 - x0 + 1 >= 2) {
					lv.hline(x0, x1, y);
					if (block && i % 2 == 0)
						lv.hline(x0, x1, y + 1);
				}
				x += P;
			}
		}
		lv.mirror();
		for (y in ys)
			for (r in runsRow(lv, y))
				if (r[1] - r[0] + 1 > L * 2 + 1 && r[0] < HALF && HALF <= r[1]) {
					lv.set(HALF - 1, y, 0);
					lv.set(HALF, y, 0);
				}
		lv.shape = "iles";
		lv.label = "iles " + L + "/" + P;
		lv.rows = ys;
		return lv;
	}

	// ---------------------------------------------------------------- PYRAMIDE: rows in the middle getting wider (or
	// narrower), a slit in some of them
	static function pyramide(depth:Int):GenGrid {
		var lv = new GenGrid();
		var r = Gen.rnd(31);
		var shape = r < 10 ? "pyramide" : (r < 17 ? "entonnoir" : (r < 25 ? "losange" : "sablier"));
		var n = Gen.pick([4, 4, 5]);
		var ys = rowsFrom(n, 3, 3, 5);
		n = ys.length;
		var k = Gen.pick([1, 2, 2]);
		var h0 = Gen.ri(2, 3);
		var slit = Gen.chance(0.6);
		for (i in 0...n) {
			var h:Float = switch (shape) {
				case "pyramide": h0 + i * k;
				case "entonnoir": h0 + (n - 1 - i) * k;
				case "losange": h0 + Math.min(i, n - 1 - i) * k * 2;
				default: h0 + Math.abs(i - (n - 1) / 2) * k * 2;
			}
			var hi = Std.int(Math.min(HALF, h));
			var cut = (slit && i % 2 == 1 && hi >= 4) || hi >= HALF - 1;
			lv.hsym(Std.int(Math.max(0, HALF - hi)), HALF - 1 - (cut ? 1 : 0), ys[i]);
		}
		lv.shape = "pyramide";
		lv.label = shape;
		lv.rows = ys;
		return lv;
	}

	// ---------------------------------------------------------------- SERPENTIN: corridors going down in a zigzag (the
	// hole once on the left, once on the right)
	static function serpentin(depth:Int):GenGrid {
		var lv = new GenGrid();
		var step = Gen.pick([3, 3, 4]);
		var n = Gen.pick([4, 4, 5]);
		var ys = rowsFrom(n, step, 3, 5);
		var m = Gen.pick([0, 1, 2]);
		var hole = Gen.pick([2, 3]);
		var double = Gen.chance(0.5);
		if (double) {
			for (i in 0...ys.length) {
				var y = ys[i];
				if (i % 2 == 0)
					lv.hline(m, HALF - 1 - hole, y);
				else
					lv.hline(m + hole, HALF - 1, y);
			}
			if (Gen.chance(0.6))
				lv.vline(HALF - 1, ys[0], ys[ys.length - 1]);
			lv.mirror();
		} else
			for (i in 0...ys.length) {
				var y = ys[i];
				if (i % 2 == 0)
					lv.hline(m, W - 1 - m - hole, y);
				else
					lv.hline(m + hole, W - 1 - m, y);
			}
		lv.shape = "serpentin";
		lv.label = "serpentin" + (double ? " double" : "");
		lv.rows = ys;
		return lv;
	}

	// ---------------------------------------------------------------- SALLES: a regular building: floors with holes in
	// a quincunx (middle, then sides, then middle...), walls in line with a door at the floor on every storey; now and
	// then a vault: a side room with no door, entered through the hole of its ceiling (its bads need the right bombs)
	static function salles(depth:Int):GenGrid {
		var lv = new GenGrid();
		var storey = depth < GenRules.JUMP_BOMBS_FROM ? 3 : Gen.pick([3, 4, 4]);
		var yTop = Gen.ri(3, 4);
		var n = storey == 3 ? 4 : 3;
		while (n > 2 && yTop + n * storey > LOWEST)
			n--;
		var ys = [for (i in 0...n + 1) yTop + i * storey];
		var m = Gen.pick([0, 0, 1, 2]);
		var g = Gen.ri(m + 4, HALF - 3);
		for (y in ys)
			lv.hsym(m, HALF - 1, y);
		if (m > 0)
			lv.vsym(m, ys[0], ys[ys.length - 1]);
		lv.vsym(g, ys[0], ys[ys.length - 1]);
		var loSide = m > 0 ? m + 1 : 0;
		var sideC = Std.int((loSide + g - 1) / 2);
		var phase = Gen.rnd(2);
		for (j in 0...ys.length) {
			var y = ys[j];
			if ((j + phase) % 2 == 0)
				lv.hline(HALF - 1, HALF, y, 0);
			else
				lv.hsym(sideC, sideC + 1, y, 0);
		}
		for (i in 0...n) {
			var yb = ys[i + 1];
			var dh = Std.int(Math.min(2, storey - 1));
			for (k in 1...dh + 1)
				lv.vsym(g, yb - k, yb - k, 0);
		}
		if (n >= 3 && Gen.chance(GenRules.chanceVault(depth))) {
			// a vault: a side room under a floor holed on the sides, its door closed
			var cands = [for (i in 1...n) if ((i + phase) % 2 == 1) i];
			if (cands.length > 0) {
				var i = Gen.pick(cands);
				var ya = ys[i];
				var yb = ys[i + 1];
				var left = Gen.chance(0.5);
				var gx = left ? g : W - 1 - g;
				lv.vline(gx, ya + 1, yb - 1);
				var x0 = left ? loSide : W - g;
				var x1 = left ? g - 1 : W - 1 - loSide;
				lv.hline(x0, x1, yb);
				lv.vault = [x0, ya, x1, yb];
			}
		}
		lv.shape = "salles";
		lv.label = "salles " + n + "x" + storey + (lv.vault != null ? " caveau" : "");
		lv.rows = ys;
		return lv;
	}

	// ---------------------------------------------------------------- LABYRINTHE: big cells, whole walls, a way from the
	// top to the bottom, corridors more than shafts
	static function labyrinthe(depth:Int):GenGrid {
		var lv = new GenGrid();
		var cw = Gen.pick([6, 6, 4]);
		var ch = Gen.pick([3, 4, 4]);
		var ncols = Std.int(W / cw);
		var xoff = Std.int((W - ncols * cw) / 2);
		var yTop = Gen.ri(2, 3);
		var nrows = Std.int(Math.min(4, (H - 3 - yTop) / ch));
		var floor = [for (i in 0...ncols * nrows) true];
		var right = [for (i in 0...ncols * nrows) true];
		var seen = [for (i in 0...ncols * nrows) false];
		var start = Gen.rnd(ncols);
		seen[start] = true;
		var stack = [start];
		while (stack.length > 0) {
			var c = stack[stack.length - 1];
			var i = c % ncols;
			var j = Std.int(c / ncols);
			var nb = [];
			for (d in [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
				var ni = i + d[0];
				var nj = j + d[1];
				if (ni >= 0 && ni < ncols && nj >= 0 && nj < nrows && !seen[nj * ncols + ni])
					nb.push(nj * ncols + ni);
			}
			if (nb.length == 0) {
				stack.pop();
				continue;
			}
			var hz = [for (n in nb) if (Std.int(n / ncols) == j) n];
			var nx = hz.length > 0 && Gen.chance(0.65) ? Gen.pick(hz) : Gen.pick(nb);
			var ni = nx % ncols;
			var nj = Std.int(nx / ncols);
			if (ni == i + 1)
				right[c] = false;
			else if (ni == i - 1)
				right[nx] = false;
			else if (nj == j + 1)
				floor[c] = false;
			else
				floor[nx] = false;
			seen[nx] = true;
			stack.push(nx);
		}
		for (i in 0...ncols)
			for (j in 0...nrows) {
				var x0 = xoff + i * cw;
				var yt = yTop + (j + 1) * ch;
				lv.hline(x0, x0 + cw - 1, yt);
				if (!floor[j * ncols + i]) {
					var hx = x0 + Std.int((cw - 2) / 2);
					lv.set(hx, yt, 0);
					lv.set(hx + 1, yt, 0);
				}
				if (i < ncols - 1 && right[j * ncols + i])
					lv.vline(x0 + cw - 1, yt - ch + 1, yt);
			}
		// the way out at the bottom
		var yl = yTop + nrows * ch;
		var i = Gen.rnd(ncols);
		var hx = xoff + i * cw + Std.int((cw - 2) / 2);
		lv.set(hx, yl, 0);
		lv.set(hx + 1, yl, 0);
		lv.shape = "labyrinthe";
		lv.label = "labyrinthe " + cw + "x" + ch;
		return lv;
	}

	// a maze of rooms: under an open top (Igor comes in there), storeys of 2 to 4 rooms shut by walls from floor to
	// ceiling (the walls of a storey not over the ones of the next), holes of 2 in the floors, doors in a few walls; the
	// rooms nothing joins get teleporters (GenDevices.linkMaze), the fruits shut in their lasers
	static function dedale(depth:Int):GenGrid {
		var lv = new GenGrid();
		// storeys of 2 rows (corridors: the teleporters standing, 2 cases, fit there; Igor jumps up through their
		// ceilings), 3 or 4 (no jump goes through a ceiling of 4: only teleporters lying in the floors join them)
		var floors = Gen.pick([[4, 7, 10, 13, 16], [4, 7, 10, 13, 16], [4, 9, 12, 16], [4, 7, 11, 14], [4, 8, 11, 14], [4, 9, 14]]);
		for (y in floors)
			lv.hline(0, W - 1, y);
		lv.mazeFloors = floors;
		lv.mazeRooms = [];
		var wallsOf:Array<Array<Int>> = [];
		for (k in 0...floors.length - 1) {
			var top = floors[k] + 1;
			var s = floors[k + 1] - 1;
			// rooms of 4 cases at least, their walls away from the walls of the storey over it
			var walls:Array<Int> = null;
			for (t in 0...20) {
				var nr = Gen.pick([2, 3, 3, 3, 4]);
				var widths = [for (i in 0...nr) 4];
				var left = W - (nr - 1) - 4 * nr;
				while (left > 0) {
					widths[Gen.rnd(nr)]++;
					left--;
				}
				var ws = [];
				var x = 0;
				for (i in 0...nr - 1) {
					x += widths[i];
					ws.push(x);
					x++;
				}
				var over = k > 0 ? wallsOf[k - 1] : [];
				if (Lambda.exists(ws, function(w) return Lambda.exists(over, function(o) return Math.abs(o - w) <= 1)) && t < 19)
					continue;
				walls = ws;
				break;
			}
			wallsOf.push(walls);
			for (x in walls)
				lv.vline(x, top, s);
			var xs = [0].concat([for (w in walls) w + 1]);
			var xe = [for (w in walls) w - 1].concat([W - 1]);
			for (i in 0...xs.length)
				lv.mazeRooms.push([xs[i], xe[i], s, top]);
		}
		// the ways down: holes of 2 inside the rooms over each floor, not under a wall over it nor over a wall under
		// it, not leaving a case alone by a side of the screen
		for (k in 0...floors.length) {
			var y = floors[k];
			var over = k > 0 ? wallsOf[k - 1] : [];
			var under = k < wallsOf.length ? wallsOf[k] : [];
			var cands = [];
			for (hx in 2...W - 3) {
				var ok = true;
				for (w in over.concat(under))
					if (w >= hx - 1 && w <= hx + 2)
						ok = false;
				if (ok)
					cands.push(hx);
			}
			Gen.shuffle(cands);
			var n = k == 0 || k == floors.length - 1 ? Gen.pick([1, 1, 2]) : Gen.pick([1, 2, 2]);
			var made = [];
			for (hx in cands) {
				if (made.length >= n)
					break;
				// (4 cases apart at least, one a room of the storey over the floor)
				if (Lambda.exists(made, function(m) return Math.abs(m - hx) < 4))
					continue;
				var room = Lambda.count(over, function(w) return w < hx);
				if (over.length > 0 && Lambda.exists(made, function(m) return Lambda.count(over, function(w) return w < m) == room))
					continue;
				lv.set(hx, y, 0);
				lv.set(hx + 1, y, 0);
				made.push(hx);
			}
		}
		// a few walls taken away (two rooms in one: no piece of wall left hanging from the ceiling)
		var doors = Gen.pick([0, 1, 1, 2]);
		var ws = [for (k in 0...wallsOf.length) for (x in wallsOf[k]) [x, k]];
		Gen.shuffle(ws);
		var gone = [];
		for (i in 0...Std.int(Math.min(doors, ws.length))) {
			var x = ws[i][0];
			var k = ws[i][1];
			for (y in floors[k] + 1...floors[k + 1])
				lv.set(x, y, 0);
			gone.push(ws[i]);
		}
		// (the rooms joined: one room)
		for (gw in gone) {
			var s = floors[gw[1] + 1] - 1;
			var a = Lambda.find(lv.mazeRooms, function(r) return r[2] == s && r[1] == gw[0] - 1);
			var b = Lambda.find(lv.mazeRooms, function(r) return r[2] == s && r[0] == gw[0] + 1);
			if (a != null && b != null) {
				lv.mazeRooms.remove(b);
				a[1] = b[1];
			}
		}
		lv.shape = "dedale";
		lv.label = "dedale " + wallsOf.length + " etages " + lv.mazeRooms.length + " salles";
		return lv;
	}
}
