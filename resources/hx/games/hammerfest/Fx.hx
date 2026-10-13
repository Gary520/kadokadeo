package hammerfest;

// hammer/Animation.mt: an effect playing its frames once (or looping), then removed
class Animation {
	public var game:Game;
	public var mc:ASprite;
	public var pic:Pic;
	public var fl_kill:Bool;
	public var fl_loop:Bool;
	public var fl_loopDone:Bool;
	public var fl_blink:Bool;
	public var frame:Float;
	public var lifeTimer:Float;
	public var blinkTimer:Float;
	public var loopFrame:Int;
	// a clip of the SWF playing by itself (one frame a picture, 40 a second), not an effect of the game (tmod)
	public var fl_swf:Bool = false;

	public function new(g:Game) {
		game = g;
		frame = 0;
		lifeTimer = 0;
		blinkTimer = 0;
		fl_kill = false;
		fl_loop = false;
		fl_loopDone = false;
		fl_blink = false;
		loopFrame = 1;
	}

	public function attach(x:Float, y:Float, link:String, depth:Int) {
		mc = new ASprite();
		pic = new Pic(link);
		mc.addChild(pic);
		mc._x = x;
		mc._y = y;
		game.dm.add(mc, depth);
	}

	public function destroy() {
		if (!fl_kill && mc != null) {
			if (mc.parent != null)
				mc.parent.removeChild(mc);
			mc.destroy({children: true});
		}
		fl_kill = true;
	}

	public function blink() {
		fl_blink = true;
	}

	public function stopBlink() {
		fl_blink = false;
		mc._alpha = 100;
	}

	public function update() {
		if (fl_kill)
			return;
		if (fl_loopDone) {
			lifeTimer -= Game.tmod;
			if (lifeTimer <= 0) {
				destroy();
				return;
			}
		}
		if (fl_blink) {
			blinkTimer -= Game.tmod;
			if (blinkTimer <= 0) {
				mc._alpha = (mc._alpha == 100) ? 30 : 100;
				blinkTimer = Data.BLINK_DURATION_FAST;
			}
		}
		frame += fl_swf ? 1 : Game.tmod;
		while (frame >= 1) {
			if (pic.cur < pic.count())
				pic.show(pic.cur + 1);
			if (pic.cur == pic.count()) {
				if (fl_loop)
					pic.show(loopFrame);
				fl_loopDone = true;
			}
			frame--;
		}
	}
}

// hammer/entity/fx/Particle.mt: a bouncing particle (ice, stones, sparks...)
class Particle extends Mover {
	var own:Bool = false;
	var bounce:Float;
	var skipWallsY:Float;
	var pid:Null<Int>;

	public function new(pid:Int) {
		super("particle");
		this.pid = pid;
		setLifeTimer(Data.SECOND * 2 + (Data.SECOND * 2) * Cs.vrnd(100) / 100);
		disableAnimator();
	}

	// (called by the constructor of Animator before pid is set)
	override public function animName(id:Int):String {
		return "particle_" + (pid == null ? 1 : pid);
	}

	override public function init(g:Game) {
		super.init(g);
		register(Data.FX);
	}

	public function initParticle(g:Game, x:Float, y:Float) {
		init(g);
		bounce = Cs.vrnd(65) / 10 + 1.5;
		setNext((1 + Cs.vrnd(50) / 10) * (Cs.vrnd(2) * 2 - 1), -bounce, 0, Data.ACTION_MOVE);
		pic.setAnim(animName(0));
		// (a clip playing by itself, from its first picture: the spark twinkling, the bits of raspberry turning)
		own = Art.LOGICAL.get(pic.anim) == 1 && pic.count() > 1;
		pic.show(own ? 1 : Cs.vrnd(pic.count()) + 1);
		scale(Cs.vrnd(50) + 50);
		rotation = Cs.vrnd(360);
		moveTo(x, y);
		skipWallsY = y;
		bounceFactor = 0.6;
		switch (pid) {
			case Data.PARTICLE_SPARK:
				scale(scaleFactor * 100 * 2);
				updateLifeTimer(Data.SECOND);
			case Data.PARTICLE_STONE:
				scale(scaleFactor * 150);
			case Data.PARTICLE_METAL:
				scale(Cs.vrnd(40) + 80);
				bounceFactor = 0.3;
			case Data.PARTICLE_LITCHI:
				bounceFactor = 0.4;
			case Data.PARTICLE_ICE_BAD:
				bounceFactor = 0.5;
				next.dx *= 0.3;
				next.dy = -Math.abs(next.dy);
			case Data.PARTICLE_BLOB:
				// (a drop of a crawler: falls slower, stays 3 seconds where it lands, shrinks instead of blinking)
				gravityFactor = 0.6;
				fallFactor = gravityFactor;
				updateLifeTimer(Data.SECOND * 3);
				fl_blink = false;
			default:
		}
		endUpdate();
	}

