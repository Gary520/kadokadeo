package hammerfest;

import hammerfest.GenGrid.GenField;

// The devices of a level (Gen), each one put for a reason:
// - a fruit no explosion can throw out of the level (a room shut, a well in U) gets a laser on the way of Igor to it:
//   red bombs for a well open at the top, black or blue ones for a place shut (black ones for a lemon shut in);
// - the room shut in a corner is reached by a teleporter;
// - a laser without bombs only on a passage Igor must take, a laser of white bombs further on, always reached;
// - green bombs (flasks) on the way to the shooters; two teleporters between two places far apart.
// The lasers stand from a ground to a ground: in a door (a floor and a ceiling) or across a hole of a floor.
class GenDevices {
	static inline var W = Data.LEVEL_WIDTH;
	static inline var H = Data.LEVEL_HEIGHT;
	public static inline var WHITE = -1;
	public static inline var BLACK = -2;
	public static inline var BLUE = -3;
	public static inline var GREEN = -4;
	public static inline var RED = -5;

	// ---------------------------------------------------------------- places of the lasers

	// a laser standing from a floor to a ceiling (2 or 3 cases high), where Igor walks
	public static function doorSites(lv:GenGrid, reach:Array<Bool>):Array<Array<Int>> {
		var out = [];
		var fm = lv.fieldMap();
		for (x in 1...W - 1)
			for (y in 2...H - 1) {
				if (!lv.stand(x, y) || (reach != null && !reach[x * H + y]))
					continue;
				for (hgt in 2...4) {
					var ok = true;
					for (k in 0...hgt)
						if (!lv.empty(x, y - k) || fm[x * H + y - k] != 0)
							ok = false;
					if (ok && lv.ground(x, y - hgt)) {
						if ((lv.stand(x - 1, y) || lv.empty(x - 1, y)) && (lv.stand(x + 1, y) || lv.empty(x + 1, y)))
							out.push([for (k in 0...hgt) x * H + y - k]);
						break;
					}
					if (!ok)
						break;
				}
			}
		return out;
	}

	// a laser across a hole of a floor (grounds on both sides): Igor falls through it
	public static function holeSites(lv:GenGrid, maxw:Int = 6):Array<Array<Int>> {
		var out = [];
		var fm = lv.fieldMap();
		for (y in 3...H) {
			var x = 1;
			while (x < W) {
				if (!lv.ground(x, y) && lv.ground(x - 1, y)) {
					var x0 = x;
					while (x < W && !lv.ground(x, y))
						x++;
					var x1 = x - 1;
					if (x < W && x1 - x0 + 1 <= maxw) {
						var ok = true;
						for (cx in x0...x1 + 1)
							if (!lv.empty(cx, y - 1) || fm[cx * H + y] != 0)
								ok = false;
						if (ok)
							out.push([for (cx in x0...x1 + 1) cx * H + y]);
					}
				} else
					x++;
			}
		}
		return out;
	}

	static function siteDist(cells:Array<Int>, zone:Array<Int>):Int {
		var best = 99;
		for (c in cells)
			for (z in zone) {
				var d = Std.int(Math.abs(GenGrid.cx(c) - GenGrid.cx(z)) + Math.abs(GenGrid.cy(c) - GenGrid.cy(z)));
				if (d < best)
					best = d;
			}
		return best;
	}

	// the whole analysis: a way out, no trap, every fruit killed with the bombs Igor really has, nothing in the column
	// where Igor falls coming in; full (the level done): no fruit can be pushed (or go) where it could no longer be
	// killed (an ice fallen into a box: the level lost)
	public static function check(lv:GenGrid, depth:Int, full:Bool = false):{an:GenAnalysis, ok:Bool, bad:Array<{id:Int, x:Int, y:Int}>,
			stuck:Array<{id:Int, x:Int, y:Int}>} {
		var an = new GenAnalysis(lv, depth);
		if (an.exitCount == 0 || an.traps > 0)
			return {an: an, ok: false, bad: [], stuck: []};
		for (y in 0...lv.sy + 1)
			if (an.special[lv.sx * H + y] != 0)
				return {an: an, ok: false, bad: [], stuck: []};
		// (every teleporter between two blocks: standing from a floor to a ceiling, lying between two grounds)
		for (p in lv.teles)
			for (f in p)
				if (!heldUp(lv, f))
					return {an: an, ok: false, bad: [], stuck: []};
		var bad = [];
		for (b in lv.bads)
			if (b.id != Data.BAD_SAW && b.id != Data.BAD_SPEAR && !an.killable(b.id, b.x * H + b.y))
				bad.push(b);
		var stuck = [];
		if (full && bad.length == 0)
			for (b in lv.bads)
				if (an.deadEnd(b.id, b.x * H + b.y) >= 0)
					stuck.push(b);
		return {an: an, ok: bad.length == 0 && stuck.length == 0, bad: bad, stuck: stuck};
	}

