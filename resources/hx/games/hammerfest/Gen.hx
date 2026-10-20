package hammerfest;

import hammerfest.GenFruits.GenPlacer;

import hammerfest.Levels.LevelData;

// The generator of the levels of the well, made at random with the random of the game (a seed gives its well, a
// replay its levels). For each level:
// - its bads drawn first, by weight for the budget of the level (GenFruits, GenRules: each kind has a weight, the
//   total grows along the well, a new kind is shown off at its first level);
// - a way of building drawn for the depth and for its bads (GenShapes), never the one of the last levels;
// - the analysis (GenAnalysis): a way from the top to the way out, no place Igor can no longer get out from, every
//   fruit killed (its ice thrown out of the level, or the right bombs on the way of Igor: GenDevices);
// - the bads placed for what they do (GenPlacer), the shut places (room of a teleporter, vault, closed cup) first;
// - devices put for themselves (laser without bombs on a passage Igor must take, flasks, shortcut teleporters).
// A few levels are drawn that way, the best one is kept (weight close to the budget, ground share of its depth).
class Gen {
	static inline var W = Data.LEVEL_WIDTH;
	static inline var H = Data.LEVEL_HEIGHT;

	// (debug builds: game.html?...&kind=<way of building> forces it)
	public static var forceShape:String = null;
	// (test harness: the way of building of the last level, its notes)
	public static var lastKind:String = "";
	public static var lastNotes:Array<String> = [];
	public static var lastWeight:Float = 0;
	public static var lastGrid:GenGrid = null;

	static var recentShapes:Array<String> = [];
	static var lastFloor = -9; // the last level with a floor across it (GenShapes.addFloor)
	static var lastRoom = -9; // the last level with the room of a teleporter
	static var lastLead:Int = -1;

	// ---------------------------------------------------------------- random of the game

	public static inline function rnd(n:Int):Int {
		return Cs.rnd(n);
	}

	public static function ri(a:Int, b:Int):Int {
		return b <= a ? a : a + Cs.rnd(b - a + 1);
	}

	public static function frand():Float {
		return Cs.rnd(1000000) / 1000000.0;
	}

	public static function chance(p:Float):Bool {
		return Cs.rnd(1000000) < Std.int(p * 1000000);
	}

	public static function pick<T>(a:Array<T>):T {
		return a[Cs.rnd(a.length)];
	}

	public static function shuffle<T>(a:Array<T>) {
		for (i in 0...a.length - 1) {
			var j = i + Cs.rnd(a.length - i);
			var t = a[i];
			a[i] = a[j];
			a[j] = t;
		}
	}

	// ---------------------------------------------------------------- the well

	public static function reset() {
		recentShapes = [];
		lastFloor = -9;
		lastRoom = -9;
		lastLead = -1;
		zoneSkin = null;
		zoneEnd = -1;
	}

	public static function make(depth:Int):LevelData {
		var lineup = GenFruits.lineupOf(depth, lastLead);
		var budget = GenRules.budget(depth);
		var best:GenGrid = null;
		var bestRate = -1.0e9;
		var tried:Array<String> = [];
		// (6 tries more when the best level lost two fruits or more)
		for (attempt in 0...GenRules.TRIES + 6) {
			if (attempt >= GenRules.TRIES && best != null && bestRate > -9)
				break;
			var shape = forceShape != null ? forceShape : chooseShape(depth, lineup, tried);
			tried.push(shape);
			var lv = tryLevel(shape, depth, lineup);
			if (lv == null)
				continue;
			var r = rate(lv, depth, budget);
			if (r > bestRate) {
				best = lv;
				bestRate = r;
			}
			// (a good one after 3 tries, a fair one after 6)
			if ((r > -1.5 && attempt >= 2) || (bestRate > -3 && attempt >= 5))
				break;
		}
		if (best == null)
			best = fallback(depth, lineup);
		recentShapes.push(best.shape);
		if (recentShapes.length > 14)
			recentShapes.shift();
		if (best.notes.indexOf("plancher à trappe") >= 0)
			lastFloor = depth;
		if (best.room != null)
			lastRoom = depth;
		lastLead = lineup.length > 0 ? lineup[0] : -1;
		lastKind = best.label;
		lastNotes = best.notes;
		lastWeight = GenFruits.weightOf([for (b in best.bads) b.id]);
		lastGrid = best;
		return data(best, depth);
	}

