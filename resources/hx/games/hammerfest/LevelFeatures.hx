package hammerfest;

import hammerfest.LevelGen.GPt;
import hammerfest.LevelGen.GSeg;

// a passage where a laser can cut the way of Igor: its cases (a hole of 1 to 3 cases in a floor, a door of 2 or 3 cases
// in a wall), the standing cases he cannot reach any more when it is shut (behind it), the bads there
typedef GGate = {cells:Array<GPt>, behind:Array<Bool>, lost:Int, bads:Array<Int>, door:Bool};

// The devices and hazards of a level, each one for a reason, and few of them (a level has none, one, or two deep in
// the well):
// - the vault (LevelDesign): its bads shut in, their ice cannot go out: a laser of black bombs in its window, the
//   way in (Black.onExplode kills them);
// - a gate: a laser on a passage every way to some bads goes through, of the colour of what is behind it: green bombs
//   (mines) where the bads run everywhere, blue ones (they knock out) where the bads blow up or crush, red ones (they
//   throw high, Igor jumps very high on them) where the bads are perched high;
// - no bombs: a laser without bombs on the way down, the laser of the bombs back a little further, nothing to kill in
//   between (Igor goes through there unarmed, the bads around shooting at him); never on a way he has to take back;
// - a pit of spikes where the ice of the bads falls (they die there), out of the ways of Igor and of the bads;
// - spikes on the ways of Igor (under the ceilings over them, in rows on the floors he jumps over), where the bads do not go;
// - teleporters between places far apart on his ways (the way back up from the bottom);
// - saws around the small blocks he passes by.
// There is never a white laser alone (Igor has white bombs at the start of each level) nor a laser in a corner he never
// goes through: a laser is on a passage he cannot avoid to reach some bads.
@:access(hammerfest.LevelGen)
class LevelFeatures {
	static inline var W = Data.LEVEL_WIDTH;
	static inline var H = Data.LEVEL_HEIGHT;

	static inline var WHITE = -1;
	static inline var BLACK = -2;
	static inline var BLUE = -3;
	static inline var GREEN = -4;
	static inline var RED = -5;

	var g:LevelGen;
	var m:Array<Array<Int>>;

	public function new(g:LevelGen) {
		this.g = g;
		m = g.m;
	}

	// (test harness: every level with this feature; the reasons of the misses)
	public static var force:String = null;
	public static var why:Map<String, Int> = new Map();

	static inline function count(k:String) {
		#if gentest
		why.set(k, (why.exists(k) ? why.get(k) : 0) + 1);
		#end
	}

	// ---------------------------------------------------------------- the features of a level

	// drawn once for the depth (the levels made for it all try them): none at first, then one in a level out of two,
	// one or two deep in the well
	public static function draw(d:Int, ?lineup:LevelCast.Cast, ?concept:LevelConcept.Concept):Array<String> {
		if (force != null)
			return force.split(",");
		var th = LevelTheme.of(d);
		inline function chance(p:Float)
			return Cs.rnd(1000) < p * 1000;
		// (players: the first levels too hard for most players, "des endroits piégés": no device before level 5, few
		// before 8; "ça manque des niveaux avec des lasers": the lasers more often from level 8)
		// ("ils n'exploitent pas comme il faut les lasers": more of them, deep in the well a level without one is rare)
		var n = 0;
		if (d >= 5 && d < 8)
			n = chance(0.5) ? 1 : 0;
		else if (d >= 8 && d < 15)
			n = chance(0.15) ? 0 : (chance(0.65) ? 1 : 2);
		else if (d >= 15)
			n = chance(0.08) ? 0 : (chance(0.45) ? 1 : 2);
		var perched = lineup != null
			&& (lineup.list.indexOf(Data.BAD_FRAISE) >= 0 || lineup.list.indexOf(Data.BAD_POIRE) >= 0);
		var kinds = ["gate", "spikes", "pit", "vault", "disarm", "teleport", "saws", "nest"];
		var w = [
			d >= 5 ? (d >= 10 ? 7.0 : 4.5) : 0, // gate
			d >= 6 ? 4.5 : 0, // spikes
			d >= 8 ? 1.6 : 0, // pit
			d >= 7 ? 1.0 : 0, // vault
			d >= 9 ? 1.8 : 0, // disarm
			d >= 6 ? 1.2 : 0, // teleport
			d >= 7 ? 1.6 : 0, // saws (more of them)
			d >= 10 && perched ? 2.6 : 0 // nest: strawberries up where only the red jump goes
		];
		for (i in 0...kinds.length)
			w[i] *= th.features.exists(kinds[i]) ? th.features.get(kinds[i]) : 1.0;
		var out:Array<String> = [];
		// the devices of the idea of the level first (the others fewer: the level has one idea)
		if (concept != null)
			for (f in concept.want) {
				var i = kinds.indexOf(f);
				if (i >= 0 && w[i] > 0 && out.indexOf(f) < 0) {
					out.push(f);
					w[i] = 0;
					n--;
				}
			}
		// (the vault and the nest are ideas of their own (coffre, nid): not drawn in the levels of another idea; the
		// lasers, the spikes, the saws, the teleporters go with any idea)
		if (concept != null) {
			w[kinds.indexOf("vault")] = 0;
			w[kinds.indexOf("nest")] = 0;
		}
		for (k in 0...n) {
			var iw = [for (v in w) Std.int(v * 100)];
			var i = Cs.draw(iw);
			if (i < 0)
				break;
			out.push(kinds[i]);
			w[i] = 0;
		}
		// (a laser in most levels deep in the well)
		if (d >= 8 && out.indexOf("gate") < 0 && chance(d >= 15 ? 0.85 : 0.7))
			out.push("gate");
		// ("des pics bien placés qui peuvent gêner le joueur": spikes in a level in 3 or 4 deep in the well, where the
		// fruits never go)
		if (d >= 8 && out.indexOf("spikes") < 0 && out.indexOf("pit") < 0 && chance(0.25))
			out.push("spikes");
		return out;
	}

