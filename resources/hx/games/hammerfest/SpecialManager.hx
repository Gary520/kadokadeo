package hammerfest;

// hammer/SpecialManager.mt: effects of the special items (the ones of the mini version: see Art.SPECIAL_IDS)
class SpecialManager {
	var game:Game;
	var player:Player;

	var permList:Array<Int>;
	var tempList:Array<{id:Int, end:Float}>;

	public var actives:Array<Bool>;

	var recurring:Array<{timer:Float, baseTimer:Float, fl_repeat:Bool, func:Void->Void}>;

	public function new(g:Game, p:Player) {
		game = g;
		player = p;
		permList = [];
		tempList = [];
		actives = [];
		recurring = [];
	}

	public function permanent(id:Int) {
		if (actives[id] != true) {
			actives[id] = true;
			permList.push(id);
		}
	}

	// until the end of the level when no duration
	public function temporary(id:Int, ?duration:Null<Float>) {
		if (duration == null)
			duration = 99999;
		if (actives[id] != true) {
			actives[id] = true;
			tempList.push({id: id, end: game.cycle + duration});
		}
	}

	public function global(id:Int) {
		game.globalActives[id] = true;
	}

	public function clearTemp() {
		while (tempList.length > 0) {
			interrupt(tempList[0].id);
			tempList.splice(0, 1);
		}
	}

	public function clearPerm() {
		while (permList.length > 0) {
			interrupt(permList[0]);
			permList.splice(0, 1);
		}
	}

	public function clearRec() {
		recurring = [];
	}

	// all the letters C R I S T A L: an extra life (and a bonus if they were picked in order)
	public function executeExtend(fl_perfect:Bool) {
		game.fxMan.attachExtend();
		game.destroyList(Data.BAD);
		game.destroyList(Data.BAD_BOMB);
		game.destroyList(Data.SHOOT);
		player.lives++;
		game.gi.setLives(player.lives);
		if (fl_perfect) {
			game.fxMan.attachAlert("PERFECT !");
			player.getScoreHidden(150000);
		}
	}

	// umbrellas: a jump of n levels
	public function warpZone(w:Int) {
		game.forcedGoto(game.world.currentId + w);
	}