	static function chooseShape(depth:Int, lineup:Array<Int>, tried:Array<String>):String {
		var w:Map<String, Float> = null;
		for (s in GenRules.SHAPES)
			if (depth >= s.from)
				w = s.w;
		var names = [];
		var ws = [];
		for (name in GenRules.SHAPE_NAMES) {
			if (!w.exists(name))
				continue;
			var v = w.get(name);
			var kinds = [];
			for (id in lineup)
				if (kinds.indexOf(id) < 0) {
					kinds.push(id);
					v *= GenRules.affinity(id, name);
				}
			var mem = recentShapes.slice(Std.int(Math.max(0, recentShapes.length - GenRules.memory(name))));
			if (mem.indexOf(name) >= 0)
				v *= 0.08;
			if (tried.indexOf(name) >= 0)
				v *= 0.35;
			names.push(name);
			ws.push(Std.int(Math.round(Cs.qt(v) * 1000)));
		}
		var i = Cs.draw(ws);
		return i < 0 ? names[0] : names[i];
	}

	// one level drawn with a way of building: null when something is wrong in it
	static function tryLevel(shape:String, depth:Int, lineup:Array<Int>):GenGrid {
		var closed = chance(GenRules.chanceClosedBottom(depth));
		var lv = GenShapes.build(shape, depth, closed);
		if (closed)
			closedBottom(lv, depth);
		// (seldom two levels in a row with the room of a teleporter; a maze has rooms of its own, and walking fruits)
		var maze = lv.mazeRooms != null;
		if (maze)
			lineup = GenFruits.forMaze(lineup, depth);
		var room = !maze && chance(GenRules.chanceRoom(depth) * (depth - lastRoom < 2 ? 0.25 : 1));
		if (room) {
			GenDevices.carveRoom(lv);
			GenShapes.fixHeadroom(lv);
			GenShapes.removeStubs(lv);
		}
		if (!maze)
			GenShapes.addPrisons(lv, GenRules.prisons(depth));
		if (!chooseStart(lv, depth))
			return null;
		if (maze) {
			var n = GenDevices.linkMaze(lv, depth);
			if (n < 0)
				return null;
			if (n > 0)
				lv.notes.push(n + (n > 1 ? " paires de téléporteurs" : " paire de téléporteurs"));
		}
		if (room && (!lv.stand(GenGrid.cx(lv.roomTele), GenGrid.cy(lv.roomTele)) || !GenDevices.linkRoom(lv, depth)))
			return null;
		// (a shortcut of teleporters before the fruits: the pears and the kiwis like to shoot through them)
		if (lv.teles.length == 0 && chance(GenRules.chanceShortcut(depth)))
			GenDevices.addShortcut(lv, depth);
		var an = new GenAnalysis(lv, depth);
		if (an.exitCount == 0 || an.traps > 0)
			return null;
		// a gate decided before the fruits: on a passage the level has, else in the trapdoor of a floor put across it
		// (not two levels in a row)
		var gate = null;
		if (chance(GenRules.chancePlannedGate(depth))) {
			gate = GenDevices.planGate(lv, an, depth);
			if (gate == null && !maze && depth - lastFloor >= 3 && chance(0.6) && GenShapes.addFloor(lv)) {
				var y = 0;
				while (y + 1 < H && !lv.ground(lv.sx, y + 1))
					y++;
				lv.sy = y;
				if (lv.sy < 3)
					return null;
				an = new GenAnalysis(lv, depth);
				if (an.exitCount == 0 || an.traps > 0)
					return null;
				gate = GenDevices.planGate(lv, an, depth);
			}
		}
		if (!placeBads(lv, an, lineup, depth, gate) || lv.sy < 3)
			return null;
		if (!GenDevices.unlockFruits(lv, depth)) {
			// the fruits no bomb can kill go rather than the whole level
			var ck = GenDevices.check(lv, depth);
			if (ck.an.exitCount == 0 || ck.an.traps > 0)
				return null;
			for (b in ck.bad) {
				lv.bads.remove(b);
				lv.notes.push("-" + GenRules.kind(b.id).name.toLowerCase());
			}
			// (their prison taken back when they were all in it)
			if (ck.bad.length > 0 && openEmpty(lv) && lv.sy < 3)
				return null;
		}
		GenDevices.addGates(lv, depth, GenRules.gates(depth));
		if (chance(GenRules.chanceGreen(depth)))
			GenDevices.addGreen(lv, depth);
		GenDevices.addSpikes(lv, depth, GenRules.spikes(depth));
		var ck = GenDevices.check(lv, depth, true);
		if (!ck.ok)
			return null;
		measure(lv, ck.an);
		return lv;
	}

