## 式の名前の規則と、数字の直後の英字（#22）のテスト。受け入れ基準ごとに分けて書く。
class_name ExprNameRuleTest
extends GdUnitTestSuite


func _error(source: String) -> ExprSyntaxError:
	var result: ExprParseResult = ExprParser.new().parse(source)
	assert_bool(result.ok).is_false()
	return result.error


func test_non_ascii_name_is_rejected_at_that_character() -> void:
	var err: ExprSyntaxError = _error("人口 * 0.02")
	assert_int(err.position).is_equal(0)
	assert_str(err.message).contains("名前は半角英数字と _ だけで書く（先頭は数字にできない）")
	assert_int(_error("x + 人口").position).is_equal(4)
	assert_int(_error("pop人口").position).is_equal(3)


func test_fullwidth_latin_letters_and_digits_are_rejected() -> void:
	var fullwidth_a: String = char(0xFF21)
	var fullwidth_1: String = char(0xFF11)
	assert_int(_error("x + " + fullwidth_a).position).is_equal(4)
	assert_str(_error("x + " + fullwidth_a).message).contains("半角英数字")
	assert_int(_error("a" + fullwidth_1).position).is_equal(1)
	assert_int(_error("1 + " + fullwidth_1).position).is_equal(4)


func test_symbols_keep_the_unusable_character_error() -> void:
	for source in ["$x", "a @ b", "a # b"]:
		var err: ExprSyntaxError = _error(source)
		assert_str(err.message).contains("使えない文字")
		assert_str(err.message).not_contains("半角英数字")


func test_invisible_characters_in_a_name_are_escaped_in_the_message() -> void:
	var err: ExprSyntaxError = _error("a" + char(0x200B) + "b")
	assert_int(err.position).is_equal(1)
	assert_str(err.message).contains("\\u{200B}")
	assert_str(HostileValues.find_raw_invisible(err.message)).is_empty()


func test_letter_or_underscore_right_after_a_number_is_rejected_at_that_letter() -> void:
	var cases: Dictionary = {"1e3": 1, "2x": 1, "0x10": 1, "1_000": 1, "1.5e3": 3, "x + 12abc": 6}
	for source in cases:
		var err: ExprSyntaxError = _error(source)
		assert_int(err.position).is_equal(cases[source])
		assert_str(err.message).contains("指数表記")
		assert_str(err.message).contains("1000")
		assert_str(err.message).contains("2 * x")


func test_numbers_and_names_that_are_fine_still_parse() -> void:
	for source in ["1000", "2 * x", "1.5", "x1", "_a1", "a_1", "min(1, 2)", "1 + x"]:
		assert_bool(ExprParser.new().parse(source).ok).is_true()
