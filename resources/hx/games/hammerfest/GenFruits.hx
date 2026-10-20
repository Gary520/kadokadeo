package hammerfest;

// The bads of a level (Gen): drawn by weight for the budget of the level (GenRules), then placed one by one where their
// power means something:
// - strawberries far apart (each on its own platform), lemons at the top or at the bottom, bombinos and litchis never
//   together, pears at the end of long platforms on the ways of Igor, pineapples and saws on his ways (never on the
//   block where he lands), leapers in the biggest empty place, apples in the open early and in corners deep down;
// - early in the well a pushed ice killing another fruit (a combo) is welcome, deeper it is avoided; deep down no fruit
//   Igor bombs at ease from the platform over it.
class GenFruits {
	static inline var W = Data.LEVEL_WIDTH;
	static inline var H = Data.LEVEL_HEIGHT;

	public static function weightOf(list:Array<Int>):Float {
		var w = 0.0;
		var straw = 0;
		for (id in list) {
			if (id == Data.BAD_SPEAR)
				continue;
			w += GenRules.kind(id).weight;
			if (id == Data.BAD_FRAISE)
				straw++;
		}
		if (straw == 1)
			w += GenRules.LONE_STRAWBERRY;
		return w;
	}

	static inline function counts(id:Int):Bool {
		return GenRules.kind(id).counts;
	}

	// the bads of a maze (GenShapes.dedale): its rooms have no block for a blob nor air for a bouncing one, a fruit
	// walking as heavy instead (the nearest weight, one of the lineup first); no saw beyond the count of fruits
	public static function forMaze(lineup:Array<Int>, depth:Int):Array<Int> {
		var walkers = [
			for (k in GenRules.KINDS)
				if (k.from <= depth && GenRules.fade(k.id, depth) > 0 && k.counts && GenAnalysis.walks(k.id)) k.id
		];
		var nf = 0;
		for (id in lineup)
			if (GenRules.kind(id).counts && GenAnalysis.walks(id))
				nf++;
		var out = [];
		for (id in lineup) {
			if (GenAnalysis.walks(id)) {
				out.push(id);
				continue;
			}
			if (!GenRules.kind(id).counts && nf >= GenRules.maxFruits(depth))
				continue;
			var w = GenRules.kind(id).weight;
			var best = -1;
			var bd = 1.0e9;
			for (o in walkers) {
				var d = Math.abs(GenRules.kind(o).weight - w) - (lineup.indexOf(o) >= 0 ? 0.5 : 0);
				if (d < bd) {
					bd = d;
					best = o;
				}
			}
			if (best >= 0) {
				out.push(best);
				nf++;
			}
		}
		return out;
	}

