package hammerfest;

import hammerfest.Levels.LevelData;

typedef GSeg = {y:Int, x0:Int, x1:Int}; // standing cells (the row over the ground) x0..x1
typedef GPt = {x:Int, y:Int};

// The levels of the well, made at random (the random of the game: a seed gives its well, the replay its levels), drawn
// like the levels of the original Hammerfest: rows of platforms 3 cases apart, regular patterns, rooms, pillars,
// funnels, towers, cups, cages..., and the shapes of the original: ramps of stairs, diagonals (Vs, a house, long
// ramps), rings, octagons and diamonds, floating rocks, mountains, combs; symmetric, almost symmetric (touched by
// hand) or not. Like in the original, the ground is gathered in a few shapes with open places around them, not a
// dust of small pieces all over the screen. Its hazards have a part in the level: lasers (kinds of bombs) in the
// holes of the floors and in the doors of the walls, spikes where they are a danger for Igor and not for the bads
// (under the ceilings, on the walls where he jumps), saws around the small blocks, teleporters between places far
// apart. The bads are placed for what they do (strawberries alone on ledges facing each other, pineapples on wide
// floors, pears up high, rows of the same bads on long floors for the combos...). Every level is checked with the
// moves of Igor (jump of 3 cases up, 4 across): every bad can be reached and killed, the bottom can be reached, Igor
// lands somewhere at the start. Several levels are made, the best one is kept.
class LevelGen {
	static inline var W = Data.LEVEL_WIDTH;
	static inline var H = Data.LEVEL_HEIGHT;
	static inline var HALF = 9;
	static inline var G = 1;

	// skins of the real levels (rank of difficulty x 100, background, tiles): a pair of the original at each level
	// (not the empty background 14, black in the game, nor the tiles drawn in relief 30, 31, 32, 35 that go with it)
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

	// bads in the order they come in the well (depth of their first level: a new one at each level up to 10, shown by
	// its level; the raspberries deep in the well)
	static var ROSTER:Array<Array<Int>> = [
		[Data.BAD_CERISE, 0], [Data.BAD_ORANGE, 0], [Data.BAD_POMME, 1], [Data.BAD_BANANE, 2], [Data.BAD_CITRON, 3],
		[Data.BAD_ABRICOT, 4], [Data.BAD_FRAISE, 5], [Data.BAD_POIRE, 6], [Data.BAD_KIWI, 7], [Data.BAD_BOMBE, 8],
		[Data.BAD_LITCHI, 9], [Data.BAD_ANANAS, 10], [Data.BAD_FRAMBOISE, 30]
	];

	// how hard a bad is to deal with: its part of the difficulty of a level
	static function threat(id:Int):Float {
		return switch (id) {
			case Data.BAD_CERISE: 1.0;
			case Data.BAD_ORANGE: 1.1;
			case Data.BAD_BANANE: 1.3;
			case Data.BAD_POMME: 1.5;
			case Data.BAD_CITRON: 1.6;
			case Data.BAD_ABRICOT: 1.9;
			case Data.BAD_FRAISE: 1.9;
			case Data.BAD_BOMBE: 2.0;
			case Data.BAD_POIRE: 2.1;
			case Data.BAD_KIWI: 2.2;
			case Data.BAD_LITCHI: 2.4;
			case Data.BAD_ANANAS: 3.0;
			case Data.BAD_FRAMBOISE: 3.4;
			default: 1.5;
		}
	}

	// the well goes in chapters of 5 levels (a zone of skins): calm at the start of a chapter, the hardest at its end
	// (factor of the bads and of the hazards; the first levels of the well rise without it)
	public static function rhythm(depth:Int):Float {
		return depth < 5 ? 1.0 : [0.82, 0.94, 1.0, 1.08, 1.18][depth % 5];
	}

	// the difficulty of the bads of a level (sum of their threats): a fast rise at first, then slower all along the well
	static function badBudget(depth:Int):Float {
		var b = depth < 10 ? 2.5 + 1.25 * depth : 15 + 0.42 * (depth - 10);
		return Math.min(34, b) * rhythm(depth);
	}

	// the raspberries, the worst of all: rare at first
	function rarity(id:Int):Float {
		return id == Data.BAD_FRAMBOISE ? (depth < 40 ? 0.12 : (depth < 50 ? 0.25 : 0.4)) : 1;
	}

	static function introDepth(id:Int):Int {
		for (r in ROSTER)
			if (r[0] == id)
				return r[1];
		return 0;
	}

	// the kind of bad met for the first time at this depth (-1: none)
	static function introKind(depth:Int):Int {
		if (depth > 0)
			for (r in ROSTER)
				if (r[1] == depth)
					return r[0];
		return -1;
	}

	public var m:Array<Array<Int>>;
	public var bads:Array<{id:Int, x:Int, y:Int}>;
	public var px:Int;
	public var py:Int;
	public var kind:String;
	public var sym:Bool;

	var depth:Int;
	var special:Array<GPt>;
	var scores:Array<GPt>;
	var danger:Array<Array<Bool>>; // spikes (and the place of the head of Igor under the spikes of a ceiling)
	var busy:Array<Array<Bool>>; // cases taken (bads, fields, items)
	var reach:Array<Array<Bool>>; // standing cells Igor can reach
	var exitOk:Bool;
	var teles:Array<{a:GPt, b:GPt}>;
	var floors:Array<Int>; // rows of the floors of the pattern
	var noBads:Array<GSeg>; // segments kept for the hazards (saws)
	var missing:Int;

	public function new(depth:Int) {
		this.depth = depth;
	}

	// ---------------------------------------------------------------- the level of a depth

	// (test harness)
	public static var fails:Map<String, Int> = new Map();

	public static var failMaps:Array<String> = [];
	public static var spikeStats:Map<String, Int> = new Map();
	public static var failWhy:String = "exit";

	function fail(why:String):Bool {
		var k = kind + ":" + why;
		#if gentest
		if (failMaps.length < 6 && why == failWhy) {
			var rows = [for (y in 0...H) [for (x in 0...W) m[x][y] > 0 ? "#" : (m[x][y] < 0 ? "f" : (reach != null && reach[x][y] ? "r" : "."))].join("")];
			if (py >= 0 && py < H)
				rows[py] = rows[py].substr(0, px) + "@" + rows[py].substr(px + 1);
			if (bads != null)
				for (b in bads)
					if (b.y >= 0 && b.y < H)
						rows[b.y] = rows[b.y].substr(0, b.x) + (b.id == Data.BAD_SPEAR ? "^" : (b.id == Data.BAD_SAW ? "X" : "B")) + rows[b.y].substr(b.x + 1);
			failMaps.push(k + " (missing " + missing + ")\n" + rows.join("\n"));
		}
		#end
		fails.set(k, (fails.exists(k) ? fails.get(k) : 0) + 1);
		return false;
	}

	public static var lastKind:String;
	public static var lastSym:Bool;
	public static var lastBudget:Float;

	static inline var SIMPLE = 14; // the kind of the simple levels of the beginning

	// kinds of the last levels (not the same kind twice in a row)
	static var prevT:Int = -1;
	static var prevT2:Int = -1;

	public static function reset() {
		prevT = -1;
		prevT2 = -1;
		zoneSkin = null;
		zoneEnd = -1;
		usedHard = [];
	}

	// the kinds of levels come one after the other in the well too (the easy ones first, the hardest ones deep)
	static function weights(depth:Int):Array<Int> {
		var easy = depth < 7;
		return [
			easy ? 6 : 3, // floors
			depth >= 4 ? 2 : 0, // rooms
			depth >= 1 && depth < 16 ? 2 : 0, // pillars
			depth >= 6 ? 2 : 0, // funnel
			depth >= 3 ? 2 : 0, // tower
			depth >= 2 ? 2 : 0, // cups
			depth >= 1 && depth < 16 ? 2 : 0, // stairs
			depth >= 2 && depth < 16 ? 2 : 0, // pyramid
			depth >= 9 ? 2 : 0, // cage
			depth >= 7 ? 2 : 0, // snake
			depth >= 3 ? 3 : 0, // frame
			depth >= 11 ? 2 : 0, // chambers
			depth >= 8 ? 2 : 0, // vee
			depth >= 12 ? 2 : 0, // tube
			depth == 0 ? 100 : (depth == 1 ? 60 : (depth == 2 ? 25 : (depth == 3 ? 8 : 0))), // simple: the first levels
			depth >= 10 ? (depth >= 16 ? 3 : 2) : 0, // shafts (hard)
			depth >= 12 ? (depth >= 18 ? 4 : 2) : 0, // blocks (hard)
			depth >= 14 ? (depth >= 20 ? 4 : 2) : 0, // maze (hard)
			depth >= 1 ? 4 : 0, // slopes: ramps of stairs
			depth >= 5 ? 4 : 0, // diag: V, house
			depth >= 8 ? 3 : 0, // ring
			depth >= 1 ? 4 : 0, // islands: floating rocks
			depth >= 4 ? 3 : 0, // mountain
			depth >= 20 ? (depth >= 30 ? 4 : 2) : 0, // caves (hard)
			depth >= 9 ? 3 : 0 // comb: bars and teeth
		];
	}

	// the names of the kinds (test harness: &kind=<name>, KIND=<name>)
	static var KINDS = ["floors", "rooms", "pillars", "funnel", "tower", "cups", "stairs", "pyramid", "cage", "snake", "frame",
		"chambers", "vee", "tube", "simple", "shafts", "blocks", "maze", "slopes", "diag", "ring", "islands", "mountain", "caves",
		"comb"];

	// test harness: every level of this kind
	public static var forceKind:String = null;

	// kinds of levels easy to move in (start of a chapter) and the hardest ones (its end)
	static var OPEN_KINDS = [0, 2, 6, 7, 18, 21, 22];
	static var HARD_KINDS = [8, 11, 13, 15, 16, 17, 23];

	// part of the levels remade from the hard levels of the original
	static function remixChance(depth:Int):Float {
		if (depth < 6)
			return 0;
		if (depth < 10)
			return 0.05;
		return 0.08;
	}

	// the kind of the level is drawn first, then several levels of that kind are made: the best one is kept
	public static function make(depth:Int):LevelData {
		// deep in the well: a hard level of the original remade (the best of a few)
		var st = depth % 5;
		// (not on the first level of a bad: it is shown there)
		var rc = introKind(depth) >= 0 ? 0 : remixChance(depth) * (st == 4 ? 2 : (st == 0 ? 0.3 : 1));
		if (forceSrc >= 0 || (Cs.rnd(1000) < rc * 1000 && forceKind == null)) {
			var target = 0.4 + 0.6 * Math.min(1, (depth - 6) / 30);
			var bestR:LevelGen = null;
			var bestRateR = -1.0e9;
			var ok = 0;
			for (i in 0...10) {
				var g = new LevelGen(depth);
				if (!g.buildRemix(target))
					continue;
				var r = g.rate();
				if (r > bestRateR) {
					bestR = g;
					bestRateR = r;
				}
				ok++;
				if (ok >= 3)
					break;
			}
			forceSrc = -1;
			if (bestR != null) {
				usedHard[bestR.srcId] = true;
				lastKind = bestR.kind + bestR.srcId;
				lastSym = bestR.sym;
				return bestR.data();
			}
		}
		var w = weights(depth);
		// (not the same kind twice in a row, but the simple levels of the beginning; only them at first)
		if (prevT >= 0 && prevT != SIMPLE)
			w[prevT] = 0;
		if (prevT2 >= 0 && prevT2 != SIMPLE)
			w[prevT2] = Std.int(w[prevT2] / 2);
		if (depth == 0)
			for (i in 0...w.length)
				if (i != SIMPLE)
					w[i] = 0;
		// (the chapter: open levels at its start and for the first level of a bad, the hardest kinds at its end)
		var open = st == 0 || introKind(depth) >= 0;
		if (depth >= 5)
			for (i in 0...w.length) {
				if (OPEN_KINDS.indexOf(i) >= 0)
					w[i] = open ? w[i] * 2 : (st == 4 ? Std.int(w[i] / 2) : w[i]);
				if (HARD_KINDS.indexOf(i) >= 0)
					w[i] = open ? Std.int(w[i] / 3) : (st == 4 ? w[i] * 2 : w[i]);
			}
		if (forceKind != null && KINDS.indexOf(forceKind) >= 0)
			w = [for (i in 0...KINDS.length) KINDS[i] == forceKind ? 1 : 0];
		var t = Cs.draw(w);
		var best:LevelGen = null;
		var bestRate = -1.0e9;
		for (pass in 0...2) {
			for (i in 0...10) {
				var g = new LevelGen(depth);
				if (!g.build(t))
					continue;
				var r = g.rate();
				if (r > bestRate) {
					best = g;
					bestRate = r;
				}
				if (i >= 6 && best != null)
					break;
			}
			if (best != null)
				break;
			t = 0;
		}
		if (best == null) {
			best = new LevelGen(depth);
			best.fallback();
		}
		prevT2 = prevT;
		prevT = t;
		lastKind = best.kind;
		lastSym = best.sym;
		lastBudget = best.budgetUsed;
		return best.data();
	}

	// skin of the levels: the same for 5 or 6 levels, a pair of the original of the difficulty of the depth
	static var zoneSkin:Array<Int> = null;
	static var zoneEnd:Int = -1;

	function data():LevelData {
		if (zoneSkin == null || depth >= zoneEnd) {
			var t = Math.min(99, depth * 2.5);
			var c = [for (i in 0...SKINS.length) if (Math.abs(SKINS[i][0] - t) <= 12 && SKINS[i] != zoneSkin) i];
			if (c.length == 0)
				c = [for (i in 0...SKINS.length) if (SKINS[i][0] >= 80 && SKINS[i] != zoneSkin) i];
			zoneSkin = SKINS[c[Cs.rnd(c.length)]];
			zoneEnd = depth - depth % 5 + 5;
		}
		var sk = zoneSkin;
		return {
			map: m,
			bads: bads,
			playerX: px,
			playerY: py,
			specialSlots: special,
			scoreSlots: scores,
			skinBg: sk[1],
			skinTiles: sk[2],
			// (the darkness: from level 3, then black all around the light of Igor at level 50)
			darkness: depth < 3 ? 0 : Std.int(Math.min(100, 10 + (depth - 3) * 90 / 47)),
			openAtEnd: openAtEnd,
			entry: entry
		};
	}

	// ---------------------------------------------------------------- random

	inline function rnd(n:Int):Int {
		return Cs.rnd(n);
	}

	inline function chance(p:Float):Bool {
		return Cs.rnd(1000) < p * 1000;
	}

	inline function range(a:Int, b:Int):Int {
		return a + Cs.rnd(b - a + 1);
	}

	function pick<T>(a:Array<T>):T {
		return a[Cs.rnd(a.length)];
	}

	function draw(w:Array<Int>):Int {
		return Cs.draw(w);
	}

	// ---------------------------------------------------------------- map

	inline function inb(x:Int, y:Int):Bool {
		return x >= 0 && x < W && y >= 0 && y < H;
	}

	// ground (the sides of the screen are walls, nothing above nor under)
	inline function gr(x:Int, y:Int):Bool {
		if (x < 0 || x >= W)
			return true;
		if (y < 0 || y >= H)
			return false;
		return m[x][y] > 0;
	}

	inline function setc(x:Int, y:Int, v:Int) {
		if (inb(x, y))
			m[x][y] = v;
	}

	// a case and its mirror when the level is symmetric
	function put(x:Int, y:Int, v:Int) {
		setc(x, y, v);
		if (sym)
			setc(W - 1 - x, y, v);
	}

	function hl(x0:Int, x1:Int, y:Int, v:Int) {
		for (x in x0...x1 + 1)
			put(x, y, v);
	}

	function vl(x:Int, y0:Int, y1:Int, v:Int) {
		for (y in y0...y1 + 1)
			put(x, y, v);
	}

	// a row from half a row (0: the side of the screen .. 8: the middle); the right half is the mirror or another one
	function applyRow(y:Int, left:Array<Bool>, ?right:Array<Bool>) {
		if (right == null)
			right = left;
		for (x in 0...HALF) {
			setc(x, y, left[x] ? G : 0);
			setc(W - 1 - x, y, right[x] ? G : 0);
		}
	}

	// ---------------------------------------------------------------- half rows

	function hFull():Array<Bool> {
		return [for (x in 0...HALF) true];
	}

	// a floor with holes of 2 cases
	function hHoles(n:Int):Array<Bool> {
		var a = hFull();
		var spots = [0, 2, 3, 4, 5, 6, 7];
		var done = 0;
		var tries = 0;
		while (done < n && tries < 20) {
			tries++;
			var x = pick(spots);
			if (x + 1 >= HALF)
				continue;
			if ((x > 0 && !a[x - 1]) || !a[x] || !a[x + 1] || (x + 2 < HALF && !a[x + 2]))
				continue;
			a[x] = false;
			a[x + 1] = false;
			done++;
		}
		return a;
	}

	// pieces of s cases every s + g
	function hPeriodic(s:Int, g:Int, o:Int):Array<Bool> {
		return [for (x in 0...HALF) ((x + o) % (s + g)) < s];
	}

	// a platform in the middle (2 h cases wide)
	function hCenter(h:Int):Array<Bool> {
		return [for (x in 0...HALF) x >= HALF - h];
	}

	// a shelf on the side
	function hSide(l:Int):Array<Bool> {
		return [for (x in 0...HALF) x < l];
	}

	function hSideCenter(l:Int, h:Int):Array<Bool> {
		if (l > HALF - h - 2)
			l = HALF - h - 2;
		return [for (x in 0...HALF) x < l || x >= HALF - h];
	}

	function hIslands(n:Int, w:Int):Array<Bool> {
		var a = [for (x in 0...HALF) false];
		var step = Std.int(HALF / n);
		var o = rnd(2);
		for (i in 0...n) {
			var x0 = o + i * step;
			for (k in 0...w)
				if (x0 + k < HALF)
					a[x0 + k] = true;
		}
		return a;
	}

	function hEmpty():Array<Bool> {
		return [for (x in 0...HALF) false];
	}

	function density(a:Array<Bool>):Float {
		var n = 0;
		for (v in a)
			if (v)
				n++;
		return n / a.length;
	}

	// a half row of a family drawn at random
	function hRandom(top:Bool):Array<Bool> {
		var f = top ? draw([0, 0, 4, 3, 2, 0]) : draw([3, 3, 2, 2, 2, 1]);
		return switch (f) {
			case 0: hHoles(range(1, 2));
			case 1: hPeriodic(range(2, 4), range(2, 3), rnd(4));
			case 2: hCenter(range(2, 6));
			case 3: hSide(range(3, 6));
			case 4: hSideCenter(range(2, 4), range(1, 4));
			default: hIslands(range(2, 3), 2);
		}
	}

	// rows of the floors from the top: 3 cases apart (sometimes 4)
	function floorRows(top:Int, ?last:Int = 16):Array<Int> {
		var out = [];
		var y = top;
		while (y <= last) {
			out.push(y);
			y += chance(0.15) ? 4 : 3;
		}
		return out;
	}

	// ---------------------------------------------------------------- templates

	function clear() {
		m = [for (x in 0...W) [for (y in 0...H) 0]];
		bads = [];
		special = [];
		scores = [];
		teles = [];
		noBads = [];
		missing = 0;
		openAtEnd = [];
		danger = [for (x in 0...W) [for (y in 0...H) false]];
		busy = [for (x in 0...W) [for (y in 0...H) false]];
	}

