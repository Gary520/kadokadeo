package hammerfest;

import hammerfest.Bad;
import hammerfest.Data.AnimDef;

// the fruits of the original (hammer/entity/bad/walker/*.mt)
class Fruits {
	public static function attachBad(g:Game, id:Int, x:Float, y:Float):Bad {
		var b:Bad = switch (id) {
			case Data.BAD_POMME: new Pomme();
			case Data.BAD_CERISE: new Cerise();
			case Data.BAD_BANANE: new Banane();
			case Data.BAD_ORANGE: new Orange();
			case Data.BAD_CITRON: new Citron();
			case Data.BAD_ABRICOT: new Abricot(true);
			case Data.BAD_ABRICOT2: new Abricot(false);
			case Data.BAD_POIRE: new Poire();
			case Data.BAD_FRAISE: new Fraise();
			case Data.BAD_KIWI: new Kiwi();
			case Data.BAD_BOMBE: new Bombe();
			case Data.BAD_LITCHI: new Litchi();
			case Data.BAD_LITCHI_WEAK: new LitchiWeak();
			case Data.BAD_ANANAS: new Bads2.Ananas();
			case Data.BAD_FRAMBOISE: new Framboise();
			case Data.BAD_BALEINE: new Baleine();
			case Data.BAD_CRAWLER: new Bads2.Crawler();
			case Data.BAD_SAW: new Bads2.Saw();
			case Data.BAD_SPEAR: new Bads2.Spear();
			default: null;
		}
		if (b == null)
			return null;
		b.attachMc(id == Data.BAD_SPEAR ? Data.DP_SPEAR : Data.DP_BADS);
		b.initBad(g, x, y);
		return b;
	}
}

class Cerise extends Walker {
	public function new() {
		super("cerise");
		animFactor = 0.65;
	}
}

class Orange extends Jumper {
	public function new() {
		super("orange");
		setJumpH(100);
	}
}

class Pomme extends Shooter {
	public function new() {
		super("pomme");
		setJumpUp(3);
		setJumpH(100);
		setClimb(100, 1);
		setFall(20);
		setShoot(2);
		initShooter(20, 12);
	}

	override public function onShoot() {
		var s = Shoot.Pepin.attach(game, x, y);
		if (dir < 0)
			s.moveLeft(s.shootSpeed);
		else
			s.moveRight(s.shootSpeed);
	}
}

class Banane extends Jumper {
	public function new() {
		super("banane");
		setJumpUp(5);
		setJumpDown(5);
		setJumpH(100);
		setClimb(100, Data.IA_CLIMB);
		setFall(5);
	}
}

class Citron extends Shooter {
	public function new() {
		super("citron");
		setJumpH(50);
		setShoot(3);
		initShooter(50, 20);
	}

	override public function onShoot() {
		var s = Shoot.Zeste.attach(game, x, y);
		var target = game.getOne(Data.PLAYER);
		if (target != null && target.y < y)
			s.moveUp(s.shootSpeed);
		else
			s.moveDown(s.shootSpeed);
	}
}

class Abricot extends Jumper {
	public var fl_spawner:Bool;

	public function new(spawner:Bool) {
		super("abricot");
		fl_spawner = spawner;
		animFactor = 0.65;
		setJumpUp(5);
		setJumpH(100);
		setClimb(100, 3);
		setFall(20);
	}

	override public function init(g:Game) {
		super.init(g);
		if (!fl_spawner)
			scale(75);
		dir = -1;
	}

	// a big apricot gives two small ones when it falls out of the level
	override public function onDeathLine() {
		if (fl_spawner) {
			game.attachBad(Data.BAD_ABRICOT2, x - Data.CASE_WIDTH, -30);
			game.attachBad(Data.BAD_ABRICOT2, x + Data.CASE_WIDTH, -30);
		}
		super.onDeathLine();
	}
}

class Poire extends Shooter {
	public function new() {
		super("poire");
		setJumpH(100);
		setClimb(100, 1);
		setShoot(4);
		initShooter(50, 8);
	}