	static function heldUp(lv:GenGrid, f:GenField):Bool {
		var a = f.cells[0];
		var b = f.cells[f.cells.length - 1];
		if (f.cells.length > 1 && f.cells[1] - f.cells[0] == H)
			return lv.ground(GenGrid.cx(a) - 1, GenGrid.cy(a)) && lv.ground(GenGrid.cx(b) + 1, GenGrid.cy(b));
		return lv.ground(GenGrid.cx(a), GenGrid.cy(a) - 1) && lv.ground(GenGrid.cx(b), GenGrid.cy(b) + 1);
	}

	static function sound(an:GenAnalysis):Bool {
		return an.exitCount > 0 && an.traps == 0;
	}

	// ---------------------------------------------------------------- fruits shut in: the right laser on the way

	static function weaponFor(hypo:Array<Int>, shut:Bool, depth:Int):Int {
		var opts = [];
		var ws = [];
		if (hypo[1] > 0 && !shut && depth >= GenRules.RED_FROM) {
			opts.push(RED);
			ws.push(30);
		}
		if (hypo[3] > 0) {
			opts.push(BLACK);
			ws.push(20);
		}
		if (hypo[2] > 0) {
			opts.push(BLUE);
			ws.push(14);
		}
		if (opts.length == 0)
			return 0;
		return opts[Cs.draw(ws)];
	}

	static function hypoOf(hypo:Array<Int>, v:Int):Int {
		return switch (v) {
			case RED: hypo[1];
			case BLUE: hypo[2];
			case BLACK: hypo[3];
			default: hypo[0];
		}
	}

	// a ceiling over the fruit (a room shut), or the open sky (a well in U)?
	static function isShut(lv:GenGrid, x:Int, y:Int):Bool {
		for (k in 1...7)
			if (lv.ground(x, y - k))
				return true;
		return false;
	}

	static function why(v:Int):String {
		return switch (v) {
			case RED: "rouge";
			case BLUE: "bleue";
			case BLACK: "noire";
			case GREEN: "verte";
			case WHITE: "blanche";
			default: "violette";
		}
	}

	// lasers for the fruits white bombs cannot kill
	public static function unlockFruits(lv:GenGrid, depth:Int):Bool {
		for (it in 0...8) {
			var ck = check(lv, depth);
			if (ck.ok)
				return true;
			if (!sound(ck.an) || ck.bad.length == 0)
				return false;
			var b = ck.bad[0];
			var cell = b.x * H + b.y;
			var hypo = ck.an.killInfo(b.id, cell)[1];
			var w = weaponFor(hypo, isShut(lv, b.x, b.y), depth);
			// a lemon shut in: only with black bombs
			if (b.id == Data.BAD_CITRON && hypo[3] > 0)
				w = BLACK;
			if (w == 0)
				return false;
			var zone = ck.an.zone(b.id, cell);
			var sites = [for (s in doorSites(lv, ck.an.reach).concat(holeSites(lv))) if (siteDist(s, zone) <= 8) s];
			sites.sort(function(a, c) return siteDist(a, zone) - siteDist(c, zone));
			// (half the time not by the fruit but on the way there: the player has to think of it before going in)
			if (Gen.chance(0.5)) {
				var away = [for (s in sites) if (siteDist(s, zone) >= 2) s];
				var by = [for (s in sites) if (siteDist(s, zone) < 2) s];
				sites = away.slice(0, 4).concat(by);
			}
			var tries = [w].concat([for (v in [BLACK, BLUE, RED]) if (v != w && hypoOf(hypo, v) > 0 && (v != RED || depth >= GenRules.RED_FROM)) v]);
			// the laser freeing the most fruits shut in at once (one at the way into a place shut rather than one for
			// each of them), the nearest one on a tie
			var best:{v:Int, cells:Array<Int>, n:Int} = null;
			for (v in tries) {
				var k = 0;
				for (cells in sites) {
					if (k++ >= 6)
						break;
					lv.fields.push({v: v, cells: cells, why: why(v) + " pour un fruit enfermé"});
					var an2 = new GenAnalysis(lv, depth);
					if (sound(an2) && an2.killable(b.id, cell) && !inArrival(lv, an2)) {
						var n = 0;
						for (o in ck.bad)
							if (an2.killable(o.id, o.x * H + o.y))
								n++;
						if (best == null || n > best.n)
							best = {v: v, cells: cells, n: n};
					}
					lv.fields.pop();
				}
				if (best != null && best.n >= ck.bad.length)
					break;
			}
			if (best == null)
				return false;
			lv.fields.push({v: best.v, cells: best.cells, why: why(best.v) + " pour un fruit enfermé"});
			lv.notes.push(why(best.v) + " pour " + (best.n > 1 ? best.n + " fruits enfermés" : GenRules.kind(b.id).name.toLowerCase()));
		}
		return check(lv, depth).ok;
	}