	function build(t:Int):Bool {
		clear();
		sym = chance(0.62);
		switch (t) {
			case 0:
				kind = "floors";
				tFloors();
			case 1:
				kind = "rooms";
				tRooms();
			case 2:
				kind = "pillars";
				tPillars();
			case 3:
				kind = "funnel";
				tFunnel();
			case 4:
				kind = "tower";
				tTower();
			case 5:
				kind = "cups";
				tCups();
			case 6:
				kind = "stairs";
				tStairs();
			case 7:
				kind = "pyramid";
				tPyramid();
			case 8:
				kind = "cage";
				tCage();
			case 9:
				kind = "snake";
				tSnake();
			case 10:
				kind = "frame";
				tFrame();
			case 11:
				kind = "chambers";
				tChambers();
			case 12:
				kind = "vee";
				tVee();
			case 13:
				kind = "tube";
				tTube();
			case 14:
				kind = "simple";
				tSimple();
			case 15:
				kind = "shafts";
				tShafts();
			case 16:
				kind = "blocks";
				tBlocks();
			case 17:
				kind = "maze";
				tMaze();
			case 18:
				kind = "slopes";
				tSlopes();
			case 19:
				kind = "diag";
				tDiag();
			case 20:
				kind = "ring";
				tRing();
			case 21:
				kind = "islands";
				tIslands();
			case 22:
				kind = "mountain";
				tMountain();
			case 23:
				kind = "caves";
				tCaves();
			default:
				kind = "comb";
				tComb();
		}
		// (half of the symmetric levels touched by hand)
		if (sym && chance(0.5))
			breakSymmetry();
		cleanup();
		// Igor comes in falling from the top where he left the level above: a ground under every column
		repairColumns();
		if (openColumns() > 0)
			return fail("open");
		if (!placeStart())
			return fail("start");
		computeReach();
		if (!exitOk)
			return fail("exit");
		addHazards();
		computeReach();
		if (!exitOk || !startOk())
			return fail("exit2");
		if (!placeBads())
			return fail("bads");
		// spikes (where the bads do not go)
		if (depth >= 2 && chance(Math.min(0.8, (0.25 + depth * 0.035) * rhythm(depth))))
			addSpikes(Std.int(Math.min(10, (2 + depth * 0.25) * rhythm(depth))));
		clearBadSpikes();
		if (!pocketsOk())
			return fail("pocket");
		if (!fieldsHeld())
			return fail("loose");
		placeItems();
		entry = entryColumns();
		if (entryCount() < 3)
			return fail("entry");
		return true;
	}

	// the first levels: a few wide platforms, like the first caves of the original (few bads, few platforms)
	function tSimple() {
		sym = chance(0.6);
		floors = [];
		var y = range(4, 5);
		var w0 = range(2, 4);
		applyRow(y, hCenter(w0));
		floors.push(y);
		var n = depth == 0 ? 2 : range(2, 3);
		var last = -1;
		for (i in 0...n) {
			y += pick([3, 4, 4]);
			if (y > 15)
				break;
			var style = rnd(3);
			if (style == last)
				style = (style + 1) % 3;
			last = style;
			var a = switch (style) {
				case 0:
					// a wide floor, holes on its sides
					var k = range(1, 3);
					[for (x in 0...HALF) x >= k];
				case 1:
					// shelves along the sides
					hSide(range(4, 6));
				default:
					// a wide platform in the middle
					hCenter(range(4, 7));
			}
			var b = sym ? null : (style == 1 ? hSide(range(3, 6)) : (style == 2 ? hCenter(range(3, 7)) : a));
			applyRow(y, a, b);
			floors.push(y);
		}
		// at the bottom, a floor with a hole in the middle sometimes (the way down)
		if (depth > 0 && chance(0.4) && y + 3 <= 17) {
			var a = [for (x in 0...HALF) x < HALF - range(1, 2)];
			applyRow(y + 3, a);
			floors.push(y + 3);
		}
	}

	// shafts between walls from the top to the bottom (the Hells): ledges on their sides every 3 rows, doors through
	// the walls with a laser or a teleporter (the teleporters of the two walls at the same rows go together)
	function tShafts() {
		sym = true;
		var wx = pick([4, 5, 5, 6]); // wall of the left half; shafts 0..wx-1, wx+1..W-2-wx and the mirror
		var t = range(2, 3);
		var b = range(14, 15);
		vl(wx, t, b, G);
		floors = [];
		// a roof over the side shafts (an opening in it), the middle open: Igor comes in there
		hl(0, wx, t, G);
		var ro = range(1, wx - 2);
		put(ro, t, 0);
		put(ro + 1, t, 0);
		var y = t + 3;
		var k = 0;
		while (y <= b) {
			var l = range(2, Std.int(Math.min(3, wx - 1)));
			// side shafts: a ledge on the side of the screen, then on the wall
			if (k % 2 == 0)
				hl(0, l - 1, y, G);
			else
				hl(wx - l, wx - 1, y, G);
			// middle shaft: ledges on its walls, or a piece in its middle
			if (k % 2 == 1)
				hl(wx + 1, wx + range(2, 3), y, G);
			else if (chance(0.6))
				hl(HALF - range(1, 2), HALF - 1, y, G);
			floors.push(y);
			y += 3;
			k++;
		}
		// the bottom: a floor under the shafts, a hole in each of them
		var by = Std.int(Math.min(17, b + 2));
		for (x in 0...HALF)
			put(x, by, G);
		var h1 = range(1, Std.int(Math.max(1, wx - 3)));
		put(h1, by, 0);
		put(h1 + 1, by, 0);
		put(HALF - 1, by, 0);
		floors.push(by);
		// doors through the walls, over a ledge against the wall
		var rows = [for (fy in floors) if (fy - 2 > t && fy <= b && (m[wx - 1][fy] > 0 || m[wx + 1][fy] > 0)) fy];
		var nd = Std.int(Math.min(rows.length, depth >= 8 ? 2 : 1));
		for (i in 0...nd) {
			var fy = rows.splice(rnd(rows.length), 1)[0];
			var v = (depth >= 3 && chance(0.5)) ? Data.FIELD_TELEPORT : fieldColor();
			put(wx, fy - 1, v);
			put(wx, fy - 2, v);
			mark(wx, fy - 1);
			mark(wx, fy - 2);
			mark(W - 1 - wx, fy - 1);
			mark(W - 1 - wx, fy - 2);
			if (v == Data.FIELD_TELEPORT)
				teles.push({a: {x: wx, y: fy - 1}, b: {x: W - 1 - wx, y: fy - 1}});
		}
	}

	// blocks scattered on a staggered grid (the Hells): 2 x 1, 2 x 2, 3 x 1, a floor with holes at the bottom; the saws
	// and the spikes come on them (addHazards)
	function tBlocks() {
		sym = chance(0.6);
		floors = [];
		var y = range(3, 4);
		var row = 0;
		var lim = sym ? HALF : W;
		while (y <= 14) {
			var x = (row % 2 == 0) ? rnd(2) : 2 + rnd(2);
			while (x < lim) {
				var bw = pick([2, 2, 3]);
				var bh = pick([1, 1, 2]);
				if (x + bw > lim)
					break;
				for (i in 0...bw)
					for (j in 0...bh)
						if (sym)
							put(x + i, y + j, G);
						else
							setc(x + i, y + j, G);
				x += bw + range(2, 4);
			}
			floors.push(y);
			y += pick([3, 4]);
			row++;
		}
		applyRow(17, hHoles(range(1, 2)), sym ? null : hHoles(range(1, 2)));
		floors.push(17);
	}

	// corridors (the Hells): floors across the level every 4 rows, an opening at one end then at the other, a wall
	// hanging in the corridor with a laser under it (a door), sometimes a hole in the middle
	function tMaze() {
		sym = false;
		floors = [];
		var y = range(3, 4);
		while (y <= 16) {
			floors.push(y);
			y += 4;
		}
		var left = chance(0.5);
		for (i in 0...floors.length) {
			var fy = floors[i];
			for (x in 0...W)
				setc(x, fy, G);
			var hw = range(2, 3);
			var ox = left ? range(0, 1) : W - hw - range(0, 1);
			for (k in 0...hw)
				setc(ox + k, fy, 0);
			if (i > 0 && chance(0.35)) {
				var hx = range(6, 10);
				setc(hx, fy, 0);
				setc(hx + 1, fy, 0);
			}
			// a door in the corridor over this floor: a wall hanging from the floor above, a laser under it
			if (i > 0 && chance(0.6)) {
				var dx = range(5, 12);
				var top = floors[i - 1];
				if (m[dx][fy] > 0 && m[dx][top] > 0) {
					for (yy in top + 1...fy - 2)
						setc(dx, yy, G);
					var c = fieldColor();
					setc(dx, fy - 2, c);
					setc(dx, fy - 1, c);
					mark(dx, fy - 2);
					mark(dx, fy - 1);
				}
			}
			left = !left;
		}
	}


	// floors of one style (the same pattern from a floor to the next, shifted): lattice, zigzag, holes, islands
	function tFloors() {
		floors = floorRows(range(3, 4));
		var style = draw([3, 4, 5, 2, 2]);
		var ps = range(2, 4);
		var pg = pick([2, 2, 3]);
		var po = rnd(ps + pg);
		var sideL = range(3, 5);
		var cenH = range(2, 4);
		var shift = rnd(7);
		for (i in 0...floors.length) {
			var y = floors[i];
			var a:Array<Bool> = switch (style) {
				case 0:
					// lattice: the same pieces, shifted by half a period every other floor
					hPeriodic(ps, pg, (po + (i % 2) * Std.int((ps + pg) / 2)) % (ps + pg));
				case 1:
					// zigzag: shelves on the sides, then a platform in the middle
					(i % 2 == 0) ? (chance(0.3) ? hSideCenter(sideL, 1) : hSide(sideL)) : hCenter(HALF - sideL + 1);
				case 2:
					// floors with holes, never over each other
					var h = hFull();
					var hx = (shift + 2 + i * 3) % 7;
					h[hx] = false;
					h[hx + 1] = false;
					if (chance(0.4)) {
						var hx2 = (hx + 4) % 7;
						h[hx2] = false;
						h[hx2 + 1] = false;
					}
					h;
				case 3:
					hIslands(range(2, 3), pick([2, 3]));
				default:
					hRandom(i == 0);
			}
			if (i == 0 && density(a) < 0.2)
				a = hCenter(cenH);
			applyRow(y, a, sym ? null : (style == 4 ? hRandom(i == 0) : a));
		}
		if (!sym && style != 4) {
			// (asymmetric: the right half another way on some floors)
			for (i in 0...floors.length)
				if (chance(0.5))
					applyRow(floors[i], rowHalf(floors[i]), hRandom(false));
		}
		if (chance(0.5))
			addPosts();
		if (chance(0.3))
			addLips();
		if (chance(0.2))
			addSideWalls();
	}

	function rowHalf(y:Int):Array<Bool> {
		return [for (x in 0...HALF) m[x][y] > 0];
	}

	// walls a little away from the sides of the screen, from a floor to another (A18)
	function addSideWalls() {
		var x = range(1, 2);
		var y0 = floors[0];
		var y1 = floors[Std.int(Math.min(floors.length - 1, range(1, 3)))];
		vl(x, y0, y1, G);
	}

	// a big room in the middle (walls, a roof with an opening, a floor with holes), platforms inside, shelves outside
	function tFrame() {
		sym = chance(0.8);
		var a = range(2, 3);
		var t = range(3, 4);
		var b = range(14, 16);
		floors = [t];
		vl(a, t, b, G);
		if (!sym)
			for (y in t...b + 1)
				setc(W - 1 - a, y, G);
		// roof with an opening in the middle
		var open = range(1, 2);
		for (x in a...HALF) {
			put(x, t, x >= HALF - open ? 0 : G);
			if (!sym)
				setc(W - 1 - x, t, x >= HALF - open ? 0 : G);
		}
		// floor: holes in the middle or along the walls
		var midHole = chance(0.5);
		for (x in a...HALF) {
			var hole = midHole ? x >= HALF - 1 : (x == a + 1 || x == a + 2);
			put(x, b, hole ? 0 : G);
			if (!sym)
				setc(W - 1 - x, b, hole ? 0 : G);
		}
		// inside: ledges on the walls and pieces in the middle, every 3 cases
		var y = t + 3;
		var style = rnd(3);
		var k = 0;
		while (y <= b - 2) {
			switch (style) {
				case 0:
					if (k % 2 == 0)
						hl(a + 1, a + range(2, 3), y, G);
					else
						hl(HALF - range(2, 3), HALF - 1, y, G);
				case 1:
					// pieces of 2 (A100)
					var o = (k % 2) * 2;
					for (x in a + 2...HALF)
						if (((x - a - 2 + o) % 4) < 2)
							put(x, y, G);
				default:
					hl(a + 1 + (k % 2) * 2, HALF - 1 - ((k + 1) % 2) * 2, y, G);
			}
			if (!sym)
				for (x in a + 1...HALF)
					setc(W - 1 - x, y, m[x][y]);
			floors.push(y);
			y += 3;
			k++;
		}
		floors.push(b);
		// a door in the walls: a way between inside and outside
		if (chance(0.6) && floors.length >= 3) {
			var dy = floors[Std.int(Math.min(floors.length - 2, range(1, 2)))];
			if (dy - 2 > t) {
				put(a, dy - 1, 0);
				put(a, dy - 2, 0);
			}
		}
		// outside: shelves along the screen
		if (a >= 2) {
			var oy = t + 2 + rnd(2);
			while (oy <= b) {
				hl(0, a - 2, oy, G);
				oy += 3 + rnd(2);
			}
		}
		if (b <= 15 && chance(0.5))
			applyRow(17, hHoles(1));
	}

	// rooms (boxes) on top of each other, openings in their roofs, doors, holes (D180)
	function tChambers() {
		sym = true;
		var bw = range(6, 7);
		var x0 = HALF - bw - range(0, 1);
		if (x0 < 0)
			x0 = 0;
		var x1 = x0 + bw - 1;
		var bh = pick([4, 5]);
		var t = range(3, 4);
		floors = [];
		var y = t;
		while (y + bh <= 16) {
			hl(x0, x1, y, G);
			hl(x0, x1, y + bh, G);
			vl(x0, y, y + bh, G);
			vl(x1, y, y + bh, G);
			// an opening in the roof, a door in a wall, a hole in the floor
			var ox = x0 + 1 + rnd(bw - 3);
			put(ox, y, 0);
			put(ox + 1, y, 0);
			if (chance(0.6)) {
				var dx = chance(0.5) ? x0 : x1;
				put(dx, y + bh - 1, 0);
				put(dx, y + bh - 2, 0);
			}
			if (chance(0.7)) {
				var hx = x0 + 1 + rnd(bw - 3);
				put(hx, y + bh, 0);
				put(hx + 1, y + bh, 0);
			}
			if (bh >= 5 && chance(0.6))
				hl(x0 + 2, x0 + 3, y + 2 + rnd(2), G);
			floors.push(y);
			floors.push(y + bh);
			y += bh + 2;
		}
		// between the boxes and outside: small shelves
		if (x1 < HALF - 2) {
			var sy = t + 2;
			while (sy <= 15) {
				hl(x1 + 2, HALF - 1, sy, G);
				sy += 4;
			}
		}
		if (x0 >= 2) {
			var sy = t + 3;
			while (sy <= 15) {
				hl(0, x0 - 2, sy, G);
				sy += 4;
			}
		}
		// teleporters between the two boxes of a row (same height: they go together)
		if (depth >= 4 && chance(0.6) && floors.length >= 2) {
			var roof = floors[floors.length - 2];
			var floor = floors[floors.length - 1];
			var tx = x0 + 1;
			if (m[tx][roof] > 0 && m[tx][floor] > 0) {
				var ok = true;
				for (y in roof + 1...floor)
					if (m[tx][y] != 0)
						ok = false;
				if (ok) {
					for (x in [tx, W - 1 - tx])
						for (y in roof + 1...floor) {
							setc(x, y, Data.FIELD_TELEPORT);
							mark(x, y);
						}
					teles.push({a: {x: tx, y: floor - 1}, b: {x: W - 1 - tx, y: floor - 1}});
				}
			}
		}
	}

	// a V of solid rock narrowing down to an opening in the middle, ledges and spikes on its sides (D190)
	function tVee() {
		sym = true;
		var t = range(3, 5);
		var slope = pick([2, 3]);
		floors = [];
		var w = range(0, 1);
		for (y in t...H) {
			if ((y - t) % slope == 0 && y > t)
				w++;
			if (w > HALF - 2)
				w = HALF - 2;
			for (x in 0...w)
				put(x, y, G);
		}
		// ledges on the sides of the V, every 3 rows
		var y = t + 2;
		while (y < H - 2) {
			var wx = 0;
			while (wx < HALF && m[wx][y] > 0)
				wx++;
			if (wx < HALF - 3)
				hl(wx, wx + range(1, 2), y, G);
			floors.push(y);
			y += 3;
		}
		hl(HALF - range(2, 3), HALF - 1, t + range(4, 6), G);
		wallSpikes = true;
	}

	var wallSpikes:Bool = false;

	// a shaft in the middle between two walls, ledges inside, platforms outside (D80)
	function tTube() {
		sym = true;
		var a = range(4, 5);
		var t = range(3, 5);
		var b = range(13, 16);
		vl(a, t, b, G);
		floors = [];
		var y = t + 2;
		var k = 0;
		while (y <= b) {
			if (k % 2 == 0)
				hl(a + 1, a + 2, y, G);
			else
				hl(HALF - 2, HALF - 1, y, G);
			floors.push(y);
			y += 3;
			k++;
		}
		var oy = t + 1;
		while (oy <= 16) {
			if (chance(0.7))
				hl(Std.int(Math.max(0, a - range(2, 3))), a - 1, oy, G);
			else
				hl(0, range(1, 2), oy, G);
			oy += 3;
		}
		if (chance(0.5))
			applyRow(Std.int(Math.min(17, b + 2)), hHoles(1));
	}

	// walls between two floors at the ends of their platforms: rooms
	function addPosts() {
		for (i in 0...floors.length - 1) {
			if (!chance(0.5))
				continue;
			var y0 = floors[i];
			var y1 = floors[i + 1];
			var cols = [for (x in 1...HALF - 1) if (gr(x, y0) && gr(x, y1) && (!gr(x - 1, y0) || !gr(x + 1, y0))) x];
			if (cols.length == 0)
				continue;
			var x = pick(cols);
			vl(x, y0 + 1, y1 - 1, G);
		}
	}

	// raised edges at the ends of platforms (cups)
	function addLips() {
		for (y in floors) {
			if (y < 4 || !chance(0.5))
				continue;
			for (x in 1...W - 1)
				if (gr(x, y) && !gr(x + 1, y) && !gr(x, y - 1) && !gr(x, y - 2) && chance(0.4))
					put(x, y - 1, G);
		}
	}

	// rooms between two walls, floors with doors alternately in the middle and on the sides (the way down zigzags)
	function tRooms() {
		sym = true;
		var a = range(1, 3);
		floors = floorRows(range(3, 4));
		var top = floors[0];
		var bottom = floors[floors.length - 1];
		vl(a, top, bottom, G);
		var mid = chance(0.5);
		for (i in 0...floors.length) {
			var y = floors[i];
			// inside
			for (x in a...HALF)
				put(x, y, G);
			var door = ((i % 2 == 0) == mid);
			if (i == 0 || door) {
				// door in the middle
				put(HALF - 1, y, 0);
				if (chance(0.5))
					put(HALF - 2, y, 0);
			} else {
				// doors along the walls
				put(a + 1, y, 0);
				put(a + 2, y, 0);
			}
			// outside: a shelf every other floor
			if (a >= 2 && i % 2 == 1)
				hl(0, a - 1, y, G);
			if (i > 0 && i < floors.length - 1 && chance(0.3)) {
				// a door in the wall (way between inside and outside)
				put(a, y - 1, 0);
				put(a, y - 2, 0);
			}
		}
		if (a == 1 && chance(0.6)) {
			// the outside column: a pit with ledges
			for (i in 0...floors.length)
				if (i % 2 == 0)
					put(0, floors[i], G);
		}
		if (chance(0.4)) {
			// pillars in the rooms
			for (i in 1...floors.length) {
				if (!chance(0.5))
					continue;
				var x = range(a + 3, HALF - 2);
				put(x, floors[i] - 1, G);
			}
		}
	}

	// pillars of 2 cases on a grid (bricks), the tops are the platforms
	function tPillars() {
		var period = pick([4, 4, 5]);
		var ph = pick([2, 2, 3]);
		var y = range(3, 4);
		floors = [];
		var row = 0;
		while (y + ph - 1 <= 15) {
			floors.push(y);
			var o = (row % 2 == 0) ? 0 : Std.int(period / 2);
			if (!sym && chance(0.5))
				o = rnd(period);
			for (x in 0...W) {
				var xx = sym ? (x < HALF ? x : W - 1 - x) : x;
				if (((xx + o) % period) < 2)
					for (k in 0...ph)
						setc(x, y + k, G);
			}
			y += ph + pick([2, 3]);
			row++;
		}
		// a floor at the bottom with holes
		if (chance(0.6) && y <= 17) {
			applyRow(Std.int(Math.min(17, y)), hHoles(range(1, 2)));
			floors.push(Std.int(Math.min(17, y)));
		}
	}