	// the bads of the level, the leading one first
	public static function lineupOf(depth:Int, lastLead:Int):Array<Int> {
		var budget = GenRules.budget(depth);
		var nmax = GenRules.maxFruits(depth);
		var nmin = GenRules.minFruits(depth);
		var alpha = GenRules.force(depth);
		var unlocked = [for (k in GenRules.KINDS) if (k.from <= depth && GenRules.fade(k.id, depth) > 0) k.id];
		var intro = [for (k in GenRules.KINDS) if (k.from == depth) k.id];
		var maxKinds = depth < 6 ? 2 : (depth < 14 ? 3 : 4);

		function pick(cands:Array<Int>, boost:Int->Float):Int {
			if (cands.length == 0)
				return -1;
			var ws = [];
			for (id in cands) {
				var k = GenRules.kind(id);
				var w = k.rarity * GenRules.fade(id, depth) * Cs.qt(Math.pow(k.weight, alpha)) * (boost != null ? boost(id) : 1.0);
				ws.push(Std.int(Math.round(w * 1000)));
			}
			var i = Cs.draw(ws);
			return i < 0 ? cands[cands.length - 1] : cands[i];
		}

		var list:Array<Int> = [];
		var lead = intro.length > 0 ? intro[0] : pick(unlocked, function(id) return id == lastLead ? 0.3 : 1.0);
		var lk = GenRules.kind(lead);
		var nl = 1;
		if (lead == Data.BAD_FRAISE)
			nl = depth < 14 ? 2 : Gen.pick([1, 2, 3, 3, 4]);
		else if (lead == Data.BAD_BALEINE || lead == Data.BAD_SAW)
			nl = 1;
		else if (lead == Data.BAD_BOMBE)
			nl = Gen.pick([1, 2]);
		else {
			nl = Std.int(Math.max(1, Math.min(lk.max, Math.round(budget * (intro.length > 0 ? 0.55 : 0.45) / lk.weight))));
			if (intro.length > 0 && lk.max >= 2 && lk.weight * 2 <= budget * 1.1)
				nl = Std.int(Math.max(nl, 2));
		}
		nl = Std.int(Math.min(nl, Math.min(lk.max, counts(lead) ? nmax : 3)));
		for (i in 0...nl)
			list.push(lead);

		function nfruits():Int {
			var n = 0;
			for (id in list)
				if (counts(id))
					n++;
			return n;
		}
		function countOf(id:Int):Int {
			var n = 0;
			for (x in list)
				if (x == id)
					n++;
			return n;
		}
		function kinds():Array<Int> {
			var out = [];
			for (id in list)
				if (out.indexOf(id) < 0)
					out.push(id);
			return out;
		}

		// up to the budget
		for (it in 0...40) {
			var total = weightOf(list);
			if (total >= budget * 0.95)
				break;
			var ks = kinds();
			var cands = [];
			for (id in unlocked) {
				var k = GenRules.kind(id);
				if (countOf(id) >= k.max)
					continue;
				if (id == Data.BAD_SAW && countOf(id) >= 1 + Std.int(Math.max(0, depth - k.from) / 10))
					continue;
				if (ks.indexOf(id) < 0 && ks.length >= maxKinds)
					continue;
				if (counts(id) && nfruits() >= nmax)
					continue;
				// strawberries come in a team: only leading
				if (id == Data.BAD_FRAISE && ks.indexOf(id) < 0)
					continue;
				// the level of its coming: nothing stronger than the new one
				if (intro.length > 0 && ks.indexOf(id) < 0 && k.weight > lk.weight)
					continue;
				if (total + k.weight > budget + k.weight * 0.5)
					continue;
				cands.push(id);
			}
			if (cands.length == 0)
				break;
			var id = pick(cands, function(id) return id == Data.BAD_FRAISE && ks.indexOf(id) >= 0 ? 3.0 : (ks.indexOf(id) >= 0 ? 2.0 : 1.0));
			if (id < 0)
				break;
			list.push(id);
		}
		// too light with no room left: the weakest ones get stronger
		for (it in 0...12) {
			var total = weightOf(list);
			if (total >= budget * 0.9)
				break;
			var weakest = 0;
			for (i in 1...list.length)
				if (GenRules.kind(list[i]).weight < GenRules.kind(list[weakest]).weight)
					weakest = i;
			var old = list[weakest];
			var ks = kinds();
			var ups = [];
			for (id in unlocked) {
				var k = GenRules.kind(id);
				if (k.weight <= GenRules.kind(old).weight || countOf(id) >= k.max || !counts(id) || id == Data.BAD_FRAISE)
					continue;
				if (ks.indexOf(id) < 0 && ks.length >= maxKinds + 1)
					continue;
				if (total - GenRules.kind(old).weight + k.weight > budget * 1.1)
					continue;
				ups.push(id);
			}
			if (ups.length == 0 || (weakest == 0 && intro.length > 0))
				break;
			var id = pick(ups, function(id) return ks.indexOf(id) >= 0 ? 2.0 : 1.0);
			if (id < 0)
				break;
			list[weakest] = id;
		}
		// too heavy: the last ones added go (never the leading ones)
		while (weightOf(list) > budget * 1.15 && list.length > Math.max(1, nmin) && list.length > nl)
			list.pop();
		while (nfruits() < nmin && list.length < 12) {
			var c = [for (id in unlocked) if (counts(id) && id != Data.BAD_FRAISE && countOf(id) < GenRules.kind(id).max) id];
			var id = pick(c, null);
			if (id < 0)
				break;
			list.push(id);
		}
		// the leading ones first, then the bads hardest to place
		var order = [
			Data.BAD_FRAISE => 0, Data.BAD_BALEINE => 1, Data.BAD_SAW => 2, Data.BAD_CITRON => 3, Data.BAD_CRAWLER => 4,
			Data.BAD_POIRE => 5, Data.BAD_ANANAS => 6
		];
		var lead0 = list[0];
		var rest = list.slice(1);
		var keyed = [for (i in 0...rest.length) {id: rest[i], k: (order.exists(rest[i]) ? order.get(rest[i]) : 9) * 100 + i}];
		keyed.sort(function(a, b) return a.k - b.k);
		var out = [lead0];
		for (e in keyed)
			if (e.id == lead0)
				out.push(e.id);
		for (e in keyed)
			if (e.id != lead0)
				out.push(e.id);
		return out;
	}
}

