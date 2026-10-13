package hammerfest;

import hammerfest.Bad;
import hammerfest.Data.AnimDef;

// hammer/entity/bad/Spear.mt: spikes on a ground, a wall or a ceiling (they also kill the bads thrown on them)
class Spear extends Bad {
	public function new() {
		super("cerise");
		disablePhysics();
		disableAnimator();
		realRadius = Data.CASE_WIDTH * 0.7;
	}

	override public function animName(id:Int):String {
		return "spear";
	}

	override public function init(g:Game) {
		super.init(g);
		unregister(Data.BAD_CLEAR);
		register(Data.SPEAR);
	}

	override public function initBad(g:Game, x:Float, y:Float) {
		super.initBad(g, x, y);
		pic.setAnim("spear");
		// side of the wall it is on
		var f = 1;
		if (world.getCase(cx, cy + 1) > 0)
			f = 1;
		else if (world.getCase(cx, cy - 1) > 0)
			f = 3;
		else if (world.getCase(cx - 1, cy) > 0)
			f = 2;
		else if (world.getCase(cx + 1, cy) > 0)
			f = 4;
		pic.show(f);
		setSubs();
	}

	override public function freeze(d:Float) {}

	override public function knock(d:Float) {}

	override public function killHit(dx:Null<Float>) {}

	override public function burn() {
		game.fxMan.attachFx(x, y, "fxPop");
	}

	override public function update() {
		// (no physics: just the contacts of the others)
		if (player == null || player.fl_destroy)
			hate(cast game.getOne(Data.PLAYER));
	}

	override public function hit(e:Entity) {
		super.hit(e);
		if ((e.types & Data.BAD_CLEAR) > 0) {
			var b:Bad = cast e;
			if (b.fl_physics && b.fl_trap)
				b.killHit(null);
		}
	}

	public static function attach(g:Game, x:Float, y:Float):Spear {
		var s = new Spear();
		s.attachMc(Data.DP_SPEAR);
		s.initBad(g, x, y);
		return s;
	}
}

// hammer/entity/bad/walker/Ananas.mt: the pineapple jumps and its landing knocks Igor out and throws everything away
class Ananas extends Jumper {
	static inline var CHANCE_DASH = 6;

	var fl_attack:Bool;
	var dashRadius:Float;
	var dashPower:Float;

	public function new() {
		super("ananas");
		setJumpH(100);
		speed *= 0.8;
		dashRadius = 100;
		dashPower = 30;
		fl_attack = false;
		slideFriction = 0.9;
		shockResistance = 2.0;
	}

	override public function freeze(d:Float) {
		super.freeze(d);
		fallFactor *= 1.5;
		fl_attack = false;
		unstick();
	}

	override public function knock(d:Float) {
		super.knock(d);
		fallFactor *= 1.5;
		fl_attack = false;
		unstick();
	}

	override public function killHit(dx:Null<Float>) {
		super.killHit(dx);
		fl_attack = false;
	}

	override public function isReady():Bool {
		return !fl_attack && super.isReady();
	}

	function repel(type:Int, powerFactor:Float) {
		for (e in game.getClose(type, x, y, dashRadius, false)) {
			var p:Physics = cast e;
			shockWave(p, dashRadius, dashPower * powerFactor);
			p.dy -= 8;
			if (p.isType(Data.PLAYER))
				(cast p : Player).knock(Data.SECOND * 1.5);
		}
	}

	function vaporize(type:Int) {
		for (e in game.getClose(type, x, y, dashRadius, false)) {
			game.fxMan.attachFx(e.x, e.y - Data.CASE_HEIGHT, "fxPop");
			e.destroy();
		}
	}

	function startAttack() {
		if (player == null || player.fl_knock)
			return;
		halt();
		playAnim(Data.ANIM_BAD_THINK);
		forceLoop(true);
		setNext(0, -10, Data.SECOND * 0.9, Data.ACTION_MOVE);
		fl_attack = true;
		var c = new ASprite();
		var taunt = new Pic("curse_" + Data.CURSE_TAUNT);
		c.addChild(taunt);
		game.dm.add(c, Data.DP_FX);
		stick(c, 0, -Data.CASE_HEIGHT * 2.5);
		stickerPic = taunt;
	}

