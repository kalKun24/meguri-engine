## 自動実行の結果を CSV の文字列にする。状態を持たない。
## 浮動小数点の文字列化は format_float の1か所、名前（見出し）の安全化は escape_field の1か所にまとめる。
## 改行は RFC 4180 に従い CRLF である。
class_name CsvFormat
extends RefCounted

## 行の終わり（RFC 4180）。
const LINE_END: String = "\r\n"

## 最初の列（ターン番号）の見出し。
const TURN_HEADER: String = "turn"

## 名前1つを出すときの最大長（エスケープした後の文字数）。
## 名前の上限（ModelCheck.MAX_NAME_LENGTH）の文字がすべて 10 文字にエスケープされても収まる長さである。
const MAX_FIELD_LENGTH: int = ModelCheck.MAX_LAST_ERROR_LENGTH

## 先頭にあると表計算ソフトが式として扱う文字。名前の先頭にあるときは、先頭に「'」を足す。
const FORMULA_PREFIXES: String = "=+-@"


## 浮動小数点を、読み戻すと同じ値になる文字列にする（Godot の var_to_str。17 桁までの最短の表記）。
## CSV に出す数値の文字列化は、すべてこの関数を通す。
## NaN・無限大は出力に入れない（T2-1。自動実行が先に Error で止める）。渡されたときは空文字を返す。
## 出力の表記は Godot の版で決まる。同じ版なら同じ文字列になる。
static func format_float(value: float) -> String:
	if is_nan(value) or is_inf(value):
		return ""
	return var_to_str(value)


## 名前を CSV の1つの欄にする。次の順に処理する。
## 1. T2-1 の対象の文字（ModelCheck.ESCAPE_RANGES）を \u{XXXX} にし、バックスラッシュを二重にする。MAX_FIELD_LENGTH 文字までで省く。
## 2. 先頭（U+0020 を除く）が = + - @ のとき、先頭に「'」を足す（表計算ソフトの式として扱われないようにする）。
## 3. カンマ・引用符・CR・LF を含むときは、RFC 4180 に従い、引用符で囲み、中の引用符を二重にする。
static func escape_field(text: String) -> String:
	var field: String = ModelCheck.escape_excerpt(text, MAX_FIELD_LENGTH)
	var first: String = field.strip_edges(true, false).left(1)
	if not first.is_empty() and FORMULA_PREFIXES.contains(first):
		field = "'" + field
	if field.contains(",") or field.contains("\"") or field.contains("\r") or field.contains("\n"):
		field = "\"" + field.replace("\"", "\"\"") + "\""
	return field


## 見出し行（ターン番号の列と、ストックの名前）を返す。行の終わりを含む。
static func format_header(stock_names: Array[String]) -> String:
	var fields := PackedStringArray([TURN_HEADER])
	for stock_name in stock_names:
		fields.append(escape_field(stock_name))
	return ",".join(fields) + LINE_END


## データ行を返す。values はストックの値で、名前の順に並ぶ。行の終わりを含む。
static func format_row(turn: int, values: PackedFloat64Array) -> String:
	var fields := PackedStringArray([str(turn)])
	for value in values:
		fields.append(format_float(value))
	return ",".join(fields) + LINE_END


## 表全体を CSV の文字列にする。rows[i] は、ターン i の値である。
static func format_table(stock_names: Array[String], rows: Array[PackedFloat64Array]) -> String:
	var lines := PackedStringArray([format_header(stock_names)])
	for turn in rows.size():
		lines.append(format_row(turn, rows[turn]))
	return "".join(lines)
