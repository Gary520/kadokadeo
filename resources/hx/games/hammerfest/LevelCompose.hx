package hammerfest;

import hammerfest.LevelGen.GPt;

// a stage of a level: the cases drawn for some of its bads, what they do needing them, and their places there
typedef GStage = {kind:String, ids:Array<Int>, spots:Array<{id:Int, x:Int, y:Int}>, cx:Float, cy:Float};

// a face of a wall: x the first free column beside it, dir the side of the free space (1: right), the rows of the wall
typedef GFace = {x:Int, dir:Int, y0:Int, y1:Int};

// a floor of the skeleton (its ground row y), taken once a stage uses it
typedef GDeck = {x0:Int, x1:Int, y:Int, used:Bool};

// The levels made around their bads. Shapes drawn from a list came back too often (a player must never think he has
// already seen a level): each level is built by a way of building drawn for it, with its own measures, and its
// dangerous bads get stages made for what they do, hung on what is built or standing apart:
// - the ways of building: trunks (pillars from the bottom or in the air, their caps, a bridge between two of them),
//   decks (long floors on piers, staggered), walls (the sides of the screen thick, stepped, the middle open),
//   rocks (blocks of rock here and there), slopes (long stairs: down, crossing, a V, a roof);
// - strawberries: ledges under a roof (a bomb resting on the roof does nothing under it), on both sides of the level,
//   their ball across it: on the face of a wall, under a deck (the deck is the roof), in an alcove of the side of the
//   screen, in a notch of a block; alone, high up;
// - a lemon: a ledge over a floor where Igor walks (its zests go down to him through the floors), a branch of a wall
//   or in the air;
// - apples: the ends of a long floor Igor walks along (their pips fly along the row), a deck, a corridor under a
//   ceiling, a bridge between two pillars;
// - pears: a balcony high over the open places where their bombs fall;
// - a pineapple: a wide floor open over it (Igor on the ground is knocked out when it lands);
// - a kiwi: a floor to cross (its mines); a bomb: a notch by the way (its blast, nowhere to run); an apricot: a ledge
//   over a floor (the small ones fall on Igor); a raspberry: a platform in the open (its grains fly far); litchis,
//   cherries: long floors (the combos), oranges: a floor cut by small holes (they hop over), a banana: stairs.
// The level is drawn mirrored or not; the other bads go on shelves where the stages leave room. Many levels are made
// and rated (LevelGen.make): the ones like the last levels lose.
@:access(hammerfest.LevelGen)
class LevelCompose {
	static inline var W = Data.LEVEL_WIDTH;
	static inline var H = Data.LEVEL_HEIGHT;

	public static var SYSTEMS = ["trunks", "decks", "walls", "rocks", "slopes"];

	var g:LevelGen;
	var m:Array<Array<Int>>;
	var sym:Bool;
	// the space around the stages drawn: no other stage there
	var keep:Array<Array<Bool>>;
	var faces:Array<GFace> = [];
	var decks:Array<GDeck> = [];

	public var stages:Array<GStage> = [];
	public var system:Int = 0;

	static inline function count(k:String) {
		#if gentest
		LevelFeatures.why.set(k, (LevelFeatures.why.exists(k) ? LevelFeatures.why.get(k) : 0) + 1);
		#end
	}

	public function new(g:LevelGen) {
		this.g = g;
		m = g.m;
	}

	// sys: the way of building (SYSTEMS)
	public function draw(sys:Int) {
		system = sys;
		g.floors = [];
		g.vault = null;
		keep = [for (x in 0...W) [for (y in 0...H) false]];
		sym = g.chance(0.3);
		bottom();
		if (g.wants("vault") && !vaultRoom())
			count("vault.room");
		switch (SYSTEMS[sys]) {
			case "trunks":
				trunks();
			case "decks":
				deckSystem();
			case "walls":
				walls();
			case "rocks":
				rocks();
			default:
				slopes();
		}
		for (r in plan()) {
			var ok = switch (r.kind) {
				case "arena": floor(r.kind, r.ids, 8, 11, 11, 15);
				case "gallery": floor(r.kind, r.ids, 7, 10, 6, 14);
				case "row": floor(r.kind, r.ids, 7, 10, 7, 15);
				case "duel": floor(r.kind, r.ids, 6, 8, 7, 15);
				case "strip": floor(r.kind, r.ids, 4, 7, 6, 14);
				case "hops": hops(r.ids);
				case "crossfire": crossfire(r.ids);
				case "sniper": perch(r.ids, true, 6, 9, 0, true, false);
				case "balcony": perch(r.ids, false, 6, 10, 0, true, false);
				case "closet": perch(r.ids, true, 6, 14, 0, false, true);
				case "lemon", "rain": ledgeOver(r.kind, r.ids);
				case "field": field(r.ids);
				case "climb": climb(r.ids);
				default: false;
			};
			if (!ok)
				count("stage.no." + r.kind);
		}
		enrich();
		entry();
		fill();
		g.kind = SYSTEMS[sys];
		g.sym = isSym();
	}

	// ---------------------------------------------------------------- the vault

	// the vault: a room on the bottom shut all around but its window (2 cases high in a wall), its bads shut in (their
	// ice cannot go out): the laser of black bombs in the window (LevelFeatures) is the way to kill them (Black.onExplode);
	// a mezzanine inside under the window, a ledge outside in front of it, turrets on the roof sometimes
	function vaultRoom():Bool {
		for (t in 0...20) {
			var iw = g.range(4, 7);
			var x0 = sym ? (W - iw - 2) >> 1 : g.range(1, W - iw - 3);
			var x1 = x0 + iw + 1;
			if (sym && (W - iw - 2) % 2 != 0)
				continue;
			var fy = H - 1;
			var ry = fy - 6;
			var left = sym ? g.chance(0.5) : (x0 + x1 > W - 1 ? true : false);
			var wx = left ? x0 : x1;
			var ox0 = left ? x0 - 3 : x1 + 1;
			if (ox0 < 0 || ox0 + 2 >= W)
				continue;
			// (free over the floor of the room and around it)
			var ok = true;
			for (x in x0 - 1...x1 + 2)
				for (y in ry - 3...fy)
					if (x >= 0 && x < W && (m[x][y] != 0 || keep[x][y]))
						ok = false;
			if (!ok)
				continue;
			var was = sym;
			sym = false;
			// (its walls, roof, floor; the window; the mezzanine; the ledge outside)
			col(x0, ry, fy);
			col(x1, ry, fy);
			h(x0, x1, ry);
			h(x0, x1, fy);
			setc(wx, ry + 1, 0);
			setc(wx, ry + 2, 0);
			var ml = g.range(2, 3);
			if (left)
				h(x0 + 1, x0 + ml, ry + 3);
			else
				h(x1 - ml, x1 - 1, ry + 3);
			if (left)
				h(x0 - g.range(2, 3), x0 - 1, ry + 3);
			else
				h(x1 + 1, x1 + g.range(2, 3), ry + 3);
			if (g.chance(0.5)) {
				c(x0, ry - 1);
				c(x1, ry - 1);
			}
			sym = was;
			g.vault = {x0: x0 + 1, x1: x1 - 1, y: fy - 1, top: ry + 1, door: [{x: wx, y: ry + 1}, {x: wx, y: ry + 2}]};
			addDeck(x0, x1, ry);
			faces.push({x: x0 - 1, dir: -1, y0: ry, y1: fy});
			faces.push({x: x1 + 1, dir: 1, y0: ry, y1: fy});
			hold(x0 - 1, x1 + 1, ry - 2, fy);
			if (g.floors.indexOf(ry + 3) < 0)
				g.floors.push(ry + 3);
			return true;
		}
		return false;
	}

