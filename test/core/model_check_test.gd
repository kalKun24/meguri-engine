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
