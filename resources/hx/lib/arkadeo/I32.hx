package arkadeo;

/**
 * AS3 computes with doubles and converts to a 32 bit int when a value is stored into an int (an int variable, field
 * or parameter): I32.of does that conversion where the original stored a value that can overflow (Haxe on JS keeps
 * the double).
 */
class I32 {
	// (the outer parentheses matter: Haxe pastes the code as is, `x | 0 & m` or `x | 0 + n` would bind to the 0)
	public static inline function of(v:Float):Int {
		return js.Syntax.code("(({0}) | 0)", v);
	}

	// int(a * b) of AS3 (doubles, then the conversion)
	public static inline function mul(a:Float, b:Float):Int {
		return of(a * b);
	}
}
