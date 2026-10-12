package hammerfest;

import pixi.core.display.Container;
import pixi.core.graphics.Graphics;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.RenderTexture;

// hammer/levels/TeleporterData.mt: a teleporter (field -6) of the level
class TeleporterData {
	public var cx:Int;
	public var cy:Int;
	public var centerX:Float;
	public var centerY:Float;
	public var startX:Float;
	public var startY:Float;
	public var endX:Float;
	public var endY:Float;
	public var dir:Int;
	public var length:Int;
	public var fl_on:Bool;
	public var mc:Pic;
	public var podA:Pic;
	public var podB:Pic;

	public function new(x:Int, y:Int, len:Int, dir:Int) {
		cx = x;
		cy = y;
		this.dir = dir;
		length = len;
		fl_on = false;
		centerX = cx * Data.CASE_WIDTH + Data.CASE_WIDTH / 2;
		centerY = cy * Data.CASE_HEIGHT + Data.CASE_HEIGHT;
		startX = Entity.x_ctr(x);
		startY = Entity.y_ctr(y);
		if (dir == Data.HORIZONTAL) {
			centerX += length / 2 * Data.CASE_WIDTH;
			startX -= Data.CASE_WIDTH * 0.5;
		}
		if (dir == Data.VERTICAL) {
			centerY += length / 2 * Data.CASE_HEIGHT;
			startY -= Data.CASE_HEIGHT;
		}
		endX = startX;
		endY = startY;
		if (dir == Data.HORIZONTAL)
			endX += length * Data.CASE_WIDTH;
		else
			endY += length * Data.CASE_HEIGHT;
	}
}

// hammer/levels/GameMechanics.mt + SetManager + ViewManager + View: the current level (cases, flags of the AI of the
// bads, triggers of the entities), its picture and the scrolling to the next level.
class World {
	var game:Game;

	public var current:Levels.LevelData;
	public var currentId:Int;

	public var flagMap:Array<Array<Int>>; // flags of the AI
	public var fallMap:Array<Array<Int>>; // fall height per case
	public var triggers:Array<Array<Array<Entity>>>;

	public var fl_lock:Bool;

	public var teleporterList:Array<TeleporterData>;
	// fields (lasers) of the level, over its picture (the teleporters light up)
	var fieldsHolder:ASprite;
	var oldFields:ASprite;
	var fieldPics:Array<Pic> = [];
	// devices of the level (levers, stone blocks: the scripts of the original), over its picture; the cases of the
	// blocks are drawn by their pictures, not as tiles
	var devicesHolder:ASprite;
	var oldDevices:ASprite;
	var leverPics:Array<Pic> = [];
	var blockPics:Array<Pic> = [];
	var endPics:Array<Pic> = [];
	public var leverDone:Array<Bool> = [];
	public var blockDone:Array<Bool> = [];
	var endDone:Bool = false;

	// view: the picture of the level (background + tiles, drawn once in a texture like the bitmap cache of the
	// original), the stone columns on the sides, the picture of the previous level while scrolling
	var view:PixiSprite;
	var viewTex:RenderTexture;
	var viewHolder:ASprite;
	var fake:PixiSprite;
	var fakeTex:RenderTexture;
	var fakeHolder:ASprite;
	// stone columns of the level and of the previous one (they scroll with their level)
	var sides:ASprite;
	var fakeSides:ASprite;
	// black screen of the jumps (umbrellas), loading bar of the transitions
	var black:Graphics;
	var loadBar:ASprite;
	var loadFill:Pic;
	var loadCpt:Float;

	public var fl_scrolling:Bool;
	public var fl_fading:Bool;

	var scrollCpt:Float;
	var fadeCpt:Float;
	var visited:Array<Bool>;

	public function new(g:Game) {
		game = g;
		fl_lock = true;
		fl_scrolling = false;
		currentId = -1;
		visited = [];
		triggers = [];
		for (i in 0...Data.LEVEL_WIDTH) {
			triggers[i] = [];
			for (j in 0...Data.LEVEL_HEIGHT)
				triggers[i][j] = [];
		}
		resetIA();

		viewHolder = new ASprite();
		game.dm.add(viewHolder, Data.DP_BACK_LAYER);
		fakeHolder = new ASprite();
		game.dm.add(fakeHolder, Data.DP_SCROLLER);
		sides = makeSides();
		game.dm.add(sides, Data.DP_BORDERS);
		fakeSides = makeSides();
		fakeHolder.addChild(fakeSides);
		fakeSides._visible = false;
		black = new Graphics();
		black.beginFill(0x000000);
		black.drawRect(-40, -40, Data.GAME_WIDTH + 80, Data.GAME_HEIGHT + 80);
		black.endFill();
		black.visible = false;
		var bh = new ASprite();
		bh.addChild(black);
		game.dm.add(bh, Data.DP_BORDERS);
		fl_fading = false;
		loadCpt = -1;
		teleporterList = [];
	}

