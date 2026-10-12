package hammerfest;

// The sounds and the musics of the original (swf/_sounds.swf: the sounds of the game, sfx/*.mp3: the musics), played
// with Web Audio like the SoundManager of the original: a volume for each channel (the settings of the original at their
// highest: 50 for the player, the bombs, the items and the fields, 40 for the bads and the interface, music 32.5).
// The files are loaded at the start of the first game, a sound asked before its file is there is not played. Nothing is
// played while a replay is sought or caught up (many cycles at once), nor sped up more than twice. Key M: music on /
// off (the original), key B: the sounds on / off, each kept in the browser and shown at the top of the field; not keys
// of the game (not in the replays).
class Snd {
	public static inline var CHAN_PLAYER = 0;
	public static inline var CHAN_BOMB = 1;
	public static inline var CHAN_ITEM = 2;
	public static inline var CHAN_FIELD = 3;
	public static inline var CHAN_BAD = 4;
	public static inline var CHAN_INTERF = 5;

	static var CHAN_VOLUMES = [0.5, 0.5, 0.5, 0.5, 0.4, 0.4];
	static inline var MUSIC_VOLUME = 0.325;

	static var SOUNDS = [
		"sound_bad_death", "sound_bomb", "sound_bomb_black", "sound_bomb_blue", "sound_bomb_drop", "sound_bomb_green",
		"sound_field", "sound_hurry", "sound_item_score", "sound_item_special", "sound_item_supa", "sound_jump",
		"sound_kick", "sound_land", "sound_level_clear", "sound_player_death", "sound_pop", "sound_teleport"
	];
	// (the tracks of the original loader: 0 the game, 2 VITE ! (1: the boss, not in this game))
	static var MUSICS = ["music", null, "hurryUp"];

	static inline var BASE = "/assets/sound/hammerfest/";

	static var ctx:Dynamic = null;
	static var master:Dynamic;
	static var sfxGain:Dynamic;
	static var chans:Array<Dynamic>;
	static var musicGain:Dynamic;
	static var buffers:Map<String, Dynamic> = new Map();
	static var musicSrc:Dynamic = null;
	static var track:Int = -1; // track asked (-1: none)
	static var playing:Int = -1; // track playing
	static var musicFactor:Float = 1;
	static var lastCycle:Map<String, Int> = new Map();
	static var cycle:Int = 0;

	public static var musicOn(default, null):Bool = true;
	public static var soundsOn(default, null):Bool = true;

	// the audio of the page and the files, once
	public static function init() {
		#if debug
		untyped js.Browser.window.hammerfestSnd = Snd; // (test harness)
		#end
		if (ctx != null)
			return;
		var w:Dynamic = js.Browser.window;
		var C:Dynamic = w.AudioContext != null ? w.AudioContext : w.webkitAudioContext;
		if (C == null)
			return;
		try {
			ctx = js.Syntax.code("new {0}()", C);
		} catch (e:Dynamic) {
			ctx = null;
			return;
		}
		master = ctx.createGain();
		master.connect(ctx.destination);
		sfxGain = ctx.createGain();
		sfxGain.connect(master);
		chans = [];
		for (v in CHAN_VOLUMES) {
			var g = ctx.createGain();
			g.gain.value = v;
			g.connect(sfxGain);
			chans.push(g);
		}
		musicGain = ctx.createGain();
		musicGain.connect(master);
		try {
			musicOn = js.Browser.getLocalStorage().getItem("hammerfest.music") != "0";
			soundsOn = js.Browser.getLocalStorage().getItem("hammerfest.sounds") != "0";
		} catch (e:Dynamic) {}
		setMusicGain();
		setSoundsGain();
		for (s in SOUNDS)
			load(s);
		for (m in MUSICS)
			if (m != null)
				load(m);
		// (the browsers start the audio after an action of the player: a key, a touch)
		var resume = function(_) {
			if (ctx.state == "suspended")
				ctx.resume();
		};
		w.addEventListener("keydown", resume);
		w.addEventListener("pointerdown", resume);
		w.addEventListener("touchstart", resume);
		w.addEventListener("keydown", function(e:Dynamic) {
			if (e.repeat || Game.me == null || isTyping(e))
				return;
			if (e.keyCode == 77) {
				toggleMusic();
				showOption(musicOn ? 5 : 6);
			} else if (e.keyCode == 66) {
				toggleSounds();
				showOption(soundsOn ? 7 : 8);
			}
		});
		// (a replay paused: the music too)
		w.setInterval(function() {
			if (ctx.state == "closed")
				return;
			var paused = replayPaused();
			if (paused && ctx.state == "running")
				ctx.suspend();
			else if (!paused && ctx.state == "suspended" && untyped (w.navigator.userActivation == null || w.navigator.userActivation.hasBeenActive))
				ctx.resume();
		}, 250);
	}

