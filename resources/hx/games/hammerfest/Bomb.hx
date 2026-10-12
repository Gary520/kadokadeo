package hammerfest;

// hammer/entity/Bomb.mt and its subclasses
class Bomb extends Mover {
	public var radius:Float;
	public var power:Float;
	public var duration:Float;

	public var fl_explode:Bool;
	public var fl_airKick:Bool;
	public var fl_bumped:Bool;
	public var explodeSound:String = "sound_bomb";

	public function new(animBase:String) {
		super(animBase);
		radius = Data.CASE_WIDTH * 3;
		power = 0;
		duration = 0;
		fl_slide = false;
		fl_bounce = false;
		fl_teleport = true;
		fl_wind = true;
		fl_blink = false;
		fl_explode = false;
		fl_airKick = false;
		fl_portal = true;
		fl_bump = true;
		fl_bumped = false;
		fl_strictGravity = false;
		slideFriction = 0.98;
	}

	public function initBomb(g:Game, x:Float, y:Float) {
		init(g);
		register(Data.BOMB);
		moveTo(x, y);
		setLifeTimer(duration);
		updateCoords();
		playAnim(Data.ANIM_BOMB_DROP);
	}

	override public function needsPatch():Bool {
		return true;
	}

	public function bombGetClose(type:Int):Array<Entity> {
		return game.getClose(type, x, y, radius, fl_stable);
	}

	public function onExplode() {
		playAnim(Data.ANIM_BOMB_EXPLODE);
		if (explodeSound != null)
			Snd.play(explodeSound, Snd.CHAN_BOMB);
		rotation = 0;
		fl_physics = false;
		fl_explode = true;
	}

	override public function onEndAnim(id:Int) {
		super.onEndAnim(id);
		if (id == Data.ANIM_BOMB_DROP.id)
			playAnim(Data.ANIM_BOMB_LOOP);
		if (id == Data.ANIM_BOMB_EXPLODE.id)
			destroy();
	}

	override public function endUpdate() {
		if (!fl_stable) {
			var ang = 30;
			if (dx > 0)
				rotation += 0.02 * (ang - rotation);
			else
				rotation -= 0.02 * (ang - rotation);
			rotation = Math.max(-ang, Math.min(ang, rotation));
		}
		super.endUpdate();
	}

	override public function onLifeTimer() {
		stopBlink();
		onExplode();
	}

	override public function onDeathLine() {
		super.onDeathLine();
		destroy();
	}

	public function onKick(p:Player) {}

	override public function onBump() {
		fl_bumped = true;
	}

	override public function onHitWall() {
		if (fl_bumped)
			dx = -dx * 0.7;
		else
			super.onHitWall();
	}

	public function duplicate():Bomb {
		return null;
	}
}

// hammer/entity/bomb/PlayerBomb.mt
class PlayerBomb extends Bomb {
	static inline var UPGRADE_FACTOR = 1.5;
	static inline var MAX_UPGRADES = 1;

	public var owner:Player;
	public var upgrades:Int;
	public var fl_unstable:Bool;

	public function new(animBase:String) {
		super(animBase);
		fl_airKick = true;
		fl_unstable = false;
		upgrades = 0;
	}

	override public function init(g:Game) {
		super.init(g);
		register(Data.PLAYER_BOMB);
	}

	public function setOwner(p:Player) {
		owner = p;
	}

	override public function hit(e:Entity) {
		super.hit(e);
		if (fl_unstable) {
			if ((e.types & Data.BAD) > 0)
				onExplode();
		}
	}

	override public function onHitGround(h:Float) {
		super.onHitGround(h);
		if (fl_unstable && fl_bounce)
			onExplode();
	}

	override public function onKick(p:Player) {
		super.onKick(p);
		if (!fl_stable)
			fl_airKick = false;
	}

