package hammerfest;

// The bads of a level of the well (its lineup): their kinds and how many of each, drawn once for the depth before the
// shape of the level, which is then made for them.
//
// Like the adventure of the original Hammerfest: the kinds come one after the other along the well (cherries,
// oranges, apples, bananas, lemons, bombs, pears, strawberries, apricots, kiwis, litchis, pineapples, raspberries), a
// new one every 2 or 3 levels, first alone in a level of its own (the original: 3 bananas at level 15, 3 lemons at
// 30, 3 bombs at 40, 4 strawberries at 60...), then with the others. A level is led by one kind (most of its bads, the
// places of the level are made for them) with none, one or two other kinds the original puts with it (the lemons go
// with everything, the pears with the apricots...): a third of the levels of the original have one kind, a third two,
// the rest three or more. The number of bads grows slowly with the depth, the strong kinds count for more (a
// pineapple for two), the chapters of 5 levels go from calm to hard.
typedef Cast = {
	lead:Int, // the kind leading the level
	intro:Bool, // its first level in the well
	list:Array<Int> // the bads, the lead ones first
}

class LevelCast {
	// kinds in the order of the well, with the depth of their first level
	public static var ORDER:Array<Array<Int>> = [
		[Data.BAD_CERISE, 0], [Data.BAD_ORANGE, 1], [Data.BAD_POMME, 2], [Data.BAD_BANANE, 3], [Data.BAD_CITRON, 4],
		[Data.BAD_BOMBE, 5], [Data.BAD_POIRE, 6], [Data.BAD_FRAISE, 7], [Data.BAD_ABRICOT, 8], [Data.BAD_KIWI, 9],
		[Data.BAD_LITCHI, 10], [Data.BAD_ANANAS, 11], [Data.BAD_FRAMBOISE, 16]
	];

	// what a bad counts for in the number of bads of a level
	public static function cost(id:Int):Float {
		return switch (id) {
			case Data.BAD_CERISE, Data.BAD_ORANGE: 1.0;
			case Data.BAD_BANANE: 1.15;
			case Data.BAD_POMME, Data.BAD_BOMBE: 1.2;
			case Data.BAD_CITRON: 1.25;
			case Data.BAD_FRAISE: 1.3;
			case Data.BAD_POIRE: 1.35;
			case Data.BAD_ABRICOT: 1.9; // (an apricot gives two small ones: deep in the well the levels never ended)
			case Data.BAD_KIWI: 1.5;
			case Data.BAD_LITCHI: 1.6; // (two hits)
			case Data.BAD_FRAMBOISE: 2.2;
			case Data.BAD_ANANAS: 2.4;
			case Data.BAD_BALEINE: 2.4;
			default: 1.3;
		}
	}

	// how often a kind leads a level (the levels of the original led by each kind)
	static function leadWeight(id:Int):Int {
		return switch (id) {
			case Data.BAD_CITRON: 36;
			case Data.BAD_BOMBE, Data.BAD_POMME, Data.BAD_POIRE: 25;
			case Data.BAD_ABRICOT, Data.BAD_ORANGE, Data.BAD_FRAISE: 22;
			case Data.BAD_CERISE: 17;
			case Data.BAD_FRAMBOISE: 12;
			case Data.BAD_BANANE, Data.BAD_LITCHI, Data.BAD_KIWI: 10;
			case Data.BAD_ANANAS: 6;
			default: 5;
		}
	}

