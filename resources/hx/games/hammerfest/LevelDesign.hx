package hammerfest;

import hammerfest.LevelGen.GPt;

// a zone of a level: its columns and rows, its side (-1: against the left side of the screen, 1: the right one, 0: in
// the middle of the level, 2: the whole width)
typedef DZone = {x0:Int, x1:Int, y0:Int, y1:Int, side:Int};

// the plan of a level: how its field is shared between zones (its layout), the motif of its main zone and the motif of
// its other zones, mirrored or not
typedef DPlan = {layout:String, main:String, other:String, sym:Bool, ?piece:String, ?open:Bool, ?concept:String};

// a cellar of the bottom, reached only by a teleporter (LevelDesign.cellar, LevelFeatures.closeTele): its inside
// (standing row y, columns x0..x1), its teleporter, the bads drawn for it, the box of its walls and its roof
typedef DClose = {x0:Int, x1:Int, y:Int, tele:Int, spots:Array<{id:Int, x:Int, y:Int}>, box:{x0:Int, x1:Int, y0:Int, y1:Int}};

// The levels drawn like the levels of the original are drawn: thin lines, every platform of a level of one length, its
// floors on one rhythm (every 3 rows from the bottom: Igor jumps 3 rows up, he can always climb back from the bottom),
// mirrored more often than not, and never a small piece alone (no case alone, no stub of one case on a wall or under a
// platform: they read as rubble in the tiles of the original).
// A level is composed: its field is shared between zones (the whole field; the middle and the sides; a band over a
// band; three columns; two halves) and each zone gets a motif of the original: a lattice of platforms, a tree, spines
// with their rungs, arches, pillars, stalactites, a box and what it holds, stairs, a building of rooms; the sides get
// ledges, a comb, a column of rungs. The same motif never makes the same level twice (its zone, its neighbours and its
// variant change), and a motif does not come back before several levels (plan: the motifs of the last levels).
// The motifs are chosen for the bads of the level, the leading kind above all: sheltered ledges on both sides for the
// strawberries, high branches over the air for the pears, shafts for the lemons, wide floors for the pineapple...
// The doors and holes the motifs leave are the places of the lasers (LevelFeatures).
@:access(hammerfest.LevelGen)
class LevelDesign {
	static inline var W = Data.LEVEL_WIDTH;
	static inline var H = Data.LEVEL_HEIGHT;
	static inline var B = Data.LEVEL_HEIGHT - 1;

	public static var LAYOUTS = ["full", "center", "bands", "three", "pair", "split"];

	// the motifs the main zone of each layout can take (the bottom band of "bands", the left half of "pair")
	static var MAINS:Map<String, Array<String>> = [
		"full" => ["lattice", "tree", "spines", "arches", "stairs", "box", "rooms", "hooks", "ladder"],
		"center" => ["tree", "spines", "box", "lattice", "arches", "rooms", "mound", "ladder"],
		"bands" => ["pillars", "lattice", "arches", "rooms", "stairs", "spines", "box", "mound"],
		"three" => ["tree", "lattice", "pillars"],
		"pair" => ["spines", "lattice", "box", "stairs", "rooms", "pillars", "mound"],
		"split" => ["spines", "lattice", "box", "stairs", "rooms", "pillars", "mound"]
	];

	// the motifs its other zones can take (the sides, the top band, the right half)
	static var OTHERS:Map<String, Array<String>> = [
		"full" => [""],
		"center" => ["ledges", "comb", "stack"],
		"bands" => ["hooks", "arches", "lattice", "tree"],
		"three" => ["comb", "ledges", "lattice"],
		"pair" => ["spines", "lattice", "box", "stairs", "rooms", "pillars", "comb"],
		"split" => ["spines", "lattice", "box", "stairs", "rooms", "pillars", "comb"]
	];

	// the rows where Igor stands at the start of a game (LevelGen.placeStart: the first level)
	public static inline var START_Y0 = 7;
	public static inline var START_Y1 = 11;

	var g:LevelGen;
	var m:Array<Array<Int>>;
	var sym:Bool;
	var thePlan:DPlan;

	// the passages the motifs made for a laser (the gap in the top of a box, the middle of a bridge, a hole in a
	// ceiling, the gap between two arches, a hole in a floor of a room): LevelFeatures prefers them
	public var gates:Array<Array<GPt>> = [];
	public var variant:String = "";

	// the style of the level: rows between its floors, length of its platforms, the first levels of a game lighter,
	// the levels with many bads denser
	var step:Int = 3;
	var unit:Int = 3;
	var light:Bool = false;
	var dense:Bool = false;
	// (the bottom left open over the void)
	var open:Bool = false;
	// (1 at the start of a game, 0 from level 7: ease)
	var easy:Float = 0;
	// the rows of its floors (the rhythm: 5, 8, 11, 14 or 6, 9, 12, 15; 6, 10, 14 at the start of a game)
	var rows:Array<Int> = [];

	static inline function count(k:String) {
		#if gentest
		LevelFeatures.why.set(k, (LevelFeatures.why.exists(k) ? LevelFeatures.why.get(k) : 0) + 1);
		#end
	}

	public function new(g:LevelGen) {
		this.g = g;
		m = g.m;
	}

	// ---------------------------------------------------------------- the plan

	// how much a motif suits the bads of a level (what their powers need)
	static function suits(motif:String, id:Int):Float {
		inline function k(a:Array<String>, v:Float):Float
			return a.indexOf(motif) >= 0 ? v : 1.0;
		return switch (id) {
			case Data.BAD_FRAISE: k(["spines", "box", "hooks", "rooms", "comb"], 1.6);
			case Data.BAD_POIRE: k(["tree", "arches", "stairs", "spines"], 1.5);
			case Data.BAD_CITRON: k(["spines", "rooms", "hooks", "pillars"], 1.4);
			case Data.BAD_POMME: k(["rooms", "lattice", "box"], 1.4);
			case Data.BAD_ANANAS: k(["box", "tree", "arches", "mound"], 1.6);
			case Data.BAD_BOMBE: k(["rooms", "box", "hooks"], 1.5);
			case Data.BAD_ORANGE: k(["lattice", "stairs", "arches"], 1.6);
			case Data.BAD_BANANE: k(["stairs", "lattice", "spines"], 1.4);
			case Data.BAD_KIWI: k(["lattice", "rooms", "box"], 1.3);
			case Data.BAD_LITCHI: k(["box", "tree", "lattice"], 1.3);
			case Data.BAD_ABRICOT: k(["rooms", "box", "hooks"], 1.4);
			case Data.BAD_FRAMBOISE, Data.BAD_BALEINE: k(["stairs", "tree", "arches", "pillars", "mound"], 1.5);
			default: 1.0;
		}
	}

	// how easy a level is (the start of a game: "très facile", few platforms): 1 at levels 0 and 1, less and less up to
	// level 7, then 0
	public static function ease(depth:Int):Float {
		return depth <= 1 ? 1.0 : Math.max(0, (7 - depth) / 6);
	}

	// the first levels (up to 5): a few long floors on 3 rows, simple motifs
	public static inline var EASY_DEPTH = 5;

	// the motifs that look alike (a family): not one after another
	static function family(motif:String):String {
		return switch (motif) {
			case "lattice", "stairs", "few": "dashes";
			case "tree", "spines", "pillars": "trunks";
			case "box", "rooms": "boxes";
			default: motif;
		}
	}

	// how often a motif comes (the first levels of a game: the simple ones, the long floors of a lattice first)
	static function motifWeight(motif:String, depth:Int):Float {
		if (depth <= EASY_DEPTH)
			return switch (motif) {
				case "lattice": 2.0;
				case "stairs": 1.0;
				case "arches", "tree": 0.8;
				case "spines": 0.6;
				case "stack": 1.0;
				default: 0;
			};
		// (levels 6 and 7: the heavy motifs rarer)
		var heavy = depth <= EASY_DEPTH + 2 ? 0.4 : 1.0;
		return switch (motif) {
			case "rooms": 0.75 * heavy;
			case "box": 0.55 * heavy;
			case "mound": 1.0 * heavy;
			case "hooks": 1.3 * heavy;
			case "ledges", "comb": heavy;
			case "pillars": 1.0;
			case "arches": 0.4;
			case "tree": 0.7;
			case "spines": 0.85;
			case "lattice": 1.1;
			case "ladder": 0.9 * heavy;
			default: 1.0;
		};
	}

	static function layoutWeight(layout:String, depth:Int, n:Int):Float {
		if (depth <= EASY_DEPTH)
			return layout == "full" ? 3 : (layout == "center" ? 1 : 0);
		var w = switch (layout) {
			case "full": 3.0;
			case "center": 3.0;
			case "bands": 2.0;
			case "three": 1.2;
			// (a half reached only by the teleporters)
			case "split": depth >= 8 ? 1.1 : 0;
			default: 1.5;
		};
		// (levels 6 and 7: still simple, the layouts of many zones later)
		if (depth <= EASY_DEPTH + 2 && layout != "full" && layout != "center")
			w *= 0.35;
		// (many bads: the layouts with ledges on the sides have room for them)
		if (n >= 9 && (layout == "center" || layout == "three"))
			w *= 1.4;
		return w;
	}

