package hammerfest;

// The idea of a level: what it is made for. The levels of the original were made by hand around a trick (a nest of
// strawberries over a void, a crossfire of lemons over the shaft Igor climbs, a pineapple in an arena of shooters, a
// field of kiwi mines on the landings...): each level of the well is drawn around one of these ideas. The idea chooses
// together the kinds of bads (the leading kind and the ones that go with it, never a mix of kinds at random), the
// devices (lasers of a colour, teleporters, spikes, a vault, a cellar...), the drawing (its layouts, its motifs, a
// bottom left open over the void or not) and how hard the level is. Never the same idea twice in 4 levels, rarely in 8.
typedef Concept = {
	id:String,
	minDepth:Int,
	maxDepth:Int,
	weight:Float,
	// the kinds that may lead the level (none: any), the kinds around them (none: the kinds the original puts with the
	// leading one), the number of kinds (drawn among these)
	leads:Array<Int>,
	support:Array<Int>,
	kinds:Array<Int>,
	// devices drawn for it (LevelFeatures), the piece drawn in the level ("close": the cellar), the layout forced
	want:Array<String>,
	piece:String,
	layout:String,
	// chance of a bottom left open: no ground at the bottom, the void (the ice falling there dies, Igor falling there
	// loses a life before the end of the level)
	open:Float,
	// weights of the layouts and the main motifs (1 by default)
	layouts:Map<String, Float>,
	mains:Map<String, Float>,
	// colours of the lasers: weights of green, blue, red
	colours:Array<Float>,
	// the bads of the level (1: the usual number), a strawberry alone / a pineapple added deep in the well
	hard:Float,
	extras:Bool
}

class LevelConcept {
	// (kinds: cerise 1, orange 9, pomme 0, banane 2, citron 11, bombe 8, poire 7, fraise 10, abricot 5, kiwi 18,
	// litchi 17, ananas 4, framboise 20, baleine 12)
	static var C = Data.BAD_CERISE;
	static var O = Data.BAD_ORANGE;
	static var P = Data.BAD_POMME;
	static var B = Data.BAD_BANANE;
	static var L = Data.BAD_CITRON;
	static var BO = Data.BAD_BOMBE;
	static var PO = Data.BAD_POIRE;
	static var F = Data.BAD_FRAISE;
	static var A = Data.BAD_ABRICOT;
	static var K = Data.BAD_KIWI;
	static var LI = Data.BAD_LITCHI;
	static var N = Data.BAD_ANANAS;
	static var R = Data.BAD_FRAMBOISE;

	public static var ALL:Array<Concept> = null;

	static function c(id:String, min:Int, weight:Float, leads:Array<Int>, support:Array<Int>, kinds:Array<Int>, open:Float,
			?mains:Map<String, Float>, ?layouts:Map<String, Float>, ?want:Array<String>, ?colours:Array<Float>, ?hard:Float = 1.0,
			?extras:Bool = false, ?piece:String = "", ?layout:String = "", ?max:Int = 9999):Concept {
		return {
			id: id,
			minDepth: min,
			maxDepth: max,
			weight: weight,
			leads: leads,
			support: support,
			kinds: kinds,
			want: want == null ? [] : want,
			piece: piece,
			layout: layout,
			open: open,
			layouts: layouts == null ? new Map() : layouts,
			mains: mains == null ? new Map() : mains,
			colours: colours == null ? [1, 1, 1] : colours,
			hard: hard,
			extras: extras
		};
	}