	// ViewManager: the stone columns at 5 and DOC_WIDTH - 5 in the pixels of the game, at the size of the original
	// (the field is scaled), cut at the height of the field
	function makeSides():ASprite {
		var s = new ASprite();
		var k = 100 / Data.GAME_SCALE;
		var l = new Pic("sides");
		l._x = -5 / Data.GAME_SCALE;
		l._xscale = l._yscale = k;
		s.addChild(l);
		var r = new Pic("sides");
		r._x = Data.GAME_WIDTH + 5 / Data.GAME_SCALE;
		r._xscale = r._yscale = k;
		s.addChild(r);
		return s;
	}

	// GameManager.progress: the red bar while the next level is prepared (the AI of its cases: 30 per cycle)
	function showLoad(ratio:Float) {
		if (ratio >= 1) {
			if (loadBar != null) {
				if (loadBar.parent != null)
					loadBar.parent.removeChild(loadBar);
				loadBar.destroy({children: true});
				loadBar = null;
			}
			return;
		}
		if (loadBar == null) {
			loadBar = new ASprite();
			loadBar.addChild(new Pic("loadBar"));
			loadFill = new Pic("loadBarFill");
			loadFill._x = Art.LOADBAR_X;
			loadBar.addChild(loadFill);
			loadBar._x = Data.GAME_WIDTH / 2;
			loadBar._y = Data.GAME_HEIGHT - 40;
			game.dm.add(loadBar, Data.DP_TOP);
		}
		loadFill._xscale = ratio * 100;
	}

	public function lock() {
		fl_lock = true;
	}

	public function unlock() {
		fl_lock = false;
	}

	public function isVisited():Bool {
		return visited[currentId] == true;
	}

	// DATA
	public function goto(id:Int, ?fade:Bool = false) {
		// (the picture of the old level with its background)
		detachSpecialBg();
		if (currentId >= 0)
			visited[currentId] = true;
		resetIA();
		var first = currentId < 0;
		currentId = id;
		current = Levels.get(id);
		parseIA();
		if (first) {
			// (the game starts the first level itself)
			drawView();
			drawDevices();
			setViewY(0);
		} else if (fade) {
			// jump (umbrellas): a black screen with the loading bar, then the new level at once
			if (fieldsHolder != null) {
				fieldsHolder.parent.removeChild(fieldsHolder);
				fieldsHolder.destroy({children: true});
				fieldsHolder = null;
			}
			if (devicesHolder != null) {
				devicesHolder.parent.removeChild(devicesHolder);
				devicesHolder.destroy({children: true});
				devicesHolder = null;
			}
			drawView();
			drawDevices();
			setViewY(0);
			viewHolder.updateState();
			black.visible = true;
			black.alpha = 1;
			fl_fading = true;
			loadCpt = 0;
		} else {
			// the picture of the old level goes up, the new one comes from below
			if (fakeTex != null)
				fakeTex.destroy(true);
			fakeTex = viewTex;
			viewTex = null;
			if (fake != null)
				fake.destroy();
			fake = new PixiSprite(fakeTex);
			fake.scale.set(1 / RT, 1 / RT);
			fake.x = -10;
			fakeHolder.addChildAt(fake, 0);
			if (fieldsHolder != null) {
				// the lasers of the old level go up with it
				fakeHolder.addChildAt(fieldsHolder, 1);
				oldFields = fieldsHolder;
				fieldsHolder = null;
			}
			if (devicesHolder != null) {
				// (its devices too)
				fakeHolder.addChildAt(devicesHolder, 1);
				oldDevices = devicesHolder;
				devicesHolder = null;
			}
			fakeHolder._y = 0;
			fakeHolder.updateState();
			drawView();
			drawDevices();
			setViewY(Data.GAME_HEIGHT);
			viewHolder.updateState();
			sides.updateState();
			fakeSides._visible = true;
			scrollCpt = 0;
			fl_scrolling = true;
		}
	}

	// the loading bar of the next level (before its scrolling)
	public function startLoad() {
		loadCpt = 0;
	}

	public function loadDone():Bool {
		return loadCpt < 0;
	}

	function setViewY(y:Float) {
		viewHolder._y = y;
		sides._y = y;
	}

	public function inBound(cx:Int, cy:Int):Bool {
		return cx >= 0 && cx < Data.LEVEL_WIDTH && cy >= 0 && cy < Data.LEVEL_HEIGHT;
	}

	public inline function map(cx:Int, cy:Int):Int {
		return current.map[cx][cy];
	}

	public function getCase(cx:Int, cy:Int):Int {
		if (inBound(cx, cy)) {
			if (cy == 0) {
				// the tiles at the top are not grounds
				return current.map[cx][0] > 0 ? Data.WALL : 0;
			}
			return current.map[cx][cy];
		} else if (cy < 0 && cx >= 0 && cx < Data.LEVEL_WIDTH) {
			return current.map[cx][0] > 0 ? Data.WALL : 0;
		} else {
			return Data.OUT_WALL; // out of the screen at the bottom, left, right
		}
	}