	// the plan of a level: its layout, then the motif of its main zone (the ones of the dimension, the ones its bads
	// need, never one of the last 3 levels, hardly one of the 3 before), then the motif of its other zones
	public static function plan(depth:Int, lineup:LevelCast.Cast, recent:Array<DPlan>, force:String, ?want:Array<String>,
			?tried:Array<DPlan>, ?concept:LevelConcept.Concept, ?openBottom:Null<Bool>):DPlan {
		// (a vault: a box or a room of a building is shut, its window gets the laser of black bombs)
		var vault = want != null && want.indexOf("vault") >= 0;
		// (the bottom of the level left open over the void: almost never platforms at the very bottom in the first
		// levels, like the first levels of the original; now and then deeper; drawn once for the level)
		var open = openBottom != null ? openBottom : Cs.rnd(1000) < (concept != null ? concept.open : (depth <= 5 ? 0.95 : 0.5)) * 1000;
		var cid = concept != null ? concept.id : "";
		// (the first levels, 0 to 5 (cherries, oranges, apples, bananas, lemons, bombinos): drawn anew in the style of the
		// first levels of the original, mFew; the simple motifs gave the same levels from one game to the next)
		if (depth <= EASY_DEPTH && force == null)
			return {layout: "full", main: "few", other: "", sym: Cs.rnd(100) < 75, open: open, concept: cid};
		var th = LevelTheme.of(depth);
		var n = lineup == null ? 6 : lineup.list.length;
		// (test harness: &kind=close, a room shut reached by a teleporter in every level)
		var forceClose = force == "close";
		var fl = force != null && LAYOUTS.indexOf(force) >= 0 ? force : null;
		var fm = force != null && fl == null && !forceClose ? force : null;
		// (the layout)
		var lw = [for (l in LAYOUTS) {
			var w = layoutWeight(l, depth, n);
			if (fl != null)
				w = l == fl ? 1 : 0;
			if (fm != null)
				w = MAINS.get(l).indexOf(fm) >= 0 || OTHERS.get(l).indexOf(fm) >= 0 ? w : 0;
			if (vault && fm == null && fl == null && l != "full" && l != "center")
				w = 0;
			// (a box shut over the whole width would shut the level: the vault in a box only between ledges)
			if (vault && fm == null && fl == null && l == "full")
				w *= 0.5;
			if (recent.length > 0 && recent[0].layout == l)
				w *= 0.4;
			else if (recent.length > 1 && recent[1].layout == l)
				w *= 0.7;
			// (the layout of the idea of the level; a level split in two only for its idea)
			if (concept != null && fl == null) {
				if (concept.layout != "")
					w = l == concept.layout ? 1 : 0;
				else if (l == "split")
					w = 0;
				else if (concept.layouts.exists(l))
					w *= concept.layouts.get(l);
			}
			w;
		}];
		var li = Cs.draw([for (w in lw) Std.int(w * 100)]);
		var layout = LAYOUTS[li < 0 ? 0 : li];
		function weigh(motif:String, main:Bool):Float {
			var w = motifWeight(motif, depth);
			if (th.systems.indexOf(motif) >= 0)
				w *= 1.7;
			if (lineup != null && lineup.list.length > 0) {
				var mean = 0.0;
				for (id in lineup.list)
					mean += suits(motif, id);
				mean /= lineup.list.length;
				w *= Math.pow(suits(motif, lineup.lead), main ? 1.6 : 0.8) * mean;
			}
			// (the motifs of the last levels: not again before several levels; the ones already tried for this level
			// neither)
			for (i in 0...recent.length) {
				var r = recent[i];
				if (r.main == motif || (r.layout != "center" && r.other == motif))
					w *= i < 3 ? 0.03 : (i < 6 ? 0.35 : 0.75);
			}
			if (tried != null)
				for (r in tried)
					if (r.main == motif && main)
						w *= 0.1;
			// (the motifs alike: not in the last 2 levels, rarely in the 2 before)
			if (main)
				for (i in 0...Std.int(Math.min(4, recent.length)))
					if (family(recent[i].main) == family(motif) && recent[i].main != motif)
						w *= i < 2 ? 0.15 : 0.5;
			// (few platforms: not for a level of many bads)
			if (n >= 9 && layout == "full" && (motif == "arches" || motif == "stairs" || motif == "hooks"))
				w *= 0.3;
			// (the motifs the idea of the level is made for)
			if (concept != null && concept.mains.exists(motif))
				w *= main ? concept.mains.get(motif) : Math.sqrt(concept.mains.get(motif));
			return w;
		}
		var mains = MAINS.get(layout);
		var mw = [for (mo in mains) fm != null && mains.indexOf(fm) >= 0 ? (mo == fm ? 1.0 : 0.0) : weigh(mo, true)];
		// (the vault in a box or a room of a building, even one seen in the last levels: the vault is the idea of the
		// level)
		if (vault && fm == null)
			for (i in 0...mains.length)
				if ((mains[i] != "box" && mains[i] != "rooms") || (layout == "full" && mains[i] == "box"))
					mw[i] = 0;
				else
					mw[i] = Math.max(mw[i], 0.05);
		var mi = Cs.draw([for (w in mw) Std.int(w * 1000)]);
		var main = mains[mi < 0 ? Cs.rnd(mains.length) : mi];
		var others = [for (o in OTHERS.get(layout)) if (o != main) o];
		var ow = [for (o in others) fm != null && others.indexOf(fm) >= 0 ? (o == fm ? 1.0 : 0.0) : (o == "" ? 1.0 : weigh(o, false))];
		var oi = Cs.draw([for (w in ow) Std.int(w * 1000)]);
		var other = others.length == 0 ? "" : others[oi < 0 ? Cs.rnd(others.length) : oi];
		// (mirrored: most of the levels of the original that have one idea)
		var sym = switch (layout) {
			case "pair", "split": false;
			case "three": true;
			case "center": Cs.rnd(100) < 80;
			default: switch (main) {
					case "tree", "arches", "box": true;
					case "rooms": Cs.rnd(100) < 70;
					default: Cs.rnd(100) < 62;
				};
		};
		// (the piece: the cellar reached only by a teleporter, for its idea; not in a level split in two)
		var piece = "";
		if (layout != "split" && !vault && (forceClose || (concept != null && concept.piece == "close")))
			piece = "close";
		else if (layout != "split" && !vault && concept != null && concept.piece == "nest")
			piece = "nest";
		return {layout: layout, main: main, other: other, sym: sym, piece: piece, open: open, concept: cid};
	}

	// ---------------------------------------------------------------- what a level looks like

	public static inline var T_CENTERWALL = 1; // a wall in the middle (a trunk, a spine, a pillar)
	public static inline var T_SIDEWALLS = 2; // walls between the middle and the sides
	public static inline var T_SIDELEDGES = 4; // ledges against the sides of the screen
	public static inline var T_ARCHES = 8; // lintels on legs
	public static inline var T_BOX = 16; // a frame
	public static inline var T_LATTICE = 32; // many small platforms alike
	public static inline var T_STAIRS = 64; // platforms going down in a diagonal
	public static inline var T_HANG = 128; // walls hanging from the top
	public static inline var T_FLOORS = 256; // long floors across
	public static inline var T_PILLARS = 512; // walls standing on the bottom with a cap

	// the traits of a level (its ground: m[x][y] > 0)
	public static function traits(m:Array<Array<Int>>):Int {
		inline function gr(x:Int, y:Int):Bool
			return x >= 0 && x < W && y >= 0 && y < H && m[x][y] > 0;
		var t = 0;
		// vertical runs of 5 cases or more: where they are, where they start and end
		var runs:Array<{x:Int, y0:Int, y1:Int}> = [];
		for (x in 0...W) {
			var y = 1;
			while (y < B) {
				if (!gr(x, y)) {
					y++;
					continue;
				}
				var y0 = y;
				while (y < B && gr(x, y))
					y++;
				if (y - y0 >= 5)
					runs.push({x: x, y0: y0, y1: y - 1});
			}
		}
		for (r in runs) {
			if (r.x >= 7 && r.x <= 10)
				t |= T_CENTERWALL;
			else if (r.x >= 2 && r.x <= 15)
				t |= T_SIDEWALLS;
			if (r.y0 <= 6 && r.y1 <= 13)
				t |= T_HANG;
			if (r.y1 >= B - 1 && r.y0 >= 8 && (gr(r.x - 1, r.y0) || gr(r.x + 1, r.y0)))
				t |= T_PILLARS;
		}
		// horizontal runs (the tops of the platforms)
		var tops:Array<{y:Int, x0:Int, x1:Int}> = [];
		for (y in 1...B) {
			var x = 0;
			while (x < W) {
				if (!(gr(x, y) && !gr(x, y - 1))) {
					x++;
					continue;
				}
				var x0 = x;
				while (x < W && gr(x, y) && !gr(x, y - 1))
					x++;
				tops.push({y: y, x0: x0, x1: x - 1});
			}
		}
		var side = 0;
		var floors = 0;
		var arches = 0;
		var lens = new Map<Int, Int>();
		for (p in tops) {
			var len = p.x1 - p.x0 + 1;
			if ((p.x0 == 0 || p.x1 == W - 1) && len <= 4)
				side++;
			if (len >= 12)
				floors++;
			if (len >= 4 && len <= 8 && gr(p.x0, p.y + 1) && gr(p.x1, p.y + 1) && !gr((p.x0 + p.x1) >> 1, p.y + 1)
				&& gr(p.x0, p.y + 2))
				arches++;
			var free = !gr(p.x0 - 1, p.y) && !gr(p.x1 + 1, p.y) && !gr(p.x0, p.y + 1) && !gr(p.x1, p.y + 1);
			if (free && len <= 4)
				lens.set(len, (lens.exists(len) ? lens.get(len) : 0) + 1);
		}
		if (side >= 4)
			t |= T_SIDELEDGES;
		if (floors >= 2)
			t |= T_FLOORS;
		if (arches >= 2)
			t |= T_ARCHES;
		for (v in lens)
			if (v >= 8)
				t |= T_LATTICE;
		// a frame: two walls with a lintel between their tops
		for (a in runs)
			for (b in runs)
				if (b.x - a.x >= 6 && Math.abs(a.y0 - b.y0) <= 1) {
					var ok = true;
					for (x in a.x...b.x + 1)
						if (!gr(x, a.y0) && !gr(x, a.y0 + 1))
							ok = false;
					var gaps = 0;
					for (x in a.x...b.x + 1)
						if (!gr(x, a.y0))
							gaps++;
					if (gaps <= 4 && ok)
						t |= T_BOX;
				}
		// stairs: three platforms, each 3 or 4 rows under the other and aside the same way
		for (a in tops)
			for (b in tops) {
				var dy = b.y - a.y;
				if (dy < 3 || dy > 4)
					continue;
				var dx = b.x0 - a.x0;
				if (Math.abs(dx) < 2 || Math.abs(dx) > 5)
					continue;
				for (c in tops)
					if (c.y - b.y >= 3 && c.y - b.y <= 4 && c.x0 - b.x0 == dx)
						t |= T_STAIRS;
			}
		return t;
	}