	// kinds the original puts together (levels of the adventure and of the well of Deepnight holding both)
	static function affinity(a:Int, b:Int):Int {
		inline function k(x:Int, y:Int)
			return (a == x && b == y) || (a == y && b == x);
		if (b == Data.BAD_CITRON || a == Data.BAD_CITRON)
			return 14; // (the lemons go with all of them)
		if (k(Data.BAD_CERISE, Data.BAD_ORANGE) || k(Data.BAD_ORANGE, Data.BAD_POMME) || k(Data.BAD_POMME, Data.BAD_BANANE)
			|| k(Data.BAD_ORANGE, Data.BAD_BANANE) || k(Data.BAD_POIRE, Data.BAD_ABRICOT) || k(Data.BAD_FRAISE, Data.BAD_POIRE)
			|| k(Data.BAD_FRAISE, Data.BAD_ANANAS) || k(Data.BAD_FRAISE, Data.BAD_FRAMBOISE) || k(Data.BAD_POIRE, Data.BAD_FRAMBOISE)
			|| k(Data.BAD_POIRE, Data.BAD_BOMBE) || k(Data.BAD_POIRE, Data.BAD_ORANGE))
			return 10;
		if (k(Data.BAD_CERISE, Data.BAD_POMME) || k(Data.BAD_CERISE, Data.BAD_BANANE) || k(Data.BAD_POIRE, Data.BAD_LITCHI)
			|| k(Data.BAD_POIRE, Data.BAD_BANANE) || k(Data.BAD_ABRICOT, Data.BAD_FRAMBOISE) || k(Data.BAD_CERISE, Data.BAD_BOMBE)
			|| k(Data.BAD_ABRICOT, Data.BAD_LITCHI) || k(Data.BAD_FRAISE, Data.BAD_BOMBE) || k(Data.BAD_FRAISE, Data.BAD_ABRICOT)
			|| k(Data.BAD_FRAISE, Data.BAD_KIWI) || k(Data.BAD_KIWI, Data.BAD_POIRE) || k(Data.BAD_ANANAS, Data.BAD_POIRE)
			|| k(Data.BAD_ANANAS, Data.BAD_ABRICOT) || k(Data.BAD_ANANAS, Data.BAD_FRAMBOISE) || k(Data.BAD_ANANAS, Data.BAD_BOMBE)
			|| k(Data.BAD_KIWI, Data.BAD_FRAMBOISE) || k(Data.BAD_KIWI, Data.BAD_LITCHI) || k(Data.BAD_ORANGE, Data.BAD_FRAMBOISE))
			return 6;
		return 2;
	}

	public static function introDepth(id:Int):Int {
		for (r in ORDER)
			if (r[0] == id)
				return r[1];
		return 999;
	}

	// the kind met for the first time at this depth (-1: none)
	public static function introKind(depth:Int):Int {
		for (r in ORDER)
			if (r[1] == depth)
				return r[0];
		return -1;
	}

	public static function unlocked(depth:Int):Array<Int> {
		return [for (r in ORDER) if (depth >= r[1]) r[0]];
	}

	// the chapters of 5 levels (a zone of skins): calm at their start, the hardest at their end
	public static function rhythm(depth:Int):Float {
		// (a steady rise first: the chapters only from level 15)
		return depth < 15 ? 1.0 : [0.95, 1.0, 1.03, 1.06, 1.1][depth % 5];
	}

	// the bads of a level, counted with cost(): 2 or 3 at first, about 6 at level 5, 8 at level 10, 10 to 11 from level
	// 14 (the hard levels of the original: 6 to 13)
	public static function budget(depth:Int):Float {
		// (players: "à partir du niveau 10 on sent déjà le gros pic": a little gentler, the top a level later)
		return Math.min(15, 3 + 0.85 * depth) * rhythm(depth);
	}

	// the most bads in a level (the field is small)
	static function maxBads(depth:Int):Int {
		return depth < 14 ? 10 : 11;
	}

	// bads of a kind in its first level (the original: 3 bananas, 3 lemons, 3 bombs, 2 then 4 pears, 2 apricots...)
	static function introMax(id:Int):Int {
		return switch (id) {
			case Data.BAD_CERISE: 2;
			case Data.BAD_BOMBE: 4;
			default: 3;
		}
	}

