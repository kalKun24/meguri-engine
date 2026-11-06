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
## エラー文に式（条件・効果の式を含む）を出すときの最大長（文字数）。超えた分は「...」で省く。
## エスケープで1文字が最長10文字（\u{10FFFF}）になっても、出力は 1003 文字以内に収まる。
const MAX_MESSAGE_EXPRESSION_LENGTH: int = 100
## エラー文に原因の説明（式の構文・評価のメッセージ）を出すときの最大長（文字数）。超えた分は「...」で省く。
const MAX_MESSAGE_REASON_LENGTH: int = 200
## 画面に出す表示名（ストック・アクションなどの表示名）の最大長（文字数）。超えた分は「...」で省く。
const MAX_LABEL_LENGTH: int = 64
## SimModel の last_error と ExprSyntaxError.format() の長さ（エスケープ後の文字数）の上限。
## 名前・式・原因の各上限が、エスケープで最長の10文字に伸びたときの合計に、定型文の分を足しても、これを超えない。
const MAX_ERROR_OUTPUT_LENGTH: int = 4000


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


## 式をエラー文やログに出すためのエスケープ。escape と同じ変換をし、MAX_MESSAGE_EXPRESSION_LENGTH 文字を超える分は「...」で省く。
## 式の全文を出してはならない（長さに上限が無いと、エラー文が際限なく伸びる）。位置は別に数字で出す。
static func escape_expression(text: String) -> String:
	return escape(text, MAX_MESSAGE_EXPRESSION_LENGTH)


## エラーの原因の説明（式の構文・評価のメッセージ）をエラー文に出すためのエスケープ。
## 説明は生成時にエスケープ済みの文でもよいので、バックスラッシュは二重にしない。MAX_MESSAGE_REASON_LENGTH 文字を超える分は「...」で省く。
static func escape_reason(text: String) -> String:
	return escape(text, MAX_MESSAGE_REASON_LENGTH, false)


## 式の中の position 付近を、エラー文に出す抜粋にする。escape_expression と違い、position が長い式の後ろにあっても抜粋に入る。
## 抜粋は、position の前に最大 MAX_MESSAGE_EXPRESSION_LENGTH / 2 文字、全体で最大 MAX_MESSAGE_EXPRESSION_LENGTH 文字の範囲である。
## 省いた側には「...」を付ける。返す Dictionary は、"text"（エスケープ済みの抜粋）と "offset"（text の中で position の文字が始まる位置）を持つ。
static func excerpt_around(text: String, position: int) -> Dictionary:
	var clamped: int = clampi(position, 0, text.length())
	var start: int = maxi(0, clamped - MAX_MESSAGE_EXPRESSION_LENGTH / 2)
	var end: int = mini(text.length(), start + MAX_MESSAGE_EXPRESSION_LENGTH)
	var head: String = "..." if start > 0 else ""
	var tail: String = "..." if end < text.length() else ""
	var offset: int = head.length() + escape(text.substr(start, clamped - start), 0).length()
	return {"text": head + escape(text.substr(start, end - start), 0) + tail, "offset": offset}


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
