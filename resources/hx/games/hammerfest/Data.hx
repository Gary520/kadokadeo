package hammerfest;

typedef AnimDef = {id:Int, loop:Bool};

// Data of the original (hammer/Data.mt): constants of the game. The field of the mini version is 20 x 20 cases of
// 20 px (the original: 20 x 25), shown at 70 % in a 300 x 300 game: the layout of the original (stone columns on the
// sides, a bar at the bottom), 5 rows less.
class Data {
	public static inline var DOC_WIDTH = 300;
	public static inline var DOC_HEIGHT = 300;

	public static inline var GAME_WIDTH = 360;
	public static inline var GAME_HEIGHT = 360;
	public static inline var GAME_SCALE = 280 / 360; // field of 360 x 360 in 280 x 280 pixels of the game

	public static inline var LEVEL_WIDTH = 18;
	public static inline var LEVEL_HEIGHT = 18;

	public static inline var CASE_WIDTH = 20;
	public static inline var CASE_HEIGHT = 20;

	public static inline var SECOND = 32; // duration of a second in game cycles

	// *** DEPTHS
	public static inline var DP_SPECIAL_BG = 0;
	public static inline var DP_BACK_LAYER = 1;
	public static inline var DP_SPRITE_BACK_LAYER = 2;
	public static inline var DP_FIELD_LAYER = 3;
	public static inline var DP_SPEAR = 4;
	public static inline var DP_PLAYER = 5;
	public static inline var DP_ITEMS = 6;
	public static inline var DP_SHOTS = 7;
	public static inline var DP_BADS = 8;
	public static inline var DP_BOMBS = 9;
	public static inline var DP_FX = 10;
	public static inline var DP_SUPA = 11;
	public static inline var DP_TOP_LAYER = 12;
	public static inline var DP_SPRITE_TOP_LAYER = 13;
	public static inline var DP_BORDERS = 14;
	public static inline var DP_SCROLLER = 15;
	public static inline var DP_INTERF = 16;
	public static inline var DP_TOP = 17;

	// *** TYPES
	public static inline var ENTITY = 1 << 0;
	public static inline var PHYSICS = 1 << 1;
	public static inline var ITEM = 1 << 2;
	public static inline var SPECIAL_ITEM = 1 << 3;
	public static inline var PLAYER = 1 << 4;
	public static inline var PLAYER_BOMB = 1 << 5;
	public static inline var BAD = 1 << 6;
	public static inline var SHOOT = 1 << 7;
	public static inline var BOMB = 1 << 8;
	public static inline var FX = 1 << 9;
	public static inline var SUPA = 1 << 10;
	public static inline var CATCHER = 1 << 11;
	public static inline var BALL = 1 << 12;
	public static inline var HU_BAD = 1 << 13;
	public static inline var BOSS = 1 << 14;
	public static inline var BAD_BOMB = 1 << 15;
	public static inline var BAD_CLEAR = 1 << 16;
	public static inline var SOCCERBALL = 1 << 17;
	public static inline var PLAYER_SHOOT = 1 << 18;
	public static inline var PERFECT_ITEM = 1 << 19;
	public static inline var SPEAR = 1 << 20;
	public static inline var TYPE_COUNT = 21;

	// *** LEVELS
	public static inline var FIELD_TELEPORT = -6; // fields (lasers) in the map: negative ids
	public static inline var FIELD_PEACE = -11;
	public static inline var FIELD_BUMPER = -10;
	public static inline var TELEPORTER_DISTANCE = CASE_WIDTH * 4;
	public static inline var PLAYER_KNOCK_DURATION = SECOND * 2.5;
	public static inline var GROUND = 1;
	public static inline var WALL = 2;
	public static inline var OUT_WALL = 3;
	public static inline var HORIZONTAL = 1;
	public static inline var VERTICAL = 2;
	public static inline var SCROLL_SPEED = 0.04;
	public static var HU_STEPS = [35 * SECOND, 25 * SECOND];

