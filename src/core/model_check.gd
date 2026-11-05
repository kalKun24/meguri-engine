## モデルの定義に入る値（名前と数値）を検査する関数と、エラー文に使う文字列のエスケープ。
## SimModel の add_* と、式の評価（#10）から共通で使う。状態を持たない。
## 検査関数は、問題が無ければ空文字を、あれば利用者向けの理由を返す。呼び出し側が Error コードを選ぶ。
class_name ModelCheck
extends RefCounted

## 名前の最大長（文字数）。これを超える名前は拒否する。
const MAX_NAME_LENGTH: int = 64
## 定義（ストック・定数・フローの合計）の最大個数。これを超える定義は拒否する。
const MAX_DEFINITIONS: int = 1000
## エラー文に名前を出すときの最大長（文字数）。超えた分は「...」で省く。
const MAX_MESSAGE_NAME_LENGTH: int = 32


## 名前を検査する。空、または MAX_NAME_LENGTH を超えると理由を返す。問題が無ければ空文字を返す。
## what は「ストック名」のような、エラー文に出す呼び名である。
static func check_name(name_value: String, what: String = "名前") -> String:
	if name_value.is_empty():
		return "%sが空である" % what
	if name_value.length() > MAX_NAME_LENGTH:
		return "%sが長すぎる（上限 %d 文字、実際 %d 文字）：%s" % [what, MAX_NAME_LENGTH, name_value.length(), escape(name_value)]
	return ""


## 数値が有限かを検査する。NaN・無限大なら理由を返す。問題が無ければ空文字を返す。
## what は「初期値」のような、エラー文に出す呼び名である。
static func check_finite(value: float, what: String = "値") -> String:
	if is_nan(value):
		return "%sが NaN である" % what
	if is_inf(value):
		return "%sが無限大である" % what
	return ""


## 利用者の入力をエラー文やログに出すためのエスケープ。
## 制御文字・bidi 制御・ゼロ幅文字・行区切りなどを \u{XXXX} の形にし、バックスラッシュは二重にする。
## MAX_MESSAGE_NAME_LENGTH を超える分は「...」で省く。
static func escape(text: String) -> String:
	var result := ""
	var count := 0
	for i in text.length():
		if count >= MAX_MESSAGE_NAME_LENGTH:
			result += "..."
			break
		var code: int = text.unicode_at(i)
		if code == 0x5C:
			result += "\\\\"
		elif _is_invisible(code):
			result += "\\u{%04X}" % code
		else:
			result += text[i]
		count += 1
	return result


static func _is_invisible(code: int) -> bool:
	return (
		code <= 0x1F
		or (code >= 0x7F and code <= 0x9F)
		or code == 0x061C
		or (code >= 0x200B and code <= 0x200F)
		or (code >= 0x2028 and code <= 0x202E)
		or (code >= 0x2060 and code <= 0x206F)
		or code == 0xFEFF
	)
