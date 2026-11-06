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


## 人が読む形にする。1行目に位置と原因、2行目に式の抜粋、3行目に位置を示す ^ を出す。
## 式は、先頭から ModelCheck.MAX_EXPRESSION_EXCERPT_LENGTH 文字（エスケープ後）までを抜粋し、超えた分は「...」にする。
## 位置が抜粋の外にあるとき、^ の行は出さない。位置は1行目の数字で分かる。
## 式の抜粋と原因は、見えない文字を \u{XXXX} にしてから出す。^ は、エスケープ後の抜粋の中で、position の文字の下に来る。
## 原因（message）は、生成時にエスケープ済みの文でもよい。バックスラッシュは二重にしない。
## 出力全体は ModelCheck.MAX_LAST_ERROR_LENGTH 文字に収まる。
func format() -> String:
	var excerpt: Dictionary = ModelCheck.expression_excerpt(source, position)
	var text: String = "構文エラー（位置 %d）：%s\n  %s" % [position, ModelCheck.escape_reason(message), excerpt["text"]]
	var offset: int = excerpt["offset"]
	if offset >= 0:
		text += "\n  %s^" % " ".repeat(offset)
	return text


