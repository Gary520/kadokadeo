package hammerfest;

class Cs {
	// Std.random of the gameplay (replays: the seed of the game)
	public static inline function rnd(n:Int):Int {
		return Seed.random(n);
	}

	// Std.random of the purely visual effects
	public static inline function vrnd(n:Int):Int {
		return Seed.randomVfx(n);
	}

	// results of Math.cos / sin used by the gameplay, rounded to 1e-9: the replays stay identical on every browser
	// even if their Math functions differ in the last bits (the rest is exact IEEE arithmetic)
	public static inline function qt(v:Float):Float {
		return Math.round(v * 1e9) / 1e9;
	}

	// RandomManager.draw: index drawn with weights
	public static function draw(weights:Array<Int>):Int {
		var sum = 0;
		for (w in weights)
			sum += w;
		var target = rnd(sum);
		var s = 0;
		for (i in 0...weights.length) {
			s += weights[i];
			if (target < s)
				return i;
		}
		return -1;
	}
}