	function attack() {
		var fx = game.fxMan.attachExplodeZone(x, y, dashRadius);
		if (fx != null)
			fx.mc._alpha = 20;
		game.shake(Data.SECOND * 0.5, 5);
		for (p in game.getPlayers()) {
			if (p.fl_stable) {
				if (p.fl_shield || p.entryGuard > 0)
					p.dy = -8;
				else
					p.knock(Data.SECOND * 2.5);
			}
		}
		repel(Data.BOMB, 1);
		repel(Data.PLAYER, 2);
		vaporize(Data.PLAYER_SHOOT);
		fl_attack = false;
		unstick();
	}

	override public function onHitGround(h:Float) {
		super.onHitGround(h);
		if (fl_attack && isHealthy()) {
			attack();
			playAnim(Data.ANIM_BAD_SHOOT_END);
			halt();
		} else {
			game.shake(Data.SECOND * 0.2, 2);
		}
	}

	override public function onHitWall() {
		if (!isHealthy())
			game.shake(5, 3);
		super.onHitWall();
	}

	override public function onEndAnim(id:Int) {
		super.onEndAnim(id);
		if (id == Data.ANIM_BAD_SHOOT_END.id)
			walk();
	}

	override public function prefix() {
		if (isReady()) {
			if (fl_playerClose && Cs.rnd(1000) <= CHANCE_DASH * 2)
				startAttack();
			if (!fl_playerClose && Cs.rnd(1000) <= CHANCE_DASH)
				startAttack();
		}
		super.prefix();
	}
}

// hammer/entity/bad/WallWalker.mt: walks along the walls and the ceilings
class WallWalker extends Bad {
	static inline var SUB_RECAL = 0.2;

	public var fl_wallWalk:Bool;
	public var fl_intercept:Bool;
	public var fl_lost:Bool;

	var cp:{x:Int, y:Int}; // check-point (relative coords)
	var speed:Float;
	var xSpeed:Float;
	var ySpeed:Float;
	var xSub:Float;
	var ySub:Float;
	var xSubBase:Float;
	var ySubBase:Float;
	var subOffset:Float;
	var lastSafe:{x:Float, y:Float, xSpeed:Float, ySpeed:Float, cp:{x:Int, y:Int}};

	// the sub clip of the original (moved, scaled, turned by the code): holder of the picture
	var subMc:ASprite;
	var subX:Float;
	var subY:Float;

	public function new(animBase:String, subPos:Array<Float>) {
		super(animBase);
		speed = 3;
		xSpeed = 0;
		ySpeed = 0;
		angerFactor = 0.4;
		subOffset = 8;
		fl_intercept = false;
		fl_lost = false;
		fl_wallWalk = false;
		fl_largeTrigger = true;
		cp = {x: 0, y: 1};
		lastSafe = null;
		// sub clip: the picture is drawn in root coordinates, shifted so that the sub moves / scales around its origin
		subX = subPos[0];
		subY = subPos[1];
		mc.removeChild(pic);
		subMc = new ASprite();
		subMc._x = subX;
		subMc._y = subY;
		pic._x = -subX;
		pic._y = -subY;
		subMc.addChild(pic);
		mc.addChild(subMc);
		// (the original computes the offset of its sub before initBad sets these: _x = NaN, ignored by Flash)
		xSub = xSubBase = subX;
		ySub = ySubBase = subY;
	}

	override public function initBad(g:Game, x:Float, y:Float) {
		super.initBad(g, x, y);
		xSub = subMc._x;
		ySub = subMc._y;
		xSubBase = xSub;
		ySubBase = ySub;
		wallWalk();
	}

	public function wallWalk() {
		if (!isHealthy() || !isReady())
			return;
		fl_wallWalk = true;
		fl_gravity = false;
		fl_friction = false;
		fl_hitWall = false;
		fl_hitGround = false;
		fl_hitBorder = false;
		var choices = [
			{x: 1, y: 0, cpx: 0, cpy: 1},
			{x: -1, y: 0, cpx: 0, cpy: 1},
			{x: 1, y: 0, cpx: 0, cpy: -1},
			{x: -1, y: 0, cpx: 0, cpy: -1},
			{x: 0, y: 1, cpx: 1, cpy: 0},
			{x: 0, y: -1, cpx: 1, cpy: 0},
			{x: 0, y: 1, cpx: -1, cpy: 0},
			{x: 0, y: -1, cpx: -1, cpy: 0},
		];
		choices = [
			for (ch in choices)
				if (!(world.getCase(cx + ch.x, cy + ch.y) > 0 || world.getCase(cx + ch.cpx, cy + ch.cpy) <= 0)) ch
		];
		if (choices.length > 0) {
			var choice = choices[Cs.rnd(choices.length)];
			setDir(choice.x, choice.y);
			setCP(choice.cpx, choice.cpy);
			playAnim(Data.ANIM_BAD_WALK);
		} else {
			suicide();
		}
		fl_softRecal = false;
	}