	// the fruits killed by the ice of another one pushed (surfing), the ones white bombs never kill (shut in)
	static function measure(lv:GenGrid, an:GenAnalysis) {
		var fruits = [for (b in lv.bads) if (b.id != Data.BAD_SPEAR && b.id != Data.BAD_SAW) b];
		var cells = [for (b in fruits) b.x * H + b.y];
		var surfed = [for (b in fruits) false];
		var shut = 0;
		for (i in 0...fruits.length) {
			var b = fruits[i];
			if (an.killInfo(b.id, cells[i])[0][0] == 0)
				shut++;
			if (GenAnalysis.walks(b.id))
				for (d in [-1, 1]) {
					var path = [];
					an.push(b.x, b.y, d, path);
					for (j in 0...fruits.length)
						if (j != i && path.indexOf(cells[j]) >= 0)
							surfed[j] = true;
				}
		}
		var n = Math.max(1, fruits.length);
		lv.surfShare = Lambda.count(surfed, function(s) return s) / n;
		lv.shutShare = shut / n;
	}

	// the column Igor falls in from the top: he lands on the first platform under him
	static function chooseStart(lv:GenGrid, depth:Int):Bool {
		var best = -1;
		var bs = -1.0e9;
		for (x in 1...W - 1) {
			var y = 0;
			while (y + 1 < H && !lv.ground(x, y + 1))
				y++;
			if (y + 1 >= H || lv.ground(x, y))
				continue;
			if (y < 3 || y > H - 5)
				continue;
			var seg = lv.segmentOf(x, y);
			if (seg == null || seg[1] - seg[0] + 1 < 2)
				continue;
			var s = -Math.abs(x - (W - 1) / 2) * (depth < 10 ? 0.5 : 0.15) - y * 0.15 + frand() * 2;
			if (seg[1] - seg[0] + 1 < 3)
				s -= 4;
			if (x == seg[0] || x == seg[1])
				s -= 1.5;
			if (s > bs) {
				bs = s;
				best = x * H + y;
			}
		}
		if (best < 0)
			return false;
		lv.sx = GenGrid.cx(best);
		lv.sy = GenGrid.cy(best);
		return true;
	}

	// a floor at the very bottom with a few holes (the way out)
	static function closedBottom(lv:GenGrid, depth:Int) {
		var low = 0;
		for (x in 0...W)
			for (y in 0...H)
				if (lv.ground(x, y) && y > low)
					low = y;
		if (low > H - 4)
			return;
		lv.hline(0, W - 1, H - 1);
		var n = depth < 12 ? pick([1, 2, 2, 3]) : pick([1, 1, 2]);
		var xs = [for (x in 1...W - 2) x];
		shuffle(xs);
		var holes = [];
		for (hx in xs) {
			if (holes.length >= n)
				break;
			var near = false;
			for (h in holes)
				if (Math.abs(hx - h) < 4)
					near = true;
			if (near)
				continue;
			holes.push(hx);
			lv.set(hx, H - 1, 0);
			lv.set(hx + 1, H - 1, 0);
		}
		lv.notes.push("fond fermé");
	}

