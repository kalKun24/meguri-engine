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


# --- #29：式の抜粋。長さは、エスケープした後で数える ---

func test_escape_expression_keeps_short_text_and_excerpts_long_text() -> void:
	var limit: int = ModelCheck.MAX_EXPRESSION_EXCERPT_LENGTH
	assert_str(ModelCheck.escape_expression("1 + 2")).is_equal("1 + 2")
	assert_str(ModelCheck.escape_expression("x".repeat(limit))).is_equal("x".repeat(limit))
	assert_str(ModelCheck.escape_expression("x".repeat(limit + 1))).is_equal("x".repeat(limit - 3) + "...")
	assert_str(ModelCheck.escape_expression("x".repeat(100000))).is_equal("x".repeat(limit - 3) + "...")


# エスケープで長さが数倍になる文字列でも、出力は上限以内で、エスケープの表記を途中で切らず、生の不可視文字が無い。
func test_escape_expression_counts_length_after_escaping() -> void:
	var limit: int = ModelCheck.MAX_EXPRESSION_EXCERPT_LENGTH
	for code in [0x01, 0x200B, 0xE0041, 0x10FFFD, 0x5C]:
		var escaped := ModelCheck.escape_expression(char(code).repeat(100000))
		assert_int(escaped.length()).override_failure_message("U+%04X：%d 文字" % [code, escaped.length()]).is_less_equal(limit)
		assert_str(escaped).ends_with("...")
		assert_str(HostileValues.find_raw_invisible(escaped)).is_empty()
		# 「...」を除いた部分は、完全な表記の繰り返しだけである。
		var body: String = escaped.substr(0, escaped.length() - 3)
		var unit: String = ModelCheck.escape(char(code), 0)
		assert_str(body).is_equal(unit.repeat(body.length() / unit.length()))
	for label: String in HostileValues.strings():
		var escaped := ModelCheck.escape_expression(HostileValues.strings()[label])
		assert_int(escaped.length()).override_failure_message(label).is_less_equal(limit)


func test_escape_excerpt_does_not_cut_a_notation_in_the_middle() -> void:
	# 1文字が "\u{200B}"（8文字）になる。上限 20 なら、「...」の3文字を除いた17文字に、完全な表記が2つ（16文字）入る。
	var text: String = char(0x200B).repeat(10)
	assert_str(ModelCheck.escape_excerpt(text, 20)).is_equal("\\u{200B}\\u{200B}...")
	assert_str(ModelCheck.escape_excerpt(char(0x200B).repeat(2), 16)).is_equal("\\u{200B}\\u{200B}")
	assert_str(ModelCheck.escape_excerpt(char(0x200B).repeat(3), 16)).is_equal("\\u{200B}...")


func test_escape_reason_limits_length_and_keeps_backslash() -> void:
	assert_str(ModelCheck.escape_reason("\\u{202E}" + char(0x202E))).is_equal("\\u{202E}\\u{202E}")
	assert_str(ModelCheck.escape_reason("x".repeat(100000))).is_equal("x".repeat(ModelCheck.MAX_MESSAGE_REASON_LENGTH - 3) + "...")


func test_expression_excerpt_reports_the_caret_offset() -> void:
	var short: Dictionary = ModelCheck.expression_excerpt("1 + $", 4)
	assert_str(short["text"]).is_equal("1 + $")
	assert_int(short["offset"]).is_equal(4)
	var at_end: Dictionary = ModelCheck.expression_excerpt("1 +", 3)
	assert_int(at_end["offset"]).is_equal(3)
	var escaped_before: Dictionary = ModelCheck.expression_excerpt(char(0x200B) + "$", 1)
	assert_int(escaped_before["offset"]).is_equal(8)
	var source: String = "a".repeat(1000)
	assert_int(ModelCheck.expression_excerpt(source, 10)["offset"]).is_equal(10)
	# 位置が抜粋の外にあるときは、-1 である（位置の数字だけが残る）。
	assert_int(ModelCheck.expression_excerpt(source, 500)["offset"]).is_equal(-1)
	assert_int(ModelCheck.expression_excerpt(source, 1000)["offset"]).is_equal(-1)
	assert_int(ModelCheck.expression_excerpt("abc", -5)["offset"]).is_equal(-1)


func test_limit_escaped_does_not_cut_a_notation_in_the_middle() -> void:
	assert_str(ModelCheck.limit_escaped("abc", 10)).is_equal("abc")
	assert_str(ModelCheck.limit_escaped("abcdefghij", 8)).is_equal("abcde...")
	# 切れ目が \u{200B} の途中に当たるときは、その表記の手前で切る。
	assert_str(ModelCheck.limit_escaped("ab\\u{200B}cd", 8)).is_equal("ab...")
	# 二重のバックスラッシュも、1組を残すか、1組を省く。
	assert_str(ModelCheck.limit_escaped("a\\\\\\\\b", 5)).is_equal("a...")
	assert_str(ModelCheck.limit_escaped("a\\\\\\\\\\\\b", 7)).is_equal("a\\\\...")

