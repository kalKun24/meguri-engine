## 式の構文エラーである。式の全文（保持用。エラー文には抜粋だけを出す）、文字位置、原因の説明を持つ。
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


## 人が読む形にする。1行目に位置と原因、続けて式の抜粋と、位置を示す ^ を出す。
## 式が長いときは、position の付近だけを抜粋し、省いた側に「...」を付ける（ModelCheck.excerpt_around）。出力の長さには上限がある。
## 式の抜粋と原因は、見えない文字を \\u{XXXX} にしてから出す。^ は、エスケープ後の抜粋の中で、position の文字の下に来る。
## 原因（message）は、生成時にエスケープ済みの文でもよい。バックスラッシュは二重にしない。
func format() -> String:
	var excerpt: Dictionary = ModelCheck.excerpt_around(source, position)
	return "構文エラー（位置 %d）：%s\n  %s\n  %s^" % [
		position, ModelCheck.escape_reason(message), excerpt["text"], " ".repeat(excerpt["offset"])
	]