	static function inArrival(lv:GenGrid, an:GenAnalysis):Bool {
		for (y in 0...lv.sy + 1)
			if (an.special[lv.sx * H + y] != 0)
				return true;
		return false;
	}

	// ---------------------------------------------------------------- teleporters

	// where a teleporter stands (2 cases high, a floor and a ceiling): Igor walks through it
	static function teleSites(lv:GenGrid, an:GenAnalysis, exclude:Array<Int>):Array<Int> {
		var out = [];
		var fm = lv.fieldMap();
		for (x in 1...W - 1)
			for (y in 2...H - 1) {
				var c = x * H + y;
				if (!an.reach[c] || !lv.stand(x, y) || exclude.indexOf(c) >= 0)
					continue;
				// (from the floor to a ceiling 2 cases over it)
				var hgt = teleHeight(lv, c);
				if (hgt == 0)
					continue;
				var used = false;
				for (k in 0...hgt)
					if (fm[c - k] != 0)
						used = true;
				if (used)
					continue;
				if (!lv.stand(x - 1, y) || !lv.stand(x + 1, y))
					continue;
				out.push(c);
			}
		return out;
	}

	// (the teleporters are 2 cases, from a floor to a ceiling: 0 elsewhere)
	static function teleHeight(lv:GenGrid, c:Int):Int {
		var x = GenGrid.cx(c);
		var y = GenGrid.cy(c);
		return lv.empty(x, y - 1) && lv.ground(x, y - 2) ? 2 : 0;
	}

	static function teleField(lv:GenGrid, c:Int):GenField {
		var h = Std.int(Math.max(2, teleHeight(lv, c)));
		return {v: Data.FIELD_TELEPORT, cells: [for (k in 0...h) c - (h - 1) + k], why: "téléporteur"};
	}

	// a room shut (roof, floor and walls of one case, 2 cases high inside, 3 to 7 wide) reached by its teleporter,
	// in several forms not to be seen again and again: against a side of the screen or standing alone in the level,
	// at any height, its teleporter at its far end, by the side of the screen or in its middle; nothing under it on 4
	// rows (Igor does not jump in through its floor): the case of the teleporter inside
	public static function carveRoom(lv:GenGrid):Int {
		var hh = 2;
		var w = Gen.ri(3, 7);
		var alone = Gen.chance(0.35);
		var ry = Gen.ri(4, H - hh - 7);
		var fy = ry + hh + 1;
		var x0 = 0;
		if (alone)
			x0 = Gen.ri(2, W - 3 - w);
		else if (Gen.chance(0.5))
			x0 = W - w;
		var x1 = x0 + w - 1;
		for (y in Std.int(Math.max(2, ry - 2))...fy + 5)
			for (x in Std.int(Math.max(0, x0 - 3))...Std.int(Math.min(W, x1 + 4)))
				lv.set(x, y, 0);
		for (x in Std.int(Math.max(0, x0 - 1))...Std.int(Math.min(W, x1 + 2))) {
			lv.set(x, ry);
			lv.set(x, fy);
		}
		for (y in ry + 1...fy) {
			if (x0 > 0)
				lv.set(x0 - 1, y);
			if (x1 < W - 1)
				lv.set(x1 + 1, y);
		}
		lv.room = [for (x in x0...x1 + 1) x * H + fy - 1];
		// (its teleporter at the end away from the side of the screen, by the side, or in the middle of a wide one)
		var far = x0 == 0 ? x1 : x0;
		var near = x0 == 0 ? x0 : x1;
		var opts = [far, near];
		var ws = [5, 3];
		if (w >= 5) {
			opts.push(x0 + Std.int(w / 2));
			ws.push(3);
		}
		lv.roomTele = opts[Cs.draw(ws)] * H + fy - 1;
		lv.label += " + salle" + (alone ? " seule" : "");
		return lv.roomTele;
	}

