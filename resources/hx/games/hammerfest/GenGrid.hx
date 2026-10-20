package hammerfest;

// a laser (bomb changer, laser without bombs, teleporter): a line of empty cases with the id of the map (< 0)
typedef GenField = {v:Int, cells:Array<Int>, why:String};

// The level a generator draws (Gen): W x H cases (Data.LEVEL_WIDTH x LEVEL_HEIGHT), a case is x * H + y; the sides of
// the screen are walls, under the last row is the void (the way out).
class GenGrid {
	public static inline var W = Data.LEVEL_WIDTH;
	public static inline var H = Data.LEVEL_HEIGHT;
	public static var HALF:Int = Std.int(Data.LEVEL_WIDTH / 2);

	public var g:Array<Int>; // 1: ground
	public var fields:Array<GenField> = [];
	public var teles:Array<Array<GenField>> = []; // pairs of teleporters
	public var bads:Array<{id:Int, x:Int, y:Int}> = [];
	public var sx:Int = -1; // where Igor lands coming in from the top
	public var sy:Int = -1;
	// what the way of building made
	public var shape:String = "";
	public var label:String = "";
	public var rows:Array<Int> = [];
	public var cups:Array<Array<Int>> = []; // x0, x1, y of the floor
	public var cells:Array<Array<Int>> = []; // prisons with a lid: x0, x1 of the inside, y of the floor
	public var vault:Array<Int> = null; // x0, y of the ceiling, x1, y of the floor of a room shut
	public var undo:Array<Array<Int>> = []; // the cases a prison changed (case, old value...): taken back if it stays empty
	public var gatePlan:Array<Int> = null; // the passage of a gate decided before the fruits (GenDevices.planGate)
	public var surfShare:Float = 0; // share of the fruits an ice pushed from another one goes through (surfing)
	public var shutShare:Float = 0; // share of the fruits white bombs never kill (shut in, behind a laser)
	public var room:Array<Int> = null; // cases inside the room of the teleporter
	public var mazeRooms:Array<Array<Int>> = null; // rooms of a maze (GenShapes.dedale): x0, x1, row stood on, top row
	public var mazeFloors:Array<Int> = null; // rows of the floors of a maze
	public var roomTele:Int = -1;
	public var notes:Array<String> = [];
	public var enclosed:Array<String> = [];

	public function new() {
		g = [for (i in 0...W * H) 0];
	}

	public function copy():GenGrid {
		var c = new GenGrid();
		c.g = g.copy();
		c.fields = fields.copy();
		c.teles = teles.copy();
		c.bads = [for (b in bads) {id: b.id, x: b.x, y: b.y}];
		c.sx = sx;
		c.sy = sy;
		c.shape = shape;
		c.label = label;
		c.rows = rows.copy();
		c.cups = cups.copy();
		c.cells = cells.copy();
		c.vault = vault;
		c.undo = undo.copy();
		c.gatePlan = gatePlan;
		c.surfShare = surfShare;
		c.shutShare = shutShare;
		c.room = room;
		c.mazeRooms = mazeRooms;
		c.mazeFloors = mazeFloors;
		c.roomTele = roomTele;
		c.notes = notes.copy();
		c.enclosed = enclosed.copy();
		return c;
	}

	// a prison taken back: the platform as it was
	public function takeBack(k:Int) {
		var u = undo[k];
		var i = 0;
		while (i + 1 < u.length) {
			g[u[i]] = u[i + 1];
			i += 2;
		}
		undo[k] = [];
		cells = [for (ce in cells) if (ce.length < 4 || ce[3] != k) ce];
		cups = [for (cu in cups) if (cu.length < 4 || cu[3] != k) cu];
	}

	public static inline function id(x:Int, y:Int):Int {
		return x * H + y;
	}

	public static inline function cx(c:Int):Int {
		return Std.int(c / H);
	}

	public static inline function cy(c:Int):Int {
		return c % H;
	}

	public inline function inb(x:Int, y:Int):Bool {
		return x >= 0 && x < W && y >= 0 && y < H;
	}

	public inline function ground(x:Int, y:Int):Bool {
		return x >= 0 && x < W && y >= 0 && y < H && g[x * H + y] == 1;
	}

	// stops a move across: a ground or the side of the screen
	public inline function solid(x:Int, y:Int):Bool {
		return x < 0 || x >= W || (y >= 0 && y < H && g[x * H + y] == 1);
	}

	public inline function empty(x:Int, y:Int):Bool {
		return x >= 0 && x < W && y < H && (y < 0 || g[x * H + y] == 0);
	}

	// an empty case over a ground
	public inline function stand(x:Int, y:Int):Bool {
		return x >= 0 && x < W && y >= 0 && y < H - 1 && g[x * H + y] == 0 && g[x * H + y + 1] == 1;
	}

