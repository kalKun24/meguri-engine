## SimModel の受け入れ基準を確かめるテスト。シーンを使わない。
class_name SimModelTest
extends GdUnitTestSuite

var _turns: Array[int] = []
var _stock_at_signal: float = 0.0


func _chain(reverse: bool) -> SimModel:
	var model := SimModel.new()
	model.add_stock("A", 10.0)
	model.add_stock("B", 0.0)
	model.add_stock("C", 0.0)
	if reverse:
		model.add_flow("b_to_c", "B", "C", 2.0)
		model.add_flow("a_to_b", "A", "B", 3.0)
	else:
		model.add_flow("a_to_b", "A", "B", 3.0)
		model.add_flow("b_to_c", "B", "C", 2.0)
	return model


func _on_turn_finished(turn: int, model: SimModel) -> void:
	_turns.append(turn)
	_stock_at_signal = model.get_stock("A").value


## ストック・フロー・定数を定義でき、初期値を取得できる。
func test_define_stock_flow_constant() -> void:
	var model := SimModel.new()
	assert_int(model.add_stock("A", 5.0)).is_equal(OK)
	assert_int(model.add_stock("B", 1.0)).is_equal(OK)
	assert_int(model.add_flow("f", "A", "B", 1.5)).is_equal(OK)
	assert_int(model.add_constant("k", 0.25)).is_equal(OK)
	assert_float(model.get_stock("A").value).is_equal(5.0)
	assert_float(model.get_constant("k").value).is_equal(0.25)


## 流出元だけ、流入先だけのフローを定義できる。
func test_flow_with_one_side_only() -> void:
	var model := SimModel.new()
	model.add_stock("A", 10.0)
	assert_int(model.add_flow("out", "A", "", 4.0)).is_equal(OK)
	assert_int(model.add_flow("in", "", "A", 1.0)).is_equal(OK)
	model.step()
	assert_float(model.get_stock("A").value).is_equal(7.0)


## 存在しないストックを指すフローはエラーになる。
func test_flow_to_missing_stock_is_error() -> void:
	var model := SimModel.new()
	model.add_stock("A", 1.0)
	assert_int(model.add_flow("f", "A", "X", 1.0)).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.add_flow("g", "X", "A", 1.0)).is_equal(ERR_INVALID_PARAMETER)
	assert_str(model.last_error).contains("X")


## 同名の定義はエラーになる。種類をまたいでも同じである。
func test_duplicate_name_is_error() -> void:
	var model := SimModel.new()
	model.add_stock("A", 1.0)
	assert_int(model.add_stock("A", 2.0)).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_constant("A", 2.0)).is_equal(ERR_ALREADY_EXISTS)
	model.add_flow("f", "A", "", 1.0)
	assert_int(model.add_flow("f", "A", "", 1.0)).is_equal(ERR_ALREADY_EXISTS)
	assert_float(model.get_stock("A").value).is_equal(1.0)


## 流出元と流入先の両方が無いフローはエラーになる。
func test_flow_without_both_ends_is_error() -> void:
	var model := SimModel.new()
	assert_int(model.add_flow("f", "", "", 1.0)).is_equal(ERR_INVALID_PARAMETER)


## 未定義の名前を get_stock() / get_constant() に渡すと、NAN ではなくエラーを返す。
func test_get_unknown_is_error_not_nan() -> void:
	var model := SimModel.new()
	var stock := model.get_stock("none")
	assert_int(stock.error).is_equal(ERR_DOES_NOT_EXIST)
	assert_bool(stock.is_ok()).is_false()
	assert_bool(is_nan(stock.value)).is_false()
	assert_str(model.last_error).contains("none")
	var constant := model.get_constant("none")
	assert_int(constant.error).is_equal(ERR_DOES_NOT_EXIST)
	assert_bool(is_nan(constant.value)).is_false()
	assert_int(model.get_stock("").error).is_equal(ERR_INVALID_PARAMETER)


## 取得に成功すると error が OK で、last_error が空に戻る。
func test_get_success_clears_last_error() -> void:
	var model := SimModel.new()
	model.add_stock("A", 2.0)
	model.get_stock("none")
	assert_str(model.last_error).is_not_empty()
	var result := model.get_stock("A")
	assert_int(result.error).is_equal(OK)
	assert_float(result.value).is_equal(2.0)
	assert_str(model.last_error).is_empty()


## NaN・無限大の値は ERR_INVALID_PARAMETER で拒否され、モデルは変わらない。
func test_non_finite_values_are_rejected() -> void:
	var model := SimModel.new()
	model.add_stock("A", 1.0)
	for bad in [NAN, INF, -INF]:
		assert_int(model.add_stock("S", bad)).is_equal(ERR_INVALID_PARAMETER)
		assert_int(model.add_constant("K", bad)).is_equal(ERR_INVALID_PARAMETER)
		assert_int(model.add_flow("F", "A", "", bad)).is_equal(ERR_INVALID_PARAMETER)
	assert_str(model.last_error).contains("無限大")
	assert_bool(model.has_stock("S")).is_false()
	assert_int(model.get_constant("K").error).is_equal(ERR_DOES_NOT_EXIST)
	# 拒否した名前は使われていないので、正しい値で定義できる。
	assert_int(model.add_flow("F", "A", "", 1.0)).is_equal(OK)


