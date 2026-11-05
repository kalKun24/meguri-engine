## 式から呼べる関数の許可リスト。ここに無い名前は、式からは呼べない。
## 乱数の関数と、型コンストラクタ、ホストのメソッドは含まない。
class_name ExprFunctions
extends RefCounted

## 許可する関数名と、その引数の数。
const ARITY: Dictionary = {
	"min": 2,
	"max": 2,
	"clamp": 3,
	"abs": 1,
	"floor": 1,
	"round": 1,
	"ceil": 1,
	"sqrt": 1,
	"pow": 2,
}


## 関数名が許可リストにあるかを返す。
static func is_allowed(function_name: String) -> bool:
	return ARITY.has(function_name)


## 許可された関数の引数の数を返す。許可されていない名前では -1 を返す。
static func arity(function_name: String) -> int:
	return ARITY.get(function_name, -1)


## 許可された関数名を、定義順に返す。
static func names() -> Array[String]:
	var result: Array[String] = []
	for function_name: String in ARITY:
		result.append(function_name)
	return result


## 関数を評価する。args の個数は arity と一致していなければならない（組み立て時に確かめてある）。
## 結果が非有限かどうかは、呼び出し側が検査する。
static func call_function(function_name: String, args: Array[float]) -> float:
	match function_name:
		"min":
			return minf(args[0], args[1])
		"max":
			return maxf(args[0], args[1])
		"clamp":
			return clampf(args[0], args[1], args[2])
		"abs":
			return absf(args[0])
		"floor":
			return floorf(args[0])
		# roundf は 0 から遠い方へ丸める（2.5 は 3、-2.5 は -3）。
		"round":
			return roundf(args[0])
		"ceil":
			return ceilf(args[0])
		"sqrt":
			return sqrt(args[0])
		"pow":
			return pow(args[0], args[1])
	return NAN