// places the bads of a level one by one, each where its power means something
class GenPlacer {
	static inline var W = Data.LEVEL_WIDTH;
	static inline var H = Data.LEVEL_HEIGHT;

	var lv:GenGrid;
	var an:GenAnalysis;
	var depth:Int;
	var segs:Array<Array<Int>>;

	public var taken:Array<Int> = []; // cases
	public var takenId:Array<Int> = [];

	var lanes:Array<Array<Bool>> = [];
	var fields:Array<Int>;
	var traffic:Array<Int>;
	var topY:Int;
	var botY:Int;
	var halfX:Float;

	public function new(lv:GenGrid, an:GenAnalysis, depth:Int, total:Int) {
		this.lv = lv;
		this.an = an;
		this.depth = depth;
		fields = lv.fieldMap();
		maxShut = Std.int(Math.round(total * GenRules.shutShare(depth)));
		segs = lv.segments();
		topY = H;
		botY = 0;
		for (s in segs) {
			if (s[2] < topY)
				topY = s[2];
			if (s[2] > botY)
				botY = s[2];
		}
		halfX = W / 2.0 - 0.5;
		computeTraffic();
	}

	// the ways of Igor: shortest ways from his landing to each platform and to the way out
	function computeTraffic() {
		traffic = [for (i in 0...W * H) 0];
		var targets = [];
		for (s in segs) {
			var t = Std.int((s[0] + s[1]) / 2) * H + s[2];
			if (targets.indexOf(t) < 0)
				targets.push(t);
		}
		var NW = GenAnalysis.NW;
		for (t in targets)
			for (s in an.pathTo(function(s) return Std.int(s / NW) == t))
				traffic[Std.int(s / NW)] += 1;
		for (s in an.pathTo(function(s) return an.exitState[s]))
			traffic[Std.int(s / NW)] += 3;
	}

	function segTraffic(seg:Array<Int>):Int {
		if (seg == null)
			return 0;
		var n = 0;
		for (x in seg[0]...seg[1] + 1)
			n += traffic[x * H + seg[2]];
		return n;
	}

	public function take(c:Int, id:Int) {
		taken.push(c);
		takenId.push(id);
		if (GenAnalysis.walks(id) && GenAnalysis.caps(id) != null)
			lanes.push(pushLane(c));
	}

	function pushLane(c:Int):Array<Bool> {
		var lane = [for (i in 0...W * H) false];
		for (d in [-1, 1]) {
			var path = [];
			an.push(GenGrid.cx(c), GenGrid.cy(c), d, path);
			for (p in path)
				if (p >= 0)
					lane[p] = true;
		}
		return lane;
	}

	// ---------------------------------------------------------------- the cases a bad can be put in

	function candidates(id:Int):Array<Int> {
		var out = [];
		if (id == Data.BAD_BALEINE) {
			for (x in 2...W - 2)
				for (y in 3...H - 3) {
					var free = true;
					for (dx in -2...3)
						for (dy in -2...3)
							if (lv.ground(x + dx, y + dy))
								free = false;
					if (free)
						out.push(x * H + y);
				}
			return out;
		}
		if (id == Data.BAD_CRAWLER || id == Data.BAD_SAW) {
			var cc = an.comps();
			var bad = [for (k in 0...cc.sizes.length) cc.sizes[k] < 2 || cc.sizes[k] > 60];
			for (c in 0...W * H) {
				var k = cc.comp[c];
				if (k < 0)
					continue;
				var x = GenGrid.cx(c);
				var y = GenGrid.cy(c);
				if (x == 0 || x == W - 1 || y >= H - 1)
					bad[k] = true;
			}
			for (x in 0...W)
				for (y in 0...H - 1)
					if (lv.stand(x, y) && !bad[cc.comp[x * H + y + 1]])
						out.push(x * H + y);
			return out;
		}
		var minLen = (id == Data.BAD_FRAISE || id == Data.BAD_ANANAS || id == Data.BAD_POIRE) ? 3 : 2;
		// (from level 8 not on the floor at the very bottom: its ice slides to the way out at the first push)
		for (pass in 0...2) {
			for (s in segs)
				if (s[1] - s[0] + 1 >= minLen && (pass == 1 || depth < 8 || s[2] < H - 2))
					for (x in s[0]...s[1] + 1)
						out.push(x * H + s[2]);
			if (out.length > 0)
				break;
		}
		return out;
	}

