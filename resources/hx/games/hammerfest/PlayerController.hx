package hammerfest;

import common_haxe_avm1.KeyboardManager;

// hammer/entity/PlayerController.mt: arrows to move and jump, space (or ctrl) to drop / kick a bomb, down to kick
// a bomb up in the air
class PlayerController {
	var player:Player;
	var game:Game;

	var lastKeys:Array<Int>;
	var keyLocks:Map<Int, Bool>;

	var jump:Int;
	var down:Int;
	var left:Int;
	var right:Int;
	var attack:Int;
	var alts:Map<Int, Int>;

	var walkTimer:Float;

	public function new(p:Player) {
		lastKeys = [];
		keyLocks = new Map();
		alts = new Map();
		player = p;
		game = player.game;
		jump = KeyboardManager.UP;
		down = KeyboardManager.DOWN;
		left = KeyboardManager.LEFT;
		right = KeyboardManager.RIGHT;
		attack = KeyboardManager.SPACE;
		alts.set(attack, KeyboardManager.CONTROL);
		walkTimer = 0;
	}

	static inline function isDown(k:Null<Int>):Bool {
		return k != null && KeyboardManager.isDown(k);
	}

	// a key that has to be released before it acts again
	function keyIsDown(id:Int):Bool {
		var alt = alts.get(id);
		var fl = (isDown(id) && keyLocks.get(id) != true) || (alt != null && isDown(alt) && keyLocks.get(alt) != true);
		if (fl)
			lockKey(id);
		return fl;
	}

	function lockKey(id:Int) {
		keyLocks.set(id, true);
		lastKeys.push(id);
		var alt = alts.get(id);
		if (alt != null) {
			keyLocks.set(alt, true);
			lastKeys.push(alt);
		}
	}

	function getControls() {
		// keys released
		var i = 0;
		while (i < lastKeys.length) {
			if (!isDown(lastKeys[i])) {
				keyLocks.set(lastKeys[i], false);
				lastKeys.splice(i, 1);
				i--;
			}
			i++;
		}

		// left
		if (isDown(left)) {
			if (game.fl_ice) {
				var frict = (!player.fl_stable) ? 0.35 : 0.1;
				player.dx -= frict * Data.PLAYER_SPEED * player.speedFactor;
				player.dx = Math.max(player.dx, -Data.PLAYER_SPEED * player.speedFactor);
			} else {
				player.dx = -Data.PLAYER_SPEED * player.speedFactor;
			}
			player.dir = -1;
			if (player.fl_stable)
				player.playAnim(player.baseWalkAnim);
		}

		// right
		if (isDown(right)) {
			if (game.fl_ice) {
				var frict = (!player.fl_stable) ? 0.35 : 0.1;
				player.dx += frict * Data.PLAYER_SPEED * player.speedFactor;
				player.dx = Math.min(player.dx, Data.PLAYER_SPEED * player.speedFactor);
			} else {
				player.dx = Data.PLAYER_SPEED * player.speedFactor;
			}
			player.dir = 1;
			if (player.fl_stable)
				player.playAnim(player.baseWalkAnim);
		}

		if (player.specialMan.actives[73]) { // tree leaf
			if (player.fl_stable && player.dx != 0) {
				walkTimer -= Game.tmod;
				if (walkTimer <= 0) {
					walkTimer = Data.SECOND;
					player.getScore(player, 10);
				}
			}
		}

		// braking
		if (!isDown(left) && !isDown(right)) {
			if (!game.fl_ice)
				player.dx *= game.gFriction * 0.8;
			if (player.animId == player.baseWalkAnim.id || player.animId == Data.ANIM_PLAYER_RUN.id)
				player.playAnim(player.baseStopAnim);
		}

		// jump
		if (player.fl_stable && isDown(jump)) {
			player.dy = -Data.PLAYER_JUMP;
			player.playAnim(Data.ANIM_PLAYER_JUMP_UP);
			Snd.play("sound_jump", Snd.CHAN_PLAYER);
			var fx = game.fxMan.attachFx(player.x, player.y, "fxJump");
			if (fx != null)
				fx.mc._alpha = 50;
			if (player.specialMan.actives[66]) // cactus
				player.getScore(player, 10);
			game.statsMan.inc(Data.STAT_JUMP, 1);
			lockKey(jump);
		}

		// attack
		if (keyIsDown(attack) && player.coolDown == 0) {
			var dist:Float = Data.KICK_DISTANCE;
			if (!player.fl_stable)
				dist = Data.AIR_KICK_DISTANCE;
			var bombList:Array<Bomb> = cast game.getClose(Data.BOMB, player.x, player.y, dist, false);
			if (bombList.length == 0) {
				// drop a bomb
				if (player.currentWeapon > 0 && player.countBombs() < player.maxBombs) {
					var e = player.attack();
					if (e != null)
						e.setParent(player);
					if (player.fl_stable)
						player.playAnim(Data.ANIM_PLAYER_ATTACK);
				}
			} else if (isDown(down)) {
				// down held while kicking a bomb: up in the air (the text of the quest "kick up!" of the original:
				// "Maintenez BAS enfoncé pendant que vous tapez dans une bombe posée")
				player.upKickBomb(bombList);
			} else {
				// kick the bombs
				player.kickBomb(bombList, 1.0);
			}
		} else if (keyIsDown(down)) {
			// up kick: the bombs close to Igor go up in the air
			var dist:Float = Data.KICK_DISTANCE;
			if (!player.fl_stable)
				dist = Data.AIR_KICK_DISTANCE;
			var bombList:Array<Bomb> = cast game.getClose(Data.BOMB, player.x, player.y, dist, false);
			if (bombList.length > 0)
				player.upKickBomb(bombList);
		}
	}

	public function update() {
		getControls();
	}
}