	// first ground under a case
	public function getGround(cx:Int, cy:Int):{x:Int, y:Int} {
		var ty = cy;
		for (n in 0...Data.LEVEL_HEIGHT + 1) {
			if (ty > 0 && getCase(cx, ty) == Data.GROUND)
				return {x: cx, y: ty - 1};
			if (ty >= Data.LEVEL_HEIGHT)
				ty = 0;
			ty++;
		}
		return {x: cx, y: cy};
	}

	// AI
	function resetIA() {
		flagMap = [];
		fallMap = [];
		for (i in 0...Data.LEVEL_WIDTH) {
			flagMap[i] = [];
			fallMap[i] = [];
			for (j in 0...Data.LEVEL_HEIGHT) {
				flagMap[i][j] = 0;
				fallMap[i][j] = -1;
			}
		}
	}

	public function checkFlag(x:Int, y:Int, flag:Int):Bool {
		if (x >= 0 && x < Data.LEVEL_WIDTH && y >= 0 && y < Data.LEVEL_HEIGHT)
			return (flagMap[x][y] & flag) > 0;
		return false;
	}

	public function fallAt(x:Int, y:Int):Int {
		if (x >= 0 && x < Data.LEVEL_WIDTH && y >= 0 && y < Data.LEVEL_HEIGHT)
			return fallMap[x][y];
		return -1;
	}

	// GameMechanics.parseCurrentIA (all at once)
	function parseIA() {
		for (cy in 0...Data.LEVEL_HEIGHT) {
			for (cx in 0...Data.LEVEL_WIDTH) {
				var flags = 0;
				// normal tile
				if (getCase(cx, cy + 1) == Data.GROUND) {
					flags |= Data.IA_TILE_TOP;
					// vertical jump zone
					if (getCase(cx, cy - Data.IA_VJUMP) == Data.GROUND && getCase(cx, cy - Data.IA_VJUMP - 1) <= 0)
						flags |= Data.IA_JUMP_UP;
				}
				if (getCase(cx, cy) == Data.GROUND && getCase(cx, cy - 1) <= 0)
					flags |= Data.IA_TILE;
				// allowed fall point (-1 if in the void)
				var fallHeight = checkSecureFall(cx, cy);
				fallMap[cx][cy] = fallHeight;
				if (fallHeight >= 0)
					flags |= Data.IA_ALLOW_FALL;
				// jump down point (under a tile)
				if (getCase(cx, cy) == 0 && getCase(cx, cy + 1) == Data.GROUND) {
					fallHeight = checkSecureFall(cx, cy + 2);
					if (fallHeight >= 0)
						flags |= Data.IA_JUMP_DOWN;
				}
				// edge of a tile
				if (getCase(cx, cy + 1) == Data.GROUND && (getCase(cx - 1, cy + 1) <= 0 || getCase(cx + 1, cy + 1) <= 0))
					flags |= Data.IA_BORDER;
				// case next to a tile from which the bads can fall
				if (getCase(cx, cy + 1) <= 0 && (getCase(cx - 1, cy + 1) == Data.GROUND || getCase(cx + 1, cy + 1) == Data.GROUND))
					flags |= Data.IA_FALL_SPOT;
				// small tile
				if ((flags & Data.IA_BORDER) > 0) {
					if (getCase(cx - 1, cy + 1) != Data.GROUND && getCase(cx + 1, cy + 1) != Data.GROUND)
						flags |= Data.IA_SMALL_SPOT;
				}
				// foot of a wall
				if ((flags & Data.IA_TILE_TOP) > 0) {
					var maxHeight = 1;
					var d = 1;
					while (d <= 5) {
						if (getCase(cx, cy - d) <= 0)
							maxHeight++;
						else
							d = 999;
						d++;
					}
					if (maxHeight > 0) {
						if (getCase(cx - 1, cy) > 0) {
							var h = getWallHeight(cx - 1, cy, Data.IA_CLIMB);
							if (h != null && h < maxHeight && cy - h >= 0)
								flags |= Data.IA_CLIMB_LEFT;
						}
						if (getCase(cx + 1, cy) > 0) {
							var h = getWallHeight(cx + 1, cy, Data.IA_CLIMB);
							if (h != null && h < maxHeight && cy - h >= 0)
								flags |= Data.IA_CLIMB_RIGHT;
						}
					}
				}
				// stairs over the void
				if ((flags & Data.IA_FALL_SPOT) > 0) {
					var maxHeight = 1;
					var d = 1;
					while (d <= 5) {
						if (getCase(cx, cy - d) <= 0) {
							maxHeight++;
						} else {
							maxHeight += 2;
							d = 999;
						}
						d++;
					}
					if (maxHeight > 0) {
						if (getCase(cx + 1, cy + 1) == Data.GROUND) {
							var h = getStepHeight(cx, cy, Data.IA_CLIMB);
							if (h != null && h < maxHeight) {
								if (checkFlag(cx, cy - h, Data.IA_BORDER) && checkFlag(cx + 1, cy - h, Data.IA_FALL_SPOT))
									flags |= Data.IA_CLIMB_LEFT;
							}
						}
						if (getCase(cx - 1, cy + 1) == Data.GROUND) {
							var h = getStepHeight(cx, cy, Data.IA_CLIMB);
							if (h != null && h < maxHeight) {
								if (checkFlag(cx, cy - h, Data.IA_BORDER) && checkFlag(cx - 1, cy - h, Data.IA_FALL_SPOT))
									flags |= Data.IA_CLIMB_RIGHT;
							}
						}
					}
				}
				// edges of tiles: jumps
				if ((flags & Data.IA_FALL_SPOT) > 0) {
					if (getCase(cx + 1, cy + 1) == Data.GROUND && getCase(cx - Data.IA_HJUMP, cy + 1) == Data.GROUND) {
						if (getCase(cx - 1, cy) <= 0)
							flags |= Data.IA_JUMP_LEFT;
					}
					if (getCase(cx - 1, cy + 1) == Data.GROUND && getCase(cx + Data.IA_HJUMP, cy + 1) == Data.GROUND) {
						if (getCase(cx + 1, cy) <= 0)
							flags |= Data.IA_JUMP_RIGHT;
					}
				}
				flagMap[cx][cy] = flags;
			}
		}
	}

