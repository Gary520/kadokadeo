package hammerfest;

import hammerfest.Data.AnimDef;

// hammer/entity/Bad.mt: an enemy (fruit)
class Bad extends Mover {
	public var player:Player;
	public var fl_playerClose:Bool;
	public var closeDistance:Float;

	public var freezeTimer:Float;
	public var freezeTotal:Float;
	public var fl_freeze:Bool;

	public var knockTimer:Float;
	public var fl_knock:Bool;

	public var deathTimer:Float;

	public var fl_trap:Bool;
	public var comboId:Null<Int>;
	public var yTrigger:Null<Float>;
	public var anger:Int;
	public var angerFactor:Float;
	public var speedFactor:Float;

	public var chaseFactor:Float;
	public var maxAnger:Int;

	public var realRadius:Null<Float>; // additional check of the contact with the player

	public var iceMc:Pic;

	public function new(animBase:String) {
		super(animBase);
		comboId = null;
		freezeTimer = 0;
		freezeTotal = 0;
		fl_freeze = false;
		knockTimer = 0;
		fl_knock = false;
		deathTimer = 0;
		yTrigger = null;
		fl_trap = true;
		fl_strictGravity = false;
		fl_largeTrigger = true;
		fl_playerClose = false;
		closeDistance = Data.IA_CLOSE_DISTANCE;
		realRadius = Data.CASE_WIDTH;
		maxAnger = Data.MAX_ANGER;
		speedFactor = 1.0;
		anger = 0;
		angerFactor = 0.7; // added to the speed for each point of anger
		chaseFactor = 5.0; // factor of the chances of decisions to follow the player
	}

	override public function init(g:Game) {
		super.init(g);
		register(Data.BAD);
		register(Data.BAD_CLEAR);
		calcSpeed();
	}

	public function initBad(g:Game, x:Float, y:Float) {
		init(g);
		moveTo(x + Data.CASE_WIDTH * 0.5, y + Data.CASE_HEIGHT); // on the ground
		endUpdate();
	}

	override public function killHit(dx:Null<Float>) {
		if (fl_freeze) {
			game.fxMan.inGameParticles(Data.PARTICLE_ICE, x, y, Cs.vrnd(3) + 2);
			game.fxMan.attachExplosion(x, y - Data.CASE_HEIGHT * 0.5, Data.CASE_WIDTH * 2);
			melt();
		}
		if (fl_knock)
			wakeUp();
		if (dx == null)
			dx = Cs.rnd(200) / 10 * (Cs.rnd(2) * 2 - 1);
		playAnim(Data.ANIM_BAD_DIE);
		super.killHit(dx);
	}

	public function forceKill(dx:Null<Float>) {
		killHit(dx);
	}

	// death on the spot
	public function burn() {
		game.fxMan.attachFx(x, y, "fxBurning");
		dropReward();
		onKill();
		destroy();
	}

	public function isHealthy():Bool {
		return !fl_kill && !fl_freeze && !fl_knock;
	}

	override public function hit(e:Entity) {
		// player
		if ((e.types & Data.PLAYER) > 0) {
			var et:Player = cast e;
			var fl_hit = true;
			if (realRadius != null) {
				if (distance(et.x, et.y) > realRadius)
					fl_hit = false;
			}
			if (fl_hit) {
				if (isHealthy()) {
					if (!et.fl_shield) {
						if (et.x < x)
							et.killHit(-1);
						else
							et.killHit(1);
					}
				}
			}
		}

		// bads: a frozen bad thrown on another one
		if ((e.types & Data.BAD) > 0) {
			var et:Bad = cast e;
			if (fl_freeze && et.fl_freeze == false) {
				var spd = evaluateSpeed();
				if (spd >= Data.ICE_HIT_MIN_SPEED) {
					et.setCombo(comboId);
					et.killHit(dx);
				} else {
					if (spd >= Data.ICE_KNOCK_MIN_SPEED) {
						et.setCombo(comboId);
						et.knock(Data.KNOCK_DURATION);
					}
				}
			}
		}
	}

	public function setCombo(id:Null<Int>) {
		if (!fl_kill)
			comboId = id;
	}

	override public function playAnim(o:AnimDef) {
		if (o.id == Data.ANIM_BAD_WALK.id && anger > 0)
			super.playAnim(Data.ANIM_BAD_ANGER);
		else
			super.playAnim(o);
	}

