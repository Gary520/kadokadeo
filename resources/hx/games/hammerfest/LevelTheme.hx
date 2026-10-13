package hammerfest;

// The dimensions of the well: from level 10, chapters of 5 levels going through the hard dimensions of the original
// (the world of Deepnight: the Hells, Metal hurlant, the Crypt of the raspberries, Egypt, the tomb of Tuberculoz), each
// with the skins of its levels, its ways of drawing (LevelDesign), the bads leading there and its features
// (LevelFeatures): the Hells of stalactites, rooms and stairs and of teleporters, Metal hurlant of saws and crawlers
// among its spines, lattices and boxes, the Crypt of spikes and raspberries in its rooms, Egypt of stairs, trees, arches
// and pillars and of pits, the tomb of Tuberculoz of boxes, rooms and vaults. The first levels: the caverns of the
// adventure.
typedef Theme = {
	name:String,
	skins:Array<Array<Int>>, // background, tiles (+ 100 x column) of the levels of the dimension
	systems:Array<String>, // its motifs (LevelDesign), drawn more often
	leads:Array<Int>, // bads leading its levels more often
	features:Map<String, Float>, // factors of the chances of its features
	crawlers:Float,
	colors:Array<Int> // weights of the lasers: white, black, blue, green, red bombs
}

class LevelTheme {
	static var CAVERNS:Theme = {
		name: "caverns",
		skins: [],
		systems: [],
		leads: [],
		features: new Map(),
		crawlers: 1,
		colors: [1, 3, 3, 2, 2]
	};

	static var THEMES:Array<Theme> = [
		{
			name: "hells",
			skins: [[24, 62], [24, 5362]],
			systems: ["hooks", "rooms", "stairs"],
			leads: [Data.BAD_CITRON, Data.BAD_BOMBE, Data.BAD_POIRE, Data.BAD_FRAISE],
			features: ["teleport" => 2.0, "disarm" => 1.5, "gate" => 1.3, "pit" => 1.2],
			crawlers: 1,
			colors: [2, 3, 5, 1, 1]
		},
		{
			name: "metal",
			skins: [[18, 5963]],
			systems: ["spines", "lattice", "box"],
			leads: [Data.BAD_KIWI, Data.BAD_LITCHI, Data.BAD_BOMBE, Data.BAD_ABRICOT],
			features: ["saws" => 2.5, "gate" => 1.2, "spikes" => 0.8],
			crawlers: 1.7,
			colors: [1, 4, 3, 1, 1]
		},
		{
			name: "crypt",
			skins: [[21, 6155], [22, 5145]],
			systems: ["rooms", "hooks", "box"],
			leads: [Data.BAD_FRAMBOISE, Data.BAD_FRAMBOISE, Data.BAD_FRAISE, Data.BAD_POIRE, Data.BAD_CITRON],
			features: ["spikes" => 1.8, "pit" => 1.8, "disarm" => 1.2],
			crawlers: 1,
			colors: [2, 2, 3, 2, 1]
		},
		{
			name: "egypt",
			skins: [[8, 41], [8, 42], [8, 4241]],
			systems: ["stairs", "tree", "arches", "pillars"],
			leads: [Data.BAD_ABRICOT, Data.BAD_POIRE, Data.BAD_CITRON, Data.BAD_BOMBE],
			features: ["gate" => 1.5, "pit" => 2.0],
			crawlers: 0.7,
			colors: [1, 1, 4, 4, 4]
		},
		{
			name: "tomb",
			skins: [[18, 6257], [23, 4844]],
			systems: ["box", "rooms", "spines"],
			leads: [Data.BAD_ANANAS, Data.BAD_LITCHI, Data.BAD_FRAMBOISE, Data.BAD_FRAISE, Data.BAD_KIWI],
			features: ["vault" => 1.8, "teleport" => 1.4, "disarm" => 1.3],
			crawlers: 1,
			colors: [2, 2, 4, 1, 3]
		}
	];

	public static function of(depth:Int):Theme {
		if (depth < 10)
			return CAVERNS;
		return THEMES[Std.int((depth - 10) / 5) % THEMES.length];
	}
}
