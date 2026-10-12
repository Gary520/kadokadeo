package hammerfest;

import hammerfest.Data.AnimDef;

// hammer/entity/Animator.mt: the root clip shows the frame of the animation (gotoAndStop(id + 1)) and the code steps
// its `sub` clip one picture per cycle. Here `pic` shows the pictures of the animation <animBase>_<id>.
class Animator extends Trigger {
	public var pic:Pic;
	public var animBase:String;
	public var animId:Null<Int>;

	public var frame:Float;
	public var animFactor:Float;
	public var blinkTimer:Float;

	public var blinkColor:Int;
	public var blinkColorAlpha:Int;
	public var blinkAlpha:Int;

	public var fl_anim:Bool;
	public var fl_loop:Bool;
	public var fl_blink:Bool;
	public var fl_alphaBlink:Bool;
	public var fl_stickyAnim:Bool;

	var fl_blinking:Bool;
	var fl_blinked:Bool;

	// frame of the sub clip stepped by the code; animations of 1 frame for the code whose nested clips play by
	// themselves (Art.LOGICAL) show their pictures in a loop meanwhile
	var subFrame:Int;
	var subCount:Int;
	var visLoop:Bool;

	public function new(animBase:String) {
		super();
		this.animBase = animBase;
		animId = null;
		frame = 0;
		animFactor = 1.0;
		fl_loop = false;
		fl_blinking = false;
		fl_blinked = true;
		fl_stickyAnim = false;
		fl_alphaBlink = true;
		fl_blink = true;
		blinkTimer = 0;
		blinkColor = 0xffffff;
		blinkAlpha = 20;
		blinkColorAlpha = 30;
		fl_anim = true;
		pic = new Pic(animName(0));
		mc.addChild(pic);
		setSubs();
	}

	override public function init(g:Game) {
		super.init(g);
	}

	public function enableAnimator() {
		fl_anim = true;
	}

	public function disableAnimator() {
		fl_anim = false;
	}

	public function blink(duration:Float) {
		if (!fl_blink)
			return;
		fl_blinking = true;
		blinkTimer = duration;
	}

	public function stopBlink() {
		fl_blinking = false;
		if (fl_alphaBlink)
			alpha = 100;
		else
			resetColor();
	}

	public function blinkLife() {
		if (lifeTimer / totalLife <= 0.1)
			blink(Data.BLINK_DURATION_FAST);
		else if (lifeTimer / totalLife <= 0.3)
			blink(Data.BLINK_DURATION);
	}

	// name of the pictures of an animation id
	public function animName(id:Int):String {
		return animBase + "_" + id;
	}

	public function onEndAnim(id:Int) {
		unstickAnim();
	}

	public function stickAnim() {
		fl_stickyAnim = true;
	}

	public function unstickAnim() {
		fl_stickyAnim = false;
	}

	public function playAnim(a:AnimDef) {
		if (fl_stickyAnim || fl_kill || !fl_anim)
			return;
		if (animId == a.id && fl_loop == a.loop)
			return;
		animId = a.id;
		pic.setAnim(animName(animId));
		pic.show(1);
		setSubs();
		fl_loop = a.loop;
		frame = 0;
	}

	// pictures of the animation set: count of frames for the code
	function setSubs() {
		subFrame = 1;
		var lg = Art.LOGICAL.get(pic.anim);
		visLoop = lg != null && pic.count() > 1;
		subCount = lg != null ? lg : pic.count();
	}

	// the anim is changed outside playAnim (another weapon...): same frame for the code
	public function setPics(name:String) {
		var f = subFrame;
		pic.setAnim(name);
		setSubs();
		subFrame = Std.int(Math.min(f, subCount));
		if (!visLoop)
			pic.show(subFrame);
	}

	public function forceLoop(flag:Bool) {
		fl_loop = flag;
	}

	// shows the pictures of the current animation again (another weapon...): the original replayed it
	public function replayAnim() {
		var id = animId;
		if (id == null)
			return;
		var fid = (id == 1) ? 2 : 1;
		playAnim({id: fid, loop: fl_loop});
		playAnim({id: id, loop: fl_loop});
	}

	// _width / _height of the clip: size of the current picture at the scale of the clip
	override public function get_width():Float {
		var s = Art.SIZE.get(pic.anim);
		if (s == null)
			return 0;
		return s[(pic.cur - 1) * 2] * Math.abs(mc._xscale) / 100;
	}

	override public function get_height():Float {
		var s = Art.SIZE.get(pic.anim);
		if (s == null)
			return 0;
		return s[(pic.cur - 1) * 2 + 1] * Math.abs(mc._yscale) / 100;
	}

	override public function update() {
		super.update();

		// blinking
		if (fl_blink) {
			if (!fl_blinking && lifeTimer > 0)
				blinkLife();
			if (fl_blinking) {
				blinkTimer -= Game.tmod;
				if (blinkTimer <= 0) {
					if (fl_blinked) {
						if (fl_alphaBlink)
							alpha = 100;
						else
							resetColor();
						fl_blinked = false;
					} else {
						if (fl_alphaBlink)
							alpha = blinkAlpha;
						else
							setColorHex(blinkColorAlpha, blinkColor);
						fl_blinked = true;
					}
					blinkLife();
				}
			}
		}

		if (!fl_anim)
			return;

		// nested clips playing by themselves
		if (visLoop)
			pic.show(pic.cur % pic.count() + 1);

		// the sub clip
		if (frame >= 0) {
			var fl_break = false;
			frame += animFactor * Game.tmod;
			while (!fl_break && frame >= 1) {
				if (subFrame == subCount) {
					// (a frame script of the original sends the sub back to one of its pictures: fall, jump...)
					var lf = Art.LOOP_FROM.get(pic.anim);
					if (lf != null) {
						subFrame = lf - 1;
					} else if (fl_loop) {
						subFrame = 1;
					} else {
						frame = -1;
						onEndAnim(animId);
						fl_break = true;
					}
				}
				if (!fl_break) {
					if (subFrame < subCount)
						subFrame++;
					frame--;
				}
			}
			if (!visLoop && !fl_break && pic.cur != subFrame)
				pic.show(subFrame);
		}
	}
}