	// the twin of the teleporter of the room outside, on the ways of Igor, far from the room and from his landing
	public static function linkRoom(lv:GenGrid, depth:Int):Bool {
		var an = new GenAnalysis(lv, depth);
		var t = lv.roomTele;
		var hgt = teleHeight(lv, t);
		var sites = [
			for (s in teleSites(lv, an, lv.room))
				if (mdist(s, t) >= 8 && mdist(s, lv.sx * H + lv.sy) >= 4 && teleHeight(lv, s) == hgt) s
		];
		if (sites.length == 0)
			return false;
		sites.sort(function(a, b) return an.cellDist[a] - an.cellDist[b] != 0 ? an.cellDist[a] - an.cellDist[b] : a - b);
		var pick = sites[Gen.rnd(Std.int(Math.min(6, sites.length)))];
		lv.teles.push([{v: Data.FIELD_TELEPORT, cells: teleField(lv, t).cells, why: "salle fermée"}, teleField(lv, pick)]);
		return true;
	}

	// the rooms of a maze Igor cannot reach, or cannot get out of the level from, joined by teleporters: a pair standing
	// from floor to ceiling in two rooms of a storey (the game joins a teleporter to the one standing on the same row
	// with the same height, GameMechanics.getNextTeleporter: one such pair a storey), or a pair lying in holes of two
	// floors one over the other (joined to the one in the same columns with the same length), a whole floor between
	// them; now and then a pair more (a shortcut). The pairs made (-1: a room left wrong)
	public static function linkMaze(lv:GenGrid, depth:Int):Int {
		var used = new Map<String, Bool>();
		var made = 0;
		var NW = GenAnalysis.NW;
		for (it in 0...8) {
			var an = new GenAnalysis(lv, depth);
			var good = [];
			var bad = [];
			for (r in lv.mazeRooms) {
				var reached = false;
				var stuck = false;
				for (x in r[0]...r[1] + 1)
					for (w in 0...NW) {
						var st = (x * H + r[2]) * NW + w;
						if (an.seen[st]) {
							reached = true;
							if (!an.canExit[st])
								stuck = true;
						}
					}
				(reached && !stuck ? good : bad).push(r);
			}
			if (bad.length == 0 && (made >= 4 || !Gen.chance([0.9, 0.7, 0.5, 0.3][made])))
				return made;
			if (it == 7)
				break;
			var r = bad.length > 0 ? bad[0] : null;
			var pair:Array<GenField> = null;
			var lying = Gen.chance(0.45);
			for (k in 0...2)
				if (pair == null)
					pair = (k == 0) == lying ? mazeLying(lv, r, used) : mazeStanding(lv, r, good, used);
			if (pair == null)
				return bad.length > 0 ? -1 : made;
			lv.teles.push(pair);
			made++;
		}
		return -1;
	}

	// a pair standing from floor to ceiling in a storey of 2 rows: a room wrong and a right one of the storey, or two right
	// ones (null: none)
	static function mazeStanding(lv:GenGrid, r:Array<Int>, good:Array<Array<Int>>, used:Map<String, Bool>):Array<GenField> {
		var pairs = r != null ? [for (q in good) if (q[2] == r[2]) [r, q]] : [for (a in good) for (q in good) if (a[0] < q[0] && a[2] == q[2]) [a, q]];
		Gen.shuffle(pairs);
		for (p in pairs) {
			var a = p[0];
			var q = p[1];
			var len = a[2] - a[3] + 1;
			var key = "v" + a[3] + ":" + len;
			if (len != 2 || used.exists(key))
				continue;
			// (each one at the end of its room on the side of the other one, now and then at the other end)
			var ta = mazeTele(lv, a, (q[0] > a[0] ? 1 : -1) * (Gen.chance(0.3) ? -1 : 1), len);
			var tq = mazeTele(lv, q, (a[0] > q[0] ? 1 : -1) * (Gen.chance(0.3) ? -1 : 1), len);
			if (ta == null || tq == null)
				continue;
			used.set(key, true);
			return [ta, tq];
		}
		return null;
	}

