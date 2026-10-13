package hammerfest;

import hammerfest.Data.AnimDef;

// hammer/entity/Player.mt: Igor
class Player extends Physics {
	public var ctrl:PlayerController;
	public var specialMan:SpecialManager;

	public var baseWalkAnim:AnimDef;
	public var baseStopAnim:AnimDef;

	public var speedFactor:Float;
	public var fl_lockControls:Bool;
	public var fl_entering:Bool;

	public var score:Int;

	public var currentWeapon:Int;
	public var maxBombs:Int;
	public var initialMaxBombs:Int;
	public var dir:Int;
	public var coolDown:Float;
	public var lastBomb:Int;

	public var lives:Int;
	public var fl_shield:Bool;
	public var shieldTimer:Float;

	public var fl_knock:Bool;
	public var knockTimer:Float;

	public var extendList:Array<Bool>;
	public var extendOrder:Array<Int>;

	public var pid:Int;
	public var shieldMC:Animation;

	public var startX:Float;
	public var extraLifeCurrent:Int;

	public var edgeTimer:Float;
	public var waitTimer:Float;

	public var lockTimer:Float;
	public var recentKicks:Array<{t:Float, bid:Int}>;

	public function new() {
		super("player");
		baseWalkAnim = Data.ANIM_PLAYER_WALK;
		baseStopAnim = Data.ANIM_PLAYER_STOP;
		score = 0;
		dir = 1;
		speedFactor = 1.0;
		fallFactor = 1.1;
		extraLifeCurrent = 0;
		fl_teleport = true;
		fl_portal = true;
		fl_wind = true;
		fl_strictGravity = false;
		fl_bump = true;
		fl_knock = false;
		knockTimer = 0;
		lockTimer = 0;
		recentKicks = [];
		currentWeapon = Data.WEAPON_B_CLASSIC;
		lastBomb = 1;
		// 2 bombs at once (the quest "multi-bombe 2" of the original: family 100)
		initialMaxBombs = 2;
		maxBombs = initialMaxBombs;
		coolDown = 0;
		lives = 1;
		fl_shield = false;
		shieldTimer = 0;
		fl_lockControls = false;
		fl_entering = false;
		extendList = [];
		extendOrder = [];
		pid = 0;
		edgeTimer = 0;
		waitTimer = 0;
	}

	override public function init(g:Game) {
		super.init(g);
		ctrl = new PlayerController(this);
		register(Data.PLAYER);
		specialMan = new SpecialManager(game, this);
	}

	public function initPlayer(g:Game, x:Float, y:Float) {
		init(g);
		moveTo(x, y);
		endUpdate();
	}

	public static function attach(g:Game, x:Float, y:Float):Player {
		var p = new Player();
		p.attachMc(Data.DP_PLAYER);
		p.initPlayer(g, x, y);
		return p;
	}

	// the scarf of Igor (clips of the weapon: currentWeapon + 1), drawn over his picture in white, tinted
	var scarf:Pic;
	// his head (Data.HEAD_*: the clips of his head, drawn over his picture and his scarf: the disguises of the original,
	// key C) and his skin (1 Igor, 2 Sandy: key V): Game.head / Game.skin, only pictures
	var headPic:Pic;

	// (Sandy: the white of the snow of Igor in the colour of the sand, like the clips of her skin)
	static inline var SANDY_TINT = 0xf0d48f;

	var capeClock:Int = 0;

	function updateHead() {
		if (headPic == null) {
			headPic = new Pic("playerHead1_0");
			mc.addChild(headPic);
		}
		var a = "playerHead" + Game.head + "_" + pic.anim.substr(7);
		if (Art.RES.exists(a) || Tex.get(a).length > 0)
			headPic.setAnim(a);
		// (a cape playing by itself: its own clock, one of its pictures a cycle, whatever Igor does)
		capeClock++;
		var ph = Art.HEAD_PHASES.get(headPic.anim);
		if (ph != null)
			headPic.show(Std.int(Math.min((pic.cur - 1) * ph + capeClock % ph + 1, headPic.count())));
		else
			headPic.show(Std.int(Math.min(pic.cur, headPic.count())));
		pic.tint = Game.skin == 2 ? SANDY_TINT : 0xffffff;
	}

