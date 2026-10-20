package hammerfest;

// a kind of bad for the generator (Gen)
typedef KindRule = {
	id:Int, // Data.BAD_*
	name:String,
	weight:Float, // how hard one of them is: the bads of a level add up to budget(level)
	from:Int, // first level where it comes (that level shows it off)
	max:Int, // at most in one level
	rarity:Float, // factor of its chance to be drawn
	counts:Bool // a fruit to kill to clear the level (a saw is not)
}

// The settings of the generator of the levels (Gen): weight of each bad, the level it comes at, how many of them,
// the difficulty along the well, the darkness, the fireball, the ways of building by depth, the devices.
// Levels are numbered like the game shows them (0 is the first one).
class GenRules {
	// one kind more at each level from the start, like before (the shooters early: lemons 4, pears 6, strawberries 7)
	public static var KINDS:Array<KindRule> = [
		{id: Data.BAD_CERISE, name: "Cerise", weight: 1.0, from: 0, max: 6, rarity: 1.0, counts: true},
		{id: Data.BAD_ORANGE, name: "Orange", weight: 1.5, from: 1, max: 6, rarity: 1.0, counts: true},
		{id: Data.BAD_POMME, name: "Pomme", weight: 2.5, from: 2, max: 4, rarity: 1.0, counts: true},
		{id: Data.BAD_BANANE, name: "Banane", weight: 2.5, from: 3, max: 5, rarity: 1.0, counts: true},
		{id: Data.BAD_CITRON, name: "Citron", weight: 3.5, from: 4, max: 4, rarity: 1.3, counts: true},
		{id: Data.BAD_BOMBE, name: "Bombino", weight: 2.5, from: 5, max: 2, rarity: 0.8, counts: true},
		{id: Data.BAD_POIRE, name: "Poire", weight: 4.0, from: 6, max: 4, rarity: 1.4, counts: true},
		{id: Data.BAD_FRAISE, name: "Fraise", weight: 3.5, from: 7, max: 6, rarity: 1.2, counts: true},
		{id: Data.BAD_ABRICOT, name: "Abricot", weight: 4.0, from: 8, max: 4, rarity: 0.6, counts: true},
		{id: Data.BAD_KIWI, name: "Kiwi", weight: 3.5, from: 9, max: 3, rarity: 0.8, counts: true},
		{id: Data.BAD_LITCHI, name: "Litchi", weight: 3.5, from: 10, max: 3, rarity: 0.8, counts: true},
		{id: Data.BAD_CRAWLER, name: "Blob", weight: 3.5, from: 11, max: 2, rarity: 0.6, counts: true},
		{id: Data.BAD_SAW, name: "Scie", weight: 4.0, from: 12, max: 2, rarity: 0.6, counts: false},
		{id: Data.BAD_ANANAS, name: "Ananas", weight: 5.0, from: 13, max: 2, rarity: 0.6, counts: true},
		{id: Data.BAD_BALEINE, name: "Bondissante", weight: 4.5, from: 15, max: 2, rarity: 0.4, counts: true},
		{id: Data.BAD_FRAMBOISE, name: "Framboisjule", weight: 5.5, from: 16, max: 3, rarity: 0.5, counts: true}
	];

	// a strawberry alone throws its ball at Igor
	public static inline var LONE_STRAWBERRY = 2.5;

	public static function kind(id:Int):KindRule {
		for (k in KINDS)
			if (k.id == id)
				return k;
		return null;
	}

	// weight of all the bads of a level aimed at: 2 or 3 fruits for the very first levels, 5 at level 4, 6 at 7, 7 at
	// 20 (like before), then heavier and heavier ones
	public static function budget(level:Int):Float {
		if (level <= 1)
			return 2.0 + 0.5 * level;
		if (level <= 3)
			return 3.0 + 1.5 * (level - 1);
		if (level <= 7)
			return 10.0 + 5 / 3 * (level - 4);
		if (level <= 20)
			return 15.0 + 0.85 * (level - 7);
		if (level <= 50)
			return 26.0 + 0.27 * (level - 20);
		return 26.0 + 0.27 * 30 + 0.4 * (level - 50);
	}