	// ---------------------------------------------------------------- the ways of building

	// trunks: 1 to 3 pillars (1 or 2 cases thick) from the bottom or in the air, a cap on some, a bridge between two
	// of them now and then (a gap in its middle); their faces carry the stages
	function trunks() {
		var n = sym ? (g.chance(0.3) ? 1 : 2) : g.draw([0, 3, 4, 2]);
		var xs:Array<Int> = [];
		var ths:Array<Int> = [];
		if (sym) {
			if (n == 1) {
				xs.push(8);
				ths.push(2);
			} else {
				var th = g.chance(0.6) ? 1 : 2;
				xs.push(g.range(3, 6));
				ths.push(th);
			}
		} else {
			// (spread over the width: thirds, a case or two of freedom)
			var slots = n == 1 ? [g.range(5, 11)] : (n == 2 ? [g.range(3, 6), g.range(11, 14)] : [g.range(2, 4), g.range(8, 9), g.range(13, 15)]);
			for (x in slots) {
				xs.push(x);
				ths.push(g.chance(0.35) ? 2 : 1);
			}
		}
		var tops:Array<Int> = [];
		for (i in 0...xs.length) {
			var x = xs[i];
			var th = ths[i];
			var top = g.range(3, 8);
			var grounded = g.chance(0.65);
			var bot = grounded ? H - 2 : g.range(top + 6, 14);
			if (sym && n == 1)
				// (the central one: both columns of the middle)
				x = 8;
			wall(x, sym && n == 1 ? 1 : th, top, bot);
			if (sym && n == 1)
				wall(9, 1, top, bot);
			tops.push(top);
			// (a cap: a T over it)
			if (g.chance(0.4)) {
				var cw = g.range(1, 2);
				h(x - cw, x + (sym && n == 1 ? 1 : th - 1) + cw, top);
				addDeck(x - cw, x + th - 1 + cw, top);
			}
		}
		// (a bridge between two trunks, its middle open)
		if (!sym && xs.length >= 2 && g.chance(0.45)) {
			var a = 0;
			var b = 1;
			var y = Std.int(Math.max(tops[a], tops[b])) + g.range(3, 5);
			if (y <= 13) {
				var x0 = xs[a] + ths[a];
				var x1 = xs[b] - 1;
				if (x1 - x0 >= 5) {
					h(x0, x1, y);
					var mid = (x0 + x1) >> 1;
					setc(mid, y, 0);
					setc(mid + 1, y, 0);
					addDeck(x0, mid - 1, y);
					addDeck(mid + 2, x1, y);
				}
			}
		}
	}

	// decks: 1 or 2 long floors (8 to 16 cases) at other heights, staggered, on piers (never closing a room under them),
	// a hole in one of them sometimes (the way down)
	function deckSystem() {
		var n = g.chance(0.6) ? 2 : 1;
		var y = g.range(6, 9);
		var prevX0 = -1;
		for (i in 0...n) {
			var len = g.range(7, 12);
			if (sym && (W - len) % 2 != 0)
				len++;
			var x0 = sym ? (W - len) >> 1 : (prevX0 < 0 ? (g.chance(0.5) ? 0 : W - len) : (prevX0 == 0 ? W - len : 0));
			if (!sym && g.chance(0.4))
				x0 = g.range(1, W - 1 - len);
			var x1 = x0 + len - 1;
			h(x0, x1, y);
			// (the hole: a way down through it)
			if (g.chance(0.4) && len >= 10) {
				var hx = sym ? 8 : g.range(x0 + 3, x1 - 4);
				c(hx, y, 0);
				c(hx + 1, y, 0);
				addDeck(x0, hx - 1, y);
				addDeck(hx + 2, x1, y);
			} else
				addDeck(x0, x1, y);
			// (piers: under an end, or two inside, down to the ground; the room under the deck stays open on a side)
			var piers = g.draw([2, 3, 2]);
			if (piers == 1)
				wallDown(g.chance(0.5) ? x0 + 1 : x1 - 1, y + 1);
			else if (piers == 2) {
				wallDown(x0 + g.range(2, 3), y + 1);
				if (!sym)
					wallDown(x1 - g.range(2, 3), y + 1);
			}
			prevX0 = x0;
			y += g.range(4, 6);
			if (y > 14)
				break;
		}
	}

	// walls: the sides of the screen thick (1 to 3 cases), from a row down to the bottom, stepped or notched, the
	// middle open; their faces carry the stages
	function walls() {
		for (side in (sym ? [0] : [0, 1])) {
			var w = g.range(1, 3);
			var top = g.range(3, 8);
			var step = g.chance(0.5);
			var y = top;
			var cur = w;
			var prev = 0;
			while (y <= H - 2) {
				var seg = g.range(3, 6);
				var y1 = Std.int(Math.min(H - 2, y + seg - 1));
				for (k in 0...cur) {
					var x = side == 0 ? k : W - 1 - k;
					col(x, y, y1);
				}
				var fx = side == 0 ? cur : W - 1 - cur;
				faces.push({x: fx, dir: side == 0 ? 1 : -1, y0: y, y1: y1});
				// (the top of the wall, the tops of its steps: floors)
				addDeck(side == 0 ? prev : W - cur, side == 0 ? cur - 1 : W - 1 - prev, y);
				prev = cur;
				y = y1 + 1;
				// (a step: the wall wider going down)
				if (step && cur < 5)
					cur += g.range(1, 2);
			}
			if (side == 0 && !sym && g.chance(0.3))
				// (one side only)
				break;
		}
	}

	// rocks: 2 to 4 blocks of rock (3 to 6 cases wide, 2 to 4 high), some on the bottom, some against a side, some in
	// the air; their tops are floors, their faces carry the stages
	function rocks() {
		// (the blocks of a level alike: their measures drawn once; set in pairs, in steps, in a row, or here and there)
		var w = g.range(3, 5);
		var hh = g.range(2, 3);
		var pattern = sym ? g.draw([0, 3, 3, 2]) : g.draw([3, 3, 3, 2]);
		switch (pattern) {
			case 0:
				var y = g.range(6, 12);
				var x0 = g.range(0, 3);
				rock(x0, y, w, hh);
				rock(W - x0 - w, y + g.range(0, 2), w, hh);
				if (g.chance(0.5))
					rock((W - w) >> 1, y + g.range(4, 5), w, hh);
			case 1:
				// (in steps going down)
				var n = g.range(3, 4);
				var dir = sym ? 1 : (g.chance(0.5) ? 1 : -1);
				var dx = (w + g.range(0, 2)) * dir;
				var dy = g.range(2, 3);
				var x = dir > 0 ? g.range(0, 2) : W - w - g.range(0, 2);
				var y = g.range(4, 7);
				for (i in 0...n) {
					if (sym && x + w - 1 > 8)
						break;
					rock(x, y, w, hh);
					x += dx;
					y += dy + hh - 1;
				}
			case 2:
				// (in a row, the same gaps between them)
				var n = sym ? 2 : g.range(2, 3);
				var y = g.range(7, 13);
				var span = sym ? 9 : W;
				var gap = Std.int((span - n * w) / (n + (sym ? 0.5 : 1)));
				var x = gap;
				for (i in 0...n) {
					rock(x, y + (sym ? 0 : (i % 2) * g.range(0, 1)), w, hh);
					x += w + gap;
				}
			default:
				var n = g.range(2, 4);
				var done = 0;
				for (t in 0...30) {
					if (done >= n)
						break;
					var where = g.draw([3, 3, 4]); // bottom, side, air
					var x0 = sym ? g.range(0, 8 - w) : g.range(0, W - w);
					var y0 = g.range(5, 13);
					if (where == 0)
						y0 = H - 1 - hh;
					if (where == 1)
						x0 = sym || g.chance(0.5) ? 0 : W - w;
					if (rock(x0, y0, w, hh))
						done++;
				}
		}
	}