	// (the scarves of the weapons of the special items have patterns: their main colour)
	static var SPECIAL_TINTS = [6 => 0xc8d800, 7 => 0xff7a30, 8 => 0xa8eaff];

	function updateScarf() {
		if (scarf == null) {
			scarf = new Pic("playerScarf_0");
			mc.addChild(scarf);
		}
		// (without a weapon, the field without bombs: the grey scarf with a padlock, frame 11 of the scarf clips)
		var w = currentWeapon;
		var a = (w == Data.WEAPON_NONE ? "playerLock_" : "playerScarf_") + pic.anim.substr(7);
		if (Art.RES.exists(a) || Tex.get(a).length > 0)
			scarf.setAnim(a);
		scarf.show(Std.int(Math.min(pic.cur, scarf.count())));
		var t = SPECIAL_TINTS.get(w);
		if (t == null)
			t = Art.SCARF_TINTS[w < 0 ? 0 : Std.int(Math.min(w, Art.SCARF_TINTS.length - 1))];
		scarf.tint = w == Data.WEAPON_NONE ? 0xffffff : t;
	}

	override public function animName(id:Int):String {
		return "player_" + id;
	}

	override public function hit(e:Entity) {
		if ((e.types & Data.ITEM) > 0) {
			var et:Item = cast e;
			et.execute(this);
		}
	}

	public function forceKill(dx:Null<Float>) {
		fl_shield = false;
		entryGuard = 0;
		killHit(dx);
	}

	// invincible without a bubble (coming in a level)
	public var entryGuard:Float = 0;