	// how many of a kind a level can hold (the original: 5 apples, 4 pears, 6 strawberries, 4 pineapples at the most)
	static function cap(id:Int, lead:Bool, depth:Int):Int {
		return switch (id) {
			case Data.BAD_ANANAS: lead && depth >= 18 ? 2 : 1;
			case Data.BAD_FRAMBOISE: lead ? (depth >= 22 ? 3 : 2) : (depth >= 20 ? 2 : 1);
			case Data.BAD_FRAISE, Data.BAD_POIRE, Data.BAD_POMME, Data.BAD_BANANE: lead ? 4 : 2;
			case Data.BAD_ABRICOT: depth >= 14 ? (lead ? 2 : 1) : (lead ? 3 : 2);
			case Data.BAD_KIWI, Data.BAD_LITCHI: lead ? 4 : 2;
			case Data.BAD_CITRON: lead ? 4 : 3;
			case Data.BAD_CERISE, Data.BAD_ORANGE: lead ? 5 : 3;
			default: lead ? 6 : 3;
		}
	}

	// kinds leading the last levels (not the same twice in a row)
	static var prevLead:Int = -1;
	static var prevLead2:Int = -1;

	public static function reset() {
		prevLead = -1;
		prevLead2 = -1;
	}

	static function rnd(n:Int):Int {
		return Cs.rnd(n);
	}

	static function drawIn(ids:Array<Int>, w:Array<Float>):Int {
		var iw = [for (v in w) Std.int(Math.max(0, v))];
		var i = Cs.draw(iw);
		return i < 0 ? ids[0] : ids[i];
	}

