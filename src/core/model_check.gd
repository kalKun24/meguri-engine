## モデルの定義に入る値（名前と数値）を検査する関数と、エラー文に使う文字列のエスケープ。
## SimModel の add_* と、式の評価（#10）から共通で使う。状態を持たない。
## 検査関数は、問題が無ければ空文字を、あれば利用者向けの理由を返す。呼び出し側が Error コードを選ぶ。
class_name ModelCheck
extends RefCounted

## 名前の最大長（文字数）。これを超える名前は拒否する。
const MAX_NAME_LENGTH: int = 64
## 定義（ストック・定数・フロー・アクションの合計）の最大個数。これを超える定義は拒否する。
const MAX_DEFINITIONS: int = 1000
## 1つのアクションが持てる効果の最大個数。これを超える定義は拒否する。
const MAX_ACTION_EFFECTS: int = 50
## エラー文に名前を出すときの最大長（文字数）。超えた分は「...」で省く。
const MAX_MESSAGE_NAME_LENGTH: int = 32
## エラー文に式（条件・効果の式、アクションの効果の文を含む）を出すときの抜粋の最大長。
## エスケープした後の文字数で数える。超えた分は「...」で省く（「...」も含めてこの長さに収める）。
const MAX_EXPRESSION_EXCERPT_LENGTH: int = 200
## エラー文に原因の説明（式の構文・評価のメッセージ）を出すときの最大長。数え方と省き方は MAX_EXPRESSION_EXCERPT_LENGTH と同じである。
const MAX_MESSAGE_REASON_LENGTH: int = 200
## 画面に出す表示名（ストック・アクションなどの表示名）の最大長。数え方と省き方は MAX_EXPRESSION_EXCERPT_LENGTH と同じである。
const MAX_LABEL_LENGTH: int = 64
## last_error 1件の全体の最大長（エスケープした後の文字数）。SimModel と TownModel の last_error は、これを超えない。
## ExprSyntaxError.format() の出力も、この長さに収まる。
const MAX_LAST_ERROR_LENGTH: int = 1000


## 名前を検査する。空（空白だけ・不可視文字だけを含む）、または MAX_NAME_LENGTH を超えると理由を返す。問題が無ければ空文字を返す。
## what は「ストック名」のような、エラー文に出す呼び名である。
static func check_name(name_value: String, what: String = "名前") -> String:
	if is_blank(name_value):
		return "%sが空である" % what
	if name_value.length() > MAX_NAME_LENGTH:
		return "%sが長すぎる（上限 %d 文字、実際 %d 文字）：%s" % [what, MAX_NAME_LENGTH, name_value.length(), escape(name_value)]
	return ""


## 空、または U+0020 とエスケープ対象の文字（needs_escape）だけからなる文字列かを返す。空の名前として扱う（T2-1）。
static func is_blank(text: String) -> bool:
	for i in text.length():
		var code: int = text.unicode_at(i)
		if code != 0x20 and not needs_escape(code):
			return false
	return true


## 数値が有限かを検査する。NaN・無限大なら理由を返す。問題が無ければ空文字を返す。
## what は「初期値」のような、エラー文に出す呼び名である。
static func check_finite(value: float, what: String = "値") -> String:
	if is_nan(value):
		return "%sが NaN である" % what
	if is_inf(value):
		return "%sが無限大である" % what
	return ""


## 利用者の入力をエラー文やログに出すためのエスケープ。
## ESCAPE_RANGES（Cc・Cf・Zl・Zp・Co、U+0020 以外の Zs、Default_Ignorable_Code_Point）の文字を \u{XXXX} の形にし、バックスラッシュは二重にする。
## limit 文字を超える分は「...」で省く。既定は MAX_MESSAGE_NAME_LENGTH である。0 以下を渡すと省かない。外部由来の文字列には使わない（式は escape_expression を使う）。
## escape_backslash を false にすると、バックスラッシュを二重にしない。既にエスケープ済みの文を、もう一度安全にするときに使う。
static func escape(text: String, limit: int = MAX_MESSAGE_NAME_LENGTH, escape_backslash: bool = true) -> String:
	var parts := PackedStringArray()
	var count := 0
	for i in text.length():
		if limit > 0 and count >= limit:
			parts.append("...")
			break
		var code: int = text.unicode_at(i)
		if code == 0x5C and escape_backslash:
			parts.append("\\\\")
		elif needs_escape(code):
			parts.append("\\u{%04X}" % code)
		else:
			parts.append(text[i])
		count += 1
	return "".join(parts)



## 式（アクションの効果の文を含む）をエラー文やログに出すためのエスケープ。
## 先頭から MAX_EXPRESSION_EXCERPT_LENGTH 文字（エスケープ後）までを抜粋し、超えた分は「...」で省く。式の全文を出してはならない。
## 位置は、呼び出し側が数字で別に出す。
static func escape_expression(text: String) -> String:
	return escape_excerpt(text, MAX_EXPRESSION_EXCERPT_LENGTH)


## エラーの原因の説明（式の構文・評価のメッセージ）をエラー文に出すためのエスケープ。
## 説明は生成時にエスケープ済みの文でもよいので、バックスラッシュは二重にしない。MAX_MESSAGE_REASON_LENGTH 文字までで省く。
static func escape_reason(text: String) -> String:
	return escape_excerpt(text, MAX_MESSAGE_REASON_LENGTH, false)


