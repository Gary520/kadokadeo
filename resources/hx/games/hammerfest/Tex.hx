package hammerfest;

import pixi.core.textures.Texture;

// textures of the animations of the game spritesheets (looked up once, in the sheets of this game only: the
// frame names of another game loaded in the same page cannot collide)
class Tex {
	static inline var SHEETS = "/hammerfest/";

	static var cache:Map<String, Array<Texture>> = new Map();
	static var sheets:Array<Dynamic> = null;
	static var anims:Dynamic = null;

	public static function get(name:String):Array<Texture> {
		var a = cache.get(name);
		if (a != null)
			return a;
		if (sheets == null || anims == null || !Reflect.hasField(anims, name))
			findSheets();
		var names:Array<String> = anims != null ? Reflect.field(anims, name) : null;
		if (names == null)
			names = [name + ".png"];
		a = [for (n in names) frame(n)];
		cache.set(name, a);
		return a;
	}

	static function frame(n:String):Texture {
		for (s in sheets) {
			var t = Reflect.field(s.textures, n);
			if (t != null)
				return t;
		}
		return Texture.from(n);
	}

	static function findSheets() {
		sheets = [];
		var res = untyped PIXI.Loader.shared.resources;
		for (k in Reflect.fields(res)) {
			var r = Reflect.field(res, k);
			var sheet = r.spritesheet;
			if (sheet == null)
				continue;
			var url:String = r.url != null ? r.url : k;
			if (url.indexOf(SHEETS) < 0)
				continue;
			sheets.push(sheet);
			if (sheet.data.animations != null && Reflect.fields(sheet.data.animations).length > 0)
				anims = sheet.data.animations;
		}
	}
}