	// height of a safe fall from a case (-1 in the void)
	function checkSecureFall(cx:Int, cy:Int):Int {
		if (cx < 0 || cx >= Data.LEVEL_WIDTH)
			return -1;
		if (cy >= 0 && cy < Data.LEVEL_HEIGHT) {
			if (current.map[cx][cy] == Data.GROUND)
				return -1;
			if (current.map[cx][cy] == Data.WALL)
				return -1;
		}
		if (cy - 1 >= 0 && cy - 1 < Data.LEVEL_HEIGHT && (flagMap[cx][cy - 1] & Data.IA_ALLOW_FALL) > 0)
			return fallMap[cx][cy - 1] - 1;
		var i = cy + 1;
		var h = 0;
		while (i < Data.LEVEL_HEIGHT) {
			if (i >= 0 && current.map[cx][i] == Data.GROUND)
				return h;
			i++;
			h++;
		}
		return -1;
	}

	public function getWallHeight(cx:Int, cy:Int, max:Int):Null<Int> {
		var h = 0;
		while (getCase(cx, cy - h) > 0 && h < max)
			h++;
		return h >= max ? null : h;
	}

	public function getStepHeight(cx:Int, cy:Int, max:Int):Null<Int> {
		var h = 0;
		while (getCase(cx, cy - h) <= 0 && h < max)
			h++;
		h++;
		return h >= max ? null : h;
	}

	// VIEW
	function isWall(cx:Int, cy:Int):Bool {
		if (cx < 0 || cx >= Data.LEVEL_WIDTH || cy < 0 || cy >= Data.LEVEL_HEIGHT)
			return false;
		return drawn(cx, cy) && (cx - 1 < 0 || !drawn(cx - 1, cy)) && (cx + 1 >= Data.LEVEL_WIDTH || !drawn(cx + 1, cy));
	}

	inline function drawn(x:Int, y:Int):Bool {
		return current.map[x][y] > 0 && !hidden(x, y);
	}

	// a case drawn by the picture of a stone block, not as a tile
	function hidden(cx:Int, cy:Int):Bool {
		var c = current;
		if (c.blocks != null)
			for (i in 0...c.blocks.length) {
				var b = c.blocks[i];
				if (blockDone[i] != true && cx >= b.x && cx <= b.x + 1 && cy >= b.y && cy <= b.y + 1)
					return true;
			}
		if (c.endBlocks != null && !endDone)
			for (b in c.endBlocks)
				if (cx >= b.x && cx <= b.x + 1 && cy >= b.y && cy <= b.y + 1)
					return true;
		return false;
	}

	// DEVICES (scripts of the original: $e_mc $levier / $block / $blockEnd, triggers $enter / $exp / $end)
	function drawDevices() {
		devicesHolder = new ASprite();
		viewHolder.addChild(devicesHolder);
		leverPics = [];
		blockPics = [];
		endPics = [];
		var c = current;
		leverDone = c.levers == null ? [] : [for (l in c.levers) false];
		blockDone = c.blocks == null ? [] : [for (b in c.blocks) false];
		endDone = false;
		// (the pictures: a block from its left side at mid height, a lever standing on its ground)
		if (c.blocks != null)
			for (b in c.blocks)
				blockPics.push(devicePic("block", 1, b.x * Data.CASE_WIDTH, b.y * Data.CASE_HEIGHT + Data.CASE_HEIGHT));
		if (c.endBlocks != null)
			for (b in c.endBlocks)
				endPics.push(devicePic("blockEnd", 1, b.x * Data.CASE_WIDTH, b.y * Data.CASE_HEIGHT + Data.CASE_HEIGHT));
		if (c.levers != null)
			for (l in c.levers)
				leverPics.push(devicePic("lever", 1, l.x * Data.CASE_WIDTH, (l.y + 1) * Data.CASE_HEIGHT));
		devicesHolder.updateState();
	}