	// stairs from both sides down to the middle (V), a platform under the opening, a chamber at the bottom
	function tFunnel() {
		sym = true;
		floors = [];
		var y = range(3, 4);
		var sl = pick([2, 2, 3]);
		var dy = pick([1, 2]);
		var x = 0;
		var ys = [];
		while (x + sl <= HALF - 1 && y <= 13) {
			hl(x, x + sl - 1, y, G);
			ys.push(y);
			x += sl;
			y += dy;
		}
		floors = ys;
		var under = y + 2;
		if (under <= 14) {
			hl(HALF - range(2, 3), HALF - 1, under, G);
			floors.push(under);
		}
		// chamber at the bottom
		var by = Std.int(Math.min(17, Math.max(under + 3, 15)));
		applyRow(by, chance(0.5) ? hSideCenter(range(2, 3), range(1, 2)) : hHoles(1));
		floors.push(by);
		if (chance(0.5))
			vl(0, by - 2, by - 1, G);
	}

	// a column in the middle, branches on its sides, shelves along the sides of the screen
	function tTower() {
		var t0 = range(4, 5);
		var t1 = range(11, 14);
		var cw = 1; // half width of the column: 2 cases
		for (y in t0...t1 + 1)
			for (k in 0...cw)
				put(HALF - 1 - k, y, G);
		floors = [t0];
		var y = t0 + 3;
		var left = chance(0.5);
		while (y <= t1) {
			var l = range(2, 4);
			var x1 = HALF - 1 - cw;
			if (sym) {
				hl(x1 - l + 1, x1, y, G);
			} else {
				var xa = left ? x1 - l + 1 : W - 1 - x1;
				var xb = left ? x1 : W - 1 - x1 + l - 1;
				for (x in xa...xb + 1)
					setc(x, y, G);
				left = !left;
			}
			floors.push(y);
			y += 3;
		}
		// shelves on the sides between the branches
		var sy = t0 + 2 + rnd(2);
		while (sy <= 15) {
			var l = range(2, 3);
			if (sym)
				hl(0, l - 1, sy, G);
			else {
				for (x in 0...l)
					setc(x, sy, G);
				if (chance(0.7))
					for (x in 0...l)
						setc(W - 1 - x, sy + 1 <= 16 ? sy + 1 : sy, G);
			}
			sy += 3;
		}
		// bottom
		var by = Std.int(Math.min(17, t1 + 2));
		if (chance(0.7)) {
			applyRow(by, hHoles(1));
			floors.push(by);
		}
	}

	// cups (a floor and a wall at each end, a hole in the middle of the floor: D119, A20) in staggered rows: the same
	// cup all over the level, a row shifted by half a cup from the next one, a platform where Igor comes in, a floor
	// with holes at the bottom
	function tCups() {
		floors = [];
		var cw = range(6, 7); // width of a cup
		var gap = range(2, 3); // between two cups
		var hh = chance(0.85) ? 1 : 2; // height of its walls
		var hole = cw - 4 >= 2 ? 2 : 1; // a hole in the middle of its floor: the frozen bads are kicked out there
		var per = cw + gap;
		var top = range(3, 4);
		applyRow(top, hCenter(range(3, 5)));
		floors.push(top);
		var y = top + 2 + hh;
		var row = 0;
		while (y <= 15) {
			// (a row of cups across the level, the whole of it symmetric: from the middle out)
			var o = row % 2 == 0 ? 0 : Std.int(per / 2) + 1;
			var cups:Array<Int> = [];
			var x = -o;
			while (x < W) {
				cups.push(x);
				x += per;
			}
			// (centred: the same space left on both sides)
			var used = cups[cups.length - 1] + cw - 1 - cups[0];
			var shift = Std.int((W - 1 - used) / 2) - cups[0];
			for (c in cups) {
				var x0 = c + shift;
				var x1 = x0 + cw - 1;
				if (x1 < 1 || x0 > W - 2)
					continue;
				var h0 = x0 + Std.int((cw - hole) / 2);
				for (xx in x0...x1 + 1)
					if (xx < h0 || xx >= h0 + hole)
						setc(xx, y, G);
				for (k in 1...hh + 1) {
					if (x0 >= 0)
						setc(x0, y - k, G);
					if (x1 < W)
						setc(x1, y - k, G);
				}
			}
			floors.push(y);
			y += 3 + hh;
			row++;
		}
		if (y - 3 - hh <= 13) {
			applyRow(17, hHoles(range(1, 2)));
			floors.push(17);
		}
		sym = true;
		for (x in 0...HALF)
			for (yy in 0...H)
				if (m[x][yy] != m[W - 1 - x][yy])
					sym = false;
	}

	// stairs: steps going down from one side to the other and back
	function tStairs() {
		floors = [];
		var sw = pick([3, 3, 4]);
		var dy = pick([2, 2, 3]);
		var y = range(3, 4);
		if (sym) {
			// stairs from the middle down to both sides (Λ), then back (V)
			var x = HALF - sw;
			var dir = -1;
			while (y <= 16) {
				hl(Std.int(Math.max(0, x)), Std.int(Math.min(HALF - 1, x + sw - 1)), y, G);
				floors.push(y);
				x += dir * (sw - 1);
				if (x <= 0 || x + sw - 1 >= HALF - 1) {
					dir = -dir;
					x = Std.int(Math.max(0, Math.min(HALF - sw, x)));
				}
				y += dy;
			}
		} else {
			var x = chance(0.5) ? 0 : W - sw;
			var dir = x == 0 ? 1 : -1;
			while (y <= 16) {
				for (k in 0...sw)
					setc(x + k, y, G);
				floors.push(y);
				x += dir * (sw + rnd(2));
				if (x < 0 || x + sw > W) {
					// the turn: a landing a little lower
					dir = -dir;
					x = x < 0 ? 0 : W - sw;
					y += 1;
				}
				y += dy - 1;
			}
		}
	}

	// platforms in the middle, wider and wider going down (or narrower), shelves on the sides
	function tPyramid() {
		floors = floorRows(range(3, 5));
		var inv = chance(0.3);
		var n = floors.length;
		for (i in 0...n) {
			var k = inv ? n - 1 - i : i;
			var h = Std.int(Math.min(HALF, 1 + k * pick([1, 2])));
			var a = hCenter(h);
			if (h >= HALF - 1)
				a = hHoles(1);
			if (i % 2 == 1 && h <= HALF - 4)
				a[0] = a[1] = true;
			applyRow(floors[i], a, sym ? null : (chance(0.5) ? a : hRandom(false)));
		}
	}

	// a closed cage in the middle (bads inside), teleporters at the same height inside and outside
	function tCage() {
		sym = true;
		var c0 = range(3, 4);
		var rt = range(6, 8);
		var rb = rt + pick([4, 5]);
		hl(c0, HALF - 1, rt, G);
		hl(c0, HALF - 1, rb, G);
		vl(c0, rt, rb, G);
		floors = [rt, rb];
		// outside: shelves at the height of the floor of the cage, floors above and under
		hl(0, c0 - 2, rb, G);
		var top = rt - 3;
		if (top >= 3) {
			applyRow(top, hSideCenter(range(2, 3), range(1, 2)));
			floors.unshift(top);
		}
		var by = Std.int(Math.min(17, rb + 3));
		applyRow(by, hHoles(range(1, 2)));
		floors.push(by);
		// teleporters from the floor to the roof: inside against the wall of the cage, outside on the shelf under a
		// ground (the same rows: they go together)
		var ty = rb - 1;
		for (x in [c0 + 1, 0, W - 2 - c0, W - 1]) {
			for (y in rt + 1...rb) {
				setc(x, y, Data.FIELD_TELEPORT);
				mark(x, y);
			}
			if (m[x][rt] <= 0)
				setc(x, rt, G);
		}
		teles.push({a: {x: 0, y: ty}, b: {x: c0 + 1, y: ty}});
		teles.push({a: {x: W - 1, y: ty}, b: {x: W - 2 - c0, y: ty}});
	}

	// floors across the screen with a hole at one end, then at the other (the way down snakes)
	function tSnake() {
		sym = false;
		floors = floorRows(range(3, 4));
		var left = chance(0.5);
		for (i in 0...floors.length) {
			var y = floors[i];
			var hw = range(2, 3);
			for (x in 0...W)
				setc(x, y, G);
			if (left)
				for (x in 0...hw)
					setc(x, y, 0);
			else
				for (x in 0...hw)
					setc(W - 1 - x, y, 0);
			// a block or a gap on the way
			if (i > 0 && chance(0.5)) {
				var x = range(5, W - 6);
				if (chance(0.5))
					setc(x, y - 1, G);
				else {
					setc(x, y, 0);
					setc(x + 1, y, 0);
				}
			}
			left = !left;
		}
	}

	// ---------------------------------------------------------------- shapes of the original: stairs, diagonals, rings,
	// rocks, mountains

	// a line from (x0, y0) to (x1, y1): straight, or in steps (at 45 degrees steps of one case, the diagonals of the
	// original; flatter, longer steps)
	function line(x0:Int, y0:Int, x1:Int, y1:Int, ?v:Int = 1) {
		var dx = Std.int(Math.abs(x1 - x0));
		var dy = -Std.int(Math.abs(y1 - y0));
		var sx = x0 < x1 ? 1 : -1;
		var sy = y0 < y1 ? 1 : -1;
		var err = dx + dy;
		var x = x0;
		var y = y0;
		for (i in 0...64) {
			put(x, y, v);
			if (x == x1 && y == y1)
				break;
			var e2 = 2 * err;
			if (e2 >= dy) {
				err += dy;
				x += sx;
			}
			if (e2 <= dx) {
				err += dx;
				y += sy;
			}
		}
	}

	// stairs going down from (x, y) towards dir: n steps of w cases, each one a case lower (the column after the last)
	function stairs(x:Int, y:Int, dir:Int, n:Int, w:Int):Int {
		for (i in 0...n)
			for (k in 0...w)
				put(x + dir * (i * w + k), y + i, G);
		return x + dir * n * w;
	}

	// a ramp from (x, y) towards dir (A13, A22): a flat of a cases, n steps of sw cases going down, a flat of b cases
	function ramp(x:Int, y:Int, dir:Int, a:Int, n:Int, sw:Int, b:Int) {
		for (k in 0...a)
			put(x + dir * k, y, G);
		var e = stairs(x + dir * a, y + 1, dir, n, sw);
		for (k in 0...b)
			put(e + dir * k, y + n + 1, G);
	}

	// the outline of an ellipse, one case thick (a case a column where it is flat, a case a row where it is steep), its
	// center at (cx2 / 2, cy2 / 2): on a case or between two, the same on both sides
	function ellipse(cx2:Int, cy2:Int, rx:Float, ry:Float):Array<GPt> {
		var out:Array<GPt> = [];
		var cx = cx2 / 2;
		var cy = cy2 / 2;
		function add(x:Int, y:Int) {
			for (p in [{x: x, y: y}, {x: cx2 - x, y: y}, {x: x, y: cy2 - y}, {x: cx2 - x, y: cy2 - y}]) {
				var dup = false;
				for (o in out)
					if (o.x == p.x && o.y == p.y)
						dup = true;
				if (!dup)
					out.push(p);
			}
		}
		// (the flat parts: a case in each column of the left half; the steep ones: a case in each row of the upper half)
		var x = Math.ceil(cx - rx);
		while (x <= cx) {
			var u = (x - cx) / rx;
			var h = ry * Math.sqrt(Math.max(0, 1 - u * u));
			if (ry * ry * (cx - x) <= rx * rx * h)
				add(x, Math.round(cy - h));
			x++;
		}
		var y = Math.ceil(cy - ry);
		while (y <= cy) {
			var u = (y - cy) / ry;
			var w = rx * Math.sqrt(Math.max(0, 1 - u * u));
			if (rx * rx * (cy - y) <= ry * ry * w)
				add(Math.round(cx - w), y);
			y++;
		}
		return out;
	}

	// an octagon: the frame from (x0, y0) to (x1, y1), its corners cut by diagonals of c cases
	function octagon(x0:Int, y0:Int, x1:Int, y1:Int, c:Int):Array<GPt> {
		var out:Array<GPt> = [];
		for (x in x0 + c...x1 - c + 1) {
			out.push({x: x, y: y0});
			out.push({x: x, y: y1});
		}
		for (y in y0 + c...y1 - c + 1) {
			out.push({x: x0, y: y});
			out.push({x: x1, y: y});
		}
		for (k in 1...c) {
			out.push({x: x0 + c - k, y: y0 + k});
			out.push({x: x1 - c + k, y: y0 + k});
			out.push({x: x0 + c - k, y: y1 - k});
			out.push({x: x1 - c + k, y: y1 - k});
		}
		return out;
	}

	function plot(pts:Array<GPt>, ?v:Int = 1) {
		for (p in pts)
			setc(p.x, p.y, v);
	}

	// first row of ground of the column x from y (H: none)
	function groundFrom(x:Int, y:Int):Int {
		while (y < H && (x < 0 || x >= W || m[x][y] <= 0))
			y++;
		return y;
	}

	// shelves that go with the shapes of the level: on the rows of its other platforms, against the side of the screen
	// or an end lined up with a platform above or under; free all around (two rows over and under, a case on the
	// sides). The big empty places stay open (the levels of the original leave about a tenth of the screen open)
	function addShelves(n:Int, ?y0:Int = 3, ?y1:Int = 16, ?lmin:Int = 3, ?lmax:Int = 4) {
		for (i in 0...n) {
			// (rows of the platforms, ends of the platforms)
			var rowUsed = [for (y in 0...H) false];
			var endAt = [for (x in 0...W + 1) [for (y in 0...H) false]];
			for (y in 1...H) {
				var x = 0;
				while (x < W) {
					if (m[x][y] > 0 && m[x][y - 1] <= 0) {
						var x0 = x;
						while (x < W && m[x][y] > 0 && m[x][y - 1] <= 0)
							x++;
						rowUsed[y] = true;
						endAt[x0][y] = true;
						endAt[x][y] = true;
					} else
						x++;
				}
			}
			var lim = sym ? HALF : W;
			var best:GPt = null;
			var bestL = 0;
			var bestV = -1.0;
			for (y in y0...y1 + 1)
				for (x in 0...lim)
					for (l in lmin...lmax + 1) {
						if (x + l > lim)
							continue;
						var ok = true;
						for (xx in x - 1...x + l + 1)
							for (yy in y - 2...y + 3)
								if (inb(xx, yy) && m[xx][yy] != 0)
									ok = false;
						if (!ok)
							continue;
						var v = l * 0.2 + rnd(100) / 150;
						if (rowUsed[y])
							v += 1;
						if (x == 0 || (!sym && x + l == W))
							v += 1;
						for (e in [x, x + l])
							for (yy in y - 6...y + 7)
								if (yy != y && yy >= 0 && yy < H && endAt[e][yy]) {
									v += 0.6;
									break;
								}
						if (v > bestV) {
							bestV = v;
							best = {x: x, y: y};
							bestL = l;
						}
					}
			if (best == null)
				break;
			hl(best.x, best.x + bestL - 1, best.y, G);
			floors.push(best.y);
		}
	}

	// a symmetric level touched by hand (the levels of the original are often almost symmetric): here and there a
	// platform longer or shorter, a small piece less (no small piece more: the dust of the levels)
	function breakSymmetry() {
		var n = range(1, 3);
		var done = 0;
		for (tries in 0...30) {
			if (done >= n)
				break;
			// (the thin platforms)
			var runs:Array<GSeg> = [];
			for (y in 2...H) {
				var x = 0;
				while (x < W) {
					if (m[x][y] > 0 && m[x][y - 1] <= 0 && (y + 1 >= H || m[x][y + 1] <= 0)) {
						var x0 = x;
						while (x < W && m[x][y] > 0 && m[x][y - 1] <= 0 && (y + 1 >= H || m[x][y + 1] <= 0))
							x++;
						runs.push({y: y, x0: x0, x1: x - 1});
					} else
						x++;
				}
			}
			if (runs.length == 0)
				break;
			var r = runs[rnd(runs.length)];
			var len = r.x1 - r.x0 + 1;
			switch (rnd(3)) {
				case 0:
					// longer: one or two cases at an end, in the free
					var dir = chance(0.5) ? -1 : 1;
					var k = range(1, 2);
					var ok = true;
					for (i in 1...k + 2) {
						var x = dir < 0 ? r.x0 - i : r.x1 + i;
						if (i <= k && !inb(x, r.y))
							ok = false;
						for (yy in r.y - 2...r.y + 3)
							if (inb(x, yy) && m[x][yy] != 0)
								ok = false;
					}
					if (ok) {
						for (i in 1...k + 1)
							setc(dir < 0 ? r.x0 - i : r.x1 + i, r.y, G);
						done++;
					}
				case 1:
					// shorter: a case gone at an end
					if (len >= 4) {
						setc(chance(0.5) ? r.x0 : r.x1, r.y, 0);
						done++;
					}
				default:
					// a small piece gone (nothing touching it)
					var alone = len <= 3;
					for (x in r.x0 - 1...r.x1 + 2)
						for (yy in r.y - 1...r.y + 2)
							if (inb(x, yy) && m[x][yy] != 0 && !(yy == r.y && x >= r.x0 && x <= r.x1))
								alone = false;
					if (alone) {
						for (x in r.x0...r.x1 + 1)
							setc(x, r.y, 0);
						done++;
					}
			}
		}
		sym = false;
	}

	// platforms joined by stairs (the ramps of A13, A22): a flat, steps going down, a flat; the same ramp again further
	// (A22), the mirror, or ramps here and there; a row of ramps every 4 or 5 rows
	function tSlopes() {
		floors = [];
		var mode = draw([4, 4, 1]); // 0: two of them across, 1: mirror, 2: one a row
		sym = mode == 1;
		var y = range(3, 4);
		var dir = chance(0.5) ? 1 : -1;
		var sw = pick([1, 2, 2]);
		while (y <= 14) {
			var a = range(3, 5);
			var n = range(1, 2);
			var b = range(3, 5);
			if (y + n + 1 > 16)
				n = 1;
			var copies = mode == 0 ? 2 : 1;
			var room = mode == 1 ? HALF : Std.int(W / copies);
			while (a + n * sw + b > room - 1 && (a > 2 || b > 2)) {
				if (b >= a)
					b--;
				else
					a--;
			}
			var len = a + n * sw + b;
			if (len > room)
				n = 1;
			len = a + n * sw + b;
			var x0 = rnd(Std.int(Math.max(1, room - len + 1)));
			for (c in 0...copies) {
				var x = x0 + c * room;
				ramp(dir > 0 ? x : x + len - 1, y, dir, a, n, sw, b);
			}
			floors.push(y);
			floors.push(y + n + 1);
			y += n + 1 + range(3, 4);
			if (mode != 0 || chance(0.4))
				dir = -dir;
		}
		if (y <= 17 && chance(0.75)) {
			var by = Std.int(Math.min(17, y));
			applyRow(by, hHoles(range(1, 2)), sym ? null : hHoles(range(1, 2)));
			floors.push(by);
		}
		addShelves(range(0, 1));
	}

