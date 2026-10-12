package hammerfest;

// hammer/entity/Shoot.mt and its subclasses: projectiles (their pictures are the root of their clip)
class Shoot extends Physics {
	public var shootSpeed:Float;
	public var coolDown:Float;
	public var fl_borderBounce:Bool;
	public var fl_checkBounds:Bool;

	// pictures playing by themselves in the clip (looping)
	var fl_selfLoop:Bool;

	public function new(animBase:String) {
		super(animBase);
		fl_hitWall = false;
		fl_hitBorder = false;
		fl_hitGround = false;
		fl_gravity = false;
		fl_friction = false;
		fl_borderBounce = false;
		fl_checkBounds = true;
		fl_bump = false;
		fl_selfLoop = false;
		shootSpeed = 0;
		coolDown = 50;
	}

	override public function animName(id:Int):String {
		return animBase;
	}

	override public function init(g:Game) {
		super.init(g);
		register(Data.SHOOT);
		playAnim(Data.ANIM_SHOOT);
	}

	public function initShoot(g:Game, x:Float, y:Float) {
		init(g);
		moveTo(x, y);
		endUpdate();
	}

	override public function playAnim(a:Data.AnimDef) {
		super.playAnim(a);
		if (fl_selfLoop)
			fl_loop = true;
	}

	override public function endUpdate() {
		// horizontal flip
		if (dy == 0) {
			if (dx < 0)
				_xscale = -Math.abs(_xscale);
			else
				_xscale = Math.abs(_xscale);
		}
		super.endUpdate();
	}

	public function onSideBorderBounce() {}

	public function onHorizontalBorderBounce() {}

	override public function update() {
		super.update();
		// out of the game
		if (fl_checkBounds) {
			if (fl_borderBounce) {
				if (x < 0) {
					onSideBorderBounce();
					dx = Math.abs(dx);
				}
				if (x >= Data.GAME_WIDTH) {
					onSideBorderBounce();
					dx = -Math.abs(dx);
				}
				if (y < 0) {
					onHorizontalBorderBounce();
					dy = Math.abs(dy);
				}
				if (y >= Data.GAME_HEIGHT) {
					onHorizontalBorderBounce();
					dy = -Math.abs(dy);
				}
			} else {
				if (!world.inBound(cx, cy))
					destroy();
			}
		}
	}
}

// the pips of the apples
class Pepin extends Shoot {
	public function new() {
		super("pepin");
		shootSpeed = 5;
		_yOffset = -2;
	}

	public static function attach(g:Game, x:Float, y:Float):Pepin {
		var s = new Pepin();
		s.attachMc(Data.DP_SHOTS);
		s.initShoot(g, x, y);
		return s;
	}

	override public function hit(e:Entity) {
		if ((e.types & Data.PLAYER) > 0) {
			var et:Player = cast e;
			et.killHit(dx);
		}
	}
}

// the zests of the lemons (up or down)
class Zeste extends Shoot {
	public function new() {
		super("zest");
		shootSpeed = 6;
	}

	public static function attach(g:Game, x:Float, y:Float):Zeste {
		var s = new Zeste();
		s.attachMc(Data.DP_SHOTS);
		s.initShoot(g, x, y);
		return s;
	}

	override public function moveDown(s:Float) {
		super.moveDown(s);
		_yscale = -_yscale;
		_yOffset = -Data.CASE_HEIGHT;
	}

	override public function hit(e:Entity) {
		if ((e.types & Data.PLAYER) > 0) {
			if (Math.abs(e.x - x) <= Data.CASE_WIDTH * 0.65) {
				var et:Player = cast e;
				et.killHit((e.x - x) * 1.5);
				game.fxMan.attachExplodeZone(x, y, 15);
			}
		}
	}
}

// the ball of the strawberries
class Ball extends Shoot {
	public var targetCatcher:Entity;

	public function new() {
		super("ball");
		shootSpeed = 8.5;
		_yOffset = 0;
		fl_alphaBlink = false;
		fl_borderBounce = true;
	}

	override public function init(g:Game) {
		super.init(g);
		register(Data.BALL);
		setLifeTimer(Data.BALL_TIMEOUT);
	}

	public static function attach(g:Game, x:Float, y:Float):Ball {
		var s = new Ball();
		s.attachMc(Data.DP_SHOTS);
		s.initShoot(g, x, y);
		return s;
	}

	// not caught: given back to a strawberry
	override public function onLifeTimer() {
		game.fxMan.attachFx(x, y - Data.CASE_HEIGHT / 2, "fxPop");
		var bad:Fruits.Fraise = cast game.getOne(Data.CATCHER);
		if (bad != null)
			bad.assignBall();
		super.onLifeTimer();
	}