	override public function onShoot() {
		var s = Bomb.PoireBomb.attach(game, x, y);
		var spd = 10;
		if (dir < 0)
			s.moveToAng(-135, spd);
		else
			s.moveToAng(-45, spd);
		setNext(null, null, shootDuration, Data.ACTION_FALLBACK);
	}
}

// the strawberries pass a ball to each other (and throw it at the player)
class Fraise extends Shooter {
	public var fl_ball:Bool;
	public var ballTarget:Entity;
	public var catchCD:Float;

	public function new() {
		super("fraise");
		catchCD = 0;
		animFactor = 1.0;
		setShoot(4);
		initShooter(0, 10);
	}

	override public function init(g:Game) {
		super.init(g);
		fl_ball = false;
		// first ball
		assignBall();
		for (e in game.getList(Data.CATCHER)) {
			var b:Fraise = cast e;
			if (b.fl_ball)
				fl_ball = false;
		}
		if (game.getList(Data.BALL).length > 0)
			fl_ball = false;
		register(Data.CATCHER);
	}

	public function catchBall(b:Shoot.Ball) {
		if (!isHealthy())
			return;
		next = null;
		walk();
		assignBall();
		b.destroy();
		ballTarget = null;
	}

	public function assignBall() {
		fl_ball = true;
		catchCD = Data.SECOND * 1.5;
	}

	override public function onShoot() {
		super.onShoot();
		this.fl_ball = false;
		if (ballTarget == null)
			return;
		// the receiver is a bad
		if ((ballTarget.types & Data.BAD) > 0) {
			var bad:Walker = cast ballTarget;
			bad.setNext(null, null, Data.BALL_TIMEOUT + 5, Data.ACTION_WALK);
			bad.halt();
			bad.playAnim(Data.ANIM_BAD_THINK);
		}
		var s = Shoot.Ball.attach(game, x, y);
		s.moveToTarget(ballTarget, s.shootSpeed);
		s.targetCatcher = ballTarget;
	}

	override public function onEndAnim(id:Int) {
		super.onEndAnim(id);
		ballTarget = null;
	}

	override public function startShoot() {
		if (!fl_ball || catchCD > 0)
			return;
		// looks for a receiver
		var l = game.getListCopy(Data.CATCHER);
		var bad:Walker = null;
		do {
			var i = Cs.rnd(l.length);
			bad = cast l[i];
			l.splice(i, 1);
		} while (bad != null && (bad == this || !bad.isReady()));
		if (bad != null) {
			ballTarget = bad;
		} else {
			if (game.getList(Data.CATCHER).length == 1) {
				// aims at the player
				ballTarget = game.getOne(Data.PLAYER);
				if (ballTarget == null)
					return;
			} else {
				return;
			}
		}
		super.startShoot();
	}

	override public function destroy() {
		if (fl_ball) {
			var bad:Fraise = cast game.getAnotherOne(Data.CATCHER, this);
			if (bad != null)
				bad.assignBall();
		}
		super.destroy();
	}

	// (its pictures with or without the ball: the clip 'balle' is shown only on the one holding it)
	override public function animName(id:Int):String {
		return (fl_ball ? "fraise_" : "fraiseNB_") + id;
	}

	override public function endUpdate() {
		super.endUpdate();
		if (animId != null) {
			var want = animName(animId);
			if (pic.anim != want)
				setPics(want);
		}
		// faces the target of its throw
		if (dx == 0 && ballTarget != null && ballTarget.fl_destroy == false) {
			if (ballTarget.x > x)
				_xscale = Math.abs(_xscale);
			if (ballTarget.x < x)
				_xscale = -Math.abs(_xscale);
		}
	}

	override public function update() {
		super.update();
		if (catchCD > 0) {
			catchCD -= Game.tmod;
			if (catchCD <= 0)
				catchCD = 0;
		}
		// lost ball
		if (game.countList(Data.BALL) == 0) {
			var fl_lost = true;
			for (e in game.getList(Data.BAD_CLEAR)) {
				if (Std.isOfType(e, Fraise) && (cast e : Fraise).fl_ball)
					fl_lost = false;
			}
			if (fl_lost)
				assignBall();
		}
	}
}