	// ---------------------------------------------------------------- the bads

	// shut places where bads are put on purpose: the room of a teleporter, a vault, a cup with no hole (they will need
	// the right bombs, GenDevices.unlockFruits)
	static function enclosures(lv:GenGrid, depth:Int):Array<{name:String, cells:Array<Int>, n:Int}> {
		var out = [];
		if (lv.room != null)
			out.push({name: "salle", cells: [for (c in lv.room) if (c != lv.roomTele && Math.abs(GenGrid.cx(c) - GenGrid.cx(lv.roomTele)) >= 2) c], n: pick([1, 2])});
		if (lv.vault != null && chance(0.85)) {
			var v = lv.vault;
			out.push({name: "caveau", cells: [for (x in v[0]...v[2] + 1) if (lv.stand(x, v[3] - 1)) x * H + v[3] - 1], n: pick([1, 1, 2])});
		}
		for (ce in lv.cells)
			out.push({name: "cellule", cells: [for (x in ce[0]...ce[1] + 1) if (lv.stand(x, ce[2])) x * H + ce[2]], n: pick([1, 2])});
		if (lv.cups.length > 0 && depth >= 5) {
			var closed = [];
			for (cu in lv.cups) {
				var full = true;
				for (x in cu[0]...cu[1] + 1)
					if (!lv.ground(x, cu[2]))
						full = false;
				var cells = [for (x in cu[0] + 1...cu[1]) if (lv.stand(x, cu[2] - 1)) x * H + cu[2] - 1];
				if (full && cells.length > 0)
					closed.push(cells);
			}
			shuffle(closed);
			for (k in 0...closed.length)
				out.push({name: "coupe", cells: closed[k], n: 1});
		}
		return out;
	}

	static function placeBads(lv:GenGrid, an:GenAnalysis, lineup:Array<Int>, depth:Int,
			?gate:{cells:Array<Int>, region:Array<Bool>}):Bool {
		var nf = 0;
		for (id in lineup)
			if (GenRules.kind(id).counts)
				nf++;
		var pl = new GenPlacer(lv, an, depth, nf);
		var st = lv.sx * H + lv.sy;
		var done = [for (i in 0...lineup.length) false];
		var shut:Array<Int> = [];
		for (e in enclosures(lv, depth)) {
			var inside = e.name == "salle" ? lv.room.copy() : e.cells.copy();
			var cells = [
				for (c in e.cells)
					if (Math.abs(GenGrid.cx(c) - GenGrid.cx(st)) + Math.abs(GenGrid.cy(c) - GenGrid.cy(st)) >= 5 && pl.taken.indexOf(c) < 0) c
			];
			var walkers = [for (i in 0...lineup.length) if (!done[i] && GenAnalysis.walks(lineup[i]) && lineup[i] != Data.BAD_FRAISE) i];
			// the strongest first
			var keyed = [for (i in walkers) {i: i, k: GenRules.kind(lineup[i]).weight * 10 + frand()}];
			keyed.sort(function(a, b) return a.k < b.k ? 1 : (a.k > b.k ? -1 : 0));
			var n = 0;
			for (e2 in keyed) {
				if (n >= e.n)
					break;
				var free = [
					for (c in cells)
						if (Lambda.foreach(pl.taken, function(t) return Math.abs(GenGrid.cx(c) - GenGrid.cx(t)) > 1 || GenGrid.cy(c) != GenGrid.cy(t))) c
				];
				if (free.length == 0)
					break;
				var c = pick(free);
				// the bad must stay shut in (the ones jumping up go through a low ceiling)
				var z = an.zone(lineup[e2.i], c);
				if (!Lambda.foreach(z, function(zc) return inside.indexOf(zc) >= 0))
					continue;
				pl.take(c, lineup[e2.i]);
				pl.obligations++;
				lv.bads.push({id: lineup[e2.i], x: GenGrid.cx(c), y: GenGrid.cy(c)});
				shut.push(c);
				shut.push(lineup[e2.i]);
				done[e2.i] = true;
				n++;
				lv.enclosed.push(e.name);
			}
		}
		// the prisons no fruit went in are taken back
		if (openEmpty(lv)) {
			an = new GenAnalysis(lv, depth);
			if (an.exitCount == 0 || an.traps > 0)
				return false;
			pl = new GenPlacer(lv, an, depth, nf);
			var k = 0;
			while (k + 1 < shut.length) {
				pl.take(shut[k], shut[k + 1]);
				pl.obligations++;
				k += 2;
			}
		}
		// the fruits behind the gate decided (the strongest first): they will need its bombs
		if (gate != null && !lv.ground(GenGrid.cx(gate.cells[0]), GenGrid.cy(gate.cells[0]))) {
			var want = depth < 15 ? 2 : pick([1, 2, 2, 3]);
			var keyed = [
				for (i in 0...lineup.length)
					if (!done[i] && GenAnalysis.walks(lineup[i]) && GenRules.kind(lineup[i]).counts)
						{i: i, k: GenRules.kind(lineup[i]).weight * 10 + frand()}
			];
			keyed.sort(function(a, b) return a.k < b.k ? 1 : (a.k > b.k ? -1 : 0));
			var got = 0;
			for (e in keyed) {
				if (got >= want)
					break;
				var c = pl.place(lineup[e.i], gate.region);
				if (c < 0)
					continue;
				lv.bads.push({id: lineup[e.i], x: GenGrid.cx(c), y: GenGrid.cy(c)});
				done[e.i] = true;
				pl.obligations++;
				got++;
			}
			if (got >= (depth < 15 ? 2 : 1))
				lv.gatePlan = gate.cells;
		}
		for (i in 0...lineup.length) {
			if (done[i])
				continue;
			var c = pl.place(lineup[i]);
			if (c < 0)
				lv.notes.push("-" + GenRules.kind(lineup[i]).name.toLowerCase());
			else
				lv.bads.push({id: lineup[i], x: GenGrid.cx(c), y: GenGrid.cy(c)});
		}
		return true;
	}

