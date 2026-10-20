package hammerfest;

// The dimensions of the well: from level 10, chapters of 5 levels going through the hard dimensions of the original
// (the world of Deepnight: the Hells, Metal hurlant, the Crypt of the raspberries, Egypt, the tomb of Tuberculoz), each
// with the skins of its levels. The first levels: the caverns of the adventure (skins by difficulty, Gen.SKINS).
typedef Theme = {
	name:String,
	skins:Array<Array<Int>> // background, tiles (+ 100 x column) of the levels of the dimension
}

class LevelTheme {
	static var CAVERNS:Theme = {name: "caverns", skins: []};

	static var THEMES:Array<Theme> = [
		{name: "hells", skins: [[24, 62], [24, 5362]]},
		{name: "metal", skins: [[18, 5963]]},
		{name: "crypt", skins: [[21, 6155], [22, 5145]]},
		{name: "egypt", skins: [[8, 41], [8, 42], [8, 4241]]},
		{name: "tomb", skins: [[18, 6257], [23, 4844]]}
	];

	public static function of(depth:Int):Theme {
		if (depth < 10)
			return CAVERNS;
		return THEMES[Std.int((depth - 10) / 5) % THEMES.length];
	}
}