	public function land() {
		fl_wallWalk = false;
		fl_gravity = true;
		fl_friction = true;
		fl_hitWall = true;
		fl_hitGround = true;
		fl_hitBorder = true;
	}

	function setDir(xoff:Int, yoff:Int) {
		xSpeed = speed * xoff;
		ySpeed = speed * yoff;
		updateSpeed();
		x = Entity.x_ctr(cx);
		y = Entity.y_ctr(cy);
		activateSoftRecal();
		setNext(dx, dy, 0, Data.ACTION_MOVE);
	}

	function setCP(xoff:Int, yoff:Int) {
		cp = {x: xoff, y: yoff};
	}

	override public function updateSpeed() {
		super.updateSpeed();
		if (fl_wallWalk && isReady()) {
			dx = xSpeed * speedFactor;
			dy = ySpeed * speedFactor;
		}
	}

	override public function infix() {
		super.infix();
		if (fl_wallWalk)
			wallWalkIA();
	}

	static inline function sgn(v:Float):Int {
		return v == 0 ? 0 : (v > 0 ? 1 : -1);
	}

	function wallWalkIA() {
		if (deathTimer > 0)
			return;
		var dirX = sgn(dx);
		var dirY = sgn(dy);
		// top of the level
		if (cy == 0) {
			if (dy < 0) {
				setDir(-cp.x, 0);
				setCP(0, -1);
			} else {
				if (world.getCase(cx + dirX, cy) > 0) {
					setDir(0, 1);
					setCP(dirX, 0);
				}
			}
		} else {
			// convex corners
			if (world.getCase(cx + cp.x, cy + cp.y) <= 0) {
				setDir(cp.x, cp.y);
				setCP(-dirX, -dirY);
			} else {
				// concave corners
				if (world.getCase(cx + dirX, cy + dirY) > 0) {
					setDir(-cp.x, -cp.y);
					setCP(dirX, dirY);
				}
			}
		}
		// dead ends
		var fl_deadEnd = true;
		var tries = 0;
		while (fl_deadEnd && tries < 4) {
			dirX = sgn(dx);
			dirY = sgn(dy);
			if (world.getCase(cx + dirX, cy + dirY) > 0 && world.getCase(cx + cp.x, cy + cp.y) > 0) {
				setDir(-cp.x, -cp.y);
				setCP(dirX, dirY);
			} else {
				fl_deadEnd = false;
			}
			tries++;
		}
		if (fl_deadEnd && !(deathTimer > 0))
			suicide();
	}

	override public function killHit(dx:Null<Float>) {
		super.killHit(dx);
		land();
		fl_hitGround = false;
		fl_hitWall = false;
	}

	function suicide() {
		if (deathTimer > 0)
			return;
		dx = 0;
		dy = 0;
		land();
		fl_lost = true;
		deathTimer = Data.SECOND * 3;
	}

	function moveToSafePos() {
		if (lastSafe != null && (x != lastSafe.x || y != lastSafe.y)) {
			x = lastSafe.x;
			y = lastSafe.y;
			cp = lastSafe.cp;
			xSpeed = lastSafe.xSpeed;
			ySpeed = lastSafe.ySpeed;
			updateCoords();
		}
	}

	override public function isReady():Bool {
		return isHealthy() && !fl_lost;
	}

	override public function onFreeze() {
		super.onFreeze();
		if (fl_wallWalk)
			fl_intercept = true;
		land();
	}

	override public function onKnock() {
		super.onKnock();
		land();
	}

	override public function onMelt() {
		super.onMelt();
		wallWalk();
	}

	override public function onWakeUp() {
		super.onWakeUp();
		wallWalk();
	}

	override public function onHitWall() {
		if (!fl_wallWalk) {
			if (world.getCase(cx, cy) != Data.WALL)
				dx = -dx;
		}
	}

	override public function onHitGround(h:Float) {
		super.onHitGround(h);
		fl_intercept = false;
		if (fl_lost) {
			fl_lost = false;
			deathTimer = 0;
			wallWalk();
		}
	}