	// a block of rock (its top a floor, its faces for the stages), when there is room for it
	function rock(x0:Int, y0:Int, w:Int, hh:Int):Bool {
		var y1 = y0 + hh - 1;
		if (x0 < 0 || x0 + w > W || y1 > H - 2 || !free(x0 - 1, x0 + w, y0 - 3, y1 + 1))
			return false;
		for (k in 0...w)
			col(x0 + k, y0, y1);
		addDeck(x0, x0 + w - 1, y0);
		if (x0 > 0)
			faces.push({x: x0 - 1, dir: -1, y0: y0, y1: y1});
		if (x0 + w < W)
			faces.push({x: x0 + w, dir: 1, y0: y0, y1: y1});
		hold(x0 - 1, x0 + w, y0 - 2, y1 + 1);
		return true;
	}

	// slopes: long stairs (5 to 9 steps of 1 or 2 cases): one across, two crossing, a V, a roof (two going down from a
	// top in the middle)
	function slopes() {
		var form = sym ? (g.chance(0.5) ? 2 : 3) : g.draw([3, 2, 2, 2]);
		var w = g.range(1, 2);
		switch (form) {
			case 0:
				// (one across the level, down to a side)
				var n = g.range(6, 9);
				var dir = g.chance(0.5) ? 1 : -1;
				var x = dir > 0 ? g.range(0, 2) : W - 1 - g.range(0, 2);
				stairRun(x, g.range(4, 7), dir, n, w);
			case 1:
				// (two parallel ones, apart)
				var dir = g.chance(0.5) ? 1 : -1;
				var n = g.range(4, 6);
				stairRun(dir > 0 ? 0 : W - 1, g.range(4, 6), dir, n, w);
				stairRun(dir > 0 ? g.range(6, 8) : W - 1 - g.range(6, 8), g.range(10, 12), dir, n, w);
			case 2:
				// (a V: from the sides down to the middle)
				var n = Std.int(Math.min(g.range(4, 7), Std.int(7 / w)));
				var y = g.range(5, 9);
				stairRun(0, y, 1, n, w);
				if (!sym)
					stairRun(W - 1, y + g.range(0, 2), -1, n, w);
			default:
				// (a roof: from a top in the middle down to the sides)
				var n = Std.int(Math.min(g.range(4, 6), Std.int(8 / w)));
				var y = g.range(4, 8);
				stairRun(8, y, -1, n, w);
				if (!sym)
					stairRun(9, y, 1, n, w);
		}
	}

	// stairs from (x, y) going down towards dir: n steps of w cases (a floor each)
	function stairRun(x:Int, y:Int, dir:Int, n:Int, w:Int) {
		for (i in 0...n) {
			var ya = y + i;
			if (ya > H - 2)
				break;
			var xa = x + dir * i * w;
			var xb = xa + dir * (w - 1);
			if (xa < 0 || xa >= W || xb < 0 || xb >= W)
				break;
			h(xa, xb, ya);
			addDeck(Std.int(Math.min(xa, xb)), Std.int(Math.max(xa, xb)), ya);
		}
		hold(Std.int(Math.min(x, x + dir * n * w)) - 1, Std.int(Math.max(x, x + dir * n * w)) + 1, y - 1, y + n);
	}

	// a wall of th cases from y0 to y1 (x its left column), its faces kept for the stages
	function wall(x:Int, th:Int, y0:Int, y1:Int) {
		for (k in 0...th)
			col(x + k, y0, y1);
		if (x - 1 >= 0)
			faces.push({x: x - 1, dir: -1, y0: y0, y1: y1});
		if (x + th < W)
			faces.push({x: x + th, dir: 1, y0: y0, y1: y1});
	}

	// a wall from (x, y) down to the ground under it (at most 8 rows)
	function wallDown(x:Int, y:Int) {
		if (x < 0 || x >= W)
			return;
		var gy = y;
		while (gy < H && m[x][gy] <= 0)
			gy++;
		if (gy >= H || gy - y > 8)
			return;
		wall(x, 1, y, gy - 1);
	}

	function addDeck(x0:Int, x1:Int, y:Int) {
		x0 = Std.int(Math.max(0, x0));
		x1 = Std.int(Math.min(W - 1, x1));
		if (y < 2 || x1 < x0)
			return;
		decks.push({x0: x0, x1: x1, y: y, used: false});
		if (g.floors.indexOf(y) < 0)
			g.floors.push(y);
	}

	// ---------------------------------------------------------------- the stages of the level

	// the stages for the bads of the lineup: the leading kind first, then the wide floors (they need the most room), at
	// most 4; the other bads go on the shelves
	function plan():Array<{kind:String, ids:Array<Int>}> {
		var num = new Map<Int, Int>();
		for (id in g.lineup.list)
			num.set(id, (num.exists(id) ? num.get(id) : 0) + 1);
		function n(id:Int):Int
			return num.exists(id) ? num.get(id) : 0;
		var out:Array<{kind:String, ids:Array<Int>}> = [];
		function take(kind:String, id:Int, k:Int) {
			var c = Std.int(Math.min(k, n(id)));
			if (c <= 0)
				return;
			num.set(id, n(id) - c);
			out.push({kind: kind, ids: [for (i in 0...c) id]});
		}
		take("arena", Data.BAD_ANANAS, 1);
		if (n(Data.BAD_FRAISE) >= 2)
			take("crossfire", Data.BAD_FRAISE, 4);
		else
			take("sniper", Data.BAD_FRAISE, 1);
		take("gallery", Data.BAD_POMME, 2);
		take("lemon", Data.BAD_CITRON, sym ? 2 : 1);
		take("balcony", Data.BAD_POIRE, sym ? 2 : 1);
		take("strip", Data.BAD_KIWI, 1);
		take("closet", Data.BAD_BOMBE, sym ? 2 : 1);
		take("rain", Data.BAD_ABRICOT, 1);
		take("field", Data.BAD_FRAMBOISE, 1);
		take("duel", Data.BAD_LITCHI, 2);
		if (n(Data.BAD_CERISE) >= 3)
			take("row", Data.BAD_CERISE, 4);
		if (n(Data.BAD_ORANGE) >= 2)
			take("hops", Data.BAD_ORANGE, 2);
		take("climb", Data.BAD_BANANE, 1);
		var lead = g.lineup.lead;
		var big = ["arena", "gallery", "row", "duel", "hops", "strip"];
		out.sort(function(a, b) {
			var la = a.ids[0] == lead ? 0 : 1;
			var lb = b.ids[0] == lead ? 0 : 1;
			if (la != lb)
				return la - lb;
			var ba = big.indexOf(a.kind) >= 0 ? 0 : 1;
			var bb = big.indexOf(b.kind) >= 0 ? 0 : 1;
			return ba - bb;
		});
		if (out.length > 4)
			out = out.slice(0, 4);
		return out;
	}