	public inline function set(x:Int, y:Int, v:Int = 1) {
		if (x >= 0 && x < W && y >= 0 && y < H)
			g[x * H + y] = v;
	}

	public function hline(x0:Int, x1:Int, y:Int, v:Int = 1) {
		var a = x0 < x1 ? x0 : x1;
		var b = x0 < x1 ? x1 : x0;
		for (x in a...b + 1)
			set(x, y, v);
	}

	public function vline(x:Int, y0:Int, y1:Int, v:Int = 1) {
		var a = y0 < y1 ? y0 : y1;
		var b = y0 < y1 ? y1 : y0;
		for (y in a...b + 1)
			set(x, y, v);
	}

	public function rect(x0:Int, y0:Int, x1:Int, y1:Int, v:Int = 1) {
		for (y in y0...y1 + 1)
			hline(x0, x1, y, v);
	}

	// the left half copied on the right
	public function mirror() {
		for (x in 0...HALF)
			for (y in 0...H)
				g[(W - 1 - x) * H + y] = g[x * H + y];
	}

	public function symmetric():Bool {
		for (x in 0...HALF)
			for (y in 0...H)
				if (g[x * H + y] != g[(W - 1 - x) * H + y])
					return false;
		return true;
	}

	// a platform and its mirror
	public function hsym(x0:Int, x1:Int, y:Int, v:Int = 1) {
		hline(x0, x1, y, v);
		hline(W - 1 - x0, W - 1 - x1, y, v);
	}

	public function vsym(x:Int, y0:Int, y1:Int, v:Int = 1) {
		vline(x, y0, y1, v);
		vline(W - 1 - x, y0, y1, v);
	}

	// platforms walked on: standing cells x0..x1 on a row y (as [x0, x1, y])
	public function segments():Array<Array<Int>> {
		var out = [];
		for (y in 0...H - 1) {
			var x = 0;
			while (x < W) {
				if (stand(x, y)) {
					var x0 = x;
					while (x + 1 < W && stand(x + 1, y))
						x++;
					out.push([x0, x, y]);
				}
				x++;
			}
		}
		return out;
	}

	public function segmentOf(x:Int, y:Int):Array<Int> {
		if (!stand(x, y))
			return null;
		var x0 = x;
		var x1 = x;
		while (stand(x0 - 1, y))
			x0--;
		while (stand(x1 + 1, y))
			x1++;
		return [x0, x1, y];
	}

	// blocks of grounds joined (4 neighbours): the component of each ground case (-1: none)
	public function components():{comp:Array<Int>, sizes:Array<Int>} {
		var comp = [for (i in 0...W * H) -1];
		var sizes = [];
		for (x in 0...W)
			for (y in 0...H) {
				var c0 = x * H + y;
				if (g[c0] != 1 || comp[c0] >= 0)
					continue;
				var k = sizes.length;
				var n = 0;
				var st = [c0];
				comp[c0] = k;
				while (st.length > 0) {
					var c = st.pop();
					n++;
					var px = cx(c);
					var py = cy(c);
					for (d in DIRS) {
						var nx = px + d[0];
						var ny = py + d[1];
						if (ground(nx, ny) && comp[nx * H + ny] < 0) {
							comp[nx * H + ny] = k;
							st.push(nx * H + ny);
						}
					}
				}
				sizes.push(n);
			}
		return {comp: comp, sizes: sizes};
	}

	public static var DIRS = [[1, 0], [-1, 0], [0, 1], [0, -1]];

	public function density():Float {
		var n = 0;
		for (v in g)
			if (v == 1)
				n++;
		return n / (W * H);
	}

	// standing cells with a ground just over them (a passage of one case: not allowed)
	public function headroomFaults():Array<Int> {
		var out = [];
		for (x in 0...W)
			for (y in 1...H - 1)
				if (stand(x, y) && g[x * H + y - 1] == 1)
					out.push(x * H + y);
		return out;
	}

	// the lasers in a map of the cases (0: none)
	public function fieldMap():Array<Int> {
		var m = [for (i in 0...W * H) 0];
		for (f in fields)
			for (c in f.cells)
				m[c] = f.v;
		for (p in teles)
			for (f in p)
				for (c in f.cells)
					m[c] = Data.FIELD_TELEPORT;
		return m;
	}

	public function dump():String {
		var fm = fieldMap();
		var rows = [];
		for (y in 0...H) {
			var r = "";
			for (x in 0...W) {
				var c = x * H + y;
				var ch = g[c] == 1 ? "#" : (fm[c] != 0 ? (fm[c] == Data.FIELD_TELEPORT ? "t" : "" + (-fm[c] % 10)) : ".");
				for (b in bads)
					if (b.x == x && b.y == y)
						ch = "B";
				if (x == sx && y == sy)
					ch = "@";
				r += ch;
			}
			rows.push(r);
		}
		return rows.join("\n");
	}
}