	// diagonals (ayame 1, A54, A49, A26): a V from the sides of the screen down to an opening in the middle, two Vs
	// one in the other, a house (a roof from the middle down to the sides), or long ramps across the level
	function tDiag() {
		floors = [];
		sym = true;
		var sw = pick([1, 1, 2]);
		var style = draw([4, 3, 3]);
		if (style == 0) {
			// a V (a funnel) from the sides of the screen: its arms down to the middle (an opening of 2) or shorter
			// (ayame 1); two Vs one in the other (A54); floors under it
			var nested = chance(0.3);
			var t = range(3, 4);
			var full = Std.int((HALF - 1) / sw);
			var steps = nested || chance(0.4) ? full : range(Std.int(full / 2) + 1, full - 1);
			var arms = nested ? [t, t + 4] : [t];
			var vb = 0;
			var vb0 = 0;
			for (a in arms) {
				for (i in 0...steps)
					for (k in 0...sw)
						put(i * sw + k, a + i, G);
				vb = a + steps - 1;
				if (a == t)
					vb0 = vb;
				floors.push(a);
			}
			floors.push(vb);
			var open = HALF - steps * sw; // half the opening
			// in the (first) V: a platform over the opening, 2 cases at least from the arms (the way down along them)
			var rows = [for (r in t + 2...vb0 - 1) if (HALF - (r - t + 1) * sw - 2 >= 2) r];
			if (rows.length > 0 && (open <= 2 || chance(0.5))) {
				var r = rows[rnd(Std.int(Math.min(2, rows.length)))];
				var pw = Std.int(Math.min(range(2, 3), HALF - (r - t + 1) * sw - 2));
				hl(HALF - pw, HALF - 1, r, G);
				floors.push(r);
			}
			// under it: floors every 3 rows (a platform under the opening, shelves, a floor with holes)
			var fy = vb + 3;
			var k = 0;
			while (fy <= 17) {
				var a = switch ((k + rnd(2)) % 3) {
					case 0: hCenter(Std.int(Math.max(2, Math.min(6, open + range(0, 2)))));
					case 1: hSideCenter(range(2, 4), range(1, 2));
					default: hHoles(range(1, 2));
				}
				if (fy == 17 || fy + 3 > 17)
					a = hHoles(range(1, 2));
				// (not over a lower arm, nor just under one)
				for (x in 0...HALF)
					if (a[x] && (m[x][fy] != 0 || m[x][fy - 1] != 0 || m[x][fy - 2] != 0 || (fy + 1 < H && m[x][fy + 1] != 0)))
						a[x] = false;
				applyRow(fy, a);
				floors.push(fy);
				fy += 3;
				k++;
			}
			// under the arms (nested Vs): shelves along the sides of the screen
			if (nested) {
				var sy = t + 6;
				while (sy < vb) {
					var l = 0;
					while (l < HALF && m[l][sy] == 0 && m[l][sy - 1] == 0 && m[l][sy - 2] == 0 && m[l][sy + 1] == 0)
						l++;
					l = Std.int(Math.min(l - 1, range(2, 3)));
					if (l >= 2) {
						hl(0, l - 1, sy, G);
						floors.push(sy);
					}
					sy += 3;
				}
			}
		} else if (style == 1) {
			// a house: a roof from the middle at the top down to 2 cases from the sides of the screen, a window in each
			// side of it, its floor under its ends with a hole in the middle, a platform in it; the ways down along the
			// sides of the screen
			var t = range(3, 4);
			var x = HALF - 1;
			var y = t;
			var cells:Array<GPt> = [];
			while (x >= 2) {
				for (k in 0...sw)
					if (x - k >= 2) {
						put(x - k, y, G);
						cells.push({x: x - k, y: y});
					}
				x -= sw;
				y++;
			}
			var rb = y - 1;
			floors.push(t);
			// the windows: two cases of the roof gone
			var wi = Std.int(cells.length / 3) + rnd(Std.int(Math.max(1, cells.length / 3)));
			for (i in wi...Std.int(Math.min(cells.length, wi + 2)))
				put(cells[i].x, cells[i].y, 0);
			// the floor of the house
			var hb = rb + 1;
			hl(2, HALF - 2, hb, G);
			floors.push(hb);
			// in it: a platform
			if (hb - 3 > t + 1) {
				var xr = HALF - (hb - 3 - t) * sw;
				if (HALF - 1 - (xr + 2) >= 1)
					hl(Std.int(Math.max(xr + 2, HALF - 3)), HALF - 1, hb - 3, G);
				floors.push(hb - 3);
			}
			// along the sides of the screen and under the house: shelves, a floor with holes
			var sy = hb + range(2, 3);
			if (sy <= 15) {
				hl(0, range(1, 2), sy, G);
				floors.push(sy);
			}
			var by = hb + range(4, 5);
			if (by <= 17) {
				// (its holes away from the sides: the shelves over them)
				var hx = range(3, 5);
				applyRow(by, [for (x in 0...HALF) x != hx && x != hx + 1 && (x < HALF - 1 || chance(0.5))]);
				floors.push(by);
			}
		} else {
			// long ramps across the level (A26, ayame 19): one or two diagonals from a side down to the other, 6 rows
			// apart, a gap in each; shelves along the side of the screen facing them, a floor with holes at the bottom
			sym = false;
			var dir = chance(0.5) ? 1 : -1;
			var n = chance(0.5) ? 2 : 1;
			var steps = sw == 1 ? range(8, 11) : range(5, 6);
			var y0 = range(3, 4);
			var low = 0;
			for (r in 0...n) {
				var ys = y0 + r * 6;
				var xs = dir > 0 ? r * 2 : W - 1 - r * 2;
				var gap = range(2, steps - 3);
				for (i in 0...steps) {
					if (ys + i > 15)
						break;
					if (i == gap || (sw == 1 && i == gap + 1))
						continue;
					for (k in 0...sw)
						setc(xs + dir * (i * sw + k), ys + i, G);
					low = Std.int(Math.max(low, ys + i));
				}
				floors.push(ys);
			}
			// the side facing the ramps: shelves every 3 rows
			var fx = dir > 0 ? W - 1 : 0;
			var sy = y0 + range(2, 3);
			while (sy <= 15) {
				var l = range(3, 5);
				var ok = true;
				for (k in 0...l + 1)
					for (yy in sy - 2...sy + 2)
						if (inb(fx - dir * k, yy) && m[fx - dir * k][yy] != 0)
							ok = false;
				if (ok) {
					for (k in 0...l)
						setc(fx - dir * k, sy, G);
					floors.push(sy);
				}
				sy += 3;
			}
			if (low + 3 <= 17) {
				var by = Std.int(Math.min(17, low + 3));
				for (x in 0...W)
					if (m[x][by - 1] == 0 && m[x][by - 2] == 0)
						setc(x, by, G);
				var hx = range(2, W - 4);
				setc(hx, by, 0);
				setc(hx + 1, by, 0);
				floors.push(by);
			}
		}
		addShelves(range(0, 1));
	}

	// rings (A41, A6, A29): a big ring with an opening at its top and at its bottom and floors in it, two rings side by
	// side, or an octagon; shelves around
	function tRing() {
		floors = [];
		sym = true;
		switch (draw([4, 3, 3, 3])) {
			case 0:
				var ry = 6.0 + rnd(2) * 0.5;
				var rx = ry + rnd(3) * 0.5;
				var cy2 = 19 + rnd(2);
				var cy = cy2 / 2;
				var pts = ellipse(W - 1, cy2, rx, ry);
				var ot = pick([1, 2]);
				pts = [for (p in pts) if (!(p.y < cy && Math.abs(p.x - 8.5) < ot) && !(p.y > cy && Math.abs(p.x - 8.5) < 1)) p];
				plot(pts);
				var top = H;
				var bot = 0;
				for (p in pts) {
					top = Std.int(Math.min(top, p.y));
					bot = Std.int(Math.max(bot, p.y));
				}
				floors.push(top);
				// in it: a floor across with a hole in the middle, or shelves on its walls
				var fy = Std.int(cy) + 1;
				var wall = 0;
				while (wall < HALF && m[wall][fy] == 0)
					wall++;
				if (chance(0.5))
					hl(wall + 1, HALF - 2, fy, G);
				else
					hl(wall + 1, wall + range(2, 3), fy, G);
				floors.push(fy);
				// up in it: a platform in the middle
				if (fy - 3 > top + 1)
					hl(HALF - range(1, 2), HALF - 1, fy - 3, G);
				// under it: a floor with holes
				if (bot <= 14) {
					applyRow(Std.int(Math.min(17, bot + 3)), hHoles(1));
					floors.push(Std.int(Math.min(17, bot + 3)));
				}
			case 1:
				// two rings side by side: floors over and under them
				var r = 3.5;
				var cy2 = 2 * range(8, 10);
				var pts = ellipse(2 * 4 + 1, cy2, r, r);
				var cy = cy2 / 2;
				// (an opening at the top and at the bottom of each ring, on the side of the middle or the screen)
				var side = chance(0.5);
				pts = [for (p in pts) if (!(Math.abs(p.x - (side ? 5 : 3)) < 1 && p.y != cy)) p];
				for (p in pts)
					put(p.x, p.y, G);
				var top = H;
				var bot = 0;
				for (p in pts) {
					top = Std.int(Math.min(top, p.y));
					bot = Std.int(Math.max(bot, p.y));
				}
				floors.push(top);
				// between them: a platform in the middle
				hl(HALF - range(1, 2), HALF - 1, Std.int(cy), G);
				floors.push(Std.int(cy));
				if (top >= 6) {
					applyRow(top - 3, hCenter(range(2, 3)));
					floors.push(top - 3);
				}
				if (bot <= 14) {
					applyRow(Std.int(Math.min(17, bot + 3)), hHoles(1));
					floors.push(Std.int(Math.min(17, bot + 3)));
				}
			case 3:
				// a diamond: four diagonals, open at its top and bottom corners, a floor across its middle
				var t = range(3, 4);
				var hh = Std.int(Math.min(range(6, 7), (16 - t) / 2));
				var cy = t + hh;
				for (i in 1...hh + 1) {
					put(HALF - 1 - i, t + i, G);
					put(HALF - 1 - i, cy + hh - i, G);
				}
				floors.push(t + 1);
				hl(HALF - hh + 2, HALF - 2, cy, G);
				floors.push(cy);
				if (chance(0.6)) {
					hl(HALF - 2, HALF - 1, cy - 3, G);
					floors.push(cy - 3);
				}
			default:
				// an octagon with a door in its roof and holes in its floor, shelves in it
				var x0 = range(2, 3);
				var t = range(4, 5);
				var b = Std.int(Math.min(16, t + range(9, 11)));
				var c = range(2, 3);
				var pts = octagon(x0, t, W - 1 - x0, b, c);
				var dw = range(1, 2);
				var hx = x0 + c + rnd(Std.int(Math.max(1, HALF - x0 - c - 3)));
				pts = [for (p in pts) if (!(p.y == t && Math.abs(p.x - 8.5) < dw) && !(p.y == b && (p.x == hx || p.x == hx + 1 || p.x == W - 1 - hx || p.x == W - 2 - hx))) p];
				plot(pts);
				floors.push(t);
				floors.push(b);
				var fy = t + 3;
				var k = 0;
				while (fy <= b - 3) {
					if (k % 2 == 0)
						hl(x0 + 1, x0 + range(2, 3), fy, G);
					else
						hl(HALF - range(2, 3), HALF - 1, fy, G);
					floors.push(fy);
					fy += 3;
					k++;
				}
		}
		addShelves(range(1, 2));
	}

	// floating rocks (A12, A23, A39): flat tops, their bottoms narrowing in steps; rows of them, staggered
	function tIslands() {
		floors = [];
		sym = chance(0.45);
		rocks(range(3, 4), 15, range(2, 3));
		addShelves(range(0, 1));
	}

	// rows of rocks from the row y0 down to y1 (thick: their thickest bottom)
	function rocks(y0:Int, y1:Int, thick:Int) {
		var lim = sym ? HALF : W;
		var y = y0;
		var row = 0;
		while (y <= y1) {
			var x = row % 2 == 0 ? rnd(2) : range(2, 3);
			var rowTh = 1;
			while (x <= lim - 2) {
				var w = range(3, 7);
				var joined = false;
				if (x + w > lim) {
					if (sym && x + 2 <= HALF) {
						w = HALF - x;
						joined = true;
					} else if (lim - x >= 3)
						w = lim - x;
					else
						break;
				}
				var th = Std.int(Math.min(thick, w >= 5 ? range(2, 3) : range(1, 2)));
				if (y + th > 17)
					th = 17 - y;
				for (k in 0...th) {
					var a = x + k;
					var b = joined ? HALF - 1 : x + w - 1 - k;
					if (a > b)
						break;
					hl(a, b, y + k, G);
					rowTh = Std.int(Math.max(rowTh, k + 1));
				}
				x += w + range(2, 3);
			}
			floors.push(y);
			y += Std.int(Math.max(3, rowTh + 2)) + rnd(2);
			row++;
		}
	}

	// a mountain (A59) or hills rising from the bottom: slopes in steps (of one case: a peak; of two), a top, the way
	// down in pits; rocks in the sky
	function tMountain() {
		floors = [];
		sym = chance(0.6);
		var hgt = [for (x in 0...W) 0];
		var sw = chance(0.4) ? 1 : 2;
		if (sym) {
			// one mountain, pits on its sides
			var s = range(1, 2);
			var top = sw == 1 ? range(6, 8) : range(4, 5);
			for (x in s...HALF) {
				hgt[x] = Std.int(Math.min(top, 1 + Std.int((x - s) / sw)));
				hgt[W - 1 - x] = hgt[x];
			}
		} else {
			// two hills, the pit between them
			var p = range(6, 10);
			var h1 = sw == 1 ? range(4, 6) : range(3, 4);
			var h2 = sw == 1 ? range(4, 6) : range(3, 4);
			for (x in 0...p)
				hgt[x] = Std.int(Math.min(h1, 1 + Std.int((p - 1 - x) / sw)));
			for (x in p + 2...W)
				hgt[x] = Std.int(Math.min(h2, 1 + Std.int((x - p - 2) / sw)));
		}
		for (x in 0...W)
			for (k in 0...hgt[x])
				setc(x, H - 1 - k, G);
		var maxH = 0;
		for (x in 0...W) {
			maxH = Std.int(Math.max(maxH, hgt[x]));
			if (hgt[x] > 0 && floors.indexOf(H - hgt[x]) < 0)
				floors.push(H - hgt[x]);
		}
		// the sky: rocks
		rocks(range(3, 4), H - maxH - 4, 2);
		addShelves(range(0, 1));
	}

	// caves (the Hells: deepnight 8 to 10): the rock from a side of the screen to the other, galleries 2 rows high dug
	// in it (its floors 2 rows thick), joined by shafts of 2 cases at one end then at the other (the way down zigzags),
	// stalactites in the galleries; the last shaft goes out at the bottom
	function tCaves() {
		sym = chance(0.35);
		floors = [];
		var top = range(4, 6);
		for (x in 0...W)
			for (y in top...H)
				setc(x, y, G);
		var galleries:Array<Int> = [];
		var gy = top + 1;
		while (gy + 3 <= 16) {
			for (x in 0...W) {
				setc(x, gy, 0);
				setc(x, gy + 1, 0);
			}
			galleries.push(gy);
			floors.push(gy + 2);
			gy += 4;
		}
		floors.push(top);
		var lim = sym ? HALF : W;
		// shafts: from the surface into the first gallery, then from each gallery into the next one, then out at the
		// bottom; at one end then at the other (one on each side in the symmetric caves)
		var left = chance(0.5);
		var rows = [top].concat([for (g in galleries) g + 2]);
		for (i in 0...rows.length) {
			var r = rows[i];
			var depthR = i == 0 ? 1 : (i == rows.length - 1 ? H - r : 2);
			var sx = sym ? range(1, HALF - 3) : (left ? range(1, 4) : W - 3 - range(1, 4));
			if (i == rows.length - 1 && !sym)
				sx = left ? range(1, 5) : W - 3 - range(1, 5);
			for (k in 0...2)
				for (d in 0...depthR)
					put(sx + k, r + d, 0);
			left = !left;
		}
		// in the galleries: stalactites hanging from the roof (the way under them stays open)
		for (g in galleries)
			for (k in 0...range(0, 2)) {
				var px = range(2, lim - 3);
				if (m[px][g - 1] > 0 && m[px][g + 2] > 0)
					put(px, g, G);
			}
		// the surface: a few rocks over it, a platform where Igor comes in
		applyRow(top - 3, hCenter(range(2, 3)));
		floors.push(top - 3);
		if (chance(0.6)) {
			var bx = range(1, lim - 4);
			hl(bx, bx + range(1, 2), top - 1, G);
		}
	}

	// combs (A30): long bars across the level 4 rows apart, an opening at one end then at the other (the way down
	// snakes), teeth hanging from each bar every few cases (Igor and the bads go under them)
	function tComb() {
		sym = false;
		floors = [];
		var sp = 4;
		var y = 3;
		var left = chance(0.5);
		var tp = range(4, 6);
		var ph = rnd(tp);
		var first = true;
		while (y <= 16) {
			var hw = range(2, 3);
			for (x in 0...W)
				setc(x, y, G);
			for (k in 0...hw)
				setc(left ? k : W - 1 - k, y, 0);
			floors.push(y);
			// (the teeth: not the first bar, Igor comes in over it; not over the opening of the next bar)
			if (!first && y + sp <= 16) {
				var x = ph + (left ? hw + 1 : 1);
				while (x < W - 1) {
					var inOpen = left ? x < hw + 1 : x > W - 2 - hw;
					if (!inOpen && x > 0)
						setc(x, y + 1, G);
					x += tp;
				}
			}
			first = false;
			y += sp;
			left = !left;
		}
	}

	function fallback() {
		clear();
		sym = true;
		kind = "fallback";
		floors = [4, 8, 12, 16];
		applyRow(4, hCenter(3));
		applyRow(8, hSide(5));
		applyRow(12, hCenter(5));
		applyRow(16, hHoles(1));
		px = 8;
		py = 3;
		bads.push({id: Data.BAD_CERISE, x: 2, y: 7});
		bads.push({id: Data.BAD_CERISE, x: 15, y: 7});
		bads.push({id: Data.BAD_CERISE, x: 6, y: 11});
	}

	// ---------------------------------------------------------------- cleaning, start

	function cleanup() {
		for (x in 0...W)
			if (m[x][0] > 0)
				m[x][0] = 0;
		// lonely cases of ground in the air (not the steps of a diagonal: touching another case by a corner)
		for (x in 0...W)
			for (y in 1...H)
				if (m[x][y] > 0 && !gr(x - 1, y) && !gr(x + 1, y) && !gr(x, y - 1) && !gr(x, y + 1) && x > 0 && x < W - 1
					&& !gr(x - 1, y - 1) && !gr(x + 1, y - 1) && !gr(x - 1, y + 1) && !gr(x + 1, y + 1))
					m[x][y] = 0;
	}

	inline function mark(x:Int, y:Int) {
		if (inb(x, y))
			busy[x][y] = true;
	}

	inline function canStand(x:Int, y:Int):Bool {
		return inb(x, y) && y + 1 < H && m[x][y] <= 0 && m[x][y + 1] > 0 && !danger[x][y];
	}

	inline function passable(x:Int, y:Int):Bool {
		if (x < 0 || x >= W)
			return false;
		if (y < 0 || y >= H)
			return true;
		return m[x][y] <= 0 && !danger[x][y];
	}

	// columns without ground (falling straight there goes through the level), the first ground of each column under
	// spikes counts too
	function openColumns():Int {
		var n = 0;
		for (x in 0...W) {
			var y = 1;
			while (y < H && m[x][y] <= 0)
				y++;
			if (y >= H || danger[x][y - 1])
				n++;
		}
		return n;
	}

	// columns without ground: a platform of a floor goes on over them (from the top floors), the nearest end of a
	// platform goes on to them, or a shelf
	function repairColumns() {
		var rows = floors == null ? [] : floors.copy();
		if (rows.length > 1)
			rows.pop(); // (not the floor at the bottom: its holes are the way down)
		for (x in 0...W) {
			var y = 1;
			while (y < H && m[x][y] <= 0)
				y++;
			if (y < H)
				continue;
			var done = false;
			for (fy in rows) {
				if (fy < 3 || fy >= H || m[x][fy] != 0 || m[x][fy - 1] > 0)
					continue;
				if ((x > 0 && m[x - 1][fy] > 0) || (x + 1 < W && m[x + 1][fy] > 0)) {
					put(x, fy, G);
					done = true;
					break;
				}
			}
			if (done)
				continue;
			// (the nearest end of a platform 2 or 3 cases away goes on to it: no small piece alone in the air)
			var bestY = -1;
			var bestDir = 0;
			var bestD = 99;
			for (y in 3...H - 1)
				for (d in 2...4)
					for (dir in [-1, 1]) {
						var ex = x + dir * d;
						if (ex < 0 || ex >= W || m[ex][y] <= 0 || m[ex][y - 1] > 0)
							continue;
						var ok = true;
						for (k in 0...d) {
							var cx = x + dir * k;
							if (m[cx][y] != 0 || m[cx][y - 1] != 0 || m[cx][y - 2] != 0 || (y + 1 < H && m[cx][y + 1] > 0))
								ok = false;
						}
						var v = d * 2 + (rows.indexOf(y) >= 0 ? 0 : 1);
						if (ok && v < bestD) {
							bestD = v;
							bestY = y;
							bestDir = dir;
						}
					}
			if (bestY >= 0) {
				var ex = x;
				while (m[ex][bestY] <= 0) {
					put(ex, bestY, G);
					ex += bestDir;
				}
				continue;
			}
			// (else a shelf of 3 cases on a row of the floors, free around)
			for (fy in rows) {
				if (fy < 3 || fy >= H - 1)
					continue;
				var x0 = Std.int(Math.max(0, Math.min(W - 3, x - 1)));
				var ok = true;
				for (xx in x0 - 1...x0 + 4)
					for (yy in fy - 2...fy + 3)
						if (inb(xx, yy) && m[xx][yy] != 0)
							ok = false;
				if (ok) {
					hl(x0, x0 + 2, fy, G);
					done = true;
					break;
				}
			}
			if (!done && rows.length > 0) {
				var fy = rows[Std.int(rows.length / 2)];
				if (fy >= 3 && m[x][fy] == 0) {
					put(x, fy, G);
					var x2 = x + 1 < W ? x + 1 : x - 1;
					if (m[x2][fy] == 0)
						put(x2, fy, G);
				}
			}
		}
	}

