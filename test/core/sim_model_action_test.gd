## SimModel のアクション（add_action・apply_action）のテスト。受け入れ基準ごとに置く。
class_name SimModelActionTest
extends GdUnitTestSuite

var _applied: Array[String] = []


func _on_action_applied(action_name: String) -> void:
	_applied.append(action_name)


# money 100、farmland 1、1 ターンに farmland * 10 のお金が入る。
func _new_model() -> SimModel:
	var model := SimModel.new()
	model.add_stock("money", 100.0)
	model.add_stock("farmland", 1.0)
	model.add_constant("price", 50.0)
	model.add_flow_expr("harvest", "", "money", "farmland * 10")
	return model


func _add_buy(model: SimModel) -> Error:
	return model.add_action("buy_farmland", "money >= price", ["money = money - price", "farmland = farmland + 1"])


func _state(model: SimModel) -> String:
	return "%s|%s|%s|%d" % [model.get_stock("money").value, model.get_stock("farmland").value, model.get_constant("price").value, model.get_turn()]


# 効果が全体で成功する。
func test_apply_action_applies_all_effects() -> void:
	var model := _new_model()
	assert_int(_add_buy(model)).is_equal(OK)
	assert_int(model.apply_action("buy_farmland")).is_equal(OK)
	assert_float(model.get_stock("money").value).is_equal(50.0)
	assert_float(model.get_stock("farmland").value).is_equal(2.0)
	assert_str(model.last_error).is_empty()
	assert_int(model.get_turn()).is_equal(0)


# 効果の式は、実行前の値で評価する（順序に依らない）。
func test_effects_use_values_before_the_action() -> void:
	var model := SimModel.new()
	model.add_stock("a", 1.0)
	model.add_stock("b", 2.0)
	assert_int(model.add_action("swap", "1", ["a = b", "b = a"])).is_equal(OK)
	assert_int(model.apply_action("swap")).is_equal(OK)
	assert_float(model.get_stock("a").value).is_equal(2.0)
	assert_float(model.get_stock("b").value).is_equal(1.0)


# 条件を満たさないとき、状態が変わらない。
func test_unmet_condition_changes_nothing() -> void:
	var model := _new_model()
	_add_buy(model)
	model.apply_action("buy_farmland")
	model.apply_action("buy_farmland")
	var before := _state(model)
	assert_int(model.apply_action("buy_farmland")).is_equal(ERR_UNAVAILABLE)
	assert_str(model.last_error).contains("money >= price")
	assert_str(_state(model)).is_equal(before)


# 非有限の効果は FAILED になり、状態が変わらない（先の効果も取り消される）。
func test_non_finite_effect_fails_and_rolls_back() -> void:
	var model := _new_model()
	model.add_stock("zero", 0.0)
	assert_int(model.add_action("bad", "1", ["money = 5", "farmland = 1 / zero"])).is_equal(OK)
	var before := _state(model)
	assert_int(model.apply_action("bad")).is_equal(FAILED)
	assert_str(model.last_error).is_not_empty()
	assert_str(_state(model)).is_equal(before)


func test_overflow_effect_fails_and_rolls_back() -> void:
	var model := SimModel.new()
	model.add_stock("a", 1.0)
	model.add_stock("big", 1.7e308)
	model.add_constant("k", 1.7e308)
	model.add_action("grow", "1", ["a = 7", "big = big + k"])
	assert_int(model.apply_action("grow")).is_equal(FAILED)
	assert_float(model.get_stock("a").value).is_equal(1.0)
	assert_float(model.get_stock("big").value).is_equal(1.7e308)


# 条件の評価で 0 除算が起きても FAILED で、状態は変わらない。
func test_condition_runtime_error_fails() -> void:
	var model := SimModel.new()
	model.add_stock("a", 1.0)
	model.add_stock("zero", 0.0)
	model.add_action("x", "1 / zero", ["a = 2"])
	assert_int(model.apply_action("x")).is_equal(FAILED)
	assert_float(model.get_stock("a").value).is_equal(1.0)


# 定義時の検査。
func test_add_action_validation() -> void:
	var model := _new_model()
	assert_int(model.add_action("", "1", ["money = 1"])).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.add_action("a", "1", [])).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.add_action("a", "1", ["money"])).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.add_action("a", "1", [5])).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.add_action("a", "1", ["nothing = 1"])).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.add_action("a", "1", ["money = 1", "money = 2"])).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.add_action("a", "1 +", ["money = 1"])).is_equal(ERR_PARSE_ERROR)
	assert_int(model.add_action("a", "1", ["money = 1 +"])).is_equal(ERR_PARSE_ERROR)
	assert_int(model.add_action("a", "lost", ["money = 1"])).is_equal(ERR_INVALID_DATA)
	assert_int(model.add_action("a", "1", ["money = system(1)"])).is_equal(ERR_INVALID_DATA)
	assert_int(model.add_action("a", "1", ["money = lost"])).is_equal(ERR_INVALID_DATA)
	var many: Array = []
	for i in ModelCheck.MAX_ACTION_EFFECTS + 1:
		many.append("money = 1")
	assert_int(model.add_action("a", "1", many)).is_equal(ERR_INVALID_PARAMETER)
	assert_str(model.last_error).is_not_empty()
	assert_bool(model.has_action("a")).is_false()
	assert_int(model.get_action_names().size()).is_equal(0)