	function addStage(kind:String, ids:Array<Int>, spots:Array<{id:Int, x:Int, y:Int}>) {
		var cx = 0.0;
		var cy = 0.0;
		for (s in spots) {
			cx += s.x;
			cy += s.y;
		}
		if (spots.length > 0) {
			cx /= spots.length;
			cy /= spots.length;
		}
		stages.push({kind: kind, ids: ids, spots: spots, cx: cx, cy: cy});
	}

	// how far a place is from the stages drawn (the stages spread over the level)
	function apart(x:Float, y:Float):Float {
		var d = 12.0;
		for (s in stages)
			d = Math.min(d, Math.abs(s.cx - x) + Math.abs(s.cy - y) * 1.3);
		return d;
	}

	// the ends of a platform (x0, x1 at the row y) over or under the ends of other platforms (lined up)
	function alignX(x0:Int, x1:Int, y:Int):Float {
		var v = 0.0;
		for (e in [x0, x1]) {
			if (e < 0 || e >= W)
				continue;
			for (yy in 1...H)
				if (yy != y && m[e][yy] > 0 && m[e][yy - 1] <= 0
					&& ((e == 0 || m[e - 1][yy] <= 0 || m[e - 1][yy - 1] > 0) || (e == W - 1 || m[e + 1][yy] <= 0 || m[e + 1][yy - 1] > 0))) {
					v += 0.4;
					break;
				}
		}
		return v;
	}

	// a row lined up with the floors drawn (the same row: good; a row next to one: crooked)
	function align(y:Int):Float {
		var v = 0.0;
		for (f in g.floors)
			if (f == y)
				v = Math.max(v, 0.5);
			else if (Math.abs(f - y) == 1)
				v = Math.min(v, -0.5);
		return v;
	}

	// the standing cases of a floor of the skeleton (free over it)
	function deckFree(d:GDeck, rows:Int):Bool {
		for (x in d.x0...d.x1 + 1)
			for (y in d.y - rows...d.y)
				if (y < 1 || m[x][y] != 0)
					return false;
		return true;
	}

	// a floor for some bads: a wide one open over it for a pineapple, a long one for apples at its ends, cherries in a
	// row, litchis, a kiwi: a floor of the skeleton, or one of its own (in the air, on a pier, under a ceiling: a
	// corridor for the pips, with a wall at one end)
	function floor(kind:String, ids:Array<Int>, l0:Int, l1:Int, y0:Int, y1:Int):Bool {
		// (a floor of the skeleton long enough, at the right height, free over it)
		var bd:GDeck = null;
		var bv = -1.0e9;
		for (d in decks) {
			var len = d.x1 - d.x0 + 1;
			if (d.used || len < l0 || d.y < y0 - 1 || d.y > y1 + 1 || !deckFree(d, kind == "arena" ? 4 : 3))
				continue;
			var v = apart((d.x0 + d.x1) / 2, d.y) + g.rnd(100) / 50 + Math.min(4, len - l0) * 0.2;
			if (v > bv) {
				bv = v;
				bd = d;
			}
		}
		if (bd != null) {
			bd.used = true;
			addStage(kind, ids, floorSpots(kind, ids, bd.x0, bd.x1, bd.y));
			return true;
		}
		var best:{x0:Int, len:Int, y:Int, form:Int} = null;
		bv = -1.0e9;
		for (t in 0...30) {
			var len = g.range(l0, l1);
			if (sym && (W - len) % 2 != 0)
				len++;
			var y = g.range(y0, y1);
			var x0 = sym ? (W - len) >> 1 : g.range(0, W - len);
			var x1 = x0 + len - 1;
			// 0 plain, 1 pier, 2 corridor
			var form = g.draw([4, 3, kind == "gallery" ? 3 : 1]);
			if (kind == "arena" && form >= 2)
				form = 0;
			var top = form == 2 ? y - 5 : (form == 3 ? y - 4 : y - 3);
			if (top < 1)
				continue;
			if (!free(x0 - 1, x1 + 1, top, y + 1))
				continue;
			var v = apart(x0 + len / 2, y) + g.rnd(100) / 40 + align(y) + alignX(x0, x1, y);
			if (kind == "arena")
				v -= Math.abs(x0 + len / 2 - 9) * 0.3;
			if (v > bv) {
				bv = v;
				best = {x0: x0, len: len, y: y, form: form};
			}
		}
		if (best == null)
			return false;
		var x0 = best.x0;
		var x1 = x0 + best.len - 1;
		var y = best.y;
		h(x0, x1, y);
		var spots = floorSpots(kind, ids, x0, x1, y);
		switch (best.form) {
			case 1:
				wallDown(sym ? g.range(3, 6) : (g.chance(0.5) ? (x0 + x1) >> 1 : (g.chance(0.5) ? x0 + 1 : x1 - 1)), y + 1);
			case 2:
				h(x0 + 1, x1 - 1, y - 4);
			default:
		}
		if (g.floors.indexOf(y) < 0)
			g.floors.push(y);
		hold(x0 - 1, x1 + 1, best.form == 2 ? y - 5 : y - 4, y + 1);
		addStage(kind, ids, spots);
		return true;
	}

	function floorSpots(kind:String, ids:Array<Int>, x0:Int, x1:Int, y:Int):Array<{id:Int, x:Int, y:Int}> {
		var spots:Array<{id:Int, x:Int, y:Int}> = [];
		switch (kind) {
			case "gallery":
				// (the apples at the ends, facing along the floor)
				var ends = g.chance(0.5) ? [x0, x1] : [x1, x0];
				for (i in 0...ids.length)
					spots.push({id: ids[i], x: ends[i % 2], y: y - 1});
			case "arena", "strip":
				spots.push({id: ids[0], x: (x0 + x1) >> 1, y: y - 1});
			default:
				var stp = Std.int(Math.max(2, (x1 - x0 - 1) / ids.length));
				var x = x0 + 1;
				var k = 0;
				while (k < ids.length && x <= x1 - 1) {
					spots.push({id: ids[k], x: x, y: y - 1});
					k++;
					x += stp;
				}
		}
		return spots;
	}

