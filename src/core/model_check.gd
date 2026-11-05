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
## limit 文字を超える分は「...」で省く。既定は MAX_MESSAGE_NAME_LENGTH である。0 以下を渡すと省かず、全文を出す（式の全文など）。
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
