package hammerfest;

import pixi.core.textures.Texture;

// A picture of the SWF (frames of an animation of the sheets): _xscale / _yscale 100 = its size in the Flash player,
// whatever the resolution of its textures.
class Pic extends ASprite {
	public var frames(default, null):Array<Texture>;
	public var anim(default, null):String;
	public var cur(default, null):Int;

	var baseScale:Float;

	public function new(anim:String, ?frame:Int = 1) {
		super();
		baseScale = 1;
		setAnim(anim);
		_xscale = 100;
		_yscale = 100;
		show(frame);
	}

	public static inline function res(anim:String):Float {
		var r = Art.RES.get(anim);
		return r == null ? 1.0 : r;
	}

	// another animation (its resolution may differ: the scale is kept)
	public function setAnim(anim:String) {
		if (anim == this.anim)
			return;
		var xs = _xscale;
		var ys = _yscale;
		var old = baseScale;
		this.anim = anim;
		frames = Tex.get(anim);
		baseScale = 1 / (Game.K * res(anim));
		texture = frames[0];
		anchor.copyFrom(frames[0].defaultAnchor);
		cur = 1;
		if (_curState != null) {
			_xscale = xs;
			_yscale = ys;
			// (a texture of another resolution: the scale of the step before converted too, else the picture drawn
			// between the two steps is at a scale between both, too small or too big for a moment: Igor's waits (0.6)
			// flickered at their start and end)
			if (_prevState != null && old != baseScale) {
				_prevState.xscale *= baseScale / old;
				_prevState.yscale *= baseScale / old;
			}
		}
	}

	public inline function show(i:Int) {
		if (i != cur) {
			cur = i;
			texture = frames[i - 1];
		}
	}

	public inline function count():Int {
		return frames.length;
	}

	override public function get__xscale():Float {
		return _curState.xscale * 100 / baseScale;
	}

	override public function set__xscale(v:Float) {
		_curState.xscale = v / 100 * baseScale;
		return v;
	}

	override public function get__yscale():Float {
		return _curState.yscale * 100 / baseScale;
	}

	override public function set__yscale(v:Float) {
		_curState.yscale = v / 100 * baseScale;
		return v;
	}
}