// hammer/entity/bad/walker/Framboise.mt: the raspberry bursts into 6 pieces flying to a place far away (when a bomb of
// Igor is close, or at random), where it is put back together; its pieces kill Igor on their way
class Framboise extends Shooter {
	static inline var FRAGS = 6;
	static inline var MAX_TRIES = 1000;

	public var tx:Float;
	public var ty:Float;
	public var fl_phased:Bool;

	var arrived:Int;
	// (put back together: its sub one picture further for each of the pieces 1-4, its parts o1 / o2 for the pieces 5 / 6)
	var arrivedSub:Int;
	var parts:Int;

	public function new() {
		super("framboise");
		setJumpUp(3);
		setJumpDown(6);
		setJumpH(100);
		setClimb(100, 3);
		setFall(20);
		setShoot(0.7);
		initShooter(20, 12);
		fl_phased = false;
		tx = 0;
		ty = 0;
		arrived = 0;
		arrivedSub = 0;
		parts = 0;
	}

	function aroundX(base:Float):Float {
		return base + Cs.rnd(Data.CASE_WIDTH) * (Cs.rnd(2) * 2 - 1);
	}

	function aroundY(base:Float):Float {
		return base - Cs.rnd(Data.CASE_HEIGHT);
	}

	override public function isReady():Bool {
		return super.isReady() && !fl_phased;
	}

	override public function freeze(d:Float) {
		phaseIn();
		super.freeze(d);
	}

	override public function knock(d:Float) {
		phaseIn();
		super.knock(d);
	}

	override public function killHit(dx:Null<Float>) {
		phaseIn();
		super.killHit(dx);
	}

	override public function destroy() {
		clearFrags();
		super.destroy();
	}

	override public function onHitGround(h:Float) {
		super.onHitGround(h);
		if (h >= Data.CASE_HEIGHT * 2)
			game.fxMan.inGameParticles(Data.PARTICLE_FRAMB, x, y, Cs.vrnd(4) + 2);
	}

	// a piece has arrived: the raspberry is there, a piece more
	public function onArrived(fb:Shoot.FramBall) {
		show();
		moveTo(tx, ty);
		var n = fb.piece;
		fb.destroy();
		if (n >= 5)
			parts |= (n == 5) ? 1 : 2;
		else if (arrivedSub < 4)
			arrivedSub++;
		pic.show(1 + arrivedSub * 4 + parts);
		arrived++;
		if (arrived >= FRAGS)
			phaseIn();
	}

	function clearFrags() {
		for (s in game.getListCopy(Data.SHOOT))
			if (Std.isOfType(s, Shoot.FramBall) && (cast s : Shoot.FramBall).owner == this)
				s.destroy();
	}

	function phaseOut() {
		game.fxMan.inGameParticles(Data.PARTICLE_FRAMB, x, y, Cs.vrnd(3) + 2);
		game.fxMan.attachExplosion(x, y, 40);
		fl_phased = true;
		dx = 0;
		dy = 0;
		disableShooter();
		disableAnimator();
		pic.setAnim("framboiseIn");
		pic.show(1);
		arrivedSub = 0;
		parts = 0;
		hide();
	}

	override public function walk() {
		if (!fl_phased)
			super.walk();
	}

	function phaseIn() {
		clearFrags();
		var was = fl_phased;
		fl_phased = false;
		enableAnimator();
		enableShooter();
		game.fxMan.attachExplosion(x, y, 40);
		// (its pictures of the animations again at the next one)
		if (was)
			animId = null;
	}

