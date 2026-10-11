package hammerfest;

// hammer/entity/Trigger.mt: the entity registers itself in the cases it covers (collisions between entities)
class Trigger extends Entity {
	public var fl_largeTrigger:Bool;

	public function new() {
		super();
		fl_largeTrigger = false;
	}

	public function tAddSingle(cx:Int, cy:Int) {
		if (cx < 0 || cx >= Data.LEVEL_WIDTH || cy < 0 || cy >= Data.LEVEL_HEIGHT)
			return;
		world.triggers[cx][cy].push(this);
	}

	public function tRemSingle(cx:Int, cy:Int) {
		if (cx < 0 || cx >= Data.LEVEL_WIDTH || cy < 0 || cy >= Data.LEVEL_HEIGHT)
			return;
		var list = world.triggers[cx][cy];
		var i = 0;
		while (i < list.length) {
			if (list[i] == this) {
				list.splice(i, 1);
				i--;
			}
			i++;
		}
	}

	public function tAdd(cx:Int, cy:Int) {
		tAddSingle(cx, cy);
		tAddSingle(cx - 1, cy);
		tAddSingle(cx + 1, cy);
		tAddSingle(cx, cy - 1);
		if (fl_largeTrigger)
			tAddSingle(cx, cy + 1);
	}

	public function tRem(cx:Int, cy:Int) {
		tRemSingle(cx, cy);
		tRemSingle(cx - 1, cy);
		tRemSingle(cx + 1, cy);
		tRemSingle(cx, cy - 1);
		if (fl_largeTrigger)
			tRemSingle(cx, cy + 1);
	}

	public function moveTo(x:Float, y:Float) {
		tRem(cx, cy);
		this.x = x;
		this.y = y - 1;
		updateCoords();
		tAdd(cx, cy);
	}

	public function moveToCase(cx:Int, cy:Int) {
		moveTo(Entity.x_ctr(cx), Entity.y_ctr(cy));
	}

	// entities of a type in the current case
	public function getByType(type:Int):Array<Entity> {
		var out = [];
		if (cx < 0 || cx >= Data.LEVEL_WIDTH || cy < 0 || cy >= Data.LEVEL_HEIGHT)
			return out;
		for (e in world.triggers[cx][cy]) {
			if ((e.types & type) != 0)
				out.push(e);
		}
		return out;
	}
}
