package hammerfest;

import common_haxe_avm1.KeyboardManager;
import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchControlsMode;
import pixi.core.display.Container;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.RenderTexture;
import pixi.core.textures.Texture;
import pixi.filters.colormatrix.ColorMatrixFilter;
import pixi.filters.extras.GlowFilter;

// Hammerfest Mini: Igor in a well of small levels, with the engine, the bads, the items and the graphics of
// Hammerfest (Motion-Twin, 2006, CC BY-NC-SA 4.0: archive WebGamesArchives/Hammerfest). This class is the
// GameMode + Adventure of the original: lists of entities, levels, hurry up, items of the levels, game over.
// The game runs in Flash pixels (300 x 300), drawn x2.
@:expose('GameHammerfest')
class Game implements kado.GameInterface {
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.KEYBOARD,
		buttons: [
			{
				id: "left",
				label: "◀",
				leftPx: 14,
				bottomPx: 14,
				size: 84,
				keyCode: KeyboardManager.LEFT,
			},
			{
				id: "right",
				label: "▶",
				leftPx: 112,
				bottomPx: 14,
				size: 84,
				keyCode: KeyboardManager.RIGHT,
			},
			{
				id: "bomb",
				label: "●",
				rightPx: 112,
				bottomPx: 14,
				size: 84,
				keyCode: KeyboardManager.SPACE,
			},
			{
				// over the bomb: the up kick (the bombs close to Igor go up in the air)
				id: "kickup",
				label: "▼",
				rightPx: 119,
				bottomPx: 112,
				size: 70,
				keyCode: KeyboardManager.DOWN,
			},
			{
				id: "jump",
				label: "▲",
				rightPx: 14,
				bottomPx: 14,
				size: 84,
				keyCode: KeyboardManager.UP,
			}
		],
	};

	// ZQSD / WASD move and jump like the arrows
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE;

	public static inline var K = 2;
	public static inline var START_LIVES = 2; // 3 tries

	public static var me:Game;

	var scene:ASprite;
	var gameMc:ASprite;

	public var dm:Plans;
	public var ui:ASprite;

	// a point of the field in the pixels of the game (ui)
	public static inline function docX(x:Float):Float {
		return 10 + x * Data.GAME_SCALE;
	}

	public static inline function docY(y:Float):Float {
		return y * Data.GAME_SCALE;
	}
	public var world:World;
	public var fxMan:FxManager;
	public var gi:Interface;
	public var statsMan:Stats;

	public var player:Player;

	// lists of entities by type (one per bit of Data types)
	var lists:Array<Array<Entity>>;

	public var killList:Array<Entity>;
	public var unregList:Array<{type:Int, ent:Entity}>;

	var uniq:Int;

	public var cycle:Float;
	public var xFriction:Float;
	public var yFriction:Float;
	public var gFriction:Float;
	public var sFriction:Float;
	public var speedFactor:Float;
	public var diffFactor:Float;

	public var fl_lock:Bool;
	public var fl_clear:Bool;
	public var fl_gameOver:Bool;
	public var fl_ice:Bool;
	public var fl_wind:Bool;
	public var windSpeed:Float;

	public var comboList:Map<Int, Int>;
	public var badCount:Int;

	public var huTimer:Float;
	public var huState:Int;

	public var globalActives:Array<Bool>;
	public var endLevelStack:Array<Void->Void>;

	var shakeTotal:Float;
	var shakeTimer:Float;
	var shakePower:Float;

	// items of the level (ScriptEngine of the original: timers from the start of the level)
	var scriptCycle:Float;
	var timers:Array<{t:Float, base:Float, repeat:Int, endClear:Bool, fn:Void->Void}>;
	var extendList:Array<Int>;

	// interface effects
	var anims:Array<Animation>;

	var gameOverTimer:Float;
	var over:Bool;
	var isReplay:Bool;

	public var frameCount:Int;
	public var levelsDone:Int;
	public var kills:Int;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: UInt16Array.fromArray([
				KeyboardManager.UP,
				KeyboardManager.DOWN,
				KeyboardManager.LEFT,
				KeyboardManager.RIGHT,
				KeyboardManager.SPACE,
				KeyboardManager.CONTROL,
				// detailed effects, intuition, disguise, skin (only pictures, recorded too: the replay shows them like the
				// game)
				69,
				73,
				67,
				86,
				#if debug
				// test keys N, L, K: they change the game, the replay plays them
				78, 76, 75,
				#end
			]),
			recordInputs: true,
			recordEvents: false,
		});
		me = this;
		this.isReplay = isReplay;
		// (the sounds and the musics of the original; the music of the game: Adventure.initGame)
		Snd.init();
		Snd.setMusicVolume(1);
		Snd.playMusic(0);
		// (the options of the browser, again: a replay may have changed them)
		detail = loadDetail();
		intuition = loadIntuition();
		loadLook();
		frameCount = 0;
		levelsDone = 0;
		kills = 0;
		over = false;
		gameOverTimer = 0;

		scene = root.createEmptyMovieClip("scene", 0);
		scene._xscale = scene._yscale = 100 * K;
		scene.updateState();
		// (nothing of the page under the game: under the irregular edges of the stone columns)
		var back = new pixi.core.graphics.Graphics();
		back.beginFill(0x000000);
		back.drawRect(0, 0, Data.DOC_WIDTH, Data.DOC_HEIGHT);
		back.endFill();
		scene.addChild(back);
		gameMc = scene.createEmptyMovieClip("game", 0);
		gameMc._x = 10;
		gameMc._xscale = gameMc._yscale = Data.GAME_SCALE * 100;
		gameMc.updateState();
		dm = new Plans(gameMc);

		lists = [for (i in 0...Data.TYPE_COUNT) []];
		killList = [];
		unregList = [];
		uniq = 0;
		cycle = 0;
		// (Mode.updateConstants, GameMode.updateGroundFrictions: the frictions of a picture)
		xFriction = Math.pow(Data.FRICTION_X, TMOD);
		yFriction = Math.pow(Data.FRICTION_Y, TMOD);
		gFriction = Math.pow(Data.FRICTION_GROUND, TMOD);
		sFriction = Math.pow(Data.FRICTION_SLIDE, TMOD);
		speedFactor = 1.0;
		diffFactor = 1.0;
		fl_lock = true;
		fl_clear = false;
		fl_gameOver = false;
		fl_ice = false;
		fl_wind = false;
		windSpeed = 0;
		comboList = new Map();
		badCount = 0;
		huTimer = 0;
		huState = 0;
		globalActives = [];
		endLevelStack = [];
		shakeTotal = 0;
		shakeTimer = 0;
		shakePower = 0;
		scriptCycle = 0;
		timers = [];
		extendList = [];
		anims = [];

		// texts of the game over the field, in the pixels of the game (the field is scaled)
		ui = scene.createEmptyMovieClip("ui", 1);
		Levels.reset();
		fxMan = new FxManager(this);
		statsMan = new Stats();
		world = new World(this);
		gi = new Interface(this, scene);

		// Adventure.initGame: the first level, Igor at his start
		var first = 0;
		#if debug
		// test harness: game.html?...&lvl=N starts at the level N
		var lv = new js.html.URLSearchParams(js.Browser.location.search).get("lvl");
		if (lv != null)
			first = Std.parseInt(lv);
		// ...&kind=<name>: every level drawn with this layout (LevelDesign.LAYOUTS: full, center, bands, three, pair) or
		// this motif (lattice, tree, spines, arches, pillars, hooks, box, stairs, rooms, ledges, comb, stack)
		LevelGen.forceKind = new js.html.URLSearchParams(js.Browser.location.search).get("kind");
		// ...&feat=<gate|spikes|pit|vault|disarm|teleport|saws|nest>[,...]: every level with these features (LevelFeatures)
		LevelFeatures.force = new js.html.URLSearchParams(js.Browser.location.search).get("feat");
		// ...&idea=<id>: every level drawn for this idea (LevelConcept: vide, tirs, fraises, nid, cave, rives, arene,
		// mines, bombinos, coffre, pics, litchis, abricots, framboises, combo, bondissantes)
		LevelConcept.force = new js.html.URLSearchParams(js.Browser.location.search).get("idea");
		#end
		world.goto(first);
		#if debug
		// test harness: items at will
		untyped js.Browser.window.__hfScore = function(x:Float, y:Float, id:Int, sub:Null<Int>) return Item.ScoreItem.attach(me, x, y, id, sub);
		untyped js.Browser.window.__hfSpecial = function(x:Float, y:Float, id:Int, sub:Null<Int>) return Item.SpecialItem.attach(me, x, y, id, sub);
		#end
		player = Player.attach(this, Entity.x_ctr(world.current.playerX), Entity.y_ctr(world.current.playerY));
		player.lives = START_LIVES;
		player.hide();
		gi.setLives(player.lives);
		gi.setLevel(0);
		world.unlock();
		onLevelReady();

		warmShaders();
	}

	// test harness: events of the game (window.__trace = true)
	public static function trace(msg:String) {
		#if debug
		var w:Dynamic = js.Browser.window;
		if (w.__trace == true) {
			if (w.__tr == null)
				w.__tr = [];
			w.__tr.push((me != null ? me.frameCount : -1) + " " + msg);
		}
		#end
	}

	public function getUniqId():Int {
		return uniq++;
	}

	// LISTS
	static inline function listId(type:Int):Int {
		var i = 0;
		while (type != (1 << i))
			i++;
		return i;
	}

	public inline function getList(type:Int):Array<Entity> {
		return lists[listId(type)];
	}

	public function countList(type:Int):Int {
		return lists[listId(type)].length;
	}

	public function getPlayers():Array<Player> {
		return cast getList(Data.PLAYER);
	}

	public function getBadList():Array<Bad> {
		return cast getList(Data.BAD);
	}

	public function getBadClearList():Array<Bad> {
		return cast getList(Data.BAD_CLEAR);
	}

	public function getListCopy(type:Int):Array<Entity> {
		return getList(type).copy();
	}

	public function getClose(type:Int, x:Float, y:Float, radius:Float, fl_onGround:Bool):Array<Entity> {
		var out = [];
		var sqrRad = radius * radius;
		for (e in getList(type)) {
			var square = (e.x - x) * (e.x - x) + (e.y - y) * (e.y - y);
			if (square <= sqrRad) {
				if (Math.sqrt(square) <= radius) {
					if (!fl_onGround || (fl_onGround && e.y <= y + Data.CASE_HEIGHT))
						out.push(e);
				}
			}
		}
		return out;
	}

	public function getOne(type:Int):Entity {
		var l = getList(type);
		if (l.length == 0)
			return null;
		return l[Cs.rnd(l.length)];
	}

	public function getAnotherOne(type:Int, e:Entity):Entity {
		var l = getList(type);
		if (l.length <= 1)
			return null;
		var i:Int;
		do {
			i = Cs.rnd(l.length);
		} while (l[i] == e);
		return l[i];
	}

	public function addToList(type:Int, e:Entity) {
		lists[listId(type)].push(e);
	}

	public function removeFromList(type:Int, e:Entity) {
		lists[listId(type)].remove(e);
	}

	public function destroyList(type:Int) {
		for (e in getList(type).copy())
			e.destroy();
	}

	public function destroySome(type:Int, n:Int) {
		var l = getListCopy(type);
		while (l.length > 0 && n > 0) {
			var i = Cs.vrnd(l.length);
			l[i].destroy();
			l.splice(i, 1);
			n--;
		}
	}

	public function cleanKills() {
		for (u in unregList)
			removeFromList(u.type, u.ent);
		unregList = [];
		for (e in killList) {
			if (Std.isOfType(e, Trigger))
				(cast e : Trigger).tRem(e.cx, e.cy);
			e.removeMc();
		}
		killList = [];
	}

	// ATTACHMENTS
	public function attachBad(id:Int, x:Float, y:Float):Bad {
		var bad = Fruits.attachBad(this, id, x, y);
		if (bad != null && bad.isType(Data.BAD_CLEAR)) {
			badCount++;
			// Adventure.attachBad: the order of the bads (killed in it: big crystal at the end)
			perfectOrder.push(bad.uniqId);
			perfectCount++;
			orderNum.set(bad.uniqId, perfectCount);
		}
		return bad;
	}

	var perfectOrder:Array<Int> = [];
	var perfectCount:Int = 0;

	public function attachItemName(id:Int) {
		var i = Art.SPECIAL_IDS.indexOf(id);
		if (i >= 0)
			fxMan.attachItemName(i, "specialItem", i + 1);
	}


	public function addAnim(a:Animation) {
		anims.push(a);
	}

	public function countCombo(id:Int):Int {
		var n = comboList.exists(id) ? comboList.get(id) : 0;
		n++;
		comboList.set(id, n);
		return n;
	}

	public function canAddItem():Bool {
		return !fl_clear || world.current.bads.length == 0;
	}

	public function pickUpSpecial(id:Int) {}

	public function pickUpScore(id:Int, subId:Null<Int>) {}

	// SCORE
	public function addScore(n:Int) {
		if (!over)
			KadoKadeoManager.kkm.addScore(n);
	}

	public function getScore():Int {
		return KadoKadeoManager.kkm.score.get();
	}

	// EFFECTS
	// detailed effects (the options detail and shake of the original): particles, dust, shaking; key E, kept in the
	// browser (only the pictures change: the game and its replay stay the same)
	public static var detail:Bool = loadDetail();

	// INTUITION (a mode of the fans): the order of the bads (killed in it: the big crystal at the end). Key I in turn:
	// a white outline on the bad to kill first, 3.5 s, then on the next one when it is dead (1); under each bad of the
	// order its number in it (2: 1 the first, the numbers kept as the bads die); nothing (0). Nothing more once the
	// order is lost. Kept in the browser, only pictures
	public static var intuition:Int = loadIntuition();
	var intuitionKey:Bool = false;

	// the look of Igor, kept in the browser: his disguise (Data.HEAD_*, key C: the cone, the afro, the jester, Piou,
	// Mario, the hood of Tuberculoz; the disguises of the original, key D there: the D of ZQSD / WASD here) and his
	// skin (key V: Igor or Sandy, her own head first)
	public static var head:Int = 1;
	public static var skin:Int = 1;
	var lookKeys:Array<Bool> = [false, false];
	static var IGOR_HEADS = [1, 2, 3, 4, 5, 6];
	static var SANDY_HEADS = [10, 2, 3, 4, 5, 6];

	static function loadLook() {
		skin = 1;
		head = 1;
		try {
			var st = js.Browser.getLocalStorage();
			skin = st.getItem("hammerfest.skin") == "2" ? 2 : 1;
			var h = Std.parseInt(st.getItem("hammerfest.head"));
			head = skin == 2 ? 10 : 1;
			if (h != null && (skin == 2 ? SANDY_HEADS : IGOR_HEADS).indexOf(h) >= 0)
				head = h;
		} catch (e:Dynamic) {}
	}

	function saveLook() {
		if (!isReplay)
			try {
				var st = js.Browser.getLocalStorage();
				st.setItem("hammerfest.skin", Std.string(skin));
				st.setItem("hammerfest.head", Std.string(head));
			} catch (e:Dynamic) {}
	}

	// the next disguise
	function nextHead() {
		var list = skin == 2 ? SANDY_HEADS : IGOR_HEADS;
		var i = list.indexOf(head);
		head = list[(i + 1) % list.length];
		saveLook();
	}

	// Igor or Sandy (with her own head, he with his cone; the other disguises kept)
	function nextSkin() {
		skin = skin == 2 ? 1 : 2;
		if (head == 1 || head == 10)
			head = skin == 2 ? 10 : 1;
		saveLook();
	}
	var orderLost:Bool = false;
	var hintBad:Bad = null;
	var hintTimer:Float = 0;
	var orderNum:Map<Int, Int> = new Map();
	var orderMarks:Array<{bad:Bad, mc:ASprite, n:Int, w:Float}> = [];

	// (the old option: "1" the outline, "0" nothing)
	static function loadIntuition():Int {
		try {
			var v = js.Browser.getLocalStorage().getItem("hammerfest.intuition");
			return v == "0" ? 0 : (v == "2" ? 2 : 1);
		} catch (e:Dynamic) {
			return 1;
		}
	}

	function toggleIntuition() {
		// (the outline, the numbers, nothing)
		intuition = (intuition + 1) % 3;
		if (!isReplay)
			try {
				js.Browser.getLocalStorage().setItem("hammerfest.intuition", Std.string(intuition));
			} catch (e:Dynamic) {}
		fxMan.attachOptionMsg(intuition == 1 ? 3 : (intuition == 2 ? 9 : 4));
		showOrderHint();
	}

	function showOrderHint() {
		clearOrderHint();
		if (intuition == 0 || orderLost || perfectOrder.length == 0 || perfectCount < 2)
			return;
		if (intuition == 2) {
			for (e in getList(Data.BAD_CLEAR))
				if (!e.fl_kill && orderNum.exists(e.uniqId) && perfectOrder.indexOf(e.uniqId) >= 0)
					orderMarks.push({
						bad: cast e,
						mc: orderMark(orderNum.get(e.uniqId)),
						n: orderNum.get(e.uniqId),
						w: orderMarkWidth(orderNum.get(e.uniqId))
					});
			updateOrderMarks();
			return;
		}
		for (e in getList(Data.BAD_CLEAR))
			if (e.uniqId == perfectOrder[0] && !e.fl_kill) {
				hintBad = cast e;
				break;
			}
		if (hintBad == null)
			return;
		hintBad.pic.filters = [
			Type.createInstance(GlowFilter, [
				{
					color: 0xffffff,
					distance: 6,
					outerStrength: 4,
					innerStrength: 0,
					quality: 0.3
				}
			])
		];
		hintTimer = Data.SECOND * 3.5;
	}

	function clearOrderHint() {
		if (hintBad != null && hintBad.pic != null)
			hintBad.pic.filters = null;
		hintBad = null;
		hintTimer = 0;
		for (m in orderMarks)
			removeOrderMark(m.mc);
		orderMarks = [];
	}

	// the number of a bad in the order: white digits outlined in black, under its feet (on its ground), its middle under
	// the middle of the bad (each digit centred on its picture, its pivot at its bottom middle)
	function orderMark(n:Int):ASprite {
		var mc = new ASprite();
		var txt = Std.string(n);
		var adv = Art.DIGIT_ORDER;
		var w = orderMarkWidth(n);
		var px = -w / 2;
		for (i in 0...txt.length) {
			var d = Std.parseInt(txt.charAt(i));
			var p = new Pic("digitOrder", d + 1);
			p._x = px + adv[d] / 2;
			p._y = 0;
			mc.addChild(p);
			px += adv[d];
		}
		dm.add(mc, Data.DP_FX);
		return mc;
	}

	static function orderMarkWidth(n:Int):Float {
		var txt = Std.string(n);
		var w = 0.0;
		for (i in 0...txt.length)
			w += Art.DIGIT_ORDER[Std.parseInt(txt.charAt(i))];
		return w;
	}

	function removeOrderMark(mc:ASprite) {
		if (mc.parent != null)
			mc.parent.removeChild(mc);
		mc.destroy({children: true});
	}

	// (after each picture: the numbers follow their bads, gone with them)
	function updateOrderMarks() {
		var i = 0;
		while (i < orderMarks.length) {
			var m = orderMarks[i];
			if (m.bad.fl_kill || m.bad.fl_destroy) {
				removeOrderMark(m.mc);
				orderMarks.splice(i, 1);
				continue;
			}
			m.mc._x = m.bad.x;
			m.mc._y = m.bad.y + ORDER_MARK_Y;
			i++;
		}
		// (two bads at the same place: their numbers side by side with a gap, not read as one number; the smaller one on
		// the left when they are at the very same place)
		for (k in 0...2)
			for (a in 0...orderMarks.length)
				for (b in a + 1...orderMarks.length) {
					var ma = orderMarks[a];
					var mb = orderMarks[b];
					if (Math.abs(ma.mc._y - mb.mc._y) >= ORDER_MARK_H)
						continue;
					var sep = (ma.w + mb.w) / 2 + ORDER_MARK_GAP;
					var dx = mb.mc._x - ma.mc._x;
					if (Math.abs(dx) >= sep - 0.01)
						continue;
					var mid = (ma.mc._x + mb.mc._x) / 2;
					var side = (dx > 0 || (dx == 0 && ma.n < mb.n)) ? 1 : -1;
					ma.mc._x = mid - side * sep / 2;
					mb.mc._x = mid + side * sep / 2;
				}
	}

	static inline var ORDER_MARK_Y = 16;
	static inline var ORDER_MARK_H = 14; // height of the digits
	static inline var ORDER_MARK_GAP = 7; // between the numbers of two bads at the same place

	function updateOrderHint() {
		if (hintBad == null)
			return;
		hintTimer -= tmod;
		if (hintTimer <= 0 || hintBad.fl_kill || hintBad.fl_destroy)
			clearOrderHint();
	}
	var detailKey:Bool = false;
	#if debug
	var debugN:Bool = false;
	var debugL:Bool = false;
	var debugK:Bool = false;
	var debugG:Bool = false;
	#end

	static function loadDetail():Bool {
		try {
			return js.Browser.getLocalStorage().getItem("hammerfest.detail") != "0";
		} catch (e:Dynamic) {
			return true;
		}
	}

	function toggleDetail() {
		detail = !detail;
		if (!isReplay)
			try {
				js.Browser.getLocalStorage().setItem("hammerfest.detail", detail ? "1" : "0");
			} catch (e:Dynamic) {}
		if (!detail)
			shake(null, 0);
		fxMan.attachOptionMsg(detail ? 1 : 2);
	}

	public function shake(duration:Null<Float>, power:Float) {
		if (duration != null && !detail)
			return;
		if (duration == null) {
			shakeTimer = 0;
		} else {
			if (duration < shakeTimer || power < shakePower)
				return;
			shakeTotal = duration;
			shakeTimer = duration;
			shakePower = power;
		}
	}

	// HURRY UP
	public function resetHurry() {
		huTimer = 0;
		huState = 0;
		// (back to the music of the game after VITE ! : Adventure.resetHurry)
		if (Snd.currentTrack() == 2)
			Snd.playMusic(0);
		diffFactor = player != null && player.lives >= 4 ? 1.0 + 0.05 * (player.lives - 3) : 1.0;
		destroyList(Data.HU_BAD);
		for (b in getBadList())
			b.calmDown();
	}

	// VITE ! comes sooner and sooner in the well (35 s then 25 s in the original)
	function hurryStep(state:Int):Float {
		var d = world.currentId;
		if (state == 0)
			return Math.max(14, 35 - d * 1.4) * Data.SECOND;
		return Math.max(9, 25 - d * 1.0) * Data.SECOND;
	}

	public function onHurryUp() {
		Game.trace("hurry up " + (huState + 1));
		huState++;
		huTimer = 0;
		for (b in getBadList())
			b.onHurryUp();
		fxMan.attachAlert("VITE !");
		if (huState == 1)
			Snd.play("sound_hurry", Snd.CHAN_INTERF);
		// (the music of VITE ! : Adventure.onHurryUp)
		if (Snd.currentTrack() == 0)
			Snd.playMusic(2);
		if (huState == 2)
			callEvilOne(0);
	}

	public function callEvilOne(baseAnger:Int) {
		Game.trace("evil one " + baseAnger);
		if (player != null && !player.fl_kill) {
			var mc = FireBall.attach(this, player);
			mc.anger = baseAnger - 1;
			if (baseAnger > 0) {
				mc.fl_summon = false;
				mc.stopBlink();
			}
			mc.angerMore();
		}
	}

	// LEVELS
	public function checkLevelClear():Bool {
		if (fl_clear)
			return true;
		if (countList(Data.BAD_CLEAR) > 0)
			return false;
		onLevelClear();
		return true;
	}

	// the letters of the level go away (and no more come)
	var lettersOff:Bool = false;

	function removeLetters() {
		lettersOff = true;
		for (e in getList(Data.SPECIAL_ITEM).copy()) {
			var it:Item = cast e;
			if (it.id == 0)
				it.destroy();
		}
	}

	public function onLevelClear() {
		Game.trace("level clear " + world.currentId);
		if (fl_clear)
			return;
		clearEndTimers();
		for (e in getList(Data.SPECIAL_ITEM).copy()) {
			var it:Item = cast e;
			if (it.id == 0)
				it.destroy();
		}
		fl_clear = true;
		world.openEnd();
		fxMan.attachExit();
		// all the bads killed in their order
		if (perfectOrder.length == 0 && perfectCount > 1 && scriptCycle >= 10) {
			Game.trace("perfect order " + perfectCount);
			// (Adventure.onLevelClear: Igor happy)
			if (player != null)
				player.setBaseAnims(Data.ANIM_PLAYER_WALK_V, Data.ANIM_PLAYER_STOP_V);
			Item.SupaItem.attach(this, perfectCount - 1);
		}
		for (f in endLevelStack)
			f();
		endLevelStack = [];
	}

	public function nextLevel() {
		goto(world.currentId + 1);
	}

	// umbrellas: the next levels without falling
	public function forcedGoto(id:Int) {
		goto(id, true);
		if (player != null) {
			player.moveTo(Entity.x_ctr(world.current.playerX), Entity.y_ctr(world.current.playerY - 1));
			player.shield(Data.SHIELD_DURATION * 1.3);
			player.hide();
		}
	}

	function clearLevel() {
		clearOrderHint();
		destroyList(Data.BAD);
		destroyList(Data.ITEM);
		destroyList(Data.BOMB);
		destroyList(Data.SUPA);
		destroyList(Data.SHOOT);
		destroyList(Data.FX);
	}

	public function goto(id:Int, ?fade:Bool = false) {
		Game.trace("goto " + id + (fl_lock ? " (locked)" : ""));
		if (fl_lock || fl_gameOver)
			return;
		levelsDone++;
		pendingLevel = null;
		// quick games: the points left in the level are picked up (not the items with effects, nor the big crystal
		// of the order of the bads: it must be caught)
		if (player != null && !player.fl_kill) {
			for (e in getList(Data.ITEM).copy()) {
				if (Std.isOfType(e, Item.ScoreItem) && !e.fl_kill)
					(cast e : Item.ScoreItem).execute(player);
			}
		}
		world.lock();
		clearLevel();
		lock();
		fl_clear = false;
		if (player != null) {
			player.moveTo(player.x, -200);
			player.hide();
			player.onNextLevel();
		}
		Snd.play("sound_level_clear", Snd.CHAN_INTERF);
		if (fade) {
			// jump (umbrellas): black screen with the loading bar, then the level
			fxMan.onNextLevel();
			world.goto(id, true);
			for (e in getList(Data.ENTITY))
				e.world = world;
		} else {
			// a pause with the loading bar on the old level (the points picked up fly away), then the scrolling
			pendingLevel = id;
			fxMan.detachExit();
			world.startLoad();
		}
	}

	var pendingLevel:Null<Int> = null;

	function nextLevelReady() {
		var id = pendingLevel;
		pendingLevel = null;
		fxMan.onNextLevel();
		world.goto(id);
		for (e in getList(Data.ENTITY))
			e.world = world;
	}

	public function lock() {
		fl_lock = true;
	}

	public function unlock() {
		fl_lock = false;
	}

	// EVENTS
	public function onLevelReady() {
		unlock();
		initLevel();
		startLevel();
		for (e in getList(Data.ENTITY))
			e.world = world;
		if (player != null)
			player.show();
		gi.setLevel(world.currentId);
	}

	function initLevel() {
		if (!world.isVisited())
			resetHurry();
		badCount = 0;
		fl_clear = false;
		if (player != null) {
			if (player.y < 0)
				safeEntry();
			player.onStartLevel();
			if (player.y < 0)
				fxMan.attachEnter(player.x);
		}
	}

	// Igor comes in falling at the column where he left the level above: moved to the nearest column where he lands
	// on a ground (not through the whole level, not on spikes)
	function safeEntry() {
		var cx = Entity.x_rtc(player.x);
		var entry = world.current.entry;
		for (pass in 0...3) {
			// (a column where every bad and the way down can be reached from where he lands, far from the bads; then
			// without the bads; then any ground)
			var far = pass == 0;
			var best = -1;
			var bd = 99;
			for (x in 0...Data.LEVEL_WIDTH) {
				var d = Std.int(Math.abs(x - cx));
				if (pass < 2 && entry != null && entry[x] != true)
					continue;
				if (d < bd && landsSafe(x, far)) {
					bd = d;
					best = x;
				}
			}
			if (best >= 0) {
				if (best != cx)
					player.x = Entity.x_ctr(best);
				return;
			}
		}
	}

	// a ground under the column, no spikes there (and no bad around if far)
	function landsSafe(x:Int, far:Bool):Bool {
		var m = world.current.map;
		for (y in 0...Data.LEVEL_HEIGHT - 1) {
			if (m[x][y] > 0)
				return false;
			if (m[x][y + 1] > 0) {
				for (b in world.current.bads) {
					if (b.id == Data.BAD_SPEAR && b.x == x && (b.y == y || b.y == y - 1))
						return false;
					if (far && b.id != Data.BAD_SPEAR && Math.abs(b.x - x) + Math.abs(b.y - y) < 4)
						return false;
				}
				return true;
			}
		}
		return false;
	}

	function startLevel() {
		lettersOff = false;
		perfectOrder = [];
		perfectCount = 0;
		orderNum = new Map();
		scriptCycle = 0;
		timers = [];
		// the fruits get faster in the well, and angry from the start deep in it
		var depth = world.currentId;
		// (players: the big rise was felt from level 10: the bads angry from the start at level 14, faster a little
		// slower)
		speedFactor = 1.0 + Math.min(0.45, depth * 0.025);
		var anger = depth < 14 ? 0 : (depth < 26 ? 1 : 2);
		var n = 0;
		for (b in world.current.bads) {
			// ScriptEngine E_BAD: in the case, on its ground
			var bad = attachBad(b.id, Entity.x_ctr(b.x) - Data.CASE_WIDTH * 0.5, Entity.y_ctr(b.y - 1));
			if (bad != null && bad.isType(Data.BAD_CLEAR)) {
				n++;
				for (i in 0...anger)
					bad.angerMore();
			}
		}
		if (n == 0) {
			fxMan.attachExit();
			fl_clear = true;
		}
		if (!world.isVisited())
			addLevelItems();
		statsMan.reset();
		orderLost = false;
		showOrderHint();
	}

	// Adventure.addLevelItems: letters every 10 s, a special item at 8 s, a score item at 12 s
	function addLevelItems() {
		var cur = world.current;
		if (cur.specialSlots.length > 0)
			spreadExtend();
		if (cur.specialSlots.length > 0) {
			var pt = cur.specialSlots[Cs.rnd(cur.specialSlots.length)];
			var id = Art.SPECIAL_IDS[Cs.draw([for (r in Art.SPECIAL_RARITY) Data.RARITY[r]])];
			addTimer(Data.SPECIAL_ITEM_TIMER, 1, true, function() {
				if (canAddItem())
					Item.SpecialItem.attach(this, Entity.x_ctr(pt.x), Entity.y_ctr(pt.y), id, null);
			});
		}
		if (cur.scoreSlots.length > 0) {
			var pt = cur.scoreSlots[Cs.rnd(cur.scoreSlots.length)];
			var id = Art.SCORE_IDS[Cs.draw([for (r in Art.SCORE_RARITY) Data.RARITY[r]])];
			addTimer(Data.SCORE_ITEM_TIMER, 1, true, function() {
				Item.ScoreItem.attach(this, Entity.x_ctr(pt.x), Entity.y_ctr(pt.y), id, null);
			});
		}
	}

	// StatsManager.spreadExtend: letters of the level (more letters after big combos)
	function spreadExtend() {
		var nb = 1;
		if (statsMan.read(Data.STAT_MAX_COMBO) >= 2)
			nb += statsMan.read(Data.STAT_MAX_COMBO) - 1;
		nb = Std.int(Math.min(7, nb));
		extendList = [];
		var taken = [];
		for (i in 0...nb) {
			var id:Int;
			do {
				id = Cs.draw(Data.RAND_EXTENDS);
			} while (taken[id] == true);
			taken[id] = true;
			extendList.push(id);
		}
		// repeated every 10 s (absolute time from the start of the level)
		addTimer(Data.EXTEND_TIMER, -1, true, function() {
			if (canAddItem())
				attachExtend();
		});
	}

	function attachExtend() {
		if (fl_clear || lettersOff)
			return;
		var pt = world.getGround(Cs.rnd(Data.LEVEL_WIDTH), Cs.rnd(Data.LEVEL_HEIGHT));
		var id = extendList[Cs.rnd(extendList.length)];
		Item.SpecialItem.attach(this, Entity.x_ctr(pt.x), Entity.y_ctr(pt.y), 0, id);
	}

	function addTimer(t:Float, repeat:Int, endClear:Bool, fn:Void->Void) {
		timers.push({
			t: t,
			base: t,
			repeat: repeat,
			endClear: endClear,
			fn: fn
		});
	}

	function clearEndTimers() {
		timers = [for (t in timers) if (!t.endClear) t];
	}

	function runTimers() {
		scriptCycle += tmod;
		var i = 0;
		while (i < timers.length) {
			var t = timers[i];
			if (scriptCycle >= t.t) {
				t.fn();
				t.repeat--;
				if (t.repeat == 0) {
					timers.remove(t);
					i--;
				} else {
					t.t = t.base + scriptCycle;
				}
			}
			i++;
		}
	}

	public function onResurrect() {
		destroyList(Data.SUPA);
		resetHurry();
	}

	// a bad replaced by another one (the litchi without its shell, Litchi.weaken): the new one takes its place in the
	// order of the big crystal (players: in the original the litchi, destroyed but never killed, stayed in the order:
	// breaking a shell lost the big crystal)
	public function replaceInOrder(from:Bad, to:Bad) {
		var i = perfectOrder.indexOf(from.uniqId);
		if (i < 0)
			return;
		perfectOrder[i] = to.uniqId;
		if (orderNum.exists(from.uniqId)) {
			orderNum.set(to.uniqId, orderNum.get(from.uniqId));
			orderNum.remove(from.uniqId);
		}
		showOrderHint();
	}

	public function onKillBad(b:Bad) {
		if (badCount > 1 && perfectOrder.length > 0) {
			if (b.uniqId == perfectOrder[0]) {
				perfectOrder.shift();
				// intuition: the next one to kill
				showOrderHint();
			} else if (perfectOrder.indexOf(b.uniqId) >= 0) {
				// the order is lost: no more hint
				orderLost = true;
				clearOrderHint();
			}
		}
		Game.trace("bad killed " + b.animBase + " combo " + b.comboId);
		kills++;
	}

	// a bomb of Igor exploded (the script $exp of the original): the stone blocks it reaches break
	public function onExplode(x:Float, y:Float, radius:Float) {
		world.onExplode(x, y, radius);
	}

	public function onGameOver() {
		fl_gameOver = true;
		Snd.stopMusic();
		// (the end of the game at once: no pause with nothing on the screen)
		gameOverTimer = Data.SECOND * 0.3;
	}

	function saveScore() {
		if (over)
			return;
		over = true;
		var stats = {l: levelsDone, k: kills};
		#if debug
		// test harness: state of the game at its end (compared between a game and its replay)
		untyped js.Browser.window.__over = {
			frame: frameCount,
			score: getScore(),
			level: world.currentId,
			stats: haxe.Json.stringify(stats)
		};
		#end
		KadoKadeoManager.kkm.gameOver(stats);
	}

	// the original ran 40 pictures a second (all its SWFs), each one a cycle of 0.8 (mt.Timer.tmod: its game counted 32
	// cycles a second): the game runs the same, 5 pictures every 4 steps of the manager (32 a second), the moves the
	// same to the pixel (Physics: gravity, steps and frictions with tmod), the keys read and the bads deciding 40 times
	// a second
	public static inline var TMOD = 0.8;
	public static var tmod:Float = TMOD;

	var picDebt:Float = 0;

	// the display (KadoKadeoManager: 32 steps a second, the clips shown between their places at the last two steps): 5
	// pictures fall on 4 steps, a step out of 4 shows two pictures (the moves would jolt 8 times a second); at the end
	// of a step the clips that moved show the game 0.75 picture behind the time instead (between their places at the
	// last two pictures: the steps show the game at even intervals), set back to their places before the next picture
	// (the game only reads its own)
	var before:Array<{mc:ASprite, x:Float, y:Float, px:Float, py:Float}> = [];
	var shown:Array<{mc:ASprite, x:Float, y:Float, sx:Float, sy:Float}> = [];

	public function update(delta:Float) {
		for (s in shown)
			if (s.mc._curState.x == s.sx && s.mc._curState.y == s.sy) {
				s.mc._curState.x = s.x;
				s.mc._curState.y = s.y;
			}
		shown = [];
		picDebt += 1 / TMOD;
		while (picDebt >= 1 - 1e-9) {
			picDebt -= 1;
			if (picDebt < 1 - 1e-9)
				keepPlaces();
			tmod = TMOD;
			picture();
			updateOrderMarks();
		}
		showBetween(picDebt + 0.25);
	}

	// the places of the clips before the last picture of a step (and their places shown at the last step: a clip shown
	// at once in the picture, Entity.snap, is not put back between its places)
	function keepPlaces() {
		before = [];
		function walk(o:Container) {
			for (c in o.children) {
				if (Std.is(c, ASprite)) {
					var a:ASprite = cast c;
					var p = a._prevState;
					before.push({
						mc: a,
						x: a._curState.x,
						y: a._curState.y,
						px: p == null ? Math.NaN : p.x,
						py: p == null ? Math.NaN : p.y
					});
				}
				if (Std.is(c, Container))
					walk(cast c);
			}
		}
		walk(scene);
	}

	// the clips that moved in the last picture shown at w between their last two places (not a jump of more than 3
	// cases: a new place)
	function showBetween(w:Float) {
		if (w < 1)
			for (b in before) {
				var a = b.mc;
				var c = a._curState;
				var p = a._prevState;
				if (p == null || p.x != b.px || p.y != b.py)
					continue;
				var dx = c.x - b.x;
				var dy = c.y - b.y;
				if ((dx == 0 && dy == 0) || Math.abs(dx) > Data.CASE_WIDTH * 3 || Math.abs(dy) > Data.CASE_HEIGHT * 3)
					continue;
				var sx = b.x + dx * w;
				var sy = b.y + dy * w;
				shown.push({mc: a, x: c.x, y: c.y, sx: sx, sy: sy});
				c.x = sx;
				c.y = sy;
			}
		before = [];
	}

	// MAIN (GameManager.main: one picture of the game, a cycle of tmod)
	function picture() {
		frameCount++;
		Snd.onCycle();

		// Mode.updateConstants
		if (!fl_lock)
			cycle += tmod;

		world.update();
		gi.update();
		for (a in anims.copy()) {
			a.update();
			if (a.fl_kill)
				anims.remove(a);
		}
		updateDarkness();

		var ek = KeyboardManager.isDown(69);
		if (ek && !detailKey)
			toggleDetail();
		detailKey = ek;
		var ik = KeyboardManager.isDown(73);
		if (ik && !intuitionKey)
			toggleIntuition();
		intuitionKey = ik;
		var ck = KeyboardManager.isDown(67);
		if (ck && !lookKeys[0])
			nextHead();
		lookKeys[0] = ck;
		var vk = KeyboardManager.isDown(86);
		if (vk && !lookKeys[1])
			nextSkin();
		lookKeys[1] = vk;
		updateOrderHint();

		#if debug
		// test keys, in the debug builds only (never in production): N the next level, L 5 levels further, K the bads
		// of the level killed
		var nk = KeyboardManager.isDown(78);
		if (nk && !debugN && !fl_lock && !fl_gameOver && pendingLevel == null && player != null && !player.fl_kill) {
			destroyList(Data.BAD);
			cleanKills();
			checkLevelClear();
			nextLevel();
		}
		debugN = nk;
		// L: 5 levels further
		var lk = KeyboardManager.isDown(76);
		if (lk && !debugL && !fl_lock && !fl_gameOver && pendingLevel == null && player != null && !player.fl_kill) {
			destroyList(Data.BAD);
			cleanKills();
			checkLevelClear();
			goto(world.currentId + 5);
		}
		debugL = lk;
		// K: the fruits killed (forceKill: the litchis in their shell too, their killHit only knocks them out)
		var kd = KeyboardManager.isDown(75);
		if (kd && !debugK && !fl_lock && !fl_gameOver)
			for (e in getList(Data.BAD_CLEAR).copy()) {
				var bad:Bad = cast e;
				if (!bad.fl_kill)
					bad.forceKill(bad.x < Data.GAME_WIDTH / 2 ? -6 : 6);
			}
		debugK = kd;
		// G: a life more
		var gk = KeyboardManager.isDown(71);
		if (gk && !debugG && !fl_lock && !fl_gameOver && player != null && !player.fl_kill) {
			player.lives++;
			gi.setLives(player.lives);
		}
		debugG = gk;
		#end

		if (pendingLevel != null) {
			fxMan.main();
			if (world.loadDone())
				nextLevelReady();
			return;
		}

		if (fl_gameOver) {
			// the game goes on behind the end of the game (the bads keep moving)
			fxMan.main();
			var l = getList(Data.ENTITY);
			var i = 0;
			while (i < l.length) {
				var e = l[i];
				if (!e.isType(Data.PLAYER)) {
					e.update();
					e.endUpdate();
				}
				i++;
			}
			cleanKills();
			if (!over) {
				gameOverTimer -= tmod;
				if (gameOverTimer <= 0)
					saveScore();
			}
			return;
		}

		if (fl_lock)
			return;

		runTimers();
		fxMan.main();

		// hurry up!
		huTimer += tmod;
		if (huState < Data.HU_STEPS.length && huTimer >= hurryStep(huState) / diffFactor)
			onHurryUp();
		if (huState >= Data.HU_STEPS.length) {
			if (countList(Data.HU_BAD) == 0)
				callEvilOne(Math.round(huTimer / Data.AUTO_ANGER));
		}

		// entities
		var l = getList(Data.ENTITY);
		var i = 0;
		while (i < l.length) {
			var e = l[i];
			e.update();
			e.endUpdate();
			if (fl_lock || fl_gameOver)
				break;
			i++;
		}

		cleanKills();
		// the levers Igor goes through (the script $enter of the original)
		if (!fl_lock && !fl_gameOver)
			world.checkLevers(player);
		if (!world.fl_lock && !fl_lock)
			checkLevelClear();
		// no more bad on the map (the dying ones gone too): no more letters
		if (!fl_clear && !lettersOff && countList(Data.BAD_CLEAR) == 0)
			removeLetters();

		// shaking (visual)
		if (shakeTimer > 0) {
			shakeTimer -= tmod;
			if (shakeTimer <= 0) {
				shakeTimer = 0;
				shakePower = 0;
			}
			gameMc._x = 10 + (Cs.vrnd(2) * 2 - 1) * (Cs.vrnd(Math.round(shakePower * 10)) / 10) * shakeTimer / shakeTotal;
			gameMc._y = (Cs.vrnd(2) * 2 - 1) * (Cs.vrnd(Math.round(shakePower * 10)) / 10) * shakeTimer / shakeTotal;
		} else {
			gameMc._x = 10;
			gameMc._y = 0;
		}

		// no exit while bads remain
		if (countList(Data.BAD_CLEAR) > 0 && fxMan.hasExit())
			fxMan.detachExit();
	}

	// GameMode.updateDarkness / holeUpdate: the level gets darker in the well, a light around Igor (bigger with the
	// candle, the bulb halves the darkness)
	var darkMc:Pic;
	var darkOver:Bool = false;
	var darkSnap:Bool = false;
	var dfactor:Float = 0;

	function updateDarkness() {
		if (world.current == null)
			return;
		var target:Float = world.current.darkness;
		if (player != null && player.specialMan.actives[26])
			target *= 0.5;
		if (dfactor < target)
			dfactor = Math.min(target, dfactor + 2);
		if (dfactor > target)
			dfactor = Math.max(target, dfactor - 2);
		if (dfactor <= 0) {
			if (darkMc != null)
				darkMc._visible = false;
			return;
		}
		if (darkMc == null) {
			darkMc = new Pic("darkness");
			dm.add(darkMc, Data.DP_BORDERS);
		}
		darkMc._visible = true;
		darkMc._alpha = dfactor;
		// going to the next level: the darkness over the old level going up and the new one coming, no light (it
		// is over the picture of the old level, at its depth; its hole far out of the screen)
		var trans = pendingLevel != null || world.fl_scrolling;
		if (trans != darkOver) {
			darkOver = trans;
			// (back from the change of level: at its place at once)
			darkSnap = !trans;
			if (darkMc.parent != null)
				darkMc.parent.removeChild(darkMc);
			dm.add(darkMc, trans ? Data.DP_SCROLLER : Data.DP_BORDERS);
		}
		if (trans) {
			darkMc._xscale = darkMc._yscale = 500;
			darkMc._x = Data.GAME_WIDTH / 2;
			darkMc._y = -1800;
			if (darkMc._prevState != null)
				darkMc._prevState.copyFrom(darkMc._curState);
			return;
		}
		var s = (player != null && player.specialMan.actives[68]) ? 150 : 100;
		darkMc._xscale = darkMc._yscale = s;
		if (player != null) {
			// (the picture of the darkness, 900 units wide, always over the whole field and the stone columns on its
			// sides: its hole stays near the edges when Igor is out of the field, coming in from the top)
			var half = 450 * s / 100;
			var tx = Math.max(Data.GAME_WIDTH + 30 - half, Math.min(half - 30, player.x));
			var ty = Math.max(Data.GAME_HEIGHT + 10 - half, Math.min(half - 10, player.y - Data.CASE_HEIGHT));
			if (player._visible && !world.fl_scrolling && !darkSnap) {
				darkMc._x += (tx - darkMc._x) * 0.5;
				darkMc._y += (ty - darkMc._y) * 0.5;
			} else {
				darkMc._x = tx;
				darkMc._y = ty;
				if (darkMc._prevState != null)
					darkMc._prevState.copyFrom(darkMc._curState);
			}
			darkSnap = false;
		}
	}

	// the first use of a shader compiles it (tens of ms of freeze): the colour matrix of the blinking bombs and
	// the masks of the tiles are drawn once now, off screen
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var holder = new Container();
		var s = new PixiSprite(Texture.WHITE);
		var f = new ColorMatrixFilter();
		s.filters = [f];
		holder.addChild(s);
		var rt:RenderTexture = (cast RenderTexture : Dynamic).create({width: 32, height: 32});
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy({children: true});
		rt.destroy(true);
	}

	public function destroy():Void {
		Snd.stopMusic();
		world.destroy();
	}
}

// hammer/StatsManager.mt: counters of the level
class Stats {
	var current:Array<Int>;

	public function new() {
		current = [for (i in 0...20) 0];
	}

	public function read(id:Int):Int {
		return current[id];
	}

	public function write(id:Int, n:Int) {
		current[id] = n;
	}

	public function inc(id:Int, n:Int) {
		current[id] += n;
	}

	public function reset() {
		current = [for (i in 0...20) 0];
	}
}