	// row where Igor lands falling straight in a column from the top
	function landRow(x:Int):Int {
		var y = 0;
		while (y < H - 1 && !(m[x][y] <= 0 && m[x][y + 1] > 0))
			y++;
		return y;
	}

	// going up: the platforms of one case are crossed from under them (no ceiling in the original physics), not the
	// walls nor the spikes
	inline function passUp(x:Int, y:Int):Bool {
		if (x < 0 || x >= W)
			return false;
		if (y < 0 || y >= H)
			return true;
		if (danger[x][y])
			return false;
		if (m[x][y] <= 0)
			return true;
		return (y == 0 || m[x][y - 1] <= 0) && (y + 1 >= H || m[x][y + 1] <= 0);
	}

	// Igor comes in at the top, in the middle as much as possible, on a platform of the top rows
	function placeStart():Bool {
		var best:GPt = null;
		var bestV = 1.0e9;
		for (y in 1...6)
			for (x in 1...W - 1) {
				if (!canStand(x, y) || m[x][y] < 0)
					continue;
				var v = Math.abs(x - 8.5) + y * 1.5 + rnd(3);
				if (v < bestV) {
					bestV = v;
					best = {x: x, y: y};
				}
			}
		if (best == null) {
			// in the air over a platform: he falls on it
			for (x in [8, 9, 7, 10, 6, 11, 5, 12]) {
				var y = 1;
				while (y < H - 1 && !canStand(x, y))
					y++;
				if (canStand(x, y) && y <= 9) {
					best = {x: x, y: 1};
					break;
				}
			}
		}
		if (best == null)
			return false;
		px = best.x;
		py = best.y;
		for (y in py - 1...py + 1)
			mark(px, y);
		return true;
	}

	// Igor at the start lands on a ground (no spikes)
	function startOk():Bool {
		var y = py;
		while (y < H - 1 && !canStand(px, y)) {
			if (!passable(px, y))
				return false;
			y++;
		}
		return canStand(px, y);
	}

	// ---------------------------------------------------------------- moves of Igor

	// teleporters: runs of cases of the map (vertical or horizontal) and the runs they lead to (World.getNextTeleporter:
	// the same direction and length, at the same row (vertical) or column (horizontal), else any of them)
	var teleRuns:Array<{cells:Array<GPt>, vert:Bool}>;
	var teleTo:Array<Array<Int>>;
	var teleAt:Array<Array<Int>>;

	function findTeleporters() {
		teleRuns = [];
		if (teleAt == null)
			teleAt = [for (x in 0...W) [for (y in 0...H) -1]];
		else
			for (x in 0...W) {
				var c = teleAt[x];
				for (y in 0...H)
					c[y] = -1;
			}
		teleTo = [];
		var any = false;
		for (x in 0...W)
			for (y in 0...H)
				if (m[x][y] == Data.FIELD_TELEPORT)
					any = true;
		if (!any)
			return;
		for (y in 0...H)
			for (x in 0...W) {
				if (m[x][y] != Data.FIELD_TELEPORT || teleAt[x][y] >= 0)
					continue;
				var vert = !(x + 1 < W && m[x + 1][y] == Data.FIELD_TELEPORT);
				var cells:Array<GPt> = [];
				if (vert) {
					var yy = y;
					while (yy < H && m[x][yy] == Data.FIELD_TELEPORT) {
						cells.push({x: x, y: yy});
						yy++;
					}
				} else {
					var xx = x;
					while (xx < W && m[xx][y] == Data.FIELD_TELEPORT) {
						cells.push({x: xx, y: y});
						xx++;
					}
				}
				for (c in cells)
					teleAt[c.x][c.y] = teleRuns.length;
				teleRuns.push({cells: cells, vert: vert});
			}
		for (i in 0...teleRuns.length) {
			var a = teleRuns[i];
			var exact = [];
			var any = [];
			for (j in 0...teleRuns.length) {
				var b = teleRuns[j];
				if (j == i || b.vert != a.vert || b.cells.length != a.cells.length)
					continue;
				any.push(j);
				if ((a.vert && b.cells[0].y == a.cells[0].y) || (!a.vert && b.cells[0].x == a.cells[0].x))
					exact.push(j);
			}
			teleTo.push(exact.length > 0 ? [exact[0]] : any);
		}
	}

	// (the work of computeReach, kept from a call to the next: cases in the air already seen, cases reached to look
	// from, ways out of the teleporters, falls; a case is (x << 5) | y)
	var airMap:Array<Bool>;
	var landQ:Array<Int>;
	var landN:Int;
	var teleQ:Array<Int>;
	var fallSt:Array<Int>;

	function computeReach() {
		findTeleporters();
		if (reach == null)
			reach = [for (x in 0...W) [for (y in 0...H) false]];
		else
			for (x in 0...W) {
				var c = reach[x];
				for (y in 0...H)
					c[y] = false;
			}
		if (airMap == null) {
			airMap = [for (i in 0...W * H) false];
			landQ = [];
			teleQ = [];
			fallSt = [];
		} else
			for (i in 0...W * H)
				airMap[i] = false;
		exitOk = false;
		landN = 0;
		teleQ.splice(0, teleQ.length);
		reachFall(px, py);
		var i = 0;
		while (i < landN || teleQ.length > 0) {
			if (i >= landN) {
				// out of a teleporter: on its ground, or falling under it
				var o = teleQ.pop();
				var ox = o >> 5;
				var oy = o & 31;
				if (canStand(ox, oy))
					reachLand(ox, oy);
				else if (oy + 1 < H)
					reachFall(ox, oy + 1);
				else
					exitOk = true;
				continue;
			}
			var p = landQ[i++];
			movesFrom(p >> 5, p & 31);
		}
	}

	// the moves of Igor from a case where he stands: walking (falling off the edges), jumping up, across, down,
	// teleporters
	function movesFrom(x:Int, y:Int) {
		// walking in a teleporter
		if (teleAt[x][y] >= 0)
			reachTele(x, y);
		var dir = -1;
		while (dir <= 1) {
			// walk
			var nx = x + dir;
			if (passable(nx, y)) {
				if (canStand(nx, y))
					reachLand(nx, y);
				else
					reachFall(nx, y);
			}
			// jump up: 3 cases high, 2 or 3 across
			for (k in 1...4) {
				var maxd = k == 3 ? 2 : 3;
				var clear = true;
				for (r in y - k - 1...y)
					if (!passUp(x, r))
						clear = false;
				if (!clear)
					break;
				for (d in 0...maxd + 1) {
					var tx = x + dir * d;
					var ty = y - k;
					if (!canStand(tx, ty))
						continue;
					// (the walls stop Igor at the height of the bottom of his body: the row he lands in)
					var ok = true;
					for (c in 1...d + 1)
						if (!passable(x + dir * c, ty))
							ok = false;
					if (ok)
						reachLand(tx, ty);
				}
			}
			// jump across or down: 4 cases (5 going down)
			if (passable(x, y - 1)) {
				for (d in 2...6) {
					for (j in 0...5) {
						if (d == 5 && j == 0)
							continue;
						var tx = x + dir * d;
						var ty = y + j;
						if (!canStand(tx, ty))
							continue;
						var ok = true;
						for (c in 1...d + 1)
							if (!passable(x + dir * c, y) || !passable(x + dir * c, y - 1))
								ok = false;
						for (r in y...ty)
							if (!passable(tx, r))
								ok = false;
						if (ok)
							reachLand(tx, ty);
					}
				}
			}
			dir += 2;
		}
	}

	inline function reachLand(x:Int, y:Int) {
		if (collecting) {
			var c = x * H + y;
			if (collected.indexOf(c) < 0)
				collected.push(c);
		} else if (!reach[x][y]) {
			reach[x][y] = true;
			landQ[landN++] = (x << 5) | y;
		}
	}

	// ways out of the teleporters met (computeReach does the same in its loop)
	function drainTele() {
		while (teleQ.length > 0) {
			var o = teleQ.pop();
			var ox = o >> 5;
			var oy = o & 31;
			if (canStand(ox, oy))
				reachLand(ox, oy);
			else if (oy + 1 < H)
				reachFall(ox, oy + 1);
			else
				exitOk = true;
		}
	}

	// the moves case by case (for many starts on the same level: wayBack, entryColumns): the cases where Igor lands from
	// each case where he stands, and the ways down out of the level from there
	var collecting:Bool = false;
	var collected:Array<Int>;
	var moveTo:Array<Array<Int>>;
	var moveOut:Array<Bool>;

	function buildMoves() {
		computeReach();
		moveTo = [for (i in 0...W * H) null];
		moveOut = [for (i in 0...W * H) false];
		collecting = true;
		for (x in 0...W)
			for (y in 0...H) {
				if (!canStand(x, y))
					continue;
				collected = [];
				exitOk = false;
				for (i in 0...W * H)
					airMap[i] = false;
				teleQ.splice(0, teleQ.length);
				movesFrom(x, y);
				drainTele();
				moveTo[x * H + y] = collected;
				moveOut[x * H + y] = exitOk;
			}
		collecting = false;
	}

	// computeReach from (x0, y0) with the moves of buildMoves
	function reachFrom(x0:Int, y0:Int) {
		for (x in 0...W) {
			var c = reach[x];
			for (y in 0...H)
				c[y] = false;
		}
		collecting = true;
		collected = [];
		exitOk = false;
		for (i in 0...W * H)
			airMap[i] = false;
		teleQ.splice(0, teleQ.length);
		reachFall(x0, y0);
		drainTele();
		collecting = false;
		var q = collected;
		for (c in q)
			reach[Std.int(c / H)][c % H] = true;
		var i = 0;
		while (i < q.length) {
			var c = q[i++];
			if (moveOut[c])
				exitOk = true;
			for (n in moveTo[c]) {
				var nx = Std.int(n / H);
				var ny = n % H;
				if (!reach[nx][ny]) {
					reach[nx][ny] = true;
					q.push(n);
				}
			}
		}
	}

	// through a teleporter: out of the other one (at its bottom: on its ground, or falling under it)
	function reachTele(x:Int, y:Int) {
		var r = teleAt[x][y];
		var cs = teleRuns[r].cells;
		var k = 0;
		for (i in 0...cs.length)
			if (cs[i].x == x && cs[i].y == y)
				k = i;
		for (j in teleTo[r]) {
			var b = teleRuns[j];
			var o = b.vert ? b.cells[b.cells.length - 1] : b.cells[k];
			teleQ.push((o.x << 5) | o.y);
		}
	}

	// falling from a case in the air: 1 case to the side for each case down (a case of the stack: (x << 5) | (y + 1))
	function reachFall(x0:Int, y0:Int) {
		var st = fallSt;
		var n = 0;
		st[n++] = (x0 << 5) | (y0 + 1);
		while (n > 0) {
			var c = st[--n];
			var x = c >> 5;
			var y = (c & 31) - 1;
			if (y >= H) {
				exitOk = true;
				continue;
			}
			if (!passable(x, y) || (y >= 0 && airMap[x * H + y]))
				continue;
			if (y >= 0)
				airMap[x * H + y] = true;
			if (teleAt[x][y] >= 0) {
				reachTele(x, y);
				continue;
			}
			if (canStand(x, y)) {
				reachLand(x, y);
				continue;
			}
			if (y + 1 >= H) {
				exitOk = true;
				continue;
			}
			st[n++] = (x << 5) | (y + 2);
			if (passable(x - 1, y) && passable(x - 1, y + 1))
				st[n++] = ((x - 1) << 5) | (y + 2);
			if (passable(x + 1, y) && passable(x + 1, y + 1))
				st[n++] = ((x + 1) << 5) | (y + 2);
		}
	}

	// standing segments of the level
	function segments():Array<GSeg> {
		var out = [];
		for (y in 1...H - 1) {
			var x = 0;
			while (x < W) {
				if (canStand(x, y)) {
					var x0 = x;
					while (x < W && canStand(x, y))
						x++;
					out.push({y: y, x0: x0, x1: x - 1});
				} else
					x++;
			}
		}
		return out;
	}

	function segReached(s:GSeg):Bool {
		for (x in s.x0...s.x1 + 1)
			if (reach[x][s.y])
				return true;
		return false;
	}

	// ---------------------------------------------------------------- hazards

	function addHazards() {
		var d = depth;
		var r = rhythm(d);
		// lasers: kinds of bombs
		if (d >= 1 && chance(Math.min(0.85, (0.35 + d * 0.05) * r)))
			addGates();
		// teleporters between the sides of the screen
		if (d >= 3 && kind != "cage" && teles.length == 0 && chance(Math.min(0.35, (0.1 + d * 0.02) * r)))
			addSideTeleporters();
		// saws around the small blocks: from level 8, in some levels (a pair in the symmetric ones), more often deeper
		// and at the end of a chapter (the original keeps them for the Hells)
		if (d >= 8 && chance(Math.min(0.55, 0.12 + (d - 8) * 0.025) * r)) {
			addSaws();
			if (d >= 25 && chance(0.35 * r))
				addSaws();
		}
		// spikes on the sides of the V
		if (wallSpikes && d >= 4)
			addWallSpikes();
	}

	function addWallSpikes() {
		var c = [];
		for (y in 3...H - 1)
			for (x in 1...HALF)
				if (m[x - 1][y] > 0 && m[x][y] == 0 && m[x][y + 1] == 0 && !busy[x][y])
					c.push({x: x, y: y});
		var n = Std.int(Math.min(4, 1 + depth / 8));
		for (k in 0...n) {
			if (c.length == 0)
				break;
			var p = c.splice(rnd(c.length), 1)[0];
			var all = [p, {x: W - 1 - p.x, y: p.y}];
			for (a in all)
				danger[a.x][a.y] = true;
			computeReach();
			if (!exitOk || !startOk()) {
				for (a in all)
					danger[a.x][a.y] = false;
				continue;
			}
			for (a in all) {
				mark(a.x, a.y);
				bads.push({id: Data.BAD_SPEAR, x: a.x, y: a.y});
			}
		}
	}

	function fieldColor():Int {
		var d = depth;
		return -1 - draw([1, d >= 4 ? 3 : 0, 3, d >= 6 ? 2 : 0, d >= 8 ? 2 : 0]);
	}

	// holes of 2 cases in a floor and doors of 2 cases in a wall: lasers
	function addGates(?forced:Null<Int>):Bool {
		var holes:Array<GPt> = [];
		var doors:Array<GPt> = [];
		for (y in 3...H)
			for (x in 0...W - 1) {
				if (busy[x][y] || busy[x + 1][y])
					continue;
				// (over a ground: falling through the laser lands in the level, not out of it)
				if (m[x][y] == 0 && m[x + 1][y] == 0 && x > 0 && x + 2 < W && m[x - 1][y] > 0 && m[x + 2][y] > 0 && !gr(x, y - 1)
					&& !gr(x + 1, y - 1) && (!sym || x + 1 < HALF || x == HALF - 1) && groundFrom(x, y + 1) < H
					&& groundFrom(x + 1, y + 1) < H)
					holes.push({x: x, y: y});
			}
		for (y in 3...H - 1)
			for (x in 1...W - 1) {
				if (m[x][y] == 0 && m[x][y - 1] == 0 && m[x][y + 1] > 0 && gr(x, y - 2) && y - 2 >= 1 && m[x][y - 2] > 0
					&& passable(x - 1, y) && passable(x + 1, y) && (!sym || x < HALF - 1))
					doors.push({x: x, y: y});
			}
		// (not on the way of Igor falling at the start)
		var landY = py;
		while (landY < H - 1 && !canStand(px, landY))
			landY++;
		holes = [for (h in holes) if (!(h.x + 1 >= px - 2 && h.x <= px + 2 && h.y <= landY + 3)) h];
		doors = [for (d in doors) if (!(Math.abs(d.x - px) <= 3 && Math.abs(d.y - landY) <= 2)) d];
		var n = (depth >= 15 && !sym) ? 2 : 1;
		var peace = depth >= 6 && holes.length + doors.length >= 2 && chance(0.25);
		if (forced != null) {
			// (a laser of that colour on a way of Igor)
			holes = [for (h in holes) if (reachedNear(h.x, h.y) || reachedNear(h.x + 1, h.y)) h];
			doors = [for (d in doors) if (reachedNear(d.x, d.y)) d];
			n = 1;
			peace = false;
		}
		if (holes.length + doors.length == 0)
			return false;
		var placed = 0;
		var tries = 0;
		while (placed < n + (peace ? 1 : 0) && tries < 10 && holes.length + doors.length > 0) {
			tries++;
			var c = forced != null ? forced : (placed == 0 && peace ? Data.FIELD_PEACE : (placed == 1 && peace ? -1 : fieldColor()));
			if (holes.length > 0 && (doors.length == 0 || chance(0.6))) {
				var h = holes.splice(rnd(holes.length), 1)[0];
				put(h.x, h.y, c);
				put(h.x + 1, h.y, c);
				mark(h.x, h.y);
				mark(h.x + 1, h.y);
				if (sym) {
					mark(W - 1 - h.x, h.y);
					mark(W - 2 - h.x, h.y);
				}
			} else {
				var dd = doors.splice(rnd(doors.length), 1)[0];
				put(dd.x, dd.y, c);
				put(dd.x, dd.y - 1, c);
				mark(dd.x, dd.y);
				mark(dd.x, dd.y - 1);
				if (sym) {
					mark(W - 1 - dd.x, dd.y);
					mark(W - 1 - dd.x, dd.y - 1);
				}
			}
			placed++;
		}
		return true;
	}

	// teleporters on both sides of the screen at the same height
	function addSideTeleporters() {
		var rows = [for (y in 3...H - 1) if (canStand(0, y) && canStand(W - 1, y) && passable(0, y - 1) && passable(W - 1, y - 1)
			&& !busy[0][y] && !busy[W - 1][y] && Math.abs(y - py) > 2 && m[0][y - 2] >= 0 && m[W - 1][y - 2] >= 0) y];
		if (rows.length == 0)
			return;
		var y = pick(rows);
		var save = sym;
		sym = false;
		for (x in [0, W - 1]) {
			setc(x, y, Data.FIELD_TELEPORT);
			setc(x, y - 1, Data.FIELD_TELEPORT);
			// (a ground over it: from a ground to a ground, like in the original)
			setc(x, y - 2, G);
			mark(x, y);
			mark(x, y - 1);
		}
		sym = save;
		teles.push({a: {x: 0, y: y}, b: {x: W - 1, y: y}});
	}