	// *** STATS
	public static inline var STAT_MAX_COMBO = 0;
	public static inline var STAT_SUPAITEM = 1;
	public static inline var STAT_KICK = 2;
	public static inline var STAT_BOMB = 3;
	public static inline var STAT_SHOT = 4;
	public static inline var STAT_JUMP = 5;
	public static inline var STAT_ICEHIT = 6;
	public static inline var STAT_KNOCK = 7;
	public static inline var STAT_DEATH = 8;

	// *** EXTENDS
	public static inline var EXTEND_TIMER = 10 * SECOND;

	// *** ANIMATIONS
	public static inline var BLINK_DURATION = 2.5;
	public static inline var BLINK_DURATION_FAST = 1;
	public static var ANIM_PLAYER_STOP:AnimDef = {id: 0, loop: true};
	public static var ANIM_PLAYER_WALK:AnimDef = {id: 1, loop: true};
	public static var ANIM_PLAYER_JUMP_UP:AnimDef = {id: 2, loop: false};
	public static var ANIM_PLAYER_JUMP_DOWN:AnimDef = {id: 3, loop: false};
	public static var ANIM_PLAYER_JUMP_LAND:AnimDef = {id: 4, loop: false};
	public static var ANIM_PLAYER_DIE:AnimDef = {id: 5, loop: true};
	public static var ANIM_PLAYER_KICK:AnimDef = {id: 6, loop: false};
	public static var ANIM_PLAYER_ATTACK:AnimDef = {id: 7, loop: false};
	public static var ANIM_PLAYER_EDGE:AnimDef = {id: 8, loop: true};
	public static var ANIM_PLAYER_WAIT1:AnimDef = {id: 9, loop: false};
	public static var ANIM_PLAYER_WAIT2:AnimDef = {id: 10, loop: false};
	public static var ANIM_PLAYER_KNOCK_IN:AnimDef = {id: 12, loop: false};
	public static var ANIM_PLAYER_KNOCK_OUT:AnimDef = {id: 13, loop: false};
	public static var ANIM_PLAYER_RESURRECT:AnimDef = {id: 14, loop: false};
	public static var ANIM_PLAYER_RUN:AnimDef = {id: 16, loop: true};
	// happy (the big crystal of the order of the bads falls) and sad (it fell out of the level)
	public static var ANIM_PLAYER_STOP_V:AnimDef = {id: 19, loop: true};
	public static var ANIM_PLAYER_WALK_V:AnimDef = {id: 20, loop: true};
	public static var ANIM_PLAYER_STOP_L:AnimDef = {id: 21, loop: true};
	public static var ANIM_PLAYER_WALK_L:AnimDef = {id: 22, loop: true};

	public static var ANIM_BAD_WALK:AnimDef = {id: 0, loop: true};
	public static var ANIM_BAD_ANGER:AnimDef = {id: 1, loop: true};
	public static var ANIM_BAD_FREEZE:AnimDef = {id: 2, loop: false};
	public static var ANIM_BAD_KNOCK:AnimDef = {id: 3, loop: true};
	public static var ANIM_BAD_DIE:AnimDef = {id: 4, loop: true};
	public static var ANIM_BAD_SHOOT_START:AnimDef = {id: 5, loop: false};
	public static var ANIM_BAD_SHOOT_END:AnimDef = {id: 6, loop: false};
	public static var ANIM_BAD_THINK:AnimDef = {id: 7, loop: false};
	public static var ANIM_BAD_JUMP:AnimDef = {id: 8, loop: true};
	public static var ANIM_BAD_SHOOT_LOOP:AnimDef = {id: 9, loop: true};

	public static var ANIM_BOMB_DROP:AnimDef = {id: 0, loop: false};
	public static var ANIM_BOMB_LOOP:AnimDef = {id: 1, loop: true};
	public static var ANIM_BOMB_EXPLODE:AnimDef = {id: 2, loop: false};

	public static var ANIM_SHOOT:AnimDef = {id: 0, loop: false};
	public static var ANIM_SHOOT_LOOP:AnimDef = {id: 0, loop: true};