	override public function onShoot() {
		var tries = 0;
		var ctx = 0;
		var cty = 0;
		var fl_inv = false;
		do {
			fl_inv = false;
			ctx = Cs.rnd(Data.LEVEL_WIDTH);
			cty = Cs.rnd(Data.LEVEL_HEIGHT);
			tries++;
			if (distanceCase(ctx, cty) <= 7)
				fl_inv = true;
			if (!world.checkFlag(ctx, cty, Data.IA_TILE_TOP))
				fl_inv = true;
			if (world.checkFlag(ctx, cty, Data.IA_SMALL_SPOT))
				fl_inv = true;
			for (e in game.getList(Data.SPEAR))
				if (e.cx == ctx && e.cy == cty)
					fl_inv = true;
		} while (tries < MAX_TRIES && fl_inv);
		if (tries >= MAX_TRIES)
			return;
		tx = Entity.x_ctr(ctx);
		ty = Entity.y_ctr(cty);
		arrived = 0;
		phaseOut();
		for (i in 0...FRAGS) {
			var s = Shoot.FramBall.attach(game, aroundX(x), aroundY(y));
			s.setOwner(this, i + 1);
		}
	}

	override public function update() {
		if (!_visible) {
			// (out of the way while its pieces fly)
			moveTo(100, -200);
			if (!isHealthy()) {
				show();
				moveTo(tx, ty);
				phaseIn();
			}
		} else {
			// a bomb of Igor close: it bursts
			var bl = game.getClose(Data.PLAYER_BOMB, x, y, 90, false);
			if (isReady() && bl.length >= 1)
				startShoot();
		}
		super.update();
	}
}

// the kiwis plant mines
class Kiwi extends Shooter {
	public var mineList:Array<Bomb.Mine>;

	public function new() {
		super("kiwi");
		setJumpUp(10);
		setJumpDown(20);
		setJumpH(50);
		setClimb(100, 3);
		setShoot(3);
		initShooter(Data.SECOND * 1, Data.SECOND * 0.6);
		speed *= 0.7;
		angerFactor *= 2.5;
		calcSpeed();
		shootCD = 0;
		mineList = [];
	}

	override public function onShoot() {
		var m = Bomb.Mine.attach(game, x + dir * Data.CASE_WIDTH * 1.1, y);
		mineList.push(m);
	}
}

// the bombs: they explode instead of dying
class Bombe extends Jumper {
	static inline var RADIUS = Data.CASE_WIDTH * 5;
	static inline var POWER = 30;

	public var fl_overheat:Bool;

	public function new() {
		super("bombe");
		setJumpUp(10);
		setJumpDown(6);
		setJumpH(100);
		setClimb(100, 3);
		fl_alphaBlink = false;
		fl_overheat = false;
		blinkColor = 0xff9e5e;
		blinkColorAlpha = 50;
	}

	override public function playAnim(obj:AnimDef) {
		if (fl_overheat)
			return;
		super.playAnim(obj);
		if (obj.id == Data.ANIM_BAD_THINK.id)
			fl_loop = true;
		if (obj.id == Data.ANIM_BAD_JUMP.id)
			fl_loop = false;
	}

	public function trigger() {
		if (fl_overheat)
			return;
		halt();
		playAnim(Data.ANIM_BAD_DIE);
		fl_loop = false;
		fl_freeze = false;
		setLifeTimer(Data.SECOND * 3);
		updateLifeTimer(Data.SECOND);
		setNext(null, null, Data.SECOND * 3, Data.ACTION_WALK);
		fl_overheat = true;
	}

	public function selfDestruct() {
		game.fxMan.attachExplodeZone(x, y, RADIUS);
		for (e in game.getClose(Data.PLAYER, x, y, RADIUS, false)) {
			var p:Player = cast e;
			p.killHit(0);
			shockWave(p, RADIUS, POWER);
			if (!p.fl_shield)
				p.dy = -10 - Cs.rnd(20);
		}
		dropReward();
		Snd.play("sound_bomb_black", Snd.CHAN_BOMB);
		game.fxMan.inGameParticles(Data.PARTICLE_METAL, x, y, Cs.vrnd(4) + 5);
		game.fxMan.inGameParticles(Data.PARTICLE_SPARK, x, y, Cs.vrnd(4));
		onKill();
		destroy();
	}

