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
	entry:Array<Bool> // columns where Igor coming in falling from the top lands with every bad and the bottom reachable
}

// The well of a game: a level made at random for each depth (LevelGen), with the random of the game (the same seed
// gives the same well, the replays the same levels).
class Levels {
	public static function reset() {
		LevelGen.reset();
	}

	public static function get(depth:Int):LevelData {
		var l = LevelGen.make(depth);
		// walls: a ground under another ground (GameMechanics.parseWalls)
		var m = l.map;
		for (cy in 1...Data.LEVEL_HEIGHT)
			for (cx in 0...Data.LEVEL_WIDTH)
				if (m[cx][cy] > 0 && m[cx][cy - 1] > 0)
					m[cx][cy] = Data.WALL;
		return l;
	}
}