	override public function killHit(dx:Null<Float>) {
		if (fl_kill || fl_shield || entryGuard > 0)
			return;
		#if debug
		Game.trace("player killHit dx=" + dx + " at " + x + "," + y + " " + untyped (new js.lib.Error()).stack.split("
").slice(2, 5).join("|"));
		#end
		fl_knock = false;
		Snd.play("sound_player_death", Snd.CHAN_PLAYER);
		var sign:Float = (dx == null || dx == 0) ? Math.NaN : dx / Math.abs(dx);
		if (Math.isNaN(sign))
			sign = Cs.rnd(2) * 2 - 1;
		if (x >= 0.85 * Data.GAME_WIDTH)
			sign = -1;
		if (x <= 0.15 * Data.GAME_WIDTH)
			sign = 1;
		playAnim(Data.ANIM_PLAYER_DIE);
		super.killHit(sign * 20);
	}

	public function getScore(origin:Entity, value:Int) {
		if (origin != null) {
			if (specialMan.actives[95])
				game.fxMan.attachScorePop(origin.x, origin.y, value * 2);
			else
				game.fxMan.attachScorePop(origin.x, origin.y, value);
		}
		getScoreHidden(value);
	}

	public function getScoreHidden(value:Int) {
		if (specialMan.actives[95])
			value *= 2;
		var step = Data.EXTRA_LIFE_STEPS[extraLifeCurrent];
		if (extraLifeCurrent < Data.EXTRA_LIFE_STEPS.length && score < step && score + value >= step) {
			lives++;
			game.gi.setLives(lives);
			extraLifeCurrent++;
		}
		score += value;
		game.addScore(value);
		game.gi.setScore(score);
	}

	// letters C R I S T A L
	public function getExtend(id:Int) {
		if (extendList[id] != true)
			game.gi.getExtend(id);
		if (extendList[id] != true)
			extendOrder.push(id);
		extendList[id] = true;
		var complete = true;
		for (i in 0...Data.EXTENDS.length) {
			if (extendList[i] != true)
				complete = false;
		}
		if (complete) {
			var fl_perfect = true;
			for (i in 0...extendOrder.length) {
				if (extendOrder[i] != i)
					fl_perfect = false;
			}
			game.gi.clearExtends();
			extendList = [];
			extendOrder = [];
			specialMan.executeExtend(fl_perfect);
		}
	}

	override public function infix() {
		super.infix();
		// fields (lasers): kind of bombs, or no bomb at all
		var id = world.getCase(cx, cy);
		if (id > Data.FIELD_TELEPORT && id < 0) {
			if (currentWeapon != Std.int(Math.abs(id))) {
				var fx = game.fxMan.attachShine(x, y - Data.CASE_HEIGHT * 0.5);
				if (fx != null)
					fx.mc._xscale = fx.mc._yscale = 65;
				Snd.play("sound_field", Snd.CHAN_FIELD);
			}
			changeWeapon(Std.int(Math.abs(id)));
		}
		if (id == Data.FIELD_PEACE) {
			if (currentWeapon != Data.WEAPON_NONE) {
				var fx = game.fxMan.attachShine(x, y - Data.CASE_HEIGHT * 0.5);
				if (fx != null)
					fx.mc._xscale = fx.mc._yscale = 65;
				Snd.play("sound_field", Snd.CHAN_FIELD);
			}
			changeWeapon(Data.WEAPON_NONE);
		}
		showTeleporters();
	}

	// teleporters close to the player light up (and the ones they lead to)
	public function showTeleporters() {
		var tl = world.teleporterList;
		for (td in tl)
			world.hideField(td);
		for (td in tl) {
			var close = false;
			if (td.dir == Data.VERTICAL) {
				if (Math.abs(td.centerX - x) <= Data.TELEPORTER_DISTANCE && y >= td.startY - Data.CASE_HEIGHT * 0.5
					&& y <= td.endY + Data.CASE_HEIGHT * 0.5)
					close = true;
			} else {
				if (Math.abs(td.centerY - y) <= Data.TELEPORTER_DISTANCE && x >= td.startX - Data.CASE_WIDTH
					&& x <= td.endX + Data.CASE_WIDTH)
					close = true;
			}
			if (close) {
				world.showField(td);
				var next = world.peekNextTeleporter(td);
				if (next != null)
					world.showField(next);
			}
		}
	}

	override public function onBump() {
		super.onBump();
		fl_knock = false;
		knock(Data.SECOND * 0.7);
	}

	override public function onTeleport() {
		super.onTeleport();
		dx = 0;
		dy = 0;
		// (the bubble of a shield goes with him at once, not across the screen)
		if (shieldMC != null && shieldMC.mc != null) {
			shieldMC.mc._x = x;
			shieldMC.mc._y = y;
			if (shieldMC.mc._prevState != null)
				shieldMC.mc._prevState.copyFrom(shieldMC.mc._curState);
		}
	}

	// death of the player (fell out of the field)
	public function killPlayer() {
		game.fxMan.attachFx(x, Data.GAME_HEIGHT, "fxDeathPlayer");
		game.statsMan.inc(Data.STAT_DEATH, 1);
		lives--;
		game.gi.setLives(lives);
		if (lives >= 0) {
			resurrect();
		} else {
			// (kept, hidden: the bads go on moving behind the end of the game)
			game.gi.setLives(0);
			hide();
			game.onGameOver();
		}
	}

	override public function resurrect() {
		super.resurrect();
		moveTo(Entity.x_ctr(world.current.playerX), Entity.y_ctr(world.current.playerY));
		dx = 0;
		dy = 0;
		shield(null);
		changeWeapon(1);
		fl_knock = false;
		specialMan.clearTemp();
		specialMan.clearPerm();
		specialMan.clearRec();
		playAnim(Data.ANIM_PLAYER_RESURRECT);
		stickAnim();
		fl_lockControls = true;
		game.onResurrect();
	}

	public function shield(duration:Null<Float>) {
		if (duration == null)
			duration = Data.SHIELD_DURATION;
		if (shieldMC != null)
			shieldMC.destroy();
		shieldMC = game.fxMan.attachFx(x, y, "playerShield");
		if (shieldMC != null) {
			shieldMC.fl_loop = true;
			shieldMC.loopFrame = 19; // gotoAndStop("loop")
			shieldMC.stopBlink();
			shieldMC.lifeTimer = duration;
		}
		shieldTimer = duration;
		fl_shield = true;
	}

	public function unshield() {
		fl_shield = false;
		shieldTimer = 0;
		onShieldOut();
	}

	public function knock(d:Float) {
		if (fl_knock)
			return;
		fl_lockControls = true;
		fl_knock = true;
		knockTimer = d;
	}

	override public function hide() {
		super.hide();
		if (shieldMC != null)
			shieldMC.mc._visible = false;
	}

	override public function show() {
		super.show();
		if (shieldMC != null)
			shieldMC.mc._visible = true;
	}

	override public function scale(n:Float) {
		super.scale(n);
		_xscale = _xscale * dir;
	}

	override public function destroy() {
		specialMan.clearPerm();
		specialMan.clearTemp();
		specialMan.clearRec();
		if (shieldMC != null) {
			shieldMC.destroy();
			shieldMC = null;
		}
		super.destroy();
	}

	public function curse(id:Int) {
		// (the curses that move in the original have their own pictures: curse_<id>)
		var own = Art.SIZE.exists("curse_" + id);
		var c = own ? new Pic("curse_" + id) : new Pic("curse", id);
		var holder = new ASprite();
		holder.addChild(c);
		holder._alpha = 70;
		game.dm.add(holder, Data.DP_FX);
		stick(holder, 0, -Data.CASE_HEIGHT * 2.5);
		setElaStick(0.25);
		if (own)
			stickerPic = c;
	}

	override public function playAnim(a:AnimDef) {
		if (a.id == baseWalkAnim.id && speedFactor > 1)
			a = Data.ANIM_PLAYER_RUN;
		if (fl_knock) {
			if (a.id != Data.ANIM_PLAYER_DIE.id && a.id != Data.ANIM_PLAYER_KNOCK_IN.id)
				return;
		}
		if (animId == Data.ANIM_PLAYER_KICK.id && a.id == Data.ANIM_PLAYER_JUMP_DOWN.id)
			return;
		super.playAnim(a);
	}

	public function setBaseAnims(a_walk:AnimDef, a_stop:AnimDef) {
		var fl_walk = animId == baseWalkAnim.id;
		var fl_stop = animId == baseStopAnim.id;
		if (animId == Data.ANIM_PLAYER_WAIT1.id || animId == Data.ANIM_PLAYER_WAIT2.id)
			fl_stop = true;
		if (a_walk != null)
			baseWalkAnim = a_walk;
		if (a_stop != null)
			baseStopAnim = a_stop;
		if (fl_walk)
			playAnim(baseWalkAnim);
		if (fl_stop)
			playAnim(baseStopAnim);
	}

	override public function needsPatch():Bool {
		return true;
	}

	public function lockControls(d:Float) {
		lockTimer = d;
		playAnim(baseStopAnim);
		fl_lockControls = true;
	}

	public function isRecentKick(b:Bomb):Bool {
		for (k in recentKicks) {
			if (b.uniqId == k.bid)
				return true;
		}
		return false;
	}

	// WEAPONS
	public function attack():Entity {
		if (specialMan.actives[91] || specialMan.actives[85])
			return null;
		switch (currentWeapon) {
			case Data.WEAPON_B_CLASSIC:
				return drop(Bomb.Classic.attach(game, x, y));
			case Data.WEAPON_B_BLACK:
				return drop(Bomb.Black.attach(game, x, y));
			case Data.WEAPON_B_BLUE:
				return drop(Bomb.Blue.attach(game, x, y));
			case Data.WEAPON_B_GREEN:
				return drop(Bomb.Green.attach(game, x, y));
			case Data.WEAPON_B_RED:
				return drop(Bomb.Red.attach(game, x, y));
			case Data.WEAPON_S_ARROW:
				return shoot(Shoot.PlayerArrow.attach(game, x, y));
			case Data.WEAPON_S_FIRE:
				return shoot(Shoot.PlayerFireBall.attach(game, x, y));
			case Data.WEAPON_S_ICE:
				return shoot(Shoot.PlayerPearl.attach(game, x, y));
			default:
				return null;
		}
	}

	public static function isBombWeapon(id:Int):Bool {
		return id >= Data.WEAPON_B_CLASSIC && id <= Data.WEAPON_B_RED;
	}

	public static function isShootWeapon(id:Int):Bool {
		return id == Data.WEAPON_S_ARROW || id == Data.WEAPON_S_FIRE || id == Data.WEAPON_S_ICE;
	}

	public function drop(b:Bomb.PlayerBomb):Entity {
		if (!fl_stable) {
			airJump();
		} else {
			// dropped by Igor standing: on the ground at once (moveTo puts it 1 px up, it landed 2 frames later and
			// an up kick at once counted as a kick in the air: no second kick of it in the air)
			b.moveTo(b.x, y + 1);
			b.fl_stable = true;
		}
		game.statsMan.inc(Data.STAT_BOMB, 1);
		b.setOwner(this);
		Snd.play("sound_bomb_drop", Snd.CHAN_PLAYER);
		if (!fl_stable)
			kickBomb([b], 1.0);
		return b;
	}

	public function airJump() {
		playAnim(Data.ANIM_PLAYER_JUMP_UP);
		if (dy > 0) {
			dy = -Data.PLAYER_AIR_JUMP;
		} else {
			if (Math.abs(dy) < Data.PLAYER_AIR_JUMP)
				dy = -Data.PLAYER_AIR_JUMP;
		}
	}

	public function shoot(s:Shoot):Entity {
		game.statsMan.inc(Data.STAT_SHOT, 1);
		coolDown = s.coolDown;
		if (dir < 0)
			s.moveLeft(s.shootSpeed);
		else
			s.moveRight(s.shootSpeed);
		return s;
	}

	public function changeWeapon(id:Null<Int>) {
		if (id == null)
			id = lastBomb;
		if (id > 0 && !isBombWeapon(id) && !isShootWeapon(id))
			return;
		if (isBombWeapon(currentWeapon) && !isBombWeapon(id))
			lastBomb = currentWeapon;
		if (isBombWeapon(id))
			lastBomb = id;
		currentWeapon = id;
		// pictures with the new weapon (the original replayed the animation)
		if (animId != null)
			setPics(animName(animId));
	}

	public function kickBomb(l:Array<Bomb>, powerFactor:Float) {
		for (b in l) {
			if (!isRecentKick(b)) {
				if ((b.fl_airKick || (!b.fl_airKick && b.fl_stable)) && !b.fl_explode) {
					b.dx = dir * Data.PLAYER_HKICK_X;

					// stairs on the left
					if (dir < 0 && world.checkFlag(cx, cy, Data.IA_CLIMB_LEFT)) {
						var h = world.getWallHeight(cx - 1, cy, Data.IA_CLIMB);
						if (h != null && h <= 1)
							b.moveTo(b.x, b.y - Data.CASE_HEIGHT * 0.5);
					}
					// stairs on the right
					if (dir > 0 && world.checkFlag(cx, cy, Data.IA_CLIMB_RIGHT)) {
						var h = world.getWallHeight(cx + 1, cy, Data.IA_CLIMB);
						if (h != null && h <= 1)
							b.moveTo(b.x, b.y - Data.CASE_HEIGHT * 0.5);
					}

					if (specialMan.actives[13])
						b.dx *= 2; // helmet
					b.dy = -Data.PLAYER_HKICK_Y;
					b.onKick(this);
					b.next = null;
					b.fl_bounce = true;
					recentKicks.push({t: game.cycle, bid: b.uniqId});
					Snd.play("sound_kick", Snd.CHAN_PLAYER);
					playAnim(Data.ANIM_PLAYER_KICK);
					game.statsMan.inc(Data.STAT_KICK, 1);
					if (specialMan.actives[70]) // clover
						getScore(this, 10);
				}
			}
		}
	}

	// the down key near a bomb sends it up in the air (the quest "kick up!" of the original: family 101)
	public function upKickBomb(l:Array<Bomb>) {
		for (b in l) {
			if (!isRecentKick(b)) {
				if ((b.fl_airKick || (!b.fl_airKick && b.fl_stable)) && !b.fl_explode) {
					b.dx *= 2;
					if (Math.abs(b.dx) <= 1.5)
						b.dx = 0.5 * dir;
					b.dy = -Data.PLAYER_VKICK;
					if (specialMan.actives[13])
						b.dy *= 2; // helmet
					b.next = null;
					b.onKick(this);
					b.fl_stable = false;
					b.fl_bounce = true;
					recentKicks.push({t: game.cycle, bid: b.uniqId});
					Snd.play("sound_kick", Snd.CHAN_PLAYER);
					playAnim(Data.ANIM_PLAYER_KICK);
					game.statsMan.inc(Data.STAT_KICK, 1);
					if (specialMan.actives[70]) // clover
						getScore(this, 10);
				}
			}
		}
	}

	public function countBombs():Int {
		var n = 0;
		for (e in game.getList(Data.PLAYER_BOMB)) {
			var b:Bomb = cast e;
			if (!b.fl_explode && e.parent == this)
				n++;
		}
		return n;
	}

	// EVENTS
	override public function onEndAnim(id:Int) {
		super.onEndAnim(id);

		if (id == Data.ANIM_PLAYER_KNOCK_OUT.id) {
			fl_lockControls = false;
			playAnim(baseStopAnim);
		}
		if (id == Data.ANIM_PLAYER_RESURRECT.id) {
			fl_lockControls = false;
			playAnim(baseStopAnim);
		}
		// after an air kick
		if (id == Data.ANIM_PLAYER_KICK.id && !fl_stable) {
			animId = null;
			playAnim(Data.ANIM_PLAYER_JUMP_DOWN);
			return;
		}
		if (id == Data.ANIM_PLAYER_KICK.id || id == Data.ANIM_PLAYER_ATTACK.id || id == Data.ANIM_PLAYER_WAIT1.id
			|| id == Data.ANIM_PLAYER_WAIT2.id || id == Data.ANIM_PLAYER_JUMP_LAND.id) {
			playAnim(baseStopAnim);
		}
	}

	override public function onDeathLine() {
		super.onDeathLine();
		if (fl_kill) {
			killPlayer();
		} else {
			if (game.checkLevelClear()) {
				// next level
				dy = 0;
				game.nextLevel();
			} else {
				// death
				y = Data.LEVEL_HEIGHT * Data.CASE_HEIGHT - Data.CASE_HEIGHT - 1;
				dx = 0;
				forceKill(0);
			}
		}
	}

	public function onShieldOut() {
		game.fxMan.attachFx(x, y, "popShield");
		if (shieldMC != null) {
			shieldMC.destroy();
			shieldMC = null;
		}
		checkHits();
	}

	public function onWakeUp() {
		fl_knock = false;
		if (fl_stable) {
			dx = 0;
			playAnim(Data.ANIM_PLAYER_KNOCK_OUT);
		} else {
			fl_lockControls = false;
			playAnim(Data.ANIM_PLAYER_JUMP_DOWN);
		}
	}

	public function onNextLevel() {
		changeWeapon(1);
		if (fl_shield)
			shieldTimer = 1;
		// (happy or sad for the big crystal of the level above: back to normal)
		setBaseAnims(Data.ANIM_PLAYER_WALK, Data.ANIM_PLAYER_STOP);
		specialMan.clearTemp();
		specialMan.clearRec();
	}

	override public function onHitGround(h:Float) {
		super.onHitGround(h);
		if (h >= Data.DUST_FALL_HEIGHT)
			game.fxMan.dust(cx, cy + 1);
		game.fxMan.attachFx(x, y, "fxFall");
		Snd.play("sound_land", Snd.CHAN_PLAYER);
		showTeleporters();
		// stone head
		if (specialMan.actives[39]) {
			game.shake(10, 2);
			for (b in game.getBadClearList())
				b.knock(Data.SECOND);
		}
	}

	override public function onHitWall() {
		if (fl_knock) {
			dx = -dx * 0.5;
			if (Math.abs(dx) >= 10 && world.getCase(cx, cy) <= 0) {
				game.shake(Data.SECOND * 0.7, 5);
				game.fxMan.inGameParticlesDir(Data.PARTICLE_STONE, x, y, 1 + Cs.vrnd(3), dx);
				game.fxMan.inGameParticlesDir(Data.PARTICLE_CLASSIC_BOMB, x, y, 3 + Cs.vrnd(5), dx);
			}
		} else {
			super.onHitWall();
		}
	}

	public function onStartLevel() {
		this.show();
		if (fl_shield && shieldMC == null)
			shield(shieldTimer);
		// (invincible for a moment when he comes in a level, without a bubble: a saw or a bad may be where he lands;
		// not at the start of the game)
		entryGuard = game.levelsDone > 0 ? Data.SECOND * 2 : 0;
		startX = x;
		fl_entering = true;
	}

	// UPDATES
	override public function endUpdate() {
		super.endUpdate();
		if (shieldMC != null) {
			if (shieldTimer <= Data.SECOND * 3)
				shieldMC.blink();
			shieldMC.mc._x = shieldMC.mc._x + (this.x - shieldMC.mc._x) * 0.75;
			shieldMC.mc._y = shieldMC.mc._y + (this.y - 20 - shieldMC.mc._y) * 0.75;
		}
		_xscale = dir * Math.abs(_xscale);
		updateScarf();
		updateHead();
	}

	override public function update() {
		// kicks
		var i = 0;
		while (i < recentKicks.length) {
			if (game.cycle - recentKicks[i].t > 2) {
				recentKicks.splice(i, 1);
				i--;
			}
			i++;
		}

		// effects of the special items
		specialMan.main();

		// moves
		if (!fl_kill && !fl_lockControls) {
			if (!fl_entering && _visible)
				ctrl.update();
		}
		if (fl_entering) {
			if (cy >= 0)
				fl_entering = false;
		}

		// cooldown of the shots
		if (coolDown > 0) {
			coolDown -= Game.tmod;
			if (coolDown <= 0)
				coolDown = 0;
		}

		// knocked
		if (fl_knock) {
			knockTimer -= Game.tmod;
			if (knockTimer <= 0) {
				onWakeUp();
			} else {
				if (fl_stable && animId != Data.ANIM_PLAYER_KNOCK_IN.id)
					playAnim(Data.ANIM_PLAYER_KNOCK_IN);
				if (!fl_stable && animId != Data.ANIM_PLAYER_DIE.id)
					playAnim(Data.ANIM_PLAYER_DIE);
			}
		}

		// controls lock
		if (fl_lockControls) {
			if (fl_stable && animId == baseStopAnim.id)
				fl_lockControls = false;
		}
		if (lockTimer > 0) {
			lockTimer -= Game.tmod;
			if (lockTimer <= 0)
				fl_lockControls = false;
			else
				fl_lockControls = true;
		}

		// shield
		if (fl_shield) {
			shieldTimer -= Game.tmod;
			if (shieldTimer <= 0)
				unshield();
		}
		if (entryGuard > 0)
			entryGuard -= Game.tmod;

		super.update();
		updateCoords();

		if (dx != 0 || dy != 0) {
			edgeTimer = 0;
			waitTimer = 0;
		}

		if (!fl_kill) {
			// jump animation
			if (!fl_stable && dy >= 0 && animId != Data.ANIM_PLAYER_JUMP_DOWN.id && !fl_lockControls)
				playAnim(Data.ANIM_PLAYER_JUMP_DOWN);
			if (animId == Data.ANIM_PLAYER_JUMP_DOWN.id && fl_stable)
				playAnim(Data.ANIM_PLAYER_JUMP_LAND);

			// waiting animation (with every weapon, like the original: its scarf has the pictures of both)
			if (animId == Data.ANIM_PLAYER_STOP.id) {
				if (waitTimer <= 0)
					waitTimer = Data.WAIT_TIMER;
				waitTimer -= Game.tmod;
				if (waitTimer <= 0) {
					// (players: "il manque des animations quand le perso est afk": the two of the original, the chewing gum
					// 19 times out of 20, the dance)
					if (Cs.rnd(20) == 0)
						playAnim(Data.ANIM_PLAYER_WAIT1);
					else
						playAnim(Data.ANIM_PLAYER_WAIT2);
				}
			}

			// on the edge of the void
			if (fl_stable && dx == 0) {
				if (animId == baseStopAnim.id) {
					var px = Entity.x_rtc(x + dir * Data.CASE_WIDTH * 0.3);
					var py = Entity.y_rtc(y + Data.CASE_HEIGHT);
					if (world.getCase(px, py) <= 0 && world.getCase(cx + dir, cy) == 0) {
						if (edgeTimer <= 0)
							edgeTimer = Data.EDGE_TIMER;
						edgeTimer -= Game.tmod;
						if (edgeTimer <= 0)
							playAnim(Data.ANIM_PLAYER_EDGE);
					}
				}
			}
		}
	}
}