	// ---------------------------------------------------------------- before the bads

	// the laser of the vault, the saws, the teleporters (their places taken before the bads come)
	public function beforeBads():Bool {
		var want = g.want;
		if (want.indexOf("vault") >= 0) {
			if (g.vault == null) {
				count("vault.none");
				return false;
			}
			for (d in g.vault.door) {
				m[d.x][d.y] = BLACK;
				g.mark(d.x, d.y);
			}
			g.computeReach();
			if (!g.exitOk || !g.reach[g.vault.x0][g.vault.y] && !g.reach[g.vault.x1][g.vault.y]) {
				count("vault.unreached");
				return false;
			}
		}
		if (want.indexOf("disarm") >= 0) {
			if (!disarm())
				count("disarm.no");
			g.computeReach();
		}
		// the shelters of the strawberries, before the saws (no saw goes around their roofs)
		var straws = 0;
		for (id in g.lineup.list)
			if (id == Data.BAD_FRAISE)
				straws++;
		if (straws > 0) {
			shelters(straws);
			g.computeReach();
		}
		// saws: from level 7, more and more deep in the well (the Hells and the Crypt of the original are full of them),
		// one more when the level is drawn with them
		var saws = sawCount(g.depth) + (want.indexOf("saws") >= 0 ? 1 : 0);
		// (a level made for its spikes: no saw running over them)
		if (g.concept != null && g.concept.id == "pics" && want.indexOf("saws") < 0)
			saws = 0;
		if (saws > 0) {
			g.routes.compute();
			for (i in 0...saws)
				g.addSaws();
		}
		if (want.indexOf("nest") >= 0) {
			if (!nest())
				count("nest.no");
			g.computeReach();
		}
		if (want.indexOf("teleport") >= 0 && !g.designTeles && g.close == null) {
			g.routes.compute();
			if (!teleporters())
				count("tele.no");
			g.computeReach();
		}
		return true;
	}

	// the saws of a level for its depth
	function sawCount(d:Int):Int {
		// (none before level 7: the first levels simple)
		if (d < 7)
			return 0;
		if (d < 9)
			return g.chance(0.3) ? 1 : 0;
		if (d < 12)
			return g.chance(0.65) ? 1 : 0;
		if (d < 20)
			return 1 + (g.chance(0.5) ? 1 : 0);
		return 2 + (g.chance(0.4) ? 1 : 0);
	}

	// ---------------------------------------------------------------- the cellar

	// the twin of the teleporter of the cellar (LevelDesign.cellar): on a ground of the ways of Igor, far from the
	// cellar, between a ground under it and a lintel over it (the ground of a platform over it, or a case put there); the
	// cellar reached through it only
	public function closeTele():Bool {
		var c = g.close;
		g.computeReach();
		if (!g.exitOk)
			return false;
		for (x in c.x0...c.x1 + 1)
			if (g.reach[x][c.y])
				return false;
		var l = landing();
		var cands:Array<{p:GPt, v:Float}> = [];
		for (x in 0...W)
			for (y in 3...H - 1) {
				if (!g.canStand(x, y) || !g.reach[x][y] || m[x][y - 1] != 0 || g.busy[x][y] || g.busy[x][y - 1])
					continue;
				if (m[x][y - 2] < 0 || g.inClose(x, y) || g.inClose(x, y - 2) || Math.abs(x - l.x) + Math.abs(y - l.y) < 4)
					continue;
				var far = Math.abs(x - c.tele) + Math.abs(y - c.y);
				if (far < 7)
					continue;
				// (a ground over it already, a wall beside it, far from the cellar)
				var v = (m[x][y - 2] > 0 ? 3.0 : 0) + ((g.gr(x - 1, y) || g.gr(x + 1, y)) ? 1.5 : 0) + Math.min(14, far) * 0.2
					+ g.rnd(100) / 40;
				cands.push({p: {x: x, y: y}, v: v});
			}
		cands.sort(function(a, b) return a.v > b.v ? -1 : (a.v < b.v ? 1 : 0));
		for (i in 0...Std.int(Math.min(12, cands.length))) {
			var p = cands[i].p;
			var lintel = m[p.x][p.y - 2] == 0;
			m[p.x][p.y] = Data.FIELD_TELEPORT;
			m[p.x][p.y - 1] = Data.FIELD_TELEPORT;
			if (lintel)
				m[p.x][p.y - 2] = 1;
			g.computeReach();
			var inside = false;
			for (x in c.x0...c.x1 + 1)
				if (g.reach[x][c.y])
					inside = true;
			if (inside && g.exitOk && g.startOk() && g.openColumns() <= g.openBase) {
				g.mark(p.x, p.y);
				g.mark(p.x, p.y - 1);
				count("close.ok");
				return true;
			}
			m[p.x][p.y] = 0;
			m[p.x][p.y - 1] = 0;
			if (lintel)
				m[p.x][p.y - 2] = 0;
		}
		g.computeReach();
		count("close.no");
		return false;
	}