	override public function endUpdate() {
		super.endUpdate();
		if (isHealthy()) {
			// off center (against the wall)
			xSub = xSubBase + cp.x * subOffset;
			ySub = ySubBase + cp.y * subOffset;
			if (cp.y > 0)
				ySub = ySubBase + subOffset * 0.5;
		} else {
			xSub = xSubBase;
			ySub = fl_freeze ? ySubBase : ySubBase + subOffset * 0.5;
		}
		subMc._x += SUB_RECAL * (xSub - subMc._x) * speedFactor;
		subMc._y += SUB_RECAL * (ySub - subMc._y) * speedFactor;
	}

	override public function update() {
		// auto radius
		var p = game.getOne(Data.PLAYER);
		realRadius = (p != null && p.y > y) ? Data.CASE_WIDTH * 1.4 : Data.CASE_WIDTH;
		super.update();
		// fixing point lost
		if (lastSafe != null
			&& world.getCase(Entity.x_rtc(lastSafe.x) + lastSafe.cp.x, Entity.y_rtc(lastSafe.y) + lastSafe.cp.y) <= 0) {
			lastSafe = null;
			fl_gravity = true;
			fl_wallWalk = false;
			fl_hitGround = true;
			fl_friction = true;
			fl_lost = true;
		}
		// safe position
		if (world.getCase(cx + cp.x, cy + cp.y) > 0) {
			lastSafe = {
				x: x,
				y: y,
				xSpeed: xSpeed,
				ySpeed: ySpeed,
				cp: {x: cp.x, y: cp.y}
			};
		}
	}
}

// hammer/entity/bad/ww/Saw.mt: an immortal saw running along the walls (a bomb only stops it a moment)
class Saw extends WallWalker {
	static inline var ROTATION_RECAL = 0.3;
	static inline var STUN_DURATION = Data.SECOND * 3;
	static inline var BASE_SPEED = 3;
	static inline var ROTATION_SPEED = 10;

	var fl_stun:Bool;
	var stunTimer:Float;
	var rotSpeed:Float;
	var blade:Pic;
	var bladeHolder:ASprite;

	public function new() {
		super("cerise", Art.SAW_SUB);
		// the body of the saw and its blade turned by the code (sub, sub.sub)
		subMc.removeChild(pic);
		bladeHolder = new ASprite();
		blade = new Pic("sawBlade");
		bladeHolder.addChild(blade);
		subMc.addChild(bladeHolder);
		// (its shine and its bolts play by themselves: 2 pictures)
		var body = new Pic("sawShine");
		subMc.addChild(body);
		shine = body;
		pic.setAnim("sawBody");
		speed = BASE_SPEED;
		angerFactor = 0;
		subOffset = 2;
		rotSpeed = 0;
		fl_stun = false;
		stunTimer = 0;
	}

	override public function animName(id:Int):String {
		return "sawBody";
	}

	override public function playAnim(o:AnimDef) {}

	override public function init(g:Game) {
		super.init(g);
		unregister(Data.BAD_CLEAR);
	}

	override public function initBad(g:Game, x:Float, y:Float) {
		super.initBad(g, x, y);
		scale(80);
	}

	function stun() {
		game.fxMan.attachExplosion(x, y - Data.CASE_HEIGHT * 0.5, 30);
		if (!fl_stun) {
			game.fxMan.inGameParticlesDir(Data.PARTICLE_METAL, x, y, 5, dx);
			game.fxMan.inGameParticlesDir(Data.PARTICLE_STONE, x, y, Cs.vrnd(4), dx);
		}
		fl_stun = true;
		fl_wallWalk = false;
		stunTimer = STUN_DURATION;
		dx = 0;
		dy = 0;
	}

	override public function isHealthy():Bool {
		return !fl_kill && !fl_stun;
	}

	override public function hit(e:Entity) {
		if (isHealthy() && e.isType(Data.PLAYER))
			game.fxMan.inGameParticles(Data.PARTICLE_CLASSIC_BOMB, x, y, Cs.vrnd(5) + 3);
		super.hit(e);
		if (isHealthy()) {
			if (e.isType(Data.BOMB) && !e.isType(Data.BAD_BOMB)) {
				var b:Bomb = cast e;
				b.setLifeTimer(Data.SECOND * 0.6);
				b.dx = (dx != 0) ? -dx : -cp.x * 4;
				b.dy = (cp.y != 0) ? -cp.y * 13 : -8;
				game.fxMan.inGameParticlesDir(Data.PARTICLE_SPARK, b.x, b.y, 2, b.dx);
			}
		}
	}

