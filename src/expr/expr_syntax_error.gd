## 式の構文エラーである。式の全文、文字位置、原因の説明を持つ。
class_name ExprSyntaxError
extends RefCounted

## エラーになった式の全文。
var source: String = ""
## エラーの位置（0 始まりの文字位置）。式の末尾で終端エラーになるときは、式の長さと同じである。
var position: int = 0
## 原因の説明。
var message: String = ""


func _init(p_source: String = "", p_position: int = 0, p_message: String = "") -> void:
	source = p_source
	position = p_position
	message = p_message


## 人が読む形にする。1行目に位置と原因、続けて式の全文と、位置を示す ^ を出す。
func format() -> String:
	return "構文エラー（位置 %d）：%s\n  %s\n  %s^" % [position, message, source, " ".repeat(position)]
