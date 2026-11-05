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
	_stock_at_signal = model.get_stock("A")


## ストック・フロー・定数を定義でき、初期値を取得できる。
func test_define_stock_flow_constant() -> void:
	var model := SimModel.new()
	assert_int(model.add_stock("A", 5.0)).is_equal(OK)
	assert_int(model.add_stock("B", 1.0)).is_equal(OK)
	assert_int(model.add_flow("f", "A", "B", 1.5)).is_equal(OK)
	assert_int(model.add_constant("k", 0.25)).is_equal(OK)
	assert_float(model.get_stock("A")).is_equal(5.0)
	assert_float(model.get_constant("k")).is_equal(0.25)


## 流出元だけ、流入先だけのフローを定義できる。
func test_flow_with_one_side_only() -> void:
	var model := SimModel.new()
	model.add_stock("A", 10.0)
	assert_int(model.add_flow("out", "A", "", 4.0)).is_equal(OK)
	assert_int(model.add_flow("in", "", "A", 1.0)).is_equal(OK)
	model.step()
	assert_float(model.get_stock("A")).is_equal(7.0)


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
	assert_float(model.get_stock("A")).is_equal(1.0)


## 流出元と流入先の両方が無いフローはエラーになる。
func test_flow_without_both_ends_is_error() -> void:
	var model := SimModel.new()
	assert_int(model.add_flow("f", "", "", 1.0)).is_equal(ERR_INVALID_PARAMETER)


## 未定義の名前を get_stock() に渡すとエラーになる。
func test_get_unknown_stock_is_error() -> void:
	var model := SimModel.new()
	assert_bool(is_nan(model.get_stock("none"))).is_true()
	assert_str(model.last_error).contains("none")


## step() は、すべてのフローを更新前の値から計算して一斉に反映する。
func test_step_updates_simultaneously() -> void:
	var model := _chain(false)
	model.step()
	assert_float(model.get_stock("A")).is_equal(7.0)
	assert_float(model.get_stock("B")).is_equal(1.0)
	assert_float(model.get_stock("C")).is_equal(2.0)
	model.step()
	assert_float(model.get_stock("A")).is_equal(4.0)
	assert_float(model.get_stock("B")).is_equal(2.0)
	assert_float(model.get_stock("C")).is_equal(4.0)


## フローの定義順を入れ替えても、結果は同じである。
func test_definition_order_does_not_matter() -> void:
	var forward := _chain(false)
	var reversed := _chain(true)
	for i in 3:
		forward.step()
		reversed.step()
		for stock_name in ["A", "B", "C"]:
			assert_float(reversed.get_stock(stock_name)).is_equal(forward.get_stock(stock_name))


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