	// a pair lying in holes of 2 of two floors one over the other, at least a floor between them kept whole in those
	// columns (else falling out of the upper one Igor would come down into the lower one again and again), the holes
	// inside rooms, grounds on both sides: one of them in the ceiling or the floor of the room r (any for a shortcut)
	static function mazeLying(lv:GenGrid, r:Array<Int>, used:Map<String, Bool>):Array<GenField> {
		var floors = lv.mazeFloors;
		var fm = lv.fieldMap();
		function hole(x:Int, y:Int):Bool {
			if (!lv.ground(x - 1, y) || !lv.ground(x, y) || !lv.ground(x + 1, y) || !lv.ground(x + 2, y))
				return false;
			for (xx in x...x + 2)
				for (dy in [-1, 1])
					if (y + dy < H && (lv.ground(xx, y + dy) || fm[xx * H + y + dy] != 0))
						return false;
			return true;
		}
		var opts = [];
		for (i in 0...floors.length)
			for (j in i + 2...floors.length)
				for (x in 1...W - 2) {
					var ya = floors[i];
					var yb = floors[j];
					if (r != null) {
						var mine = (ya == r[3] - 1 || ya == r[2] + 1 || yb == r[3] - 1 || yb == r[2] + 1) && x >= r[0] && x + 1 <= r[1];
						if (!mine)
							continue;
					}
					if (used.exists("h" + x) || !hole(x, ya) || !hole(x, yb))
						continue;
					var whole = false;
					for (k in i + 1...j)
						if (lv.ground(x - 1, floors[k]) && lv.ground(x, floors[k]) && lv.ground(x + 1, floors[k]) && lv.ground(x + 2, floors[k]))
							whole = true;
					if (whole)
						opts.push([x, ya, yb]);
				}
		if (opts.length == 0)
			return null;
		var o = Gen.pick(opts);
		var x = o[0];
		used.set("h" + x, true);
		var out = [];
		for (y in [o[1], o[2]]) {
			lv.set(x, y, 0);
			lv.set(x + 1, y, 0);
			out.push({v: Data.FIELD_TELEPORT, cells: [x * H + y, (x + 1) * H + y], why: "dédale"});
		}
		return out;
	}

	// a teleporter of a room of a maze standing on its floor, len cases high, the nearest to its side d (null: no place)
	static function mazeTele(lv:GenGrid, r:Array<Int>, d:Int, len:Int):GenField {
		var fm = lv.fieldMap();
		var xs = [for (x in r[0]...r[1] + 1) x];
		if (d > 0)
			xs.reverse();
		for (x in xs) {
			var y = r[2];
			// (from the floor to a ceiling: a block over it, not a hole)
			if (!lv.stand(x, y) || !lv.stand(x - 1, y) && !lv.stand(x + 1, y) || !lv.ground(x, y - len))
				continue;
			// (none by another teleporter: the game reads two side by side as one lying across, World.drawFields)
			var ok = true;
			for (k in 0...len) {
				if (!lv.empty(x, y - k) || fm[x * H + y - k] != 0)
					ok = false;
				for (nx in [x - 1, x + 1])
					if (nx >= 0 && nx < W && fm[nx * H + y - k] == Data.FIELD_TELEPORT)
						ok = false;
			}
			if (ok)
				return {v: Data.FIELD_TELEPORT, cells: [for (k in 0...len) x * H + y - len + 1 + k], why: "dédale"};
		}
		return null;
	}

	static function mdist(a:Int, b:Int):Int {
		return Std.int(Math.abs(GenGrid.cx(a) - GenGrid.cx(b)) + Math.abs(GenGrid.cy(a) - GenGrid.cy(b)));
	}

	// two teleporters between two places far apart
	public static function addShortcut(lv:GenGrid, depth:Int):Bool {
		var an = new GenAnalysis(lv, depth);
		var st = lv.sx * H + lv.sy;
		var sites = [
			for (s in teleSites(lv, an, [])) if (mdist(s, st) >= 4 && Lambda.foreach(lv.bads, function(b) return mdist(s, b.x * H + b.y) > 2)) s
		];
		if (sites.length < 2)
			return false;
		// (lying in two holes one over the other now and then)
		if (Gen.chance(0.45) && lyingShortcut(lv, an, depth))
			return true;
		var best = null;
		var bd = -1;
		for (k in 0...40) {
			var a = sites[Gen.rnd(sites.length)];
			var b = sites[Gen.rnd(sites.length)];
			if (a == b || Math.abs(GenGrid.cy(a) - GenGrid.cy(b)) < 5 || teleHeight(lv, a) != teleHeight(lv, b))
				continue;
			var d = Std.int(Math.abs(an.cellDist[a] - an.cellDist[b]));
			if (d > bd) {
				bd = d;
				best = [a, b];
			}
		}
		if (best == null || bd < 6)
			return lyingShortcut(lv, an, depth);
		lv.teles.push([teleField(lv, best[0]), teleField(lv, best[1])]);
		var ck = check(lv, depth);
		if (!ck.ok) {
			lv.teles.pop();
			return false;
		}
		lv.notes.push("raccourci");
		return true;
	}