	// a floor cut by small holes (1 or 2 cases): the oranges hop over them
	function hops(ids:Array<Int>):Bool {
		var best:{x0:Int, len:Int, y:Int} = null;
		var bv = -1.0e9;
		for (t in 0...20) {
			var len = g.range(10, 14);
			if (sym && (W - len) % 2 != 0)
				len++;
			var y = g.range(7, 15);
			var x0 = sym ? (W - len) >> 1 : g.range(0, W - len);
			if (!free(x0 - 1, x0 + len, y - 3, y + 1))
				continue;
			var v = apart(x0 + len / 2, y) + g.rnd(100) / 40 + align(y);
			if (v > bv) {
				bv = v;
				best = {x0: x0, len: len, y: y};
			}
		}
		if (best == null)
			return false;
		var x0 = best.x0;
		var x1 = x0 + best.len - 1;
		var y = best.y;
		h(x0, x1, y);
		var holes:Array<Int> = [];
		if (sym)
			holes.push(g.range(3, 5));
		else {
			var hx = g.range(x0 + 3, x1 - 4);
			holes.push(hx);
			if (best.len >= 12 && hx - x0 >= 6)
				holes.push(g.range(x0 + 2, hx - 4));
		}
		for (hx in holes) {
			var w = g.range(1, 2);
			for (k in 0...w)
				c(hx + k, y, 0);
		}
		if (g.floors.indexOf(y) < 0)
			g.floors.push(y);
		hold(x0 - 1, x1 + 1, y - 3, y + 1);
		var hx = holes[0];
		var spots = [{id: ids[0], x: Std.int(Math.max(x0, hx - 2)), y: y - 1}];
		if (ids.length > 1)
			spots.push({id: ids[1], x: sym ? W - 1 - spots[0].x : Std.int(Math.min(x1, hx + 3)), y: y - 1});
		addStage("hops", ids, spots);
		return true;
	}

	// the strawberries in a formation over the whole level, their ball across the middle where Igor goes down: 2 on both
	// sides (at most 3 rows apart: the ball crosses the level), 3 in a zigzag (a side high and low, the other side in
	// between), 4 at the corners (both sides high and low); never two on a side less than 4 rows apart (the ball would
	// only fly along the side), the ledges near the sides of the screen. Mirrored levels: a pair of mirrored ledges, a
	// second pair lower for the 3rd and the 4th
	function crossfire(ids:Array<Int>):Bool {
		var n = ids.length;
		if (sym) {
			if (!perch(ids.slice(0, 2), true, 6, 9, -1, false, false, true))
				return false;
			if (n > 2)
				perch(ids.slice(2, 4), true, 11, 14, -1, false, false, true);
			return true;
		}
		var s = g.chance(0.5) ? -1 : 1;
		if (n == 2) {
			if (!perch([ids[0]], true, 6, 11, s, false, false, true))
				return false;
			var y = lastY();
			perch([ids[1]], true, Std.int(Math.max(5, y - 3)), Std.int(Math.min(14, y + 3)), -s, false, false, true);
			return true;
		}
		// (zones: side, rows; the 4th the other side of the 3rd)
		var zones = n == 3 ? [[s, 6, 9], [-s, 8, 11], [s, 11, 14]] : [[s, 6, 9], [-s, 6, 9], [s, 11, 14], [-s, 11, 14]];
		var done = 0;
		for (i in 0...Std.int(Math.min(n, zones.length))) {
			var z = zones[i];
			if (perch([ids[i]], true, z[1], z[2], z[0], false, false, true))
				done++;
		}
		return done >= 2;
	}

	// the row of the bad of the last stage drawn
	function lastY():Int {
		var st = stages[stages.length - 1];
		return st.spots.length > 0 ? st.spots[0].y + 1 : 9;
	}

	// a ledge with its bad at the back (against a wall), under a roof 2 rows over it (a bomb resting on the roof does
	// nothing under it) for the strawberries and the bombs, open for the pears: on the face of a wall of the skeleton,
	// under a floor of the skeleton (the floor is its roof), in an alcove of a side of the screen, in a notch of a block.
	// side -1: the left half (the wall on its left), 1 the right half, 0 any; mirrored levels: the left one and its
	// mirror (the second bad there)
	function perch(ids:Array<Int>, roof:Bool, y0:Int, y1:Int, side:Int, high:Bool, inner:Bool, ?outer:Bool = false):Bool {
		var best:{x0:Int, x1:Int, y:Int, s:Int, form:Int, wx:Int} = null;
		var bv = -1.0e9;
		function consider(x0:Int, x1:Int, y:Int, s:Int, form:Int, wx:Int, bonus:Float) {
			if (x0 < 0 || x1 >= W || y < y0 || y > y1 || (sym && x1 > 7))
				return;
			if (side != 0 && !sym && ((side < 0) != ((x0 + x1) / 2 < 9)))
				return;
			// (the strawberries near the sides: their ball goes across the whole level; none less than 4 rows from another
			// one of the same side)
			if (outer) {
				var cx = (x0 + x1) / 2;
				if (cx > 5.5 && cx < 11.5)
					return;
				for (st in stages)
					for (p in st.spots)
						if (p.id == Data.BAD_FRAISE && Math.abs(p.x - cx) <= 6 && Math.abs(p.y - (y - 1)) < 4)
							return;
				bonus += Math.abs(cx - 8.5) * 0.3;
			}
			// (the ledge, its roof (not under a floor of the skeleton: it is there), the space in front)
			var rt = form == 1 ? y - 2 : (roof ? y - 4 : y - 3);
			if (!free(x0, x1, rt, y + 1))
				return;
			var fx0 = s < 0 ? x1 + 1 : x0 - 3;
			var fx1 = s < 0 ? x1 + 3 : x0 - 1;
			if (!free(fx0, fx1, y - 2, y - 1))
				return;
			var v = apart((x0 + x1) / 2, y) + g.rnd(100) / 50 + (high ? (12 - y) * 0.4 : 0) + align(y) + bonus;
			if (v > bv) {
				bv = v;
				best = {x0: x0, x1: x1, y: y, s: s, form: form, wx: wx};
			}
		}
		// (on the faces of the walls: the wall from the roof down to the ledge)
		for (f in faces)
			for (t in 0...3) {
				var y = g.range(Std.int(Math.max(y0, f.y0 + (roof ? 3 : 2))), Std.int(Math.max(y0, Math.min(y1, f.y1))));
				if (y - (roof ? 3 : 2) < f.y0 || y > f.y1 + 1)
					continue;
				var len = g.range(2, 3);
				var x0 = f.dir > 0 ? f.x : f.x - len + 1;
				consider(x0, x0 + len - 1, y, f.dir > 0 ? -1 : 1, 0, -1, 2.5);
			}
		// (under a floor of the skeleton: the floor is the roof)
		if (roof)
			for (d in decks)
				for (t in 0...2) {
					var len = g.range(2, 3);
					if (d.x1 - d.x0 + 1 < len)
						continue;
					var atLeft = g.chance(0.5);
					var x0 = atLeft ? d.x0 : d.x1 - len + 1;
					consider(x0, x0 + len - 1, d.y + 3, atLeft ? 1 : -1, 1, -1, 2.0);
				}
		// (an alcove in a side of the screen, a notch in a block of its own)
		for (t in 0...12) {
			var s = sym ? -1 : (side != 0 ? side : (g.chance(0.5) ? -1 : 1));
			var len = g.range(2, 3);
			var y = g.range(y0, y1);
			if (!inner) {
				var x0 = s < 0 ? 0 : W - len;
				consider(x0, x0 + len - 1, y, s, 2, -1, 0.3);
			}
			var th = g.range(1, 2);
			var off = g.range(inner ? 3 : 1, inner ? 7 : 5);
			var wx = s < 0 ? off : W - off - th;
			var x0 = s < 0 ? wx + th : wx - len;
			if (free(wx - 1, wx + th, y - (roof ? 4 : 3), y + 2))
				consider(x0, x0 + len - 1, y, s, 3, wx, 0);
		}
		if (best == null)
			return false;
		var b = best;
		var y = b.y;
		h(b.x0, b.x1, y);
		if (b.form == 3) {
			// (the block: from the roof down to the ledge, the notch cut in it)
			var th = b.s < 0 ? b.x0 - b.wx : b.wx - b.x1;
			var lo = b.s < 0 ? b.wx : b.x1 + 1;
			for (k in 0...Std.int(Math.max(1, Math.min(2, Math.abs(th)))))
				col(lo + k, roof ? y - 3 : y - 2, y + g.range(0, 1));
			faces.push({x: b.s < 0 ? lo - 1 : lo + 2, dir: b.s < 0 ? -1 : 1, y0: y - 3, y1: y});
		}
		if (roof && b.form != 1) {
			var r0 = b.x0;
			var r1 = b.x1;
			if (b.form == 3) {
				r0 = Std.int(Math.min(r0, b.s < 0 ? b.wx : b.x1));
				r1 = Std.int(Math.max(r1, b.s < 0 ? b.x0 : b.x1 + 2));
			}
			h(r0, r1, y - 3);
		}
		if (g.floors.indexOf(y) < 0)
			g.floors.push(y);
		hold(b.x0 - 1, b.x1 + 1, y - (roof ? 4 : 3), y + 1);
		// (the bad at the back of the ledge)
		var bx = b.s < 0 ? b.x0 : b.x1;
		var spots = [{id: ids[0], x: bx, y: y - 1}];
		if (sym && ids.length > 1)
			spots.push({id: ids[1], x: W - 1 - bx, y: y - 1});
		addStage(roof ? "perch" : "balcony", ids, spots);
		return true;
	}