	static inline function dist(a:Int, b:Int):Float {
		var dx = GenGrid.cx(a) - GenGrid.cx(b);
		var dy = GenGrid.cy(a) - GenGrid.cy(b);
		return Math.sqrt(dx * dx + dy * dy);
	}

	function ok(id:Int, c:Int):Bool {
		var x = GenGrid.cx(c);
		var y = GenGrid.cy(c);
		if (fields[c] != 0)
			return false;
		for (t in taken)
			if (Math.abs(GenGrid.cx(t) - x) <= 1 && Math.abs(GenGrid.cy(t) - y) <= 1)
				return false;
		var st = lv.sx * H + lv.sy;
		var d = dist(c, st);
		var safe = depth < 4 ? 6 : (depth < 12 ? 5 : 4);
		if (id == Data.BAD_SAW || id == Data.BAD_CRAWLER || id == Data.BAD_ANANAS || id == Data.BAD_BALEINE)
			safe = Std.int(Math.max(safe, 7));
		if (d < safe)
			return false;
		if (id == Data.BAD_SAW) {
			// not on the block where Igor lands, two saws not side by side
			var cc = an.comps();
			if (cc.comp[x * H + y + 1] >= 0 && cc.comp[x * H + y + 1] == cc.comp[lv.sx * H + lv.sy + 1])
				return false;
			for (i in 0...taken.length)
				if (takenId[i] == Data.BAD_SAW && dist(taken[i], c) < 7)
					return false;
		}
		if (id == Data.BAD_BOMBE)
			for (i in 0...taken.length) {
				var dd = dist(taken[i], c);
				if ((takenId[i] == Data.BAD_BOMBE && dd < 8) || dd < 4)
					return false;
			}
		if (GenAnalysis.walks(id)) {
			var seg = lv.segmentOf(x, y);
			var sseg = lv.segmentOf(lv.sx, lv.sy);
			if (depth < 6 && seg != null && sseg != null && seg[0] == sseg[0] && seg[2] == sseg[2])
				return false;
		}
		// no shooter in line with the landing of Igor early in the well
		if (depth < 8) {
			if (id == Data.BAD_CITRON && Math.abs(x - lv.sx) <= 1)
				return false;
			if ((id == Data.BAD_POMME || id == Data.BAD_POIRE) && Math.abs(y - lv.sy) <= 1)
				return false;
			// a fruit walking to the landing of Igor
			if (GenAnalysis.walks(id) && an.zone(id, c).indexOf(st) >= 0)
				return false;
		}
		// one strawberry a platform
		if (id == Data.BAD_FRAISE) {
			var seg = lv.segmentOf(x, y);
			for (i in 0...taken.length)
				if (takenId[i] == Data.BAD_FRAISE) {
					var s2 = lv.segmentOf(GenGrid.cx(taken[i]), GenGrid.cy(taken[i]));
					if (s2 != null && seg != null && s2[0] == seg[0] && s2[2] == seg[2])
						return false;
				}
		}
		return true;
	}

	// ---------------------------------------------------------------- what each bad likes

