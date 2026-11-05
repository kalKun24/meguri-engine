## 式の字句解析が返す、1つの字句（トークン）である。
class_name ExprToken
extends RefCounted

## 字句の種類。
enum Type {
	NUMBER,
	NAME,
	PLUS,
	MINUS,
	STAR,
	SLASH,
	PERCENT,
	LT,
	LE,
	GT,
	GE,
	EQ,
	NE,
	LPAREN,
	RPAREN,
	COMMA,
	END,
	ERROR,
}

## 字句の種類。
var type: Type = Type.END
## 式の中で字句が元々書かれていた文字列。ERROR のときは、原因の説明である。
var text: String = ""
## 式の中の開始位置（0 始まりの文字位置）。
var position: int = 0
## NUMBER のときの値。
var number: float = 0.0


func _init(p_type: Type = Type.END, p_text: String = "", p_position: int = 0) -> void:
	type = p_type
	text = p_text
	position = p_position