	function devicePic(name:String, f:Int, x:Float, y:Float):Pic {
		var p = new Pic(name, f);
		p._x = x;
		p._y = y;
		devicesHolder.addChild(p);
		return p;
	}

	// Igor in the case of a lever: it is pulled (once), its cases change
	public function checkLevers(p:Player) {
		var c = current;
		if (c.levers == null || p == null || p.fl_kill || fl_lock)
			return;
		for (i in 0...c.levers.length) {
			var l = c.levers[i];
			if (leverDone[i] || p.cx != l.x || p.cy != l.y)
				continue;
			leverDone[i] = true;
			leverPics[i].show(2);
			Snd.play("sound_kick", Snd.CHAN_FIELD);
			var cells:Array<{x:Int, y:Int}> = [for (a in l.add) {x: a.x, y: a.y}].concat(l.rem).concat(l.spikes);
			for (k in cells)
				game.fxMan.inGameParticles(Data.PARTICLE_STONE, Entity.x_ctr(k.x), Entity.y_ctr(k.y) - Data.CASE_HEIGHT * 0.5, 2);
			if (cells.length > 0)
				game.fxMan.attachExplosion(Entity.x_ctr(cells[0].x), Entity.y_ctr(cells[0].y) - Data.CASE_HEIGHT * 0.5, Data.CASE_WIDTH * 1.5);
			applyCases(l.add, l.rem);
			for (s in l.spikes)
				game.attachBad(Data.BAD_SPEAR, Entity.x_ctr(s.x) - Data.CASE_WIDTH * 0.5, Entity.y_ctr(s.y - 1));
			if (l.spikes.length > 0)
				game.shake(Data.SECOND * 0.3, 2);
		}
	}

	// a bomb of Igor exploding (Game.onExplode, the script $exp of the original): the stone blocks it reaches break
	public function onExplode(x:Float, y:Float, r:Float) {
		var c = current;
		if (c.blocks == null)
			return;
		for (i in 0...c.blocks.length) {
			if (blockDone[i])
				continue;
			var b = c.blocks[i];
			var hit = false;
			for (k in 0...4) {
				var dx = Entity.x_ctr(b.x + (k & 1)) - x;
				var dy = Entity.y_ctr(b.y + (k >> 1)) - Data.CASE_HEIGHT * 0.5 - y;
				if (dx * dx + dy * dy <= r * r)
					hit = true;
			}
			if (hit)
				breakBlock(i);
		}
	}

	function breakBlock(i:Int) {
		blockDone[i] = true;
		var b = current.blocks[i];
		dropBlock(blockPics[i], b);
		Snd.play("sound_bomb_black", Snd.CHAN_FIELD);
		game.shake(Data.SECOND * 0.3, 2);
		applyCases([], [for (k in 0...4) {x: b.x + (k & 1), y: b.y + (k >> 1)}]);
	}

	// the picture of a block goes, its fall plays ($blockFall), stones fly
	function dropBlock(p:Pic, b:{x:Int, y:Int}) {
		if (p != null && p.parent != null)
			p.parent.removeChild(p);
		var x = b.x * Data.CASE_WIDTH;
		var y = b.y * Data.CASE_HEIGHT + Data.CASE_HEIGHT;
		game.fxMan.attachFx(x, y, "blockFall");
		game.fxMan.inGameParticles(Data.PARTICLE_STONE, x + Data.CASE_WIDTH, y, 4);
	}

	// cases of the map changed by a device: grounds and walls again (Levels.get), the flags of the AI, the picture
	function applyCases(add:Array<{x:Int, y:Int, v:Int}>, rem:Array<{x:Int, y:Int}>) {
		var m = current.map;
		for (r in rem)
			if (inBound(r.x, r.y))
				m[r.x][r.y] = 0;
		for (a in add)
			if (inBound(a.x, a.y))
				m[a.x][a.y] = a.v > 0 ? Data.GROUND : a.v;
		for (cx in 0...Data.LEVEL_WIDTH)
			for (cy in 0...Data.LEVEL_HEIGHT)
				if (m[cx][cy] > 0)
					m[cx][cy] = (cy > 0 && m[cx][cy - 1] > 0) ? Data.WALL : Data.GROUND;
		resetIA();
		parseIA();
		var old = viewTex;
		drawView(specialBg == null, true);
		if (old != null)
			old.destroy(true);
	}