	public function calcSpeed() {
		speedFactor = 1.0 + angerFactor * anger;
		if (game != null && game.globalActives[69])
			speedFactor *= 0.6; // turtle
		if (game != null && game.globalActives[80])
			speedFactor *= 0.3; // snail
	}

	public function updateSpeed() {
		calcSpeed();
	}

	// a crystal (combo) or a diamond where the bad died
	public function dropReward() {
		var itY = world.inBound(cx, cy) ? y : -30;
		if (comboId != null) {
			var n = game.countCombo(comboId) - 1;
			if (n + 1 > game.statsMan.read(Data.STAT_MAX_COMBO))
				game.statsMan.write(Data.STAT_MAX_COMBO, n + 1);
			Item.ScoreItem.attach(game, x, itY, 0, n);
		} else {
			Item.ScoreItem.attach(game, x, itY, Data.DIAMANT, null);
		}
	}

	public function evaluateSpeed():Float {
		return Math.sqrt(dx * dx + dy * dy);
	}

	override public function destroy() {
		super.destroy();
		removeIce();
	}

	function removeIce() {
		if (iceMc != null) {
			if (iceMc.parent != null)
				iceMc.parent.removeChild(iceMc);
			iceMc.destroy();
			iceMc = null;
		}
	}

	override public function needsPatch():Bool {
		return fl_freeze || fl_knock;
	}

	// EVENTS
	override public function onDeathLine() {
		var fx = game.fxMan.attachFx(x, Data.GAME_HEIGHT * 0.5, "fxDeath");
		if (fx != null) // (thinner in the small field)
			fx.mc._xscale = 55;
		game.shake(10, 3);
		Snd.play("sound_bad_death", Snd.CHAN_BAD);
		deathTimer = 0;
		super.onDeathLine();
		if (!fl_kill)
			onKill();
		dropReward();
		destroy();
	}

	public function onMelt() {
		removeIce();
	}

	public function onWakeUp() {}

	public function onFreeze() {
		playAnim(Data.ANIM_BAD_FREEZE);
		if (iceMc == null) {
			iceMc = new Pic("badIce");
			iceMc._x = mc._x;
			iceMc._y = mc._y;
			iceMc._xscale = 0.85 * scaleFactor * 100;
			iceMc._yscale = 0.85 * scaleFactor * 100;
			iceMc.updateState();
			game.dm.add(iceMc, Data.DP_BADS);
		}
	}

	public function onKnock() {
		playAnim(Data.ANIM_BAD_KNOCK);
	}

	public function onHurryUp() {
		angerMore();
	}

	override public function onKill() {
		super.onKill();
		deathTimer = Data.SECOND * 5;
		game.onKillBad(this);
	}

	override public function onHitGround(h:Float) {
		super.onHitGround(h);
		if (fl_freeze) {
			game.fxMan.inGameParticles(Data.PARTICLE_ICE_BAD, x, y, Cs.vrnd(3) + 2);
			if (h >= Data.DUST_FALL_HEIGHT)
				game.fxMan.dust(cx, cy + 1);
		}
	}

	// CHANGES OF STATE
	public function freeze(timer:Float) {
		if (fl_kill)
			return;
		if (fl_knock)
			wakeUp();
		fallFactor = Data.FALL_FACTOR_FROZEN;
		fl_slide = true;
		freezeTimer = timer;
		freezeTotal = timer;
		fl_freeze = true;
		onFreeze();
	}

	public function knock(timer:Float) {
		if (fl_freeze)
			melt();
		fallFactor = Data.FALL_FACTOR_KNOCK;
		knockTimer = timer;
		fl_knock = true;
		game.statsMan.inc(Data.STAT_KNOCK, 1);
		onKnock();
	}

	public function melt() {
		next = null;
		angerMore();
		freezeTimer = 0;
		fl_freeze = false;
		fl_slide = false;
		fallFactor = 1.0;
		onMelt();
	}

	public function wakeUp() {
		next = null;
		knockTimer = 0;
		fl_knock = false;
		fallFactor = 1.0;
		onWakeUp();
	}

	public function calmDown() {
		if (fl_kill)
			return;
		anger = 0;
		updateSpeed();
	}

	public function angerMore() {
		anger = Math.round(Math.min(anger + 1, maxAnger));
		updateSpeed();
	}