	// a prison (GenShapes.addPrisons) with no fruit inside is a trap for the ices: the platform as it was (the landing
	// of Igor moved if it was in it); true when one was taken back
	static function openEmpty(lv:GenGrid):Bool {
		var back:Array<Int> = [];
		function empty(x0:Int, x1:Int, y:Int):Bool {
			for (b in lv.bads)
				if (b.x >= x0 && b.x <= x1 && b.y <= y && b.y >= y - 2)
					return false;
			return true;
		}
		for (ce in lv.cells)
			if (ce.length > 3 && empty(ce[0], ce[1], ce[2]))
				back.push(ce[3]);
		for (cu in lv.cups)
			if (cu.length > 3 && empty(cu[0] + 1, cu[1] - 1, cu[2] - 1))
				back.push(cu[3]);
		if (back.length == 0)
			return false;
		for (k in back)
			lv.takeBack(k);
		var y = 0;
		while (y + 1 < H && !lv.ground(lv.sx, y + 1))
			y++;
		lv.sy = y;
		return true;
	}

	// ---------------------------------------------------------------- choosing among the levels drawn

	static function densityTarget(depth:Int):Array<Float> {
		if (depth <= 6)
			return [0.07, 0.15];
		if (depth <= 15)
			return [0.10, 0.21];
		if (depth <= 30)
			return [0.12, 0.26];
		return [0.14, 0.32];
	}

	static function rate(lv:GenGrid, depth:Int, budget:Float):Float {
		var w = GenFruits.weightOf([for (b in lv.bads) b.id]);
		var r = -Math.abs(w - budget) / Math.max(1.0, budget) * 6.0;
		for (n in lv.notes)
			if (n.charAt(0) == "-")
				r -= 5;
		var t = densityTarget(depth);
		var dn = lv.density();
		if (dn < t[0])
			r -= (t[0] - dn) * 60;
		if (dn > t[1])
			r -= (dn - t[1]) * 60;
		// (a way of building just used: another one rather)
		var mem = recentShapes.slice(Std.int(Math.max(0, recentShapes.length - GenRules.memory(lv.shape))));
		if (mem.indexOf(lv.shape) >= 0)
			r -= 3;
		// (harder and harder: few fruits killed by surfing, a share of them shut in)
		var hd = GenRules.hard(depth);
		r -= 4.0 * hd * Math.max(0, lv.surfShare - 0.25);
		r -= 4.5 * hd * Math.max(0, GenRules.shutShare(depth) * 0.85 - lv.shutShare);
		return r;
	}