	override public function onExplode() {
		super.onExplode();
		game.onExplode(x, y, radius);
		if (owner != null) {
			if (owner.specialMan.actives[14]) // blue mushroom
				Item.ScoreItem.attach(game, x, y, 47, 0);
			if (owner.specialMan.actives[15]) // red mushroom
				Item.ScoreItem.attach(game, x, y, 48, 0);
			if (owner.specialMan.actives[16]) // green mushroom
				Item.ScoreItem.attach(game, x, y, 49, 0);
			if (owner.specialMan.actives[17]) // gold mushroom
				Item.ScoreItem.attach(game, x, y, 50, 0);
		}
	}

	override public function update() {
		super.update();
		if (!fl_blinking && upgrades > 0)
			blink(Data.BLINK_DURATION_FAST);
	}
}

// hammer/entity/bomb/player/Classic.mt: freezes the bads around
class Classic extends PlayerBomb {
	public function new() {
		super("bombClassic");
		duration = 45;
		power = 30;
	}

	public static function attach(g:Game, x:Float, y:Float):Classic {
		var b = new Classic();
		b.attachMc(Data.DP_BOMBS);
		b.initBomb(g, x, y);
		return b;
	}

	override public function duplicate():Bomb {
		return attach(game, x, y);
	}

	override public function onExplode() {
		super.onExplode();
		game.shake(Data.SECOND * 0.35, 1.5);
		for (e in bombGetClose(Data.BAD)) {
			var b:Bad = cast e;
			b.setCombo(uniqId);
			b.freeze(Data.FREEZE_DURATION);
			shockWave(b, radius, power);
		}
		game.fxMan.inGameParticles(Data.PARTICLE_ICE, x, y, Cs.vrnd(2) + 2);
	}
}

// hammer/entity/bomb/BadBomb.mt
class BadBomb extends Bomb {
	public var owner:Bad;

	public function new(animBase:String) {
		super(animBase);
		fl_airKick = true;
	}

	override public function init(g:Game) {
		super.init(g);
		register(Data.BAD_BOMB);
	}

	public function setOwner(b:Bad) {
		owner = b;
	}

	// easy to push back
	override public function onKick(p:Player) {
		super.onKick(p);
		dx *= 3;
	}
}

// hammer/entity/bomb/bad/PoireBomb.mt: the bomb of the pears
class PoireBomb extends BadBomb {
	public function new() {
		super("bombPoire");
		duration = 45;
		power = 30;
		radius = Data.CASE_WIDTH * 4;
	}

	public static function attach(g:Game, x:Float, y:Float):PoireBomb {
		var b = new PoireBomb();
		b.attachMc(Data.DP_BOMBS);
		b.initBomb(g, x, y);
		return b;
	}

	override public function duplicate():Bomb {
		return attach(game, x, y);
	}

	override public function onExplode() {
		super.onExplode();
		game.fxMan.attachExplodeZone(x, y, radius);
		for (e in game.getClose(Data.PLAYER, x, y, radius, false)) {
			var p:Player = cast e;
			p.killHit(0);
			shockWave(p, radius, power);
			if (!p.fl_shield)
				p.dy = -10 - Cs.rnd(20);
		}
	}

	override public function onKick(p:Player) {
		super.onKick(p);
		setLifeTimer(lifeTimer + Data.SECOND * 0.5);
	}
}

// hammer/entity/bomb/bad/Mine.mt: the mines of the kiwis, invisible once planted
class Mine extends BadBomb {
	static inline var SUDDEN_DEATH = Data.SECOND * 1.1;
	static inline var HIDE_SPEED = 3;
	static inline var DETECT_RADIUS = Data.CASE_WIDTH * 2.5;

	public var fl_trigger:Bool;
	public var fl_defuse:Bool;
	public var fl_plant:Bool;

	public function new() {
		super("bombMine");
		fl_blink = true;
		fl_alphaBlink = false;
		duration = Data.SECOND * 15;
		power = 50;
		radius = Data.CASE_WIDTH * 3;
		fl_trigger = false;
		fl_defuse = false;
		fl_plant = false;
	}