	override public function hit(e:Entity) {
		if ((e.types & Data.PLAYER) > 0) {
			var et:Player = cast e;
			et.killHit(dx);
		}
		if ((e.types & Data.CATCHER) > 0 && targetCatcher == e) {
			var f:Fruits.Fraise = cast e;
			f.catchBall(this);
		}
	}
}

// fireballs of the gold ring
class PlayerFireBall extends Shoot {
	public function new() {
		super("playerFireball");
		shootSpeed = 8;
		coolDown = Data.SECOND * 2;
		fl_selfLoop = true;
	}

	override public function init(g:Game) {
		super.init(g);
		register(Data.PLAYER_SHOOT);
	}

	public static function attach(g:Game, x:Float, y:Float):PlayerFireBall {
		var s = new PlayerFireBall();
		s.attachMc(Data.DP_SHOTS);
		s.initShoot(g, x, y);
		return s;
	}

	override public function hit(e:Entity) {
		if ((e.types & Data.BAD_CLEAR) > 0) {
			var et:Bad = cast e;
			et.setCombo(uniqId);
			et.burn();
		}
	}

	override public function destroy() {
		game.fxMan.inGameParticles(Data.PARTICLE_SPARK, x, y, 3);
		game.fxMan.inGameParticles(Data.PARTICLE_STONE, x, y, 4);
		super.destroy();
	}

	override public function update() {
		super.update();
		if (Cs.vrnd(3) == 0)
			game.fxMan.inGameParticles(Data.PARTICLE_SPARK, x, y, Cs.vrnd(3));
	}
}

// pearls of the crystal necklace: they freeze the bads
class PlayerPearl extends Shoot {
	var shotList:Array<Int>;

	public function new() {
		super("playerPearl");
		shootSpeed = 8.5;
		coolDown = Data.SECOND * 2;
		shotList = [];
		_yOffset = -16;
		fl_selfLoop = true;
	}

	override public function init(g:Game) {
		super.init(g);
		register(Data.PLAYER_SHOOT);
	}

	public static function attach(g:Game, x:Float, y:Float):PlayerPearl {
		var s = new PlayerPearl();
		s.attachMc(Data.DP_SHOTS);
		s.initShoot(g, x, y);
		return s;
	}

	function hitWallAnim() {
		game.fxMan.inGameParticles(Data.PARTICLE_ICE, x, y, 2);
		game.fxMan.inGameParticles(Data.PARTICLE_STONE, x, y, 3);
		if (dx < 0)
			game.fxMan.attachFx(x + Data.CASE_WIDTH * 0.5, y + _yOffset, "fxIcePouf");
		else
			game.fxMan.attachFx(x - Data.CASE_WIDTH * 0.5, y + _yOffset, "fxIcePouf");
	}

	override public function onSideBorderBounce() {
		super.onSideBorderBounce();
		hitWallAnim();
	}

	override public function onLifeTimer() {
		game.fxMan.attachFx(x, y, "fxPop");
		super.onLifeTimer();
	}

	override public function endUpdate() {
		if (dy != 0)
			rotation = Math.atan2(dy, dx) * 180 / Math.PI;
		super.endUpdate();
	}

	override public function destroy() {
		hitWallAnim();
		super.destroy();
	}

	override public function hit(e:Entity) {
		if ((e.types & Data.BAD) > 0) {
			var et:Bad = cast e;
			if (shotList.indexOf(et.uniqId) < 0) {
				et.setCombo(uniqId);
				et.freeze(Data.FREEZE_DURATION);
				et.dx = dx * 2;
				et.dy -= 3;
				shotList.push(et.uniqId);
			}
		}
	}
}

// arrows of the emerald ring
class PlayerArrow extends Shoot {
	var fl_livedOneTurn:Bool;

	public function new() {
		super("arrow");
		shootSpeed = 4;
		coolDown = Data.SECOND * 2;
		_yOffset = -15;
		fl_hitWall = true;
		fl_teleport = true;
		fl_livedOneTurn = false;
	}

	override public function init(g:Game) {
		super.init(g);
		register(Data.PLAYER_SHOOT);
		playAnim(Data.ANIM_SHOOT_LOOP);
	}

	public static function attach(g:Game, x:Float, y:Float):PlayerArrow {
		var s = new PlayerArrow();
		s.attachMc(Data.DP_SHOTS);
		s.initShoot(g, x, y);
		return s;
	}

	override public function onHitWall() {
		if (fl_livedOneTurn) {
			var fx = game.fxMan.attachFx(x, y + _yOffset, "fxArrowPouf");
			if (fx != null && dx < 0)
				fx.mc._xscale = -fx.mc._xscale;
		} else {
			game.fxMan.attachFx(x, y - Data.CASE_HEIGHT * 0.5, "fxPop");
		}
		destroy();
	}