	static function init() {
		if (ALL != null)
			return;
		ALL = [
			// the first steps: a few long floors high in the level, the void under them (the first levels of the
			// original), the kinds met first
			c("debut", 0, 1.0, [], [], [1], 0.95, null, null, null, null, 1.0, false, "", "", 3),
			// the void: platforms over the void, kinds that cross the gaps toward Igor; a push of a bomb throws their
			// ice out of the level, a jump missed throws Igor out of it
			c("vide", 4, 1.3, [O, B, LI, K, P, C], [L, PO, O, B], [1, 2, 2], 1.0,
				["lattice" => 2.0, "stairs" => 1.6, "arches" => 1.3, "tree" => 1.1, "pillars" => 0.9, "box" => 0.4, "rooms" => 0.3,
					"mound" => 0.3],
				["full" => 1.5, "center" => 1.2, "three" => 1.2, "bands" => 0.6], null, [1.5, 0.8, 1]),
			// crossfire: the shooters over and under the shaft Igor climbs (lemons straight up and down, pears lobbing
			// bombs from high up, apples at the ends of the rows)
			c("tirs", 4, 1.3, [L, PO, P], [L, PO, P, B, O], [2, 2, 3], 0.4,
				["ladder" => 2.2, "spines" => 1.9, "pillars" => 1.6, "tree" => 1.4, "hooks" => 1.3, "lattice" => 0.6, "box" => 0.5],
				["three" => 1.5, "center" => 1.3, "bands" => 1.1], null, [0.8, 1, 1.4], 1.05),
			// the strawberries: sheltered from the bombs from above, far from each other, their ball across the ways
			c("fraises", 7, 1.1, [F], [PO, L, BO, K], [1, 2, 2], 0.3,
				["rooms" => 1.7, "box" => 1.5, "hooks" => 1.5, "arches" => 1.3, "tree" => 1.1], ["center" => 1.3, "pair" => 1.2],
				null, [0.8, 1, 1.4]),
			// the nest: strawberries (or pears) perched where only the jump of a red bomb goes
			c("nid", 10, 0.9, [F, PO], [L, A, BO], [1, 2], 0.4, ["tree" => 1.4, "spines" => 1.3, "pillars" => 1.3, "lattice" => 1.2],
				["full" => 1.3, "bands" => 1.1], ["nest"], [0.5, 0.5, 2.5], 1.05, false, "nest"),
			// the cellar: a room of the bottom reached only by a teleporter, a laser of black bombs at its door
			c("cave", 6, 1.2, [], [], [1, 2, 2], 0.6, null, ["full" => 1.2, "center" => 1.2], null, null, 1.0, true, "close"),
			// the two banks: a wall from the top to the bottom, the roofed half reached by two teleporters
			c("rives", 8, 0.35, [L, PO, BO, F, A, K, LI, R], [], [2, 2, 3], 0.5, null, null, null, null, 1.05, true, "", "split"),
			// the arena: a pineapple on a wide floor in the middle, shooters around it (Igor knocked out under fire);
			// a blue laser: its bombs stun the pineapple without throwing it
			c("arene", 11, 1.0, [N], [L, P, PO, F], [2, 2, 3], 0.3,
				["mound" => 1.8, "box" => 1.4, "arches" => 1.4, "lattice" => 1.0, "stairs" => 0.8],
				["center" => 2.0, "full" => 1.3, "bands" => 1.1], ["gate"], [0.6, 2.5, 0.8], 1.1),
			// the minefield: kiwis on the landings Igor must cross, runners with them; a green laser (mines against the
			// runners)
			c("mines", 9, 1.0, [K], [B, O, LI, L], [1, 2, 2], 0.5,
				["stairs" => 1.9, "arches" => 1.5, "lattice" => 1.3, "pillars" => 1.3, "ladder" => 1.0],
				["full" => 1.3, "bands" => 1.2], ["gate"], [2.5, 0.7, 0.7]),
			// the Bombinos: narrow places where Igor cannot flee the blast; a blue laser (they do not explode)
			c("bombinos", 5, 1.0, [BO], [O, PO, L, C], [1, 2, 2], 0.3,
				["rooms" => 1.9, "box" => 1.7, "ladder" => 1.5, "hooks" => 1.3, "spines" => 1.2], ["center" => 1.3, "pair" => 1.2],
				["gate"], [0.6, 2.5, 0.6]),
			// the vault: a box or rooms shut, their windows a laser of black bombs
			// (never over the void: the vault stands on the bottom)
			c("coffre", 7, 0.7, [], [], [1, 2, 2], 0.0, ["box" => 1.6, "rooms" => 1.6], ["center" => 1.5, "full" => 1.0],
				["vault"], null, 1.0, true),
			// the spikes: kinds that keep to their floors (their ice kicked onto the spikes), spikes on the ways of Igor
			c("pics", 6, 1.0, [F, L, O, PO, N], [F, L, O, PO, C], [1, 2], 0.3,
				["hooks" => 1.5, "box" => 1.3, "rooms" => 1.3, "spines" => 1.2, "pillars" => 1.2], null, ["spikes"]),
			// disarmed: a passage crossed without bombs, the laser of the bombs back further on
			// (a passage crossed without bombs: too rarely possible in these levels, left to the devices drawn at random)
			c("desarme", 9, 0.0, [], [], [1, 2, 2], 0.4, null, ["full" => 1.2, "bands" => 1.2], ["disarm"], null, 1.0, true),
			// the litchis: long floors on the way of Igor, where the naked litchi chases him; a green laser
			c("litchis", 10, 0.9, [LI], [L, PO, O], [1, 2], 0.6, ["lattice" => 1.7, "stairs" => 1.6, "arches" => 1.4],
				["full" => 1.3, "bands" => 1.2], ["gate"], [2.2, 0.8, 0.8], 1.05),
			// the apricots: rooms and shafts where the small apricots fall back on Igor
			c("abricots", 8, 0.9, [A], [PO, L], [1, 2], 0.3, ["rooms" => 1.8, "box" => 1.5, "spines" => 1.4, "ladder" => 1.3],
				["center" => 1.2, "pair" => 1.2]),
			// the raspberries: the open air, their trails across the ways of Igor
			c("framboises", 16, 1.0, [R], [L, PO, F, K], [2, 2, 3], 0.6, ["lattice" => 1.5, "tree" => 1.4, "arches" => 1.3,
				"stairs" => 1.2], ["full" => 1.4, "three" => 1.1], null, [1.5, 1, 1], 1.05),
			// a breather: many weak bads in rows (combos of ice sliding along them)
			c("combo", 3, 0.9, [C, O, P, B], [C, O, P], [1, 2], 0.6, ["lattice" => 2.0, "arches" => 1.5, "stairs" => 1.3],
				["full" => 1.4, "bands" => 1.2], null, null, 0.85, false, "", "", 30),
			// the leapers: flying watermelons in the open air, a few others
			c("bondissantes", 25, 1.1, [L, PO, O, F, B], [L, PO, F], [1, 2], 0.7, ["lattice" => 1.4, "tree" => 1.4, "arches" => 1.3,
				"few" => 0.0], ["full" => 1.5, "three" => 1.1], null, null, 1.0, false),
		];
	}