	// *** IA
	public static inline var IA_TILE_TOP = 1 << 0;
	public static inline var IA_ALLOW_FALL = 1 << 1;
	public static inline var IA_BORDER = 1 << 2;
	public static inline var IA_SMALL_SPOT = 1 << 3;
	public static inline var IA_FALL_SPOT = 1 << 4;
	public static inline var IA_JUMP_UP = 1 << 5;
	public static inline var IA_JUMP_DOWN = 1 << 6;
	public static inline var IA_JUMP_LEFT = 1 << 7;
	public static inline var IA_JUMP_RIGHT = 1 << 8;
	public static inline var IA_TILE = 1 << 9;
	public static inline var IA_CLIMB_LEFT = 1 << 10;
	public static inline var IA_CLIMB_RIGHT = 1 << 11;

	public static inline var IA_HJUMP = 2; // horizontal jump distance
	public static inline var IA_VJUMP = 2; // vertical jump distance
	public static inline var IA_CLIMB = 4; // max climbing distance
	public static inline var IA_CLOSE_DISTANCE = 110;

	public static inline var ACTION_MOVE = 1;
	public static inline var ACTION_WALK = 2;
	public static inline var ACTION_SHOOT = 3;
	public static inline var ACTION_FALLBACK = 4;

	// *** PHYSICS
	public static inline var BORDER_MARGIN = CASE_WIDTH / 2;
	public static inline var FRICTION_X = 0.93;
	public static inline var FRICTION_Y = 0.86;
	public static inline var FRICTION_GROUND = 0.70;
	public static inline var FRICTION_SLIDE = 0.97;
	public static inline var GRAVITY = 1.0; // added to dy going up
	public static inline var FALL_FACTOR_FROZEN = 2.3;
	public static inline var FALL_FACTOR_KNOCK = 1.5;
	public static inline var FALL_FACTOR_DEAD = 1.75;
	public static inline var FALL_SPEED = 0.9; // added to dy going down
	public static inline var STEP_MAX = CASE_WIDTH;
	public static inline var DEATH_LINE = GAME_HEIGHT + 50;

	// *** FX
	public static inline var MAX_FX = 16;
	public static inline var DUST_FALL_HEIGHT = CASE_HEIGHT * 4;
	public static inline var PARTICLE_ICE = 1;
	public static inline var PARTICLE_CLASSIC_BOMB = 2;
	public static inline var PARTICLE_STONE = 3;
	public static inline var PARTICLE_SPARK = 4;
	public static inline var PARTICLE_DUST = 5;
	public static inline var PARTICLE_ORANGE = 6;
	public static inline var PARTICLE_METAL = 7;
	public static inline var PARTICLE_TUBERCULOZ = 8;
	public static inline var PARTICLE_RAIN = 9;
	public static inline var PARTICLE_LITCHI = 10;
	public static inline var PARTICLE_PORTAL = PARTICLE_SPARK;
	public static inline var PARTICLE_BUBBLE = 11;
	public static inline var PARTICLE_ICE_BAD = 12;
	public static inline var PARTICLE_BLOB = 13;
	public static inline var PARTICLE_FRAMB = 14;

	// special backgrounds of the items (hammer_special_bg: frame id + 1)
	public static inline var BG_STAR = 0;
	public static inline var BG_ORANGE = 2;
	public static inline var BG_SINGER = 10;

	// *** PLAYER
	public static inline var PLAYER_SPEED = 4.3;
	public static inline var PLAYER_JUMP = 18.7;
	public static inline var PLAYER_HKICK_X = 3.5;
	public static inline var PLAYER_HKICK_Y = 7.4;
	public static inline var PLAYER_VKICK = 18;
	public static inline var PLAYER_AIR_JUMP = 7;

	public static inline var KICK_DISTANCE = CASE_WIDTH;
	public static inline var AIR_KICK_DISTANCE = CASE_WIDTH * 1.5;

	public static inline var SHIELD_DURATION = SECOND * 5;
	public static inline var WEAPON_DURATION = SECOND * 30;
	public static var EXTRA_LIFE_STEPS = [100000, 500000, 1000000, 2000000, 3000000, 4000000];

	public static inline var CURSE_PEACE = 1;
	public static inline var CURSE_SHRINK = 2;
	public static inline var CURSE_SLOW = 3;
	public static inline var CURSE_TAUNT = 4;