	// spikes where they are a danger for Igor and not for the bads (the bads go everywhere by themselves: they would die
	// on them one after the other): under the ceilings over the ways (no jumping there), on the ways only Igor takes (his
	// jumps are longer)
	function addSpikes(n:Int) {
		computeReach();
		var zone = badZone();
		function safe(x:Int, y:Int):Bool {
			return farFromBads(zone, x, y);
		}
		var before = 0;
		for (s in segments())
			if (segReached(s))
				before++;
		var placed:Array<GPt> = [];
		var segs = segments();
		var tries = 0;
		// (the places: strips on the floors, under the ceilings over the ways, on the walls where Igor jumps)
		var floorsC = [for (s in segs) if (s.x1 - s.x0 + 1 >= 5 && Math.abs(s.y - py) > 1 && [for (x in s.x0 + 2...s.x1 - 1) if (safe(x, s.y)) x].length > 0) s];
		var ceils:Array<GPt> = [];
		var walls:Array<GPt> = [];
		for (y in 2...H - 1)
			for (x in 0...W) {
				if (m[x][y] != 0 || busy[x][y] || !safe(x, y))
					continue;
				if (m[x][y - 1] > 0 && m[x][y + 1] == 0 && y + 3 < H && m[x][y + 2] == 0
					&& (m[x][y + 3] > 0 || (y + 4 < H && m[x][y + 3] == 0 && m[x][y + 4] > 0)))
					ceils.push({x: x, y: y});
				else if (depth >= 4 && m[x][y - 1] <= 0 && m[x][y + 1] <= 0 && (wallAt(x - 1, y) || wallAt(x + 1, y))
					&& reachedNear(x, y) && Math.abs(y - py) > 3)
					walls.push({x: x, y: y});
			}
		#if gentest
		spikeStats.set("calls", (spikeStats.exists("calls") ? spikeStats.get("calls") : 0) + 1);
		spikeStats.set("floorsC", (spikeStats.exists("floorsC") ? spikeStats.get("floorsC") : 0) + floorsC.length);
		spikeStats.set("ceils", (spikeStats.exists("ceils") ? spikeStats.get("ceils") : 0) + ceils.length);
		spikeStats.set("walls", (spikeStats.exists("walls") ? spikeStats.get("walls") : 0) + walls.length);
		#end
		while (placed.length < n && tries < 20) {
			tries++;
			var added:Array<GPt> = [];
			var what = draw([floorsC.length > 0 ? 4 : 0, ceils.length > 0 ? 4 : 0, walls.length > 0 && depth >= 6 ? 3 : 0]);
			if (floorsC.length + ceils.length + walls.length == 0)
				break;
			if (what == 0) {
				// a strip of spikes in a long platform (2 to 4 of them: a row, like in the original)
				var s = pick(floorsC);
				var len = s.x1 - s.x0 + 1;
				var k = range(2, Std.int(Math.max(2, Math.min(4, len - 4))));
				var x0 = s.x0 + 2 + rnd(Std.int(Math.max(1, len - 3 - k)));
				for (x in x0...x0 + k)
					if (x <= s.x1 && !busy[x][s.y] && !(x == px && s.y >= py) && safe(x, s.y))
						added.push({x: x, y: s.y});
				if (added.length < 2)
					added = [];
			} else if (what == 1) {
				// spikes under a ceiling, over a way 2 or 3 cases lower
				// (the whole underside of the ceiling, or 3 or 4 cases of it: a row, not spikes here and there)
				var p = pick(ceils);
				var a = p.x;
				var b = p.x;
				while (a > 0 && m[a - 1][p.y - 1] > 0 && m[a - 1][p.y] == 0)
					a--;
				while (b < W - 1 && m[b + 1][p.y - 1] > 0 && m[b + 1][p.y] == 0)
					b++;
				if (b - a + 1 > 5) {
					var k = range(3, 4);
					a = Std.int(Math.max(a, Math.min(p.x - 1, b - k + 1)));
					b = a + k - 1;
				}
				for (x in a...b + 1)
					if (!busy[x][p.y] && safe(x, p.y))
						added.push({x: x, y: p.y});
				if (added.length < 2 || added.length < b - a + 1)
					added = [];
			} else {
				// spikes on a wall, in the air where Igor jumps (two over each other when the wall is free there)
				var p = pick(walls);
				added.push(p);
				walls.remove(p);
				for (w in walls)
					if (w.x == p.x && Math.abs(w.y - p.y) == 1 && added.length < 2) {
						added.push(w);
						walls.remove(w);
						break;
					}
			}
			if (added.length == 0)
				continue;
			var all = [];
			for (a in added) {
				all.push(a);
				if (sym && W - 1 - a.x != a.x && safe(W - 1 - a.x, a.y) && !busy[W - 1 - a.x][a.y])
					all.push({x: W - 1 - a.x, y: a.y});
			}
			for (a in all)
				setDanger(a, true);
			computeReach();
			var after = 0;
			for (s in segments())
				if (segReached(s))
					after++;
			if (!exitOk || after < before - 1 || !startOk() || openColumns() > 0) {
				for (a in all)
					setDanger(a, false);
				continue;
			}
			for (a in all) {
				placed.push(a);
				mark(a.x, a.y);
				bads.push({id: Data.BAD_SPEAR, x: a.x, y: a.y});
			}
			#if gentest
			spikeStats.set("placed" + what, (spikeStats.exists("placed" + what) ? spikeStats.get("placed" + what) : 0) + all.length);
			#end
			segs = segments();
		}
		computeReach();
	}

	// a case of a wall (ground over or under it too), not the end of a thin platform
	function wallAt(x:Int, y:Int):Bool {
		return x >= 0 && x < W && m[x][y] > 0 && ((y > 0 && m[x][y - 1] > 0) || (y + 1 < H && m[x][y + 1] > 0));
	}

	// platforms left for the bads (reached, long enough, no saw nor spikes around, not where Igor comes in): the
	// hazards keep enough of them
	function badRoom():Int {
		var topLand = H;
		for (x in 0...W)
			topLand = Std.int(Math.min(topLand, landRow(x)));
		var n = 0;
		for (s in segments())
			if ((segReached(s) || segNear(s)) && s.x1 - s.x0 + 1 >= 2 && !isNoBad(s) && !spikesNear(s) && s.y != topLand)
				n += s.x1 - s.x0 + 1 >= 9 ? 2 : 1;
		return n;
	}

	function badNeed():Int {
		return Std.int(Math.min(5, 2 + depth / 3)) + 1;
	}

	function setDanger(a:GPt, v:Bool) {
		danger[a.x][a.y] = v;
		// spikes of a ceiling: the head of Igor under them
		if (a.y > 0 && m[a.x][a.y - 1] > 0 && a.y + 1 < H && m[a.x][a.y + 1] <= 0)
			danger[a.x][a.y + 1] = v;
	}

	// saws walking around the small platforms
	function addSaws() {
		var segs = segments();
		// (not against the sides of the screen: the saws would climb them)
		var c = [for (s in segs) if (s.x1 - s.x0 + 1 >= 2 && s.x1 - s.x0 + 1 <= 6 && blockSize(s) <= 8 && !blockOnSide
			&& Math.abs(s.y - py) + Math.abs(s.x0 - px) > 6 && !isNoBad(s)) s];
		if (c.length == 0)
			return;
		var s = pick(c);
		var x = s.x0 + rnd(s.x1 - s.x0 + 1);
		if (busy[x][s.y])
			return;
		var twin = sym && W - 1 - x != x && (s.x0 > HALF - 1 || s.x1 < HALF);
		var nn = noBads.length;
		noBads.push(s);
		if (twin)
			noBads.push({y: s.y, x0: W - 1 - s.x1, x1: W - 1 - s.x0});
		// (enough platforms left for the bads)
		if (badRoom() < badNeed()) {
			noBads.splice(nn, noBads.length - nn);
			return;
		}
		bads.push({id: Data.BAD_SAW, x: x, y: s.y});
		mark(x, s.y);
		if (twin) {
			bads.push({id: Data.BAD_SAW, x: W - 1 - x, y: s.y});
			mark(W - 1 - x, s.y);
		}
	}

	var blockOnSide:Bool = false;

	// cases of ground of the block under a segment (blockOnSide: it touches a side of the screen)
	function blockSize(s:GSeg):Int {
		blockOnSide = false;
		var seen = [for (x in 0...W) [for (y in 0...H) false]];
		var st = [{x: s.x0, y: s.y + 1}];
		var n = 0;
		while (st.length > 0 && n < 30) {
			var p = st.pop();
			if (!inb(p.x, p.y) || seen[p.x][p.y] || m[p.x][p.y] <= 0)
				continue;
			seen[p.x][p.y] = true;
			n++;
			if (p.x == 0 || p.x == W - 1)
				blockOnSide = true;
			st.push({x: p.x + 1, y: p.y});
			st.push({x: p.x - 1, y: p.y});
			st.push({x: p.x, y: p.y + 1});
			st.push({x: p.x, y: p.y - 1});
		}
		return n;
	}

	// ---------------------------------------------------------------- bads

	function unlocked():Array<Int> {
		return [for (r in ROSTER) if (depth >= r[1]) r[0]];
	}

	// bads throwing things at Igor
	function shooter(id:Int):Bool {
		return id == Data.BAD_POMME || id == Data.BAD_POIRE || id == Data.BAD_CITRON || id == Data.BAD_FRAISE
			|| id == Data.BAD_CRAWLER;
	}

	function minLen(id:Int):Int {
		return switch (id) {
			case Data.BAD_FRAISE: 1;
			case Data.BAD_ANANAS: 4;
			case Data.BAD_KIWI: 4;
			case Data.BAD_POMME, Data.BAD_ABRICOT: 3;
			default: 2;
		}
	}

	// liking of a bad for a segment
	function liking(id:Int, s:GSeg):Float {
		var len = s.x1 - s.x0 + 1;
		var v = 1.0;
		switch (id) {
			case Data.BAD_FRAISE:
				// alone on a ledge, another ledge in front of it
				v = len <= 4 ? 3 : 0.5;
			case Data.BAD_ANANAS:
				v = len * 0.5 + s.y * 0.2;
			case Data.BAD_POIRE:
				v = (H - s.y) * 0.3;
			case Data.BAD_ABRICOT:
				v = 1 + (H - s.y) * 0.15 + len * 0.1;
			case Data.BAD_KIWI, Data.BAD_POMME:
				v = len * 0.4;
			case Data.BAD_CITRON:
				// open over and under
				v = 1 + (gr(s.x0, s.y - 2) ? 0 : 1);
			case Data.BAD_BANANE:
				// near the walls (it climbs)
				v = 1 + ((gr(s.x0 - 1, s.y) || gr(s.x1 + 1, s.y)) ? 2 : 0);
			default:
				v = 1 + len * 0.15;
		}
		return v;
	}

	// the bads of the level: kinds by the depth (a new kind comes in its first levels), placed for what they do
	// the bads of the level: a budget of difficulty (badBudget) spent on 1 to 3 kinds (the recent ones more often, and
	// the strong ones deeper and deeper in the well); the kind met for the first time is shown: a few of it among
	// weaker ones, a level a little calmer
	public var budgetUsed:Float = 0;

	function badList():Array<Int> {
		var kinds = unlocked();
		var budget = badBudget(depth);
		// (a level holds 8 or 9 of them: deeper, stronger bads rather than more)
		var maxBads = Std.int(Math.min(9, 3 + depth));
		var list:Array<Int> = [];
		var sum = 0.0;
		var intro = introKind(depth);
		if (intro >= 0) {
			budget *= 0.9;
			var p = (intro == Data.BAD_ANANAS || intro == Data.BAD_FRAMBOISE) ? 1
				: ((intro == Data.BAD_FRAISE || intro == Data.BAD_ABRICOT) ? 2 : range(2, 3));
			for (i in 0...p) {
				list.push(intro);
				sum += threat(intro);
			}
		}
		var pool = [for (k in kinds) if (k != intro) k];
		// (the weakest ones hardly ever deep in the well)
		var w = [for (k in pool) Std.int(100 * (depth - introDepth(k) <= 4 ? 2.5 : 1) * Math.pow(threat(k), depth / 15)
			* (depth >= 15 && threat(k) < 1.2 ? 0.2 : 1) * rarity(k))];
		var nk = depth < 2 ? 1 : (depth < 6 ? range(1, 2) : range(2, 3));
		if (intro >= 0)
			nk = Std.int(Math.max(1, nk - 1));
		var chosen:Array<Int> = [];
		while (chosen.length < nk && pool.length > 0) {
			var i = draw(w);
			chosen.push(pool[i]);
			pool.splice(i, 1);
			w.splice(i, 1);
		}
		if (chosen.length == 0)
			chosen.push(kinds[0]);
		// (the strongest kinds a few in a level)
		function full(id:Int):Bool {
			var n = 0;
			for (l in list)
				if (l == id)
					n++;
			return switch (id) {
				case Data.BAD_ANANAS: n >= (depth < 20 ? 1 : 2);
				case Data.BAD_FRAMBOISE: n >= (depth < 45 ? 1 : 2);
				case Data.BAD_ABRICOT: n >= 2;
				case Data.BAD_BOMBE: n >= 3;
				default: false;
			}
		}
		// the budget filled turn by turn; a weaker kind when the next one is too strong for what is left
		var i = 0;
		var guard = 0;
		while (list.length < maxBads && sum < budget - 0.5 && guard++ < 60) {
			var id = chosen[i % chosen.length];
			i++;
			if (sum + threat(id) > budget + 0.6 || full(id)) {
				var alt = -1;
				for (c in chosen)
					if (!full(c) && sum + threat(c) <= budget + 0.6 && (alt < 0 || threat(c) < threat(alt)))
						alt = c;
				if (alt < 0)
					break;
				id = alt;
			}
			list.push(id);
			sum += threat(id);
		}
		// all the bads there and some budget left: the weakest ones become stronger ones (of the level, else of the well)
		var strong = [for (k in kinds) if (k != Data.BAD_CERISE && k != Data.BAD_ORANGE && k != Data.BAD_FRAMBOISE) k];
		guard = 0;
		while (sum < budget - 1 && guard++ < 20) {
			var wi = -1;
			for (j in 0...list.length)
				if (list[j] != intro && (wi < 0 || threat(list[j]) < threat(list[wi])))
					wi = j;
			if (wi < 0)
				break;
			var old = list[wi];
			// (a kind of the level first, the strongest that fits)
			var up = -1;
			var upScore = -1.0;
			for (c in chosen.concat(strong)) {
				if (threat(c) <= threat(old) || full(c) || sum - threat(old) + threat(c) > budget + 0.6)
					continue;
				var sc = (chosen.indexOf(c) >= 0 ? 10 : 0) + threat(c);
				if (sc > upScore) {
					up = c;
					upScore = sc;
				}
			}
			if (up < 0)
				break;
			list[wi] = up;
			sum += threat(up) - threat(old);
		}
		// strawberries go by pairs (they pass their ball); one alone deep in the well (it throws it at Igor)
		var fr = 0;
		for (l in list)
			if (l == Data.BAD_FRAISE)
				fr++;
		if (depth < 12 && fr == 1)
			list.push(Data.BAD_FRAISE);
		if (depth >= 12 && fr > 1) {
			// (the others: bads of other kinds the level can hold more of, the weakest of the level first)
			var seen = false;
			for (i in 0...list.length)
				if (list[i] == Data.BAD_FRAISE) {
					if (seen) {
						list[i] = -1;
						var alt = -1;
						var altScore = 1.0e9;
						for (c in chosen.concat(strong)) {
							if (c == Data.BAD_FRAISE || full(c))
								continue;
							var sc = (chosen.indexOf(c) >= 0 ? 0 : 10) + threat(c);
							if (sc < altScore) {
								alt = c;
								altScore = sc;
							}
						}
						list[i] = alt;
					}
					seen = true;
				}
			list = [for (l in list) if (l >= 0) l];
		}
		budgetUsed = 0;
		for (l in list)
			budgetUsed += threat(l);
		return list;
	}

	function placeBads():Bool {
		var list = badList();
		// crawlers on the walls, more and more of them deep in the well
		if (depth >= 6)
			for (i in 0...Std.int(Math.min(2, (depth - 3) / 10 * rhythm(depth))))
				if (chance(0.6))
					list.push(Data.BAD_CRAWLER);
		// the bad met for the first time first (it must be there), then the bigger ones (fewer places for them)
		var intro = introKind(depth);
		list.sort(function(a, b) {
			if ((a == intro) != (b == intro))
				return a == intro ? -1 : 1;
			return minLen(b) != minLen(a) ? minLen(b) - minLen(a) : a - b;
		});

		var segs = [for (s in segments()) if (segReached(s) || segNear(s)) s];
		// (with a laser of black or red bombs on the way, the bads shut between walls can be killed)
		var killer = killerLaser();
		if (!killer && depth >= 3 && chance(0.5)) {
			var shut = false;
			for (s in segs)
				if (!iceEscapes(s))
					shut = true;
			if (shut)
				killer = addKillerLaser();
		}
		var used = [for (s in segs) 0];
		var landY = py;
		while (landY < H - 1 && !canStand(px, landY))
			landY++;
		var topLand = H;
		for (x in 0...W)
			topLand = Std.int(Math.min(topLand, landRow(x)));
		var placed:Array<GPt> = [];
		// a row of bads of the same kind on a long floor (A10, A16, A20): a frozen one kicked into the others kills
		// them all, a combo
		if (depth >= 1 && list.length >= 4 && chance(Math.min(0.45, 0.15 + depth * 0.03))) {
			// (not the bads a level holds a few of)
			var walkers = [for (id in list) if (id != Data.BAD_CRAWLER && id != Data.BAD_FRAISE && id != Data.BAD_ANANAS
				&& id != Data.BAD_FRAMBOISE && id != Data.BAD_ABRICOT && id != Data.BAD_BOMBE) id];
			var cands = [];
			for (k in 0...segs.length) {
				var s = segs[k];
				if (s.x1 - s.x0 + 1 < 7 || isNoBad(s) || spikesNear(s) || (!killer && !iceEscapes(s)) || s.y <= topLand + 1
					|| (Math.abs(s.y - landY) <= 2 && s.x1 >= px - 4 && s.x0 <= px + 4) || (sym && s.x0 + s.x1 != W - 1))
					continue;
				cands.push(k);
			}
			if (walkers.length >= 3 && cands.length > 0) {
				var id = walkers[rnd(walkers.length)];
				var k = cands[rnd(cands.length)];
				var s = segs[k];
				var len = s.x1 - s.x0 + 1;
				var pos:Array<Int> = [];
				if (sym) {
					var g = len >= 12 ? 3 : 2;
					for (j in 0...(len >= 10 ? 2 : 1)) {
						pos.push(s.x0 + 1 + j * g);
						pos.push(s.x1 - 1 - j * g);
					}
				} else {
					var cnt = len >= 10 ? 4 : 3;
					var step = (len - 3) / (cnt - 1);
					for (j in 0...cnt)
						pos.push(s.x0 + 1 + Math.round(j * step));
				}
				var ok = true;
				for (x in pos)
					if (busy[x][s.y] || m[x][s.y] != 0 || Math.abs(x - px) + Math.abs(s.y - landY) < 5)
						ok = false;
				if (ok) {
					for (x in pos) {
						bads.push({id: id, x: x, y: s.y});
						mark(x, s.y);
						placed.push({x: x, y: s.y});
						// (one less of the others: the same kind, else another walker)
						var j = list.indexOf(id);
						if (j < 0)
							for (q in 0...list.length)
								if (j < 0 && walkers.indexOf(list[q]) >= 0)
									j = q;
						if (j >= 0)
							list.splice(j, 1);
					}
					used[k] = 9;
				}
			}
		}
		var i = 0;
		while (i < list.length) {
			var id = list[i];
			var bestK = -1;
			var bestV = -1.0e9;
			for (k in 0...segs.length) {
				var s = segs[k];
				var len = s.x1 - s.x0 + 1;
				if (len < minLen(id) && id != Data.BAD_CRAWLER)
					continue;
				if (used[k] >= (len >= 9 ? 2 : 1))
					continue;
				if (isNoBad(s))
					continue;
				// (no spikes where it starts nor around: it would kill itself at once)
				if (spikesNear(s))
					continue;
				// (frozen there, it can be kicked out of the level: no bad shut in a cup, unless a laser gives the
				// bombs to kill it)
				if (!killer && !iceEscapes(s))
					continue;
				// far from the place where Igor lands at the start
				if (Math.abs(s.y - landY) <= 2 && s.x1 >= px - 4 && s.x0 <= px + 4)
					continue;
				// Igor comes in falling anywhere: no bad on the first ground of the columns of the top, no shooter
				// on its rows
				if (s.y <= topLand + 1 && (shooter(id) || s.y == topLand))
					continue;
				// (crawlers: against a wall of the level, not a side of the screen)
				if (id == Data.BAD_CRAWLER && !(s.x0 > 0 && gr(s.x0 - 1, s.y) && gr(s.x0 - 1, s.y - 1))
					&& !(s.x1 < W - 1 && gr(s.x1 + 1, s.y) && gr(s.x1 + 1, s.y - 1)))
					continue;
				var v = liking(id, s) + rnd(100) / 60;
				// apart from the others
				for (p in placed)
					if (Math.abs(p.y - s.y) <= 1 && p.x >= s.x0 - 3 && p.x <= s.x1 + 3)
						v -= 2;
				v -= used[k] * 2;
				if (v > bestV) {
					bestV = v;
					bestK = k;
				}
			}
			if (bestK < 0) {
				missing++;
				i++;
				continue;
			}
			var s = segs[bestK];
			var x = freeCell(s, id);
			// (5 cases at least from the place where Igor lands at the start)
			if (x >= 0 && Math.abs(x - px) + Math.abs(s.y - landY) < 5) {
				var far = [for (c in s.x0...s.x1 + 1) if (!busy[c][s.y] && m[c][s.y] == 0 && Math.abs(c - px) + Math.abs(s.y - landY) >= 5) c];
				x = far.length > 0 ? far[rnd(far.length)] : -1;
			}
			if (x < 0) {
				missing++;
				used[bestK] = 9;
				continue;
			}
			used[bestK]++;
			bads.push({id: id, x: x, y: s.y});
			mark(x, s.y);
			placed.push({x: x, y: s.y});
			i++;
			// symmetric levels: the same bad at the mirror place
			if (sym && i < list.length && list[i] == id) {
				var mx = W - 1 - x;
				if (mx != x && !busy[mx][s.y] && canStand(mx, s.y)) {
					var mk = -1;
					for (k in 0...segs.length)
						if (segs[k].y == s.y && segs[k].x0 <= mx && segs[k].x1 >= mx)
							mk = k;
					if (mk >= 0 && (mk != bestK || s.x1 - s.x0 + 1 >= 9)) {
						used[mk]++;
						bads.push({id: id, x: mx, y: s.y});
						mark(mx, s.y);
						placed.push({x: mx, y: s.y});
						i++;
					}
				}
			}
		}
		var real = 0;
		var shown = intro < 0;
		for (b in bads) {
			if (b.id != Data.BAD_SPEAR && b.id != Data.BAD_SAW)
				real++;
			if (b.id == intro)
				shown = true;
		}
		return shown && real >= Std.int(Math.min(5, 2 + depth / 3));
	}

