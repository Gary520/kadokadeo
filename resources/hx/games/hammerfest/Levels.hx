package hammerfest;

typedef LevelData = {
	map:Array<Array<Int>>, // [cx][cy]: 0 empty, 1 ground, 2 wall (a ground under another one), < 0 fields (lasers)
	bads:Array<{id:Int, x:Int, y:Int}>, // (x, y): the case over the ground of the bad
	playerX:Int,
	playerY:Int,
	specialSlots:Array<{x:Int, y:Int}>,
	scoreSlots:Array<{x:Int, y:Int}>,
	skinBg:Int,
	skinTiles:Int,
	darkness:Int,
	openAtEnd:Array<{x:Int, y:Int}>, // cases opened when the level is clear (the way down of some hard levels)
	entry:Array<Bool>, // columns where Igor coming in falling from the top lands with every bad and the bottom reachable
	// devices of the scripts of the original
	levers:Array<LeverData>, // pulled by Igor going through their case
	blocks:Array<{x:Int, y:Int}>, // stone blocks of 2 x 2 cases (from x, y) broken by a bomb of Igor
	endBlocks:Array<{x:Int, y:Int}> // stone blocks of 2 x 2 cases going away when the level is clear (in openAtEnd)
}

// a lever ($levier1 / $levier2 of the original, its script $enter): the cases it changes when Igor goes through its
// case (over a ground)
typedef LeverData = {
	x:Int,
	y:Int,
	add:Array<{x:Int, y:Int, v:Int}>, // cases set (1: ground, < 0: a field)
	rem:Array<{x:Int, y:Int}>, // cases emptied
	spikes:Array<{x:Int, y:Int}> // spikes coming out (the case over their ground)
}

// The well of a game: a level made at random for each depth (LevelGen), with the random of the game (the same seed
// gives the same well, the replays the same levels).
class Levels {
	public static function reset() {
		LevelGen.reset();
	}

	public static function get(depth:Int):LevelData {
		var l = LevelGen.make(depth);
		#if debug
		// (test harness: the bombs from above on each strawberry of the level, LevelGen.bombExposure)
		var w:Dynamic = js.Browser.window;
		if (w.__hfStraw == null)
			w.__hfStraw = {};
		Reflect.setField(w.__hfStraw, "" + depth, LevelGen.lastStraw);
		// (the way of drawing of each level and its variant)
		if (w.__hfKind == null)
			w.__hfKind = {};
		Reflect.setField(w.__hfKind, "" + depth, LevelGen.lastKind);
		#end
		// walls: a ground under another ground (GameMechanics.parseWalls)
		var m = l.map;
		for (cy in 1...Data.LEVEL_HEIGHT)
			for (cx in 0...Data.LEVEL_WIDTH)
				if (m[cx][cy] > 0 && m[cx][cy - 1] > 0)
					m[cx][cy] = Data.WALL;
		return l;
	}
}