func test_error_messages_carry_expression_and_position() -> void:
	var model := _new_model()
	model.add_action("a", "1", ["money = 1 +"])
	assert_str(model.last_error).contains("money = 1 +".substr(7))
	assert_str(model.last_error).contains("位置")


func test_effect_can_target_a_constant() -> void:
	var model := _new_model()
	assert_int(model.add_action("raise", "1", ["price = price + 10"])).is_equal(OK)
	assert_int(model.apply_action("raise")).is_equal(OK)
	assert_float(model.get_constant("price").value).is_equal(60.0)


# アクション名は、ストック・定数・フロー・許可関数と同じ名前空間にある。
func test_action_names_share_the_namespace() -> void:
	var model := _new_model()
	for taken: String in ["money", "price", "harvest", "min"]:
		assert_int(model.add_action(taken, "1", ["money = 1"])).is_equal(ERR_ALREADY_EXISTS)
		assert_bool(model.has_action(taken)).is_false()
	assert_int(model.add_action("go", "1", ["money = 1"])).is_equal(OK)
	assert_int(model.add_action("go", "1", ["money = 1"])).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_stock("go", 1.0)).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_constant("go", 1.0)).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_flow("go", "", "money", 1.0)).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_flow_expr("go", "", "money", "1")).is_equal(ERR_ALREADY_EXISTS)
	assert_array(model.get_action_names()).is_equal(["go"])


func test_definition_limit_includes_actions() -> void:
	var model := SimModel.new()
	model.add_stock("s", 1.0)
	for i in ModelCheck.MAX_DEFINITIONS - 1:
		assert_int(model.add_action("a%d" % i, "1", ["s = 1"])).is_equal(OK)
	assert_int(model.add_action("over", "1", ["s = 1"])).is_equal(ERR_OUT_OF_MEMORY)
	assert_int(model.add_stock("over", 1.0)).is_equal(ERR_OUT_OF_MEMORY)


func test_apply_unknown_or_empty_action() -> void:
	var model := _new_model()
	var before := _state(model)
	assert_int(model.apply_action("nothing")).is_equal(ERR_DOES_NOT_EXIST)
	assert_str(model.last_error).is_not_empty()
	assert_int(model.apply_action("")).is_equal(ERR_INVALID_PARAMETER)
	assert_str(_state(model)).is_equal(before)


# シグナル：成功のときだけ、効果の反映後に 1 回発火する。
func test_action_applied_signal() -> void:
	var model := _new_model()
	_add_buy(model)
	_applied.clear()
	model.action_applied.connect(_on_action_applied)
	model.apply_action("buy_farmland")
	assert_array(_applied).is_equal(["buy_farmland"])
	model.apply_action("buy_farmland")
	model.apply_action("buy_farmland")
	assert_array(_applied).is_equal(["buy_farmland", "buy_farmland"])
	model.apply_action("nothing")
	assert_int(_applied.size()).is_equal(2)


func test_signal_sees_the_applied_state() -> void:
	var model := _new_model()
	_add_buy(model)
	var seen: Array[float] = []
	model.action_applied.connect(func(_n: String) -> void: seen.append(model.get_stock("farmland").value))
	model.apply_action("buy_farmland")
	assert_array(seen).is_equal([2.0])


# 1 ターンに何回でも実行でき、費用は毎回かかる。
func test_apply_many_times_in_one_turn() -> void:
	var model := _new_model()
	model.add_action("cheap", "money >= 10", ["money = money - 10", "farmland = farmland + 1"])
	for i in 5:
		assert_int(model.apply_action("cheap")).is_equal(OK)
	assert_float(model.get_stock("money").value).is_equal(50.0)
	assert_float(model.get_stock("farmland").value).is_equal(6.0)
	assert_int(model.get_turn()).is_equal(0)


# 次のターンに反映される。
func test_effects_show_in_the_next_turn() -> void:
	var model := _new_model()
	_add_buy(model)
	model.apply_action("buy_farmland")
	assert_int(model.step()).is_equal(OK)
	# money 50 + farmland 2 * 10
	assert_float(model.get_stock("money").value).is_equal(70.0)
	assert_float(model.get_stock("farmland").value).is_equal(2.0)


func test_constant_effect_shows_in_the_next_turn() -> void:
	var model := SimModel.new()
	model.add_stock("out", 0.0)
	model.add_constant("rate", 1.0)
	model.add_flow_expr("f", "", "out", "rate")
	model.add_action("boost", "1", ["rate = rate + 4"])
	model.step()
	model.apply_action("boost")
	model.step()
	assert_float(model.get_stock("out").value).is_equal(6.0)


# 定義後に足したストックも、後のアクションが使える。ターンの途中の実行でも式は現在値で評価される。
func test_condition_uses_current_values() -> void:
	var model := _new_model()
	_add_buy(model)
	for i in 3:
		model.step()
	assert_int(model.apply_action("buy_farmland")).is_equal(OK)
	assert_float(model.get_stock("money").value).is_equal(130.0 - 50.0)