	// (should hardly ever serve) rows of the start of the well
	static function fallback(depth:Int, lineup:Array<Int>):GenGrid {
		var lv:GenGrid = null;
		for (k in 0...50) {
			lv = GenShapes.build("etages", Std.int(Math.min(depth, 6)));
			if (!chooseStart(lv, depth))
				continue;
			var an = new GenAnalysis(lv, depth);
			if (an.exitCount == 0 || an.traps > 0)
				continue;
			placeBads(lv, an, lineup, depth);
			// (the fruits not killable go, then the ones that could get stuck)
			for (pass in 0...3) {
				var ck = GenDevices.check(lv, depth, true);
				if (ck.ok)
					break;
				for (b in ck.bad.concat(ck.stuck))
					lv.bads.remove(b);
			}
			lv.notes.push("secours");
			return lv;
		}
		return lv;
	}

	// ---------------------------------------------------------------- the level for the game

	// skins of the real levels (rank of difficulty x 100, background, tiles): a pair of the original for 5 levels
	// (not the empty background 14, black in the game, nor the tiles drawn in relief 30, 31, 32, 35 going with it)
	static var SKINS:Array<Array<Int>> = [
		[0, 18, 2928], [5, 24, 43], [6, 29, 5350], [8, 24, 4443], [11, 29, 5650], [14, 18, 29], [18, 24, 2745],
		[19, 13, 22], [23, 1, 7], [24, 1, 3], [26, 2, 46], [33, 17, 47], [34, 25, 19], [35, 12, 12], [36, 1, 1],
		[40, 10, 28], [41, 29, 4241], [42, 19, 22], [44, 21, 5657], [45, 1, 9], [45, 2, 6], [45, 7, 17], [54, 29, 2954],
		[55, 18, 5350], [56, 22, 18], [57, 16, 47], [57, 29, 54], [58, 16, 15], [59, 8, 23], [61, 28, 5250], [64, 18, 5349],
		[65, 21, 4445], [66, 9, 14], [68, 17, 9], [70, 11, 11], [70, 27, 51], [71, 22, 5145], [77, 23, 4844],
		[78, 8, 42], [80, 22, 5045], [81, 19, 2524], [83, 21, 910], [84, 18, 5963], [86, 26, 3736], [88, 25, 2952],
		[91, 27, 5250], [92, 24, 5341], [93, 12, 19], [95, 21, 6155], [96, 26, 28], [96, 26, 4245],
		[98, 24, 5362], [99, 24, 62]
	];
	static var zoneSkin:Array<Int> = null;
	static var zoneEnd:Int = -1;

	static function data(lv:GenGrid, depth:Int):LevelData {
		if (zoneSkin == null || depth >= zoneEnd) {
			var th = LevelTheme.of(depth);
			if (th.skins.length > 0) {
				var sk = th.skins[Cs.rnd(th.skins.length)];
				zoneSkin = [0, sk[0], sk[1]];
			} else {
				var t = Math.min(99, depth * 2.5);
				var c = [for (i in 0...SKINS.length) if (Math.abs(SKINS[i][0] - t) <= 12 && SKINS[i] != zoneSkin) i];
				if (c.length == 0)
					c = [for (i in 0...SKINS.length) if (SKINS[i][0] >= 80 && SKINS[i] != zoneSkin) i];
				zoneSkin = SKINS[c[Cs.rnd(c.length)]];
			}
			zoneEnd = depth - depth % 5 + 5;
		}
		var fm = lv.fieldMap();
		var map = [for (x in 0...W) [for (y in 0...H) lv.g[x * H + y] == 1 ? 1 : fm[x * H + y]]];
		var items = placeItems(lv, depth);
		return {
			map: map,
			bads: lv.bads,
			playerX: lv.sx,
			playerY: lv.sy,
			specialSlots: items.special,
			scoreSlots: items.scores,
			skinBg: zoneSkin[1],
			skinTiles: zoneSkin[2],
			darkness: GenRules.darkness(depth),
			openAtEnd: [],
			entry: entryColumns(lv, depth),
			levers: [],
			blocks: [],
			endBlocks: []
		};
	}