	// how much a level is like the last 6 levels (their traits): shared traits, the last level counting most
	public static function sameLook(t:Int, recent:Array<Int>):Float {
		var v = 0.0;
		var w = [1.0, 0.7, 0.5, 0.35, 0.25, 0.15];
		for (i in 0...Std.int(Math.min(w.length, recent.length))) {
			var s = t & recent[i];
			var n = 0;
			while (s != 0) {
				n += s & 1;
				s >>= 1;
			}
			v += n * w[i];
		}
		return v;
	}

	// ---------------------------------------------------------------- drawing a level

	public function draw(p:DPlan) {
		thePlan = p;
		g.floors = [];
		g.vault = null;
		gates = [];
		// (3 rows of floors up to level 7, the simple motifs only up to level 5)
		light = g.depth <= EASY_DEPTH + 2;
		easy = ease(g.depth);
		var n = g.lineup == null ? 6 : g.lineup.list.length;
		dense = n >= 8 && !light;
		// (3 rows apart like the floors of the original: a bad jumps up from one to the next, a banana goes everywhere)
		step = 3;
		open = p.open == true;
		g.open = open;
		// (the first levels: 3 floors at the bottom of the screen, the air over them like the first levels of the
		// original; levels 0-3 drawn on 4 rows (mFew), 6-7 on 4 floors)
		rows = light ? (g.depth <= 3 || g.depth > EASY_DEPTH ? [5, 8, 11, 14] : [8, 11, 14])
			: (g.chance(0.7) ? [5, 8, 11, 14] : [6, 9, 12, 15]);
		// (a bottom open over the void: the lowest floor 3 or 4 rows over it; the first levels keep their rows, the air
		// under the lowest floor only, like the first levels of the original (players: "trop de vide"))
		if (open && !light && g.chance(0.5))
			rows = [4, 7, 10, 13];
		// (long platforms in the first levels, like the original's: 5 to 7 cases)
		unit = light ? g.range(5, 7) : (dense ? g.range(2, 3) : g.range(3, 4));
		sym = p.sym;
		variant = "";
		// the bottom (its ways out cut once the motifs are drawn); none over the void
		if (!open)
			for (x in 0...W)
				m[x][B] = 1;
		var top = rows[0];
		// (the lowest row of the zones: over the void, the lowest floor)
		var zb = open ? rows[rows.length - 1] : B - 1;
		switch (p.layout) {
			case "full":
				motif(p.main, {x0: 0, x1: W - 1, y0: top, y1: zb, side: 2});
			case "center":
				var a = g.range(3, 4);
				motif(p.main, {x0: a + 1, x1: W - 2 - a, y0: top, y1: zb, side: 0});
				motif(p.other, {x0: 0, x1: a - 1, y0: top, y1: zb, side: -1});
				if (!sym)
					motif(p.other, {x0: W - a, x1: W - 1, y0: top, y1: zb, side: 1});
			case "bands":
				// (the top band: the rows over the split, the bottom band: the ones under)
				var ys = rows[Std.int(Math.min(2, rows.length - 1))];
				motif(p.other, {x0: 0, x1: W - 1, y0: top, y1: ys - 1, side: 2});
				motif(p.main, {x0: 0, x1: W - 1, y0: ys, y1: zb, side: 2});
			case "three":
				motif(p.main, {x0: 6, x1: 11, y0: top, y1: zb, side: 0});
				motif(p.other, {x0: 0, x1: 4, y0: top, y1: zb, side: -1});
			case "split":
				split(p);
			default:
				var a = g.range(7, 8);
				motif(p.main, {x0: 0, x1: a - 1, y0: top, y1: zb, side: -1});
				motif(p.other, {x0: a + 2, x1: W - 1, y0: top, y1: zb, side: 1});
		}
		if (p.piece == "close")
			cellar();
		if (p.piece == "nest")
			nestCorner();
		if (g.wants("vault") && g.vault == null)
			count("vault.none");
		tidy();
		// (over the void: no way out to cut, no column to cover: Igor coming in over the void is put over a ground,
		// Game.safeEntry)
		if (!open)
			exits();
		entry();
		if (!open)
			coverColumns();
		tidy();
		// (an asymmetric level drawn one way or the other)
		if (!sym && g.chance(0.5))
			flip();
		for (y in rows.concat([B]))
			if (g.floors.indexOf(y) < 0)
				g.floors.push(y);
		g.floors.sort(function(a, b) return a - b);
		g.kind = p.layout + ":" + p.main + (p.other != "" ? "|" + p.other : "");
		g.sym = isSym();
		variant = g.kind + (variant != "" ? "/" + variant : "");
	}

	function motif(name:String, z:DZone) {
		switch (name) {
			case "lattice":
				mLattice(z);
			case "tree":
				mTree(z);
			case "spines":
				mSpines(z);
			case "arches":
				mArches(z);
			case "pillars":
				mPillars(z);
			case "hooks":
				mHooks(z);
			case "box":
				mBox(z);
			case "stairs":
				mStairs(z);
			case "rooms":
				mRooms(z);
			case "mound":
				mMound(z);
			case "few":
				mFew(z);
			case "ladder":
				mLadder(z);
			case "ledges":
				mLedges(z, false);
			case "stack":
				mLedges(z, true);
			case "comb":
				mComb(z);
			default:
		}
	}

	// the kind leading the level (-1: none)
	inline function lead():Int {
		return g.lineup == null ? -1 : g.lineup.lead;
	}

	// weights of the variants of a motif, the ones the leading kind needs raised (pairs: kind, variant)
	function variantFor(w:Array<Int>, wants:Array<Array<Int>>):Int {
		var ww = w.copy();
		for (p in wants)
			if (p[0] == lead() && ww[p[1]] > 0)
				ww[p[1]] *= 4;
		return g.draw(ww);
	}

	function tag(s:String) {
		variant += (variant != "" ? "," : "") + s;
	}

	// the floor rows of a zone
	function zr(z:DZone):Array<Int> {
		return [for (r in rows) if (r >= z.y0 && r <= z.y1) r];
	}

	// a zone mirrored over the middle of the level (its motif drawn symmetric)
	inline function centered(z:DZone):Bool {
		return z.x0 + z.x1 == W - 1;
	}

	// ---------------------------------------------------------------- motifs

	// a lattice: platforms of one length on the floor rows, side by side with the same gaps: in columns, in bricks
	// (every other row shifted by half a step), or in a checker
	function mLattice(z:DZone) {
		var w = z.x1 - z.x0 + 1;
		var layout = light ? (g.chance(0.7) ? 1 : 0) : variantFor([3, 5, 1], [[Data.BAD_ORANGE, 1], [Data.BAD_POMME, 0]]);
		tag(["grid", "bricks", "checker"][layout] + (light ? "-long" : ""));
		var L = w <= 6 ? 2 : (dense ? g.range(2, 3) : g.range(3, 4));
		var gap = dense || lead() == Data.BAD_ORANGE ? 2 : g.range(2, 3);
		// (the start of a game: long floors, wide gaps: two on a row, one on the next)
		if (light && w > 6) {
			L = easy >= 0.6 ? g.range(5, 7) : g.range(4, 6);
			gap = easy >= 0.6 ? g.range(4, 5) : g.range(3, 4);
		}
		var rr = zr(z);
		for (k in 0...rr.length) {
			var starts = latticeRow(z.x0, z.x1, L, gap, layout == 1 ? k % 2 : 0);
			for (i in 0...starts.length) {
				if (layout == 2 && (i + k) % 2 == 1)
					continue;
				h(starts[i], starts[i] + L - 1, rr[k]);
			}
		}
	}

	// ledges against the side of the screen on the floor rows (every one, or every other one), 2 cases at least
	// between their end and the next zone
	function mLedges(z:DZone, sparse:Bool) {
		var w = z.x1 - z.x0 + 1;
		var L = Std.int(Math.max(2, Math.min(unit, w - 1)));
		tag(sparse ? "stack" : "ledges");
		var rr = zr(z);
		var left = z.side < 0;
		for (k in 0...rr.length) {
			if (sparse && k % 2 == (rr.length % 2 == 0 ? 0 : 1))
				continue;
			var x0 = left ? z.x0 : z.x1 - L + 1;
			h(x0, x0 + L - 1, rr[k]);
		}
	}

	// a comb: a wall along the inner edge of a side zone, hanging from its first floor row down under its last one,
	// its ledges toward the side of the screen (a case free by the side: the way down)
	function mComb(z:DZone) {
		var w = z.x1 - z.x0 + 1;
		var left = z.side < 0;
		var wx = left ? z.x1 : z.x0;
		var rr = zr(z);
		if (rr.length == 0 || w < 3)
			return;
		var L = Std.int(Math.max(1, Math.min(unit, w - 2)));
		tag("comb");
		col(wx, rr[0], rr[rr.length - 1] + 1);
		for (r in rr)
			if (L >= 2 || w == 3)
				h(left ? wx - L : wx + 1, left ? wx - 1 : wx + L, r);
	}

