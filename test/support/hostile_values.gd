## 敵対的な値の共有一覧（チーム合意 T2-1）。外部由来の値を受け取る公開関数のテストが、全件を流す。
## 新しい種類の値は、ここに足すだけで、HostileValues を使う全テストに効く。
## 不可視文字は、文字コードから char() で作る。ソースに生の不可視文字を書かない。
##
## 使い方：
##   for label: String in HostileValues.strings():
##       var value: String = HostileValues.strings()[label]
##       ...  # value を名前・式・流出元・流入先などに渡す
##   for label: String in HostileValues.floats(): ...
##   for pair: Array in HostileValues.overflow_pairs(): ...  # [初期値, 加える量]
class_name HostileValues
extends RefCounted


## 敵対的な文字列。キーは失敗時に出す名前、値は渡す文字列である。
## 名前・式・流出元・流入先のどれにも渡せる。
static func strings() -> Dictionary:
	var all: Dictionary = {
		"空文字": "",
		"空白": " ",
		"空白の連続": " ".repeat(10),
		"U+200B だけ": char(0x200B),
		"U+200B の連続": char(0x200B).repeat(10),
		"U+202E を含む": "a" + char(0x202E) + "b",
		"U+202E だけ": char(0x202E),
		"U+00AD（ソフトハイフン）を含む": "a" + char(0x00AD) + "b",
		"異体字選択子 U+FE0F を含む": "a" + char(0xFE0F) + "b",
		"タグ文字 U+E0041 を含む": "a" + char(0xE0041) + "b",
		"U+00A0（改行しない空白）だけ": char(0x00A0),
		"U+3000（全角空白）だけ": char(0x3000),
		"U+2028（行区切り）を含む": "a" + char(0x2028) + "b",
		"私用領域 U+E000 を含む": "a" + char(0xE000) + "b",
		"U+3164（ハングルフィラー）だけ": char(0x3164),
		"改行を含む": "a" + char(0x0A) + "b",
		"バックスラッシュを含む": "a\\b",
		"エスケープ表記に見える文字列": "\\u{202E}",
		"長さ10万": "x".repeat(100000),
		"長さ10万の不可視文字": char(0x200B).repeat(100000),
		"長さ10万のタグ文字（エスケープで10倍）": char(0xE0041).repeat(100000),
		"長さ10万の制御文字（エスケープで8倍）": char(0x01).repeat(100000),
		"長さ10万のバックスラッシュ（エスケープで2倍）": "\\".repeat(100000),
		"長さ10万の演算子と不可視文字の交互": ("1 +" + char(0x202E)).repeat(25000),
		"深さ1000の入れ子（括弧）": "(".repeat(1000) + "1" + ")".repeat(1000),
		"深さ1000の入れ子（関数）": "min(".repeat(1000) + "1" + ", 1)".repeat(1000),
		"深さ1000の入れ子（単項）": "-".repeat(1000) + "1",
		"float に収まらない数": "1" + "0".repeat(400),
		"1e308 + 1e308": "1" + "0".repeat(308) + " + 1" + "0".repeat(308),
	}
	return all


## 敵対的な float。キーは名前、値は渡す数である。
static func floats() -> Dictionary:
	var all: Dictionary = {
		"NaN": NAN,
		"INF": INF,
		"-INF": -INF,
	}
	return all


## 足すと無限大になる、有限の2つの数の組 [a, b]。a + a、a + b のどちらも float の範囲を超える。
static func overflow_pairs() -> Array[Array]:
	var all: Array[Array] = [
		[1e308, 1e308],
		[-1e308, -1e308],
		[1.7976931348623157e308, 1.7976931348623157e308],
	]
	return all


## 文字列 text に、エスケープ対象の文字（ModelCheck.needs_escape）が残っているかを返す。
## 残っていれば、最初の文字の説明（位置とコードポイント）を返す。残っていなければ空文字を返す。
static func find_raw_invisible(text: String) -> String:
	for i in text.length():
		var code: int = text.unicode_at(i)
		if ModelCheck.needs_escape(code):
			return "位置 %d に生の U+%04X" % [i, code]
	return ""