	public function hate(p:Player) {
		player = p;
	}

	override public function endUpdate() {
		var ox = mc._x;
		var oy = mc._y;
		if (fl_softRecal)
			softRecalFactor += 0.1 * Game.tmod * speedFactor;
		super.endUpdate();

		// ice pieces behind a frozen bad sliding fast
		var minSpeed = 2;
		if (fl_freeze && fl_stable && Math.abs(dx) > minSpeed)
			game.fxMan.iceTrail(ox, oy, (Math.abs(dx) - minSpeed) / 5 * 100);

		if (iceMc != null) {
			iceMc._x = mc._x;
			iceMc._y = mc._y;
			iceMc._xscale = 0.85 * scaleFactor * 100;
			iceMc._yscale = 0.85 * scaleFactor * freezeTimer / freezeTotal * 100;
		}
		if (!fl_stable && isHealthy() && (animId == null || animId == Data.ANIM_BAD_WALK.id || animId == Data.ANIM_BAD_ANGER.id))
			playAnim(Data.ANIM_BAD_JUMP);
	}

	override public function update() {
		if (player == null || player.fl_destroy)
			hate(cast game.getOne(Data.PLAYER));

		fl_playerClose = player != null && isHealthy() && (distance(player.x, player.y) <= closeDistance * (anger + 1));

		// frozen
		if (freezeTimer > 0) {
			freezeTimer -= Game.tmod;
			if (freezeTimer <= 0)
				melt();
		}

		// forced death (lost bad)
		if (deathTimer > 0) {
			deathTimer -= Game.tmod;
			if (deathTimer <= 0) {
				game.fxMan.attachExplosion(x, y, 80);
				y = 1000;
			}
		}

		// knocked
		if (knockTimer > 0) {
			knockTimer -= Game.tmod;
			if (knockTimer <= 0)
				wakeUp();
		}

		super.update();

		// ground contact back
		if (yTrigger != null && !fl_kill) {
			if (y >= yTrigger) {
				fl_hitGround = true;
				yTrigger = null;
			}
		}

		// no more combo once healthy again
		if (comboId != null) {
			if (isHealthy())
				setCombo(null);
		}
	}
}

// hammer/entity/bad/Walker.mt
class Walker extends Bad {
	public var speed:Float;
	public var dir:Int;

	public var fl_fall:Bool;
	public var fl_willFallDown:Bool;
	public var chanceFall:Float;

	public var recentParticles:Float;

	public function new(animBase:String) {
		super(animBase);
		setFall(null);
		speed = 2;
		dir = 1;
		fl_willFallDown = false;
		recentParticles = 0;
	}

	override public function init(g:Game) {
		super.init(g);
		dir = Cs.rnd(2) * 2 - 1;
	}

	public function halt() {
		if (!fl_freeze && !fl_knock)
			dx = 0;
		dy = 0;
	}

	public function walk() {
		var base = speedFactor * speed * game.speedFactor;
		if (!isReady())
			return;
		if (dir == -1)
			base = -base;
		if (fl_stable)
			playAnim(Data.ANIM_BAD_WALK);
		setNext(base, 0, 0, Data.ACTION_MOVE);
	}

	public function fallBack() {
		dx = -dx;
		if (!fl_freeze && !fl_knock)
			dir = -dir;
	}

	override public function infix() {
		if (fl_stable && world.checkFlag(cx, cy, Data.IA_FALL_SPOT)) {
			onFall();
			fl_stopStepping = true;
			return;
		}
		super.infix();
	}

	override public function postfix() {
		super.postfix();
		fl_friction = !isReady();
	}

	override public function isReady():Bool {
		return super.isReady() && isHealthy();
	}

	public function setFall(chance:Null<Float>) {
		if (chance == null) {
			fl_fall = false;
		} else {
			fl_fall = true;
			chanceFall = chance * 10;
		}
	}

	override public function calmDown() {
		super.calmDown();
		if (animId == Data.ANIM_BAD_ANGER.id)
			playAnim(Data.ANIM_BAD_WALK);
		if (isReady()) {
			halt();
			walk();
		}
	}

	override public function angerMore() {
		super.angerMore();
		if (isReady()) {
			halt();
			walk();
		}
	}

	override public function updateSpeed() {
		super.updateSpeed();
		walk();
	}

