## CsvFormat のテスト。浮動小数点の文字列化、RFC 4180 のクォート、式として扱われる文字、T2-1 の4のエスケープを確かめる。
## シーンを使わない。不可視文字は char() で作る。
class_name CsvFormatTest
extends GdUnitTestSuite

## escape_field の出力の最大長。MAX_FIELD_LENGTH 文字の引用符がすべて二重になり、前後に引用符が付く場合である。
const MAX_OUTPUT_LENGTH: int = CsvFormat.MAX_FIELD_LENGTH * 2 + 2


## 列1〜2：往復できる精度。丸めた表記（%.1f など）にならない。
func test_format_float_round_trips() -> void:
	var values: Array[float] = [0.1, 0.1 + 0.2, 1.0 / 3.0, 123456.789, -2.5, 1e-7, 1e22, 100.0, 0.0, -0.0, 1e300, 1.7976931348623157e308]
	for value in values:
		var text := CsvFormat.format_float(value)
		assert_bool(text.to_float() == value).override_failure_message("往復できない：%s" % text).is_true()
	assert_str(CsvFormat.format_float(0.1 + 0.2)).is_equal("0.30000000000000004")
	assert_str(CsvFormat.format_float(100.0)).is_equal("100.0")


## 列1：NaN・無限大は出力に入れない。共有一覧の float と、足すと溢れる組を流す。
func test_format_float_never_outputs_non_finite() -> void:
	for label: String in HostileValues.floats():
		assert_str(CsvFormat.format_float(HostileValues.floats()[label])).override_failure_message(label).is_empty()
	for pair: Array in HostileValues.overflow_pairs():
		var sum: float = pair[0] + pair[1]
		assert_str(CsvFormat.format_float(sum)).is_empty()


## RFC 4180：カンマ・引用符を含む名前は引用符で囲み、中の引用符を二重にする。
func test_escape_field_quotes_per_rfc4180() -> void:
	assert_str(CsvFormat.escape_field("plain")).is_equal("plain")
	assert_str(CsvFormat.escape_field("a,b")).is_equal("\"a,b\"")
	assert_str(CsvFormat.escape_field("a\"b")).is_equal("\"a\"\"b\"")
	assert_str(CsvFormat.escape_field("\"")).is_equal("\"\"\"\"")
	assert_str(CsvFormat.escape_field("a b")).is_equal("a b")


## RFC 4180：改行を含む名前は、改行が \u{XXXX} にエスケープされるので、CSV の行を割らない。
func test_escape_field_does_not_split_lines() -> void:
	for newline in ["\n", "\r", "\r\n", char(0x2028), char(0x85)]:
		var field := CsvFormat.escape_field("a" + newline + "b")
		assert_bool(field.contains("\n") or field.contains("\r")).is_false()
	assert_str(CsvFormat.escape_field("a\nb")).is_equal("a\\u{000A}b")


## 先頭の = + - @ は、先頭に「'」を足して、式として扱われないようにする。
func test_escape_field_neutralizes_formula_prefixes() -> void:
	for text in ["=1+1", "+1", "-1", "@SUM(A1)", "  =1", "=cmd|' /C calc'!A0"]:
		var field := CsvFormat.escape_field(text)
		assert_bool(field.begins_with("'") or field.begins_with("\"'")).override_failure_message(field).is_true()
	assert_str(CsvFormat.escape_field("=1+1")).is_equal("'=1+1")
	# 先頭でなければ変えない。
	assert_str(CsvFormat.escape_field("a=1")).is_equal("a=1")
	assert_str(CsvFormat.escape_field("a-b")).is_equal("a-b")
	# 式の文字とカンマが両方あるときは、「'」を足してから囲む。
	assert_str(CsvFormat.escape_field("=1,2")).is_equal("\"'=1,2\"")


## T2-1 の4：エスケープ対象の文字は、そのまま出ない。範囲表のすべての範囲について、両端と中央を確かめる。
func test_escape_field_escapes_every_range() -> void:
	var ranges: PackedInt32Array = ModelCheck.ESCAPE_RANGES
	for i in ranges.size() / 2:
		var first: int = ranges[i * 2]
		var last: int = ranges[i * 2 + 1]
		for code: int in [first, last, (first + last) / 2]:
			# GDScript の char(0) は NUL にならない（文字列に NUL は入らない）ので除く。NUL は引数の検査のテストで扱う。
			if code == 0:
				continue
			var field := CsvFormat.escape_field("a" + char(code) + "b")
			var raw := HostileValues.find_raw_invisible(field)
			assert_str(raw).override_failure_message("U+%04X：%s" % [code, raw]).is_empty()
			assert_str(field).contains("\\u{%04X}" % code)


## 列3〜6：共有一覧の文字列を全件流す。生の不可視文字が残らず、長さの上限を守り、引用符で囲むか、区切りを含まないかのどちらかである。
func test_escape_field_with_hostile_strings() -> void:
	var all := HostileValues.strings()
	for label: String in all:
		var field := CsvFormat.escape_field(all[label])
		assert_str(HostileValues.find_raw_invisible(field)).override_failure_message(label).is_empty()
		assert_int(field.length()).override_failure_message(label).is_less_equal(MAX_OUTPUT_LENGTH)
		assert_bool(_is_single_field(field)).override_failure_message("1つの欄でない：" + label).is_true()
		var first := field.strip_edges(true, false).left(1)
		assert_bool(["=", "+", "-", "@"].has(first)).override_failure_message("式の文字で始まる：" + label).is_false()


## 長い入力は、MAX_FIELD_LENGTH 文字までで省く。
func test_escape_field_limits_length() -> void:
	var field := CsvFormat.escape_field(char(0xE0041).repeat(100000))
	assert_int(field.length()).is_less_equal(CsvFormat.MAX_FIELD_LENGTH)
	assert_str(field).ends_with("...")


## 名前の上限（64 文字）の不可視文字は、省かれずに出る（1 文字が最大 10 文字にエスケープされても収まる）。
func test_escape_field_keeps_max_length_name() -> void:
	var name_value := char(0x10FFFD).repeat(ModelCheck.MAX_NAME_LENGTH)
	var field := CsvFormat.escape_field(name_value)
	assert_bool(field.contains("...")).is_false()


## 見出しは turn と各ストックの名前、行はターン番号と値。行の終わりは CRLF である。
func test_format_table() -> void:
	var names: Array[String] = ["a", "b,c"]
	var rows: Array[PackedFloat64Array] = [PackedFloat64Array([1.0, 2.5]), PackedFloat64Array([0.5, -1.0])]
	assert_str(CsvFormat.format_table(names, rows)).is_equal("turn,a,\"b,c\"\r\n0,1.0,2.5\r\n1,0.5,-1.0\r\n")


## 値の負の数は、名前と違い「'」を足さない（数値は escape_field を通らない）。
func test_negative_numbers_are_not_prefixed() -> void:
	assert_str(CsvFormat.format_row(3, PackedFloat64Array([-1.5]))).is_equal("3,-1.5\r\n")


# field が CSV の1つの欄かを返す。引用符で囲まれて中の引用符が二重か、区切り文字を含まないかのどちらかである。
func _is_single_field(field: String) -> bool:
	if field.begins_with("\"") and field.ends_with("\"") and field.length() >= 2:
		var inner := field.substr(1, field.length() - 2)
		return inner.replace("\"\"", "").find("\"") < 0 and not inner.contains("\r") and not inner.contains("\n")
	return not (field.contains(",") or field.contains("\"") or field.contains("\r") or field.contains("\n"))