	// fruits in a level (saws apart)
	public static function maxFruits(level:Int):Int {
		return level <= 1 ? 2 : (level <= 3 ? 3 : (level <= 6 ? 5 : (level < 20 ? 6 : 7)));
	}

	public static function minFruits(level:Int):Int {
		return level <= 1 ? 2 : (level <= 3 ? 3 : (level <= 6 ? 4 : (level < 20 ? 5 : 6)));
	}

	// the heavy bads come more often down the well: chance ~ weight ^ force (a mix of kinds all the same)
	public static function force(level:Int):Float {
		return Math.max(0, Math.min(1.0, (level - 2) / 16));
	}

	// the weak kinds fade away down the well: no cherry nor orange from level 10 (no point there), apples and bananas
	// rarer and rarer
	public static function fade(id:Int, level:Int):Float {
		if (id == Data.BAD_CERISE || id == Data.BAD_ORANGE)
			return level >= 10 ? 0 : (level >= 6 ? 0.4 : 1.0);
		if (id == Data.BAD_POMME || id == Data.BAD_BANANE)
			return level >= 14 ? 0.2 : (level >= 8 ? 0.5 : 1.0);
		return 1.0;
	}

	// how hard the placing of the bads is (0 for the very first levels, 1 from level 12): fruits their ice leaves the
	// level from at the first push, fruits bombed from the platform over them, fruits in a row a pushed ice kills
	// together (surfing), avoided more and more
	public static function hard(level:Int):Float {
		return Math.max(0, Math.min(1, (level - 3) / 9));
	}

	// share of the fruits put where white bombs never throw their ice out (shut in: a laser of other bombs on the way
	// to them), like before: about half of them deep in the well
	public static function shutShare(level:Int):Float {
		return level < 4 ? 0 : (level < 8 ? 0.15 : (level < 12 ? 0.35 : 0.5));
	}

	// darkness (%): from level 3, then black all around the light of Igor at level 50
	public static function darkness(level:Int):Int {
		return level < 3 ? 0 : Std.int(Math.min(100, 10 + (level - 3) * 90 / 47));
	}

	// seconds before the fireball: the first VITE ! then the second one (Game.hurryStep)
	public static function fireball(level:Int):Float {
		return Math.max(14, 35 - level * 1.4) + Math.max(9, 25 - level * 1.0);
	}

	// ways of building a level (GenShapes), weights from a level on
	public static var SHAPES:Array<{from:Int, w:Map<String, Float>}> = [
		{from: 0, w: ["etages" => 1.0]},
		{from: 4, w: [
			"etages" => 1.0, "briques" => 0.4, "coupes" => 0.15, "colonnes" => 0.5, "serpentin" => 0.15, "pyramide" => 0.25,
			"escaliers" => 0.2
		]},
		{from: 8, w: [
			"etages" => 0.45, "briques" => 0.25, "coupes" => 0.2, "colonnes" => 0.45, "escaliers" => 0.12, "iles" => 0.15,
			"pyramide" => 0.15, "serpentin" => 0.12, "salles" => 1.0, "labyrinthe" => 0.6
		]},
		{from: 12, w: [
			"etages" => 0.45, "briques" => 0.25, "coupes" => 0.2, "colonnes" => 0.45, "escaliers" => 0.12, "iles" => 0.15,
			"pyramide" => 0.15, "serpentin" => 0.12, "salles" => 1.0, "labyrinthe" => 0.6, "dedale" => 0.5
		]},
		{from: 20, w: [
			"etages" => 0.3, "briques" => 0.15, "coupes" => 0.2, "colonnes" => 0.4, "escaliers" => 0.1, "iles" => 0.12,
			"pyramide" => 0.1, "serpentin" => 0.1, "salles" => 1.0, "labyrinthe" => 1.0, "dedale" => 1.2
		]}
	];
	// the order of the ways of building (the maps above are not iterated: always in this order)
	public static var SHAPE_NAMES = [
		"etages", "briques", "coupes", "colonnes", "escaliers", "iles", "pyramide", "serpentin", "salles", "labyrinthe",
		"dedale"
	];

	// a way of building used in the last levels is avoided: the last 2 levels, more for the ones a player recognizes at
	// once (the cups in rows, the snake of rows, the pyramids, the stairs, the mazes, the buildings)
	public static inline var SHAPE_MEMORY = 2;