	// the cases where the bads go by themselves from where they start (standing there or going through): walking,
	// falling where the fall is safe (they do not jump in the void: World.checkSecureFall), jumping down through their
	// platform, over a hole of 2 cases, up on a platform 3 rows higher, climbing a wall of 3 cases (parseIA)
	function badZone():Array<Array<Bool>> {
		var zone = [for (x in 0...W) [for (y in 0...H) false]];
		var seen = [for (x in 0...W) [for (y in 0...H) false]];
		var q:Array<GPt> = [];
		function stand(x:Int, y:Int):Bool {
			return x >= 0 && x < W && y >= 0 && y + 1 < H && m[x][y] <= 0 && m[x][y + 1] > 0;
		}
		function pass(x:Int, y:Int) {
			if (inb(x, y))
				zone[x][y] = true;
		}
		function add(x:Int, y:Int) {
			if (stand(x, y) && !seen[x][y]) {
				seen[x][y] = true;
				zone[x][y] = true;
				q.push({x: x, y: y});
			}
		}
		// (the first ground under a case, -1 in the void; the cases of the fall marked when it is safe)
		function landing(x:Int, y:Int):Int {
			var y0 = y;
			while (y + 1 < H && !stand(x, y)) {
				if (m[x][y] > 0)
					return -1;
				y++;
			}
			if (!stand(x, y))
				return -1;
			for (k in y0...y)
				pass(x, k);
			return y;
		}
		for (b in bads) {
			if (b.id == Data.BAD_CRAWLER || b.id == Data.BAD_SAW)
				crawlZone(zone, b.x, b.y);
			if (b.id == Data.BAD_SPEAR || b.id == Data.BAD_SAW || b.id == Data.BAD_CRAWLER)
				continue;
			var ly = landing(b.x, b.y);
			if (ly >= 0)
				add(b.x, ly);
		}
		while (q.length > 0) {
			var p = q.pop();
			for (d in [-1, 1]) {
				var nx = p.x + d;
				if (nx < 0 || nx >= W)
					continue;
				if (m[nx][p.y] > 0) {
					// a wall: climbed when it is low
					var h = 0;
					while (p.y - h >= 0 && m[nx][p.y - h] > 0)
						h++;
					if (h <= 3 && stand(nx, p.y - h)) {
						for (k in 1...h + 1)
							pass(p.x, p.y - k);
						add(nx, p.y - h);
					}
					continue;
				}
				if (stand(nx, p.y))
					add(nx, p.y);
				else {
					var ly = landing(nx, p.y);
					if (ly >= 0)
						add(nx, ly);
					if (stand(p.x + 3 * d, p.y) && m[p.x + 2 * d][p.y] <= 0) {
						for (k in 1...3) {
							pass(p.x + k * d, p.y);
							pass(p.x + k * d, p.y - 1);
						}
						add(p.x + 3 * d, p.y);
					}
				}
			}
			// down through a platform of one case, up on a platform 3 rows higher
			if (p.y + 2 < H && m[p.x][p.y + 2] <= 0) {
				var ly = landing(p.x, p.y + 2);
				if (ly >= 0)
					add(p.x, ly);
			}
			if (p.y >= 3 && m[p.x][p.y - 1] <= 0 && m[p.x][p.y - 2] > 0 && m[p.x][p.y - 3] <= 0) {
				pass(p.x, p.y - 1);
				add(p.x, p.y - 3);
			}
		}
		return zone;
	}

	// the crawlers and the saws go all around the ground they hold on to (floors, walls and ceilings: WallWalker): the
	// cases along that piece of ground
	function crawlZone(zone:Array<Array<Bool>>, x0:Int, y0:Int) {
		var seen = [for (x in 0...W) [for (y in 0...H) false]];
		var st:Array<GPt> = [];
		for (dx in -1...2)
			for (dy in -1...2)
				if (inb(x0 + dx, y0 + dy) && m[x0 + dx][y0 + dy] > 0 && !seen[x0 + dx][y0 + dy]) {
					seen[x0 + dx][y0 + dy] = true;
					st.push({x: x0 + dx, y: y0 + dy});
				}
		while (st.length > 0) {
			var c = st.pop();
			for (dx in -1...2)
				for (dy in -1...2) {
					var nx = c.x + dx;
					var ny = c.y + dy;
					if (!inb(nx, ny))
						continue;
					if (m[nx][ny] > 0) {
						if (!seen[nx][ny]) {
							seen[nx][ny] = true;
							st.push({x: nx, y: ny});
						}
					} else
						zone[nx][ny] = true;
				}
		}
	}

	// a case where spikes do not touch a bad going its ways: not on them, nor next to them, nor 2 rows over them (the
	// bads hop: their hits are their boxes)
	function farFromBads(zone:Array<Array<Bool>>, x:Int, y:Int):Bool {
		for (dx in -1...2)
			for (dy in -1...3)
				if (inb(x + dx, y + dy) && zone[x + dx][y + dy])
					return false;
		return true;
	}

	// the spikes on the ways of the bads (where they go by themselves, or next to it) go: they would kill them all one
	// after the other (the hard levels of the original keep the ones next to the ways: the bads die there sometimes)
	function clearBadSpikes(?strict:Bool = true) {
		var zone = badZone();
		var keep = [];
		for (b in bads) {
			if (b.id == Data.BAD_SPEAR) {
				var near = strict ? !farFromBads(zone, b.x, b.y) : zone[b.x][b.y];
				if (near) {
					setDanger({x: b.x, y: b.y}, false);
					continue;
				}
			}
			keep.push(b);
		}
		bads = keep;
		computeReach();
	}

	function segNear(s:GSeg):Bool {
		for (x in s.x0...s.x1 + 1)
			for (dx in -2...3)
				for (dy in -1...2)
					if (inb(x + dx, s.y + dy) && reach[x + dx][s.y + dy])
						return true;
		return false;
	}

	// a case of the map Igor goes through: reached by him, or just under / beside a case he reaches
	function reachedNear(x:Int, y:Int):Bool {
		for (d in [[0, 0], [1, 0], [-1, 0], [0, -1], [1, -1], [-1, -1], [0, 1]])
			if (inb(x + d[0], y + d[1]) && reach[x + d[0]][y + d[1]])
				return true;
		return false;
	}

	// a laser of black bombs (they kill the bads around: Black.onExplode) or red ones (they throw them high) Igor
	// goes through: the bads shut between walls can be killed
	function killerLaser():Bool {
		// (only the black bombs: the red ones do not lift a bad high enough out of a pocket)
		for (x in 0...W)
			for (y in 0...H)
				if (m[x][y] == -2 && reachedNear(x, y))
					return true;
		return false;
	}

	// platforms where the ice of a bad could not be kicked out of the level (pockets between walls, against a side
	// of the screen): the bads walk everywhere, one may be frozen there
	function pockets():Int {
		var n = 0;
		for (sg in segments())
			if ((segReached(sg) || segNear(sg)) && !iceEscapes(sg))
				n++;
		return n;
	}

	// with pockets: first a hole at an end of their floor (the ice falls there), else a laser of black bombs on the
	// way of Igor (one is made), else the level is not kept
	function pocketsOk():Bool {
		var before = pockets();
		repairPockets();
		var after = pockets();
		#if gentest
		if (before > 0)
			fail(after == 0 ? "pocketRepaired" : (killerLaser() ? "pocketHasBlack" : "pocketNeedsBlack"));
		#end
		if (after == 0 || killerLaser())
			return true;
		return addKillerLaser() && killerLaser();
	}

	function repairPockets() {
		for (pass in 0...4) {
			var found = false;
			for (sg in segments()) {
				if (!(segReached(sg) || segNear(sg)) || iceEscapes(sg))
					continue;
				found = true;
				var fy = sg.y + 1;
				for (x in [sg.x0, sg.x1]) {
					// a floor one case thick, nobody standing there
					if (fy >= H || m[x][fy] <= 0 || (fy + 1 < H && m[x][fy + 1] > 0) || busy[x][sg.y])
						continue;
					var v = m[x][fy];
					m[x][fy] = 0;
					if (sym && W - 1 - x != x && m[W - 1 - x][fy] == v)
						m[W - 1 - x][fy] = 0;
					computeReach();
					if (exitOk && startOk() && openColumns() == 0 && iceEscapes({y: sg.y, x0: sg.x0, x1: sg.x1}))
						break;
					m[x][fy] = v;
					if (sym && W - 1 - x != x && m[W - 1 - x][fy] == 0)
						m[W - 1 - x][fy] = v;
					computeReach();
				}
			}
			if (!found)
				break;
		}
	}

	// every laser as World.drawFields draws it (the runs of a same id, across first) held at both ends by the ground,
	// another laser or the side of the screen: no laser floating, no door of two columns drawn as two bars across
	function fieldsHeld():Bool {
		var done = [for (x in 0...W) [for (y in 0...H) false]];
		for (y in 0...H)
			for (x in 0...W) {
				var id = m[x][y];
				if (id >= 0 || done[x][y])
					continue;
				if (x + 1 < W && m[x + 1][y] == id) {
					var i = x;
					while (i < W && m[i][y] == id)
						done[i++][y] = true;
					if (!heldAt(x - 1, y) || !heldAt(i, y))
						return false;
				} else {
					var i = y;
					while (i < H && m[x][i] == id)
						done[x][i++] = true;
					if (!heldAt(x, y - 1) || !heldAt(x, i))
						return false;
				}
			}
		return true;
	}

	inline function heldAt(x:Int, y:Int):Bool {
		return !inb(x, y) || m[x][y] != 0;
	}

	// one more: a laser of the level Igor goes through turns black, else a black laser in a hole or a door on his way
	function addKillerLaser():Bool {
		var runs = [];
		for (x in 0...W)
			for (y in 0...H) {
				var v = m[x][y];
				if (v < 0 && v >= -5 && v != -2 && reachedNear(x, y))
					runs.push({x: x, y: y, v: v});
			}
		if (runs.length > 0) {
			var r = runs[rnd(runs.length)];
			// the whole run of this laser (and its mirror)
			var st = [{x: r.x, y: r.y}];
			var seen = [for (x in 0...W) [for (y in 0...H) false]];
			while (st.length > 0) {
				var c = st.pop();
				if (!inb(c.x, c.y) || seen[c.x][c.y] || m[c.x][c.y] != r.v)
					continue;
				seen[c.x][c.y] = true;
				m[c.x][c.y] = -2;
				if (sym && m[W - 1 - c.x][c.y] == r.v)
					st.push({x: W - 1 - c.x, y: c.y});
				st.push({x: c.x + 1, y: c.y});
				st.push({x: c.x - 1, y: c.y});
				st.push({x: c.x, y: c.y + 1});
				st.push({x: c.x, y: c.y - 1});
			}
			return true;
		}
		return addGates(-2);
	}

	// the platform where a bad placed at (x, y) lands
	function segmentOf(x:Int, y:Int):GSeg {
		var ly = y;
		while (ly < H - 1 && !canStand(x, ly)) {
			if (!passable(x, ly))
				return null;
			ly++;
		}
		if (!canStand(x, ly))
			return null;
		var x0 = x;
		var x1 = x;
		while (x0 > 0 && canStand(x0 - 1, ly))
			x0--;
		while (x1 < W - 1 && canStand(x1 + 1, ly))
			x1++;
		return {y: ly, x0: x0, x1: x1};
	}

	function spikeAt(x:Int, y:Int):Bool {
		for (b in bads)
			if (b.id == Data.BAD_SPEAR && b.x == x && b.y == y)
				return true;
		return false;
	}

	// a bad frozen on this platform can be killed: its ice, kicked by Igor from a side he reaches, slides along the
	// platforms, stops against the walls (kicked back from there), falls off their edges onto lower ones, and ends out
	// of the level or on spikes (Bad.onDeathLine, Spear.hit). Its bombs hardly lift it (shockWave: 5 pixels up when
	// on the ground): a bad shut between walls cannot be killed
	function iceEscapes(s:GSeg):Bool {
		var seen = [for (x in 0...W) [for (y in 0...H) false]];
		var q:Array<GPt> = [for (x in s.x0...s.x1 + 1) {x: x, y: s.y}];
		var guard = 0;
		while (q.length > 0 && guard < 500) {
			guard++;
			var p = q.pop();
			if (seen[p.x][p.y])
				continue;
			seen[p.x][p.y] = true;
			for (d in [-1, 1]) {
				var kx = p.x - d;
				if (!(inb(kx, p.y) && reach[kx][p.y]) && !reach[p.x][p.y])
					continue;
				var x = p.x;
				var y = p.y;
				while (true) {
					var nx = x + d;
					if (nx < 0 || nx >= W || m[nx][y] > 0) {
						// against a wall (or a side of the screen): it stops there
						q.push({x: x, y: y});
						break;
					}
					if (spikeAt(nx, y))
						return true;
					if (y + 1 < H && m[nx][y + 1] > 0) {
						x = nx;
						continue;
					}
					// off the edge: it falls
					var fy = y;
					while (fy + 1 < H && m[nx][fy + 1] <= 0) {
						fy++;
						if (spikeAt(nx, fy))
							return true;
					}
					if (fy + 1 >= H)
						return true;
					q.push({x: nx, y: fy});
					break;
				}
			}
		}
		return false;
	}

	function spikesNear(s:GSeg):Bool {
		for (b in bads)
			if (b.id == Data.BAD_SPEAR && b.y >= s.y - 2 && b.y <= s.y + 1 && b.x >= s.x0 - 2 && b.x <= s.x1 + 2)
				return true;
		return false;
	}

	function isNoBad(s:GSeg):Bool {
		for (n in noBads)
			if (n.y == s.y && n.x0 <= s.x1 && n.x1 >= s.x0)
				return true;
		return false;
	}

	// a free case of a segment for a bad (the middle of the small ones)
	function freeCell(s:GSeg, id:Int):Int {
		var len = s.x1 - s.x0 + 1;
		var c = [for (x in s.x0...s.x1 + 1) if (!busy[x][s.y] && !busy[x][s.y - 1 >= 0 ? s.y - 1 : 0] && m[x][s.y] == 0) x];
		if (c.length == 0)
			return -1;
		if (len <= 4)
			return c[Std.int(c.length / 2)];
		return c[rnd(c.length)];
	}

	// places of the items: on platforms reached by Igor, apart from each other
	function placeItems() {
		var segs = [for (s in segments()) if (segReached(s)) s];
		var cells:Array<GPt> = [];
		for (s in segs)
			for (x in s.x0...s.x1 + 1)
				if (!busy[x][s.y] && reach[x][s.y] && (Math.abs(x - px) + Math.abs(s.y - py) > 4))
					cells.push({x: x, y: s.y});
		for (k in 0...5) {
			if (cells.length == 0)
				break;
			var p = cells.splice(rnd(cells.length), 1)[0];
			if (k < 2)
				special.push(p);
			else
				scores.push(p);
			cells = [for (c in cells) if (Math.abs(c.x - p.x) + Math.abs(c.y - p.y) > 4) c];
		}
	}

	// holes in a floor (4 cases at most) with a ground just over them or over their edges: the bads jumping over them
	// hit it and fall
	function blockedGaps():Int {
		var n = 0;
		for (y in 2...H) {
			var x = 1;
			while (x < W) {
				if (m[x][y] <= 0 && m[x - 1][y] > 0 && m[x - 1][y - 1] <= 0) {
					var g0 = x;
					while (x < W && m[x][y] <= 0)
						x++;
					if (x < W && x - g0 <= 4 && m[x][y - 1] <= 0) {
						for (c in g0 - 1...x + 1)
							if (gr(c, y - 2) || (c >= g0 && c < x && gr(c, y - 1)))
								{
									n++;
									break;
								}
					}
				} else
					x++;
			}
		}
		return n;
	}

	// part of the reached segments from which Igor can go back to the segment of the start
	function wayBack():Float {
		var segs = [for (s in segments()) if (segReached(s)) s];
		if (segs.length == 0)
			return 0;
		var sx = px;
		var sy = py;
		while (sy < H - 1 && !canStand(sx, sy))
			sy++;
		var ok = 0;
		buildMoves();
		for (s in segs) {
			reachFrom(s.x0, s.y);
			if (reach[sx][sy])
				ok++;
		}
		computeReach();
		return ok / segs.length;
	}

	// ---------------------------------------------------------------- hard levels: real hard levels remade

	// a hard level of the original (HardData: Diffiland, the Hells, Metal hurlant, the Crypt...) near the difficulty
	// aimed, not met yet in this game, remade for the well: 18 rows (the empty rows under the last floor, over the
	// first one and in the middle beyond 2, the rows repeating the one over them), 18 columns (the column of each half
	// changing the level the least), mirrored or made symmetric from one of its halves, its bads of other kinds for
	// the depth (one strawberry), no spikes where a bad starts; the cases its script opens at the end kept
	public var openAtEnd:Array<GPt> = [];
	var entry:Array<Bool> = [];

	// the columns where Igor coming in falling from the top (where he left the level above) lands with every bad and
	// the way down reachable: he is moved to the nearest one (Game.safeEntry)
	function entryColumns():Array<Bool> {
		var spx = px;
		var spy = py;
		var out = [];
		buildMoves();
		for (x in 0...W) {
			px = x;
			py = 0;
			var ok = startOk();
			if (ok) {
				reachFrom(x, 0);
				ok = exitOk || openAtEnd.length > 0;
				if (ok)
					for (b in bads) {
						if (b.id == Data.BAD_SPEAR || b.id == Data.BAD_SAW)
							continue;
						var near = false;
						for (dx in -2...3)
							for (dy in -2...4)
								if (inb(b.x + dx, b.y + dy) && reach[b.x + dx][b.y + dy])
									near = true;
						if (!near) {
							ok = false;
							break;
						}
					}
			}
			out.push(ok);
		}
		px = spx;
		py = spy;
		computeReach();
		return out;
	}

	function entryCount():Int {
		var n = 0;
		for (e in entry)
			if (e)
				n++;
		return n;
	}
	public var srcId:Int = -1;

	static var usedHard:Array<Bool> = [];

	// test harness: the source of the first level
	public static var forceSrc:Int = -1;

	static inline var SW = 20; // width of the levels of the original

	static function cellOf(c:Int):Int {
		return c == "#".code ? 1 : (c == ".".code ? 0 : -(c - "a".code + 1));
	}