	override public function killHit(dx:Null<Float>) {
		trigger();
	}

	override public function onFreeze() {
		trigger();
	}

	override public function isHealthy():Bool {
		return !fl_overheat && super.isHealthy();
	}

	override public function onLifeTimer() {
		selfDestruct();
	}

	override public function prefix() {
		if (!fl_stable && fl_overheat)
			dx = 0;
		super.prefix();
	}
}

// the litchis: a bomb only takes off their shell
class Litchi extends Jumper {
	public var child:LitchiWeak;

	public function new() {
		super("litchi");
		speed *= 0.8;
		setJumpH(100);
		setJumpUp(10);
		setJumpDown(6);
		setClimb(25, 3);
		setFall(25);
	}

	override public function freeze(d:Float) {
		weaken();
	}

	override public function killHit(dx:Null<Float>) {
		if (!fl_knock)
			knock(Data.KNOCK_DURATION);
	}

	override public function forceKill(dx:Null<Float>) {
		super.killHit(dx);
	}

	public function weaken() {
		if (child != null)
			return;
		child = cast Fruits.attachBad(game, Data.BAD_LITCHI_WEAK, x, y - Data.CASE_HEIGHT);
		// (the litchi without its shell takes its place in the order of the big crystal)
		game.replaceInOrder(this, child);
		child.angerMore();
		child.updateSpeed();
		child.halt();
		child.dir = dir;
		game.fxMan.inGameParticles(Data.PARTICLE_LITCHI, x + Cs.vrnd(20) * (Cs.vrnd(2) * 2 - 1), y - Cs.vrnd(20), Cs.vrnd(3) + 5);
		child.playAnim(Data.ANIM_BAD_SHOOT_START);
	}

	override public function update() {
		super.update();
		if (!fl_kill && fl_knock && child == null && dy <= -Data.BAD_VJUMP_Y * 0.6)
			dy = -Data.BAD_VJUMP_Y * 0.6;
	}

	override public function endUpdate() {
		if (child != null) {
			child.dy = -7;
			destroy();
		} else {
			super.endUpdate();
		}
	}
}

class LitchiWeak extends Jumper {
	public function new() {
		super("litchiW");
		setJumpH(100);
		setJumpUp(10);
		setJumpDown(6);
		setClimb(25, 3);
		setFall(25);
	}

	override public function onEndAnim(id:Int) {
		super.onEndAnim(id);
		if (id == Data.ANIM_BAD_SHOOT_START.id) {
			playAnim(Data.ANIM_BAD_WALK);
			walk();
		}
	}

	override public function walk() {
		if (animId != Data.ANIM_BAD_SHOOT_START.id)
			super.walk();
	}
}

// hammer/entity/bad/Flyer.mt: a bad flying at 45 degrees, bouncing off the walls, the floors, the ceilings and the
// bottom of the level; frozen or knocked out, it falls like the others and flies again when it melts or wakes up
class Flyer extends Bad {
	var xSpeed:Float;
	var ySpeed:Float;
	var fl_fly:Bool;
	var fl_intercept:Bool; // frozen in the air
	var speed:Float;
	var dir:Int;

	public function new(animBase:String) {
		super(animBase);
		speed = 4;
		angerFactor = 0.5;
	}

	override public function init(g:Game) {
		super.init(g);
		xSpeed = Math.cos(Math.PI * 0.25) * speed;
		ySpeed = Math.sin(Math.PI * 0.25) * speed;
		dir = Cs.rnd(2) * 2 - 1;
		fly();
	}

	function fly() {
		if (!isHealthy())
			return;
		if (anger > 0)
			playAnim(Data.ANIM_BAD_ANGER);
		else
			playAnim(Data.ANIM_BAD_WALK);
		dx = dir * xSpeed * speedFactor;
		dy = -ySpeed * speedFactor;
		fl_fly = true;
		fl_intercept = false;
		fl_gravity = false;
		fl_friction = false;
		fl_hitCeil = true;
	}