	// a tree: a trunk in the middle of its zone, its branches on the floor rows, their width drawn by a profile (a
	// pyramid, a pagoda wide and narrow in turn, a diamond, all alike); or the branches without the trunk
	function mTree(z:DZone) {
		var rr = zr(z);
		if (rr.length == 0)
			return;
		var mid = centered(z);
		var zc = (z.x0 + z.x1) >> 1;
		var trunk = g.chance(light ? 0.35 : 0.5);
		var prof = variantFor([3, 3, 2, 2], [[Data.BAD_POIRE, 1], [Data.BAD_ANANAS, 0], [Data.BAD_FRAMBOISE, 2]]);
		tag(["pyramid", "pagoda", "diamond", "even"][prof] + (trunk ? "" : "-bars"));
		var nb = light ? Std.int(Math.min(3, rr.length)) : rr.length;
		var maxHw = Std.int((z.x1 - z.x0 + 1) / 2) - (mid ? 2 : 1);
		var grounded = trunk && z.y1 >= B - 1 && g.chance(0.6);
		if (trunk)
			col(mid ? 8 : zc, rr[0], grounded ? B : rr[nb - 1]);
		for (k in 0...nb) {
			var hw = switch (prof) {
				case 0: 1 + k * 2;
				case 1: k % 2 == 0 ? maxHw : Std.int(maxHw / 2);
				case 2: Std.int(2 + Math.min(k, nb - 1 - k) * 2.5);
				default: Std.int(Math.max(2, maxHw - 2));
			};
			hw = Std.int(Math.max(1, Math.min(maxHw, hw)));
			if (mid)
				h(8 - hw, 8, rr[k]);
			else
				h(zc - hw, zc + hw, rr[k]);
		}
	}

	// spines: walls standing on the bottom (or hanging), one in the middle of the zone or two, their rungs every 3 rows
	// on both sides, only outside, or meeting the rungs of the other spine (bridges); a cap on top
	function mSpines(z:DZone) {
		var rr = zr(z);
		if (rr.length < 2)
			return;
		var w = z.x1 - z.x0 + 1;
		var mid = centered(z);
		var two = w >= 13 && !light && g.chance(0.7);
		var L = Std.int(Math.max(2, unit));
		var xs:Array<Int> = [];
		var t = 1;
		if (!two) {
			if (mid) {
				xs = [8];
				t = 2;
			} else
				xs = [(z.x0 + z.x1) >> 1];
		} else {
			var a = g.range(4, 5);
			xs = [z.x0 + a, z.x1 - a];
		}
		var pat = variantFor([4, 2, two ? 3 : 0], [[Data.BAD_FRAISE, 0], [Data.BAD_POIRE, 1], [Data.BAD_CITRON, 2],
			[Data.BAD_ORANGE, 2]]);
		var grounded = z.y1 >= B - 1 && g.chance(0.7);
		tag(["both", "outer", "bridges"][pat] + xs.length + (grounded ? "" : "-hang"));
		var bot = grounded ? B : rr[rr.length - 1] + 1;
		for (x in xs)
			col(x, rr[0], bot);
		if (t == 2)
			col(9, rr[0], bot);
		// (the rooms of the rungs: outside each spine to the edge of the zone, between the two spines; 2 cases free
		// by a side of the screen, 1 by another zone)
		var left = xs[0];
		var right = xs[xs.length - 1] + t - 1;
		var outL = left - z.x0 - (z.x0 == 0 ? 2 : 1);
		var outR = z.x1 - right - (z.x1 == W - 1 ? 2 : 1);
		var inner = two ? xs[1] - xs[0] - 1 : 0;
		var lo = Std.int(Math.min(L, outL));
		var ro = Std.int(Math.min(L, outR));
		// the caps (a T on each spine)
		if (g.chance(0.7))
			for (i in 0...xs.length) {
				var x = xs[i];
				var cl = i == 0 ? Std.int(Math.min(2, lo)) : Std.int(Math.min(2, (inner - 3) >> 1));
				var cr = i == xs.length - 1 ? Std.int(Math.min(2, ro)) : Std.int(Math.min(2, (inner - 3) >> 1));
				if (cl >= 1 && cr >= 1)
					h(x - cl, x + t - 1 + cr, rr[0]);
			}
		for (k in 1...rr.length) {
			var y = rr[k];
			if (lo >= 2)
				h(left - lo, left - 1, y);
			if (ro >= 2)
				h(right + 1, right + ro, y);
			if (!two || pat == 1)
				continue;
			if (pat == 2) {
				// (bridges: a hole of 2 in the middle)
				var li = (inner - 2) >> 1;
				if (li >= 1) {
					h(xs[0] + 1, xs[0] + li, y);
					h(xs[1] - li, xs[1] - 1, y);
					gates.push([for (x in xs[0] + 1 + li...xs[1] - li) {x: x, y: y}]);
				}
			} else {
				var li = Std.int(Math.min(L, (inner - 3) >> 1));
				if (li >= 2) {
					h(xs[0] + 1, xs[0] + li, y);
					h(xs[1] - li, xs[1] - 1, y);
				}
			}
		}
	}

	// arches: a lintel on two legs (2 cases), in a row, a second row 6 rows lower shifted by half an arch; or arches of
	// two sizes (a wide one in the middle); never touching what is under them
	function mArches(z:DZone) {
		var rr = [for (r in zr(z)) if (r + 3 <= z.y1) r];
		if (rr.length == 0)
			return;
		var form = light ? 0 : g.draw([4, 3]);
		var legs = 2;
		var gap = g.range(2, 3);
		tag(["rows", "sizes"][form]);
		if (form == 0) {
			var aw = light ? g.range(5, 7) : (dense ? g.range(4, 5) : g.range(4, 6));
			var ar = [rr[0]];
			if (rr.length >= 3 && !light)
				ar.push(rr[2]);
			for (k in 0...ar.length)
				archRow(z.x0, z.x1, ar[k], aw, gap, k % 2, legs);
		} else {
			// (a wide arch in the middle, narrower ones on the sides, then the other way under them)
			var wide = g.range(6, 8);
			if ((W - wide) % 2 != 0)
				wide++;
			var narrow = g.range(3, 4);
			var y = rr[0];
			var cx0 = (W - wide) >> 1;
			arch(cx0, cx0 + wide - 1, y, legs);
			var sx = cx0 - gap - narrow;
			while (sx >= z.x0) {
				arch(sx, sx + narrow - 1, y, legs);
				gates.push([for (x in sx + narrow...sx + narrow + gap) {x: x, y: y}]);
				sx -= narrow + gap;
			}
			if (rr.length >= 3) {
				var y2 = rr[2];
				var w2 = g.range(4, 5);
				var x2 = cx0 - Std.int(w2 / 2) - 1;
				if (x2 >= z.x0 + 1) {
					arch(x2, x2 + w2 - 1, y2, legs);
				}
			}
		}
	}

	function archRow(x0:Int, x1:Int, y:Int, aw:Int, gap:Int, shift:Int, legs:Int) {
		var st = latticeRow(x0, x1, aw, gap, shift);
		for (i in 0...st.length) {
			arch(st[i], st[i] + aw - 1, y, legs);
			if (i + 1 < st.length && st[i + 1] - (st[i] + aw) <= 3)
				gates.push([for (x in st[i] + aw...st[i + 1]) {x: x, y: y}]);
		}
	}

	function arch(x0:Int, x1:Int, y:Int, legs:Int) {
		h(x0, x1, y);
		col(x0, y + 1, y + legs);
		col(x1, y + 1, y + legs);
	}

	// pillars standing on the bottom, a cap on each (5 cases), tall and short in turn (a short cap 3 rows over the
	// bottom: Igor climbs back on it, then on the tall ones)
	function mPillars(z:DZone) {
		var rr = zr(z);
		if (rr.length == 0)
			return;
		var xs:Array<Int> = [];
		var mid = centered(z);
		if (mid) {
			// (pairs mirrored, the middle one 2 cases thick)
			var a = g.range(2, 3);
			if (z.x1 - z.x0 >= 12)
				xs = [z.x0 + a, 8];
			else
				xs = [8];
		} else {
			var P = 6;
			xs = latticeRow(z.x0 + 2, z.x1 - 2, 1, P - 1, 0);
		}
		tag("p" + xs.length);
		var tall = rr.length >= 2 ? rr[rr.length - 2] : rr[0];
		var short = rr[rr.length - 1];
		if (rr.length >= 3 && g.chance(0.4))
			tall = rr[rr.length - 3];
		for (i in 0...xs.length) {
			var x = xs[i];
			var isMid = mid && x == 8;
			var top = (i % 2 == (mid ? 1 : 0)) ? tall : short;
			col(x, top, B);
			if (isMid)
				col(9, top, B);
			h(x - 2, x + (isMid ? 3 : 2), top);
		}
	}