	public static function attach(g:Game, pid:Int, x:Float, y:Float):Particle {
		var p = new Particle(pid);
		p.attachMc(Data.DP_BADS);
		p.initParticle(g, x, y);
		return p;
	}

	override public function prefix() {
		fl_hitWall = y > skipWallsY;
		super.prefix();
	}

	override public function postfix() {
		fl_friction = false;
	}

	override public function onHitGround(h:Float) {
		// (a drop sticks where it lands)
		if (pid == Data.PARTICLE_BLOB) {
			recal();
			dx = 0;
			dy = 0;
			fl_gravity = false;
		}
		skipWallsY = 0;
		fl_hitWall = true;
		setNext(dx, -dy * bounceFactor, 0, Data.ACTION_MOVE);
		if (Math.abs(next.dy) <= 1.5)
			next.dx *= game.gFriction;
		fl_skipNextGravity = true;
		super.onHitGround(h);
	}

	override public function onHitCeil() {
		destroy();
	}

	override public function onHitWall() {
		if (fl_hitWall) {
			if (pid == Data.PARTICLE_BLOB)
				dx = 0;
			else
				dx = -dx * 0.5;
		}
	}

	override public function onDeathLine() {
		destroy();
	}

	override public function endUpdate() {
		rotation += dx * 2;
		super.endUpdate();
		// (a drop shrinks over the last two thirds of its life)
		if (pid == Data.PARTICLE_BLOB && totalLife != null && totalLife > 0) {
			_xscale = 100 * scaleFactor * Math.min(1, 1.5 * lifeTimer / totalLife);
			_yscale = _xscale;
		}
	}

	override public function update() {
		if (own)
			pic.show(pic.cur % pic.count() + 1);
		if (Math.abs(dx) <= 0.5 && pid != Data.PARTICLE_BLOB) {
			lifeTimer -= Game.tmod;
			if (lifeTimer <= 0)
				onLifeTimer();
		}
		super.update();
	}
}

// hammer/FxManager.mt
class FxManager {
	var game:Game;
	var animList:Array<Animation>;
	var pops:Array<{mc:ASprite, inner:ASprite, f:Int}>;
	var alerts:Array<{mc:ASprite, f:Int, timer:Float}>;
	var stack:Array<{t:Float, link:String, x:Float, y:Float}>;
	var exitArrow:Animation;
	var itemName:ASprite;
	// special backgrounds of the items, one after the other (each one its time)
	var bgList:Array<{id:Int, timer:Float}>;
	var fl_bg:Bool;

	public function new(g:Game) {
		game = g;
		animList = [];
		pops = [];
		alerts = [];
		stack = [];
		bgList = [];
		fl_bg = false;
	}

	// a special background in place of the one of the level for a while (FxManager.attachBg)
	public function attachBg(id:Int, timer:Float) {
		bgList.push({id: id, timer: timer});
	}

	function detachBg() {
		fl_bg = false;
		game.world.detachSpecialBg();
	}

	public function clearBg() {
		bgList = [];
		detachBg();
	}

	// the word CRISTAL done (extendSequence in the middle of the screen; its dark band the width of the field): the
	// whole sequence of the original (the letters, their balls gathered, turning, then thrown away; the band closing),
	// gone at its end (its clip removed itself)
	public function attachExtend() {
		var band = attachFx(Data.GAME_WIDTH / 2, Data.GAME_HEIGHT / 2, "extendBand");
		if (band != null) {
			// (a strip of 2 Flash pixels)
			band.mc._xscale = (Data.GAME_WIDTH + 40) / 2 * 100;
			band.lifeTimer = 1;
		}
		var a = attachFx(Data.GAME_WIDTH / 2, Data.GAME_HEIGHT / 2, "extendFx");
		if (a != null)
			a.lifeTimer = 1;
	}

	public function attachFx(x:Float, y:Float, link:String, ?start:Int = 1):Animation {
		if (game.fl_lock)
			return null;
		var a = new Animation(game);
		a.attach(x, y, link, Data.DP_FX);
		if (start > 1)
			a.pic.show(Std.int(Math.min(start, a.pic.count())));
		animList.push(a);
		return a;
	}