	// background + tiles of the level, drawn once in a texture (View.attach)
	function drawView(?withBg:Bool = true, ?withFields:Bool = true) {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var root = new Container();
		root.scale.set(RT, RT);
		var c = new Container();
		c.x = 10;
		root.addChild(c);
		// View: the skins of the level (skinTiles: tile + 100 * column when they differ)
		if (withBg) {
			var bgi = Art.BG_SKINS.indexOf(current.skinBg);
			var bg = new Pic("bg", bgi < 0 ? 1 : bgi + 1);
			place(bg, 0, 0);
			c.addChild(bg);
		}
		var tileSkin = current.skinTiles >= 100 ? current.skinTiles % 100 : current.skinTiles;
		var colSkin = current.skinTiles >= 100 ? Std.int(current.skinTiles / 100) : current.skinTiles;
		var m = current.map;
		for (y in 0...Data.LEVEL_HEIGHT) {
			var tracing = false;
			var startX = 0;
			for (x in 0...Data.LEVEL_WIDTH + 1) {
				var v = x < Data.LEVEL_WIDTH ? m[x][y] : 0;
				if (v > 0 && hidden(x, y))
					v = 0;
				if (!tracing && v > 0) {
					startX = x;
					tracing = true;
				}
				if (tracing && (v <= 0 || x == Data.LEVEL_WIDTH)) {
					var wid = x - startX;
					if (wid == 1 && isWall(x - 1, y)) {
						if (!isWall(x - 1, y - 1)) {
							var hei = 0;
							var vty = y;
							while (isWall(x - 1, vty)) {
								hei++;
								vty++;
							}
							if (hei == 1)
								c.addChild(tile(startX, y, 1, tileSkin, false));
							else
								c.addChild(tile(startX, y, hei, colSkin, true));
						}
					} else {
						c.addChild(tile(startX, y, wid, tileSkin, false));
					}
					tracing = false;
				}
			}
		}
		viewTex = (cast RenderTexture : Dynamic).create({
			width: Math.ceil((Data.GAME_WIDTH + 20) * RT),
			height: Math.ceil(Data.GAME_HEIGHT * RT)
		});
		renderer.render(root, {renderTexture: viewTex, clear: true});
		root.destroy({children: true});
		if (view != null)
			view.destroy();
		view = new PixiSprite(viewTex);
		view.scale.set(1 / RT, 1 / RT);
		view.x = -10;
		viewHolder.addChildAt(view, specialBg != null && specialBg.parent == viewHolder ? 1 : 0);
		if (withFields)
			drawFields();
	}

	// the cases opened when the level is clear (script $end of the original levels): the way down, with a blast
	public function openEnd() {
		var l = current.openAtEnd;
		if (l == null || l.length == 0)
			return;
		if (current.endBlocks != null && !endDone) {
			endDone = true;
			for (i in 0...current.endBlocks.length)
				dropBlock(endPics[i], current.endBlocks[i]);
		}
		var m = current.map;
		for (p in l) {
			if (p.x < 0 || p.x >= Data.LEVEL_WIDTH || p.y < 0 || p.y >= Data.LEVEL_HEIGHT)
				continue;
			m[p.x][p.y] = 0;
			game.fxMan.inGameParticles(Data.PARTICLE_STONE, Entity.x_ctr(p.x), Entity.y_ctr(p.y) - Data.CASE_HEIGHT * 0.5, 3);
		}
		// (a wall under an opened case is the top of a ground now)
		for (p in l)
			if (p.y + 1 < Data.LEVEL_HEIGHT && m[p.x][p.y + 1] == Data.WALL)
				m[p.x][p.y + 1] = Data.GROUND;
		var p0 = l[0];
		game.fxMan.attachExplosion(Entity.x_ctr(p0.x), Entity.y_ctr(p0.y) - Data.CASE_HEIGHT * 0.5, Data.CASE_WIDTH * 2);
		game.shake(Data.SECOND * 0.4, 3);
		var old = viewTex;
		drawView();
		if (old != null)
			old.destroy(true);
	}

	// View.attachField: the fields of the level (vertical or horizontal runs of the same id)
	function drawFields() {
		if (fieldsHolder != null) {
			if (fieldsHolder.parent != null)
				fieldsHolder.parent.removeChild(fieldsHolder);
			fieldsHolder.destroy({children: true});
		}
		fieldsHolder = new ASprite();
		viewHolder.addChild(fieldsHolder);
		teleporterList = [];
		fieldPics = [];
		var m = current.map;
		var done = [for (x in 0...Data.LEVEL_WIDTH) [for (y in 0...Data.LEVEL_HEIGHT) false]];
		var fs = Art.FIELD_SKIN;
		var sz = Art.SIZE.get("field_1");
		var flen = sz == null ? 60 : sz[1];
		for (sy in 0...Data.LEVEL_HEIGHT) {
			for (sx in 0...Data.LEVEL_WIDTH) {
				var id = m[sx][sy];
				if (id >= 0 || done[sx][sy])
					continue;
				var p = new Pic("field_" + Std.int(Math.min(11, -id)));
				fieldPics.push(p);
				var len = 1;
				var dir = Data.HORIZONTAL;
				if (sx + 1 < Data.LEVEL_WIDTH && m[sx + 1][sy] == id) {
					var i = sx;
					while (i < Data.LEVEL_WIDTH && m[i][sy] == id) {
						done[i][sy] = true;
						i++;
					}
					len = i - sx;
				} else if (sy + 1 < Data.LEVEL_HEIGHT && m[sx][sy + 1] == id) {
					var i = sy;
					while (i < Data.LEVEL_HEIGHT && m[sx][i] == id) {
						done[sx][i] = true;
						i++;
					}
					len = i - sy;
					dir = Data.VERTICAL;
				}
				done[sx][sy] = true;
				if (dir == Data.VERTICAL) {
					p._x = sx * Data.CASE_WIDTH + fs[4];
					p._y = sy * Data.CASE_HEIGHT + fs[5];
					p._xscale = fs[0] * 100;
					p._yscale = Data.CASE_HEIGHT * len / flen * 100;
				} else {
					// frame 2 of the field: the skin turned (-90)
					p._rotation = -90;
					p._x = sx * Data.CASE_WIDTH;
					p._y = sy * Data.CASE_HEIGHT + 17.7;
					p._yscale = Data.CASE_WIDTH * len / flen * 100;
				}
				fieldsHolder.addChild(p);
				if (id == Data.FIELD_TELEPORT) {
					var td = new TeleporterData(sx, sy, len, dir);
					td.mc = p;
					td.podA = new Pic("podOff");
					fieldPics.push(td.podA);
					td.podA._x = td.startX;
					td.podA._y = td.startY;
					td.podB = new Pic("podOff");
					fieldPics.push(td.podB);
					td.podB._x = td.endX;
					td.podB._y = td.endY;
					td.podB._rotation = 180;
					if (dir == Data.HORIZONTAL) {
						td.podA._y -= Data.CASE_HEIGHT * 0.5;
						td.podB._y -= Data.CASE_HEIGHT * 0.5;
					} else {
						td.podA._rotation += 90;
						td.podB._rotation += 90;
					}
					fieldsHolder.addChild(td.podA);
					fieldsHolder.addChild(td.podB);
					teleporterList.push(td);
				}
			}
		}
		fieldsHolder.updateState();
	}