	function buildRemix(target:Float):Bool {
		clear();
		kind = "remix";
		sym = false;
		var all = HardData.LEVELS;
		var cands:Array<Int> = [];
		var win = 0.05;
		while (cands.length < 4 && win < 1.5) {
			cands = [for (i in 0...all.length) if (usedHard[i] != true && Math.abs(all[i].d - target) <= win) i];
			win *= 1.5;
		}
		if (cands.length == 0)
			cands = [for (i in 0...all.length) i];
		srcId = forceSrc >= 0 ? forceSrc : cands[rnd(cands.length)];
		var src = all[srcId];
		var sh = src.h;
		var g = [for (x in 0...SW) [for (y in 0...sh) cellOf(src.m.charCodeAt(y * SW + x))]];
		var sb:Array<{id:Int, x:Int, y:Int}> = [];
		for (b in src.b.split(",")) {
			var a = b.split(":");
			sb.push({id: Std.parseInt(a[0]), x: Std.parseInt(a[1]), y: Std.parseInt(a[2])});
		}
		var pa = src.p.split(":");
		var sp = {x: Std.parseInt(pa[0]), y: Std.parseInt(pa[1])};
		var se:Array<GPt> = [];
		if (src.e != "")
			for (e in src.e.split(",")) {
				var a = e.split(":");
				se.push({x: Std.parseInt(a[0]), y: Std.parseInt(a[1])});
			}
		// rows and columns holding something that must stay: bads, start, cases opened at the end
		var prow = [for (y in 0...sh) false];
		var pcol = [for (x in 0...SW) false];
		function protect(x:Int, y:Int) {
			if (y >= 0 && y < sh)
				prow[y] = true;
			if (x >= 0 && x < SW)
				pcol[x] = true;
		}
		for (b in sb)
			protect(b.x, b.y);
		protect(sp.x, sp.y);
		for (e in se)
			protect(e.x, e.y);

		// ---- rows
		var rows = [for (y in 0...sh) y];
		function rowEmpty(y:Int):Bool {
			if (y < 0)
				return true;
			if (prow[y])
				return false;
			for (x in 0...SW)
				if (g[x][y] != 0)
					return false;
			return true;
		}
		function rowSame(a:Int, b:Int):Bool {
			if (a < 0 || b < 0)
				return false;
			for (x in 0...SW)
				if (g[x][a] != g[x][b])
					return false;
			return true;
		}
		while (rows.length > H) {
			var k = -1;
			var last = rows.length - 1;
			// empty rows under the last floor (the void)
			if (rowEmpty(rows[last]))
				k = last;
			// empty rows over the first floor, beyond 2
			if (k < 0 && rowEmpty(rows[0]) && rowEmpty(rows[1]) && rowEmpty(rows[2]))
				k = 0;
			// a run of 3 empty rows: 2 are enough for Igor
			if (k < 0)
				for (i in 1...rows.length - 1)
					if (rowEmpty(rows[i - 1]) && rowEmpty(rows[i]) && rowEmpty(rows[i + 1])) {
						k = i;
						break;
					}
			// a row of thick walls repeating the one over it
			if (k < 0)
				for (i in 1...rows.length)
					if (!prow[rows[i]] && !rowEmpty(rows[i]) && rowSame(rows[i], rows[i - 1])) {
						k = i;
						break;
					}
			if (k < 0)
				break;
			rows.splice(k, 1);
		}
		// still too high: some gaps of 2 rows down to 1 (the sprites go under the ceilings), 3 at most
		var squeezed = 0;
		while (rows.length > H && squeezed < 3) {
			var k = -1;
			for (i in 1...rows.length - 2)
				if (!rowEmpty(rows[i - 1]) && rowEmpty(rows[i]) && rowEmpty(rows[i + 1]) && !rowEmpty(rows[i + 2])) {
					k = i;
					break;
				}
			if (k < 0)
				break;
			rows.splice(k, 1);
			squeezed++;
		}
		// then the 18 rows keeping the most bads, the bottom first (the way down)
		if (rows.length > H) {
			var bestA = rows.length - H;
			var bestN = -1;
			var a = rows.length - H;
			while (a >= 0) {
				var n = 0;
				for (i in a...a + H)
					if (rows[i] >= 0 && prow[rows[i]])
						n++;
				if (n > bestN) {
					bestN = n;
					bestA = a;
				}
				a--;
			}
			var lost = 0;
			for (i in 0...rows.length)
				if ((i < bestA || i >= bestA + H) && rows[i] >= 0 && prow[rows[i]])
					lost++;
			if (lost > 3)
				return fail("high");
			rows = rows.slice(bestA, bestA + H);
		}
		while (rows.length < H)
			rows.unshift(-1);

		// ---- columns: one of each half, the one whose loss changes the level the least
		function colCost(x:Int):Float {
			if (pcol[x])
				return 1000;
			var c = 0.0;
			for (y in rows) {
				if (y < 0)
					continue;
				var v = g[x][y];
				if (v < 0)
					c += 40;
				var l = x > 0 ? g[x - 1][y] : v;
				var r = x < SW - 1 ? g[x + 1][y] : v;
				if (v != l && v != r)
					c += 1;
			}
			return c;
		}
		var cost = [for (x in 0...SW) colCost(x)];
		var c1 = 0;
		var c2 = SW - 1;
		for (x in 0...10)
			if (cost[x] < cost[c1])
				c1 = x;
		for (x in 10...SW)
			if (cost[x] < cost[c2])
				c2 = x;
		// (the mirror columns when they cost about the same: a symmetric level stays symmetric)
		var bestPair = 0;
		for (x in 0...10)
			if (cost[x] + cost[SW - 1 - x] < cost[bestPair] + cost[SW - 1 - bestPair])
				bestPair = x;
		if (cost[bestPair] + cost[SW - 1 - bestPair] <= cost[c1] + cost[c2] + 2) {
			c1 = bestPair;
			c2 = SW - 1 - bestPair;
		}
		var cols = [for (x in 0...SW) if (x != c1 && x != c2) x];
		function mx(x:Int):Int {
			var best = 0;
			var bd = 99;
			for (i in 0...cols.length) {
				var d = Std.int(Math.abs(cols[i] - x));
				if (d < bd) {
					bd = d;
					best = i;
				}
			}
			return best;
		}
		function my(y:Int):Int {
			var best = 0;
			var bd = 99;
			for (i in 0...rows.length) {
				if (rows[i] < 0)
					continue;
				var d = Std.int(Math.abs(rows[i] - y));
				if (d < bd) {
					bd = d;
					best = i;
				}
			}
			// (a bad over the top of the source)
			if (y < 0)
				best = Std.int(Math.max(0, best + y));
			return best;
		}

		// ---- the level: mirrored one time out of two
		var mirror = chance(0.5);
		function tx(x:Int):Int {
			return mirror ? W - 1 - x : x;
		}
		for (y in 0...H)
			for (i in 0...W)
				m[tx(i)][y] = rows[y] < 0 ? 0 : g[cols[i]][rows[y]];
		// (what was in the rows cut off goes)
		var nb:Array<{id:Int, x:Int, y:Int}> = [for (b in sb) if (rows.indexOf(b.y) >= 0) {id: b.id, x: tx(mx(b.x)), y: my(b.y)}];
		px = tx(mx(sp.x));
		py = rows.indexOf(sp.y) >= 0 ? my(sp.y) : -1;
		for (e in se)
			if (rows.indexOf(e.y) >= 0)
				openAtEnd.push({x: tx(mx(e.x)), y: my(e.y)});

		// ---- sometimes symmetric: one half and its mirror
		var leftBads = 0;
		for (b in nb)
			if (b.x < HALF && b.id != Data.BAD_SPEAR && b.id != Data.BAD_SAW)
				leftBads++;
		if (openAtEnd.length == 0 && leftBads >= 2 && chance(0.25)) {
			sym = true;
			for (y in 0...H)
				for (x in 0...HALF)
					m[W - 1 - x][y] = m[x][y];
			var half = [for (b in nb) if (b.x < HALF) b];
			nb = half.copy();
			for (b in half)
				if (W - 1 - b.x != b.x)
					nb.push({id: b.id, x: W - 1 - b.x, y: b.y});
			if (px >= HALF)
				px = W - 1 - px;
		}

		// ---- bads of the depth: the kinds unlocked, one strawberry, a few of another kind (the raspberries too)
		var kinds = unlocked();
		var hard = [for (k in kinds) if ((k != Data.BAD_CERISE && k != Data.BAD_ORANGE) || kinds.length <= 4) k];
		var fruits = 0;
		var maxFruits = Std.int(Math.min(10, 4 + depth * 0.5));
		var fraise = 0;
		var framb = 0;
		var out:Array<{id:Int, x:Int, y:Int}> = [];
		for (b in nb) {
			var id = b.id;
			if (id == Data.BAD_SPEAR || id == Data.BAD_SAW || id == Data.BAD_CRAWLER) {
				out.push({id: id, x: b.x, y: b.y});
				continue;
			}
			if (id == Data.BAD_LITCHI_WEAK)
				id = Data.BAD_LITCHI;
			if ((kinds.indexOf(id) < 0 && id != Data.BAD_ABRICOT2) || chance(0.2))
				id = hard[draw([for (k in hard) Std.int(100 * Math.pow(threat(k), depth / 15) * rarity(k))])];
			if (id == Data.BAD_FRAMBOISE) {
				framb++;
				if (framb > (depth < 45 ? 1 : 2))
					id = Data.BAD_LITCHI;
			}
			if (id == Data.BAD_FRAISE) {
				fraise++;
				if (fraise > 1) {
					var others = [for (k in hard) if (k != Data.BAD_FRAISE && k != Data.BAD_FRAMBOISE) k];
					id = others[rnd(others.length)];
				}
			}
			out.push({id: id, x: b.x, y: b.y});
			fruits++;
		}
		// too many for the depth: some go
		while (fruits > maxFruits) {
			var f = [for (i in 0...out.length) if (out[i].id != Data.BAD_SPEAR && out[i].id != Data.BAD_SAW && out[i].id != Data.BAD_CRAWLER) i];
			out.splice(f[rnd(f.length)], 1);
			fruits--;
		}
		bads = out;

		// ---- teleporters without any other one of their kind: a laser instead (it stays between its grounds)
		findTeleporters();
		for (r in 0...teleRuns.length)
			if (teleTo[r].length == 0)
				for (c in teleRuns[r].cells)
					m[c.x][c.y] = -1 - rnd(5);

		// ---- spikes: none where a bad starts nor around (it would kill itself at once)
		var spikes = [for (b in bads) if (b.id == Data.BAD_SPEAR) b];
		var keep = [];
		for (sk in spikes) {
			var near = false;
			for (b in bads) {
				if (b.id == Data.BAD_SPEAR || b.id == Data.BAD_SAW)
					continue;
				var ly = b.y;
				while (ly < H - 1 && !(m[b.x][ly] <= 0 && ly + 1 < H && m[b.x][ly + 1] > 0))
					ly++;
				// its platform: the cases it walks on, and 2 cases around
				var x0 = b.x;
				var x1 = b.x;
				while (x0 > 0 && m[x0 - 1][ly] <= 0 && ly + 1 < H && m[x0 - 1][ly + 1] > 0)
					x0--;
				while (x1 < W - 1 && m[x1 + 1][ly] <= 0 && ly + 1 < H && m[x1 + 1][ly + 1] > 0)
					x1++;
				if (sk.y >= ly - 2 && sk.y <= ly + 1 && sk.x >= x0 - 2 && sk.x <= x1 + 2)
					near = true;
			}
			if (!near)
				keep.push(sk);
		}
		bads = [for (b in bads) if (b.id != Data.BAD_SPEAR) b].concat(keep);
		for (b in bads)
			if (b.id == Data.BAD_SPEAR)
				setDanger({x: b.x, y: b.y}, true);

		// ---- Igor: his start, or the best place at the top
		if (py < 0 || py >= H || !startOk())
			if (!placeStart())
				return fail("start");
		var landY = py;
		while (landY < H - 1 && !canStand(px, landY))
			landY++;
		// (the bads where Igor lands at the start go)
		bads = [for (b in bads) if (b.id == Data.BAD_SPEAR || b.id == Data.BAD_SAW || Math.abs(b.x - px) + Math.abs(b.y - landY) >= 4) b];

		// ---- the bottom can be reached (when the level is clear for some of them), every bad too
		computeReach();
		if (!exitOk && openAtEnd.length > 0) {
			var saved = [for (o in openAtEnd) m[o.x][o.y]];
			for (o in openAtEnd)
				m[o.x][o.y] = 0;
			computeReach();
			for (i in 0...openAtEnd.length)
				m[openAtEnd[i].x][openAtEnd[i].y] = saved[i];
			var ok = exitOk;
			computeReach();
			exitOk = ok;
		}
		if (!exitOk)
			return fail("exit");
		// the bads Igor cannot reach go (2 at most), and the ones he could not kill (their ice cannot leave the
		// level: shut in a cup...); others come to have enough of them for the depth
		var gone = 0;
		var shut = 0;
		var kept = [];
		var killer = killerLaser();
		var killerTried = false;
		for (b in bads) {
			if (b.id == Data.BAD_SPEAR || b.id == Data.BAD_SAW) {
				kept.push(b);
				continue;
			}
			var near = false;
			for (dx in -2...3)
				for (dy in -2...4)
					if (inb(b.x + dx, b.y + dy) && reach[b.x + dx][b.y + dy])
						near = true;
			if (!near) {
				gone++;
				continue;
			}
			if (b.id != Data.BAD_CRAWLER) {
				var sg = segmentOf(b.x, b.y);
				if (sg != null && !iceEscapes(sg) && !killer && !killerTried) {
					// (the original kills it with the bombs of a laser: one of its lasers gets black)
					killerTried = true;
					killer = addKillerLaser();
				}
				if (sg == null || (!killer && !iceEscapes(sg))) {
					shut++;
					continue;
				}
			}
			kept.push(b);
		}
		if (gone > 2 || shut > 4)
			return fail("reach");
		bads = kept;
		for (b in bads)
			mark(b.x, b.y);
		var n = 0;
		for (b in bads)
			if (b.id != Data.BAD_SPEAR && b.id != Data.BAD_SAW)
				n++;
		var minFruits = Std.int(Math.min(8, 4 + depth * 0.3));
		if (n < minFruits)
			addFruits(minFruits - n, hard, landY);
		n = 0;
		for (b in bads)
			if (b.id != Data.BAD_SPEAR && b.id != Data.BAD_SAW)
				n++;
		if (n < Std.int(Math.min(5, 3 + depth / 6)))
			return fail("few");
		clearBadSpikes(false);
		if (!pocketsOk())
			return fail("pocket");
		if (!fieldsHeld())
			return fail("loose");
		placeItems();
		entry = entryColumns();
		if (entryCount() < 3)
			return fail("entry");
		return true;
	}

	// more bads on free platforms reached by Igor, apart from the others, not near spikes nor where Igor lands
	function addFruits(n:Int, kinds:Array<Int>, landY:Int) {
		var segs = [for (s in segments()) if (segReached(s) && !spikesNear(s) && !(Math.abs(s.y - landY) <= 2 && s.x1 >= px - 4 && s.x0 <= px + 4)
			&& iceEscapes(s)) s];
		var fraise = 0;
		for (b in bads)
			if (b.id == Data.BAD_FRAISE)
				fraise++;
		for (k in 0...n) {
			var best:GSeg = null;
			var bestV = -1.0e9;
			for (s in segs) {
				var v = (s.x1 - s.x0) * 0.3 + rnd(100) / 50;
				for (b in bads)
					if (Math.abs(b.y - s.y) <= 1 && b.x >= s.x0 - 3 && b.x <= s.x1 + 3)
						v -= 3;
				if (v > bestV) {
					bestV = v;
					best = s;
				}
			}
			if (best == null)
				return;
			var c = [for (x in best.x0...best.x1 + 1) if (!busy[x][best.y] && m[x][best.y] == 0) x];
			if (c.length == 0) {
				segs.remove(best);
				continue;
			}
			var id = kinds[rnd(kinds.length)];
			if (id == Data.BAD_FRAISE && fraise > 0)
				id = kinds[0] == Data.BAD_FRAISE && kinds.length > 1 ? kinds[1] : kinds[0];
			if (id == Data.BAD_FRAISE)
				fraise++;
			var x = c[rnd(c.length)];
			bads.push({id: id, x: x, y: best.y});
			mark(x, best.y);
			segs.remove(best);
		}
	}


	// ---------------------------------------------------------------- quality of a level

	function rate():Float {
		var segs = segments();
		var reached = 0;
		for (s in segs)
			if (segReached(s))
				reached++;
		var r = 0.0;
		r += 4.0 * reached / Math.max(1, segs.length);
		if (segs.length >= 7 && segs.length <= 24)
			r += 1;
		// open places (cases 4 cases away from any ground): the levels of the original gather their ground in a few
		// shapes and leave 5 to 10 % of the screen open, not a dust of pieces all over it
		var empty = 0;
		for (x in 0...W)
			for (y in 2...H) {
				var near = false;
				for (dx in -3...4)
					for (dy in -3...4)
						if (inb(x + dx, y + dy) && m[x + dx][y + dy] != 0)
							near = true;
				if (!near)
					empty++;
			}
		var ef = empty / (W * (H - 2));
		r += ef <= 0.08 ? ef * 30 : 2.4 - (ef - 0.08) * 15;
		r -= missing * 1.2;
		// the bads jump over the holes of the floors: nothing just over them
		r -= blockedGaps() * 2.5;
		// Igor can go back up to the top from most of the places
		r += 2.0 * wayBack();
		// coming in falling from anywhere, Igor can play
		r += 2.0 * entryCount() / W;
		// better without pockets (their bads killed only with the bombs of a black laser)
		r -= pockets() * 1.0;
		// the bads apart from each other
		var bl = [for (b in bads) if (b.id != Data.BAD_SPEAR) b];
		var sum = 0.0;
		for (a in bl) {
			var dm = 99.0;
			for (b in bl)
				if (a != b)
					dm = Math.min(dm, Math.abs(a.x - b.x) + Math.abs(a.y - b.y));
			sum += Math.min(dm, 6);
		}
		if (bl.length > 0)
			r += sum / bl.length * 0.3;
		// long floors (the combos: a frozen bad kicked along one into the others), not a dust of small pieces
		var longs = 0;
		for (s in segs)
			if (s.x1 - s.x0 + 1 >= 6)
				longs++;
		r += Math.min(4, longs) * 0.35;
		r -= Math.max(0, loosePieces() - 2) * 0.5;
		// a row of spikes on the way of Igor from level 6 (they take a little of the ways: not a reason to drop them;
		// the original has them in a quarter of its levels)
		if (depth >= 6) {
			var sp = 0;
			for (b in bads)
				if (b.id == Data.BAD_SPEAR)
					sp++;
			if (sp > 0)
				r += 1.5;
		}
		return r + rnd(100) / 200;
	}

	// small pieces of ground alone in the air (1 or 2 cases, not the steps of a diagonal): the noise of a level
	function loosePieces():Int {
		var comp = [for (x in 0...W) [for (y in 0...H) -1]];
		var size:Array<Int> = [];
		for (x in 0...W)
			for (y in 0...H) {
				if (m[x][y] <= 0 || comp[x][y] >= 0)
					continue;
				var id = size.length;
				var n = 0;
				var st = [x * H + y];
				comp[x][y] = id;
				while (st.length > 0) {
					var c = st.pop();
					var cx = Std.int(c / H);
					var cy = c % H;
					n++;
					for (d in [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
						var nx = cx + d[0];
						var ny = cy + d[1];
						if (inb(nx, ny) && m[nx][ny] > 0 && comp[nx][ny] < 0) {
							comp[nx][ny] = id;
							st.push(nx * H + ny);
						}
					}
				}
				size.push(n);
			}
		var loose = 0;
		var counted = [for (i in 0...size.length) false];
		for (x in 0...W)
			for (y in 0...H) {
				var id = comp[x][y];
				if (id < 0 || size[id] > 2 || counted[id])
					continue;
				var step = false;
				for (dx in [-1, 1])
					for (dy in [-1, 1])
						if (inb(x + dx, y + dy) && comp[x + dx][y + dy] >= 0 && comp[x + dx][y + dy] != id)
							step = true;
				if (step)
					continue;
				// (both cases of a piece of 2 checked before it is counted)
				var other = -1;
				for (d in [[1, 0], [0, 1]])
					if (inb(x + d[0], y + d[1]) && comp[x + d[0]][y + d[1]] == id)
						other = (x + d[0]) * H + y + d[1];
				if (other >= 0) {
					var ox = Std.int(other / H);
					var oy = other % H;
					for (dx in [-1, 1])
						for (dy in [-1, 1])
							if (inb(ox + dx, oy + dy) && comp[ox + dx][oy + dy] >= 0 && comp[ox + dx][oy + dy] != id)
								step = true;
				}
				counted[id] = true;
				if (!step)
					loose++;
			}
		return loose;
	}
}