	function liking(id:Int, c:Int):Float {
		var x = GenGrid.cx(c);
		var y = GenGrid.cy(c);
		var hard = GenRules.hard(depth);
		var s = 0.0;
		var seg = GenAnalysis.walks(id) || id == Data.BAD_CRAWLER || id == Data.BAD_SAW ? lv.segmentOf(x, y) : null;
		var slen = seg != null ? seg[1] - seg[0] + 1 : 0;
		var dminSame = 20.0;
		var dminAll = 20.0;
		var same:Array<Int> = [];
		for (i in 0...taken.length) {
			var dd = dist(taken[i], c);
			if (dd < dminAll)
				dminAll = dd;
			if (takenId[i] == id) {
				same.push(taken[i]);
				if (dd < dminSame)
					dminSame = dd;
			}
		}
		var zn = an.zone(id, c).length;
		switch (id) {
			case Data.BAD_CERISE:
				s += Math.min(slen, 8) * 0.3;
			case Data.BAD_ORANGE:
				s += Math.min(zn, 30) * 0.15;
			case Data.BAD_POMME:
				if (depth < 22)
					s += Math.min(zn, 25) * 0.1;
				else {
					var walls = (lv.solid(x - 1, y) ? 1 : 0) + (lv.solid(x + 1, y) ? 1 : 0);
					s += 2.0 * walls + (slen <= 4 ? 2.0 : 0.0);
				}
			case Data.BAD_BANANE:
				s += Math.min(zn, 40) * 0.08;
			case Data.BAD_CITRON:
				var mid = (topY + botY) / 2.0;
				s += Math.abs(y - mid) * 0.6;
				if (topY + 2 < y && y < botY - 2)
					s -= 4;
			case Data.BAD_BOMBE:
				s += Math.min(dminAll, 10) * 0.5 + Math.min(dminSame, 14) * 0.6;
			case Data.BAD_POIRE:
				s += Math.min(slen, 10) * 0.4;
				if (seg != null && (x - seg[0] <= 1 || seg[1] - x <= 1))
					s += 2;
				s += Math.min(segTraffic(seg), 20) * 0.1;
				if (teleBy(seg))
					s += 4;
			case Data.BAD_FRAISE:
				if (same.length > 0) {
					s += Math.min(dminSame, 16) * 0.9;
					var rowSeen = false;
					var sideSeen = false;
					for (t in same) {
						if (GenGrid.cy(t) == y)
							rowSeen = true;
						if ((GenGrid.cx(t) < halfX) == (x < halfX))
							sideSeen = true;
					}
					if (!rowSeen)
						s += 2;
					if (!sideSeen)
						s += 2;
				} else
					s += Math.abs(x - halfX) * 0.3;
				s += Math.min(slen, 8) * 0.2;
			case Data.BAD_ABRICOT:
				s += Math.min(zn, 30) * 0.08;
			case Data.BAD_KIWI:
				s += Math.min(segTraffic(seg), 20) * 0.2;
				if (teleBy(seg))
					s += 3;
			case Data.BAD_LITCHI:
				s += Math.min(dminSame, 14) * 0.5;
			case Data.BAD_CRAWLER:
				s += Gen.frand() * 2;
			case Data.BAD_SAW:
				s += Math.min(segTraffic(seg), 25) * 0.3 + Math.min(dminSame, 12) * 0.3;
			case Data.BAD_BALEINE:
				var clear = 0;
				for (r in 2...6) {
					var free = true;
					for (dx in -r...r + 1)
						for (dy in -r...r + 1)
							if (lv.ground(x + dx, y + dy))
								free = false;
					if (free)
						clear = r;
				}
				s += clear * 1.5 + Math.min(dminSame, 12) * 0.4;
			case Data.BAD_ANANAS:
				s += Math.min(segTraffic(seg), 20) * 0.25 + Math.min(dminSame, 12) * 0.3;
			case Data.BAD_FRAMBOISE:
				s += Math.min(dminSame, 12) * 0.3;
			default:
		}
		// spread
		s += Math.min(dminAll, 6) * 0.25;
		// a pushed ice killing another fruit: wanted early, avoided later
		var onLane = false;
		for (ln in lanes)
			if (ln[c])
				onLane = true;
		if (onLane)
			s += 1.5 * (1 - hard) - 3.0 * hard;
		return s;
	}

	// a teleporter on the platform (standing on it, or lying in a hole at one of its ends): the bombs of a pear, the mines
	// of a kiwi go through it and come out of the other one
	function teleBy(seg:Array<Int>):Bool {
		if (seg == null)
			return false;
		var y = seg[2];
		for (x in seg[0] - 1...seg[1] + 2)
			if (x >= 0 && x < W && (fields[x * H + y] == Data.FIELD_TELEPORT || (y + 1 < H && fields[x * H + y + 1] == Data.FIELD_TELEPORT)))
				return true;
		return false;
	}

	// a platform reached by Igor 3 to 6 rows higher with nothing between: he bombs it from there
	function exposed(c:Int):Bool {
		var x = GenGrid.cx(c);
		var y = GenGrid.cy(c);
		for (dx in -2...3) {
			var xx = x + dx;
			for (k in 1...7) {
				var yy = y - k;
				if (yy < 0)
					break;
				if (lv.ground(xx, yy)) {
					if (k >= 3 && yy - 1 >= 0 && an.reach[xx * H + yy - 1])
						return true;
					break;
				}
			}
		}
		return false;
	}