	public function showField(td:TeleporterData) {
		if (td.fl_on)
			return;
		td.fl_on = true;
		td.mc.setAnim("fieldOn_6");
		td.podA.setAnim("podOn");
		td.podB.setAnim("podOn");
	}

	public function hideField(td:TeleporterData) {
		if (!td.fl_on)
			return;
		td.fl_on = false;
		td.mc.setAnim("field_6");
		td.podA.setAnim("podOff");
		td.podB.setAnim("podOff");
	}

	// GameMechanics.getTeleporter: the teleporter of a case (null: the one just used)
	public function getTeleporter(e:Physics, cx:Int, cy:Int):TeleporterData {
		if (getCase(cx, cy) != Data.FIELD_TELEPORT)
			return null;
		var out:TeleporterData = null;
		for (td in teleporterList) {
			if (td.dir == Data.HORIZONTAL && cx >= td.cx && cx < td.cx + td.length && cy == td.cy) {
				out = td;
				break;
			}
			if (td.dir == Data.VERTICAL && cy >= td.cy && cy < td.cy + td.length && cx == td.cx) {
				out = td;
				break;
			}
		}
		if (out == e.lastTeleporter)
			return null;
		return out;
	}

	// GameMechanics.getNextTeleporter: the facing one, else one of the same size, else one at random
	public function getNextTeleporter(start:TeleporterData):{fl_rand:Bool, td:TeleporterData} {
		var out:TeleporterData = null;
		var fl_rand = false;
		for (td in teleporterList) {
			if (td.cx != start.cx || td.cy != start.cy) {
				if (start.dir == Data.HORIZONTAL && start.dir == td.dir && start.cx == td.cx && start.length == td.length) {
					out = td;
					break;
				}
				if (start.dir == Data.VERTICAL && start.dir == td.dir && start.cy == td.cy && start.length == td.length) {
					out = td;
					break;
				}
			}
		}
		if (out == null) {
			fl_rand = true;
			var l = [
				for (td in teleporterList)
					if ((td.cx != start.cx || td.cy != start.cy) && td.dir == start.dir && td.length == start.length) td
			];
			if (l.length > 0) {
				out = l[Cs.rnd(l.length)];
				if (l.length == 1)
					fl_rand = false;
			}
		}
		if (out == null) {
			fl_rand = true;
			var l = [for (td in teleporterList) if (td.cx != start.cx || td.cy != start.cy) td];
			if (l.length > 0)
				out = l[Cs.rnd(l.length)];
		}
		if (out == null)
			return null;
		return {fl_rand: fl_rand, td: out};
	}

	// (Player.showTeleporters: the teleporter it leads to, when it is not drawn at random)
	public function peekNextTeleporter(td:TeleporterData):TeleporterData {
		var n = getNextTeleporter(td);
		return (n != null && !n.fl_rand) ? n.td : null;
	}