	// score earned (popScore: the number goes up, then flattens)
	public function attachScorePop(x:Float, y:Float, value:Int) {
		var mc = new ASprite();
		var inner = new ASprite();
		mc.addChild(inner);
		// (the thousands grouped by a dot like the original, "2.000": the 11th picture of the digits)
		var txt = Data.formatNumber(value);
		var adv = Art.DIGIT_POP;
		var w = 0.0;
		for (i in 0...txt.length) {
			var c = txt.charAt(i);
			w += adv[c == "." ? 10 : Std.parseInt(c)];
		}
		// (popScore: its text field stretched 1.53 times in height, its baseline 6.25 under the label)
		var field = new ASprite();
		field._yscale = 153.17;
		field._y = 6.25;
		inner.addChild(field);
		var px = -w / 2;
		for (i in 0...txt.length) {
			var c = txt.charAt(i);
			var d = c == "." ? 10 : Std.parseInt(c);
			var p = new Pic("digitPop", d + 1);
			p._x = px;
			p._y = 0;
			field.addChild(p);
			px += adv[d];
		}
		mc._x = x;
		mc._y = y;
		inner._y = -11;
		game.dm.add(mc, Data.DP_FX);
		pops.push({mc: mc, inner: inner, f: 1});
	}

	// explodeZone: a circle of the radius of the explosion
	public function attachExplodeZone(x:Float, y:Float, radius:Float):Animation {
		if (game.fl_lock)
			return null;
		var a = attachFx(x, y, "explodeZone");
		if (a != null) {
			var s = Art.SIZE.get("explodeZone");
			var w = s == null ? 100 : s[0];
			a.mc._xscale = radius * 2 / w * 100;
			a.mc._yscale = a.mc._xscale;
		}
		return a;
	}

	public function attachExplosion(x:Float, y:Float, radius:Float):Animation {
		var a = attachExplodeZone(x, y, radius);
		if (a != null)
			a.mc._alpha = 60;
		return a;
	}

	public function attachShine(x:Float, y:Float):Animation {
		if (game.fl_lock)
			return null;
		var fx = attachFx(x, y, "shine");
		if (fx != null) {
			fx.mc._xscale *= 1.5;
			fx.mc._yscale = fx.mc._xscale;
			fx.mc._xscale *= Cs.vrnd(2) * 2 - 1;
		}
		return fx;
	}

	// a message in the middle of the field, sliding in and out (hurryUp)
	public function attachAlert(msg:String) {
		var mc = new ASprite();
		var p:Pic;
		if (msg == "VITE !") {
			p = new Pic("txtHurry");
		} else {
			p = new Pic("txtMsg", Std.int(Math.max(1, ["Niveau", "Partie terminée", "PERFECT !", "Vie supplémentaire"].indexOf(msg) + 1)));
		}
		mc.addChild(p);
		mc._xscale = mc._yscale = 75;
		mc._x = Game.docX(Data.GAME_WIDTH / 2 + ALERT_X[0]);
		mc._y = Game.docY(Data.GAME_HEIGHT / 2);
		game.ui.addChild(mc);
		alerts.push({mc: mc, f: 1, timer: 50});
	}

	// x of the label of hurryUp at each frame (scaled to the width of the mini field)
	static var ALERT_X = [313.95, 196.25, 104.7, 39.3, 0.1, -13, -8.65, -4.35, 0, 2, 8, -56.2, -120.4, -184.6, -248.8, -313];

	public function attachExit() {
		detachExit();
		// in the middle (the levels have a hole there)
		var ex = Data.GAME_WIDTH / 2;
		exitArrow = new Animation(game);
		exitArrow.attach(ex, Data.GAME_HEIGHT + 7, "exitArrow", Data.DP_INTERF);
		exitArrow.fl_loop = true;
		exitArrow.loopFrame = 9;
		exitArrow.lifeTimer = 1e9;
		// small, with its label
		exitArrow.mc._xscale = exitArrow.mc._yscale = 75;
		exitLabel = new ASprite();
		exitLabel.addChild(new Pic("txtNext"));
		exitLabel._x = Game.docX(ex);
		exitLabel._y = Game.docY(Data.GAME_HEIGHT - 44) + 5.5;
		game.ui.addChild(exitLabel);
	}

	var exitLabel:ASprite;