	public function decideFall():Bool {
		var d = player.cy - cy;
		var fall = world.fallAt(cx, cy);
		var fl_good = fall > 0 && d > 0 && fall <= d + 3;
		if (fl_playerClose)
			return fl_good;
		else
			return Cs.rnd(1000) < chanceFall;
	}

	override public function onNext() {
		if (next.action == Data.ACTION_WALK) {
			next = null;
			walk();
		}
		if (next != null && next.action == Data.ACTION_FALLBACK) {
			next = null;
			walk();
			if (next != null)
				next.dx = -next.dx;
		}
		if (next != null && next.action == Data.ACTION_MOVE && next.dy == 0)
			playAnim(Data.ANIM_BAD_WALK);
		if (next != null)
			super.onNext();
	}

	override public function onHitWall() {
		if (!fl_stopStepping) {
			if (world.getCase(cx, cy) != Data.WALL) {
				if (!isHealthy() || fl_stable)
					fallBack();
			}
		}
		if (fl_freeze && Math.abs(dx) >= 4) {
			if (recentParticles <= 0) {
				game.shake(Data.SECOND * 0.2, 2);
				game.fxMan.inGameParticles(Data.PARTICLE_ICE_BAD, x, y, Cs.vrnd(4) + 1);
				recentParticles = 10;
			}
			if (fl_stable)
				game.fxMan.dust(cx, cy + 1);
		}
	}

	override public function onHitGround(h:Float) {
		super.onHitGround(h);
		halt();
		walk();
	}

	// about to fall
	public function onFall() {
		if (!isReady())
			return;

		// does not stay on a small spot if it can fall
		if (world.checkFlag(Entity.x_rtc(oldX), Entity.y_rtc(oldY), Data.IA_SMALL_SPOT) && world.checkFlag(cx, cy, Data.IA_ALLOW_FALL)) {
			halt();
			return;
		}

		// falls (the Jumper may have set the flag)
		if (fl_fall) {
			if (decideFall()) {
				if (world.checkFlag(cx, cy, Data.IA_ALLOW_FALL))
					fl_willFallDown = true;
			}
			if (fl_willFallDown) {
				fl_willFallDown = false;
				halt();
				return;
			}
		}

		x = oldX;
		y = oldY;
		fallBack();
	}

	override public function onFreeze() {
		super.onFreeze();
		next = null;
	}

	override public function onMelt() {
		super.onMelt();
		walk();
		if (!fl_stable)
			playAnim(Data.ANIM_BAD_JUMP);
	}

	override public function onKnock() {
		super.onKnock();
		next = null;
	}

	override public function onWakeUp() {
		super.onWakeUp();
		walk();
		if (!fl_stable)
			playAnim(Data.ANIM_BAD_JUMP);
	}

	override public function endUpdate() {
		super.endUpdate();
		// flip of the clip
		if (!fl_freeze && !fl_knock) {
			if (dx < 0)
				dir = -1;
			if (dx > 0)
				dir = 1;
			_xscale = dir * Math.abs(_xscale);
		}
	}

	override public function update() {
		fl_willFallDown = false;
		if (recentParticles > 0)
			recentParticles -= Game.tmod;
		super.update();
	}
}

// hammer/entity/bad/Jumper.mt
class Jumper extends Walker {
	public var jumpTimer:Float;

	public var fl_jUp:Bool;
	public var fl_jDown:Bool;
	public var fl_jH:Bool;
	public var fl_jumper:Bool;
	public var fl_climb:Bool;

	var chanceJumpH:Float;
	var chanceJumpUp:Float;
	var chanceJumpDown:Float;
	var chanceClimb:Float;

	public var maxClimb:Int;

	public function new(animBase:String) {
		super(animBase);
		jumpTimer = 0;
		fl_jUp = false;
		fl_jDown = false;
		fl_jH = false;
		fl_climb = false;
		maxClimb = 0;
		setJumper();
	}

	public function setJumpUp(chance:Null<Float>) {
		if (chance == null) {
			fl_jUp = false;
		} else {
			fl_jUp = true;
			chanceJumpUp = chance * 10;
		}
		setJumper();
	}

	public function setJumpDown(chance:Null<Float>) {
		if (chance == null) {
			fl_jDown = false;
		} else {
			fl_jDown = true;
			chanceJumpDown = chance * 10;
		}
		setJumper();
	}