	override public function land() {}

	override public function killHit(dx:Null<Float>) {
		stun();
	}

	override public function knock(d:Float) {
		stun();
	}

	override public function freeze(d:Float) {
		stun();
	}

	override public function onWakeUp() {
		fl_wallWalk = true;
		moveToSafePos();
		updateSpeed();
		game.fxMan.inGameParticles(Data.PARTICLE_STONE, x, y, 3);
	}

	override public function endUpdate() {
		super.endUpdate();
		if (fl_stun) {
			var f = 1 - stunTimer / STUN_DURATION;
			mc._x = x + f * (Cs.vrnd(20) / 10) * (Cs.vrnd(2) * 2 - 1);
			mc._y = y + f * (Cs.vrnd(20) / 10) * (Cs.vrnd(2) * 2 - 1);
		}
		if (fl_wallWalk) {
			var angDeg = 180 * Math.atan2(cp.y, cp.x) / Math.PI - 90;
			var delta = angDeg - subMc._rotation;
			if (delta < -180)
				delta += 360;
			if (delta > 180)
				delta -= 360;
			subMc._rotation += delta * ROTATION_RECAL;
		} else if (isHealthy()) {
			subMc._rotation += (0 - subMc._rotation) * (ROTATION_RECAL * 0.25);
		}
		if (fl_stun)
			rotSpeed *= 0.9;
		else
			rotSpeed = Math.min(ROTATION_SPEED, rotSpeed + Game.tmod);
		bladeHolder._rotation += rotSpeed;
		shine.show(shine.cur % shine.count() + 1);
	}

	var shine:Pic;

	override public function update() {
		if (fl_stun) {
			dx = 0;
			dy = 0;
			if (Cs.vrnd(10) == 0)
				game.fxMan.inGameParticles(Data.PARTICLE_SPARK, x, y, 1);
			stunTimer -= Game.tmod;
			if (stunTimer <= 0) {
				fl_stun = false;
				onWakeUp();
			}
		}
		super.update();
	}
}

// hammer/entity/bad/ww/Crawler.mt: a blob crawling on the walls, spitting fireballs
class Crawler extends WallWalker {
	static inline var SCALE_RECAL = 0.2;
	static inline var CRAWL_STRETCH = 1.8;
	static inline var COLOR = 0xFF9146;
	static inline var COLOR_ALPHA = 40;
	static inline var SHOOT_SPEED = 6;
	static inline var CHANCE_ATTACK = 10;
	static inline var COOLDOWN = Data.SECOND * 2;
	static inline var ATTACK_TIMER = Data.SECOND * 0.5;

	var fl_attack:Bool;
	var attackCD:Float;
	var attackTimer:Float;
	var colorAlpha:Float;
	var xscale:Float;
	var yscale:Float;
	var blobCpt:Float;

	public function new() {
		super("crawler", Art.CRAWLER_SUB);
		speed = 2;
		angerFactor = 0.5;
		fl_attack = false;
		attackCD = Data.PEACE_COOLDOWN;
		attackTimer = 0;
		colorAlpha = 0;
		blobCpt = 0;
	}

	override public function initBad(g:Game, x:Float, y:Float) {
		super.initBad(g, x, y);
		scale(90);
	}

	override public function killHit(dx:Null<Float>) {
		super.killHit(dx);
		fl_attack = false;
	}

	override public function isReady():Bool {
		return super.isReady() && !fl_attack;
	}

	function prepareAttack() {
		dx = 0;
		dy = 0;
		fl_attack = true;
		fl_wallWalk = false;
		attackTimer = ATTACK_TIMER;
		playAnim(Data.ANIM_BAD_SHOOT_START);
	}

