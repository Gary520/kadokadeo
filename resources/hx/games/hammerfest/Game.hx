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
				// detailed effects, intuition (only pictures, recorded too: the replay shows them like the game)
				69,
				73,
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
		intuition = loadOpt("hammerfest.intuition");
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
		xFriction = Data.FRICTION_X;
		yFriction = Data.FRICTION_Y;
		gFriction = Data.FRICTION_GROUND;
		sFriction = Data.FRICTION_SLIDE;
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
		// ...&src=N: the first level remade from the hard level N of HardData
		var src = new js.html.URLSearchParams(js.Browser.location.search).get("src");
		if (src != null)
			LevelGen.forceSrc = Std.parseInt(src);
		// ...&kind=<name>: every level of that kind (LevelGen.KINDS)
		LevelGen.forceKind = new js.html.URLSearchParams(js.Browser.location.search).get("kind");
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
		}
		return bad;
	}

	var perfectOrder:Array<Int> = [];
	var perfectCount:Int = 0;

	public function attachItemName(id:Int) {
		var i = Art.SPECIAL_IDS.indexOf(id);
		if (i >= 0)
			fxMan.attachItemName(i);
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

	// INTUITION (a mode of the fans): a white outline on the bad to kill first for the order of the bads (the big
	// crystal), 3.5 s, then on the next one when it is dead; nothing more once the order is lost. Key I (kept in the
	// browser), only pictures
	public static var intuition:Bool = loadOpt("hammerfest.intuition");
	var intuitionKey:Bool = false;
	var orderLost:Bool = false;
	var hintBad:Bad = null;
	var hintTimer:Float = 0;

	static function loadOpt(k:String):Bool {
		try {
			return js.Browser.getLocalStorage().getItem(k) != "0";
		} catch (e:Dynamic) {
			return true;
		}
	}

	function toggleIntuition() {
		intuition = !intuition;
		if (!isReplay)
			try {
				js.Browser.getLocalStorage().setItem("hammerfest.intuition", intuition ? "1" : "0");
			} catch (e:Dynamic) {}
		fxMan.attachOptionMsg(intuition ? 3 : 4);
		if (intuition)
			showOrderHint();
		else
			clearOrderHint();
	}

	function showOrderHint() {
		clearOrderHint();
		if (!intuition || orderLost || perfectOrder.length == 0 || perfectCount < 2)
			return;
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
	}

	function updateOrderHint() {
		if (hintBad == null)
			return;
		hintTimer -= 1;
		if (hintTimer <= 0 || hintBad.fl_kill || hintBad.fl_destroy)
			clearOrderHint();
	}
	var detailKey:Bool = false;
	#if debug
	var debugN:Bool = false;
	var debugL:Bool = false;
	var debugK:Bool = false;
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
		scriptCycle = 0;
		timers = [];
		// the fruits get faster in the well, and angry from the start deep in it
		var depth = world.currentId;
		speedFactor = 1.0 + Math.min(0.5, depth * 0.03);
		var anger = depth < 6 ? 0 : Std.int(Math.min(2, (depth - 2) / 8));
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
		scriptCycle += 1;
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

	public function onExplode(x:Float, y:Float, radius:Float) {}

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

	// MAIN (one cycle of the game)
	public function update(delta:Float) {
		frameCount++;
		Snd.onCycle();

		// Mode.updateConstants
		if (!fl_lock)
			cycle += 1;

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
		var kd = KeyboardManager.isDown(75);
		if (kd && !debugK && !fl_lock && !fl_gameOver)
			for (e in getList(Data.BAD_CLEAR).copy()) {
				var bad:Bad = cast e;
				if (!bad.fl_kill)
					bad.killHit(bad.x < Data.GAME_WIDTH / 2 ? -6 : 6);
			}
		debugK = kd;
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
				gameOverTimer -= 1;
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
		huTimer += 1;
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
		if (!world.fl_lock && !fl_lock)
			checkLevelClear();
		// no more bad on the map (the dying ones gone too): no more letters
		if (!fl_clear && !lettersOff && countList(Data.BAD_CLEAR) == 0)
			removeLetters();

		// shaking (visual)
		if (shakeTimer > 0) {
			shakeTimer -= 1;
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