	public function setJumpH(chance:Null<Float>) {
		if (chance == null) {
			fl_jH = false;
		} else {
			fl_jH = true;
			chanceJumpH = chance * 10;
		}
		setJumper();
	}

	public function setClimb(chance:Null<Float>, max:Int) {
		if (chance == null) {
			fl_climb = false;
			maxClimb = 0;
		} else {
			fl_climb = true;
			maxClimb = max;
			chanceClimb = chance * 10;
		}
		setJumper();
	}

	public function setJumper() {
		fl_jumper = fl_jUp || fl_jDown || fl_jH;
	}

	// DECISIONS
	public function decideJumpUp():Bool {
		if (fl_playerClose)
			return player.cy < cy && Cs.rnd(1000) < chanceJumpUp * chaseFactor && isReady();
		else
			return Cs.rnd(1000) < chanceJumpUp && isReady();
	}

	public function decideJumpDown():Bool {
		if (fl_playerClose)
			return player.cy > cy && Cs.rnd(1000) < chanceJumpDown * chaseFactor && isReady();
		else
			return Cs.rnd(1000) < chanceJumpDown && isReady();
	}

	public function decideClimb():Bool {
		var d = Math.abs(player.cy - cy);
		var fl_good = d >= 3 || (d < 3 && ((player.cx < cx && dx < 0) || (player.cx > cx && dx > 0)));
		var fl_stairway = (world.checkFlag(cx, cy, Data.IA_CLIMB_LEFT) || world.checkFlag(cx, cy, Data.IA_CLIMB_RIGHT))
			&& world.checkFlag(cx, cy, Data.IA_SMALL_SPOT);
		if (fl_playerClose)
			return isReady() && (fl_stairway || (fl_good && Cs.rnd(1000) < chanceClimb * chaseFactor));
		else
			return isReady() && (fl_stairway || Cs.rnd(1000) < chanceClimb);
	}

	public function jump(dx:Float, dy:Float, delay:Float) {
		halt();
		setNext(dx, dy, delay, Data.ACTION_MOVE);
		if (delay > 0)
			playAnim(Data.ANIM_BAD_THINK);
	}

	public function checkClimb() {
		if (decideClimb()) {
			// left
			if (dx < 0 && world.checkFlag(cx, cy, Data.IA_CLIMB_LEFT)) {
				var h:Null<Int>;
				if (world.checkFlag(cx, cy, Data.IA_TILE_TOP))
					h = world.getWallHeight(cx - 1, cy, Data.IA_CLIMB);
				else
					h = world.getStepHeight(cx, cy, Data.IA_CLIMB);
				if (h != null && h <= maxClimb) {
					var wait = (h > 1) ? Data.SECOND : 0;
					if (world.checkFlag(cx, cy, Data.IA_TILE_TOP)) {
						jump(-Data.BAD_VJUMP_X_CLIFF, -Data.BAD_VJUMP_Y_LIST[h - 1], wait);
					} else {
						jump(-Data.BAD_VJUMP_X, -Data.BAD_VJUMP_Y_LIST[h - 1], wait);
						x = oldX;
					}
					fl_stopStepping = true;
				}
			}
			// right
			if (dx > 0 && world.checkFlag(cx, cy, Data.IA_CLIMB_RIGHT)) {
				var h:Null<Int>;
				if (world.checkFlag(cx, cy, Data.IA_TILE_TOP))
					h = world.getWallHeight(cx + 1, cy, Data.IA_CLIMB);
				else
					h = world.getStepHeight(cx, cy, Data.IA_CLIMB);
				if (h != null && h <= maxClimb) {
					var wait = (h > 1) ? Data.SECOND : 0;
					if (world.checkFlag(cx, cy, Data.IA_TILE_TOP)) {
						jump(Data.BAD_VJUMP_X_CLIFF, -Data.BAD_VJUMP_Y_LIST[h - 1], wait);
					} else {
						jump(Data.BAD_VJUMP_X, -Data.BAD_VJUMP_Y_LIST[h - 1], wait);
						x = oldX;
					}
					fl_stopStepping = true;
				}
			}
		}
	}

	override public function onNext() {
		if (next.action == Data.ACTION_MOVE && next.dy != 0)
			playAnim(Data.ANIM_BAD_JUMP);
		super.onNext();
	}