	public static function get(id:String):Concept {
		init();
		for (k in ALL)
			if (k.id == id)
				return k;
		return null;
	}

	// the idea shown at the level of a new kind (its first level: the place made for its power)
	static function showcase(kind:Int):String {
		return switch (kind) {
			case Data.BAD_CERISE, Data.BAD_ORANGE, Data.BAD_POMME: "debut";
			case Data.BAD_BANANE: "vide";
			case Data.BAD_CITRON, Data.BAD_POIRE: "tirs";
			case Data.BAD_BOMBE: "bombinos";
			case Data.BAD_FRAISE: "fraises";
			case Data.BAD_ABRICOT: "abricots";
			case Data.BAD_KIWI: "mines";
			case Data.BAD_LITCHI: "litchis";
			case Data.BAD_ANANAS: "arene";
			case Data.BAD_FRAMBOISE: "framboises";
			default: "vide";
		}
	}

	// test harness: every level with this idea
	public static var force:String = null;

	// the ideas of the last levels (the last one first)
	static var recent:Array<String> = [];

	public static function reset() {
		recent = [];
	}

	public static function remember(id:String) {
		recent.unshift(id);
		if (recent.length > 10)
			recent.pop();
	}

	// the idea of the level: the one of a new kind at its first level, else drawn among the ones its depth allows
	public static function pick(depth:Int):Concept {
		init();
		if (force != null) {
			var f = get(force);
			if (f != null)
				return f;
		}
		var intro = LevelCast.introKind(depth);
		if (depth <= 3)
			return get("debut");
		if (intro >= 0)
			return get(showcase(intro));
		// (the first leaper of the well)
		if (depth == LevelCast.LEAPER_DEPTH)
			return get("bondissantes");
		var kinds = LevelCast.unlocked(depth);
		var th = LevelTheme.of(depth);
		var w = [for (k in ALL) {
			var v = k.weight;
			if (depth < k.minDepth || depth > k.maxDepth || k.id == "debut")
				v = 0;
			// (an idea of a kind not met yet)
			if (k.leads.length > 0) {
				var any = false;
				for (id in k.leads)
					if (kinds.indexOf(id) >= 0)
						any = true;
				if (!any)
					v = 0;
			}
			// (the ideas of the last levels: never in the last 4, rarely in the 4 before)
			var i = recent.indexOf(k.id);
			if (i >= 0)
				v *= i < 4 ? 0 : (i < 8 ? 0.3 : 1);
			// (the dimension: its devices more often)
			for (f in k.want)
				if (th.features.exists(f))
					v *= th.features.get(f);
			// (the kinds of the dimension leading)
			for (t in th.leads)
				if (k.leads.indexOf(t) >= 0)
					v *= 1.5;
			// (a breather at the start of a chapter of 5 levels, the hard ideas at its end)
			if (depth >= 15) {
				var pos = depth % 5;
				if (k.hard < 1)
					v *= pos == 0 ? 3 : 0.6;
				else if (k.hard > 1)
					v *= pos >= 3 ? 1.6 : 0.8;
			}
			v;
		}];
		var i = Cs.draw([for (v in w) Std.int(v * 100)]);
		return i < 0 ? get("vide") : ALL[i];
	}
}