	function attack() {
		var s = Shoot.BadFireBall.attach(game, x, y);
		s.moveTo(x, y);
		s.dx = -cp.x * SHOOT_SPEED;
		s.dy = -cp.y * SHOOT_SPEED;
		s.scale(70);
		var n = Cs.vrnd(3) + 2;
		if (cp.x != 0)
			game.fxMan.inGameParticlesDir(Data.PARTICLE_BLOB, x, y, n, -cp.x);
		else
			game.fxMan.inGameParticles(Data.PARTICLE_BLOB, x, y, n);
		game.fxMan.attachExplosion(x, y, 20);
		subMc._xscale = 150 + Math.abs(cp.x) * 150;
		subMc._yscale = 150 + Math.abs(cp.y) * 150;
		colorAlpha = COLOR_ALPHA;
		setColorHex(Math.round(colorAlpha), COLOR);
		attackCD = COOLDOWN;
		playAnim(Data.ANIM_BAD_SHOOT_END);
	}

	function decideAttack():Bool {
		if (fl_attack || player == null)
			return false;
		var fl_inSight = false;
		var factor = 1.0;
		if (cp.y != 0 && Math.abs(player.x - x) <= Data.CASE_WIDTH * 2) {
			if (cp.y > 0 && player.y < y)
				fl_inSight = true;
			if (cp.y < 0 && player.y > y)
				fl_inSight = true;
		}
		if (cp.x != 0 && Math.abs(player.y - y) <= Data.CASE_HEIGHT * 2) {
			if (cp.x > 0 && player.x < x)
				fl_inSight = true;
			if (cp.x < 0 && player.x > x)
				fl_inSight = true;
		}
		if (fl_inSight) {
			attackCD -= Game.tmod * 4;
			factor = 8;
		}
		return isReady() && isHealthy() && attackCD <= 0 && Cs.rnd(1000) < CHANCE_ATTACK * factor;
	}

	override public function onEndAnim(id:Int) {
		super.onEndAnim(id);
		if (id == Data.ANIM_BAD_SHOOT_END.id) {
			fl_attack = false;
			fl_wallWalk = true;
			moveToSafePos();
			updateSpeed();
			if (dx == 0 && dy == 0)
				wallWalk();
		}
	}

	override public function onFreeze() {
		super.onFreeze();
		fl_attack = false;
	}

	override public function onKnock() {
		super.onKnock();
		fl_attack = false;
	}

	override public function onHitGround(h:Float) {
		super.onHitGround(h);
		if (Math.abs(h) >= Data.CASE_HEIGHT * 3) {
			subMc._xscale = 2 * 100 * scaleFactor;
			subMc._yscale = 0.2 * 100 * scaleFactor;
			subMc._y = ySubBase + 10;
			if (!fl_freeze)
				game.fxMan.inGameParticles(Data.PARTICLE_BLOB, x, y, Cs.vrnd(3) + 2);
		}
	}

	override public function endUpdate() {
		super.endUpdate();
		if (fl_attack) {
			mc._x += Cs.vrnd(15) / 10 * (Cs.vrnd(2) * 2 - 1);
			mc._y += Cs.vrnd(15) / 10 * (Cs.vrnd(2) * 2 - 1);
			xscale = scaleFactor * 100 + Cs.vrnd(20) * (Cs.vrnd(2) * 2 - 1);
			yscale = scaleFactor * 100 + Cs.vrnd(20) * (Cs.vrnd(2) * 2 - 1);
		} else {
			xscale = scaleFactor * 100;
			yscale = scaleFactor * 100;
		}
		if (fl_wallWalk) {
			if (dx != 0)
				xscale = 100 * scaleFactor * CRAWL_STRETCH;
			if (dy != 0)
				yscale = 100 * scaleFactor * CRAWL_STRETCH;
		}
		if (isHealthy()) {
			xscale += 10 * Math.sin(blobCpt);
			yscale += 10 * Math.cos(blobCpt);
			blobCpt += Game.tmod * 0.1;
		}
		subMc._xscale += SCALE_RECAL * (xscale - subMc._xscale);
		subMc._yscale += SCALE_RECAL * (yscale - subMc._yscale);
		if (colorAlpha > 0) {
			colorAlpha -= Game.tmod * 3;
			if (colorAlpha <= 0)
				resetColor();
			else
				setColorHex(Math.round(colorAlpha), COLOR);
		}
	}

	override public function update() {
		if (fl_attack) {
			dx = 0;
			dy = 0;
		}
		super.update();
		if (attackCD > 0)
			attackCD -= Game.tmod;
		if (decideAttack()) {
			if (world.getCase(cx + cp.x, cy + cp.y) > 0)
				prepareAttack();
		}
		if (fl_attack && attackTimer > 0) {
			attackTimer -= Game.tmod;
			if (attackTimer <= 0)
				attack();
		}
	}
}