	function exitX():Float {
		var m = game.world.current.map;
		var y = Data.LEVEL_HEIGHT - 1;
		var best = Data.GAME_WIDTH / 2;
		var bestD = 1e9;
		var x = 0;
		while (x < Data.LEVEL_WIDTH) {
			if (m[x][y] <= 0) {
				var a = x;
				while (x < Data.LEVEL_WIDTH && m[x][y] <= 0)
					x++;
				var c = (a + x) * Data.CASE_WIDTH / 2;
				var d = Math.abs(c - Data.GAME_WIDTH / 2);
				if (d < bestD) {
					bestD = d;
					best = c;
				}
			} else {
				x++;
			}
		}
		return best;
	}

	public function detachExit() {
		if (exitArrow != null) {
			exitArrow.destroy();
			exitArrow = null;
		}
		if (exitLabel != null) {
			removeMc(exitLabel);
			exitLabel = null;
		}
	}

	public function hasExit():Bool {
		return exitArrow != null;
	}

	public function attachEnter(x:Float) {
		var a = new Animation(game);
		a.attach(x, 0, "enter", Data.DP_INTERF);
		animList.push(a);
	}

	// detailed effects on / off (key E), at the top of the field like the name of an item
	public function attachOptionMsg(frame:Int) {
		if (itemName != null) {
			if (itemName.parent != null)
				itemName.parent.removeChild(itemName);
			itemName.destroy({children: true});
		}
		itemName = new ASprite();
		itemName.addChild(new Pic("txtFx", frame));
		itemName._x = Game.docX(Data.GAME_WIDTH / 2);
		itemName._y = 10;
		game.ui.addChild(itemName);
	}

	// name of a special item at the top of the field, the item at its left like attachItemName of the original (about
	// the height of the text: its 75 % were too big next to the name)
	public function attachItemName(idx:Int, ?icon:String, ?iconFrame:Int = 1) {
		if (itemName != null) {
			if (itemName.parent != null)
				itemName.parent.removeChild(itemName);
			itemName.destroy({children: true});
		}
		itemName = new ASprite();
		itemName.addChild(new Pic("itemName", idx + 1));
		itemName._x = Game.docX(Data.GAME_WIDTH / 2);
		itemName._y = 10;
		if (icon != null) {
			var w = idx < Art.ITEM_NAME_W.length ? Art.ITEM_NAME_W[idx] : 0;
			var s = Art.SIZE.get(icon);
			var iw = s != null ? s[(iconFrame - 1) * 2] : 20;
			var ih = s != null ? s[(iconFrame - 1) * 2 + 1] : 20;
			// (half its size at the most; the tall ones (a candle, a lamp and its rays) not under 35 %)
			var k = Math.max(0.35, Math.min(0.5, 14 / Math.max(1, ih)));
			var p = new Pic(icon, iconFrame);
			// (its middle on the middle of the text: the item stands on its origin)
			p._x = -(w * 0.5 + 6 + iw * k * 0.5);
			p._y = (ih * 0.5 - 1) * k;
			p._xscale = k * 100;
			p._yscale = k * 100;
			itemName.addChild(p);
			// (the item and its name centred together)
			itemName._x += (6 + iw * k) * 0.5;
		}
		game.ui.addChild(itemName);
	}

	// dust falling from a tile
	public function dust(cx:Int, cy:Int) {
		var x = Entity.x_ctr(cx);
		var y = Entity.y_ctr(cy);
		var xMin = x - Data.CASE_WIDTH * 0.5;
		var xMax = x + Data.CASE_WIDTH * 0.5;
		if (game.world.getCase(cx - 1, cy) == Data.GROUND)
			xMin -= Data.CASE_WIDTH;
		if (game.world.getCase(cx + 1, cy) == Data.GROUND)
			xMax += Data.CASE_WIDTH;
		var wid = Math.round(xMax - xMin);
		for (i in 0...7) {
			var fx = attachFx(xMin + Cs.vrnd(wid), y, "fxDust", Cs.vrnd(5) + 5);
			if (fx == null)
				continue;
			if (!Game.detail)
				fx.mc._visible = false;
			fx.mc._xscale = Cs.vrnd(50) + 50 * (Cs.vrnd(2) * 2 - 1);
			fx.mc._yscale = Cs.vrnd(80) + 10;
			fx.mc._alpha = Cs.vrnd(50) + 50;
		}
	}

	// pieces of ice behind a frozen bad sliding fast
	public function iceTrail(ox:Float, oy:Float, alpha:Float) {
		var nb = Cs.vrnd(5) + 2;
		for (i in 0...nb) {
			var part = attachFx(ox + Cs.vrnd(12) * (Cs.vrnd(2) * 2 - 1), oy - Cs.vrnd(5) + 2, "partIce");
			if (part == null)
				continue;
			if (!Game.detail)
				part.mc._visible = false;
			part.mc._rotation = Cs.vrnd(360);
			part.mc._xscale = Cs.vrnd(80) + 20;
			part.mc._yscale = part.mc._xscale;
			part.mc._alpha = Math.min(100, alpha);
		}
	}

