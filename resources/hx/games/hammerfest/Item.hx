package hammerfest;

// hammer/entity/Item.mt: an item to pick up
class Item extends Physics {
	public var id:Int;
	public var subId:Null<Int>;

	public function new(animBase:String) {
		super(animBase);
		disableAnimator();
		fl_alphaBlink = true;
		fl_largeTrigger = true;
		fl_strictGravity = false;
		minAlpha = 0;
	}

	override public function animName(id:Int):String {
		return animBase;
	}

	override public function init(g:Game) {
		super.init(g);
		setLifeTimer(Data.ITEM_LIFE_TIME);
		register(Data.ITEM);
	}

	// the picture of the item (frame id + 1 of its clip, sub frame subId + 1)
	public function showItem() {}

	public function initItem(g:Game, x:Float, y:Float, id:Int, subId:Null<Int>) {
		init(g);
		Game.trace("item " + animBase + " " + id + "/" + subId + " at " + Math.round(x) + "," + Math.round(y));
		moveTo(x, y);
		this.id = id;
		this.subId = subId;
		showItem();
		game.fxMan.attachFx(x, y - Data.CASE_HEIGHT, "fxShine");
		endUpdate();
	}

	public function execute(p:Player) {
		Game.trace("picked " + animBase + " " + id + "/" + subId + " score " + p.score);
		destroy();

	}

	override public function onDeathLine() {
		super.onDeathLine();
		moveTo(x, -30);
		dy = 0;
	}

	override public function onLifeTimer() {
		super.onLifeTimer();
		game.fxMan.attachFx(x, y - Data.CASE_HEIGHT / 2, "fxPop");
		Snd.play("sound_pop", Snd.CHAN_ITEM);
	}
}

// hammer/entity/item/ScoreItem.mt: points (crystals of the combos, diamonds, food...)
class ScoreItem extends Item {
	public function new() {
		super("scoreItem");
	}

	public static function attach(g:Game, x:Float, y:Float, id:Int, subId:Null<Int>):ScoreItem {
		var it = new ScoreItem();
		it.attachMc(Data.DP_ITEMS);
		if (id >= 1000)
			id -= 1000;
		it.initItem(g, x, y, id, subId);
		return it;
	}

	override public function showItem() {
		if (id == 0) {
			// crystals: sub frame = size of the combo
			pic.setAnim("crystal");
			var n = pic.count();
			pic.show(Std.int(Math.max(1, Math.min(n, (subId == null ? 0 : subId) + 1))));
		} else {
			var i = Art.SCORE_IDS.indexOf(id);
			pic.setAnim("scoreItem");
			pic.show(i < 0 ? 1 : i + 1);
		}
	}

	public static function value(id:Int):Int {
		var i = Art.SCORE_IDS.indexOf(id);
		return i < 0 ? 0 : Art.SCORE_VALUES[i];
	}

	override public function execute(p:Player) {
		var value:Int = ScoreItem.value(id);
		Snd.play("sound_item_score", Snd.CHAN_ITEM);
		if (value == 0) {
			switch (id) {
				case 0: // crystals
					value = Data.getCrystalValue(subId == null ? 0 : subId);
				case Data.DIAMANT: // diamond
					value = 2000;
				default:
					value = 0;
			}
		}
		p.getScore(this, value);
		game.pickUpScore(id, subId);
		super.execute(p);
	}
}

// hammer/entity/item/SpecialItem.mt: an effect (SpecialManager), or a letter C R I S T A L (id 0)
class SpecialItem extends Item {
	public function new() {
		super("specialItem");
	}

	override public function init(g:Game) {
		super.init(g);
		register(Data.SPECIAL_ITEM);
	}

	public static function attach(g:Game, x:Float, y:Float, id:Int, subId:Null<Int>):SpecialItem {
		if (g.fl_clear && id == 0) // no letter once the level is clear
			return null;
		var it = new SpecialItem();
		it.attachMc(Data.DP_ITEMS);
		it.initItem(g, x, y, id, subId);
		return it;
	}

	override public function showItem() {
		if (id == 0) {
			pic.setAnim("letter");
			pic.show((subId == null ? 0 : subId) + 1);
		} else {
			var i = Art.SPECIAL_IDS.indexOf(id);
			pic.setAnim("specialItem");
			pic.show(i < 0 ? 1 : i + 1);
		}
	}

