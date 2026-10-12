package hammerfest;

typedef NextAction = {dx:Null<Float>, dy:Null<Float>, delay:Float, action:Int};

// hammer/entity/Mover.mt: a decision taken after a delay (move, walk, shoot...)
class Mover extends Physics {
	public var next:NextAction;
	public var fl_bounce:Bool;
	public var bounceFactor:Float;

	public function new(animBase:String) {
		super(animBase);
		fl_bounce = false;
		bounceFactor = 0.5;
		next = null;
	}

	public function setNext(dx:Null<Float>, dy:Null<Float>, delay:Float, action:Int) {
		next = {
			dx: dx,
			dy: dy,
			delay: delay,
			action: action
		};
	}

	public function onNext() {
		if (next.action == Data.ACTION_MOVE) {
			dx = next.dx;
			dy = next.dy;
			if (dy != 0)
				fl_stable = false;
			next = null;
		}
	}

	override public function onKill() {
		super.onKill();
		next = null;
	}

	override public function onHitGround(h:Float) {
		if (fl_bounce) {
			var b = bounceFactor * Math.abs(dy);
			if (b >= 2) {
				setNext(dx, -b, 0, Data.ACTION_MOVE);
				fl_skipNextGravity = true;
			}
		}
		super.onHitGround(h);
	}

	public function isReady():Bool {
		return fl_stable && next == null;
	}

	override public function update() {
		if (next != null) {
			next.delay -= Game.tmod;
			if (next.delay <= 0)
				onNext();
		}
		super.update();
	}
}
