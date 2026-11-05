## SimModel の get_stock・get_constant の結果。成功か失敗かは error で判別し、値は value で受け取る。
## 失敗のとき value は 0.0 であり、意味を持たない。error を先に確かめること。
class_name SimValue
extends RefCounted

## OK、または失敗の Error コード（未定義の名前は ERR_DOES_NOT_EXIST、空や長すぎる名前は ERR_INVALID_PARAMETER）。
var error: Error = OK
## 取得した値。error が OK のときだけ意味を持つ。
var value: float = 0.0


func _init(p_error: Error = OK, p_value: float = 0.0) -> void:
	error = p_error
	value = p_value


## 取得に成功したかを返す。
func is_ok() -> bool:
	return error == OK