	public function execute(item:Item) {
		var id = item.id;
		var subId = item.subId;
		switch (id) {
			case 0: // letters
				if (actives[27])
					player.getScore(item, 25);
				player.getScoreHidden(5);
				player.getExtend(subId);
			case 1: // gold shield
				player.shield(Data.SECOND * 10);
			case 2: // silver shield
				player.shield(Data.SECOND * 60);
			case 4: // gold lamp: one more bomb (3)
				if (actives[5] != true) {
					player.maxBombs = player.initialMaxBombs + 1;
					permanent(id);
				}
			case 5: // black lamp: 4 more bombs (6)
				player.maxBombs = player.initialMaxBombs + 4;
				permanent(id);
			case 6: // yin yang: freeze all
				for (b in game.getBadClearList())
					b.freeze(Data.FREEZE_DURATION * 2);
			case 7: // shoe: faster
				player.speedFactor = 1.5;
				permanent(id);
			case 11: // red umbrella
				warpZone(1);
			case 12: // blue umbrella
				warpZone(2);
			case 13: // helmet: bombs kicked further
				permanent(id);
			case 14:
				permanent(id);
				interrupt(15);
				interrupt(16);
				interrupt(17);
			case 15:
				permanent(id);
				interrupt(14);
				interrupt(16);
				interrupt(17);
			case 16:
				permanent(id);
				interrupt(14);
				interrupt(15);
				interrupt(17);
			case 17:
				permanent(id);
				interrupt(14);
				interrupt(15);
				interrupt(16);
			case 18: // dandelion: slow fall
				permanent(id);
				player.fallFactor = 0.55;
			case 19: // sunflower: all the bads die (in a cloud of a fight)
				Item.Smoke.attach(game);
				game.fxMan.attachBg(Data.BG_ORANGE, Data.SECOND * 3);
				for (b in game.getBadClearList())
					b.forceKill(null);
			case 20: // treasure chest
				for (i in 0...5) {
					var s = Item.ScoreItem.attach(game, item.x, item.y, 0, Cs.rnd(4));
					s.moveFrom(item, 8);
				}
			case 21: // loudspeaker: one bad dies
				var bad:Bad = cast game.getOne(Data.BAD_CLEAR);
				if (bad != null) {
					game.fxMan.attachFx(bad.x, bad.y - Data.CASE_HEIGHT, "fxPop");
					bad.forceKill(null);
					game.fxMan.attachBg(Data.BG_SINGER, Data.SECOND * 3);
				}
			case 22: // old shoe: slower
				interrupt(7);
				player.curse(Data.CURSE_SLOW);
				player.speedFactor = 0.6;
				temporary(id, Data.SECOND * 40);
			case 23: // crystal ball: a pearl on each bad
				for (b in game.getBadClearList()) {
					var s = Shoot.PlayerPearl.attach(game, player.x, player.y - Data.CASE_WIDTH);
					s.moveToTarget(b, s.shootSpeed);
					s.fl_borderBounce = true;
					s.setLifeTimer(Data.SECOND * 3 + Cs.rnd(400) / 10);
					s._yOffset = 0;
					s.endUpdate();
				}
			case 25: // cold flame: curtain of fireballs
				for (i in 0...3) {
					var s = Shoot.PlayerFireBall.attach(game, Data.GAME_WIDTH * 0.167 + Data.GAME_WIDTH * 0.333 * i, 10);
					s.moveDown(s.shootSpeed);
				}
				for (i in 0...3) {
					var s = Shoot.PlayerFireBall.attach(game, Data.GAME_WIDTH * 0.333 + Data.GAME_WIDTH * 0.333 * i, Data.GAME_HEIGHT - 10);
					s.moveUp(s.shootSpeed);
				}
			case 28: // silver trinket: the bads are knocked out
				game.fxMan.attachBg(Data.BG_STAR, Data.SECOND * 9);
				for (b in game.getBadClearList())
					b.knock(Data.SECOND * 10);
			case 29: // gold ring: fireballs
				player.changeWeapon(Data.WEAPON_S_FIRE);
				temporary(id, Data.WEAPON_DURATION);
			case 32: // aces: the bads become crystals
				aces(0, false);
			case 33:
				aces(2, false);
			case 34:
				aces(5, false);
			case 35:
				aces(6, true);
			case 36: // Ig'or: an extra life
				player.lives++;
				game.gi.setLives(player.lives);
				game.fxMan.attachShine(item.x, item.y - Data.CASE_HEIGHT * 0.5);
			case 37: // crystal necklace: pearls
				player.changeWeapon(Data.WEAPON_S_ICE);
				temporary(id, Data.WEAPON_DURATION);
			case 39: // stone head
				player.fallFactor = 1.6;
				temporary(id);
			case 26: // bulb: the darkness halved
				permanent(id);
			case 68: // candle: a bigger light around Igor
				permanent(id);
			case 65: // duck buoy: points for each bad
				for (b in game.getBadList()) {
					if ((b.types & Data.BAD_CLEAR) > 0)
						player.getScore(b, 2500);
					else
						player.getScore(b, 600);
				}
			case 66: // cactus: jumps give points
				permanent(id);
			case 67: // emerald ring: arrows
				player.changeWeapon(Data.WEAPON_S_ARROW);
				temporary(id, Data.WEAPON_DURATION);
			case 69: // turtle: slower bads
				global(id);
				temporary(id, Data.SECOND * 30);
				for (b in game.getBadClearList()) {
					b.updateSpeed();
					b.animFactor *= 0.6;
				}
			case 70: // clover: kicks give points
				permanent(id);
			case 71: // dragon head: two fireballs
				var s = Shoot.PlayerFireBall.attach(game, item.x, item.y);
				s.moveLeft(s.shootSpeed);
				s = Shoot.PlayerFireBall.attach(game, item.x, item.y);
				s.moveRight(s.shootSpeed);
			case 72: // wizard hat: bads -> crystals of increasing value
				game.destroyList(Data.ITEM);
				game.destroyList(Data.BAD_BOMB);
				var n = 1;
				for (e in game.getList(Data.BAD_CLEAR).copy()) {
					var b:Bad = cast e;
					Item.ScoreItem.attach(game, b.x, b.y, 0, n);
					b.destroy();
					n++;
				}
			case 73: // tree leaf: walking gives points
				permanent(id);
			case 74, 75, 76: // spirits: candies
				for (i in 0...7) {
					var it = Item.ScoreItem.attach(game, Cs.rnd(Data.GAME_WIDTH), Data.GAME_HEIGHT, id - 71, null);
					it.moveToAng(-20 - Cs.rnd(160), Cs.rnd(15) + 10);
				}
			case 77, 78, 79: // fishes: crystals at the end of the level
				var sub = [0, 2, 3][id - 77];
				var me = game;
				game.endLevelStack.push(function() {
					for (i in 0...5)
						Item.ScoreItem.attach(me, Cs.rnd(Data.GAME_WIDTH), -30 - Cs.rnd(50), 0, sub);
				});
			case 80: // snail: much slower bads
				global(id);
				temporary(id, Data.SECOND * 30);
				for (b in game.getBadClearList()) {
					b.updateSpeed();
					b.animFactor *= 0.3;
				}
			default:
		}
	}