	// a shortcut lying in two holes of 2 of floors one over the other, a ground kept whole between them in
	// their columns (no fall from the upper one into the lower one), far apart on the ways of Igor
	static function lyingShortcut(lv:GenGrid, an:GenAnalysis, depth:Int):Bool {
		var holes = [for (h in holeSites(lv, 2)) if (h.length == 2 && nearReach(h, an.reach)) h];
		var best = null;
		var bd = 5;
		for (a in holes)
			for (b in holes) {
				var ya = GenGrid.cy(a[0]);
				var yb = GenGrid.cy(b[0]);
				if (ya + 3 > yb || GenGrid.cx(a[0]) != GenGrid.cx(b[0]) || a.length != b.length)
					continue;
				var x0 = GenGrid.cx(a[0]);
				var whole = false;
				for (y in ya + 1...yb) {
					var all = true;
					for (x in x0 - 1...x0 + a.length + 1)
						if (!lv.ground(x, y))
							all = false;
					if (all)
						whole = true;
				}
				if (!whole)
					continue;
				// (Igor standing by them, the left one: far apart on his ways)
				var da = an.cellDist[a[0] - H - 1];
				var db = an.cellDist[b[0] - H - 1];
				if (da < 0 || db < 0)
					continue;
				var d = Std.int(Math.abs(da - db));
				if (d > bd) {
					bd = d;
					best = [a, b];
				}
			}
		if (best == null)
			return false;
		lv.teles.push([{v: Data.FIELD_TELEPORT, cells: best[0], why: "raccourci"}, {v: Data.FIELD_TELEPORT, cells: best[1], why: "raccourci"}]);
		if (!check(lv, depth).ok) {
			lv.teles.pop();
			return false;
		}
		lv.notes.push("raccourci couché");
		return true;
	}

	// ---------------------------------------------------------------- lasers put for themselves

	// Igor comes by the passage: on it or by it (beside a hole of a floor, he stands on the floor)
	static function nearReach(cells:Array<Int>, reach:Array<Bool>):Bool {
		for (c in cells) {
			var x = GenGrid.cx(c);
			var y = GenGrid.cy(c);
			for (dx in -1...2)
				for (dy in -1...2)
					if (x + dx >= 0 && x + dx < W && y + dy >= 0 && y + dy < H && reach[(x + dx) * H + y + dy])
						return true;
		}
		return false;
	}

	// gates: a laser across a passage Igor must take to reach two fruits or more (the region behind it): he gets there
	// with other bombs. The colour after what is behind: black ones for fruits shut in or hard to throw out, red ones
	// (from GenRules.RED_FROM) for fruits in wells open at the top, blue ones over a floor with the void under it, green
	// ones (flasks) for shooters

	// a gate decided before the fruits: a passage Igor has to take to reach a part of the level (the standing cases he
	// no longer reaches with it stopped up), room for fruits there and a part left before it (null: none)
	public static function planGate(lv:GenGrid, an:GenAnalysis, depth:Int):{cells:Array<Int>, region:Array<Bool>} {
		var total = 0;
		for (c in 0...W * H)
			if (an.reach[c] && lv.stand(GenGrid.cx(c), GenGrid.cy(c)))
				total++;
		var sites = doorSites(lv, an.reach).concat(holeSites(lv, 4));
		Gen.shuffle(sites);
		var keyed = [for (i in 0...sites.length) {s: sites[i], o: openings(lv, sites[i]), i: i}];
		keyed.sort(function(a, b) return a.o != b.o ? a.o - b.o : a.i - b.i);
		var best:{cells:Array<Int>, region:Array<Bool>} = null;
		var bs = -1.0e9;
		var tried = 0;
		for (e in keyed) {
			if (tried >= 8)
				break;
			var cells = e.s;
			if (!nearReach(cells, an.reach))
				continue;
			tried++;
			var t = lv.copy();
			for (c in cells)
				t.g[c] = 1;
			if (t.ground(t.sx, t.sy))
				continue;
			var an2 = new GenAnalysis(t, depth);
			var region = [for (i in 0...W * H) false];
			var n = 0;
			var rows = new Map<Int, Bool>();
			for (c in 0...W * H)
				if (an.reach[c] && !an2.reach[c] && cells.indexOf(c) < 0 && lv.stand(GenGrid.cx(c), GenGrid.cy(c))) {
					region[c] = true;
					n++;
					rows.set(GenGrid.cy(c), true);
				}
			var nrows = Lambda.count(rows);
			if (n < 6 || n > total * 0.6 || nrows < 2)
				continue;
			var s = -Math.abs(n - total * 0.4) * 0.3 - e.o * 1.5 + nrows + Gen.frand();
			if (s > bs) {
				bs = s;
				best = {cells: cells, region: region};
			}
		}
		return best;
	}

