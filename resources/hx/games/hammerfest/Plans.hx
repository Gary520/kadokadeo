package hammerfest;

// DepthManager of the original (a clip attached on a plan goes over the others of its plan): one container per plan,
// in the order of the plans. Adding is immediate (no depth table, no sort of all the children: the scissors on a long
// snake add more than a thousand particles at once).
class Plans {
	var root:ASprite;
	var plans:Array<ASprite>;

	public function new(root:ASprite) {
		this.root = root;
		plans = [];
	}

	public function getMC():ASprite {
		return root;
	}

	function plan(p:Int):ASprite {
		var mc = plans[p];
		if (mc == null) {
			mc = root.createEmptyMovieClip("plan" + p, p);
			plans[p] = mc;
		}
		return mc;
	}

	public function add<T:ASprite>(mc:T, p:Int):T {
		plan(p).addChild(mc);
		return mc;
	}

	public function empty(p:Int):ASprite {
		return add(new ASprite(), p);
	}
}