## 空の名前は、すべての add_* で ERR_INVALID_PARAMETER になる。
func test_empty_name_is_rejected() -> void:
	var model := SimModel.new()
	model.add_stock("A", 1.0)
	assert_int(model.add_stock("", 1.0)).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.add_constant("", 1.0)).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.add_flow("", "A", "", 1.0)).is_equal(ERR_INVALID_PARAMETER)
	assert_str(model.last_error).contains("空")


## 名前の長さの上限。上限ちょうどは通り、超えると拒否される。
func test_name_length_limit() -> void:
	var model := SimModel.new()
	var ok_name := "a".repeat(ModelCheck.MAX_NAME_LENGTH)
	var long_name := "a".repeat(ModelCheck.MAX_NAME_LENGTH + 1)
	assert_int(model.add_stock(ok_name, 1.0)).is_equal(OK)
	assert_int(model.add_stock(long_name, 1.0)).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.add_constant(long_name, 1.0)).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.add_flow(long_name, ok_name, "", 1.0)).is_equal(ERR_INVALID_PARAMETER)
	# エラー文は長い名前をそのまま出さない。
	assert_int(model.last_error.length()).is_less(ModelCheck.MAX_NAME_LENGTH + 80)


## 定義の個数の上限。超えるとエラーになる。
func test_definition_count_limit() -> void:
	var model := SimModel.new()
	for i in ModelCheck.MAX_DEFINITIONS:
		assert_int(model.add_constant("c%d" % i, 1.0)).is_equal(OK)
	assert_int(model.add_constant("over", 1.0)).is_equal(ERR_OUT_OF_MEMORY)
	assert_int(model.add_stock("over", 1.0)).is_equal(ERR_OUT_OF_MEMORY)
	assert_int(model.add_flow("over", "", "x", 1.0)).is_equal(ERR_OUT_OF_MEMORY)
	assert_int(model.get_constant("over").error).is_equal(ERR_DOES_NOT_EXIST)


## 成功した add_* は last_error を空にする。
func test_success_clears_last_error() -> void:
	var model := SimModel.new()
	model.add_stock("", 1.0)
	assert_str(model.last_error).is_not_empty()
	assert_int(model.add_stock("A", 1.0)).is_equal(OK)
	assert_str(model.last_error).is_empty()
	model.add_constant("", 1.0)
	assert_int(model.add_constant("k", 1.0)).is_equal(OK)
	assert_str(model.last_error).is_empty()
	model.add_flow("f", "A", "", NAN)
	assert_int(model.add_flow("f", "A", "", 1.0)).is_equal(OK)
	assert_str(model.last_error).is_empty()


## エラー文に出す利用者の名前は、制御文字がエスケープされる。
func test_error_message_escapes_control_characters() -> void:
	var model := SimModel.new()
	var evil := "x" + char(0x0A) + char(0x09) + char(0x202E) + char(0x200B) + char(0x1B) + "y"
	model.get_stock(evil)
	_assert_clean(model.last_error)
	assert_str(model.last_error).contains("\\u{000A}")
	assert_str(model.last_error).contains("\\u{202E}")
	assert_str(model.last_error).contains("\\u{200B}")
	model.add_stock(evil, 1.0)
	model.add_stock(evil, 1.0)
	_assert_clean(model.last_error)
	model.add_flow("f", evil + "z", "", 1.0)
	_assert_clean(model.last_error)
	model.add_flow("f" + evil, "", "", 1.0)
	_assert_clean(model.last_error)
	model.add_stock(evil + "a".repeat(100), NAN)
	_assert_clean(model.last_error)
	model.add_stock("ok", NAN)
	_assert_clean(model.last_error)


func _assert_clean(message: String) -> void:
	assert_str(message).is_not_empty()
	for i in message.length():
		var code := message.unicode_at(i)
		assert_bool(code > 0x1F and not (code >= 0x7F and code <= 0x9F) and not (code >= 0x200B and code <= 0x202E)).is_true()


## step() は、すべてのフローを更新前の値から計算して一斉に反映する。
func test_step_updates_simultaneously() -> void:
	var model := _chain(false)
	model.step()
	assert_float(model.get_stock("A").value).is_equal(7.0)
	assert_float(model.get_stock("B").value).is_equal(1.0)
	assert_float(model.get_stock("C").value).is_equal(2.0)
	model.step()
	assert_float(model.get_stock("A").value).is_equal(4.0)
	assert_float(model.get_stock("B").value).is_equal(2.0)
	assert_float(model.get_stock("C").value).is_equal(4.0)


## フローの定義順を入れ替えても、結果は同じである。
func test_definition_order_does_not_matter() -> void:
	var forward := _chain(false)
	var reversed := _chain(true)
	for i in 3:
		forward.step()
		reversed.step()
		for stock_name in ["A", "B", "C"]:
			assert_float(reversed.get_stock(stock_name).value).is_equal(forward.get_stock(stock_name).value)


## ターン番号は 0 から始まり、step() で 1 増える。
func test_turn_counter() -> void:
	var model := _chain(false)
	assert_int(model.get_turn()).is_equal(0)
	model.step()
	model.step()
	assert_int(model.get_turn()).is_equal(2)


## turn_finished は、反映が終わった後に、増えた後のターン番号で発火する。
func test_turn_finished_signal() -> void:
	var model := _chain(false)
	_turns.clear()
	model.turn_finished.connect(_on_turn_finished.bind(model))
	model.step()
	model.step()
	assert_array(_turns).is_equal([1, 2])
	assert_float(_stock_at_signal).is_equal(4.0)