	static function isTyping(e:Dynamic):Bool {
		var t:Dynamic = e.target;
		if (t == null || t.tagName == null)
			return false;
		var n = (t.tagName : String).toUpperCase();
		return n == "INPUT" || n == "TEXTAREA" || n == "SELECT" || t.isContentEditable;
	}

	static function load(name:String) {
		var w:Dynamic = js.Browser.window;
		var p:Dynamic = w.fetch(BASE + name + ".mp3").then(function(r:Dynamic) {
			return r.ok ? r.arrayBuffer() : null;
		}).then(function(data:Dynamic) {
			if (data == null)
				return;
			ctx.decodeAudioData(data, function(b:Dynamic) {
				buffers.set(name, b);
				// (the music asked before its file was there)
				if (track >= 0 && MUSICS[track] == name && playing != track)
					startMusic();
			}, function(_) {});
		});
		js.Syntax.code("{0}.catch(function () {})", p);
	}

	// (a replay sought or caught up, sped up: many cycles in a short time)
	static function quiet():Bool {
		var k = KadoKadeoManager.kkm;
		if (k == null)
			return false;
		return @:privateAccess (k.seekTarget != null || k.catchUpTarget != null || (k.replay.isPlayingReplay() && k.replaySpeed > 2));
	}

	static function replayPaused():Bool {
		var k = KadoKadeoManager.kkm;
		if (k == null)
			return false;
		return @:privateAccess (k.replay.isPlayingReplay() && k.replayPaused);
	}

	// one cycle of the game (Game.update): the same sound once a cycle at most (10 bads killed by a bomb: one sound)
	public static function onCycle() {
		cycle++;
	}

	public static function play(name:String, chan:Int) {
		if (ctx == null || !soundsOn || quiet())
			return;
		var b = buffers.get(name);
		if (b == null)
			return;
		var key = name + chan;
		if (lastCycle.get(key) == cycle)
			return;
		lastCycle.set(key, cycle);
		var src = ctx.createBufferSource();
		src.buffer = b;
		src.connect(chans[chan]);
		src.start(0);
	}

	// MUSIC (Mode.playMusic, stopMusic, setMusicVolume)
	public static function playMusic(id:Int) {
		if (ctx == null)
			return;
		track = id;
		startMusic();
	}

	public static function stopMusic() {
		track = -1;
		stopSource();
	}

	public static function currentTrack():Int {
		return track;
	}

	// (the pause of the original: half the volume)
	public static function setMusicVolume(f:Float) {
		musicFactor = f;
		setMusicGain();
	}

	public static function toggleMusic() {
		musicOn = !musicOn;
		try {
			js.Browser.getLocalStorage().setItem("hammerfest.music", musicOn ? "1" : "0");
		} catch (e:Dynamic) {}
		setMusicGain();
	}

	static function setMusicGain() {
		if (musicGain != null)
			musicGain.gain.value = musicOn ? MUSIC_VOLUME * musicFactor : 0;
	}

	public static function toggleSounds() {
		soundsOn = !soundsOn;
		try {
			js.Browser.getLocalStorage().setItem("hammerfest.sounds", soundsOn ? "1" : "0");
		} catch (e:Dynamic) {}
		setSoundsGain();
	}

	static function setSoundsGain() {
		if (sfxGain != null)
			sfxGain.gain.value = soundsOn ? 1 : 0;
	}

	// (the message at the top of the field, like the options of the game: "Musique : non"...)
	static function showOption(frame:Int) {
		var g = Game.me;
		if (g != null && g.fxMan != null)
			g.fxMan.attachOptionMsg(frame);
	}

	static function startMusic() {
		stopSource();
		if (track < 0)
			return;
		var b = buffers.get(MUSICS[track]);
		if (b == null)
			return;
		musicSrc = ctx.createBufferSource();
		musicSrc.buffer = b;
		musicSrc.loop = true;
		musicSrc.connect(musicGain);
		musicSrc.start(0);
		playing = track;
	}

	static function stopSource() {
		if (musicSrc != null) {
			try {
				musicSrc.stop(0);
			} catch (e:Dynamic) {}
			musicSrc.disconnect();
			musicSrc = null;
		}
		playing = -1;
	}
}