	// stalactites: a ceiling across the zone (its ways in between them), walls hanging from it every 5 or 6 cases, long
	// and short in turn, a foot at their end (2 cases toward the middle, or a T); or no ceiling: each wall its own cap
	function mHooks(z:DZone) {
		var rr = zr(z);
		if (rr.length < 2)
			return;
		var yC = rr[0];
		var ceiling = g.chance(0.6);
		var P = g.range(5, 6);
		var footT = g.chance(0.35);
		tag((ceiling ? "ceiling" : "caps") + (footT ? "-t" : ""));
		if (ceiling)
			h(z.x0, z.x1, yC);
		var xs = latticeRow(z.x0 + 1, z.x1 - 1, 1, P - 1, 0);
		for (i in 0...xs.length) {
			var x = xs[i];
			var long = i % 2 == 0;
			var end = rr[Std.int(Math.min(rr.length - 1, long ? 2 : 1))];
			col(x, yC, end);
			if (!ceiling)
				h(x - 1, x + 1, yC);
			var dir = x < 9 ? 1 : -1;
			if (footT)
				h(x - 2, x + 2, end);
			else
				h(Std.int(Math.min(x, x + dir * 2)), Std.int(Math.max(x, x + dir * 2)), end);
		}
		// (the ways in: holes in the ceiling between the hanging walls)
		if (ceiling)
			for (i in 0...xs.length - 1) {
				var a = xs[i];
				var b = xs[i + 1];
				if (i % 2 == 1 || xs.length <= 3) {
					var hx = (a + b) >> 1;
					var hw = (b - a) % 2 == 0 ? 1 : 2;
					for (k in 0...hw)
						c(hx + k, yC, 0);
					addGate([for (k in 0...hw) {x: hx + k, y: yC}]);
				}
			}
	}

	// a box: its walls, a gap in its top (the way in), its bottom raised with a gap (or the bottom of the level), a
	// door in a side; inside: ledges on its walls, bars in its middle (a wide floor), or a lattice
	function mBox(z:DZone) {
		var rr = zr(z);
		if (rr.length < 2)
			return;
		var inset = z.side == 2 ? g.range(1, 2) : 0;
		var bx0 = z.x0 + inset;
		var bx1 = z.x1 - inset;
		var y0 = rr[0];
		// (the vault: the box on the bottom, shut, a window in its sides)
		var vault = g.wants("vault") && g.vault == null && z.y1 >= B - 1 && rr.length >= 3 && z.side == 0;
		var grounded = vault || (z.y1 >= B - 1 && g.chance(0.4));
		var y1 = grounded ? B : rr[rr.length - 1];
		var inner = variantFor([4, 3, 2], [[Data.BAD_FRAISE, 0], [Data.BAD_ANANAS, 1], [Data.BAD_LITCHI, 1],
			[Data.BAD_KIWI, 2], [Data.BAD_POMME, 2]]);
		tag(["ledges", "bars", "lattice"][inner] + (grounded ? "" : "-raised"));
		col(bx0, y0, y1);
		col(bx1, y0, y1);
		h(bx0, bx1, y0);
		// the way in: a gap in the middle of the top, or one near each corner (the vault: its windows)
		if (vault) {
			var wy = rr[rr.length - 1] - 1;
			var door = [{x: bx0, y: wy - 1}, {x: bx0, y: wy}];
			setc(bx0, wy - 1, 0);
			setc(bx0, wy, 0);
			if (sym) {
				setc(bx1, wy - 1, 0);
				setc(bx1, wy, 0);
				door.push({x: bx1, y: wy - 1});
				door.push({x: bx1, y: wy});
			}
			g.vault = {x0: bx0 + 1, x1: bx1 - 1, y: B - 1, top: y0 + 1, door: door};
			tag("vault");
		} else if (g.chance(0.6)) {
			var gw = (bx1 - bx0 + 1) % 2 == 0 ? 2 : 3;
			var gx = (bx0 + bx1 + 1 - gw) >> 1;
			for (k in 0...gw)
				setc(gx + k, y0, 0);
			gates.push([for (k in 0...gw) {x: gx + k, y: y0}]);
		} else {
			var gx = bx0 + 2;
			c(gx, y0, 0);
			c(gx + 1, y0, 0);
			addGate([{x: gx, y: y0}, {x: gx + 1, y: y0}]);
		}
		if (!grounded) {
			h(bx0, bx1, y1);
			var gw = (bx1 - bx0 + 1) % 2 == 0 ? 2 : 3;
			var gx = (bx0 + bx1 + 1 - gw) >> 1;
			for (k in 0...gw)
				setc(gx + k, y1, 0);
			gates.push([for (k in 0...gw) {x: gx + k, y: y1}]);
		}
		var inRows = [for (r in rr) if (r > y0 && r < y1) r];
		// (a door of 2 cases in a side, over an inner floor)
		if (!vault && inRows.length > 0 && g.chance(0.45)) {
			var dy = inRows[g.rnd(inRows.length)];
			c(bx0, dy - 1, 0);
			c(bx0, dy - 2, 0);
			addGate([{x: bx0, y: dy - 2}, {x: bx0, y: dy - 1}]);
		}
		var ix0 = bx0 + 1;
		var ix1 = bx1 - 1;
		var iw = ix1 - ix0 + 1;
		switch (inner) {
			case 0:
				var L = Std.int(Math.max(2, Math.min(unit, (iw - 4) >> 1)));
				for (y in inRows) {
					h(ix0, ix0 + L - 1, y);
					h(ix1 - L + 1, ix1, y);
				}
			case 1:
				for (k in 0...inRows.length) {
					var bw = k % 2 == 0 ? iw - 6 : Std.int(Math.max(2, iw - 10));
					if (bw < 2)
						bw = 2;
					var bx = (ix0 + ix1 + 1 - bw) >> 1;
					h(bx, bx + bw - 1, inRows[k]);
				}
			default:
				for (k in 0...inRows.length)
					for (s in latticeRow(ix0 + 1, ix1 - 1, 2, 2, k % 2))
						h(s, s + 1, inRows[k]);
		}
	}

	// stairs: platforms of the level's length going down a row of floors at a time, a step aside each time: from the
	// sides down to the middle (a V), from the middle down to the sides (a roof), or across the zone
	function mStairs(z:DZone) {
		var rr = zr(z);
		if (rr.length < 2)
			return;
		var L = Std.int(Math.max(3, unit));
		var sx = L + g.range(0, 1);
		var mid = centered(z);
		if (mid) {
			var roof = g.chance(0.45);
			tag(roof ? "roof" : "V");
			var x = roof ? 8 - L + 1 : z.x0 + g.range(0, 1);
			for (r in rr) {
				if (x < z.x0 || x + L - 1 > 8)
					break;
				h(x, x + L - 1, r);
				x += roof ? -sx : sx;
			}
			// (a floor across the point of the V)
			if (!roof && g.chance(0.6)) {
				var r = rr[rr.length - 1];
				if (m[7][r] == 0 && m[6][r] == 0)
					h(7, 8, r);
			}
		} else {
			var dir = z.side < 0 ? 1 : (z.side > 0 ? -1 : (g.chance(0.5) ? 1 : -1));
			tag(dir > 0 ? "down-right" : "down-left");
			var x = dir > 0 ? z.x0 : z.x1 - L + 1;
			for (r in rr) {
				if (x < z.x0 || x + L - 1 > z.x1)
					break;
				h(x, x + L - 1, r);
				x += dir * sx;
			}
		}
	}

	// a building: walls going down from its roof to the bottom, its rooms floor over floor (every 3 rows), a hole of 2
	// in each floor (in the middle of a wide room, at one end then the other of a narrow one), doors of a case in the
	// walls (their lintel over them), its roof with a way into each room; in a narrow zone a tower of rooms. The vault:
	// the room of the bottom of a side shut, a window in its wall
	function mRooms(z:DZone) {
		var rr = zr(z);
		if (rr.length < 2)
			return;
		var walls:Array<Int> = [];
		var w = z.x1 - z.x0 + 1;
		if (z.x0 > 0)
			walls.push(z.x0);
		if (z.x1 < W - 1)
			walls.push(z.x1);
		if (w >= 16) {
			var a = g.range(5, 6);
			walls.push(z.x0 + a);
			walls.push(z.x1 - a);
		}
		walls.sort(function(a, b) return a - b);
		var zig = variantFor([3, 2], [[Data.BAD_CITRON, 0]]) == 1;
		tag((walls.length + 1) + "c" + (zig ? "-zig" : ""));
		for (x in walls)
			col(x, rr[0], B);
		// the rooms: the columns between the walls (or a wall and a side of the screen)
		var spans:Array<Array<Int>> = [];
		var prev = z.x0 - 1;
		for (x in walls) {
			if (x - prev - 1 >= 3)
				spans.push([prev + 1, x - 1]);
			prev = x;
		}
		if (z.x1 - prev >= 3)
			spans.push([prev + 1, z.x1]);
		var vault = g.wants("vault") && g.vault == null && spans.length >= 2 && spans[0][0] == 0;
		for (si in 0...spans.length) {
			var sp = spans[si];
			var a = sp[0];
			var b = sp[1];
			if (sym && a > 8)
				continue;
			var wd = b - a + 1;
			var across = sym && a <= 8 && b >= 9;
			for (k in 0...rr.length) {
				var y = rr[k];
				for (x in a...b + 1)
					c(x, y);
				// (the floor of the vault: shut)
				if (vault && si == 0 && k == rr.length - 1)
					continue;
				// (the holes: never one under another down to the bottom (a ground over every column): in the middle of a
				// wide room then at both its ends, or at one end then the other)
				var hs:Array<Int> = [];
				if (across || (wd >= 6 && !zig))
					hs = k % 2 == 0 ? [a + ((wd - 2) >> 1)] : [a, b - 1];
				else
					hs = [(k % 2 == 0) == (a == 0) ? b - 1 : a];
				if (across)
					hs = k % 2 == 0 ? [8] : [a];
				for (hx in hs) {
					c(hx, y, 0);
					c(hx + 1, y, 0);
					if (k > 0)
						addGate([{x: hx, y: y}, {x: hx + 1, y: y}]);
				}
			}
		}
		// doors of a case over the floors, every other floor, in the inner walls (not the vault's)
		for (x in walls) {
			if (x == z.x0 || x == z.x1 || (sym && x > 8))
				continue;
			for (k in 1...rr.length)
				if (k % 2 == 1 && !(vault && x == walls[0] && k == rr.length - 1))
					c(x, rr[k] - 1, 0);
		}
		if (vault) {
			// (the window: the 2 cases of the wall of the bottom room over its floor)
			var wx = spans[0][1] + 1;
			var door = [{x: wx, y: B - 2}, {x: wx, y: B - 1}];
			c(wx, B - 2, 0);
			c(wx, B - 1, 0);
			if (sym) {
				door.push({x: W - 1 - wx, y: B - 2});
				door.push({x: W - 1 - wx, y: B - 1});
			}
			g.vault = {x0: spans[0][0], x1: spans[0][1], y: B - 1, top: rr[rr.length - 1] + 1, door: door};
			tag("vault");
		}
	}