	public static function attach(g:Game, x:Float, y:Float):Mine {
		var b = new Mine();
		b.attachMc(Data.DP_BOMBS);
		b.initBomb(g, x, y);
		return b;
	}

	override public function duplicate():Bomb {
		return attach(game, x, y);
	}

	override public function onHitGround(h:Float) {
		super.onHitGround(h);
		if (!fl_trigger)
			playAnim(Data.ANIM_BOMB_LOOP);
		if (!fl_defuse)
			rotation = 0;
	}

	override public function onExplode() {
		if (!fl_trigger || fl_defuse) {
			game.fxMan.attachFx(x, y - Data.CASE_HEIGHT, "fxPop");
			destroy();
		} else {
			super.onExplode();
			game.fxMan.attachExplodeZone(x, y, radius);
			for (e in game.getClose(Data.PLAYER, x, y, radius, false)) {
				var p:Player = cast e;
				p.killHit(0);
				shockWave(p, radius, power);
				if (!p.fl_shield)
					p.dy = -10 - Cs.rnd(20);
			}
		}
	}

	override public function onKick(p:Player) {
		super.onKick(p);
		triggerMine();
		updateLifeTimer(Data.SECOND * 0.7);
		dx *= 0.8 + Cs.rnd(10) / 10;
	}

	public function triggerMine() {
		if (fl_trigger)
			return;
		fl_trigger = true;
		playAnim(Data.ANIM_BOMB_DROP);
		dy = -7;
		show();
		alpha = 100;
		setLifeTimer(SUDDEN_DEATH * 3); // to force the blinking
		updateLifeTimer(SUDDEN_DEATH);
		blinkLife();
	}

	override public function playAnim(a:Data.AnimDef) {
		super.playAnim(a);
		if (a.id == Data.ANIM_BOMB_DROP.id)
			fl_loop = true;
		if (a.id == Data.ANIM_BOMB_LOOP.id)
			fl_loop = false;
	}

	override public function update() {
		super.update();
		if (fl_stable && !fl_plant)
			fl_plant = true;
		// hidden after it is planted
		if (fl_plant && !fl_trigger && alpha > 0) {
			alpha -= Game.tmod * HIDE_SPEED;
			if (alpha <= 0)
				hide();
		}
		// triggered by the player
		if (fl_plant && !fl_trigger) {
			for (e in game.getClose(Data.PLAYER, x, y, DETECT_RADIUS, false)) {
				if (!e.fl_kill)
					triggerMine();
			}
		}
	}
}

// hammer/entity/bomb/player/Black.mt: kills the bads around (no crystal combo by freezing: they fly away)
class Black extends PlayerBomb {
	public function new() {
		super("bombBlack");
		explodeSound = "sound_bomb_black";
		duration = 100;
		power = 20;
	}

	public static function attach(g:Game, x:Float, y:Float):Black {
		var b = new Black();
		b.attachMc(Data.DP_BOMBS);
		b.initBomb(g, x, y);
		return b;
	}

	override public function duplicate():Bomb {
		return attach(game, x, y);
	}

	override public function onExplode() {
		super.onExplode();
		game.shake(10, 4);
		game.fxMan.attachExplodeZone(x, y, radius);
		for (e in bombGetClose(Data.BAD)) {
			var b:Bad = cast e;
			b.setCombo(uniqId);
			b.killHit(0);
			shockWave(b, radius, power);
			b.dy = -10 - Cs.rnd(20);
		}
	}
}

// hammer/entity/bomb/player/Blue.mt: knocks out the bads around
class Blue extends PlayerBomb {
	public function new() {
		super("bombBlue");
		explodeSound = "sound_bomb_blue";
		duration = 45;
		power = 20;
	}

	public static function attach(g:Game, x:Float, y:Float):Blue {
		var b = new Blue();
		b.attachMc(Data.DP_BOMBS);
		b.initBomb(g, x, y);
		return b;
	}