	// a ledge with its bad over a floor where Igor walks, 3 to 5 rows under it: the zests of a lemon go down to him, the
	// small apricots fall on him. A branch of a wall over a floor, a ledge over a floor of the skeleton, or both drawn
	function ledgeOver(kind:String, ids:Array<Int>):Bool {
		var best:{x0:Int, len:Int, y:Int, fx0:Int, fl:Int, fy:Int, newFloor:Bool} = null;
		var bv = -1.0e9;
		function consider(x0:Int, len:Int, y:Int, fx0:Int, fl:Int, fy:Int, newFloor:Bool, bonus:Float) {
			if (x0 < 0 || x0 + len > W || y < 6 || fy > H - 1 || (sym && x0 + len - 1 > 7))
				return;
			if (!free(x0, x0 + len - 1, y - 2, y + 1) || !free(x0, x0 + len - 1, y + 1, fy - 1))
				return;
			if (newFloor && !free(fx0 - 1, fx0 + fl, fy - 2, fy + 1))
				return;
			var v = apart(x0 + len / 2, y) + g.rnd(100) / 50 + bonus;
			if (v > bv) {
				bv = v;
				best = {x0: x0, len: len, y: y, fx0: fx0, fl: fl, fy: fy, newFloor: newFloor};
			}
		}
		// (over a floor of the skeleton, a branch of a wall standing over it or a ledge in the air)
		for (d in decks) {
			var dl = d.x1 - d.x0 + 1;
			if (dl < 3 || d.y < 7)
				continue;
			for (t in 0...3) {
				var len = g.range(2, Std.int(Math.min(4, dl)));
				var x0 = g.range(d.x0, d.x1 - len + 1);
				consider(x0, len, d.y - g.range(3, 5), d.x0, dl, d.y, false, 1.5);
			}
		}
		for (f in faces)
			for (t in 0...2) {
				var len = g.range(2, 3);
				var y = g.range(Std.int(Math.max(4, f.y0)), Std.int(Math.max(4, Math.min(10, f.y1))));
				var x0 = f.dir > 0 ? f.x : f.x - len + 1;
				// (the floor under it: one of the skeleton, or one drawn)
				var fy = y + g.range(3, 5);
				var fl = g.range(len + 3, len + 6);
				var fx0 = f.dir > 0 ? f.x : f.x - fl + 1;
				consider(x0, len, y, fx0, fl, fy, true, 2.0);
			}
		for (t in 0...16) {
			var len = g.range(2, 4);
			var y = g.range(4, 10);
			var fy = y + g.range(3, 5);
			var x0 = sym ? g.range(1, 7 - len) : g.range(1, W - 1 - len);
			var fl = g.range(len + 3, len + 6);
			var fx0 = Std.int(Math.max(0, Math.min(W - fl, x0 - g.range(1, fl - len - 1))));
			if (sym && fx0 + fl - 1 > 7)
				continue;
			consider(x0, len, y, fx0, fl, fy, true, 0);
		}
		if (best == null)
			return false;
		h(best.x0, best.x0 + best.len - 1, best.y);
		if (best.newFloor) {
			h(best.fx0, best.fx0 + best.fl - 1, best.fy);
			hold(best.fx0 - 1, best.fx0 + best.fl, best.fy - 2, best.fy + 1);
			addDeck(best.fx0, best.fx0 + best.fl - 1, best.fy);
		}
		if (g.floors.indexOf(best.y) < 0)
			g.floors.push(best.y);
		hold(best.x0 - 1, best.x0 + best.len, best.y - 2, best.y + 1);
		hold(best.x0, best.x0 + best.len - 1, best.y + 1, best.fy - 1);
		var lx = best.x0 + (best.len >> 1);
		var spots = [{id: ids[0], x: lx, y: best.y - 1}];
		if (sym && ids.length > 1)
			spots.push({id: ids[1], x: W - 1 - lx, y: best.y - 1});
		addStage(kind, ids, spots);
		return true;
	}

	// a platform in the open, nothing around it (the grains of a raspberry fly far)
	function field(ids:Array<Int>):Bool {
		var best:{x0:Int, len:Int, y:Int} = null;
		var bv = -1.0e9;
		for (t in 0...20) {
			var len = g.range(3, 4);
			var y = g.range(5, 13);
			if (sym && (W - len) % 2 != 0)
				len++;
			var x0 = sym ? (W - len) >> 1 : g.range(2, W - 2 - len);
			if (!free(x0 - 2, x0 + len + 1, y - 3, y + 2))
				continue;
			var v = apart(x0 + len / 2, y) + g.rnd(100) / 50;
			if (v > bv) {
				bv = v;
				best = {x0: x0, len: len, y: y};
			}
		}
		if (best == null)
			return false;
		h(best.x0, best.x0 + best.len - 1, best.y);
		if (g.floors.indexOf(best.y) < 0)
			g.floors.push(best.y);
		hold(best.x0 - 2, best.x0 + best.len + 1, best.y - 3, best.y + 2);
		addStage("field", ids, [{id: ids[0], x: best.x0 + (best.len >> 1), y: best.y - 1}]);
		return true;
	}