	// a mound: a mass of ground standing on the bottom, its sides in steps (a row and 1 or 2 cases each), its top a
	// floor of the level (3 rows over the bottom: Igor climbs on it from the bottom); in the middle of its zone, or
	// against a side of the screen (a cliff going down in steps toward the middle); platforms of the level's length
	// over it on the floor rows
	function mMound(z:DZone) {
		var rr = zr(z);
		if (rr.length == 0 || z.y1 < B - 1)
			return;
		var mid = centered(z);
		var st = g.range(1, 2);
		var top = rr[rr.length - 1];
		var hgt = B - top;
		var cliff = !mid && (z.x0 == 0 || z.x1 == W - 1);
		tag(cliff ? "cliff" : "hill" + st);
		if (cliff) {
			// (against the side of the screen, going down toward the middle)
			var left = z.x0 == 0;
			var tw = g.range(2, 3);
			for (k in 0...hgt) {
				var y = top + k;
				var wdt = tw + k * st;
				for (q in 0...wdt)
					setc(left ? q : W - 1 - q, y, 1);
			}
		} else {
			var zc2 = z.x0 + z.x1;
			var tw = g.range(2, 3);
			for (k in 0...hgt) {
				var y = top + k;
				var hw = tw + k * st;
				var x0 = Std.int(Math.max(z.x0 + 1, (zc2 >> 1) - hw + 1));
				var x1 = Std.int(Math.min(z.x1 - 1, ((zc2 + 1) >> 1) + hw - 1));
				h(x0, x1, y);
			}
		}
		// (platforms over it on the floor rows: the lattice of the level, the ones over the mound left out)
		var L = Std.int(Math.max(2, Math.min(4, unit)));
		var gap = g.range(2, 3);
		for (k in 0...rr.length - 1) {
			var y = rr[k];
			for (s in latticeRow(z.x0, z.x1, L, gap, k % 2))
				if (ledgeFits(s, s + L - 1, y))
					h(s, s + L - 1, y);
		}
	}

	// the first levels of a game (0 to 3) in the style of the first levels of the original well (adventure 2 to 7),
	// drawn anew every time (players: "toujours les mêmes niveaux, pas une copie des originaux mais un truc dans le même
	// style"): 3 or 4 floors 3 rows apart, each over the next one somewhere (a bad jumps up from one to the next: the
	// bananas, the apples reach Igor everywhere), long platforms, gaps of 2 the oranges hop over, a long floor at the
	// bottom under the middle (Igor falling from the others lands on it); now and then walls of 2 cases the bananas
	// climb (the rims of a basin open in its middle, a lip under a floor); mirrored most of the time
	function mFew(z:DZone) {
		var ys = g.chance(0.55) ? [5, 8, 11, 14] : (g.chance(0.5) ? [8, 11, 14] : [7, 10, 13]);
		var mirror = sym;
		tag(mirror ? "few" : "few-free");
		// the pieces of each floor, from the bottom up: [x0, x1] over the whole width
		var floors:Array<Array<Array<Int>>> = [];
		var kinds:Array<Int> = [];
		var k = ys.length - 1;
		var guard = 0;
		while (k >= 0 && guard++ < 200) {
			var bottom = k == ys.length - 1;
			var kind = bottom ? (mirror ? g.draw([5, 3, 0, 2]) : 4) : (mirror ? g.draw([3, 4, 2, 3]) : 4);
			var row = fewRow(kind, bottom, mirror);
			if (row == null)
				continue;
			// (over the floor under it somewhere, not the same floor again)
			if (!bottom) {
				var under = floors[floors.length - 1];
				if (overlap(row, under) < 2 || same(row, under))
					continue;
				// (a floor at the top with nothing over the one under it but one case: a jump in the air)
				if (k == 0 && cover(row) < 4)
					continue;
			}
			floors.push(row);
			kinds.push(kind);
			k--;
		}
		if (k >= 0)
			return;
		floors.reverse();
		kinds.reverse();
		var sig = "";
		for (i in 0...floors.length) {
			for (p in floors[i])
				for (x in p[0]...p[1] + 1)
					setc(x, ys[i], 1);
			sig += "LPEMF".charAt(kinds[i]);
		}
		tag(sig);
		// walls of 2 cases the bananas climb
		if (mirror && g.chance(0.3)) {
			// (a basin: walls standing on the outer ends of a pair open in its middle, up to the floor over it)
			for (i in 1...floors.length) {
				var f = floors[i];
				if (kinds[i] != 1 || f.length != 2)
					continue;
				var xa = f[0][0];
				if (xa <= 0 || gr(xa, ys[i] - 3))
					continue;
				for (y in ys[i] - 2...ys[i]) {
					setc(xa, y, 1);
					setc(W - 1 - xa, y, 1);
				}
				tag("basin");
				break;
			}
		} else if (g.chance(0.3)) {
			// (a lip: a wall of 2 cases under the end of a floor, over the air)
			var i = g.rnd(floors.length - 1);
			var f = floors[i];
			var p = f[g.rnd(f.length)];
			var x = g.chance(0.5) ? p[0] : p[1];
			if (!gr(x, ys[i] + 1) && !gr(x, ys[i] + 2) && !gr(x, ys[i] + 3)) {
				setc(x, ys[i] + 1, 1);
				setc(x, ys[i] + 2, 1);
				if (mirror) {
					setc(W - 1 - x, ys[i] + 1, 1);
					setc(W - 1 - x, ys[i] + 2, 1);
				}
				tag("lip");
			}
		}
	}

	// a floor of the first levels: 0 a long one in the middle, 1 a pair around a gap in the middle, 2 two from the sides,
	// 3 a middle between two ends, 4 (not mirrored) one or two anywhere; null when it does not fit
	function fewRow(kind:Int, bottom:Bool, mirror:Bool):Array<Array<Int>> {
		inline function mid(n:Int):Array<Int>
			return [9 - (n >> 1), 8 + (n >> 1)];
		switch (kind) {
			case 0:
				return [mid(bottom ? 2 * g.range(5, 7) : 2 * g.range(3, 6))];
			case 1:
				// (the gap of 2 an orange hops over, or wider)
				var gap = bottom ? 2 : [2, 2, 4, 6][g.rnd(4)];
				var len = bottom ? g.range(5, 7) : g.range(3, 6);
				var x1 = 8 - (gap >> 1);
				var x0 = x1 - len + 1;
				if (x0 < 0)
					return null;
				return [[x0, x1], [W - 1 - x1, W - 1 - x0]];
			case 2:
				var len = g.range(3, 7);
				return [[0, len - 1], [W - len, W - 1]];
			case 3:
				var e = g.range(2, 3);
				var m = 2 * g.range(2, bottom ? 5 : 4);
				var md = mid(m);
				if (md[0] - e < 2)
					return null;
				return [[0, e - 1], md, [W - e, W - 1]];
			default:
				// (not mirrored: a long one anywhere, sometimes a second one beyond a gap)
				var len = bottom ? g.range(9, 13) : g.range(5, 10);
				var x0 = bottom ? g.range(2, W - len - 2) : g.rnd(W - len + 1);
				var row = [[x0, x0 + len - 1]];
				var room = x0 >= W - (x0 + len) ? x0 : W - (x0 + len);
				if (!bottom && room >= 5 && g.chance(0.6)) {
					var gap = g.chance(0.5) ? 2 : g.range(3, 4);
					var l2 = g.range(3, Std.int(Math.min(6, room - gap)));
					if (l2 >= 3) {
						if (x0 >= W - (x0 + len))
							row.unshift([x0 - gap - l2, x0 - gap - 1]);
						else
							row.push([x0 + len + gap, x0 + len + gap + l2 - 1]);
					}
				}
				return row;
		}
	}

	// the columns where two floors are both there (a bad of the lower one jumps up to the upper one there)
	static function overlap(a:Array<Array<Int>>, b:Array<Array<Int>>):Int {
		var n = 0;
		for (x in 0...W) {
			var ina = false;
			var inb = false;
			for (p in a)
				if (x >= p[0] && x <= p[1])
					ina = true;
			for (p in b)
				if (x >= p[0] && x <= p[1])
					inb = true;
			if (ina && inb)
				n++;
		}
		return n;
	}

	static function same(a:Array<Array<Int>>, b:Array<Array<Int>>):Bool {
		if (a.length != b.length)
			return false;
		for (i in 0...a.length)
			if (a[i][0] != b[i][0] || a[i][1] != b[i][1])
				return false;
		return true;
	}

	static function cover(a:Array<Array<Int>>):Int {
		var n = 0;
		for (p in a)
			n += p[1] - p[0] + 1;
		return n;
	}