	// the bads of a level drawn for its idea (LevelConcept): its leading kinds, the kinds around them, how many kinds,
	// how hard
	public static function make(depth:Int, ?concept:LevelConcept.Concept, ?open:Bool = false):Cast {
		var b = budget(depth) * (concept != null ? concept.hard : 1.0) * (open && depth >= 4 ? 0.88 : 1.0);
		var intro = introKind(depth);
		var list:Array<Int> = [];
		// (no cherries deep in the well: they only walk)
		var kinds = [for (k in unlocked(depth)) if (k != Data.BAD_CERISE || depth < 10) k];
		var recent = [for (r in ORDER) if (depth >= r[1] && depth - r[1] <= 3) r[0]];
		var lead:Int;
		if (intro >= 0) {
			// the new kind leads its first level (the places of the level made for it): alone at first (the original:
			// 3 bananas at level 15, 3 lemons at 30...), with kinds met before around it from level 8 (a little calmer
			// than the levels around it)
			lead = intro;
			if (depth < 4)
				b *= 0.85;
			if (depth < 3 || lead == Data.BAD_CERISE) {
				var n = Std.int(Math.max(2, Math.min(introMax(lead), Math.round(b / cost(lead)))));
				for (i in 0...n)
					list.push(lead);
				prevLead2 = prevLead;
				prevLead = lead;
				return {lead: lead, intro: true, list: list};
			}
		} else {
			// ---- the lead kind: the recent kinds more often (the player meets them again), the weak ones less deep in
			// the well
			var lw = [for (k in kinds) {
				var w:Float = leadWeight(k);
				if (recent.indexOf(k) >= 0)
					w *= 2.2;
				// (soon the first kinds lead few levels: they come with others; the strong ones lead)
				var weak = k == Data.BAD_CERISE || k == Data.BAD_ORANGE || k == Data.BAD_POMME || k == Data.BAD_BANANE;
				if (weak && depth >= 8)
					w *= depth >= 14 ? 0.25 : 0.5;
				if (!weak && depth >= 12)
					w *= k == Data.BAD_ANANAS || k == Data.BAD_FRAMBOISE ? 1.2 : 1.5;
				if (k == Data.BAD_ABRICOT && depth >= 14)
					w *= 0.5;
				// (the bads of the dimension of the level)
				for (t in LevelTheme.of(depth).leads)
					if (t == k)
						w *= 2;
				if (k == prevLead)
					w *= 0.1;
				else if (k == prevLead2)
					w *= 0.5;
				w;
			}];
			// (the kinds the idea of the level is made for)
			if (concept != null && concept.leads.length > 0) {
				var cw = [for (i in 0...kinds.length) concept.leads.indexOf(kinds[i]) >= 0 ? Math.max(lw[i], 1) : 0];
				var sum = 0.0;
				for (v in cw)
					sum += v;
				if (sum > 0)
					lw = cw;
			}
			lead = drawIn(kinds, lw);
		}
		prevLead2 = prevLead;
		prevLead = lead;
		// ---- the number of kinds
		var nk = if (depth < 2) 1 else if (depth < 6) [1, 2, 2, 2, 3][rnd(5)] else if (depth < 12) [1, 2, 2, 3, 3, 3][rnd(6)] else
			[2, 2, 3, 3, 3, 4][rnd(6)];
		if (intro >= 0)
			nk = 2;
		else if (concept != null && concept.kinds.length > 0)
			nk = concept.kinds[rnd(concept.kinds.length)];
		// (a pineapple or a raspberry leads with other kinds around it: a level holds one or two of them)
		if (cap(lead, true, depth) <= 2 && nk < 2)
			nk = 2;
		nk = Std.int(Math.min(nk, kinds.length));
		var chosen = [lead];
		var pool = [for (k in kinds) if (k != lead) k];
		// (the kinds around the leading one: the ones of the idea of the level)
		if (concept != null && concept.support.length > 0) {
			var sp = [for (k in pool) if (concept.support.indexOf(k) >= 0) k];
			if (sp.length > 0)
				pool = sp;
		}
		while (chosen.length < nk && pool.length > 0) {
			var w = [for (k in pool) {
				var v:Float = affinity(lead, k);
				// (around a new kind: the kinds met before it, the strong ones hardly)
				if (intro >= 0)
					v *= depth - introDepth(k) >= 3 ? 1.5 : 0.4;
				for (c in chosen)
					if (c != lead)
						v *= affinity(c, k) / 8;
				if (recent.indexOf(k) >= 0)
					v *= 1.6;
				// (the strong ones are rare around another kind at first)
				if (k == Data.BAD_ANANAS || k == Data.BAD_FRAMBOISE)
					v *= depth < 15 ? 0.5 : 0.9;
				v * 10;
			}];
			var k = drawIn(pool, w);
			chosen.push(k);
			pool.remove(k);
		}
		// ---- the counts: the lead kind most of the budget, at least one of each other kind; a kind more when the
		// ones there are full (the strong kinds, few in a level)
		var counts = [for (c in chosen) 0];
		var used = 0.0;
		for (i in 0...chosen.length) {
			counts[i] = 1;
			used += cost(chosen[i]);
		}
		var minLead = intro >= 0 ? Std.int(Math.min(introMax(lead), cap(lead, true, depth))) : Std.int(Math.min(2, cap(lead, true, depth)));
		while (counts[0] < minLead && used + cost(lead) <= b + 1) {
			counts[0]++;
			used += cost(lead);
		}
		var leadShare = chosen.length == 1 ? 1.0 : (intro >= 0 ? 0.65 : 0.5 + rnd(25) / 100);
		var guard = 0;
		// (10 bads at the most: the field is small)
		inline function total() {
			var n = 0;
			for (c in counts)
				n += c;
			return n;
		}
		// (a level of an idea keeps to its kinds: one or two more of each instead of another kind; not the ones placed
		// with care, few in a level: the strawberries, the strong ones)
		var idea = concept != null && intro < 0;
		inline function more(id:Int):Int
			return !idea || id == Data.BAD_FRAISE || id == Data.BAD_ANANAS || id == Data.BAD_FRAMBOISE || id == Data.BAD_ABRICOT
				|| id == Data.BAD_BALEINE ? 0 : 2;
		while (guard++ < 60 && total() < maxBads(depth)) {
			// the kind that is the furthest under its share of the budget
			var best = -1;
			var bestGap = 0.0;
			for (i in 0...chosen.length) {
				var id = chosen[i];
				if (counts[i] >= cap(id, i == 0, depth) + more(id) || used + cost(id) > b + 0.4)
					continue;
				var share = i == 0 ? leadShare : (1 - leadShare) / Math.max(1, chosen.length - 1);
				var gap = share * b - counts[i] * cost(id);
				if (best < 0 || gap > bestGap) {
					best = i;
					bestGap = gap;
				}
			}
			if (best < 0) {
				if (used >= b * 0.8 || pool.length == 0 || chosen.length >= (idea ? 3 : 4))
					break;
				var w = [for (k in pool) affinity(lead, k) * 10.0];
				var k = drawIn(pool, w);
				chosen.push(k);
				pool.remove(k);
				counts.push(1);
				used += cost(k);
				leadShare = Math.min(leadShare, 0.7);
				continue;
			}
			counts[best]++;
			used += cost(chosen[best]);
		}
		// a strawberry alone with other kinds throws its ball at Igor (it has nobody to pass it to): kept so, the
		// isolated one; two pass it to each other across the level
		for (i in 0...chosen.length)
			for (j in 0...counts[i])
				list.push(chosen[i]);
		// deeper, harder: a strawberry alone (its ball thrown at Igor wherever he is, from a perch far away) and
		// pineapples (their landings knock him out wherever he stands), more of them deeper
		// (from level 14: the big rise came too soon)
		if (depth >= 14 && intro < 0 && (concept == null || concept.extras)) {
			if (list.indexOf(Data.BAD_FRAISE) < 0 && rnd(100) < Std.int(Math.min(45, 15 + (depth - 14) * 2)))
				addHard(list, Data.BAD_FRAISE, lead, depth);
			var pine = 0;
			for (id in list)
				if (id == Data.BAD_ANANAS)
					pine++;
			if (pine < (depth >= 22 ? 2 : 1) && rnd(100) < Std.int(Math.min(55, 15 + (depth - 14) * 2.5)))
				addHard(list, Data.BAD_ANANAS, lead, depth);
		}
		// (the leapers: the idea made for them; one now and then in the ideas of the open air, where they fly)
		if (concept != null && concept.id == "bondissantes")
			addLeaper(list, lead, depth, true);
		else if (concept != null && (concept.id == "vide" || concept.id == "framboises") && depth > LEAPER_DEPTH
			&& rnd(100) < 25)
			addLeaper(list, lead, depth, true);
		return {lead: lead, intro: intro >= 0, list: list};
	}