	function land() {
		fl_fly = false;
		fl_gravity = true;
		fl_friction = true;
		fl_hitCeil = false;
	}

	override public function killHit(dx:Null<Float>) {
		super.killHit(dx);
		land();
	}

	override public function infix() {
		super.infix();
		if (fl_fly && y >= Data.GAME_HEIGHT) {
			y = Data.GAME_HEIGHT;
			dy = -ySpeed * speedFactor;
		}
	}

	override public function postfix() {
		super.postfix();
		if (fl_fly)
			fl_friction = false;
	}

	override public function playAnim(a:AnimDef) {
		if (a.id != Data.ANIM_BAD_JUMP.id)
			super.playAnim(a);
	}

	override public function updateSpeed() {
		super.updateSpeed();
		if (fl_fly) {
			dx = dir * xSpeed * speedFactor;
			if (dy < 0)
				dy = -ySpeed * speedFactor;
			else
				dy = ySpeed * speedFactor;
		}
	}

	override public function onNext() {
		if (!fl_fly)
			super.onNext();
	}

	override public function onHitGround(h:Float) {
		if (!fl_fly) {
			fl_intercept = false;
			super.onHitGround(h);
			return;
		}
		fl_stopStepping = true;
		dy = -ySpeed * speedFactor;
	}

	override public function onHitCeil() {
		if (!fl_fly) {
			super.onHitCeil();
			return;
		}
		fl_stopStepping = true;
		dy = ySpeed * speedFactor;
	}

	override public function onHitWall() {
		if (!fl_fly) {
			if (world.getCase(cx, cy) != Data.WALL)
				dx = -dx;
			return;
		}
		fl_stopStepping = true;
		dir = -dir;
		dx = dir * xSpeed * speedFactor;
	}

	override public function onFreeze() {
		super.onFreeze();
		if (fl_fly)
			fl_intercept = true;
		land();
	}

	override public function onKnock() {
		super.onKnock();
		land();
	}

	override public function onMelt() {
		super.onMelt();
		fly();
	}

	override public function onWakeUp() {
		super.onWakeUp();
		fly();
	}

	override public function update() {
		super.update();
		// (the top of the level)
		if (fl_fly && dy < 0 && y <= Data.CASE_HEIGHT)
			dy = Math.abs(dy);
	}

	override public function endUpdate() {
		super.endUpdate();
		_xscale = dir * Math.abs(_xscale);
	}
}

// hammer/entity/bad/flyer/Baleine.mt: the leapers (Bondissantes), flying watermelons
class Baleine extends Flyer {
	public function new() {
		super("baleine");
	}
}

// hammer/entity/bad/FireBall.mt: the ghost of the hurry up, chasing the player through the walls
class FireBall extends Bad {
	var body:Pic;
	var eyes:Pic;
	var ang:Float;
	var tang:Float;
	var speed:Float;
	var angSpeed:Float;
	var angerTimer:Float;
	var summonTimer:Float;

	public var fl_summon:Bool;

	var bodyFrame:Int;
	// (its eyelids, playing by themselves: 8 pictures for each of the 60 angles)
	var eyeFrame:Int = 0;

	public function new() {
		super("cerise");
		mc.removeChild(pic);
		// the body turns around its own center (its place in hammer_bad_fireball)
		body = new Pic("fireballBody");
		var m = Art.FIREBALL_BODY;
		body._xscale = m[0] * 100;
		body._yscale = m[3] * 100;
		eyes = new Pic("fireballEyes");
		var e = Art.FIREBALL_EYES;
		eyes._x = e[4];
		eyes._y = e[5];
		var bodyHolder = new ASprite();
		bodyHolder._x = m[4];
		bodyHolder._y = m[5];
		bodyHolder.addChild(body);
		mc.addChild(bodyHolder);
		mc.addChild(eyes);
		this.bodyHolder = bodyHolder;
		bodyFrame = 1;
		disableAnimator();
		fl_hitGround = false;
		fl_hitWall = false;
		fl_gravity = false;
		fl_hitBorder = false;
		fl_alphaBlink = true;
		speed = 2.5;
		angSpeed = 1.5;
		ang = 270;
		tang = 270;
		summonTimer = 85;
		fl_summon = true;
		angerTimer = 0;
		angerFactor = 0.05;
		maxAnger = 9999;
	}