	// a ladder: two walls standing on the bottom (or hanging), its rungs between them every 3 rows, a hole of 2 at one
	// end then the other (the way down zigzags inside); one in the middle of the zone, or two mirrored
	function mLadder(z:DZone) {
		var rr = zr(z);
		if (rr.length < 3)
			return;
		var mid = centered(z);
		var w = z.x1 - z.x0 + 1;
		var two = mid && w >= 16 && g.chance(0.6);
		var grounded = z.y1 >= B - 1 && g.chance(0.6);
		var bot = grounded ? B : rr[rr.length - 1];
		// (one in the middle, mirrored: 6 cases inside, its rungs open in the middle then on both sides; else 4 or 5
		// cases inside, its rungs open at one end then the other)
		var inner = mid && !two ? 6 : (g.chance(0.5) ? 4 : 5);
		var xa0 = two ? z.x0 + g.range(1, 2) : (mid ? 5 : z.x0 + ((w - inner - 2) >> 1));
		tag((two ? "two" : "one") + (grounded ? "" : "-hang"));
		for (xa in (two ? [xa0] : [xa0])) {
			var xb = xa + inner + 1;
			col(xa, rr[0], bot);
			col(xb, rr[0], bot);
			for (k in 1...rr.length) {
				var y = rr[k];
				for (x in xa + 1...xb) {
					var on = if (mid && !two)
						(k % 2 == 1 ? (x < 8 - 0 && x <= xa + 2) || (x > 9 && x >= xb - 2) : (x >= 8 && x <= 9))
					else
						(k % 2 == 1 ? x > xa + 2 : x < xb - 2);
					if (on)
						c(x, y);
				}
			}
			// (caps on the walls: the tops of the ladder)
			h(xa - 2, xa - 1, rr[0]);
			h(xb + 1, xb + 2, rr[0]);
		}
	}

	// a level split in two by a wall from the top down to the bottom, a half under a roof: Igor goes there only by the
	// teleporters on both sides of the wall (at the same row: they lead to each other)
	function split(p:DPlan) {
		sym = false;
		var top = rows[0];
		// (the roof 2 rows over the first floor: the bads jumping over a gap there do not hit it and fall)
		var yw = Std.int(Math.max(1, top - 3));
		// (a wall of one case in the middle or a little aside, each teleporter at its own height: two levels split in two
		// never alike)
		var a = g.range(7, 10);
		var rl = rows[g.range(1, 2)];
		var rr = rows[g.range(1, 2)];
		tag("teleporters");
		tag("wall" + a + (rl == rr ? "" : "-steps"));
		motif(p.main, {x0: 0, x1: a - 2, y0: top, y1: B - 1, side: -1});
		motif(p.other, {x0: a + 2, x1: W - 1, y0: top, y1: B - 1, side: 1});
		// (the wall, the roof of the right half; the level is flipped half the time)
		for (y in yw...B + 1)
			setc(a, y, 1);
		for (x in a + 1...W)
			setc(x, yw, 1);
		for (x in a + 1...W)
			for (y in yw + 1...top)
				setc(x, y, 0);
		// (the teleporters: their floor and their lintel against the wall, their place cleared)
		for (t in [{x: a - 1, o: a - 2, r: rl}, {x: a + 1, o: a + 2, r: rr}]) {
			for (x in [t.x, t.o])
				for (y in t.r - 3...t.r + 1)
					setc(x, y, 0);
			for (x in [t.x, t.o]) {
				setc(x, t.r, 1);
				setc(x, t.r - 3, 1);
			}
			setc(t.x, t.r - 1, Data.FIELD_TELEPORT);
			setc(t.x, t.r - 2, Data.FIELD_TELEPORT);
		}
		g.designTeles = true;
	}

	// a cellar at the bottom of the level, reached only by a teleporter (its twin is put on the ways of Igor:
	// LevelFeatures.closeTele): a room of the bottom under a roof of one case, drawn with the thin lines of the level (Igor
	// never goes down through a ground; out of it he jumps up through its roof or takes the teleporter back), on a side
	// or in the middle, 5 to 8 cases wide; its teleporter at one end, a laser of black bombs beside it (Igor goes through
	// it coming in: the bombs kill the fruits shut there, their ice cannot go out), its fruits further on
	function cellar() {
		var was = sym;
		sym = false;
		var w = g.range(5, 8);
		var where = g.rnd(3);
		var x0 = where == 0 ? 0 : (where == 1 ? W - w : g.range(3, W - 3 - w));
		var x1 = x0 + w - 1;
		var roof = B - 3;
		// (its walls: none against a side of the screen)
		var bx0 = x0 > 0 ? x0 - 1 : 0;
		var bx1 = x1 < W - 1 ? x1 + 1 : W - 1;
		for (x in bx0...bx1 + 1) {
			for (y in roof...B)
				setc(x, y, 0);
			setc(x, roof, 1);
			setc(x, B, 1);
		}
		for (y in roof...B) {
			if (x0 > 0)
				setc(x0 - 1, y, 1);
			if (x1 < W - 1)
				setc(x1 + 1, y, 1);
		}
		// (the teleporter at one end, the laser beside it, both held by the roof and the bottom)
		var atLeft = g.chance(0.5);
		var tx = atLeft ? x0 : x1;
		var dir = atLeft ? 1 : -1;
		setc(tx, B - 2, Data.FIELD_TELEPORT);
		setc(tx, B - 1, Data.FIELD_TELEPORT);
		setc(tx + dir, B - 2, -2);
		setc(tx + dir, B - 1, -2);
		// (its fruits between them: the ones that stay on their floor first, one or two)
		var ids:Array<Int> = [];
		if (g.lineup != null) {
			for (id in [Data.BAD_FRAISE, Data.BAD_CERISE, Data.BAD_CITRON, Data.BAD_ORANGE, Data.BAD_POIRE])
				if (g.lineup.list.indexOf(id) >= 0 && ids.indexOf(id) < 0)
					ids.push(id);
			for (id in g.lineup.list)
				if (id != Data.BAD_BALEINE && ids.indexOf(id) < 0)
					ids.push(id);
		}
		var spots:Array<{id:Int, x:Int, y:Int}> = [];
		var n = w >= 7 && ids.length > 0 ? 2 : 1;
		for (k in 0...Std.int(Math.min(n, ids.length)))
			spots.push({id: ids[k], x: tx + dir * (3 + k * 2), y: B - 1});
		g.close = {x0: x0, x1: x1, y: B - 1, tele: tx, spots: spots, box: {x0: bx0, x1: bx1, y0: roof, y1: B}};
		tag("cellar" + (where == 2 ? "-mid" : "") + w);
		sym = was;
		if (sym)
			sym = false;
	}

	// the corner of a nest (LevelFeatures.nest puts its perch and the red laser): high in a corner nothing within 5
	// cases of the perch down to 2 rows under it (only the jump of a red bomb reaches it), a ledge 5 rows under the
	// perch where Igor stands to jump; the platform where he comes in on the other side (entry)
	function nestCorner() {
		var was = sym;
		sym = false;
		var left = g.chance(0.5);
		inline function X(x:Int):Int
			return left ? x : W - 1 - x;
		var py = g.range(4, 5);
		for (x in 0...8)
			for (y in 0...py + 3)
				setc(X(x), y, 0);
		var fy = py + 5;
		for (x in 0...5)
			for (y in py + 3...fy)
				setc(X(x), y, 0);
		for (x in 0...5)
			setc(X(x), fy, 1);
		nestSide = left ? -1 : 1;
		tag("nest");
		sym = was;
		if (sym)
			sym = false;
	}

	// (the side of the corner of a nest: -1 left, 1 right)
	var nestSide:Int = 0;

	// ---------------------------------------------------------------- the bottom

	// the ways out of the bottom: in each room between two walls standing on it (else the ice falling there stays), 3
	// cases (4 in the middle of a mirrored level), under columns that have a ground over them (Igor coming in falling
	// there lands), at least one
	function exits() {
		var y = B - 1;
		var made = 0;
		var x = 0;
		var lim = sym ? 9 : W;
		while (x < lim) {
			if (m[x][y] > 0) {
				x++;
				continue;
			}
			var a = x;
			while (x < W && m[x][y] <= 0)
				x++;
			var b = x - 1;
			var wd = b - a + 1;
			if (g.vault != null && a >= g.vault.x0 && b <= g.vault.x1)
				continue;
			if (g.close != null && a >= g.close.box.x0 && b <= g.close.box.x1)
				continue;
			var hw = wd >= 5 ? 3 : wd;
			if (sym && a <= 8 && b >= 9)
				hw = Std.int(Math.min(4, wd));
			if (wd <= 2 && !(a == 0 || b == W - 1))
				continue;
			// (the place of the hole: the middle of the room first, then aside, where the columns are covered)
			var best = -1;
			var bd = 99;
			for (hx in a...b - hw + 2) {
				var ok = true;
				for (k in 0...hw)
					if (!coveredAbove(hx + k) || inVault(hx + k))
						ok = false;
				if (sym && a <= 8 && b >= 9 && hx + hx + hw - 1 != W - 1)
					ok = false;
				var d = Std.int(Math.abs((hx + hx + hw - 1) - (a + b)));
				if (ok && d < bd) {
					bd = d;
					best = hx;
				}
			}
			// (no place with ground over it: a ledge over the middle of the room, then the way out under it)
			if (best < 0 && wd >= 3) {
				var hx = across(a, b) ? (W - hw) >> 1 : a + ((wd - hw) >> 1);
				var free = true;
				for (k in 0...hw)
					if (inVault(hx + k))
						free = false;
				if (free && coverOver(hx, hx + hw - 1))
					best = hx;
			}
			if (best >= 0) {
				for (k in 0...hw)
					c(best + k, B, 0);
				made++;
			}
		}
		if (made == 0) {
			// (no room for a way out by the walls: the middle, or a side)
			for (hx in [7, 1, 13, 4]) {
				var hw = hx == 7 ? 4 : 3;
				var ok = true;
				for (k in 0...hw)
					if (!coveredAbove(hx + k) || m[hx + k][B - 1] > 0 || inVault(hx + k) || g.inClose(hx + k, B))
						ok = false;
				if (ok) {
					for (k in 0...hw)
						c(hx + k, B, 0);
					break;
				}
			}
		}
	}