	override public function onFall() {
		if (fl_jumper) {
			if (isReady() && fl_jH) {
				// on the edge and decides to fall (no jump: the Walker lets itself fall)
				if (fl_fall && decideFall()) {
					if (world.checkFlag(cx, cy, Data.IA_ALLOW_FALL))
						fl_willFallDown = true;
				}
				// small step down
				if (fl_fall && fl_climb) {
					if (world.checkFlag(cx, cy + 1, Data.IA_CLIMB_LEFT) || world.checkFlag(cx, cy + 1, Data.IA_CLIMB_RIGHT))
						fl_willFallDown = true;
				}
				if (!fl_willFallDown) {
					// jump to the left
					if (dx < 0 && world.checkFlag(cx, cy, Data.IA_JUMP_LEFT)) {
						jump(-Data.BAD_HJUMP_X, -Data.BAD_HJUMP_Y, 0);
						adjustToRight();
					}
					// jump to the right
					if (dx > 0 && world.checkFlag(cx, cy, Data.IA_JUMP_RIGHT)) {
						jump(Data.BAD_HJUMP_X, -Data.BAD_HJUMP_Y, 0);
						adjustToLeft();
					}
					// climbing
					if (fl_climb)
						checkClimb();
				}
			}
		}
		super.onFall();
	}

	override public function onHitWall() {
		if (fl_climb)
			checkClimb();
		super.onHitWall();
	}

	override public function onFreeze() {
		super.onFreeze();
		fl_skipNextGround = false;
	}

	override public function onKnock() {
		super.onKnock();
		fl_skipNextGround = false;
	}

	override public function infix() {
		super.infix();
		// vertical jumps
		if (fl_jumper) {
			updateCoords();
			if (fl_jUp) {
				if (decideJumpUp()) {
					if (world.checkFlag(cx, cy, Data.IA_JUMP_UP)) {
						jump(0, -Data.BAD_VJUMP_Y, Data.SECOND);
						fl_stopStepping = true;
					}
				}
			}
			if (fl_jDown) {
				if (decideJumpDown()) {
					if (world.checkFlag(cx, cy, Data.IA_JUMP_DOWN)) {
						jump(0, -Data.BAD_VDJUMP_Y, Data.SECOND);
						fl_skipNextGround = true;
						fl_stopStepping = true;
					}
				}
			}
		}
	}
}

// hammer/entity/bad/Shooter.mt
class Shooter extends Jumper {
	public var fl_shooter:Bool;
	public var shootCD:Float;
	public var shootDuration:Float;
	public var shootPreparation:Float;
	public var chanceShoot:Float;

	public function new(animBase:String) {
		super(animBase);
		shootCD = Data.PEACE_COOLDOWN;
		fl_shooter = false;
		chanceShoot = 0;
		shootDuration = 0;
		shootPreparation = 0;
	}

	public function initShooter(prepa:Float, duration:Float) {
		shootPreparation = prepa;
		shootDuration = duration;
	}

	public function setShoot(chance:Null<Float>) {
		if (chance == null) {
			fl_shooter = false;
		} else {
			fl_shooter = true;
			chanceShoot = chance * 10;
		}
	}

	public function enableShooter() {
		fl_shooter = true;
	}

	public function disableShooter() {
		fl_shooter = false;
	}

	override public function onNext() {
		var action = next.action;
		super.onNext();
		if (action == Data.ACTION_SHOOT && next != null && next.action == Data.ACTION_SHOOT) {
			setNext(null, null, shootDuration, Data.ACTION_WALK);
			halt();
			playAnim(Data.ANIM_BAD_SHOOT_END);
			onShoot();
		}
	}

	public function startShoot() {
		setNext(dx, dy, shootPreparation, Data.ACTION_SHOOT);
		halt();
		playAnim(Data.ANIM_BAD_SHOOT_START);
	}

	override public function onEndAnim(id:Int) {
		super.onEndAnim(id);
		if (id == Data.ANIM_BAD_SHOOT_START.id)
			playAnim(Data.ANIM_BAD_SHOOT_LOOP);
	}

	public function onShoot() {}

	override public function update() {
		if (shootCD > 0)
			shootCD -= Game.tmod;
		if (fl_shooter && shootCD <= 0) {
			if (isReady() && Cs.rnd(1000) < chanceShoot)
				startShoot();
		}
		super.update();
	}
}