	override public function execute(p:Player) {
		game.pickUpSpecial(id);
		p.specialMan.execute(this);
		Snd.play("sound_item_special", Snd.CHAN_ITEM);
		if (id > 0)
			game.attachItemName(id);
		super.execute(p);
	}

	override public function update() {
		super.update();
		if (id != 0) {
			if (Cs.vrnd(4) == 0) {
				var a = game.fxMan.attachFx(x + Cs.vrnd(15) * (Cs.vrnd(2) * 2 - 1), y - Cs.vrnd(10), "fxStar");
				if (a != null) {
					a.mc._xscale = Cs.vrnd(70) + 30;
					a.mc._yscale = a.mc._xscale;
				}
			}
		}
	}
}

// hammer/entity/supa/SupaItem.mt: the big crystal falling at the end of a level whose bads were killed in their
// order (worth 5 crystals of the same size)
class SupaItem extends Mover {
	var supaId:Int;
	var radius:Float;

	public function new(id:Int) {
		super("supaItem");
		supaId = id;
		fl_hitGround = false;
		fl_hitWall = false;
		fl_gravity = false;
		fl_friction = false;
		fl_hitBorder = false;
		fl_alphaBlink = false;
		minAlpha = 0;
		radius = 50;
		disableAnimator();
	}

	override public function animName(id:Int):String {
		return "supaItem";
	}

	override public function init(g:Game) {
		super.init(g);
		register(Data.SUPA);
	}

	public static function attach(g:Game, id:Int):SupaItem {
		var s = new SupaItem(id);
		s.attachMc(Data.DP_SUPA);
		s.init(g);
		s.moveTo(Data.GAME_WIDTH / 2, -50);
		s.scale(200);
		s.moveDown(5);
		s.pic.show(Std.int(Math.max(1, Math.min(s.pic.count(), id + 1))));
		s.endUpdate();
		return s;
	}

	public function pickBy(pl:Player) {
		pick(pl);
	}

	function pick(pl:Player) {
		game.fxMan.inGameParticles(Data.PARTICLE_ICE, x, y, 15);
		game.fxMan.attachExplodeZone(x, y, 50);
		pl.getScore(this, Data.getCrystalValue(supaId) * 5);
		Snd.play("sound_item_supa", Snd.CHAN_ITEM);
		destroy();
	}

	override public function infix() {}

	override public function tAdd(cx:Int, cy:Int) {}

	override public function tRem(cx:Int, cy:Int) {}

	override public function prefix() {
		super.prefix();
		for (e in game.getClose(Data.PLAYER, x, y + Data.CASE_HEIGHT * 1.5, radius, false)) {
			if (!e.fl_kill && e._visible) {
				pick(cast e);
				break;
			}
		}
		// out of the level: Igor sad (SupaItem.onDeathLine)
		if (y >= Data.GAME_HEIGHT + 50) {
			for (p in game.getList(Data.PLAYER)) {
				var pl:Player = cast p;
				pl.setBaseAnims(Data.ANIM_PLAYER_WALK, Data.ANIM_PLAYER_STOP_L);
			}
			destroy();
		}
	}
}

// hammer/entity/supa/Smoke.mt: the cloud of a fight in the middle of the screen for 3 seconds (the sunflower: all the
// bads die), 265 % of its clip, the clip playing by itself (a picture of its loop every picture of the game, like the
// SWF at 40 pictures a second)
class Smoke extends Mover {
	var f:Int;

	public function new() {
		super("supaSmoke");
		fl_hitGround = false;
		fl_hitWall = false;
		fl_gravity = false;
		fl_friction = false;
		fl_hitBorder = false;
		fl_alphaBlink = false;
		fl_blink = false;
		minAlpha = 0;
		disableAnimator();
		f = 0;
	}

	override public function animName(id:Int):String {
		return "supaSmoke";
	}

	override public function init(g:Game) {
		super.init(g);
		register(Data.SUPA);
	}

	public static function attach(g:Game):Smoke {
		var s = new Smoke();
		s.attachMc(Data.DP_SUPA);
		s.init(g);
		s.moveTo(Data.GAME_WIDTH / 2, Data.GAME_HEIGHT / 2);
		s.scale(265);
		s.setLifeTimer(Data.SECOND * 3);
		s.endUpdate();
		return s;
	}

	override public function infix() {}

	override public function tAdd(cx:Int, cy:Int) {}

	override public function tRem(cx:Int, cy:Int) {}

	override public function update() {
		super.update();
		f++;
		pic.show(1 + f % pic.count());
	}
}