	// ---------------------------------------------------------------- the nest

	// a nest high up: a perch of 3 or 4 cases free around, Igor reaches it only with the jump of a red bomb (4 to 6 rows
	// over a place of his ways, the column clear: Red.onExplode throws him about 7 cases up), a red laser on a passage
	// near that place; the strawberries (or a pear) sit in the nest (LevelBads)
	function nest():Bool {
		g.computeReach();
		var best:{x0:Int, x1:Int, y:Int, lx:Int, ly:Int} = null;
		var bv = -1.0;
		for (y in 3...9)
			for (x0 in 0...W - 2) {
				var w = 3 + g.rnd(2);
				var x1 = x0 + w - 1;
				if (x1 >= W)
					continue;
				var ok = true;
				for (x in x0 - 1...x1 + 2)
					for (yy in y - 3...y + 2)
						if (g.inb(x, yy) && m[x][yy] != 0)
							ok = false;
				// (out of the reach of the moves of Igor: no place of his within 5 cases over it nor 3 rows under it)
				for (x in x0 - 5...x1 + 6)
					for (yy in 0...y + 3)
						if (g.inb(x, yy) && g.reach[x][yy])
							ok = false;
				if (!ok)
					continue;
				// (a place of Igor under it, 4 to 6 rows lower, the column clear up to the nest)
				for (lx in x0...x1 + 1)
					for (ly in y + 3...y + 6) {
						if (ly >= H || !g.canStand(lx, ly) || !g.reach[lx][ly])
							continue;
						var clear = true;
						for (r in y...ly)
							if (!g.passUp(lx, r) && r != y)
								clear = false;
						if (!clear)
							continue;
						var v = (ly - y) + (y <= 5 ? 2 : 0) + g.rnd(100) / 50;
						if (v > bv) {
							bv = v;
							best = {x0: x0, x1: x1, y: y, lx: lx, ly: ly};
						}
					}
			}
		if (best == null)
			return false;
		for (x in best.x0...best.x1 + 1)
			m[x][best.y] = 1;
		g.computeReach();
		// (not reached without the red jump; reached with it)
		var normal = false;
		for (x in best.x0...best.x1 + 1)
			if (g.reach[x][best.y - 1])
				normal = true;
		g.redJump = true;
		g.computeReach();
		var red = false;
		for (x in best.x0...best.x1 + 1)
			if (g.reach[x][best.y - 1])
				red = true;
		// (the red laser on a passage near the place under the nest)
		var site:GGate = null;
		var sd = 99;
		if (!normal && red)
			for (st in sites()) {
				var d = 99;
				for (c in st.cells)
					d = Std.int(Math.min(d, Math.abs(c.x - best.lx) + Math.abs(c.y - best.ly)));
				var near = false;
				for (c in st.cells)
					if (g.reachedNear(c.x, c.y))
						near = true;
				if (near && d < sd && d <= 9) {
					sd = d;
					site = st;
				}
			}
		if (normal || !red || site == null || !g.exitOk || !g.startOk() || g.openColumns() > g.openBase) {
			for (x in best.x0...best.x1 + 1)
				m[x][best.y] = 0;
			g.redJump = false;
			g.computeReach();
			count(normal ? "nest.normal" : (!red ? "nest.red" : "nest.site"));
			return false;
		}
		put(site, RED);
		g.gates.push({cells: site.cells, v: RED});
		g.nest = {x0: best.x0, x1: best.x1, y: best.y - 1, top: best.y - 1, door: site.cells};
		count("nest.ok");
		return true;
	}

	// ---------------------------------------------------------------- the shelters of the strawberries

	// the strawberries out of the reach of the bombs from above: Igor has to come to their row, into the way of their
	// ball, to kill them. Where the shape has too few ledges like that (LevelGen.bombExposure), a roof over a ledge
	// (against a wall first, the second one on the other side of the level): 2 rows over it, as wide as the places
	// where a bomb from above would rest by the bad. A bomb resting on the roof does nothing under it, a bomb falling
	// past the roof goes down past the ledge
	public function shelters(n:Int) {
		g.routes.compute();
		var landY = g.py;
		while (landY < H - 1 && !g.canStand(g.px, landY))
			landY++;
		var top = H;
		for (x in 0...W)
			top = Std.int(Math.min(top, g.landRow(x)));
		var y0 = Std.int(Math.max(5, Math.max(landY + 4, top + 2)));
		var safe = 0;
		var cand:Array<{s:GSeg, v:Float}> = [];
		for (s in g.segments()) {
			if (s.y < y0 || s.y > H - 4 || !(g.segReached(s) || g.segNear(s)) || g.isNoBad(s) || g.spikesNear(s))
				continue;
			if (g.bombExposure(s.x0, s.x1, s.y) == 0) {
				safe++;
				continue;
			}
			var len = s.x1 - s.x0 + 1;
			if (len > 5)
				continue;
			var wall = g.gr(s.x0 - 1, s.y) || g.gr(s.x1 + 1, s.y);
			cand.push({s: s, v: (wall ? 2 : 0) + (len <= 3 ? 1 : 0) + (s.y <= 12 ? 1 : 0) + g.rnd(100) / 60});
		}
		var want = Std.int(Math.min(3, n - safe));
		if (want > 0)
			count(cand.length == 0 ? "shelter.nocand" : "shelter.need");
		if (want <= 0 || cand.length == 0)
			return;
		cand.sort(function(a, b) return Reflect.compare(b.v, a.v));
		var side = 0;
		for (pass in 0...2)
			for (c in cand) {
				if (want <= 0)
					return;
				var sd = c.s.x0 + c.s.x1 < W - 1 ? -1 : 1;
				if (pass == 0 && sd == side)
					continue;
				if (roof(c.s)) {
					want--;
					side = sd;
				}
			}
	}