	override public function hit(e:Entity) {
		if ((e.types & Data.BAD) > 0) {
			var et:Bad = cast e;
			et.setCombo(uniqId);
			et.killHit(dx);
			game.fxMan.attachFx(x, y - Data.CASE_HEIGHT * 0.5, "fxPop");
			destroy();
		}
	}

	override public function update() {
		super.update();
		fl_livedOneTurn = true;
	}
}

// hammer/entity/shoot/FireBall.mt: fireball of the crawlers
class BadFireBall extends Shoot {
	public function new() {
		super("crawlerFireball");
		fl_largeTrigger = true;
		shootSpeed = 7;
		fl_selfLoop = true;
	}

	override public function init(g:Game) {
		super.init(g);
		playAnim(Data.ANIM_SHOOT_LOOP);
	}

	public static function attach(g:Game, x:Float, y:Float):BadFireBall {
		var s = new BadFireBall();
		s.attachMc(Data.DP_SHOTS);
		s.initShoot(g, x, y - 10);
		return s;
	}

	override public function destroy() {
		game.fxMan.attachFx(x, y - Data.CASE_HEIGHT / 2, "fxPop");
		super.destroy();
	}

	override public function hit(e:Entity) {
		if ((e.types & Data.PLAYER) > 0) {
			var p:Player = cast e;
			if (distance(p.x, p.y) <= Data.CASE_WIDTH * 1.2) {
				game.fxMan.attachExplosion(x, y, 25);
				p.killHit(dx);
			}
		}
	}
}

// hammer/entity/shoot/FramBall.mt: a piece of a raspberry flying (turning towards the place where it is put back
// together, slower and slower near it); it kills Igor on its way
class FramBall extends Shoot {
	public var owner:Fruits.Framboise;
	public var piece:Int;

	var turnSpeed:Float;
	var ang:Float;
	var fl_arrived:Bool;

	public function new() {
		super("framBall");
		shootSpeed = 5 + Cs.rnd(3);
		turnSpeed = 0.03 + Cs.rnd(10) / 100 + shootSpeed * 0.02;
		_yOffset = -2;
		fl_checkBounds = false;
		fl_blink = false;
		fl_arrived = false;
		piece = 1;
		ang = Cs.rnd(314);
	}

	public static function attach(g:Game, x:Float, y:Float):FramBall {
		var s = new FramBall();
		s.attachMc(Data.DP_SHOTS);
		s.initShoot(g, x, y);
		return s;
	}

	override public function init(g:Game) {
		super.init(g);
		setLifeTimer(Data.SECOND * 4);
		disableAnimator();
	}

	// its raspberry, and the piece it is (its picture)
	public function setOwner(b:Fruits.Framboise, n:Int) {
		owner = b;
		var tang = Cs.qt(Math.atan2(owner.ty - y, owner.tx - x));
		ang = -tang + (Cs.rnd(168) / 100) * (Cs.rnd(2) * 2 - 1);
		if (owner.anger > 0)
			shootSpeed *= (1 + owner.anger * 0.5);
		piece = n;
		pic.show(n);
	}

	override public function hit(e:Entity) {
		if ((e.types & Data.PLAYER) > 0) {
			var et:Player = cast e;
			et.killHit(dx);
		}
	}

	static function adjustAngRad(a:Float):Float {
		if (a < -Math.PI)
			return a + Math.PI * 2;
		if (a > Math.PI)
			return a - Math.PI * 2;
		return a;
	}

	override public function onLifeTimer() {
		onArrived();
		super.onLifeTimer();
	}

	function onArrived() {
		if (fl_arrived)
			return;
		fl_arrived = true;
		owner.onArrived(this);
	}

	override public function infix() {
		super.infix();
		// slower close to the place
		var d = distance(owner.tx, owner.ty);
		if (d < 40)
			turnSpeed *= 1.1;
		if (d < 20) {
			shootSpeed *= 0.9;
			if (shootSpeed <= 5.8 || owner.anger > 0)
				onArrived();
		}
		turnSpeed = Math.min(1, turnSpeed);
		shootSpeed = Math.max(2, shootSpeed);
	}

	override public function update() {
		// towards the place where the raspberry is put back together
		var tang = Cs.qt(Math.atan2(owner.ty - y, owner.tx - x));
		if (adjustAngRad(tang - ang) > 0)
			ang += turnSpeed * Game.tmod;
		if (adjustAngRad(tang - ang) < 0)
			ang -= turnSpeed * Game.tmod;
		// (tmod twice in the original: its speed and its move, the pieces as slow as in the original)
		dx = Cs.qt(Math.cos(ang)) * shootSpeed * Game.tmod;
		dy = Cs.qt(Math.sin(ang)) * shootSpeed * Game.tmod;
		super.update();
	}
}