	// a column of the vault (or of its mirror in a mirrored level): no way out under it
	function inVault(x:Int):Bool {
		var v = g.vault;
		if (v == null)
			return false;
		return (x >= v.x0 && x <= v.x1) || (sym && W - 1 - x >= v.x0 && W - 1 - x <= v.x1);
	}

	inline function across(a:Int, b:Int):Bool {
		return sym && a <= 8 && b >= 9;
	}

	// a ledge of the level over the columns a..b (on its lowest floor row where it fits)
	function coverOver(a:Int, b:Int):Bool {
		var rs = rows.copy();
		rs.reverse();
		for (ry in rs)
			if (ledgeFits(a, b, ry)) {
				h(a, b, ry);
				return true;
			}
		return false;
	}

	// a ground in the column over the bottom (Igor coming in falling there lands on it)
	function coveredAbove(x:Int):Bool {
		for (y in 1...B)
			if (m[x][y] > 0)
				return true;
		return false;
	}

	// ---------------------------------------------------------------- the entry, the columns, the cleaning

	// the platform where Igor comes in at the top (a platform of the top rows near the middle, free over it): when the
	// motifs have none, a lintel in the middle; the first level (the start of a game): at mid-height
	function entry() {
		var first = g.depth == 0;
		var ya = first ? START_Y0 + 1 : 3;
		var yb = first ? START_Y1 : 6;
		for (y in ya...yb + 1)
			for (x in 4...14)
				if (m[x][y] > 0 && m[x][y - 1] <= 0 && m[x][y - 2] <= 0 && !g.inClose(x, y))
					return;
		var len = 4;
		var ys = first ? [for (r in rows) if (r >= ya && r <= yb) r] : [rows[0]];
		for (y in ys) {
			// (away from the corner of a nest)
			var x0 = nestSide < 0 ? 9 : (nestSide > 0 ? 5 : (W - len) >> 1);
			if (ledgeFits(x0, x0 + len - 1, y)) {
				h(x0, x0 + len - 1, y);
				return;
			}
		}
	}

	// every column has a ground under the top (Igor comes in falling where he left the level above): a run of columns
	// without one gets a ledge over it on a floor row, apart from everything (never joined to another platform: that
	// would shut a way down)
	function coverColumns() {
		var lim = sym ? 9 : W;
		var x = 0;
		while (x < lim) {
			if (coveredAbove(x) || m[x][B] > 0) {
				x++;
				continue;
			}
			var a = x;
			while (x < lim && !coveredAbove(x) && m[x][B] <= 0)
				x++;
			var b = x - 1;
			if (sym && b == 8)
				b = 8;
			if (a == b) {
				if (a + 1 < W && (!sym || a < 8))
					b = a + 1;
				else
					a = a - 1;
			}
			var rs = rows.copy();
			rs.reverse();
			for (ry in rs)
				if (ledgeFits(a, b, ry)) {
					h(a, b, ry);
					break;
				}
		}
	}

	// a ledge a..b at the row y touches nothing on its row, has room over it (2 rows) and nothing just under it
	function ledgeFits(a:Int, b:Int, y:Int):Bool {
		for (x in a - 1...b + 2)
			if (g.inb(x, y) && m[x][y] != 0)
				return false;
		for (x in a...b + 1)
			for (yy in [y - 2, y - 1, y + 1])
				if (g.inb(x, yy) && m[x][yy] != 0)
					return false;
		return true;
	}

	// no case of ground that reads as rubble: a stub of one case out of a wall or under a platform, a piece of 1 or 2
	// cases alone
	function tidy() {
		for (pass in 0...2) {
			for (x in 0...W)
				for (y in 1...B) {
					if (m[x][y] <= 0)
						continue;
					var l = gr(x - 1, y);
					var r = gr(x + 1, y);
					var u = gr(x, y - 1);
					var d = gr(x, y + 1);
					var n = (l ? 1 : 0) + (r ? 1 : 0) + (u ? 1 : 0) + (d ? 1 : 0);
					if (n != 1)
						continue;
					// (its only neighbour goes the other way: a stub)
					var stub = if (l || r) {
						var nx = l ? x - 1 : x + 1;
						(gr(nx, y - 1) || gr(nx, y + 1)) && !gr(nx + (l ? -1 : 1), y);
					} else {
						var ny = u ? y - 1 : y + 1;
						(gr(x - 1, ny) || gr(x + 1, ny)) && !gr(x, ny + (u ? -1 : 1));
					};
					if (stub)
						setc(x, y, 0);
				}
			// pieces of 1 or 2 cases
			var seen = [for (x in 0...W) [for (y in 0...H) false]];
			for (x in 0...W)
				for (y in 1...B) {
					if (m[x][y] <= 0 || seen[x][y])
						continue;
					var cells = [{x: x, y: y}];
					seen[x][y] = true;
					var i = 0;
					while (i < cells.length) {
						var p = cells[i++];
						for (d in [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
							var nx = p.x + d[0];
							var ny = p.y + d[1];
							if (nx >= 0 && nx < W && ny >= 0 && ny < B && m[nx][ny] > 0 && !seen[nx][ny]) {
								seen[nx][ny] = true;
								cells.push({x: nx, y: ny});
							}
						}
					}
					if (cells.length <= 1 || (cells.length == 2 && cells[0].x == cells[1].x))
						for (p in cells)
							m[p.x][p.y] = 0;
				}
		}
	}

	inline function gr(x:Int, y:Int):Bool {
		return x >= 0 && x < W && y >= 0 && y < H && m[x][y] > 0;
	}

	// the starts of the platforms of a row from x0 to x1 (L long, gap apart), centered, shifted by half a step on the
	// odd rows of bricks
	function latticeRow(x0:Int, x1:Int, L:Int, gap:Int, shift:Int):Array<Int> {
		var P = L + gap;
		var span = x1 - x0 + 1;
		var out:Array<Int> = [];
		var n = Std.int((span + gap) / P);
		if (shift == 1)
			n = n - 1 >= 1 ? n - 1 : n + 1;
		var used = n * L + (n - 1) * gap;
		while (used > span && n > 1) {
			n--;
			used = n * L + (n - 1) * gap;
		}
		var start = x0 + Std.int((span - used) / 2);
		// (an odd margin in a mirrored zone: the gaps of the middle one case wider)
		var odd = (span - used) % 2 == 1 && sym && x0 + x1 == W - 1;
		for (i in 0...n) {
			var s = start + i * P + (odd && i >= (n + 1) >> 1 ? 1 : 0);
			if (s >= x0 && s + L - 1 <= x1)
				out.push(s);
		}
		return out;
	}

	// the level the other way (left to right)
	function flip() {
		for (x in 0...(W >> 1))
			for (y in 0...H) {
				var v = m[x][y];
				m[x][y] = m[W - 1 - x][y];
				m[W - 1 - x][y] = v;
			}
		if (g.vault != null) {
			var v = g.vault;
			g.vault = {x0: W - 1 - v.x1, x1: W - 1 - v.x0, y: v.y, top: v.top, door: [for (d in v.door) {x: W - 1 - d.x, y: d.y}]};
		}
		for (gt in gates)
			for (p in gt)
				p.x = W - 1 - p.x;
		if (g.close != null) {
			var c = g.close;
			g.close = {x0: W - 1 - c.x1, x1: W - 1 - c.x0, y: c.y, tele: W - 1 - c.tele,
				spots: [for (s in c.spots) {id: s.id, x: W - 1 - s.x, y: s.y}],
				box: {x0: W - 1 - c.box.x1, x1: W - 1 - c.box.x0, y0: c.box.y0, y1: c.box.y1}};
		}
	}

	// ---------------------------------------------------------------- drawing

	// a passage made for a laser (cases of a row or of a column), and its mirror
	function addGate(cells:Array<GPt>) {
		gates.push(cells);
		if (sym) {
			var mc = [for (c in cells) {x: W - 1 - c.x, y: c.y}];
			var same = true;
			for (i in 0...cells.length)
				if (mc[i].x != cells[i].x)
					same = false;
			if (!same)
				gates.push(mc);
		}
	}

	inline function setc(x:Int, y:Int, v:Int) {
		if (x >= 0 && x < W && y >= 0 && y < H)
			m[x][y] = v;
	}

	// a case of ground, and its mirror in a mirrored level
	function c(x:Int, y:Int, ?v:Int = 1) {
		setc(x, y, v);
		if (sym)
			setc(W - 1 - x, y, v);
	}

	function h(x0:Int, x1:Int, y:Int, ?v:Int = 1) {
		for (x in Std.int(Math.min(x0, x1))...Std.int(Math.max(x0, x1)) + 1)
			c(x, y, v);
	}

	function col(x:Int, y0:Int, y1:Int, ?v:Int = 1) {
		for (y in Std.int(Math.min(y0, y1))...Std.int(Math.max(y0, y1)) + 1)
			c(x, y, v);
	}

	function isSym():Bool {
		for (y in 0...H)
			for (x in 0...9)
				if (m[x][y] != m[W - 1 - x][y])
					return false;
		return true;
	}
}
