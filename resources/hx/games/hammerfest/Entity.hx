package hammerfest;

import pixi.filters.colormatrix.ColorMatrixFilter;

// hammer/Entity.mt: an element of the game (the MovieClip of the original is `mc`, its picture `pic` in the
// Animator). Coordinates x, y: the bottom center of the entity in the field, in Flash pixels.
class Entity {
	public var game:Game;
	public var world:World;
	public var mc:ASprite;

	public var x:Float; // real coords
	public var y:Float;
	public var oldX:Float; // previous real coords
	public var oldY:Float;
	public var cx:Int; // bottom entity case coords
	public var cy:Int;
	public var fcx:Int; // under feet case coords
	public var fcy:Int;

	public var _xOffset:Float; // graphical offset of mc (for shoots)
	public var _yOffset:Float;

	public var rotation:Float;
	public var alpha:Float;
	public var minAlpha:Float;
	public var scaleFactor:Float;

	public var types:Int;

	public var lifeTimer:Float;
	public var totalLife:Null<Float>;

	public var fl_kill:Bool;
	public var fl_destroy:Bool;

	public var uniqId:Int;
	public var parent:Entity;

	public var sticker:ASprite;
	// (a picture of the sticker playing by itself: a curse bobbing, turning)
	public var stickerPic:Pic = null;
	public var stickerX:Float;
	public var stickerY:Float;
	public var elaStickFactor:Float;
	public var stickTimer:Float;
	public var fl_stick:Bool;
	public var fl_stickRot:Bool;
	public var fl_stickBound:Bool;
	public var fl_elastick:Bool;
	public var fl_softRecal:Bool;
	public var softRecalFactor:Float;

	// Color of the original (setColorHex): a colour matrix on the clip
	var colorFilter:ColorMatrixFilter;

	public function new() {
		types = 0;
		x = 0;
		y = 0;
		oldX = 0;
		oldY = 0;
		alpha = 100;
		rotation = 0;
		minAlpha = 35;
		stickTimer = 0;
		lifeTimer = 0;
		totalLife = null;
		scaleFactor = 1;
		_xOffset = 0;
		_yOffset = 0;
		updateCoords();
		fl_kill = false;
		fl_destroy = false;
		fl_stick = false;
		fl_stickRot = false;
		fl_stickBound = false;
		fl_elastick = false;
		fl_softRecal = false;
		mc = new ASprite();
	}

	public function init(g:Game) {
		game = g;
		uniqId = game.getUniqId();
		register(Data.ENTITY);
		world = game.world;
		scale(100);
	}

	// the MovieClip of the entity on a plan of the game (depthMan.attach)
	public function attachMc(depth:Int) {
		Game.me.dm.add(mc, depth);
	}

	public function register(type:Int) {
		game.addToList(type, this);
		types |= type;
	}

	public function unregister(type:Int) {
		game.removeFromList(type, this);
		types ^= type;
	}

	public inline function isType(t:Int):Bool {
		return (types & t) > 0;
	}

	public function setParent(e:Entity) {
		parent = e;
	}

	public function setLifeTimer(t:Float) {
		lifeTimer = t;
		totalLife = t;
	}

	public function updateLifeTimer(t:Float) {
		if (totalLife == null)
			setLifeTimer(t);
		else
			lifeTimer = t;
	}

	public function onLifeTimer() {
		destroy();
	}

	// _width / _height of the MovieClip (size of its current picture, at its scale)
	public function get_width():Float {
		return 0;
	}

	public function get_height():Float {
		return 0;
	}

	public function hitBound(e:Entity):Bool {
		var w = get_width();
		var h = get_height();
		var ew = e.get_width();
		var eh = e.get_height();
		return x + w / 2 > e.x - ew / 2 && y > e.y - eh && x - w / 2 < e.x + ew / 2 && y - h < e.y;
	}

	public function hit(e:Entity) {}

	public function destroy() {
		fl_kill = true;
		fl_destroy = true;
		unstick();
		for (i in 0...Data.TYPE_COUNT) {
			if ((types & (1 << i)) > 0)
				game.unregList.push({type: 1 << i, ent: this});
		}
		game.killList.push(this);
	}

	// end of the turn: the MovieClip leaves the display (removeMovieClip)
	public function removeMc() {
		if (mcRemoved)
			return;
		mcRemoved = true;
		if (sticker != null)
			unstick();
		if (mc.parent != null)
			mc.parent.removeChild(mc);
		mc.destroy({children: true});
	}

	var mcRemoved:Bool = false;

	// STICKER (a clip following the entity)
	public function stick(m:ASprite, ox:Float, oy:Float) {
		if (sticker != null)
			unstick();
		sticker = m;
		stickerX = ox;
		stickerY = oy;
		fl_stick = true;
		fl_stickRot = false;
		fl_stickBound = false;
		fl_elastick = false;
	}

	public function setElaStick(f:Float) {
		if (fl_elastick)
			return;
		elaStickFactor = f;
		fl_elastick = true;
		stickerX *= elaStickFactor;
		stickerY *= elaStickFactor;
	}

	public function unstick() {
		fl_stick = false;
		stickerPic = null;
		if (sticker != null) {
			if (sticker.parent != null)
				sticker.parent.removeChild(sticker);
			sticker.destroy({children: true});
			sticker = null;
		}
	}

	public function activateSoftRecal() {
		fl_softRecal = true;
		softRecalFactor = 0.1;
	}

	public function hide() {
		mc._visible = false;
		if (sticker != null)
			sticker._visible = false;
	}

	public function show() {
		mc._visible = true;
		if (sticker != null)
			sticker._visible = true;
	}

	public var _visible(get, never):Bool;

	inline function get__visible():Bool {
		return mc._visible;
	}

