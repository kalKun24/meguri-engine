## ModelCheck（名前と数値の検査、エスケープ）のテスト。#10 の式の評価からも使う関数である。
class_name ModelCheckTest
extends GdUnitTestSuite


func test_check_name() -> void:
	assert_str(ModelCheck.check_name("a")).is_empty()
	assert_str(ModelCheck.check_name("")).is_not_empty()
	assert_str(ModelCheck.check_name("a".repeat(ModelCheck.MAX_NAME_LENGTH + 1))).is_not_empty()


func test_check_finite() -> void:
	assert_str(ModelCheck.check_finite(1.5)).is_empty()
	assert_str(ModelCheck.check_finite(NAN)).contains("NaN")
	assert_str(ModelCheck.check_finite(INF, "量")).contains("量")
	assert_str(ModelCheck.check_finite(-INF)).contains("無限大")


func test_escape() -> void:
	assert_str(ModelCheck.escape("abc")).is_equal("abc")
	assert_str(ModelCheck.escape("a" + char(0x0A) + "b")).is_equal("a\\u{000A}b")
	assert_str(ModelCheck.escape(char(0x202E))).is_equal("\\u{202E}")
	assert_str(ModelCheck.escape("a\\b")).is_equal("a\\\\b")
	assert_str(ModelCheck.escape("x".repeat(100))).is_equal("x".repeat(ModelCheck.MAX_MESSAGE_NAME_LENGTH) + "...")


# 範囲表の全範囲を回し、そのまま出力された文字があれば失敗とする。巨大な範囲は代表点で調べる。
const _FULL_SCAN_LIMIT: int = 5000
const _SAMPLE_STRIDE: int = 997


func test_escape_covers_every_range() -> void:
	var table := ModelCheck.ESCAPE_RANGES
	assert_int(table.size() % 2).is_equal(0)
	assert_int(table.size()).is_greater(0)
	var checked := 0
	for r in table.size() / 2:
		var low: int = table[r * 2]
		var high: int = table[r * 2 + 1]
		assert_bool(low <= high).is_true()
		var points: Array[int] = []
		if high - low < _FULL_SCAN_LIMIT:
			for code in range(low, high + 1):
				points.append(code)
		else:
			for code in range(low, high + 1, _SAMPLE_STRIDE):
				points.append(code)
			points.append(high)
		for code in points:
			var escaped := ModelCheck.escape("a" + char(code) + "b", 0)
			if code == 0x00:
				continue  # Godot の String は NUL を持てない。needs_escape の判定だけを確かめる。
			if escaped != "a\\u{%04X}b" % code:
				fail("U+%04X がそのまま出力された、または形が違う：%s" % [code, escaped])
				return
			checked += 1
	assert_int(checked).is_greater(1000)


func test_escape_range_table_is_sorted_and_has_gaps() -> void:
	var table := ModelCheck.ESCAPE_RANGES
	for r in range(1, table.size() / 2):
		# 隣り合う範囲は、離れていて、小さい順である。
		assert_bool(table[r * 2] > table[r * 2 - 1] + 1).is_true()


func test_escape_range_boundaries_are_exact() -> void:
	var table := ModelCheck.ESCAPE_RANGES
	for r in table.size() / 2:
		var low: int = table[r * 2]
		var high: int = table[r * 2 + 1]
		if low > 0:
			assert_bool(ModelCheck.needs_escape(low - 1)).is_false()
		if high < 0x10FFFF:
			assert_bool(ModelCheck.needs_escape(high + 1)).is_false()


func test_escape_known_code_points() -> void:
	# 依頼の例と、各カテゴリの代表。Cc, Cf, Zl, Zp, Co, Zs, Default_Ignorable。
	var targets: Array[int] = [
		0x00, 0x1F, 0x7F, 0x9F, 0x00A0, 0x00AD, 0x034F, 0x061C, 0x115F, 0x180B, 0x200B, 0x200F, 0x2028, 0x2029,
		0x202E, 0x2060, 0x2066, 0x2069, 0x3000, 0x3164, 0xE000, 0xF8FF, 0xFE00, 0xFE0F, 0xFEFF, 0xFFA0,
		0x1D173, 0xE0001, 0xE0041, 0xE0100, 0xF0000, 0x10FFFD,
	]
	for code in targets:
		assert_bool(ModelCheck.needs_escape(code)).override_failure_message("U+%04X が対象でない" % code).is_true()


func test_escape_leaves_ordinary_characters() -> void:
	var others: Array[int] = [0x20, 0x21, 0x41, 0x7E, 0xA1, 0x3042, 0x4E2D, 0x1F600]
	for code in others:
		assert_bool(ModelCheck.needs_escape(code)).override_failure_message("U+%04X が対象になった" % code).is_false()
		assert_str(ModelCheck.escape(char(code), 0)).is_equal(char(code))


func test_escape_output_has_no_raw_invisible() -> void:
	for label: String in HostileValues.strings():
		var escaped := ModelCheck.escape(HostileValues.strings()[label], 0)
		assert_str(HostileValues.find_raw_invisible(escaped)).override_failure_message(label).is_empty()
		assert_str(HostileValues.find_raw_invisible(ModelCheck.escape(HostileValues.strings()[label]))).override_failure_message(label).is_empty()


func test_escape_without_backslash_doubling() -> void:
	assert_str(ModelCheck.escape("\\u{202E}" + char(0x202E), 0, false)).is_equal("\\u{202E}\\u{202E}")


func test_blank_names_are_empty() -> void:
	assert_bool(ModelCheck.is_blank("")).is_true()
	assert_bool(ModelCheck.is_blank(" ")).is_true()
	assert_bool(ModelCheck.is_blank(" " + char(0x200B) + char(0x3000))).is_true()
	assert_bool(ModelCheck.is_blank(char(0x202E))).is_true()
	assert_bool(ModelCheck.is_blank("a")).is_false()
	assert_bool(ModelCheck.is_blank(" a ")).is_false()
	assert_str(ModelCheck.check_name(" ")).is_not_empty()
	assert_str(ModelCheck.check_name(char(0x200B))).is_not_empty()