	// tile.mc of the original: the skin strip masked to the length of the tile, its shadow, the end of the tile;
	// a column is the same tile turned (rotation 90, yscale -100)
	function tile(sx:Int, sy:Int, wid:Int, skin:Int, column:Bool):Container {
		var t = new Container();
		t.x = sx * Data.CASE_WIDTH;
		t.y = sy * Data.CASE_HEIGHT;
		if (column) {
			t.scale.y = -1;
			t.rotation = Math.PI / 2;
		}
		var w = wid * Data.CASE_WIDTH;
		// maskTile._width = w (scaled from its registration point)
		var mk = Art.TILE_MASK;
		var reg = Art.TILE_MASK_REG[0];
		var sc = w / (mk[2] - mk[0]);
		var mask = new Graphics();
		mask.beginFill(0xffffff);
		// (2 units more, under the end: the edges of the textures do not meet exactly at this scale)
		mask.drawRect(reg + (mk[0] - reg) * sc, mk[1], w + 2, mk[3] - mk[1]);
		mask.endFill();
		var masked = new Container();
		masked.addChild(place(new Pic("tileShadow"), 0, 0));
		masked.addChild(place(new Pic("tileSkin", skinIndex(skin)), 0, 0));
		masked.mask = mask;
		t.addChild(mask);
		t.addChild(masked);
		t.addChild(place(new Pic("tileEndShadow"), w, 0));
		t.addChild(place(new Pic("tileEnd", skinIndex(skin)), w, 0));
		return t;
	}

	// a picture drawn once in the texture of the level: its PIXI transform at once
	static function place(p:Pic, x:Float, y:Float):Pic {
		p._x = x;
		p._y = y;
		p.updateState();
		p.updateGraphics(1);
		return p;
	}

	static inline var RT = Game.K * Data.GAME_SCALE;

	static function skinIndex(skin:Int):Int {
		var i = Art.TILE_SKINS.indexOf(skin);
		return i < 0 ? 1 : i + 1;
	}

	// ViewManager.onViewReady: the level is playable again (its end is checked)
	function onViewReady() {
		unlock();
		game.onLevelReady();
	}

	// a special background of an item (View.attachSpecialBg: frame id + 1 of hammer_special_bg) in place of the one
	// of the level, under its tiles: its layers centered on the field
	var specialBg:ASprite;
	var specialPics:Array<Pic> = [];

	public function attachSpecialBg(id:Int) {
		detachSpecialBg();
		var layers = switch (id) {
			case Data.BG_STAR: ["sbgStarBack", "sbgStar"];
			case Data.BG_ORANGE: ["sbgRays"];
			case Data.BG_SINGER: ["sbgRays", "sbgSinger"];
			default: [];
		}
		if (layers.length == 0)
			return;
		specialBg = new ASprite();
		specialBg._x = Data.GAME_WIDTH / 2;
		specialBg._y = Data.GAME_HEIGHT / 2;
		for (l in layers) {
			var p = new Pic(l);
			// (the pictures: 400 x 400 around the middle of the screen of the original, from their top left)
			p._x = -200;
			p._y = -200;
			specialBg.addChild(p);
			specialPics.push(p);
		}
		viewHolder.addChildAt(specialBg, 0);
		redraw(false);
	}

	public function detachSpecialBg() {
		if (specialBg == null)
			return;
		if (specialBg.parent != null)
			specialBg.parent.removeChild(specialBg);
		specialBg.destroy({children: true});
		specialBg = null;
		specialPics = [];
		redraw(true);
	}

	// the picture of the level again, with or without its background
	function redraw(bg:Bool) {
		var old = viewTex;
		drawView(bg, false);
		if (old != null)
			old.destroy(true);
	}

	public function update() {
		// the fields play their animations
		for (p in fieldPics)
			if (p.count() > 1)
				p.show(p.cur % p.count() + 1);
		for (p in specialPics)
			if (p.count() > 1)
				p.show(p.cur % p.count() + 1);
		if (loadCpt >= 0) {
			loadCpt += Game.tmod;
			// (shorter than the original: 12 cycles)
			var ratio = loadCpt / 12;
			showLoad(ratio);
			if (ratio >= 1)
				loadCpt = -1;
		}
		if (fl_fading && loadCpt < 0) {
			black.visible = false;
			fl_fading = false;
			onViewReady();
		}
		if (fl_scrolling) {
			scrollCpt += Data.SCROLL_SPEED * Game.tmod;
			var s = Cs.qt(Math.sin(scrollCpt));
			setViewY(Data.GAME_HEIGHT + s * (0 - Data.GAME_HEIGHT));
			fakeHolder._y = -s * Data.GAME_HEIGHT;
			if (scrollCpt >= Math.PI / 2) {
				setViewY(0);
				fakeSides._visible = false;
				if (fake != null) {
					fake.destroy();
					fake = null;
				}
				if (fakeTex != null) {
					fakeTex.destroy(true);
					fakeTex = null;
				}
				if (oldFields != null) {
					if (oldFields.parent != null)
						oldFields.parent.removeChild(oldFields);
					oldFields.destroy({children: true});
					oldFields = null;
				}
				if (oldDevices != null) {
					if (oldDevices.parent != null)
						oldDevices.parent.removeChild(oldDevices);
					oldDevices.destroy({children: true});
					oldDevices = null;
				}
				fl_scrolling = false;
				onViewReady();
			}
		}
	}

	public function destroy() {
		if (viewTex != null)
			viewTex.destroy(true);
		if (fakeTex != null)
			fakeTex.destroy(true);
	}
}