	public static function addGates(lv:GenGrid, depth:Int, n:Int):Int {
		var made = 0;
		// (each gate keeps a group of its own: fruits behind another gate, or shut in with their own laser, do not count)
		var an0 = new GenAnalysis(lv, depth);
		var covered = [for (b in lv.bads) if (b.id != Data.BAD_SAW && b.id != Data.BAD_SPEAR && an0.killInfo(b.id, b.x * H + b.y)[0][0] == 0) b.x * H + b.y];
		for (k in 0...n) {
			var an = new GenAnalysis(lv, depth);
			var sites = doorSites(lv, an.reach).concat(holeSites(lv, 4));
			Gen.shuffle(sites);
			// (the holes of a floor with few ways down first: Igor has to take them; the gate decided before the fruits
			// first of all)
			var keyed = [for (i in 0...sites.length) {s: sites[i], o: openings(lv, sites[i]), i: i}];
			keyed.sort(function(a, b) return a.o != b.o ? a.o - b.o : a.i - b.i);
			sites = [for (e in keyed) e.s];
			if (k == 0 && lv.gatePlan != null)
				sites.unshift(lv.gatePlan);
			var best:{cells:Array<Int>, behind:Array<{id:Int, x:Int, y:Int}>} = null;
			var tried = 0;
			for (cells in sites) {
				if (tried >= 8)
					break;
				if (!nearReach(cells, an.reach))
					continue;
				tried++;
				var behind = [for (b in cutOff(lv, an, depth, cells)) if (covered.indexOf(b.x * H + b.y) < 0) b];
				if (behind.length >= (depth < 15 ? 2 : 1) && (best == null || behind.length > best.behind.length))
					best = {cells: cells, behind: behind};
			}
			if (best == null)
				break;
			var shooters = 0;
			var shut = 0;
			for (b in best.behind) {
				if (b.id == Data.BAD_POMME || b.id == Data.BAD_POIRE || b.id == Data.BAD_CITRON || b.id == Data.BAD_KIWI)
					shooters++;
				if (an.killInfo(b.id, b.x * H + b.y)[0][0] != 1)
					shut++;
			}
			var colours = [BLACK, BLUE, RED, GREEN];
			var ws = [shut * 3 + 2, 3, depth >= GenRules.RED_FROM ? 2 : 0, shooters * 2 + 1];
			var placed = false;
			for (attempt in 0...3) {
				var v = colours[Cs.draw(ws)];
				lv.fields.push({v: v, cells: best.cells, why: why(v) + " (passage)"});
				var ck = check(lv, depth);
				if (ck.ok) {
					lv.notes.push(why(v) + " au passage (" + best.behind.length + (best.behind.length > 1 ? " fruits" : " fruit") + " derrière)");
					for (b in best.behind)
						covered.push(b.x * H + b.y);
					placed = true;
					made++;
					break;
				}
				lv.fields.pop();
			}
			if (!placed)
				break;
		}
		return made;
	}

	// the ways down of the row of a hole (its runs of empty cases); a door (a laser standing): 3
	static function openings(lv:GenGrid, cells:Array<Int>):Int {
		var y = GenGrid.cy(cells[0]);
		if (cells.length > 1 && GenGrid.cy(cells[1]) != y)
			return 3;
		var n = 0;
		var x = 0;
		while (x < W) {
			if (!lv.ground(x, y)) {
				n++;
				while (x < W && !lv.ground(x, y))
					x++;
			} else
				x++;
		}
		return n;
	}

	// the fruits Igor can no longer kill when the passage is stopped up
	// (a passage on the way out too: the fruits under it are behind it; a walking fruit is cut off when Igor can no
	// longer hit it anywhere it goes, an0 the analysis of the level as it is)
	static function cutOff(lv:GenGrid, an0:GenAnalysis, depth:Int, cells:Array<Int>):Array<{id:Int, x:Int, y:Int}> {
		var t = lv.copy();
		for (c in cells)
			t.g[c] = 1;
		if (t.ground(t.sx, t.sy))
			return [];
		var an = new GenAnalysis(t, depth);
		var out = [];
		for (b in lv.bads) {
			if (b.id == Data.BAD_SAW || b.id == Data.BAD_SPEAR || t.ground(b.x, b.y))
				continue;
			var c = b.x * H + b.y;
			if (GenAnalysis.walks(b.id)) {
				if (!Lambda.exists(an0.zone(b.id, c), function(z) return an.reach[z]))
					out.push(b);
			} else if (!an.killable(b.id, c))
				out.push(b);
		}
		return out;
	}

