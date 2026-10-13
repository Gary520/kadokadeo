package hammerfest;

import hammerfest.Levels.LevelData;

typedef GSeg = {y:Int, x0:Int, x1:Int}; // standing cells (the row over the ground) x0..x1
typedef GPt = {x:Int, y:Int};

// a room that can be shut (the vault): the row y where its bads stand (over its floor) from x0 to x1, its inside from
// the row top, the cases of its door (a window of 2 cases in a wall)
typedef GVault = {x0:Int, x1:Int, y:Int, top:Int, door:Array<GPt>};

// The levels of the well, made at random (the random of the game: a seed gives its well, the replay its levels), each
// one drawn around an idea, like a level made by hand:
// - its bads drawn first (LevelCast: the kinds coming one after the other along the well, a kind leading each level;
//   the leapers from level 25);
// - its features drawn for the depth (LevelFeatures: none, one or two: a vault, lasers on its passages, no bombs for a
//   while, a pit of spikes, spikes on the ways, teleporters, saws, a nest);
// - its drawing (LevelDesign): a way of drawing chosen for its bads and its dimension (spines, a frame, a lattice, a
//   tree, rooms, slopes, stalactites, arcades), with its variants and its measures, mirrored more often than not;
// - the ways of Igor in it (LevelRoutes: where he has to go), his moves (jumps of 3 cases up, 4 across), every bad and the
//   bottom reached, the ice of every bad able to go out of the level (or a laser of black bombs on his way);
// - its bads placed for what they do (LevelBads: the strawberries far apart, their ball across the ways of Igor and
//   between him and them, the lemons over and under his ways, the apples along his rows, the pears over the places he
//   walks...), the devices and hazards put where they mean something (LevelFeatures).
// A few levels are drawn that way: the best one is kept (rated on the bads in their places, on the look of a level made
// by hand, on not being like the last levels).
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

	// the chapters of 5 levels: calm at their start, the hardest at their end (factor of the hazards)
	public static function rhythm(depth:Int):Float {
		return LevelCast.rhythm(depth);
	}

	static function introKind(depth:Int):Int {
		return LevelCast.introKind(depth);
	}

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

	public var m:Array<Array<Int>>;
	public var bads:Array<{id:Int, x:Int, y:Int}>;
	public var px:Int;
	public var py:Int;
	public var kind:String;
	public var variant:String = "";
	// the passages the structure made for lasers (LevelDesign)
	public var designGates:Array<Array<GPt>> = [];
	// the teleporters drawn with the level (a level split in two), the room shut reached by a teleporter
	public var designTeles:Bool = false;
	// the idea of the level (LevelConcept), its bottom left open over the void
	public var concept:LevelConcept.Concept = null;
	public var open:Bool = false;
	// the columns without ground once the level is drawn (over the void: the columns of the void)
	public var openBase:Int = 0;
	public var close:LevelDesign.DClose = null;
	#if gentest
	public var designMap:Array<Array<Int>>;
	public static var lastDesign:Array<Array<Int>>;
	#end
	public var sym:Bool;

	var depth:Int;
	var special:Array<GPt>;
	var scores:Array<GPt>;
	var danger:Array<Array<Bool>>; // spikes (and the place of the head of Igor under the spikes of a ceiling)
	var busy:Array<Array<Bool>>; // cases taken (bads, fields, items)
	var reach:Array<Array<Bool>>; // standing cells Igor can reach
	var exitOk:Bool;
	var teles:Array<{a:GPt, b:GPt}>;
	var floors:Array<Int>; // rows of the floors of the shape
	var noBads:Array<GSeg>; // segments kept for the hazards (saws)
	var missing:Int;

	// the features of the level (LevelFeatures.draw), its vault (LevelDesign), the lasers put
	public var want:Array<String> = [];
	public var vault:GVault = null;
	public var gates:Array<{cells:Array<GPt>, v:Int}> = [];
	// the nest of the red laser (LevelFeatures.nest), the jump of the red bombs in the moves of Igor then
	public var nest:GVault = null;
	// the roofs of the shelters of the strawberries (LevelFeatures.shelters): no saw goes around them
	public var roofs:Array<GPt> = [];
	public var redJump:Bool = false;

	var routes:LevelRoutes;
	var feats:LevelFeatures;

	public var openAtEnd:Array<GPt> = [];
	public var levers:Array<Levels.LeverData> = [];

	var entry:Array<Bool> = [];

	// the bads of the level (LevelCast) and how well they fit their places (LevelBads)
	public var lineup:LevelCast.Cast;
	public var roleFit:Float = 0;
	public var leadFit:Float = 0;
	public var guarded:Int = 0;

	var hints:Array<GPt> = null;

	public function new(depth:Int) {
		this.depth = depth;
	}

	public function wants(f:String):Bool {
		return want != null && want.indexOf(f) >= 0;
	}

	public static var lastKind:String;
	public static var lastSym:Bool;
	public static var lastBudget:Float;
	public static var lastCast:LevelCast.Cast;
	public static var lastFit:Float;
	public static var lastWant:Array<String>;
	public static var lastGates:Array<{cells:Array<GPt>, v:Int}>;
	public static var lastGuard:Int;
	public static var lastExpo:Array<Int> = [];
	public static var lastStraw:Array<{x:Int, y:Int, e:Int}> = [];
	public static var lastLike:Float = 0;
	public static var lastConcept:String = "";
	public static var lastOpen:Bool = false;

	// the ground of the last levels (the last one first): a level like one of them loses
	static var recentMaps:Array<Array<Array<Int>>> = [];
	// the plans of the last levels (LevelDesign.plan), the last one first: their motifs do not come back soon
	static var plans:Array<LevelDesign.DPlan> = [];
	// what the last levels look like (LevelDesign.traits), the last one first
	static var recentTraits:Array<Int> = [];
	// the drawings of the last 12 levels (layout, motifs, variants: "bands:arches|hooks/ceiling-t,sizes"): the very same
	// drawing does not come back so soon
	static var recentLabels:Array<String> = [];
	public static var lastTraits:Int = 0;

	// levels drawn and rated for a plan
	static inline var TRIES = 6;

	// test harness: every level drawn with this layout or this motif (LevelDesign.LAYOUTS, the motifs)
	public static var forceKind:String = null;

	public static function reset() {
		LevelCast.reset();
		LevelConcept.reset();
		recentMaps = [];
		plans = [];
		recentTraits = [];
		recentLabels = [];
		zoneSkin = null;
		zoneEnd = -1;
	}

	// the bads of the level and its features drawn first, then its plan (LevelDesign.plan: a layout and its motifs,
	// drawn for the bads of the level, the dimension, never the motifs of the last levels), several levels drawn with
	// it: the best one is kept; another plan when none of them is right (or when it is like one of the last levels)
	public static function make(depth:Int):LevelData {
		// the idea of the level first: its bads, its devices, its drawing are made for it
		var concept = LevelConcept.pick(depth);
		// (the bottom left open over the void, for the whole level: the bottom floor holds bads no longer, a few bads
		// less; a jump missed costs a life)
		var open = Cs.rnd(1000) < concept.open * 1000;
		var lineup = LevelCast.make(depth, concept, open);
		lastCast = lineup;
		var want = LevelFeatures.draw(depth, lineup, concept);
		var best:LevelGen = null;
		var bestRate = -1.0e9;
		var bestPlan:LevelDesign.DPlan = null;
		var tried:Array<LevelDesign.DPlan> = [];
		// (the device of the idea of the level drawn: a level of kiwi mines without its green laser is not one)
		function ownOk(g:LevelGen):Bool {
			for (f in concept.want)
				if (want.indexOf(f) >= 0 && !g.realized(f))
					return false;
			return true;
		}
		// (the very same drawing as one of the last 12 levels)
		function seen(g:LevelGen):Bool {
			return recentLabels.indexOf(g.variant != "" ? g.variant : g.kind) >= 0;
		}
		// (two plans a round, three levels drawn with each: the one the most unlike the last levels wins; two rounds more
		// when the device of the idea is still missing or the drawing is one of the last levels)
		for (round in 0...5) {
			if (round >= 3 && (best == null || (ownOk(best) && !seen(best))))
				break;
			for (k in 0...2) {
				var p = LevelDesign.plan(depth, lineup, plans, forceKind, want, tried, concept, open);
				tried.unshift(p);
				for (i in 0...(TRIES >> 1)) {
					var g = new LevelGen(depth);
					g.lineup = lineup;
					g.want = want;
					g.concept = concept;
					if (!g.build(p))
						continue;
					var r = g.rate() - 1.6 * LevelDesign.sameLook(LevelDesign.traits(g.m), recentTraits);
					if (seen(g))
						r -= 5;
					if (r > bestRate) {
						best = g;
						bestRate = r;
						bestPlan = p;
					}
				}
			}
			if (best != null && (forceKind != null || best.likeness() <= 0.62) && ownOk(best) && (forceKind != null || !seen(best)))
				break;
		}
		// (nothing right with these features: the device of the idea only, then none; fewer bads, the supporting ones
		// going first)
		if (best == null)
			for (i in 0...20) {
				var g = new LevelGen(depth);
				var drop = Std.int(i / 5);
				// (the leapers stay: they fly, they need no place on a floor)
				var walk = [for (id in lineup.list) if (id != Data.BAD_BALEINE) id];
				var fly = [for (id in lineup.list) if (id == Data.BAD_BALEINE) id];
				g.lineup = {lead: lineup.lead, intro: lineup.intro, list: walk.slice(0, Std.int(Math.max(2, walk.length - drop))).concat(fly)};
				// (the device of the idea kept for the first tries)
				g.want = i < 10 ? [for (f in want) if (concept.want.indexOf(f) >= 0) f] : [];
				#if gentest
				fails.set("relaxed", (fails.exists("relaxed") ? fails.get("relaxed") : 0) + 1);
				#end
				g.concept = concept;
				var p = LevelDesign.plan(depth, g.lineup, plans, forceKind, g.want, null, concept, i < 10 ? open : false);
				if (g.build(p) && (i >= 10 || forceKind != null || !seen(g))) {
					best = g;
					bestPlan = p;
					break;
				}
			}
		if (best == null) {
			best = new LevelGen(depth);
			best.fallback();
		}
		lastLike = best.likeness();
		recentMaps.unshift([for (c in best.m) [for (v in c) v > 0 ? 1 : 0]]);
		if (recentMaps.length > 10)
			recentMaps.pop();
		if (bestPlan != null) {
			plans.unshift(bestPlan);
			if (plans.length > 12)
				plans.pop();
		}
		recentTraits.unshift(LevelDesign.traits(best.m));
		if (recentTraits.length > 6)
			recentTraits.pop();
		lastTraits = recentTraits[0];
		lastKind = best.variant != "" ? best.variant : best.kind;
		recentLabels.unshift(lastKind);
		if (recentLabels.length > 12)
			recentLabels.pop();
		lastConcept = concept.id;
		lastOpen = best.open;
		LevelConcept.remember(concept.id);
		// (the idea of the level in its label: the test harness, the debug builds)
		lastKind = concept.id + (best.open ? " (vide) " : " ") + lastKind;
		#if gentest
		lastDesign = best.designMap;
		#end
		lastSym = best.sym;
		lastFit = best.roleFit;
		lastWant = [for (f in best.want) if (best.realized(f)) f];
		lastGates = best.gates;
		lastGuard = best.guarded;
		lastExpo = best.routes != null ? best.strawExposure() : [];
		lastStraw = [];
		if (best.routes != null) {
			var k = 0;
			for (b in best.bads)
				if (b.id == Data.BAD_FRAISE)
					lastStraw.push({x: b.x, y: b.y, e: lastExpo[k++]});
		}
		lastBudget = 0;
		for (id in lineup.list)
			lastBudget += LevelCast.cost(id);
		return best.data();
	}

	function clear() {
		m = [for (x in 0...W) [for (y in 0...H) 0]];
		bads = [];
		special = [];
		scores = [];
		teles = [];
		noBads = [];
		missing = 0;
		openAtEnd = [];
		levers = [];
		gates = [];
		vault = null;
		nest = null;
		redJump = false;
		roofs = [];
		designTeles = false;
		close = null;
		danger = [for (x in 0...W) [for (y in 0...H) false]];
		busy = [for (x in 0...W) [for (y in 0...H) false]];
	}

	// a level drawn with a plan (LevelDesign), its bads, its features: false when something is wrong in it
	function build(plan:LevelDesign.DPlan):Bool {
		clear();
		var lc = new LevelDesign(this);
		lc.draw(plan);
		variant = lc.variant;
		designGates = lc.gates;
		#if gentest
		designMap = [for (c in m) c.copy()];
		#end
		cleanup();
		// Igor comes in falling from the top where he left the level above: a ground under every column (over the void,
		// he is put over a ground: Game.safeEntry; the columns of the void stay open)
		if (!open) {
			repairColumns();
			if (openColumns() > 0)
				return fail("open");
		}
		openBase = openColumns();
		if (!placeStart())
			return fail("start");
		computeReach();
		if (!exitOk)
			return fail("exit");
		routes = new LevelRoutes(this);
		feats = new LevelFeatures(this);
		// the twin of the teleporter of the cellar, on the ways of Igor
		if (close != null && !feats.closeTele())
			return fail("close");
		if (close != null)
			noBads.push({y: close.y, x0: close.box.x0, x1: close.box.x1});
		// the laser of the vault, the shelters of the strawberries, the saws, the teleporters, the nest
		if (!feats.beforeBads())
			return fail("before");
		computeReach();
		if (!exitOk || !startOk())
			return fail("exit2");
		routes.compute();
		if (!placeBads())
			return fail("bads");
		// the lasers on the ways to the bads, the spikes
		if (!feats.afterBads())
			return fail("after");
		clearBadSpikes();
		if (!pocketsOk())
			return fail("pocket");
		dropLooseSpikes();
		if (!fieldsHeld())
			return fail("loose");
		if (!purposeful())
			return fail("purpose");
		placeItems();
		entry = entryColumns();
		if (entryCount() < 3)
			return fail("entry");
		return true;
	}

	// a feature drawn for the level is there
	function realized(f:String):Bool {
		return switch (f) {
			case "vault": vault != null && hasLaser(-2);
			case "gate": hasLaser(-3) || hasLaser(-4) || hasLaser(-5);
			case "disarm": hasLaser(Data.FIELD_PEACE);
			case "pit", "spikes": hasBad(Data.BAD_SPEAR);
			case "teleport": teles.length > 0;
			case "saws": hasBad(Data.BAD_SAW);
			case "nest": nest != null;
			default: false;
		}
	}

	function hasLaser(v:Int):Bool {
		for (x in 0...W)
			for (y in 0...H)
				if (m[x][y] == v)
					return true;
		return false;
	}

	function hasBad(id:Int):Bool {
		for (b in bads)
			if (b.id == id)
				return true;
		return false;
	}

	// every laser has a reason to be there: Igor goes through it (a passage of his ways: a case of each laser by a case he
	// reaches), a white one only after a laser without bombs (he has white bombs at the start of the level)
	function purposeful():Bool {
		var white = false;
		var peace = false;
		var seen = [for (x in 0...W) [for (y in 0...H) false]];
		for (x in 0...W)
			for (y in 0...H) {
				var v = m[x][y];
				if (v >= 0 || seen[x][y])
					continue;
				if (v == -1)
					white = true;
				if (v == Data.FIELD_PEACE)
					peace = true;
				// (the laser: its cases of the same id joined)
				var near = false;
				var st = [{x: x, y: y}];
				seen[x][y] = true;
				while (st.length > 0) {
					var c = st.pop();
					if (reachedNear(c.x, c.y))
						near = true;
					for (d in [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
						var nx = c.x + d[0];
						var ny = c.y + d[1];
						if (inb(nx, ny) && !seen[nx][ny] && m[nx][ny] == v) {
							seen[nx][ny] = true;
							st.push({x: nx, y: ny});
						}
					}
				}
				if (!near && v != Data.FIELD_TELEPORT) {
					#if gentest
					fail("purpose" + v);
					#end
					return false;
				}
			}
		return !white || peace;
	}

	// ---------------------------------------------------------------- bads

	function placeBads():Bool {
		// (the leapers fly: placed in the open, not on a platform)
		var flyers = 0;
		for (id in lineup.list)
			if (id == Data.BAD_BALEINE)
				flyers++;
		var list = [for (id in lineup.list) if (id != Data.BAD_BALEINE) id];
		// (crawlers on the walls deep in the well; not in a level made for its spikes: they would crawl over them)
		if (depth >= 8 && (concept == null || concept.id != "pics"))
			for (i in 0...Std.int(Math.min(3, (depth - 5) / 5 * rhythm(depth) * LevelTheme.of(depth).crawlers)))
				if (chance(0.6))
					list.push(Data.BAD_CRAWLER);
		var want = 0;
		for (id in lineup.list)
			if (id == lineup.lead)
				want++;
		var before = bads.copy();
		var busy0 = [for (c in busy) c.copy()];
		var missing0 = missing;
		for (attempt in 0...2) {
			var lb = new LevelBads(this);
			lb.hints = hints;
			lb.spots = close != null ? close.spots : [];
			lb.place({lead: lineup.lead == Data.BAD_BALEINE && list.length > 0 ? list[0] : lineup.lead, intro: lineup.intro, list: list});
			roleFit = lb.fit;
			leadFit = lb.leadFit;
			guarded = lb.guardedN;
			var real = 0;
			var leads = 0;
			for (b in bads) {
				if (b.id != Data.BAD_SPEAR && b.id != Data.BAD_SAW && b.id != Data.BAD_CRAWLER)
					real++;
				if (b.id == lineup.lead)
					leads++;
			}
			// (all of them, one missing at the most in a level of 6 or more; the leading kind there)
			var n = lineup.list.length - flyers;
			if (leads >= Std.int(Math.min(2, want)) && real >= n - (n >= 6 ? 1 : 0))
				return placeFlyers(flyers);
			// not enough places their ice can be kicked out from: like the original, a laser of black bombs on the way
			// to them (they kill the bads) and the bads placed again
			#if gentest
			fails.set("short" + (n - real), (fails.exists("short" + (n - real)) ? fails.get("short" + (n - real)) : 0) + 1);
			if (leads < Std.int(Math.min(2, want)))
				fails.set("noLead", (fails.exists("noLead") ? fails.get("noLead") : 0) + 1);
			#end
			if (attempt > 0 || depth < 3 || killerLaser())
				return false;
			bads = before.copy();
			busy = [for (c in busy0) c.copy()];
			missing = missing0;
			if (!addKillerLaser())
				return false;
			computeReach();
			if (!exitOk)
				return false;
			routes.compute();
		}
		return false;
	}

	// the leapers in the open: the middle of the biggest empty place (nothing around them), far from the place
	// where Igor lands at the start, apart from each other
	function placeFlyers(n:Int):Bool {
		var ly = py;
		while (ly < H - 1 && !canStand(px, ly))
			ly++;
		for (k in 0...n) {
			var best:GPt = null;
			var bv = -1.0e9;
			for (x in 2...W - 2)
				for (y in 4...H - 4) {
					var open = 0;
					var near = false;
					for (dx in -3...4)
						for (dy in -3...4) {
							var xx = x + dx;
							var yy = y + dy;
							if (!inb(xx, yy))
								continue;
							if (m[xx][yy] == 0)
								open++;
							else if (Math.abs(dx) <= 1 && Math.abs(dy) <= 1)
								near = true;
						}
					// (in the air, not too close to where Igor lands; better with nothing around it, far from him)
					if (m[x][y] != 0 || busy[x][y])
						continue;
					var d = Math.abs(x - px) + Math.abs(y - ly);
					if (d < 5)
						continue;
					var v = open + Math.min(14, d) * 0.5 + rnd(100) / 50 - (near ? 8 : 0) - Math.max(0, 8 - d) * 3;
					for (b in bads)
						if (b.id == Data.BAD_BALEINE)
							v -= Math.max(0, 8 - Math.abs(b.x - x) - Math.abs(b.y - y)) * 2;
					if (v > bv) {
						bv = v;
						best = {x: x, y: y};
					}
				}
			if (best == null) {
				#if gentest
				fails.set("flyer", (fails.exists("flyer") ? fails.get("flyer") : 0) + 1);
				#end
				missing++;
				continue;
			}
			bads.push({id: Data.BAD_BALEINE, x: best.x, y: best.y});
			mark(best.x, best.y);
		}
		return true;
	}

	// a laser of black bombs on a passage of the ways of Igor (the bads of the pockets behind it first)
	function addKillerLaser():Bool {
		return feats.killerGate() && killerLaser();
	}

	// ---------------------------------------------------------------- items

	// the places of the items on the platforms Igor reaches, apart from each other: the first special item where going is
	// worth it (in the vault, by the spikes, far from the start), the others spread
	function placeItems() {
		var segs = [for (s in segments()) if (segReached(s)) s];
		var cells:Array<GPt> = [];
		for (s in segs)
			for (x in s.x0...s.x1 + 1)
				if (!busy[x][s.y] && reach[x][s.y] && (Math.abs(x - px) + Math.abs(s.y - py) > 4))
					cells.push({x: x, y: s.y});
		if (cells.length == 0)
			return;
		var bv = -1.0;
		var bi = 0;
		for (i in 0...cells.length) {
			var p = cells[i];
			var v = routes != null && routes.dist != null && routes.dist[p.x * H + p.y] >= 0 ? Math.min(12, routes.dist[p.x * H + p.y]) * 0.3 : 0;
			if (vault != null && p.x >= vault.x0 && p.x <= vault.x1 && p.y >= vault.top && p.y <= vault.y)
				v += 5;
			// (in the cellar reached by a teleporter)
			if (inClose(p.x, p.y))
				v += 4;
			for (b in bads)
				if (b.id == Data.BAD_SPEAR && Math.abs(b.x - p.x) <= 2 && Math.abs(b.y - p.y) <= 2)
					v += 1.5;
			v += rnd(100) / 60;
			if (v > bv) {
				bv = v;
				bi = i;
			}
		}
		var first = cells.splice(bi, 1)[0];
		special.push(first);
		cells = [for (c in cells) if (Math.abs(c.x - first.x) + Math.abs(c.y - first.y) > 4) c];
		for (k in 0...4) {
			if (cells.length == 0)
				break;
			var p = cells.splice(rnd(cells.length), 1)[0];
			if (k == 0)
				special.push(p);
			else
				scores.push(p);
			cells = [for (c in cells) if (Math.abs(c.x - p.x) + Math.abs(c.y - p.y) > 4) c];
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
		// (the start of a game: Igor at mid-height, the levels built without room for it there lose)
		if (depth == 0 && py < LevelDesign.START_Y0)
			r -= 30;
		// (the first levels, "très faciles": few platforms, the light drawings win, a little more each level up to level
		// 8: the ground from 10 % of the screen, the platforms from 5)
		// (not the first levels drawn in the style of the original (0-5, mFew): their floors are what they are)
		if (depth < 10 && depth > LevelDesign.EASY_DEPTH) {
			var n = 0;
			for (x in 0...W)
				for (y in 0...H)
					if (m[x][y] > 0)
						n++;
			r -= Math.max(0, n / (W * H) - (0.10 + 0.012 * depth)) * 80;
			var plats = 0;
			for (s in segs)
				if (s.x1 - s.x0 >= 1 && s.y < H - 2)
					plats++;
			r -= 2.5 * Math.max(0, plats - (5 + 0.5 * depth));
		}
		r += 4.0 * reached / Math.max(1, segs.length);
		if (segs.length >= 7 && segs.length <= 24)
			r += 1;
		// open places (cases 4 cases away from any ground): the levels made by hand leave 5 to 10 % of the screen open
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
		r -= missing * 1.5;
		// the bads in the places made for what they do (LevelBads), the leading kind above all
		r += 2.5 * roleFit + 3.5 * leadFit;
		// the bads jump over the holes of the floors: nothing just over them
		r -= blockedGaps() * 2.0;
		// Igor can go back up to the top from most of the places
		r += 2.0 * wayBack();
		// coming in falling from anywhere, Igor can play
		r += 2.0 * entryCount() / W;
		// better without pockets (their bads killed only with the bombs of a black laser), but in the vault; a laser of
		// black bombs for them is a last resort
		r -= pockets() * (vault != null || close != null ? 0.1 : (killerLaser() ? 0.4 : 1.0));
		if (vault == null && close == null && hasLaser(-2))
			r -= 2.5;
		// the features drawn for the level there (the device of the idea of the level above all)
		for (f in want) {
			var own = concept != null && concept.want.indexOf(f) >= 0;
			r += realized(f) ? (own ? 6.0 : 2.5) : (own ? -6.0 : -1.5);
		}
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
		// long floors (the combos), and no dust of small pieces
		var longs = 0;
		for (s in segs)
			if (s.x1 - s.x0 + 1 >= 6)
				longs++;
		r += Math.min(3, longs) * 0.3;
		r -= loosePieces() * 0.8;
		// the strawberries out of the bombs from above
		for (e in strawExposure())
			r += e == 0 ? 1.2 : -Math.min(2.0, e * 0.3);
		// not like the last levels (the player must never think he has seen it before)
		var lk0 = likeness();
		r -= 8 * Math.max(0, lk0 - 0.3) + 20 * Math.max(0, lk0 - 0.5);
		// the look of a level made by hand (measured on the original, gen/look.py): the ends of the platforms lined up
		// with other ends, not too many long floors, none over another one (the way down zigzagging), big pieces
		var lk = looks();
		r += 4 * (lk.lined - 0.6) - 1.5 * lk.stack - 0.8 * Math.max(0, lk.long - 2) + 0.04 * Math.min(40, lk.biggest)
			- 0.8 * sticks();
		// (no hop over the void: a bad missing its jump would fall out of the level)
		r -= 3 * voidHops();
		var wideRows = 0;
		for (y in 2...H - 1) {
			var n = 0;
			for (x in 0...W)
				if (m[x][y] > 0)
					n++;
			if (n >= 11)
				wideRows++;
		}
		if (wideRows >= 3)
			r -= 2.5 * (wideRows - 2);
		return r + rnd(100) / 200;
	}

	function fallback() {
		clear();
		sym = true;
		kind = "fallback";
		floors = [4, 9, 14];
		for (x in 6...12)
			m[x][4] = G;
		for (x in 0...6) {
			m[x][9] = G;
			m[W - 1 - x][9] = G;
		}
		for (x in 4...14)
			m[x][14] = G;
		px = 8;
		py = 3;
		bads.push({id: Data.BAD_CERISE, x: 2, y: 8});
		bads.push({id: Data.BAD_CERISE, x: 15, y: 8});
		bads.push({id: Data.BAD_CERISE, x: 6, y: 13});
	}

	// skin of the levels: the same for 5 or 6 levels, a pair of the original of the difficulty of the depth
	static var zoneSkin:Array<Int> = null;
	static var zoneEnd:Int = -1;

	function data():LevelData {
		if (zoneSkin == null || depth >= zoneEnd) {
			var th = LevelTheme.of(depth);
			if (th.skins.length > 0) {
				// (a dimension: the skins of its levels; the table: rank, background, tiles)
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
			entry: entry,
			levers: levers,
			blocks: [],
			endBlocks: []
		};
	}

	// ---------------------------------------------------------------- random, map

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

	// ---------------------------------------------------------------- cleaning, start

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

	// columns still without ground (LevelDesign.coverColumns puts ledges over them): a shelf of 3 cases on a row of the
	// floors, free around (never a platform going on over the column: that would shut a way down)
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
					break;
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

	// Igor comes in at the top, in the middle as much as possible, on a platform of the top rows; at the start of a
	// game (the first level) at mid-height, not on the top of the level (he is born there, and born again there)
	function placeStart():Bool {
		var best:GPt = null;
		var bestV = 1.0e9;
		if (depth == 0)
			for (y in LevelDesign.START_Y0...LevelDesign.START_Y1)
				for (x in 2...W - 2) {
					if (!canStand(x, y) || m[x][y] < 0 || inClose(x, y))
						continue;
					var v = Math.abs(x - 8.5) + Math.abs(y - 8.5) * 1.5 + rnd(3);
					if (v < bestV) {
						bestV = v;
						best = {x: x, y: y};
					}
				}
		if (best == null)
			for (y in 1...6)
				for (x in 1...W - 1) {
					if (!canStand(x, y) || m[x][y] < 0 || inClose(x, y))
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
				if (inClose(x, 1))
					continue;
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
			// the jump of a red bomb (a level with a nest: Red.onExplode throws Igor about 7 cases up): 4 to 6 rows over
			// him, straight up or a case aside
			if (redJump)
				for (k in 4...7) {
					var clear = true;
					for (r in y - k - 1...y)
						if (!passUp(x, r))
							clear = false;
					if (!clear)
						break;
					for (d in 0...2) {
						var tx = x + dir * d;
						var ty = y - k;
						if (canStand(tx, ty) && (d == 0 || passable(tx, ty)))
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
	var moveTeleTo:Array<Array<Int>>; // (the ones through a teleporter)
	var moveOut:Array<Bool>;

	function buildMoves() {
		computeReach();
		var ok = exitOk;
		moveTo = [for (i in 0...W * H) null];
		moveTeleTo = [for (i in 0...W * H) null];
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
				var n0 = collected.length;
				drainTele();
				moveTo[x * H + y] = collected;
				moveTeleTo[x * H + y] = collected.slice(n0);
				moveOut[x * H + y] = exitOk;
			}
		collecting = false;
		exitOk = ok;
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

	// ---------------------------------------------------------------- the bombs of Igor from above

	// where a bomb falling down the column x rests by a bad standing on a platform (x0..x1, row y) and blows it: the row
	// of the bomb, -1 when it does nothing to the bad. The blast of a bomb on the ground reaches 3 cases around but not
	// the bads more than 1 case under it (Bomb.bombGetClose, Game.getClose): a bomb resting on a ceiling over the bad
	// does nothing, a bomb falling past the end of the platform down to a floor far under it neither
	function blastRest(x:Int, x0:Int, x1:Int, y:Int):Int {
		if (y < 1 || m[x][y - 1] > 0)
			return -1;
		var by = y - 1;
		while (by + 1 < H && m[x][by + 1] <= 0)
			by++;
		if (by + 1 >= H)
			return -1;
		var dx = x < x0 ? x0 - x : (x > x1 ? x - x1 : 0);
		return dx * dx + (by - y) * (by - y) > 9 ? -1 : by;
	}

	// the places of Igor over the bad from which a bomb comes down to rest by it (blastRest): kicked off the edge of a
	// platform 2 rows over its platform at least (the roof of a shelter too: harness h/shelter.mjs), dropped while he
	// jumps or falls 3 rows over it at least (higher than his jumps from the platform of the bad): bombed from above
	// without coming near it
	public function bombExposure(x0:Int, x1:Int, y:Int):Int {
		var n = 0;
		for (x in x0 - 3...x1 + 4) {
			if (x < 0 || x >= W)
				continue;
			var by = blastRest(x, x0, x1, y);
			if (by < 0)
				continue;
			var yy = by - 1;
			while (yy >= 0 && yy >= by - 11 && m[x][yy] <= 0) {
				if (yy <= y - 4 && routes.at(x, yy) > 0)
					n++;
				if (yy <= y - 3)
					for (d in [-1, 1])
						for (k in 1...3) {
							var kx = x + d * k;
							if (!inb(kx, yy) || m[kx][yy] > 0)
								break;
							if (reach[kx][yy]) {
								n++;
								break;
							}
						}
				yy--;
			}
		}
		return n;
	}

	// the look of the level: the ends of the tops of the platforms lined up with an end at another row (share), the
	// long floors (7 cases or more), the pairs of long floors over each other (3 to 6 rows apart, 5 cases in common),
	// the biggest piece of ground
	function looks():{lined:Float, long:Int, stack:Int, biggest:Int} {
		var tops:Array<{y:Int, x0:Int, x1:Int}> = [];
		for (y in 1...H) {
			var x = 0;
			while (x < W) {
				if (m[x][y] > 0 && m[x][y - 1] <= 0) {
					var x0 = x;
					while (x < W && m[x][y] > 0 && m[x][y - 1] <= 0)
						x++;
					tops.push({y: y, x0: x0, x1: x - 1});
				} else
					x++;
			}
		}
		var lined = 0;
		for (t in tops)
			for (e in [t.x0, t.x1]) {
				for (o in tops)
					if (o.y != t.y && (o.x0 == e || o.x1 == e)) {
						lined++;
						break;
					}
			}
		var longs = [for (t in tops) if (t.x1 - t.x0 + 1 >= 7) t];
		var stack = 0;
		for (i in 0...longs.length)
			for (j in i + 1...longs.length) {
				var a = longs[i];
				var b = longs[j];
				var ov = Math.min(a.x1, b.x1) - Math.max(a.x0, b.x0) + 1;
				var dy = Math.abs(a.y - b.y);
				if (dy >= 3 && dy <= 6 && ov >= 5)
					stack++;
			}
		// (the pieces of ground, their size)
		var seen = [for (x in 0...W) [for (y in 0...H) false]];
		var biggest = 0;
		for (x in 0...W)
			for (y in 0...H) {
				if (m[x][y] <= 0 || seen[x][y])
					continue;
				var n = 0;
				var st = [x * H + y];
				seen[x][y] = true;
				while (st.length > 0) {
					var cc = st.pop();
					var cx = Std.int(cc / H);
					var cy = cc % H;
					n++;
					for (d in [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
						var nx = cx + d[0];
						var ny = cy + d[1];
						if (inb(nx, ny) && m[nx][ny] > 0 && !seen[nx][ny]) {
							seen[nx][ny] = true;
							st.push(nx * H + ny);
						}
					}
				}
				if (n > biggest)
					biggest = n;
			}
		return {lined: tops.length == 0 ? 0 : lined / (2 * tops.length), long: longs.length, stack: stack, biggest: biggest};
	}

	// the holes of 1 or 2 cases between two platforms (on the same row, or one row apart) the bads jump over, with nothing
	// under them down to the bottom of the level: a bad missing its jump falls out of it (h/fall4.mjs)
	function voidHops():Int {
		var segs = segments();
		var n = 0;
		for (a in segs)
			for (b in segs) {
				if (b.x0 <= a.x1 || Math.abs(b.y - a.y) > 1)
					continue;
				var gap = b.x0 - a.x1 - 1;
				if (gap < 1 || gap > 2)
					continue;
				var y = Std.int(Math.max(a.y, b.y)) + 1;
				for (x in a.x1 + 1...b.x0) {
					var gy = y;
					while (gy < H && m[x][gy] <= 0)
						gy++;
					if (gy >= H) {
						n++;
						break;
					}
				}
			}
		return n;
	}

	// sticks: pieces of ground one case wide standing up (2 to 5 cases high, nothing on their sides), touching nothing at
	// their ends: the noise of a level
	function sticks():Int {
		var n = 0;
		for (x in 0...W) {
			var y = 0;
			while (y < H) {
				if (m[x][y] > 0 && !gr(x - 1, y) && !gr(x + 1, y)) {
					var y0 = y;
					while (y < H && m[x][y] > 0 && !gr(x - 1, y) && !gr(x + 1, y))
						y++;
					var len = y - y0;
					var topFree = y0 == 0 || m[x][y0 - 1] <= 0;
					var botFree = y >= H || m[x][y] <= 0;
					if (len >= 2 && len <= 5 && topFree && botFree && x > 0 && x < W - 1)
						n++;
				} else
					y++;
			}
		}
		return n;
	}

	// the ground of the level against the ground of each of the last levels: the share of the cases they have in common
	// (the best of the shifts of a case and of the mirror), the most like of them
	function likeness():Float {
		var best = 0.0;
		for (o in recentMaps)
			for (mir in 0...2)
				for (dx in -1...2)
					for (dy in -1...2) {
						var inter = 0;
						var uni = 0;
						for (x in 0...W) {
							var ox = mir == 1 ? W - 1 - x + dx : x + dx;
							var col = m[x];
							for (y in 0...H) {
								var a = col[y] > 0;
								var oy = y + dy;
								var b = ox >= 0 && ox < W && oy >= 0 && oy < H && o[ox][oy] > 0;
								if (a || b)
									uni++;
								if (a && b)
									inter++;
							}
						}
						if (uni > 0)
							best = Math.max(best, inter / uni);
					}
		return best;
	}

	// the bombs from above on each strawberry (bombExposure of its platform)
	function strawExposure():Array<Int> {
		var out = [];
		for (b in bads)
			if (b.id == Data.BAD_FRAISE) {
				var x0 = b.x;
				var x1 = b.x;
				while (x0 > 0 && canStand(x0 - 1, b.y))
					x0--;
				while (x1 < W - 1 && canStand(x1 + 1, b.y))
					x1++;
				out.push(bombExposure(x0, x1, b.y));
			}
		return out;
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

	// spikes where they are a danger for Igor and not for the bads (the bads go everywhere by themselves: they would die
	// on them one after the other): under the ceilings over the ways (no jumping there), on the ways only Igor takes (his
	// jumps are longer)
	function addSpikes(n:Int) {
		computeReach();
		var own = fruitZone();
		// (nor where Igor lands at the start, nor under the platform he lands on: always there, they would be seen again
		// and again; nor in the room shut)
		var ly = py;
		while (ly < H - 1 && !canStand(px, ly))
			ly++;
		var home = segmentOf(px, ly);
		function safe(x:Int, y:Int):Bool {
			if (home != null && x >= home.x0 - 1 && x <= home.x1 + 1 && y >= home.y - 2 && y <= home.y + 3)
				return false;
			return !own[x][y] && !(Math.abs(x - px) <= 2 && y >= ly - 2 && y <= ly + 1) && !inClose(x, y);
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
				// (or over a gap of the floor under it: Igor jumping up through the gap from the floor lower hits them)
				if (m[x][y - 1] > 0 && m[x][y + 1] == 0 && y + 3 < H && m[x][y + 2] == 0
					&& (m[x][y + 3] > 0 || (y + 4 < H && m[x][y + 3] == 0 && m[x][y + 4] > 0)
						|| (y + 5 < H && m[x][y + 3] == 0 && m[x][y + 4] == 0 && m[x][y + 5] > 0)))
					ceils.push({x: x, y: y});
				else if (depth >= 4 && m[x][y - 1] <= 0 && m[x][y + 1] <= 0 && (wallAt(x - 1, y) || wallAt(x + 1, y))
					&& reachedNear(x, y) && Math.abs(y - py) > 3)
					walls.push({x: x, y: y});
			}
		// (the tops of the pillars and of the short platforms Igor lands on, where no fruit goes: all spikes)
		var tops = [for (s in segs) if (s.x1 - s.x0 + 1 <= 4 && s.y > 2 && s.y < H - 2 && segReached(s)
			&& [for (x in s.x0...s.x1 + 1) if (!safe(x, s.y) || busy[x][s.y] || m[x][s.y] != 0) x].length == 0) s];
		#if gentest
		spikeStats.set("tops", (spikeStats.exists("tops") ? spikeStats.get("tops") : 0) + tops.length);
		spikeStats.set("calls", (spikeStats.exists("calls") ? spikeStats.get("calls") : 0) + 1);
		spikeStats.set("floorsC", (spikeStats.exists("floorsC") ? spikeStats.get("floorsC") : 0) + floorsC.length);
		spikeStats.set("ceils", (spikeStats.exists("ceils") ? spikeStats.get("ceils") : 0) + ceils.length);
		spikeStats.set("walls", (spikeStats.exists("walls") ? spikeStats.get("walls") : 0) + walls.length);
		#end
		while (placed.length < n && tries < 20) {
			tries++;
			var added:Array<GPt> = [];
			var what = draw([
				floorsC.length > 0 ? 4 : 0,
				ceils.length > 0 ? 4 : 0,
				walls.length > 0 && depth >= 6 ? 3 : 0,
				tops.length > 0 ? 3 : 0
			]);
			if (floorsC.length + ceils.length + walls.length + tops.length == 0 || what < 0)
				break;
			if (what == 0) {
				// a strip of spikes in a long platform (2 to 4 of them: a row, like in the original), where Igor goes
				var s = pickBy(floorsC, function(s) return 0.3 + traffic(s.x0, s.y - 1, s.x1, s.y));
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
				var p = pickBy(ceils, function(p) return 0.3 + traffic(p.x, p.y + 1, p.x, p.y + 2));
				ceils.remove(p);
				// (along the ceiling, as far as the cases are safe: 2 to 4 of them)
				function free(x:Int):Bool
					return m[x][p.y - 1] > 0 && m[x][p.y] == 0 && !busy[x][p.y] && safe(x, p.y);
				var a = p.x;
				var b = p.x;
				while (a > 0 && free(a - 1))
					a--;
				while (b < W - 1 && free(b + 1))
					b++;
				if (b - a + 1 > 4) {
					var k = range(3, 4);
					a = Std.int(Math.max(a, Math.min(p.x - 1, b - k + 1)));
					b = a + k - 1;
				}
				for (x in a...b + 1)
					added.push({x: x, y: p.y});
				if (added.length < 2)
					added = [];
			} else if (what == 3) {
				// the top of a pillar or of a short platform where Igor lands: spikes all over it
				var s = pickBy(tops, function(s) return 0.3 + traffic(s.x0 - 1, s.y - 2, s.x1 + 1, s.y));
				tops.remove(s);
				for (x in s.x0...s.x1 + 1)
					added.push({x: x, y: s.y});
			} else {
				// spikes on a wall, in the air where Igor jumps (two over each other when the wall is free there)
				var p = pickBy(walls, function(p) return 0.3 + traffic(p.x - 1, p.y - 1, p.x + 1, p.y + 1));
				added.push(p);
				walls.remove(p);
				for (w in walls)
					if (w.x == p.x && Math.abs(w.y - p.y) == 1 && added.length < 2) {
						added.push(w);
						walls.remove(w);
						break;
					}
			}
			if (added.length == 0) {
				#if gentest
				spikeStats.set("empty" + what, (spikeStats.exists("empty" + what) ? spikeStats.get("empty" + what) : 0) + 1);
				#end
				continue;
			}
			var all:Array<GPt> = [];
			function put(x:Int, y:Int) {
				if (busy[x][y] || spikeAt(x, y))
					return;
				for (p in all)
					if (p.x == x && p.y == y)
						return;
				all.push({x: x, y: y});
			}
			for (a in added) {
				put(a.x, a.y);
				// (the mirrored spike only on the mirrored ground: a level drawn mirrored is not always so everywhere;
				// players saw the mirror of spikes under a ceiling in the air on the other side)
				var side = spikeSide(a.x, a.y);
				var mside = spikeSide(W - 1 - a.x, a.y);
				if (sym && W - 1 - a.x != a.x && safe(W - 1 - a.x, a.y) && !busy[W - 1 - a.x][a.y]
					&& side != 0 && mside == (side == 2 ? 4 : (side == 4 ? 2 : side)))
					put(W - 1 - a.x, a.y);
			}
			for (a in all)
				setDanger(a, true);
			computeReach();
			var after = 0;
			for (s in segments())
				if (segReached(s))
					after++;
			if (!exitOk || after < before - 1 || !startOk() || openColumns() > openBase) {
				#if gentest
				var why = !exitOk ? "exit" : (after < before - 1 ? "segs" : (!startOk() ? "start" : "open"));
				spikeStats.set(why + what, (spikeStats.exists(why + what) ? spikeStats.get(why + what) : 0) + 1);
				#end
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

	// the traffic of the ways of Igor in a box (LevelRoutes; the cases he reaches when it is not known)
	function traffic(x0:Int, y0:Int, x1:Int, y1:Int):Float {
		if (routes != null && routes.traffic != null)
			return routes.sum(x0, y0, x1, y1);
		var n = 0.0;
		for (x in x0...x1 + 1)
			for (y in y0...y1 + 1)
				if (inb(x, y) && reach[x][y])
					n++;
		return n;
	}

	// one of the elements drawn with these weights
	function pickBy<T>(a:Array<T>, w:T->Float):T {
		var sum = 0.0;
		var ws = [for (e in a) {
			var v = Math.max(0, w(e));
			sum += v;
			v;
		}];
		var t = rnd(10000) / 10000 * sum;
		for (i in 0...a.length) {
			t -= ws[i];
			if (t < 0)
				return a[i];
		}
		return a[a.length - 1];
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
			&& !blockOnRoof && Math.abs(s.y - py) + Math.abs(s.x0 - px) > 6 && !isNoBad(s)) s];
		if (c.length == 0)
			return;
		// (the block Igor passes by the most: a saw going around it guards his way)
		var s = c[0];
		var sv = -1.0;
		for (k in c) {
			var v = rnd(100) / 40 + traffic(k.x0 - 2, k.y - 3, k.x1 + 2, k.y + 3);
			if (v > sv) {
				sv = v;
				s = k;
			}
		}
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
	var blockOnRoof:Bool = false;

	// cases of ground of the block under a segment (blockOnSide: it touches a side of the screen; blockOnRoof: it is the
	// roof of a shelter)
	function blockSize(s:GSeg):Int {
		blockOnSide = false;
		blockOnRoof = false;
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
			for (r in roofs)
				if (r.x == p.x && r.y == p.y)
					blockOnRoof = true;
			st.push({x: p.x + 1, y: p.y});
			st.push({x: p.x - 1, y: p.y});
			st.push({x: p.x, y: p.y + 1});
			st.push({x: p.x, y: p.y - 1});
		}
		return n;
	}

	// ---------------------------------------------------------------- the bads and their ice

	// the cases where the bads go by themselves from where they start (standing there or going through): walking,
	// falling where the fall is safe (they do not jump in the void: World.checkSecureFall), jumping down through their
	// platform, over a hole of 2 cases, up on a platform 3 rows higher, climbing a wall of 3 cases (parseIA)
	function badZone(?fruits:Bool = false):Array<Array<Bool>> {
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
			if ((b.id == Data.BAD_CRAWLER || b.id == Data.BAD_SAW) && !fruits)
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

	// what a fruit does by itself (its class: Fruits.hx, Bads2.hx): falls off the ends of its platform, jumps up 3 rows
	// onto the platform over it, jumps down through a floor of one case, jumps over a gap of 1 or 2 cases, climbs a wall
	// of so many cases, jumps in place (the attack of the pineapple)
	static function moves(id:Int):{fall:Bool, up:Bool, down:Bool, across:Bool, climb:Int, hop:Bool} {
		return switch (id) {
			case Data.BAD_CERISE, Data.BAD_FRAISE: {fall: false, up: false, down: false, across: false, climb: 0, hop: false};
			case Data.BAD_ORANGE, Data.BAD_CITRON: {fall: false, up: false, down: false, across: true, climb: 0, hop: false};
			case Data.BAD_ANANAS: {fall: false, up: false, down: false, across: true, climb: 0, hop: true};
			case Data.BAD_POIRE: {fall: false, up: false, down: false, across: true, climb: 1, hop: false};
			case Data.BAD_POMME: {fall: true, up: true, down: false, across: true, climb: 1, hop: false};
			case Data.BAD_ABRICOT, Data.BAD_ABRICOT2: {fall: true, up: true, down: false, across: true, climb: 3, hop: false};
			case Data.BAD_KIWI, Data.BAD_BOMBE: {fall: false, up: true, down: true, across: true, climb: 3, hop: false};
			case Data.BAD_BANANE: {fall: true, up: true, down: true, across: true, climb: 4, hop: false};
			// (the litchis, the raspberry)
			default: {fall: true, up: true, down: true, across: true, climb: 3, hop: false};
		};
	}

	// where the fruits go by themselves, each with its own moves: spikes there would kill them one after the other (the
	// cherry and the strawberry stay on their platform, the orange, the lemon, the pear and the pineapple only jump over
	// the gaps of their row, all fall off a spot of one case; the others go everywhere, the raspberry even bursts and
	// comes back together far away). The cases their feet go through: their platforms and their ends (they turn back
	// there, half over the gap), over the gaps they jump, the columns they fall or jump down through, the cases under the
	// platforms they jump up to; then their boxes around them. The leapers and the crawlers go through all the air they
	// reach, the saws around their grounds
	public function fruitZone():Array<Array<Bool>> {
		var zone = [for (x in 0...W) [for (y in 0...H) false]];
		function stand(x:Int, y:Int):Bool {
			return x >= 0 && x < W && y >= 0 && y + 1 < H && m[x][y] <= 0 && m[x][y + 1] > 0;
		}
		// (the first ground under a case, -1 in the void or in a ground)
		function ground(x:Int, y:Int):Int {
			if (x < 0 || x >= W)
				return -1;
			while (y + 1 < H && !stand(x, y)) {
				if (y >= 0 && m[x][y] > 0)
					return -1;
				y++;
			}
			return stand(x, y) ? y : -1;
		}
		for (b in bads) {
			if (b.id == Data.BAD_SPEAR)
				continue;
			if (b.id == Data.BAD_SAW) {
				crawlZone(zone, b.x, b.y);
				continue;
			}
			// (the leapers fly through all the air they reach; the crawlers crawl on every ground the air takes them to,
			// along the sides of the screen from one to the other: all of it too)
			if (b.id == Data.BAD_BALEINE || b.id == Data.BAD_CRAWLER) {
				var air = [for (x in 0...W) [for (y in 0...H) false]];
				var st:Array<GPt> = [for (dx in -1...2) for (dy in -1...2) {x: b.x + dx, y: b.y + dy}];
				while (st.length > 0) {
					var p = st.pop();
					if (!inb(p.x, p.y) || air[p.x][p.y] || m[p.x][p.y] > 0)
						continue;
					air[p.x][p.y] = true;
					zone[p.x][p.y] = true;
					for (d in [[1, 0], [-1, 0], [0, 1], [0, -1]])
						st.push({x: p.x + d[0], y: p.y + d[1]});
				}
				continue;
			}
			var mv = moves(b.id);
			// (the cases its feet go through, then its box around them: get_width / get_height of its picture, measured
			// in the game: the bomb and the pineapple 2 cases aside and 2 over, the others 1)
			var feet = [for (x in 0...W) [for (y in 0...H) false]];
			function pass(x:Int, y:Int) {
				if (inb(x, y))
					feet[x][y] = true;
			}
			var seen = [for (x in 0...W) [for (y in 0...H) false]];
			var q:Array<GPt> = [];
			function add(x:Int, y:Int) {
				if (stand(x, y) && !seen[x][y]) {
					seen[x][y] = true;
					q.push({x: x, y: y});
				}
			}
			var y0 = ground(b.x, b.y);
			if (y0 < 0)
				continue;
			for (k in b.y...y0)
				pass(b.x, k);
			add(b.x, y0);
			// (the raspberry bursts by itself and comes back together on any platform of 2 cases or more: Framboise.onShoot)
			if (b.id == Data.BAD_FRAMBOISE)
				for (x in 0...W)
					for (y in 0...H)
						if (stand(x, y) && (stand(x - 1, y) || stand(x + 1, y)))
							add(x, y);
			while (q.length > 0) {
				var p = q.pop();
				pass(p.x, p.y);
				pass(p.x, p.y - 1);
				if (mv.hop)
					for (k in 2...4)
						pass(p.x, p.y - k);
				// (a spot of one case: whatever it is, it does not stay there and falls off it, Walker.onFall)
				var small = true;
				for (d in [-1, 1])
					if (p.x + d >= 0 && p.x + d < W && m[p.x + d][p.y + 1] > 0 && m[p.x + d][p.y] <= 0)
						small = false;
				for (d in [-1, 1]) {
					var nx = p.x + d;
					if (nx < 0 || nx >= W)
						continue;
					if (m[nx][p.y] > 0) {
						// a wall: climbed when it is low enough, with room over the fruit (World.parseIA: IA_CLIMB)
						if (mv.climb > 0) {
							var h = 0;
							while (p.y - h >= 0 && m[nx][p.y - h] > 0)
								h++;
							var room = 0;
							while (room < h && p.y - room - 1 >= 0 && m[p.x][p.y - room - 1] <= 0)
								room++;
							if (h <= mv.climb && room >= h && stand(nx, p.y - h)) {
								for (k in 1...h + 2)
									pass(p.x, p.y - k);
								add(nx, p.y - h);
							}
						}
						continue;
					}
					if (stand(nx, p.y)) {
						add(nx, p.y);
						continue;
					}
					// the end of its platform: it turns back there, jumps over the gap, falls, or climbs a step over the gap
					pass(nx, p.y);
					pass(nx, p.y - 1);
					if (mv.across)
						for (k in 2...4) {
							var lx = p.x + k * d;
							if (lx < 0 || lx >= W || m[lx][p.y] > 0)
								break;
							if (stand(lx, p.y)) {
								for (j in 1...k)
									for (dy in 0...3)
										pass(p.x + j * d, p.y - dy);
								add(lx, p.y);
								break;
							}
						}
					if (mv.fall || small) {
						var ly = ground(nx, p.y);
						if (ly >= 0) {
							// (it falls from the edge: its body over both columns)
							for (k in p.y...ly + 1) {
								pass(nx, k);
								pass(p.x, k);
							}
							add(nx, ly);
						}
					}
					// (a step over the gap: the end of a platform right over the gap, the air over the fruit)
					if (mv.climb > 0)
						for (h in 2...mv.climb + 1) {
							var free = true;
							for (k in 0...h - 1)
								if (m[nx][p.y - k] > 0)
									free = false;
							if (free && p.y - h >= 0 && stand(nx, p.y - h) && m[p.x][p.y - h + 1] <= 0 && m[p.x][p.y - h] <= 0) {
								for (k in 1...h + 1)
									pass(p.x, p.y - k);
								pass(nx, p.y - h);
								add(nx, p.y - h);
								break;
							}
							if (!free)
								break;
						}
				}
				// up 3 rows through the platform over it, down through its floor of one case
				if (mv.up && p.y >= 3 && m[p.x][p.y - 2] > 0 && m[p.x][p.y - 3] <= 0) {
					for (k in 1...5)
						pass(p.x, p.y - k);
					pass(p.x - 1, p.y - 1);
					pass(p.x + 1, p.y - 1);
					add(p.x, p.y - 3);
				}
				if (mv.down && p.y + 2 < H && m[p.x][p.y + 2] <= 0) {
					var ly = ground(p.x, p.y + 2);
					if (ly >= 0) {
						for (k in p.y + 2...ly + 1)
							for (dx in -1...2)
								pass(p.x + dx, k);
						add(p.x, ly);
					}
				}
			}
			var big = b.id == Data.BAD_BOMBE || b.id == Data.BAD_ANANAS;
			var bx = big ? 2 : 1;
			var by = big ? 2 : 1;
			for (x in 0...W)
				for (y in 0...H)
					if (feet[x][y])
						for (dx in -bx...bx + 1)
							for (dy in 0...by + 1)
								if (inb(x + dx, y - dy))
									zone[x + dx][y - dy] = true;
		}
		return zone;
	}

	// the cellar (LevelDesign.cellar): a case of it, of its walls, of its roof
	public function inClose(x:Int, y:Int):Bool {
		return close != null && x >= close.box.x0 && x <= close.box.x1 && y >= close.box.y0 && y <= close.box.y1;
	}

	// the spikes on the ways of the fruits (where they go by themselves) go: they would kill them all one after the other
	function clearBadSpikes() {
		var zone = fruitZone();
		var keep = [];
		for (b in bads) {
			if (b.id == Data.BAD_SPEAR) {
				if (zone[b.x][b.y]) {
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
		var zone = badZone(true);
		var n = 0;
		for (sg in segments())
			if (pocket(sg, zone))
				n++;
		return n;
	}

	// a platform where a bad may be frozen (where the bads go by themselves) that its ice cannot leave
	function pocket(sg:GSeg, zone:Array<Array<Bool>>):Bool {
		if (!(segReached(sg) || segNear(sg)))
			return false;
		var walked = false;
		for (x in sg.x0...sg.x1 + 1)
			if (zone[x][sg.y])
				walked = true;
		return walked && !iceEscapes(sg);
	}

	// with pockets: the bombs of a black laser kill their bads; else a hole at an end of their floor (the ice falls
	// there), else a laser of black bombs on the way of Igor (one is made), else the level is not kept
	function pocketsOk():Bool {
		if (killerLaser())
			return true;
		var before = pockets();
		if (before == 0)
			return true;
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

	// the side of the ground a spike at (x, y) stands on, as Spear.initBad sees it: 1 under it, 3 over it, 2 on its left,
	// 4 on its right, 0 none
	function spikeSide(x:Int, y:Int):Int {
		return m0(x, y + 1) ? 1 : (m0(x, y - 1) ? 3 : (m0(x - 1, y) ? 2 : (m0(x + 1, y) ? 4 : 0)));
	}

	// a spike on a side of this ground case
	function spikeBy(x:Int, y:Int):Bool {
		for (b in bads)
			if (b.id == Data.BAD_SPEAR && Math.abs(b.x - x) + Math.abs(b.y - y) == 1)
				return true;
		return false;
	}

	// a spike stands on a side of a ground (Spear.initBad: else it is drawn pointing up in the air): none left where a
	// ground was cut after it (players saw spikes floating in the air)
	function dropLooseSpikes() {
		bads = [for (b in bads) if (b.id != Data.BAD_SPEAR || m0(b.x, b.y + 1) || m0(b.x, b.y - 1) || m0(b.x - 1, b.y)
			|| m0(b.x + 1, b.y)) b];
	}

	inline function m0(x:Int, y:Int):Bool {
		return inb(x, y) && m[x][y] > 0;
	}

	function repairPockets() {
		var zone = badZone(true);
		for (pass in 0...4) {
			var found = false;
			for (sg in segments()) {
				if (!pocket(sg, zone))
					continue;
				found = true;
				var fy = sg.y + 1;
				for (x in [sg.x0, sg.x1]) {
					// a floor one case thick, nobody standing there (not the roof of the cellar), no spike on it
					if (fy >= H || m[x][fy] <= 0 || (fy + 1 < H && m[x][fy + 1] > 0) || busy[x][sg.y] || inClose(x, fy)
						|| spikeBy(x, fy))
						continue;
					var v = m[x][fy];
					m[x][fy] = 0;
					if (sym && W - 1 - x != x && m[W - 1 - x][fy] == v)
						m[W - 1 - x][fy] = 0;
					computeReach();
					if (exitOk && startOk() && openColumns() <= openBase && iceEscapes({y: sg.y, x0: sg.x0, x1: sg.x1}))
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
						if (b.id == Data.BAD_SPEAR || b.id == Data.BAD_SAW || b.id == Data.BAD_BALEINE)
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