	// fruits put where white bombs never throw their ice out (a laser of other bombs comes for them)
	public var obligations = 0;
	#if gentest
	public static var dbg:Array<String> = [];
	#end
	var maxShut = 0;

	// the case for a bad (-1: none): the best ones for its power, then measured: how many pushes of white bombs its ice
	// takes to leave the level (one push: easy), bombed at ease from the platform over it, in a row with another fruit
	// (the ice of one of them pushed kills the other: surfing); the harder the level, the more these go; up to its share
	// of the fruits go where white bombs never throw them out (shut in)
	public function place(id:Int, ?region:Array<Bool>):Int {
		var cs = [for (c in candidates(id)) if (taken.indexOf(c) < 0 && ok(id, c) && (region == null || within(id, c, region))) c];
		if (cs.length == 0)
			return -1;
		var scored = [for (c in cs) {c: c, s: liking(id, c), p: -1, e: false, surf: false}];
		var hd = GenRules.hard(depth);
		var keep = [];
		for (t in scored) {
			if (id == Data.BAD_SAW) {
				keep.push(t);
				continue;
			}
			var ki = an.killInfo(id, t.c);
			var real = ki[0];
			var hypo = ki[1];
			var hr = depth >= GenRules.RED_FROM ? hypo[1] : 0;
			if (real[0] + real[1] + real[2] + real[3] == 0 && hypo[0] + hr + hypo[2] + hypo[3] == 0)
				continue;
			// (where it starts: a fruit walking to an edge first is not killed at once)
			t.p = real[0] == 0 ? 0 : an.pushesAt(id, t.c);
			t.e = GenAnalysis.walks(id) && exposed(t.c);
			t.surf = surfs(id, t.c);
			if (t.p == 1)
				t.s -= 4 * hd;
			else if (t.p >= 2)
				t.s += 1.5 * hd;
			else
				t.s += obligations < maxShut ? 3.0 * hd : -6;
			if (t.e)
				t.s -= 4 * hd;
			if (t.surf)
				t.s -= 5 * hd;
			keep.push(t);
		}
		if (keep.length == 0)
			return -1;
		// (always from half the hardness on, sometimes before)
		function filter(pred:Dynamic->Bool) {
			if (hd >= 0.5 || Gen.chance(hd)) {
				var f = [for (t in keep) if (pred(t)) t];
				if (f.length > 0)
					keep = f;
			}
		}
		// no ice thrown out at the first push, none in a row with another fruit (surfing): both, else no surfing first
		if (hd >= 0.5 || Gen.chance(hd)) {
			var both = [for (t in keep) if (t.p != 1 && !t.surf) t];
			var ns = [for (t in keep) if (!t.surf) t];
			var np = [for (t in keep) if (t.p != 1) t];
			if (both.length > 0)
				keep = both;
			else if (ns.length > 0)
				keep = ns;
			else if (np.length > 0)
				keep = np;
		}
		filter(function(t) return !t.e);
		if (obligations < maxShut && hd > 0) {
			var f = [for (t in keep) if (t.p == 0) t];
			if (f.length > 0)
				keep = f;
		}
		#if gentest
		var n0 = 0;
		for (t in scored)
			if (t.p == 0)
				n0++;
		dbg.push(id + ":" + scored.length + "/" + n0 + "/" + keep.length + (obligations < maxShut ? "+" : ""));
		#end
		keep.sort(function(a, b) return a.s < b.s ? 1 : (a.s > b.s ? -1 : b.c - a.c));
		var top = keep.slice(0, Std.int(Math.max(3, keep.length / 4)));
		var r = Gen.frand();
		var t = top[Std.int(Math.min(top.length - 1, r * r * top.length))];
		take(t.c, id);
		if (t.p == 0)
			obligations++;
		return t.c;
	}

	// the bad put there stays in the region (it does not walk out of it)
	function within(id:Int, c:Int, region:Array<Bool>):Bool {
		if (!region[c] || !GenAnalysis.walks(id))
			return false;
		for (z in an.zone(id, c))
			if (!region[z])
				return false;
		return true;
	}

	// a fruit put there and another one in a row: the ice of one of them pushed goes through the other (it dies)
	function surfs(id:Int, c:Int):Bool {
		if (!GenAnalysis.walks(id))
			return false;
		for (ln in lanes)
			if (ln[c])
				return true;
		var lane = pushLane(c);
		for (t in taken)
			if (lane[t])
				return true;
		return false;
	}
}
