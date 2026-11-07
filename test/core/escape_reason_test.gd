## ModelCheck.escape_reason（escape_backslash=false）の切り方（#22、#29 の security の should）のテスト。
## 「\\」と「\u{XXXX}」を1単位として扱い、表記の途中で切らない。エスケープと長さの上限の組み合わせを確かめる（T4-2 の列6）。
class_name EscapeReasonTest
extends GdUnitTestSuite

## 切った結果の本文（末尾の「...」を除く）として許される形。「\\」・「\u{XXXX}」・それ以外の1文字の並びである。
const UNITS_PATTERN: String = "^(?:[^\\\\]|\\\\\\\\|\\\\u\\{[0-9A-F]{4,6}\\})*$"

var _units: RegEx = null


func before_test() -> void:
	_units = RegEx.new()
	_units.compile(UNITS_PATTERN)


func _body(result: String) -> String:
	assert_str(result).ends_with("...")
	return result.substr(0, result.length() - 3)


func _assert_cut_cleanly(result: String, limit: int) -> void:
	assert_int(result.length()).is_less_equal(limit)
	assert_str(result).ends_with("...")
	assert_object(_units.search(_body(result))).is_not_null()


## 先頭に x を n 個置いて、切れ目の位置を1文字ずつずらす。どの位置でも、表記の途中で切れない。
func test_cut_position_sweep_never_splits_a_notation() -> void:
	var tails: Dictionary = {
		"二重バックスラッシュ": "\\\\".repeat(300),
		"不可視文字の表記": "\\u{202E}".repeat(60),
		"長い表記": "\\u{E0041}".repeat(60),
		"両方の交互": "\\\\\\u{200B}".repeat(60),
	}
	var limit: int = ModelCheck.MAX_MESSAGE_REASON_LENGTH
	for label: String in tails:
		for pad in range(0, 14):
			var text: String = "x".repeat(pad) + tails[label]
			var result: String = ModelCheck.escape_reason(text)
			_assert_cut_cleanly(result, limit)


func test_does_not_end_with_an_odd_number_of_backslashes_before_the_ellipsis() -> void:
	for pad in range(0, 6):
		var result: String = ModelCheck.escape_reason("x".repeat(190 + pad) + "\\\\".repeat(20))
		var body: String = _body(result)
		var trailing: int = 0
		while trailing < body.length() and body[body.length() - 1 - trailing] == "\\":
			trailing += 1
		assert_int(trailing % 2).is_equal(0)


func test_does_not_end_inside_a_unicode_notation() -> void:
	for pad in range(190, 200):
		var result: String = ModelCheck.escape_reason("x".repeat(pad) + "\\u{E0041}".repeat(5))
		assert_str(_body(result)).not_contains("\\u{E004")
		assert_object(_units.search(_body(result))).is_not_null()


func test_a_notation_that_just_fits_is_kept_whole() -> void:
	# 本文 189 文字 + 表記 8 文字 + 「...」3 文字 = 200 文字。ちょうど収まる。
	var text: String = "x".repeat(189) + "\\u{202E}" + "y".repeat(50)
	var result: String = ModelCheck.escape_reason(text)
	assert_int(result.length()).is_equal(200)
	assert_str(result).contains("\\u{202E}")
	assert_str(result).ends_with("\\u{202E}...")


func test_short_text_is_returned_unchanged() -> void:
	assert_str(ModelCheck.escape_reason("a\\\\b\\u{202E}c")).is_equal("a\\\\b\\u{202E}c")
	assert_str(ModelCheck.escape_reason("")).is_equal("")
	assert_str(ModelCheck.escape_reason("x".repeat(200))).is_equal("x".repeat(200))


func test_raw_invisible_characters_are_still_escaped_and_cut_cleanly() -> void:
	var text: String = "x".repeat(150) + char(0x202E).repeat(40)
	var result: String = ModelCheck.escape_reason(text)
	_assert_cut_cleanly(result, ModelCheck.MAX_MESSAGE_REASON_LENGTH)
	assert_str(HostileValues.find_raw_invisible(result)).is_empty()


func test_lone_backslash_and_unclosed_notation_are_single_characters() -> void:
	assert_str(ModelCheck.escape_reason("a\\b")).is_equal("a\\b")
	assert_str(ModelCheck.escape_reason("a\\u{12")).is_equal("a\\u{12")
	assert_str(ModelCheck.escape_reason("a\\u{ZZ}")).is_equal("a\\u{ZZ}")


func test_every_hostile_string_through_escape_reason_stays_within_the_limit() -> void:
	var strings: Dictionary = HostileValues.strings()
	for label: String in strings:
		var result: String = ModelCheck.escape_reason(strings[label])
		assert_int(result.length()).is_less_equal(ModelCheck.MAX_MESSAGE_REASON_LENGTH)
		assert_str(HostileValues.find_raw_invisible(result)).is_empty()


func test_limit_escaped_and_escape_reason_cut_at_the_same_place() -> void:
	# 同じ規則で切るので、エスケープ済みの文なら、limit_escaped と escape_reason の結果が一致する。
	var limit: int = ModelCheck.MAX_MESSAGE_REASON_LENGTH
	for pad in range(0, 10):
		var text: String = "x".repeat(pad) + "\\u{202E}\\\\".repeat(80)
		assert_str(ModelCheck.escape_reason(text)).is_equal(ModelCheck.limit_escaped(text, limit))


func test_syntax_error_message_with_a_hostile_name_keeps_the_notation_whole() -> void:
	# 原因の文に名前（エスケープ済み）を入れても、表記が壊れない。
	var name_value: String = char(0x202E).repeat(100)
	var message: String = "名前 '%s' は使えない。" % ModelCheck.escape(name_value, 0) + "x".repeat(30)
	var result: String = ModelCheck.escape_reason(message)
	_assert_cut_cleanly(result, ModelCheck.MAX_MESSAGE_REASON_LENGTH)