	public function inGameParticles(id:Int, x:Float, y:Float, n:Int) {
		inGameParticlesDir(id, x, y, n, null);
	}

	// (without the detailed effects the particles are hidden, not left out: the game and its replay stay the same)
	public function inGameParticlesDir(id:Int, x:Float, y:Float, n:Int, dir:Null<Float>) {
		if (game.fl_lock)
			return;
		var l = game.getList(Data.FX);
		if (l.length + n > Data.MAX_FX) {
			n = Math.ceil(n * 0.5);
			game.destroySome(Data.FX, n + l.length - Data.MAX_FX);
		}
		var fl_left = Cs.vrnd(2) == 0;
		for (i in 0...n) {
			var mc = Particle.attach(game, id, x, y);
			if (!Game.detail)
				mc.mc._visible = false;
			if (x <= Data.CASE_WIDTH)
				fl_left = false;
			if (x >= Data.GAME_WIDTH - Data.CASE_WIDTH)
				fl_left = true;
			fl_left = (dir != null) ? dir < 0 : fl_left;
			if (fl_left)
				mc.next.dx = -Math.abs(mc.next.dx);
			else
				mc.next.dx = Math.abs(mc.next.dx);
			fl_left = !fl_left;
		}
	}

	public function delayFx(t:Float, x:Float, y:Float, link:String) {
		stack.push({t: t, x: x, y: y, link: link});
	}

	public function clear() {
		detachExit();
		clearBg();
		game.destroyList(Data.FX);
		for (a in animList)
			a.destroy();
		animList = [];
		for (p in pops)
			removeMc(p.mc);
		pops = [];
		for (a in alerts)
			removeMc(a.mc);
		alerts = [];
		game.cleanKills();
	}

	static function removeMc(mc:ASprite) {
		if (mc.parent != null)
			mc.parent.removeChild(mc);
		mc.destroy({children: true});
	}

	public function onNextLevel() {
		stack = [];
		clear();
	}

	public function main() {
		// special backgrounds
		if (bgList.length > 0) {
			var b = bgList[0];
			if (!fl_bg) {
				fl_bg = true;
				game.world.attachSpecialBg(b.id);
			}
			b.timer -= Game.tmod;
			if (b.timer <= 0) {
				bgList.splice(0, 1);
				detachBg();
			}
		}
		// delayed effects
		var i = 0;
		while (i < stack.length) {
			stack[i].t -= Game.tmod;
			if (stack[i].t <= 0) {
				attachFx(stack[i].x, stack[i].y, stack[i].link);
				stack.splice(i, 1);
				i--;
			}
			i++;
		}
		// animations
		i = 0;
		while (i < animList.length) {
			var a = animList[i];
			a.update();
			if (a.fl_kill) {
				animList.splice(i, 1);
				i--;
			}
			i++;
		}
		if (exitArrow != null)
			exitArrow.update();
		// score pops
		i = 0;
		while (i < pops.length) {
			var p = pops[i];
			p.f++;
			if (p.f > 39) {
				removeMc(p.mc);
				pops.splice(i, 1);
				i--;
			} else {
				p.inner._y = -11 - 1.1754 * (p.f - 1);
				if (p.f >= 35)
					p.inner._yscale = Math.max(0, 100 - (p.f - 34) * 18.6);
			}
			i++;
		}
		// alerts
		i = 0;
		while (i < alerts.length) {
			var a = alerts[i];
			if (a.f == 10 && a.timer > 0) {
				a.timer -= Game.tmod;
				a.mc._x = Game.docX(Data.GAME_WIDTH / 2 + (a.timer % 2 < 1 ? ALERT_X[8] : ALERT_X[9]));
			} else {
				a.f++;
				if (a.f > ALERT_X.length) {
					removeMc(a.mc);
					alerts.splice(i, 1);
					i--;
					i++;
					continue;
				}
				a.mc._x = Game.docX(Data.GAME_WIDTH / 2 + ALERT_X[a.f - 1]);
			}
			i++;
		}
		// name of an item
		if (itemName != null) {
			itemName._alpha -= (105 - itemName._alpha) * 0.01;
			if (itemName._alpha <= 5) {
				removeMc(itemName);
				itemName = null;
			}
		}
	}
}