	// stairs (3 to 6 steps): a banana climbs, jumps, falls all over them (the stairs of the skeleton if there are some)
	function climb(ids:Array<Int>):Bool {
		if (SYSTEMS[system] == "slopes")
			for (d in decks)
				if (!d.used && d.y >= 4 && deckFree(d, 2)) {
					d.used = true;
					addStage("climb", ids, [{id: ids[0], x: d.x0, y: d.y - 1}]);
					return true;
				}
		for (t in 0...20) {
			var n = g.range(4, 6);
			var w = g.range(1, 2);
			var dir = sym ? -1 : (g.chance(0.5) ? -1 : 1);
			var y = g.range(5, 11);
			var span = n * w;
			var x = dir > 0 ? g.range(1, W - 1 - span) : g.range(span, W - 2);
			var xa = dir > 0 ? x : x - span + 1;
			var xb = dir > 0 ? x + span - 1 : x;
			if (xa < 0 || xb >= W || (sym && xb > 7) || y + n > H - 2)
				continue;
			if (!free(xa - 1, xb + 1, y - 3, y + n))
				continue;
			stairRun(x, y, dir, n, w);
			addStage("climb", ids, [{id: ids[0], x: x, y: y - 1}]);
			return true;
		}
		return false;
	}

	// ---------------------------------------------------------------- more of the level

	// more of the level until it has about the ground of a level made by hand (17 to 24 % of the screen): branches on
	// the faces of its walls (lined up with its floors), structures of their own (a colonnade, an arch, a block, a cliff
	// from a side, stairs)
	function enrich() {
		var target = g.range(17, 24) / 100;
		var guard = 0;
		while (groundShare() < target && guard++ < 12) {
			var ok = switch (g.draw([faces.length > 0 ? 5 : 0, 1, 1, 1, 1, 1])) {
				case 0: branch();
				case 1: colonnade();
				case 2: arch();
				case 3: block();
				case 4: cliff();
				default: stairsAlone();
			};
			if (!ok)
				count("enrich.no");
		}
	}

	function groundShare():Float {
		var n = 0;
		for (x in 0...W)
			for (y in 0...H)
				if (m[x][y] > 0)
					n++;
		return n / (W * H);
	}

	// a ledge of 2 to 4 cases out of the face of a wall, on a row of the floors when it can
	function branch():Bool {
		var best:{x0:Int, x1:Int, y:Int} = null;
		var bv = -1.0e9;
		for (f in faces)
			for (t in 0...3) {
				if (f.y1 - f.y0 < 2)
					continue;
				var y = g.range(f.y0 + 1, f.y1);
				var len = g.range(2, 4);
				var x0 = f.dir > 0 ? f.x : f.x - len + 1;
				var x1 = x0 + len - 1;
				if (x0 < 0 || x1 >= W || (sym && x1 > 8))
					continue;
				if (!free(x0, x1 + (f.dir > 0 ? 1 : 0) - (f.dir > 0 ? 0 : 1), y - 2, y + 2))
					continue;
				var v = align(y) * 2 + alignX(x0, x1, y) * 2 + g.rnd(100) / 50;
				if (v > bv) {
					bv = v;
					best = {x0: x0, x1: x1, y: y};
				}
			}
		if (best == null)
			return false;
		h(best.x0, best.x1, best.y);
		addDeck(best.x0, best.x1, best.y);
		hold(best.x0, best.x1, best.y - 1, best.y + 1);
		return true;
	}

	// stairs of their own (4 to 7 steps)
	function stairsAlone():Bool {
		for (t in 0...16) {
			var n = g.range(4, 7);
			var w = g.range(1, 2);
			var dir = sym ? -1 : (g.chance(0.5) ? -1 : 1);
			var y = g.range(4, 11);
			var span = n * w;
			var x = dir > 0 ? g.range(0, W - span) : g.range(span - 1, W - 1);
			var xa = dir > 0 ? x : x - span + 1;
			var xb = dir > 0 ? x + span - 1 : x;
			if (xa < 0 || xb >= W || (sym && xb > 7) || y + n > H - 2)
				continue;
			if (!free(xa - 1, xb + 1, y - 2, y + n))
				continue;
			stairRun(x, y, dir, n, w);
			return true;
		}
		return false;
	}

	// 2 or 3 pillars of the same height in a row, standing on the bottom or in the air, a lintel over them sometimes
	function colonnade():Bool {
		for (t in 0...16) {
			var n = sym ? 2 : g.range(2, 3);
			var gap = g.range(2, 4);
			var hgt = g.range(3, 6);
			var span = n + (n - 1) * gap;
			var x0 = sym ? g.range(1, 4) : g.range(1, W - 1 - span);
			if (sym && x0 + span - 1 > 7)
				continue;
			var standing = g.chance(0.5);
			var yb = standing ? H - 2 : g.range(9, 14);
			var y0 = yb - hgt + 1;
			if (y0 < 3 || !free(x0 - 1, x0 + span, y0 - 2, yb + 1))
				continue;
			for (i in 0...n)
				wall(x0 + i * (gap + 1), 1, y0, yb);
			if (!standing || g.chance(0.4)) {
				h(x0 - 1, x0 + span, y0 - 1);
				addDeck(x0 - 1, x0 + span, y0 - 1);
			}
			hold(x0 - 1, x0 + span, y0 - 2, yb + 1);
			return true;
		}
		return false;
	}

	// an arch: a lintel on two legs
	function arch():Bool {
		for (t in 0...16) {
			var w = g.range(5, 9);
			if (sym && (W - w) % 2 != 0)
				w++;
			var legs = g.range(2, 4);
			var y = g.range(5, 12);
			var x0 = sym ? (W - w) >> 1 : g.range(1, W - 1 - w);
			var x1 = x0 + w - 1;
			if (y + legs > H - 2 || !free(x0 - 1, x1 + 1, y - 3, y + legs + 1))
				continue;
			h(x0, x1, y);
			wall(x0, 1, y + 1, y + legs);
			wall(x1, 1, y + 1, y + legs);
			addDeck(x0, x1, y);
			hold(x0 - 1, x1 + 1, y - 3, y + legs + 1);
			return true;
		}
		return false;
	}

	// a block of rock, 2 to 4 cases wide, 2 to 3 high
	function block():Bool {
		for (t in 0...16) {
			var w = g.range(2, 4);
			var hh = g.range(2, 3);
			var x0 = sym ? g.range(1, 8 - w) : g.range(1, W - 1 - w);
			var y = g.range(5, 13);
			if (!free(x0 - 1, x0 + w, y - 3, y + hh))
				continue;
			for (k in 0...w)
				col(x0 + k, y, y + hh - 1);
			addDeck(x0, x0 + w - 1, y);
			if (x0 > 0)
				faces.push({x: x0 - 1, dir: -1, y0: y, y1: y + hh - 1});
			if (x0 + w < W)
				faces.push({x: x0 + w, dir: 1, y0: y, y1: y + hh - 1});
			hold(x0 - 1, x0 + w, y - 3, y + hh);
			return true;
		}
		return false;
	}