## エスケープして、エスケープ後の長さが limit 文字に収まるように、先頭から抜粋する。収まらないときは末尾を「...」にする。
## \u{XXXX} の表記を途中で切らない（1文字分をまとめて残すか、まとめて省く）。limit は 4 以上にする。
## escape_backslash の意味は escape と同じである。
static func escape_excerpt(text: String, limit: int, escape_backslash: bool = true) -> String:
	return excerpt_at(text, -1, limit, escape_backslash)["text"]


## escape_expression に加えて、position の文字が抜粋の中で始まる位置も返す。位置を ^ で示す形で、式を出すときに使う。
## 返す Dictionary は、"text"（抜粋）と "offset"（text の中の位置。position の文字が抜粋に入らないときは -1）を持つ。
## position が text の長さと同じで、省かれていないときは、末尾の位置を返す。
static func expression_excerpt(text: String, position: int) -> Dictionary:
	return excerpt_at(text, position, MAX_EXPRESSION_EXCERPT_LENGTH, true)


## escape_excerpt の本体。position は text の中の文字位置で、不要なら -1 を渡す。
static func excerpt_at(text: String, position: int, limit: int, escape_backslash: bool) -> Dictionary:
	var pieces := PackedStringArray()
	var total: int = 0
	var offset: int = -1
	var truncated: bool = false
	for i in text.length():
		var piece: String = _escape_char(text.unicode_at(i), text[i], escape_backslash)
		if total + piece.length() > limit:
			truncated = true
			break
		if i == position:
			offset = total
		pieces.append(piece)
		total += piece.length()
	if not truncated:
		if position >= text.length():
			offset = total
		return {"text": "".join(pieces), "offset": offset}
	# 「...」の分を空けるために、末尾の文字を1文字ずつ省く。
	while total + 3 > limit and not pieces.is_empty():
		total -= pieces[pieces.size() - 1].length()
		pieces.remove_at(pieces.size() - 1)
	if offset >= total:
		offset = -1
	pieces.append("...")
	return {"text": "".join(pieces), "offset": offset}


## エスケープ済みの文を、limit 文字に収まるように切る。収まらないときは末尾を「...」にする。
## 「\\」と「\u{XXXX}」の表記を途中で切らない。last_error の全体の上限（MAX_LAST_ERROR_LENGTH）を守るために使う。
static func limit_escaped(text: String, limit: int) -> String:
	if text.length() <= limit:
		return text
	var cut: int = limit - 3
	var i: int = 0
	while i < text.length():
		var step: int = 1
		if text[i] == "\\" and i + 1 < text.length():
			if text[i + 1] == "\\":
				step = 2
			elif text[i + 1] == "u" and i + 2 < text.length() and text[i + 2] == "{":
				var close: int = text.find("}", i)
				if close >= 0:
					step = close - i + 1
		if i + step > cut:
			break
		i += step
	return text.substr(0, i) + "..."


## last_error に入れる文を、MAX_LAST_ERROR_LENGTH に収める。
static func limit_last_error(message: String) -> String:
	return limit_escaped(message, MAX_LAST_ERROR_LENGTH)


static func _escape_char(code: int, character: String, escape_backslash: bool) -> String:
	if code == 0x5C and escape_backslash:
		return "\\\\"
	if needs_escape(code):
		return "\\u{%04X}" % code
	return character


## コードポイントが、エスケープの対象かを返す。ESCAPE_RANGES を二分探索で引く。
static func needs_escape(code: int) -> bool:
	var low: int = 0
	var high: int = ESCAPE_RANGES.size() / 2 - 1
	while low <= high:
		var mid: int = (low + high) / 2
		if code < ESCAPE_RANGES[mid * 2]:
			high = mid - 1
		elif code > ESCAPE_RANGES[mid * 2 + 1]:
			low = mid + 1
		else:
			return true
	return false


# エスケープ対象の範囲表。T2-1 に従い、判定はこの表だけで行う（文字の列挙で判定しない）。
# 対象：一般カテゴリ Cc・Cf・Zl・Zp・Co、U+0020 以外の Zs、Default_Ignorable_Code_Point。
# BEGIN GENERATED ESCAPE_RANGES
## Unicode 16.0.0。scripts/gen_invisible_ranges.py で生成した。手で書き換えない。
## 2つずつ組で、開始と終了（含む）のコードポイントを小さい順に並べる。
const ESCAPE_RANGES: PackedInt32Array = [
	0x0000, 0x001F,
	0x007F, 0x00A0,
	0x00AD, 0x00AD,
	0x034F, 0x034F,
	0x0600, 0x0605,
	0x061C, 0x061C,
	0x06DD, 0x06DD,
	0x070F, 0x070F,
	0x0890, 0x0891,
	0x08E2, 0x08E2,
	0x115F, 0x1160,
	0x1680, 0x1680,
	0x17B4, 0x17B5,
	0x180B, 0x180F,
	0x2000, 0x200F,
	0x2028, 0x202F,
	0x205F, 0x206F,
	0x3000, 0x3000,
	0x3164, 0x3164,
	0xE000, 0xF8FF,
	0xFE00, 0xFE0F,
	0xFEFF, 0xFEFF,
	0xFFA0, 0xFFA0,
	0xFFF0, 0xFFFB,
	0x110BD, 0x110BD,
	0x110CD, 0x110CD,
	0x13430, 0x1343F,
	0x1BCA0, 0x1BCA3,
	0x1D173, 0x1D17A,
	0xE0000, 0xE0FFF,
	0xF0000, 0xFFFFD,
	0x100000, 0x10FFFD,
]
# END GENERATED ESCAPE_RANGES