	// a roof 2 rows over a ledge (see shelters): Igor still reaching the ledge or its sides, no saw, no laser by it
	function roof(s:GSeg):Bool {
		var ry = s.y - 2;
		if (ry < 2)
			return false;
		for (x in s.x0...s.x1 + 1)
			if (!g.canStand(x, s.y) || m[x][s.y - 1] != 0)
				return false;
		// (the columns where a bomb from up there comes down to rest by the bad: open from its place up over the roof)
		var rx0 = W;
		var rx1 = -1;
		for (x in s.x0 - 3...s.x1 + 4) {
			if (x < 0 || x >= W)
				continue;
			var by = g.blastRest(x, s.x0, s.x1, s.y);
			if (by < 0)
				continue;
			var open = true;
			for (r in ry - 1...by)
				if (m[x][r] > 0)
					open = false;
			if (!open)
				continue;
			rx0 = Std.int(Math.min(rx0, x));
			rx1 = Std.int(Math.max(rx1, x));
		}
		if (rx1 < 0)
			return false;
		// (3 cases at least: no lonely bit of ground)
		while (rx1 - rx0 < 2) {
			var grown = false;
			if (rx0 > 0 && m[rx0 - 1][ry] >= 0 && m[rx0 - 1][ry + 1] == 0) {
				rx0--;
				grown = true;
			}
			if (rx1 - rx0 < 2 && rx1 < W - 1 && m[rx1 + 1][ry] >= 0 && m[rx1 + 1][ry + 1] == 0) {
				rx1++;
				grown = true;
			}
			if (!grown) {
				count("shelter.narrow");
				return false;
			}
		}
		// (the cases added free over them: a roof apart; a ground there already is part of it)
		var add:Array<Int> = [];
		for (x in rx0...rx1 + 1) {
			if (m[x][ry + 1] != 0 || m[x][ry] < 0 || m[x][ry - 1] < 0) {
				count("shelter.room");
				return false;
			}
			if (m[x][ry] == 0)
				add.push(x);
			for (y in ry - 2...s.y + 2)
				for (d in [-1, 0, 1])
					if (g.inb(x + d, y) && m[x + d][y] < 0) {
						count("shelter.laser");
						return false;
					}
		}
		if (add.length == 0)
			return false;
		// (away from the blocks the saws go around: 2 free cases between)
		for (b in g.bads)
			if (b.id == Data.BAD_SAW || b.id == Data.BAD_CRAWLER)
				for (c in blockOf(b.x, b.y + 1))
					if (c.x >= rx0 - 2 && c.x <= rx1 + 2 && c.y >= ry - 2 && c.y <= ry + 2) {
						count("shelter.saw");
						return false;
					}
		count("shelter.try");
		for (x in add)
			m[x][ry] = 1;
		g.computeReach();
		var ok = g.exitOk && g.startOk();
		if (!ok)
			count("shelter.exit");
		else if (!g.segNear(s)) {
			count("shelter.lost");
			ok = false;
		}
		if (ok) {
			g.routes.compute();
			ok = g.bombExposure(s.x0, s.x1, s.y) == 0;
			if (!ok)
				count("shelter.still");
		}
		if (!ok) {
			for (x in add)
				m[x][ry] = 0;
			g.computeReach();
			g.routes.compute();
			return false;
		}
		for (x in add)
			g.roofs.push({x: x, y: ry});
		count("shelter.ok");
		return true;
	}