	public function scale(n:Float) {
		scaleFactor = n / 100;
		_xscale = n;
		_yscale = n;
	}

	// _xscale / _yscale of the clip; flipping it (sign) is not interpolated between two pictures
	public var _xscale(get, set):Float;
	public var _yscale(get, set):Float;

	inline function get__xscale():Float {
		return mc._xscale;
	}

	function set__xscale(v:Float):Float {
		var flip = (v < 0) != (mc._xscale < 0);
		mc._xscale = v;
		if (flip && mc._prevState != null)
			mc._prevState.xscale = mc._curState.xscale;
		return v;
	}

	inline function get__yscale():Float {
		return mc._yscale;
	}

	function set__yscale(v:Float):Float {
		var flip = (v < 0) != (mc._yscale < 0);
		mc._yscale = v;
		if (flip && mc._prevState != null)
			mc._prevState.yscale = mc._curState.yscale;
		return v;
	}

	public function setColorHex(a:Float, col:Int) {
		var r = ((col >> 16) & 0xFF) / 255;
		var g = ((col >> 8) & 0xFF) / 255;
		var b = (col & 0xFF) / 255;
		var k = 1 - a / 100;
		var ratio = a / 100;
		if (colorFilter == null) {
			colorFilter = new ColorMatrixFilter();
			mc.filters = [colorFilter];
		}
		colorFilter.matrix = [k, 0, 0, 0, ratio * r, 0, k, 0, 0, ratio * g, 0, 0, k, 0, ratio * b, 0, 0, 0, 1, 0];
	}

	public function resetColor() {
		if (colorFilter != null) {
			mc.filters = null;
			colorFilter = null;
		}
	}

	// COORDINATES
	public function updateCoords() {
		cx = x_rtc(x);
		cy = y_rtc(y);
		fcx = cx;
		fcy = y_rtc(y + Math.floor(Data.CASE_HEIGHT / 2));
	}

	public static inline function x_rtc(n:Float):Int {
		return Math.floor(n / Data.CASE_WIDTH);
	}

	public static inline function y_rtc(n:Float):Int {
		return Math.floor((n - Data.CASE_HEIGHT / 2) / Data.CASE_HEIGHT);
	}

	public static inline function x_ctr(n:Int):Float {
		return n * Data.CASE_WIDTH + Data.CASE_WIDTH * 0.5;
	}

	public static inline function y_ctr(n:Int):Float {
		return n * Data.CASE_HEIGHT + Data.CASE_HEIGHT;
	}

	public function adjustAngle(a:Float):Float {
		while (a < 0)
			a += 360;
		while (a >= 360)
			a -= 360;
		return a;
	}

	public function adjustToLeft() {
		x = x_ctr(cx);
		y = y_ctr(cy);
		x -= Data.CASE_WIDTH * 0.5 + 1;
	}

	public function adjustToRight() {
		x = x_ctr(cx);
		y = y_ctr(cy);
		x += Data.CASE_WIDTH * 0.5 - 1;
	}

	public function centerInCase() {
		x = x_ctr(cx);
		y = y_ctr(cy);
	}

	public function distanceCase(cx:Int, cy:Int):Float {
		return Math.sqrt((cy - this.cy) * (cy - this.cy) + (cx - this.cx) * (cx - this.cx));
	}

	public function distance(x:Float, y:Float):Float {
		return Math.sqrt((y - this.y) * (y - this.y) + (x - this.x) * (x - this.x));
	}

	// UPDATES
	public function update() {
		if (lifeTimer > 0) {
			lifeTimer -= Game.tmod;
			if (lifeTimer <= 0)
				onLifeTimer();
		}
		if (stickTimer > 0) {
			stickTimer -= Game.tmod;
			if (stickTimer <= 0)
				unstick();
		}
	}

	public function endUpdate() {
		updateCoords();
		var px = mc._x;
		var py = mc._y;
		if (fl_softRecal) {
			var tx = x + _xOffset;
			var ty = y + _yOffset;
			mc._x = mc._x + (tx - mc._x) * softRecalFactor;
			mc._y = mc._y + (ty - mc._y) * softRecalFactor;
			softRecalFactor += 0.02 * Game.tmod;
			if (softRecalFactor >= 1 || (Math.abs(tx - mc._x) <= 1.5 && Math.abs(ty - mc._y) <= 1.5))
				fl_softRecal = false;
		}
		if (!fl_softRecal) {
			mc._x = x + _xOffset;
			mc._y = y + _yOffset;
		}
		// a jump (teleportation, new level...) is not interpolated
		if (Math.abs(mc._x - px) > Data.CASE_WIDTH * 3 || Math.abs(mc._y - py) > Data.CASE_HEIGHT * 3)
			snap();
		mc._rotation = rotation;
		mc._alpha = Math.max(minAlpha, alpha);
		oldX = x;
		oldY = y;
		if (fl_stick && sticker != null) {
			if (stickerPic != null)
				stickerPic.show(stickerPic.cur % stickerPic.count() + 1);
			if (fl_elastick) {
				sticker._x = sticker._x + (x - sticker._x) * elaStickFactor + stickerX;
				sticker._y = sticker._y + (y - sticker._y) * elaStickFactor + stickerY;
			} else {
				sticker._x = x + stickerX;
				sticker._y = y + stickerY;
			}
			if (fl_stickRot)
				sticker._rotation += 8 * Game.tmod;
			if (fl_stickBound) {
				sticker._x = Math.max(sticker._x, 10);
				sticker._x = Math.min(sticker._x, Data.GAME_WIDTH - 10);
			}
		}
	}

	// the clip shows its new state at once (no interpolation from the previous step)
	public function snap() {
		if (mc._prevState != null)
			mc._prevState.copyFrom(mc._curState);
	}
}