	var bodyHolder:ASprite;

	override public function init(g:Game) {
		super.init(g);
		register(Data.HU_BAD);
		unregister(Data.BAD_CLEAR);
		blink(Data.BLINK_DURATION);
	}

	public static function attach(g:Game, p:Player):FireBall {
		var b = new FireBall();
		b.attachMc(Data.DP_BADS);
		b.initBad(g, Data.GAME_WIDTH / 2, Data.GAME_HEIGHT + 10);
		b.hate(p);
		return b;
	}

	override public function get_width():Float {
		return 30;
	}

	override public function get_height():Float {
		return 30;
	}

	override public function playAnim(o:AnimDef) {}

	override public function freeze(d:Float) {}

	override public function knock(d:Float) {}

	override public function killHit(dx:Null<Float>) {}

	override public function tAdd(cx:Int, cy:Int) {
		super.tAdd(cx, cy);
		tAddSingle(cx, cy + 1);
	}

	override public function tRem(cx:Int, cy:Int) {
		super.tRem(cx, cy);
		tRemSingle(cx, cy + 1);
	}

	override public function endUpdate() {
		super.endUpdate();
		bodyHolder._rotation = ang;
		eyeFrame = eyeFrame % 8 + 1;
		eyes.show((Std.int(Math.min(60, Math.round(ang / 360 * 60) + 1)) - 1) * 8 + eyeFrame);
		// the body plays its own timeline
		bodyFrame = bodyFrame % body.count() + 1;
		body.show(bodyFrame);
	}

	override public function hit(e:Entity) {
		if (fl_summon)
			return;
		if ((e.types & Data.PLAYER) > 0) {
			var et:Player = cast e;
			if (et.animId != Data.ANIM_PLAYER_DIE.id) {
				et.fl_shield = false;
				et.killHit(dx);
			}
		}
		if ((e.types & Data.BOMB) > 0) {
			var b:Bomb = cast e;
			if (!b.fl_kill && !b.fl_explode)
				b.onExplode();
		}
	}

	override public function angerMore() {
		super.angerMore();
		angSpeed *= 1.15;
	}

	override public function onHurryUp() {}

	override public function onDeathLine() {}

	override public function update() {
		if (fl_summon) {
			summonTimer -= Game.tmod;
			if (summonTimer <= 0) {
				fl_summon = false;
				stopBlink();
			}
		}
		// death of the target
		if (player == null || player.fl_kill || player.fl_destroy) {
			game.fxMan.attachShine(x, y);
			game.fxMan.attachExplodeZone(x, y, 4 * Data.CASE_WIDTH);
			game.shake(Data.SECOND * 1, 5);
			destroy();
			return;
		}
		// anger over time
		angerTimer += Game.tmod * game.diffFactor;
		if (angerTimer >= Data.AUTO_ANGER) {
			angerTimer = 0;
			angerMore();
		}
		// angle to the target
		tang = Math.atan2(player.y - y, player.x - x);
		tang = adjustAngle(tang * 180 / Math.PI);
		if (ang - tang > 180)
			ang -= 360;
		if (tang - ang > 180)
			ang += 360;
		if (ang < tang) {
			ang += angSpeed * speedFactor * Game.tmod;
			if (ang > tang)
				ang = tang;
		}
		if (ang > tang) {
			ang -= angSpeed * speedFactor * Game.tmod;
			if (ang < tang)
				ang = tang;
		}
		ang = adjustAngle(ang);
		moveToAng(ang, speed * speedFactor);
		super.update();
	}
}