	public static function memory(shape:String):Int {
		return switch (shape) {
			case "serpentin": 12;
			case "coupes": 8;
			case "pyramide": 6;
			case "escaliers": 5;
			case "dedale": 4;
			case "salles", "labyrinthe": 3;
			default: SHAPE_MEMORY;
		}
	}

	// bads fond of some ways of building (factor of the weight of the way)
	public static function affinity(id:Int, shape:String):Float {
		var m:Map<String, Float> = switch (id) {
			case Data.BAD_BALEINE: ["iles" => 2.0, "etages" => 1.4, "salles" => 0.3, "labyrinthe" => 0.2, "coupes" => 0.6];
			case Data.BAD_ANANAS: ["iles" => 1.8, "escaliers" => 1.5, "colonnes" => 1.4, "etages" => 0.7];
			case Data.BAD_FRAISE: ["etages" => 1.4, "colonnes" => 1.3, "salles" => 1.2, "iles" => 1.2];
			case Data.BAD_CITRON: ["etages" => 1.2];
			case Data.BAD_ORANGE: ["etages" => 1.5, "iles" => 0.6];
			case Data.BAD_SAW: ["iles" => 1.3, "colonnes" => 1.2];
			default: null;
		}
		return m != null && m.exists(shape) ? m.get(shape) : 1.0;
	}

	// devices put for themselves (the ones a shut fruit needs come anyway)
	// green bombs (flasks) on the way to the shooters
	public static function chanceGreen(level:Int):Float {
		return level < 8 ? 0 : 0.12;
	}

	// a room shut in a corner reached by a teleporter, bads in it
	public static function chanceRoom(level:Int):Float {
		return level < 8 ? 0 : Math.min(0.18, 0.1 + 0.004 * (level - 8));
	}

	// two teleporters between two places far apart
	public static function chanceShortcut(level:Int):Float {
		return level < 10 ? 0 : Math.min(0.3, 0.1 + 0.008 * (level - 10));
	}

	// a closed bottom (a floor with a few holes): the ice of the fruits no longer falls out of the level at the first
	// push everywhere
	public static function chanceClosedBottom(level:Int):Float {
		return level < 4 ? 0 : Math.min(0.95, 0.35 + 0.08 * (level - 4));
	}

	// prisons (cups, cells with a hatch) drawn on the platforms for fruits that stay shut in
	public static function prisons(level:Int):Int {
		return level < 6 ? 0 : (level < 12 ? 1 : (level < 24 ? Gen.ri(1, 2) : Gen.ri(1, 3)));
	}

	// strips of spikes on the ways of Igor
	public static function spikes(level:Int):Int {
		return level < 6 ? 0 : (level < 12 ? (Gen.chance(0.7) ? 1 : 0) : (level < 20 ? Gen.ri(1, 2) : Gen.ri(1, 3)));
	}

	// lasers across passages to the fruits behind them (gates)
	// a gate decided before the fruits (some of them put behind it on purpose)
	public static function chancePlannedGate(level:Int):Float {
		return level < 6 ? 0 : (level < 10 ? 0.35 : (level < 18 ? 0.6 : 0.8));
	}

	public static function gates(level:Int):Int {
		return level < 6 ? 0 : (level < 10 ? (Gen.chance(0.6) ? 1 : 0) : (level < 18 ? Gen.ri(1, 2) : Gen.ri(2, 3)));
	}

	// a vault in a building (a room without door entered through its ceiling)
	public static function chanceVault(level:Int):Float {
		return level < 8 ? 0 : 0.85;
	}

	// jumps of Igor (cases): a jump, a jump and two bombs (only asked from JUMP_BOMBS_FROM), a bounce on a red bomb
	public static inline var JUMP = 3;
	public static inline var JUMP_BOMBS = 4;
	public static inline var JUMP_BOMBS_FROM = 12;
	public static inline var JUMP_RED = 6;
	// red lasers from this level on: the red bombs throw the frozen fruits high, they must go off away from them (hard)
	public static inline var RED_FROM = 30;

	// levels drawn for each level of the well (the best one is kept)
	public static inline var TRIES = 10;
}
