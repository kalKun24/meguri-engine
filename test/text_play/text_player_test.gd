## TextPlayer（テキスト版の入出力）と、仮モデル TownModel のテスト。シーンを使わない。
class_name TextPlayerTest
extends GdUnitTestSuite


func _play(inputs: Array[String], overrides: Dictionary = {}) -> BufferTextPlayIO:
	var builder := TownModel.new()
	var model := builder.build(overrides)
	assert_object(model).is_not_null()
	var io := BufferTextPlayIO.new(inputs)
	TextPlayer.new(model, io, TownModel.LABELS).run()
	return io


func _enters(count: int, last: String = "") -> Array[String]:
	var result: Array[String] = []
	for i in count:
		result.append("")
	if not last.is_empty():
		result.append(last)
	return result


# 数値は小数第1位まで。形は「ターン数: 人口=…, 食料=…, お金=…」。
func test_every_turn_prints_one_line_with_all_stocks_to_one_decimal() -> void:
	var io := _play(_enters(3, "q"))
	var lines := io.outputs.filter(func(l: String) -> bool: return l.contains("人口="))
	assert_int(lines.size()).is_equal(4)
	assert_str(lines[0]).is_equal("0: 人口=100.0, 食料=120.0, お金=100.0")
	var pattern := RegEx.create_from_string("^\\d+: 人口=-?\\d+\\.\\d, 食料=-?\\d+\\.\\d, お金=-?\\d+\\.\\d$")
	for line: String in lines:
		assert_object(pattern.search(line)).is_not_null()
	assert_str(lines[3]).starts_with("3: ")


func test_q_ends_without_advancing() -> void:
	var io := _play(["q", ""] as Array[String])
	assert_int(io.outputs.filter(func(l: String) -> bool: return l.contains("人口=")).size()).is_equal(1)


# Enter（空行・空白だけ）だけがターンを進める。分からない入力は、進めずに理由を表示する。
func test_only_blank_input_advances_and_unknown_input_does_not() -> void:
	var io := _play(["", "abc", "Q", " ", "quit", "q"] as Array[String])
	assert_int(io.outputs.filter(func(l: String) -> bool: return l.begins_with("1: ") or l.begins_with("2: ")).size()).is_equal(2)
	assert_int(io.outputs.filter(func(l: String) -> bool: return l.begins_with("分からない入力")).size()).is_equal(3)


func test_eof_ends() -> void:
	var io := _play(_enters(2))
	assert_int(io.outputs.filter(func(l: String) -> bool: return l.contains("人口=")).size()).is_equal(3)
	assert_bool(io.is_eof()).is_true()


func test_empty_input_ends_immediately() -> void:
	var io := _play([] as Array[String])
	assert_int(io.outputs.filter(func(l: String) -> bool: return l.contains("人口=")).size()).is_equal(1)


# 12ターン進めても、NaN・負にならず、人口が 0 にならない。
func test_town_stays_sane_for_12_turns() -> void:
	var model := TownModel.new().build()
	for turn in 12:
		assert_int(model.step()).is_equal(OK)
		for stock_name in model.get_stock_names():
			var value: float = model.get_stock(stock_name).value
			assert_bool(is_nan(value)).is_false()
			assert_bool(is_inf(value)).is_false()
			assert_float(value).is_greater_equal(0.0)
		assert_float(model.get_stock("population").value).is_greater(0.0)


# 食料が不足する設定では、死亡のフローが増える。
func test_deaths_grow_when_food_is_short() -> void:
	var plenty := TownModel.new().build({"food": 10000.0})
	var short := TownModel.new().build({"food": 10.0})
	plenty.step()
	short.step()
	var plenty_deaths: float = 100.0 - plenty.get_stock("population").value
	var short_deaths: float = 100.0 - short.get_stock("population").value
	# 人口の変化 = 出生 - 死亡。出生は同じなので、人口が少ないほうが死亡が多い。
	assert_float(short.get_stock("population").value).is_less(plenty.get_stock("population").value)
	assert_float(plenty_deaths).is_not_equal(short_deaths)


# 食料が足りないままでも、12ターン、負にならない。
func test_no_negative_stock_even_with_no_food() -> void:
	var model := TownModel.new().build({"food": 0.0, "money": 0.0})
	for turn in 12:
		assert_int(model.step()).is_equal(OK)
		for stock_name in model.get_stock_names():
			assert_float(model.get_stock(stock_name).value).is_greater_equal(0.0)


func test_unknown_override_fails() -> void:
	var builder := TownModel.new()
	assert_object(builder.build({"nope": 1.0})).is_null()
	assert_str(builder.last_error).contains("nope")


# step() の実行時エラーは、進めようとしたターン番号つきで表示し、ターンは進めずに終わる。
func test_runtime_error_is_shown_with_attempted_turn_and_play_ends() -> void:
	var model := SimModel.new()
	model.add_stock("stock", 10.0)
	model.add_stock("divisor", 1.0)
	model.add_flow_expr("shrink", "divisor", "", "1")
	model.add_flow_expr("share", "stock", "", "stock / divisor")
	var io := BufferTextPlayIO.new(_enters(5))
	var code := TextPlayer.new(model, io, {"stock": "在庫", "divisor": "割る数"}).run()
	assert_int(code).is_equal(FAILED)
	assert_int(model.get_turn()).is_equal(1)
	var text := "\n".join(io.outputs)
	assert_str(text).contains("ターン 2 に進めようとしてエラーになった")
	assert_str(text).contains("0 で割った")
	assert_str(text).contains("ターンは進んでいない")
	assert_str(text).contains("1: 在庫=")