	// the leapers (Bondissantes): flying watermelons bouncing at 45 degrees off everything, faster and faster with
	// their anger, very hard to hit deep in the well: only from level 25 (one in its first level, then in the levels of
	// their idea, now and then in the open air), one at a time (two now and then from level 45)
	public static inline var LEAPER_DEPTH = 25;

	static function addLeaper(list:Array<Int>, lead:Int, depth:Int, ?always:Bool = false) {
		if (depth < LEAPER_DEPTH)
			return;
		var p = always || depth == LEAPER_DEPTH ? 100 : Std.int(Math.min(32, 20 + (depth - LEAPER_DEPTH) * 0.5));
		if (rnd(100) >= p)
			return;
		addHard(list, Data.BAD_BALEINE, lead, depth);
		if (depth >= 45 && rnd(100) < 10)
			addHard(list, Data.BAD_BALEINE, lead, depth);
	}

	// a bad more, or in place of the weakest one that is not of the leading kind when the level is full
	static function addHard(list:Array<Int>, id:Int, lead:Int, depth:Int) {
		if (list.length < maxBads(depth)) {
			list.push(id);
			return;
		}
		var wi = -1;
		for (i in 0...list.length)
			if (list[i] != lead && list[i] != id && (wi < 0 || cost(list[i]) < cost(list[wi])))
				wi = i;
		if (wi >= 0)
			list[wi] = id;
	}
}