	override public function duplicate():Bomb {
		return attach(game, x, y);
	}

	override public function onExplode() {
		super.onExplode();
		for (e in bombGetClose(Data.BAD)) {
			var b:Bad = cast e;
			b.setCombo(uniqId);
			b.knock(Data.KNOCK_DURATION * 0.75);
			shockWave(b, radius, power);
			b.dx *= 0.3;
			b.dy = -6;
			b.yTrigger = b.y + Data.CASE_HEIGHT * 1.5;
			b.fl_hitGround = false;
		}
	}
}

// hammer/entity/bomb/player/Green.mt: a mine exploding when a bad touches it (or when it falls)
class Green extends PlayerBomb {
	public function new() {
		super("bombGreen");
		explodeSound = "sound_bomb_green";
		duration = 200;
		power = 25;
		fl_blink = true;
		fl_alphaBlink = false;
		fl_unstable = true;
	}

	public static function attach(g:Game, x:Float, y:Float):Green {
		var b = new Green();
		b.attachMc(Data.DP_BOMBS);
		b.initBomb(g, x, y);
		return b;
	}

	override public function duplicate():Bomb {
		return attach(game, x, y);
	}

	override public function endUpdate() {
		super.endUpdate();
		rotation = 0;
		mc._rotation = 0;
	}

	override public function onExplode() {
		if (fl_explode)
			return;
		Snd.play("sound_bomb", Snd.CHAN_BOMB);
		super.onExplode();
		for (e in bombGetClose(Data.BAD)) {
			var b:Bad = cast e;
			b.setCombo(uniqId);
			b.freeze(Data.FREEZE_DURATION);
			shockWave(b, radius, power);
		}
		game.fxMan.inGameParticles(Data.PARTICLE_ICE, x, y, Cs.vrnd(2) + 2);
	}
}

// hammer/entity/bomb/player/Red.mt: freezes and throws high; Igor on it jumps very high
class Red extends PlayerBomb {
	static inline var JUMP_POWER = 32;

	public function new() {
		super("bombRed");
		duration = 38;
		power = 30;
	}

	public static function attach(g:Game, x:Float, y:Float):Red {
		var b = new Red();
		b.attachMc(Data.DP_BOMBS);
		b.initBomb(g, x, y);
		return b;
	}

	override public function duplicate():Bomb {
		return attach(game, x, y);
	}

	override public function onExplode() {
		super.onExplode();
		for (e in bombGetClose(Data.BAD)) {
			var b:Bad = cast e;
			b.setCombo(uniqId);
			b.freeze(Data.FREEZE_DURATION);
			shockWave(b, radius, power);
			if (b.dy < 0) {
				b.dy *= 3;
				if (distance(b.x, b.y) <= radius * 0.5) {
					b.dx *= 0.5;
					b.dy *= 2;
				}
			}
		}
		game.fxMan.inGameParticles(Data.PARTICLE_ICE, x, y, Cs.vrnd(2) + 2);
		game.fxMan.attachExplodeZone(x, y, radius);
		// bomb jump of the player
		for (e in game.getList(Data.PLAYER)) {
			var p:Player = cast e;
			var distX = p.x - x;
			var distY = p.y - y;
			if (fl_stable) {
				distX *= 1.5;
				distY *= 0.5;
			} else {
				distX *= 0.9;
				distY *= 0.35;
			}
			var dist = Math.sqrt(distX * distX + distY * distY);
			if (dist <= 40) {
				if (p.dy > 0)
					p.dy = 0;
				p.dy -= JUMP_POWER;
				if (p.dy <= -35) {
					game.shake(10, 3);
					game.fxMan.attachExplodeZone(p.x, p.y - 40, 50);
					game.fxMan.attachExplodeZone(p.x, p.y - 80, 40);
					game.fxMan.attachExplodeZone(p.x, p.y - 120, 30);
				}
			} else {
				if (p.distance(x, y) <= radius)
					shockWave(p, radius, power);
			}
		}
	}
}
