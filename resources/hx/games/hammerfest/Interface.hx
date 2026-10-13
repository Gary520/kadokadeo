package hammerfest;

// hammer/gui/GameInterface.mt: the bar at the bottom (letters C R I S T A L, lives, level, score)
class Interface {
	static inline var BASE_X = 92; // lives
	static inline var BASE_WIDTH = 16;
	// (8 cones at the most like the original (GameInterface.MAX_LIVES), then the "+")
	static inline var MAX_LIVES = 8;
	// level: the red arrow of the bar and the number, centered in the box of the bar (between its cracks at 234
	// and 294); the score is shown by the site under the game
	static inline var BOX_CENTER = 264;
	static inline var GLOW = 3.5; // glow around the glyphs of the digits
	static inline var ARROW_GAP = 1;
	static inline var ARROW_X0 = 261.05; // the arrow is drawn at its place in the bar of the original
	static inline var ARROW_W = 17.1;

	var game:Game;
	var mc:ASprite;
	var letters:Array<Pic>;
	var lives:Array<Pic>;
	var more:Pic;
	var levelMc:ASprite;
	var arrow:Pic;
	var levelBox:ASprite;

	// the red arrow and the number: a little smaller than the bar of the original, centered in its box
	static inline var LEVEL_SCALE = 85;
	static inline var BAR_MID = -10.0; // middle of the height of the bar (its bottom at 0)
	// the arrow smaller than the digits of the original (18 high, the digits 13: the number looked too high by it), its
	// middle at the middle of the digits
	static inline var ARROW_SCALE = 0.95;
	static inline var DIGIT_MID = 0.75; // middle of the glyphs of the digits (their pictures at 9.75: -5.75..7.25)
	static inline var ARROW_TOP = 18.5; // the ink of the arrow over its pivot: 18.5..0.5
	static inline var ARROW_BOTTOM = 0.5;

	var shownLevel:Int;

	public function new(g:Game, root:ASprite) {
		game = g;
		mc = new ASprite();
		mc._y = Data.DOC_HEIGHT;
		root.addChild(mc);
		var bg = new Pic("barBg");
		mc.addChild(bg);
		letters = [];
		for (i in 0...7) {
			var l = new Pic("barLetters", i + 1);
			l._visible = false;
			mc.addChild(l);
			letters.push(l);
		}
		lives = [];
		levelBox = new ASprite();
		levelBox._x = BOX_CENTER;
		levelBox._y = BAR_MID;
		levelBox._xscale = levelBox._yscale = LEVEL_SCALE;
		mc.addChild(levelBox);
		arrow = new Pic("barArrow");
		arrow._xscale = arrow._yscale = ARROW_SCALE * 100;
		levelBox.addChild(arrow);
		levelMc = new ASprite();
		levelBox.addChild(levelMc);
		shownLevel = -1;
	}

	public function setScore(v:Int) {}

	public function setLevel(id:Int) {
		if (id == shownLevel)
			return;
		shownLevel = id;
		var w = writeDigits(levelMc, Std.string(id), 0);
		// (the arrow and the number centered on the middle of the box)
		var aw = ARROW_W * ARROW_SCALE;
		var left = -(aw + ARROW_GAP + w) / 2;
		arrow._x = left - ARROW_X0 * ARROW_SCALE;
		arrow._y = DIGIT_MID + (ARROW_TOP + ARROW_BOTTOM) / 2 * ARROW_SCALE;
		levelMc._x = left + aw + ARROW_GAP - GLOW;
		levelMc._y = 9.75;
	}

	public function setLives(v:Int) {
		while (lives.length > 0 && (lives.length > v || lives.length > MAX_LIVES)) {
			var l = lives.pop();
			mc.removeChild(l);
			l.destroy();
		}
		while (lives.length < v && lives.length < MAX_LIVES) {
			// (GameInterface.setLives: a new cone plays its clip, update: it comes in big and clear, sets in its place,
			// flashes white; players: "il manque l'animation du cône quand on obtient une nouvelle vie")
			var l = new Pic("life");
			l.show(1);
			l._x = BASE_X + lives.length * BASE_WIDTH;
			l._y = -19;
			mc.addChild(l);
			lives.push(l);
		}
		// (more lives than cones: a "+" after the last one, like the original)
		if (v > MAX_LIVES && more == null) {
			more = new Pic("more");
			more._x = BASE_X + BASE_WIDTH * MAX_LIVES - 4;
			more._y = -25;
			mc.addChild(more);
		} else if (v <= MAX_LIVES && more != null) {
			mc.removeChild(more);
			more.destroy();
			more = null;
		}
	}

	public function getExtend(id:Int) {
		var l = letters[id];
		if (!l._visible) {
			l._visible = true;
			// (GameInterface.getExtend: the pop of the letter in the bar itself, over the letter, at its bottom middle:
			// its flash on the letter, its puff going up over the field; a clip of the SWF playing its frames, one a
			// picture)
			var fx = new Animation(game);
			fx.attach(0, 0, "letterPop", Data.DP_INTERF);
			if (fx.mc.parent != null)
				fx.mc.parent.removeChild(fx.mc);
			mc.addChild(fx.mc);
			var b = Art.BAR_LETTERS;
			fx.mc._x = (b[id * 4] + b[id * 4 + 2]) * 0.5;
			fx.mc._y = -3.2;
			fx.fl_swf = true;
			game.addAnim(fx);
		}
	}

	public function clearExtends() {
		for (l in letters)
			l._visible = false;
	}

	// digits of the font of the game (Franklin Gothic Heavy, glow) from x
	function writeDigits(holder:ASprite, txt:String, x:Float):Float {
		while (holder.children.length > 0) {
			var c = holder.getChildAt(0);
			holder.removeChild(c);
			c.destroy();
		}
		var adv = Art.DIGIT_SCORE;
		var w = 0.0;
		for (i in 0...txt.length) {
			var ch = txt.charAt(i);
			w += ch == " " ? 4 : adv[Std.parseInt(ch)];
		}
		var px = x;
		for (i in 0...txt.length) {
			var ch = txt.charAt(i);
			if (ch == " ") {
				px += 4;
				continue;
			}
			var d = Std.parseInt(ch);
			var p = new Pic("digitScore", d + 1);
			p._x = px;
			p._y = -0.5; // (glyphs centered in the bar, like the letters)
			holder.addChild(p);
			px += adv[d];
		}
		return w;
	}

	// the clips of the new cones play their frames, one a cycle, and stop on their last one (frame 23: stop())
	public function update() {
		for (l in lives)
			if (l.cur < l.count())
				l.show(l.cur + 1);
	}
}