	// a cliff from a side of the screen, its edge going down in steps
	function cliff():Bool {
		for (t in 0...12) {
			var s = sym ? -1 : (g.chance(0.5) ? -1 : 1);
			var w = g.range(3, 5);
			var y = g.range(8, 12);
			var x0 = s < 0 ? 0 : W - w;
			if (!free(x0, x0 + w - 1, y - 3, H - 2))
				continue;
			for (k in 0...w) {
				var e = s < 0 ? k : w - 1 - k;
				var top = y + Std.int(e * 1.5);
				col(x0 + k, top, H - 2);
				addDeck(x0 + k, x0 + k, top);
			}
			faces.push({x: s < 0 ? x0 + w : x0 - 1, dir: s < 0 ? 1 : -1, y0: y + Std.int((w - 1) * 1.5), y1: H - 2});
			hold(x0 - 1, x0 + w, y - 3, H - 2);
			return true;
		}
		return false;
	}

	// ---------------------------------------------------------------- the frame: bottom, entry, shelves

	// the bottom of the level: a floor across with holes of 3 cases (the ways down: the bads never jump over 3 cases,
	// World.parseIA, a bad missing its jump over a smaller one would fall out of the level), floors from the sides with
	// the middle open, or a floor in the middle with the sides open
	function bottom() {
		var y = H - 1;
		switch (g.draw([5, 3, 3])) {
			case 0:
				h(0, W - 1, y);
				if (sym) {
					for (x in 7...11)
						setc(x, y, 0);
					if (g.chance(0.5)) {
						var hx = g.range(1, 3);
						h(hx, hx + 2, y, 0);
					}
				} else {
					var hx = g.range(1, 14);
					for (k in 0...3)
						setc(hx + k, y, 0);
					if (g.chance(0.5)) {
						var hx2 = hx < 9 ? g.range(hx + 6, 15) : g.range(0, hx - 6);
						if (hx2 >= 0 && hx2 + 2 < W)
							for (k in 0...3)
								setc(hx2 + k, y, 0);
					}
				}
			case 1:
				var a = g.range(4, 7);
				h(0, a - 1, y);
				if (!sym)
					h(W - g.range(4, 7), W - 1, y);
			default:
				var len = g.range(8, 12);
				if (sym && (W - len) % 2 != 0)
					len++;
				var x0 = sym ? (W - len) >> 1 : g.range(2, W - 2 - len);
				h(x0, x0 + len - 1, y);
		}
		g.floors.push(y);
	}

	// the platform where Igor comes in at the top: away from the shooters of the stages, free around it (on the top of
	// a trunk or a wall when there is one up there); the first level (the start of a game): at mid-height
	function entry() {
		var first = g.depth == 0;
		var ya = first ? START_Y0 + 1 : 2;
		var yb = first ? START_Y1 : 4;
		for (d in decks)
			if (d.y >= ya && d.y <= (first ? yb : yb + 1) && !d.used && d.x1 - d.x0 + 1 >= 2 && deckFree(d, 2)
				&& g.chance(0.6))
				return;
		var best:{x0:Int, len:Int, y:Int} = null;
		var bv = -1.0e9;
		// (the first level: a second round closer to the walls, its rooms may be narrow at mid-height)
		for (t in 0...(first ? 48 : 24)) {
			var len = sym ? 4 : g.range(3, 4);
			var y = g.range(ya, yb);
			var x0 = sym ? (W - len) >> 1 : g.range(2, W - 2 - len);
			if (first && t >= 24) {
				len = 3;
				x0 = g.range(1, W - 1 - len);
				if (!free(x0, x0 + len - 1, y - 2, y))
					continue;
			} else if (!free(x0 - 1, x0 + len, y - 1, y + 2))
				continue;
			var v = g.rnd(100) / 50 - Math.abs(x0 + len / 2 - 9) * 0.15;
			for (s in stages) {
				for (id in s.ids)
					if (id == Data.BAD_FRAISE || id == Data.BAD_POIRE || id == Data.BAD_POMME)
						v += Math.min(6, Math.abs(s.cx - (x0 + len / 2))) * 0.3;
				// (Igor lands there at the start: no bad within 2 rows and 5 cases)
				for (p in s.spots)
					if (Math.abs(p.y - (y - 1)) <= 2 && p.x >= x0 - 5 && p.x <= x0 + len + 4)
						v -= 6;
			}
			if (v > bv) {
				bv = v;
				best = {x0: x0, len: len, y: y};
			}
		}
		if (best == null)
			return;
		h(best.x0, best.x0 + best.len - 1, best.y);
		if (g.floors.indexOf(best.y) < 0)
			g.floors.push(best.y);
	}

	// the rows where Igor stands at the start of a game (LevelGen.placeStart: the first level)
	public static inline var START_Y0 = 7;
	public static inline var START_Y1 = 11;

	// shelves for the other bads (the long ones first) where the stages leave room, and for the saws deep in the well
	// (small blocks to go around)
	function fill() {
		var need = (g.lineup == null ? 6 : g.lineup.list.length) + (g.depth >= 5 ? 1 : 0) + (g.depth >= 12 ? 1 : 0)
			+ (g.depth >= 20 ? 1 : 0);
		var guard = 0;
		while (places() < need && guard++ < 4 && faces.length > 0)
			if (!branch())
				break;
		guard = 0;
		while (places() < need && guard++ < 8) {
			var n = g.floors.length;
			g.addShelves(1, 3, 15, 3, 5);
			if (g.floors.length == n)
				break;
		}
	}

	// the places for bads (a platform of 2 cases or more, a bad every 4 cases)
	function places():Int {
		var n = 0;
		for (y in 1...H - 1) {
			var x = 0;
			while (x < W) {
				if (m[x][y] <= 0 && m[x][y + 1] > 0) {
					var x0 = x;
					while (x < W && m[x][y] <= 0 && m[x][y + 1] > 0)
						x++;
					var len = x - x0;
					if (len >= 2)
						n += len <= 6 ? 1 : (len <= 10 ? 2 : 3);
				} else
					x++;
			}
		}
		return n;
	}

	// ---------------------------------------------------------------- drawing

	inline function inb(x:Int, y:Int):Bool {
		return x >= 0 && x < W && y >= 0 && y < H;
	}

	inline function setc(x:Int, y:Int, v:Int) {
		if (inb(x, y))
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

	// nothing drawn nor kept in a box (the sides of the screen are outside: fine)
	function free(x0:Int, x1:Int, y0:Int, y1:Int):Bool {
		if (y0 < 1 || y1 > H - 1)
			return false;
		for (x in x0...x1 + 1)
			for (y in y0...y1 + 1)
				if (inb(x, y) && (m[x][y] != 0 || keep[x][y]))
					return false;
		return true;
	}

	function hold(x0:Int, x1:Int, y0:Int, y1:Int) {
		for (x in x0...x1 + 1)
			for (y in y0...y1 + 1)
				if (inb(x, y)) {
					keep[x][y] = true;
					if (sym)
						keep[W - 1 - x][y] = true;
				}
	}

	function isSym():Bool {
		for (y in 0...H)
			for (x in 0...9)
				if (m[x][y] != m[W - 1 - x][y])
					return false;
		return true;
	}
}