	public static inline var EDGE_TIMER = SECOND * 0.2;
	public static inline var WAIT_TIMER = SECOND * 8;

	public static inline var WEAPON_B_CLASSIC = 1;
	public static inline var WEAPON_B_BLACK = 2;
	public static inline var WEAPON_B_BLUE = 3;
	public static inline var WEAPON_B_GREEN = 4;
	public static inline var WEAPON_B_RED = 5;
	public static inline var WEAPON_NONE = -1;
	public static inline var WEAPON_S_ARROW = 6;
	public static inline var WEAPON_S_FIRE = 7;
	public static inline var WEAPON_S_ICE = 8;

	// *** BADS
	public static inline var PEACE_COOLDOWN = SECOND * 3;
	public static inline var AUTO_ANGER = SECOND * 4;
	public static inline var MAX_ANGER = 3;
	public static inline var BALL_TIMEOUT = 2.3 * SECOND;
	public static inline var BAD_HJUMP_X = 5.5;
	public static inline var BAD_HJUMP_Y = 8.5;
	public static inline var BAD_VJUMP_X_CLIFF = 2.2; // climbing (foot of a wall)
	public static inline var BAD_VJUMP_X = 1.3; // climbing (steps over the void)
	public static inline var BAD_VJUMP_Y = 19;
	public static var BAD_VJUMP_Y_LIST = [11, 14, 19];
	public static inline var BAD_VDJUMP_Y = 6.5;
	public static inline var FREEZE_DURATION = SECOND * 5;
	public static inline var KNOCK_DURATION = SECOND * 3.75;
	public static inline var ICE_HIT_MIN_SPEED = 4; // distance per cycle (dx+dy)
	public static inline var ICE_KNOCK_MIN_SPEED = 2;

	public static inline var BAD_POMME = 0;
	public static inline var BAD_CERISE = 1;
	public static inline var BAD_BANANE = 2;
	public static inline var BAD_FIREBALL = 3;
	public static inline var BAD_ANANAS = 4;
	public static inline var BAD_ABRICOT = 5;
	public static inline var BAD_ABRICOT2 = 6;
	public static inline var BAD_POIRE = 7;
	public static inline var BAD_BOMBE = 8;
	public static inline var BAD_ORANGE = 9;
	public static inline var BAD_FRAISE = 10;
	public static inline var BAD_CITRON = 11;
	public static inline var BAD_BALEINE = 12;
	public static inline var BAD_KIWI = 18;
	public static inline var BAD_SPEAR = 13;
	public static inline var BAD_CRAWLER = 14;
	public static inline var BAD_SAW = 16;
	public static inline var BAD_LITCHI = 17;
	public static inline var BAD_LITCHI_WEAK = 19;
	public static inline var BAD_FRAMBOISE = 20;

	// *** ITEMS
	public static inline var ITEM_LIFE_TIME = 8 * SECOND;
	public static inline var DIAMANT = 8;
	public static var EXTENDS = ["C", "R", "Y", "S", "T", "A", "L"];
	public static inline var SPECIAL_ITEM_TIMER = 8 * SECOND;
	public static inline var SCORE_ITEM_TIMER = 12 * SECOND;

	// *** ITEM RANDOMIZER (rarity of the xml files -> weight)
	public static var RARITY = [0, 2000, 1000, 300, 100, 10, 1, 60];
	public static var RAND_EXTENDS = [10, 10, 6, 5, 5, 10, 4];

	// crystals (score item 0): value of the crystal of a combo of n + 1 bads
	public static function getCrystalValue(id:Int):Int {
		return Math.round(Math.min(50000, (5 * 100) * Math.round(Math.pow(id + 1, 2))));
	}

	// Data.formatNumber: groups of 3 digits
	public static function formatNumber(n:Int):String {
		var txt = n + "";
		if (txt.indexOf("-") < 0) {
			var i = txt.length - 3;
			while (i > 0) {
				txt = txt.substr(0, i) + "." + txt.substr(i);
				i -= 3;
			}
		}
		return txt;
	}
}