	// the places of the items on the platforms Igor reaches, apart from each other: the first special item where going
	// is worth it (in a room shut, far from the start), the others spread
	static function placeItems(lv:GenGrid, depth:Int):{special:Array<{x:Int, y:Int}>, scores:Array<{x:Int, y:Int}>} {
		var an = new GenAnalysis(lv, depth);
		var fm = lv.fieldMap();
		var busy = [for (i in 0...W * H) fm[i] != 0];
		for (b in lv.bads)
			busy[b.x * H + b.y] = true;
		var cells = [];
		for (s in lv.segments())
			for (x in s[0]...s[1] + 1) {
				var c = x * H + s[2];
				if (!busy[c] && an.reach[c] && Math.abs(x - lv.sx) + Math.abs(s[2] - lv.sy) > 4)
					cells.push(c);
			}
		var special = [];
		var scores = [];
		if (cells.length == 0)
			return {special: special, scores: scores};
		var bv = -1.0;
		var bi = 0;
		for (i in 0...cells.length) {
			var c = cells[i];
			var v = an.cellDist[c] >= 0 ? Math.min(12, an.cellDist[c]) * 0.3 : 0;
			if (lv.room != null && lv.room.indexOf(c) >= 0)
				v += 4;
			if (lv.vault != null && GenGrid.cx(c) >= lv.vault[0] && GenGrid.cx(c) <= lv.vault[2] && GenGrid.cy(c) == lv.vault[3] - 1)
				v += 5;
			v += rnd(100) / 60;
			if (v > bv) {
				bv = v;
				bi = i;
			}
		}
		var first = cells.splice(bi, 1)[0];
		special.push({x: GenGrid.cx(first), y: GenGrid.cy(first)});
		function far(c:Int, p:Int):Bool {
			return Math.abs(GenGrid.cx(c) - GenGrid.cx(p)) + Math.abs(GenGrid.cy(c) - GenGrid.cy(p)) > 4;
		}
		cells = [for (c in cells) if (far(c, first)) c];
		for (k in 0...4) {
			if (cells.length == 0)
				break;
			var p = cells.splice(rnd(cells.length), 1)[0];
			if (k == 0)
				special.push({x: GenGrid.cx(p), y: GenGrid.cy(p)});
			else
				scores.push({x: GenGrid.cx(p), y: GenGrid.cy(p)});
			cells = [for (c in cells) if (far(c, p)) c];
		}
		return {special: special, scores: scores};
	}

	// the columns where Igor coming in falling from the top lands with every fruit and the way out reachable, no laser
	// crossed on his way down
	static function entryColumns(lv:GenGrid, depth:Int):Array<Bool> {
		var out = [for (x in 0...W) false];
		var fm = lv.fieldMap();
		var tried = new Map<Int, Bool>();
		for (x in 0...W) {
			var y = 0;
			var crossed = false;
			while (y + 1 < H && !lv.ground(x, y + 1)) {
				if (fm[x * H + y] != 0)
					crossed = true;
				y++;
			}
			if (y + 1 >= H || lv.ground(x, y) || crossed || fm[x * H + y] != 0)
				continue;
			var c = x * H + y;
			if (!tried.exists(c)) {
				var t = lv.copy();
				t.sx = x;
				t.sy = y;
				tried.set(c, GenDevices.check(t, depth).ok);
			}
			out[x] = tried.get(c);
		}
		// at least the column of the start
		out[lv.sx] = true;
		return out;
	}
}