	function aces(sub:Int, two:Bool) {
		for (b in game.getBadClearList().copy()) {
			b.destroy();
			if (two) {
				Item.ScoreItem.attach(game, b.x - Data.CASE_WIDTH, b.y - Data.CASE_HEIGHT, 0, sub);
				Item.ScoreItem.attach(game, b.x + Data.CASE_WIDTH, b.y - Data.CASE_HEIGHT, 0, sub);
			} else {
				Item.ScoreItem.attach(game, b.x, b.y - Data.CASE_HEIGHT, 0, sub);
			}
		}
	}

	public function interrupt(id:Int) {
		if (actives[id] != true)
			return;
		actives[id] = false;
		switch (id) {
			case 4, 5:
				player.maxBombs = player.initialMaxBombs;
			case 7:
				player.speedFactor = 1.0;
			case 18:
				player.fallFactor = 1.1;
			case 22:
				player.speedFactor = 1.0;
				player.unstick();
			case 29:
				if (player.currentWeapon == Data.WEAPON_S_FIRE)
					player.changeWeapon(null);
			case 37:
				if (player.currentWeapon == Data.WEAPON_S_ICE)
					player.changeWeapon(null);
			case 39:
				player.fallFactor = 1.1;
			case 67:
				if (player.currentWeapon == Data.WEAPON_S_ARROW)
					player.changeWeapon(null);
			case 69:
				game.globalActives[id] = false;
				for (b in game.getBadClearList()) {
					b.updateSpeed();
					b.animFactor *= 1 / 0.6;
				}
			case 80:
				game.globalActives[id] = false;
				for (b in game.getBadClearList()) {
					b.updateSpeed();
					b.animFactor *= 1 / 0.3;
				}
			default:
		}
	}

	public function main() {
		var n = 0;
		while (n < recurring.length) {
			var e = recurring[n];
			e.timer -= Game.tmod;
			if (e.timer <= 0) {
				e.func();
				if (e.fl_repeat) {
					e.timer = e.baseTimer + e.timer;
				} else {
					recurring.splice(n, 1);
					n--;
				}
			}
			n++;
		}
		var i = 0;
		while (i < tempList.length) {
			if (game.cycle >= tempList[i].end) {
				interrupt(tempList[i].id);
				tempList.splice(i, 1);
				i--;
			}
			i++;
		}
	}
}