	// the cases of the block of ground holding the case (x, y): 30 at most
	function blockOf(x:Int, y:Int):Array<GPt> {
		var out:Array<GPt> = [];
		if (!g.inb(x, y) || m[x][y] <= 0)
			return out;
		var seen = new Map<Int, Bool>();
		var st = [{x: x, y: y}];
		seen.set(x * 32 + y, true);
		while (st.length > 0 && out.length < 30) {
			var p = st.pop();
			out.push(p);
			for (d in [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
				var nx = p.x + d[0];
				var ny = p.y + d[1];
				if (g.inb(nx, ny) && m[nx][ny] > 0 && !seen.exists(nx * 32 + ny)) {
					seen.set(nx * 32 + ny, true);
					st.push({x: nx, y: ny});
				}
			}
		}
		return out;
	}

	// ---------------------------------------------------------------- after the bads

	public function afterBads():Bool {
		var want = g.want;
		g.computeReach();
		g.routes.compute();
		for (w in want)
			switch (w) {
				case "gate":
					if (!gate())
						count("gate.no");
					else if (g.depth >= 12 && g.chance(0.65))
						gate();
				case "pit":
					if (!pit()) {
						count("pit.no");
						g.addSpikes(Std.int(Math.min(8, 3 + g.depth * 0.25)));
					}
				case "spikes":
					g.addSpikes(Std.int(Math.min(10, (3 + g.depth * 0.35) * LevelGen.rhythm(g.depth))));
				default:
			}
		g.computeReach();
		return g.exitOk;
	}

	// ---------------------------------------------------------------- passages

	// the holes and the doors of the level where a laser can stand (held at both ends by the ground), not taken
	public function sites():Array<GGate> {
		var out:Array<GGate> = [];
		// holes of 1 to 3 cases in a floor: nothing over them (Igor falls through), a ground under them in the level
		for (y in 3...H) {
			var x = 1;
			while (x < W - 1) {
				if (!(m[x][y] == 0 && m[x - 1][y] > 0)) {
					x++;
					continue;
				}
				var a = x;
				while (x < W && m[x][y] == 0)
					x++;
				var b = x - 1;
				if (x >= W || m[x][y] <= 0 || b - a + 1 > 3)
					continue;
				var ok = true;
				for (c in a...b + 1)
					if (m[c][y - 1] != 0 || g.groundFrom(c, y + 1) >= H || g.busy[c][y] || g.danger[c][y])
						ok = false;
				// (in a floor Igor walks on: a standing case at one of its ends)
				if (!g.canStand(a - 1, y - 1) && !g.canStand(b + 1, y - 1))
					ok = false;
				if (ok)
					out.push({cells: [for (c in a...b + 1) {x: c, y: y}], behind: null, lost: 0, bads: [], door: false});
			}
		}
		// doors of 2 or 3 cases in a wall: ground over and under them (the wall going on over or under), open on both
		// sides
		for (x in 1...W - 1)
			for (y in 3...H - 1) {
				if (m[x][y] != 0 || m[x][y + 1] <= 0)
					continue;
				var t = y;
				while (t > 1 && m[x][t - 1] == 0 && y - t < 3)
					t--;
				var hg = y - t + 1;
				if (hg < 2 || hg > 3 || t < 2 || m[x][t - 1] <= 0)
					continue;
				// (in a wall: the ground going on over and under the door, not a gap between two platforms nor a place
				// under a ceiling)
				if (!(m[x][t - 2] > 0 && y + 2 < H && m[x][y + 2] > 0) || (g.gr(x - 1, t - 1) && g.gr(x + 1, t - 1)))
					continue;
				if (!g.passable(x - 1, y) || !g.passable(x + 1, y))
					continue;
				var ok = true;
				for (yy in t...y + 1)
					if (g.busy[x][yy] || g.danger[x][yy])
						ok = false;
				if (ok)
					out.push({cells: [for (yy in t...y + 1) {x: x, y: yy}], behind: null, lost: 0, bads: [], door: true});
			}
		// curtains: from the tip of a platform down to the platform 3 rows lower (the 2 cases between them, Igor walking
		// on the lower one goes through it; levels over the void have few holes with a ground under them)
		for (x in 0...W)
			for (y in 2...H - 2) {
				if (m[x][y] <= 0 || m[x][y - 1] > 0 || m[x][y + 1] != 0 || m[x][y + 2] != 0 || y + 3 >= H || m[x][y + 3] <= 0)
					continue;
				// (the tip of the upper platform: no ground on one side of it)
				var tip = (x == 0 || m[x - 1][y] <= 0) != (x == W - 1 || m[x + 1][y] <= 0);
				if (!tip || !g.passable(x - 1, y + 2) || !g.passable(x + 1, y + 2))
					continue;
				var ok = true;
				for (yy in y + 1...y + 3)
					if (g.busy[x][yy] || g.danger[x][yy] || (x > 0 && m[x - 1][yy] < 0) || (x < W - 1 && m[x + 1][yy] < 0))
						ok = false;
				if (ok && g.canStand(x, y + 2))
					out.push({cells: [{x: x, y: y + 1}, {x: x, y: y + 2}], behind: null, lost: 0, bads: [], door: true});
			}
		return out;
	}

	// what is behind a passage: the standing cases lost when it is shut, the bads standing there
	function measure(s:GGate) {
		g.computeReach();
		var before = [for (x in 0...W) g.reach[x].copy()];
		var saved = [for (c in s.cells) m[c.x][c.y]];
		for (c in s.cells)
			m[c.x][c.y] = 1;
		g.computeReach();
		s.behind = [for (i in 0...W * H) false];
		s.lost = 0;
		for (x in 0...W)
			for (y in 0...H)
				if (before[x][y] && !g.reach[x][y]) {
					s.behind[x * H + y] = true;
					s.lost++;
				}
		for (i in 0...s.cells.length)
			m[s.cells[i].x][s.cells[i].y] = saved[i];
		g.computeReach();
		s.bads = [];
		for (i in 0...g.bads.length) {
			var b = g.bads[i];
			if (!isFruit(b.id))
				continue;
			var ly = b.y;
			while (ly < H - 1 && !g.canStand(b.x, ly))
				ly++;
			if (s.behind[b.x * H + ly])
				s.bads.push(i);
		}
	}

	static function isFruit(id:Int):Bool {
		return id != Data.BAD_SPEAR && id != Data.BAD_SAW && id != Data.BAD_CRAWLER;
	}

	// (the place where Igor lands at the start)
	function landing():GPt {
		var y = g.py;
		while (y < H - 1 && !g.canStand(g.px, y))
			y++;
		return {x: g.px, y: y};
	}

	function nearStart(s:GGate):Bool {
		var l = landing();
		for (c in s.cells)
			if (Math.abs(c.x - l.x) <= 2 && Math.abs(c.y - l.y) <= 3)
				return true;
		return false;
	}

	function put(s:GGate, v:Int) {
		for (c in s.cells) {
			m[c.x][c.y] = v;
			g.mark(c.x, c.y);
		}
	}

	// ---------------------------------------------------------------- a gate

	// the laser on the passage every way to the most bads goes through, of the colour of what is behind it (else on a
	// passage Igor takes often by dangerous bads, of their colour)
	function gate():Bool {
		var best:GGate = null;
		var bv = 0.0;
		var all = sites();
		for (s in all) {
			if (nearStart(s))
				continue;
			measure(s);
			if (s.bads.length < (g.depth >= 8 ? 1 : 2) || s.lost < 3)
				continue;
			var v = s.bads.length * 2.0 + Math.min(6, s.lost * 0.3) + g.rnd(100) / 60;
			for (c in s.cells)
				v += Math.min(2, g.routes.at(c.x, c.y) * 0.3);
			// (a passage the structure made for it: the gap of a frame, the middle of a bridge, a hole of a ceiling)
			if (designed(s))
				v += 3;
			if (v > bv) {
				bv = v;
				best = s;
			}
		}
		// (no passage shutting bads away: a passage Igor goes through often, dangerous bads near it (one is enough
		// deep in the well); its laser gives him the bombs for them on his way)
		if (best == null)
			for (s in all) {
				if (nearStart(s) || s.behind == null)
					continue;
				var traffic = 0.0;
				for (c in s.cells)
					traffic += g.routes.at(c.x, c.y);
				if (traffic < 2)
					continue;
				var near:Array<Int> = [];
				for (i in 0...g.bads.length) {
					var b = g.bads[i];
					if (!isFruit(b.id) || b.id == Data.BAD_CERISE)
						continue;
					var d = 99;
					for (c in s.cells)
						d = Std.int(Math.min(d, Math.abs(c.x - b.x) + Math.abs(c.y - b.y)));
					if (d <= 6)
						near.push(i);
				}
				if (near.length < (g.depth >= 10 ? 1 : 2))
					continue;
				var v = Math.min(8, traffic) * 0.4 + near.length + g.rnd(100) / 60 + (designed(s) ? 3 : 0);
				if (v > bv) {
					bv = v;
					best = s;
					s.bads = near;
				}
			}
		if (best == null)
			return false;
		var col = colourFor(best);
		put(best, col);
		g.gates.push({cells: best.cells, v: col});
		count("gate." + col);
		// (a mirrored level: the same laser on the mirrored passage)
		if (g.sym)
			for (s in all) {
				if (s == best || s.cells.length != best.cells.length || nearStart(s))
					continue;
				var mirror = true;
				for (c in s.cells) {
					var found = false;
					for (b in best.cells)
						if (b.x == W - 1 - c.x && b.y == c.y)
							found = true;
					if (!found)
						mirror = false;
				}
				if (mirror) {
					put(s, col);
					g.gates.push({cells: s.cells, v: col});
					break;
				}
			}
		return true;
	}

	// a passage of the level the structure made for a laser (LevelDesign.gates)
	function designed(s:GGate):Bool {
		for (dg in g.designGates) {
			if (dg.length != s.cells.length)
				continue;
			var same = true;
			for (c in s.cells) {
				var found = false;
				for (d in dg)
					if (d.x == c.x && d.y == c.y)
						found = true;
				if (!found)
					same = false;
			}
			if (same)
				return true;
		}
		return false;
	}

	// the bombs that go with the bads behind a passage
	function colourFor(s:GGate):Int {
		var green = 1.0;
		var blue = 1.0;
		var red = 1.0;
		var top = H;
		var bot = 0;
		for (i in 0...W * H)
			if (s.behind[i]) {
				top = Std.int(Math.min(top, i % H));
				bot = Std.int(Math.max(bot, i % H));
			}
		for (i in s.bads) {
			var b = g.bads[i];
			switch (b.id) {
				case Data.BAD_BANANE, Data.BAD_ORANGE, Data.BAD_KIWI, Data.BAD_ABRICOT, Data.BAD_LITCHI, Data.BAD_FRAMBOISE:
					green += 2;
				case Data.BAD_BOMBE, Data.BAD_ANANAS:
					blue += 2.5;
				case Data.BAD_FRAISE, Data.BAD_CITRON, Data.BAD_POIRE:
					red += b.y < bot - 4 ? 2 : 0.8;
				default:
					green += 0.5;
					red += 0.5;
			}
		}
		if (bot - top >= 8)
			red += 2;
		var c = LevelTheme.of(g.depth).colors;
		// (the colours of the idea of the level: blue against the Bombinos and the pineapples, green against the
		// runners, red for a nest)
		var k = g.concept != null ? g.concept.colours : [1.0, 1.0, 1.0];
		var w = [
			Std.int(green * c[3] * 30 * k[0] * (g.depth >= 4 ? 1 : 0)),
			Std.int(blue * c[2] * 30 * k[1]),
			Std.int(red * c[4] * 30 * k[2] * (g.depth >= 6 ? 1 : 0))
		];
		return switch (g.draw(w)) {
			case 0: GREEN;
			case 1: BLUE;
			case 2: RED;
			default: BLUE;
		}
	}

	// ---------------------------------------------------------------- no bombs

	// a laser without bombs on a passage of the way down, the laser of the bombs back on the next passage (room for bads
	// behind it), no bad between them (Igor goes through there unarmed); the way back up from there does not go through
	// the first one (put before the bads: none of them is placed between the two)
	function disarm():Bool {
		var all = sites();
		for (s in all)
			measure(s);
		var best:{a:GGate, b:GGate} = null;
		var bv = 0.0;
		var pairs = 0;
		for (a in all) {
			if (nearStart(a) || a.lost < 4 || a.door)
				continue;
			for (b in all) {
				if (a == b || b.lost < 4)
					continue;
				// (b behind a, everything behind b behind a too, no bad between them)
				var inside = true;
				for (c in b.cells) {
					var near = false;
					for (d in [[0, 0], [-1, 0], [1, 0], [0, -1], [0, 1]]) {
						var x = c.x + d[0];
						var y = c.y + d[1];
						if (g.inb(x, y) && a.behind[x * H + y])
							near = true;
					}
					if (!near)
						inside = false;
				}
				if (!inside)
					continue;
				var sub = true;
				var between = 0;
				for (i in 0...W * H) {
					if (b.behind[i] && !a.behind[i])
						sub = false;
					if (a.behind[i] && !b.behind[i])
						between++;
				}
				if (!sub || between < 2)
					continue;
				// (from behind b, the start reached again without a)
				pairs++;
				if (!backWithout(a, b))
					continue;
				var v = Math.min(8, between) * 0.3 + Math.min(10, b.lost) * 0.2 + g.rnd(100) / 50;
				if (v > bv) {
					bv = v;
					best = {a: a, b: b};
				}
			}
		}
		if (best == null) {
			count(pairs == 0 ? "disarm.pairs" : "disarm.back");
			return false;
		}
		put(best.a, Data.FIELD_PEACE);
		var back = WHITE;
		put(best.b, back);
		// (no bad between them)
		for (sg in g.segments())
			for (x in sg.x0...sg.x1 + 1)
				if (best.a.behind[x * H + sg.y] && !best.b.behind[x * H + sg.y]) {
					g.noBads.push(sg);
					break;
				}
		g.gates.push({cells: best.a.cells, v: Data.FIELD_PEACE});
		g.gates.push({cells: best.b.cells, v: back});
		count("disarm.ok");
		return true;
	}

	// going back from behind b never goes through a (the places reached from there the same with a shut): once his
	// bombs back, Igor does not lose them again
	function backWithout(a:GGate, b:GGate):Bool {
		var from = -1;
		for (i in 0...W * H)
			if (b.behind[i]) {
				from = i;
				break;
			}
		if (from < 0)
			return false;
		g.buildMoves();
		g.reachFrom(Std.int(from / H), from % H);
		var open = [for (x in 0...W) g.reach[x].copy()];
		var saved = [for (c in a.cells) m[c.x][c.y]];
		for (c in a.cells)
			m[c.x][c.y] = 1;
		g.buildMoves();
		g.reachFrom(Std.int(from / H), from % H);
		var ok = true;
		for (x in 0...W)
			for (y in 0...H)
				if (open[x][y] && !g.reach[x][y])
					ok = false;
		for (i in 0...a.cells.length)
			m[a.cells[i].x][a.cells[i].y] = saved[i];
		g.buildMoves();
		g.computeReach();
		return ok;
	}

	// ---------------------------------------------------------------- a pit of spikes

	// spikes where the ice of the bads falls when it is kicked off their platforms (they die there), out of the ways of
	// the bads walking and of the ways Igor needs
	function pit():Bool {
		var zone = g.fruitZone();
		var land = new Map<Int, Int>();
		for (b in g.bads) {
			if (!isFruit(b.id))
				continue;
			var s = g.segmentOf(b.x, b.y);
			if (s != null)
				for (c in iceLandings(s))
					land.set(c, (land.exists(c) ? land.get(c) : 0) + 1);
		}
		// (rows of 2 to 4 cases where ice lands, nobody walking around)
		var best:Array<GPt> = null;
		var bv = 0.0;
		for (s in g.segments()) {
			var run:Array<GPt> = [];
			var hits = 0;
			for (x in s.x0...s.x1 + 1) {
				var ok = !zone[x][s.y] && !g.busy[x][s.y] && g.m[x][s.y] == 0 && !g.inClose(x, s.y);
				if (ok) {
					run.push({x: x, y: s.y});
					if (land.exists(x * H + s.y))
						hits += land.get(x * H + s.y);
				} else if (run.length > 0)
					break;
			}
			if (run.length < 2 || hits == 0)
				continue;
			if (run.length > 4)
				run = run.slice(0, 4);
			var v = hits + run.length * 0.3 - g.routes.sum(s.x0, s.y, s.x1, s.y) * 0.05 + g.rnd(100) / 100;
			if (v > bv) {
				bv = v;
				best = run;
			}
		}
		if (best == null)
			return false;
		for (p in best)
			g.setDanger(p, true);
		g.computeReach();
		if (!g.exitOk || !g.startOk() || g.openColumns() > g.openBase || !badsReached()) {
			for (p in best)
				g.setDanger(p, false);
			g.computeReach();
			return false;
		}
		for (p in best) {
			g.mark(p.x, p.y);
			g.bads.push({id: Data.BAD_SPEAR, x: p.x, y: p.y});
		}
		count("pit.ok");
		return true;
	}

	// the standing cases where the ice of a bad of this platform lands, kicked from a side Igor reaches
	function iceLandings(s:GSeg):Array<Int> {
		var out:Array<Int> = [];
		for (d in [-1, 1]) {
			var x = d < 0 ? s.x0 : s.x1;
			var y = s.y;
			var guard = 0;
			while (guard++ < 40) {
				var nx = x + d;
				if (nx < 0 || nx >= W || m[nx][y] > 0)
					break;
				if (y + 1 < H && m[nx][y + 1] > 0) {
					x = nx;
					continue;
				}
				var fy = y;
				while (fy + 1 < H && m[nx][fy + 1] <= 0)
					fy++;
				if (fy + 1 < H)
					out.push(nx * H + fy);
				break;
			}
		}
		return out;
	}

	// every bad still near a case Igor reaches
	function badsReached():Bool {
		for (b in g.bads) {
			if (b.id == Data.BAD_SPEAR || b.id == Data.BAD_SAW)
				continue;
			var near = false;
			for (dx in -2...3)
				for (dy in -2...4)
					if (g.inb(b.x + dx, b.y + dy) && g.reach[b.x + dx][b.y + dy])
						near = true;
			if (!near)
				return false;
		}
		return true;
	}

	// ---------------------------------------------------------------- teleporters

	// two teleporters (2 cases high, a ground over them) between a place down in the level and one up near the start, far
	// apart on the ways of Igor (the way back up from the bottom): the only two of their size, they go together
	function teleporters():Bool {
		g.computeReach();
		if (!g.exitOk)
			return false;
		var l = landing();
		var spots:Array<GPt> = [];
		for (x in 0...W)
			for (y in 3...H - 1)
				if (g.canStand(x, y) && g.reach[x][y] && free(x, y) && free(x, y - 1) && (m[x][y - 2] > 0 || free(x, y - 2))
					&& Math.abs(x - l.x) + Math.abs(y - l.y) >= 4)
					spots.push({x: x, y: y});
		if (spots.length < 2)
			return false;
		g.buildMoves();
		var best:{a:GPt, b:GPt} = null;
		var bv = 0.0;
		for (k in 0...40) {
			var a = spots[g.rnd(spots.length)];
			var b = spots[g.rnd(spots.length)];
			if (b.y - a.y < 6 || Math.abs(a.x - b.x) + Math.abs(a.y - b.y) < 9)
				continue;
			// (b down in the level, from where going back up to a takes many moves)
			var d = movesBetween(b, a);
			if (d >= 0 && d < 8)
				continue;
			var v = (d < 0 ? 20 : d) + (b.y - a.y) * 0.5 + g.rnd(100) / 25;
			// (a ground over them already: a passage from a ground to a ground, nothing added)
			if (m[a.x][a.y - 2] > 0)
				v += 6;
			if (m[b.x][b.y - 2] > 0)
				v += 6;
			if (v > bv) {
				bv = v;
				best = {a: a, b: b};
			}
		}
		if (best == null)
			return false;
		var before = g.wayBack();
		var cells:Array<{x:Int, y:Int, v:Int}> = [];
		for (p in [best.a, best.b]) {
			cells.push({x: p.x, y: p.y, v: Data.FIELD_TELEPORT});
			cells.push({x: p.x, y: p.y - 1, v: Data.FIELD_TELEPORT});
			if (m[p.x][p.y - 2] == 0)
				cells.push({x: p.x, y: p.y - 2, v: 1});
		}
		var saved = [for (c in cells) m[c.x][c.y]];
		for (c in cells)
			m[c.x][c.y] = c.v;
		g.computeReach();
		var ok = g.exitOk && g.startOk() && g.openColumns() <= g.openBase;
		if (ok)
			ok = g.wayBack() > before + 0.05;
		if (!ok) {
			for (i in 0...cells.length)
				m[cells[i].x][cells[i].y] = saved[i];
			g.computeReach();
			return false;
		}
		for (c in cells)
			g.mark(c.x, c.y);
		g.teles.push({a: best.a, b: best.b});
		count("tele.ok");
		return true;
	}

	inline function free(x:Int, y:Int):Bool {
		return g.inb(x, y) && m[x][y] == 0 && !g.busy[x][y] && !g.danger[x][y];
	}

	// moves from a standing case to another (-1: not reached)
	function movesBetween(a:GPt, b:GPt):Int {
		var dist = [for (i in 0...W * H) -1];
		var q = [a.x * H + a.y];
		dist[q[0]] = 0;
		var i = 0;
		while (i < q.length) {
			var c = q[i++];
			var n = g.moveTo[c];
			if (n == null)
				continue;
			for (t in n)
				if (dist[t] < 0) {
					dist[t] = dist[c] + 1;
					q.push(t);
				}
		}
		return dist[b.x * H + b.y];
	}

	// ---------------------------------------------------------------- the laser of black bombs

	// the bads of pockets (their ice cannot go out): a laser of black bombs on a passage the ways to them go through, else
	// on a passage of the ways of Igor
	public function killerGate():Bool {
		// (not with the lasers without bombs: the black one would give the bombs back on the way)
		if (g.hasLaser(Data.FIELD_PEACE))
			return false;
		var best:GGate = null;
		var bv = -1.0;
		var zone = g.badZone(true);
		var pockets = [for (s in g.segments()) if (g.pocket(s, zone)) s];
		for (s in sites()) {
			if (nearStart(s))
				continue;
			measure(s);
			if (s.lost == 0)
				continue;
			var v = 0.0;
			for (p in pockets)
				if (s.behind[p.x0 * H + p.y] || s.behind[p.x1 * H + p.y])
					v += 3;
			v += Math.min(4, s.lost * 0.2) + g.rnd(100) / 100;
			if (v > bv) {
				bv = v;
				best = s;
			}
		}
		if (best == null)
			return false;
		put(best, BLACK);
		g.gates.push({cells: best.cells, v: BLACK});
		g.computeReach();
		return true;
	}
}