	// spikes on the ways of Igor: strips of 1 or 2 cases in the middle of a platform he walks (he jumps over them),
	// never where a fruit goes (it would die there by itself), nor by his landing or a laser
	public static function addSpikes(lv:GenGrid, depth:Int, n:Int):Int {
		var made = 0;
		var st = lv.sx * H + lv.sy;
		for (k in 0...n) {
			var an = new GenAnalysis(lv, depth);
			var busy = [for (i in 0...W * H) false];
			function mark(c:Int) {
				var x = GenGrid.cx(c);
				var y = GenGrid.cy(c);
				for (dx in -1...2)
					for (dy in -1...2)
						if (lv.inb(x + dx, y + dy))
							busy[(x + dx) * H + y + dy] = true;
			}
			for (b in lv.bads) {
				mark(b.x * H + b.y);
				if (b.id != Data.BAD_SPEAR)
					for (c in an.zone(b.id, b.x * H + b.y))
						mark(c);
			}
			var fm = lv.fieldMap();
			for (c in 0...W * H)
				if (fm[c] != 0)
					mark(c);
			// (no fruit jumps up through a ceiling with spikes under it: nothing of a fruit under it on 3 rows)
			var cands = [];
			for (sg in lv.segments()) {
				if (sg[1] - sg[0] + 1 < 5)
					continue;
				var y = sg[2];
				for (x in sg[0] + 2...sg[1] - 1) {
					var c = x * H + y;
					if (!an.reach[c] || busy[c] || x == lv.sx || mdist(c, st) < 5)
						continue;
					if (!lv.empty(x, y - 1) || !lv.empty(x, y - 2))
						continue;
					cands.push(c);
				}
			}
			// spikes under a ceiling (pointing down) over the places where Igor walks and jumps
			for (x in 1...W - 1)
				for (y in 3...H - 3) {
					var c = x * H + y;
					if (!lv.ground(x, y - 1) || !lv.empty(x, y) || !lv.empty(x, y + 1) || lv.ground(x, y + 1) || busy[c])
						continue;
					if (x == lv.sx || mdist(c, st) < 5)
						continue;
					var under = false;
					var fruit = false;
					for (k in 1...4)
						if (lv.inb(x, y + k)) {
							if (an.reach[x * H + y + k])
								under = true;
							if (busy[x * H + y + k])
								fruit = true;
						}
					if (under && !fruit)
						cands.push(c);
				}
			if (cands.length == 0)
				break;
			Gen.shuffle(cands);
			var ok = false;
			var tries = 0;
			for (c in cands) {
				if (tries++ >= 6)
					break;
				var strip = [c];
				var c2 = c + H;
				if (Gen.chance(0.5) && cands.indexOf(c2) >= 0)
					strip.push(c2);
				var c3 = c2 + H;
				if (strip.length == 2 && Gen.chance(0.3) && cands.indexOf(c3) >= 0)
					strip.push(c3);
				for (sc in strip)
					lv.bads.push({id: Data.BAD_SPEAR, x: GenGrid.cx(sc), y: GenGrid.cy(sc)});
				if (check(lv, depth).ok) {
					ok = true;
					made++;
					break;
				}
				for (sc in strip)
					lv.bads.pop();
			}
			if (!ok)
				break;
		}
		if (made > 0)
			lv.notes.push(made == 1 ? "pics" : made + " bandes de pics");
		return made;
	}

	// green bombs on the way to the shooters
	public static function addGreen(lv:GenGrid, depth:Int):Bool {
		var shooters = [for (b in lv.bads) if (b.id == Data.BAD_POMME || b.id == Data.BAD_POIRE || b.id == Data.BAD_CITRON || b.id == Data.BAD_KIWI) b];
		if (shooters.length == 0)
			return false;
		var an = new GenAnalysis(lv, depth);
		var zone:Array<Int> = [];
		for (b in shooters)
			zone = zone.concat(an.zone(b.id, b.x * H + b.y));
		var sites = [for (s in doorSites(lv, an.reach).concat(holeSites(lv, 4))) if (siteDist(s, zone) >= 2 && siteDist(s, zone) <= 7) s];
		Gen.shuffle(sites);
		var k = 0;
		for (cells in sites) {
			if (k++ >= 6)
				break;
			lv.fields.push({v: GREEN, cells: cells, why: "fioles contre les tireurs"});
			if (check(lv, depth).ok) {
				lv.notes.push("verte");
				return true;
			}
			lv.fields.pop();
		}
		return false;
	}
}
