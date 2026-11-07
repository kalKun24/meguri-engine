## ストックの上限・下限（StockRange）のテスト（#7）。シーンを使わない。
class_name SimModelRangeTest
extends GdUnitTestSuite

const TOLERANCE: float = 1e-9


func _stock(model: SimModel, stock_name: String) -> float:
	return model.get_stock(stock_name).value


## 食料 food（範囲つき）に、消費 out と生産 in をつないだモデル。
func _food_model(initial: float, stock_range: StockRange, produce: float, consume: float) -> SimModel:
	var model := SimModel.new()
	assert_int(model.add_stock("food", initial, stock_range)).is_equal(OK)
	assert_int(model.add_flow("in", "", "food", produce)).is_equal(OK)
	assert_int(model.add_flow("out", "food", "", consume)).is_equal(OK)
	return model


# --- 基準1：設定でき、省略できる ---

func test_range_is_set_per_stock() -> void:
	var model := SimModel.new()
	model.add_stock("food", 50.0, StockRange.between(0.0, 100.0))
	model.add_stock("wood", 5.0, StockRange.at_least(1.0))
	model.add_stock("cap", 5.0, StockRange.at_most(9.0))
	model.add_stock("money", 5.0)
	var food := model.get_stock_range("food")
	assert_bool(food.has_lower()).is_true()
	assert_bool(food.has_upper()).is_true()
	assert_float(food.get_lower()).is_equal(0.0)
	assert_float(food.get_upper()).is_equal(100.0)
	assert_bool(model.get_stock_range("wood").has_upper()).is_false()
	assert_bool(model.get_stock_range("cap").has_lower()).is_false()
	assert_object(model.get_stock_range("money")).is_null()
	assert_object(model.get_stock_range("none")).is_null()


func test_omitted_range_is_expressed_without_infinity() -> void:
	var lower_only := StockRange.at_least(0.0)
	var upper_only := StockRange.at_most(10.0)
	assert_bool(lower_only.has_upper()).is_false()
	assert_bool(upper_only.has_lower()).is_false()
	assert_bool(is_inf(lower_only.get_upper())).is_false()
	assert_bool(is_inf(upper_only.get_lower())).is_false()


# --- 基準2：設定しない側は制限が無い ---

func test_stock_without_lower_goes_negative() -> void:
	var model := _food_model(5.0, StockRange.at_most(100.0), 0.0, 3.0)
	for i in 4:
		assert_int(model.advance_turn()).is_equal(OK)
	assert_float(_stock(model, "food")).is_equal(-7.0)


func test_stock_without_range_goes_negative_and_grows_freely() -> void:
	var model := SimModel.new()
	model.add_stock("money", 0.0)
	model.add_stock("gold", 0.0)
	model.add_flow("debt", "money", "", 1000.0)
	model.add_flow("mine", "", "gold", 1e12)
	for i in 5:
		model.advance_turn()
	assert_float(_stock(model, "money")).is_equal(-5000.0)
	assert_float(_stock(model, "gold")).is_equal(5e12)


func test_stock_without_upper_grows_without_limit() -> void:
	var model := _food_model(0.0, StockRange.at_least(0.0), 1e9, 0.0)
	for i in 5:
		model.advance_turn()
	assert_float(_stock(model, "food")).is_equal(5e9)


# --- 基準3：値を止める。合計した後に収め、削った量は消える ---

func test_stops_at_lower_when_consumption_is_high() -> void:
	var model := _food_model(10.0, StockRange.between(0.0, 100.0), 1.0, 8.0)
	model.advance_turn()
	assert_float(_stock(model, "food")).is_equal(3.0)
	model.advance_turn()
	assert_float(_stock(model, "food")).is_equal(0.0)
	model.advance_turn()
	assert_float(_stock(model, "food")).is_equal(0.0)


func test_stops_at_upper_when_production_is_high() -> void:
	var model := _food_model(90.0, StockRange.between(0.0, 100.0), 8.0, 1.0)
	for i in 3:
		model.advance_turn()
	assert_float(_stock(model, "food")).is_equal(100.0)


func test_clamps_the_sum_of_inflows_and_outflows_of_the_same_turn() -> void:
	# 流入 50・流出 30 の合計は +20。流入だけを先に足した途中の値（130）では止めない。
	var model := _food_model(80.0, StockRange.between(0.0, 100.0), 50.0, 30.0)
	model.advance_turn()
	assert_float(_stock(model, "food")).is_equal(100.0)
	# 流出 60・流入 50 の合計は -10 なので 0 に止まる。
	var model2 := _food_model(5.0, StockRange.between(0.0, 100.0), 50.0, 60.0)
	model2.advance_turn()
	assert_float(_stock(model2, "food")).is_equal(0.0)
	# 流入だけなら上限を超える途中の値（140）でも、合計（95）が範囲内ならそのまま。
	var model3 := _food_model(90.0, StockRange.between(0.0, 100.0), 50.0, 45.0)
	model3.advance_turn()
	assert_float(_stock(model3, "food")).is_equal(95.0)


func test_clipped_amount_vanishes_and_goes_nowhere() -> void:
	var model := SimModel.new()
	model.add_stock("a", 10.0, StockRange.between(0.0, 100.0))
	model.add_stock("b", 0.0)
	model.add_flow("a_to_b", "a", "b", 30.0)
	model.advance_turn()
	assert_float(_stock(model, "a")).is_equal(0.0)
	# 送り先の b は、元の流量どおり 30 増える。削った 20 は a にも b にも戻らない。
	assert_float(_stock(model, "b")).is_equal(30.0)


func test_step_also_clamps() -> void:
	var model := _food_model(1.0, StockRange.between(0.0, 100.0), 0.0, 5.0)
	model.step()
	assert_float(_stock(model, "food")).is_equal(0.0)


func test_stock_without_flow_stays_as_is() -> void:
	var model := SimModel.new()
	model.add_stock("still", 5.0, StockRange.between(0.0, 10.0))
	model.add_stock("a", 1.0)
	model.add_flow("f", "", "a", 1.0)
	model.advance_turn()
	assert_float(_stock(model, "still")).is_equal(5.0)


func test_expression_flow_reads_clamped_value_next_turn() -> void:
	var model := SimModel.new()
	model.add_stock("food", 10.0, StockRange.between(0.0, 12.0))
	model.add_stock("fed", 0.0)
	model.add_flow("grow", "", "food", 5.0)
	model.add_flow_expr("eat", "", "fed", "food")
	model.advance_turn()
	assert_float(_stock(model, "food")).is_equal(12.0)
	model.advance_turn()
	assert_float(_stock(model, "fed")).is_equal(10.0 + 12.0)


func test_overflow_policy_is_selectable_and_defaults_to_clamp() -> void:
	assert_int(StockRange.between(0.0, 1.0).get_overflow()).is_equal(StockRange.Overflow.CLAMP)
	assert_int(StockRange.at_least(0.0, StockRange.Overflow.CLAMP).get_overflow()).is_equal(StockRange.Overflow.CLAMP)
	assert_int(StockRange.at_most(0.0, StockRange.Overflow.CLAMP).get_overflow()).is_equal(StockRange.Overflow.CLAMP)


# --- 基準4：収めた後の値が非有限なら、そのターンは実行時エラー ---

func test_non_finite_after_clamping_is_runtime_error_and_state_is_kept() -> void:
	var model := SimModel.new()
	model.add_stock("a", 1.0, StockRange.at_least(0.0))
	model.add_stock("b", 5.0)
	model.add_flow("huge1", "", "a", 1e308)
	model.add_flow("huge2", "", "a", 1e308)
	model.add_flow("ok", "", "b", 1.0)
	assert_int(model.advance_turn()).is_equal(FAILED)
	assert_str(model.last_error).contains("ターン 1")
	assert_float(_stock(model, "a")).is_equal(1.0)
	assert_float(_stock(model, "b")).is_equal(5.0)
	assert_int(model.get_turn()).is_equal(0)


func test_nan_after_clamping_is_runtime_error() -> void:
	var model := SimModel.new()
	model.add_stock("a", 1.0, StockRange.between(0.0, 10.0))
	model.add_flow_expr("bad", "", "a", "sqrt(0 - 1)")
	assert_int(model.advance_turn()).is_equal(FAILED)
	assert_float(_stock(model, "a")).is_equal(1.0)
	assert_int(model.get_turn()).is_equal(0)


func test_infinity_that_clamping_makes_finite_is_not_an_error() -> void:
	# 上限があれば、合計が無限大でも上限に収まって有限になる。収めた後の値で判定する。
	var model := SimModel.new()
	model.add_stock("a", 1.0, StockRange.at_most(10.0))
	model.add_flow("huge1", "", "a", 1e308)
	model.add_flow("huge2", "", "a", 1e308)
	assert_int(model.advance_turn()).is_equal(OK)
	assert_float(_stock(model, "a")).is_equal(10.0)


func test_defeat_judgement_sees_clamped_values_and_failure_restores_state() -> void:
	var model := _food_model(2.0, StockRange.at_least(0.0), 0.0, 5.0)
	model.add_defeat_condition("starved", "food <= 0")
	model.advance_turn()
	assert_float(_stock(model, "food")).is_equal(0.0)
	assert_str(model.get_result().condition_name).is_equal("starved")
	# 判定で失敗したターンは、範囲に収めた値ごと取り消す。
	var model2 := _food_model(2.0, StockRange.at_least(0.0), 0.0, 5.0)
	model2.add_defeat_condition("bad", "1 / food")
	assert_int(model2.advance_turn()).is_equal(FAILED)
	assert_float(_stock(model2, "food")).is_equal(2.0)
	assert_int(model2.get_turn()).is_equal(0)


# --- 基準5：組み立て時の検査 ---

func test_lower_above_upper_is_invalid_parameter() -> void:
	var model := SimModel.new()
	assert_int(model.add_stock("a", 5.0, StockRange.between(10.0, 0.0))).is_equal(ERR_INVALID_PARAMETER)
	assert_str(model.last_error).contains("下限が上限より大きい")
	assert_bool(model.has_stock("a")).is_false()
	assert_object(model.get_stock_range("a")).is_null()


func test_lower_equal_to_upper_is_allowed() -> void:
	var model := SimModel.new()
	assert_int(model.add_stock("a", 5.0, StockRange.between(5.0, 5.0))).is_equal(OK)


func test_initial_value_outside_range_is_invalid_parameter() -> void:
	var model := SimModel.new()
	assert_int(model.add_stock("a", -1.0, StockRange.at_least(0.0))).is_equal(ERR_INVALID_PARAMETER)
	assert_str(model.last_error).contains("初期値が下限を下回る")
	assert_int(model.add_stock("a", 11.0, StockRange.at_most(10.0))).is_equal(ERR_INVALID_PARAMETER)
	assert_str(model.last_error).contains("初期値が上限を上回る")
	assert_bool(model.has_stock("a")).is_false()
	# 境界の値は範囲内である。
	assert_int(model.add_stock("a", 0.0, StockRange.between(0.0, 10.0))).is_equal(OK)
	assert_int(model.add_stock("b", 10.0, StockRange.between(0.0, 10.0))).is_equal(OK)


func test_non_finite_bounds_are_invalid_parameter() -> void:
	for label: String in HostileValues.floats():
		var value: float = HostileValues.floats()[label]
		var model := SimModel.new()
		var ranges: Dictionary = {
			"between 下限": StockRange.between(value, 10.0),
			"between 上限": StockRange.between(0.0, value),
			"at_least": StockRange.at_least(value),
			"at_most": StockRange.at_most(value),
		}
		for where: String in ranges:
			var code := model.add_stock("a", 1.0, ranges[where])
			assert_int(code).override_failure_message("%s %s" % [label, where]).is_equal(ERR_INVALID_PARAMETER)
			assert_bool(model.has_stock("a")).is_false()
			assert_bool(model.last_error.is_empty()).is_false()
			assert_str(HostileValues.find_raw_invisible(model.last_error)).is_empty()


func test_non_finite_initial_value_with_range_is_invalid_parameter() -> void:
	for label: String in HostileValues.floats():
		var value: float = HostileValues.floats()[label]
		var model := SimModel.new()
		assert_int(model.add_stock("a", value, StockRange.between(0.0, 10.0))).override_failure_message(label).is_equal(ERR_INVALID_PARAMETER)
		assert_bool(model.has_stock("a")).is_false()


func test_unknown_overflow_is_invalid_parameter() -> void:
	var model := SimModel.new()
	var stock_range := StockRange.between(0.0, 10.0, 99 as StockRange.Overflow)
	assert_int(model.add_stock("a", 1.0, stock_range)).is_equal(ERR_INVALID_PARAMETER)
	assert_bool(model.has_stock("a")).is_false()


func test_hostile_names_with_range_errors_are_escaped() -> void:
	for label: String in HostileValues.strings():
		var value: String = HostileValues.strings()[label]
		var model := SimModel.new()
		model.add_stock(value, 5.0, StockRange.between(10.0, 0.0))
		assert_str(HostileValues.find_raw_invisible(model.last_error)).override_failure_message(label).is_empty()
		assert_int(model.last_error.length()).is_less_equal(ModelCheck.MAX_LAST_ERROR_LENGTH)


func test_range_cannot_be_changed_after_setting() -> void:
	var model := SimModel.new()
	model.add_stock("a", 5.0, StockRange.between(0.0, 10.0))
	# 公開の変更関数は無い。同名の再定義は拒否され、元の範囲が残る。
	assert_int(model.add_stock("a", 5.0, StockRange.between(0.0, 100.0))).is_equal(ERR_ALREADY_EXISTS)
	assert_float(model.get_stock_range("a").get_upper()).is_equal(10.0)
	for method in ["set_lower", "set_upper", "set_stock_range", "set_range"]:
		assert_bool(model.has_method(method)).is_false()
		assert_bool(model.get_stock_range("a").has_method(method)).is_false()


# --- 基準6：更新後の値が範囲内。多数ターン・小数の流量で、境界に実際に当てる ---

## 範囲を使う run を 300 ターン進める。各ターンで範囲内を確かめ、境界に達したターン数を返す。
## 境界に張り付いた値は apply が返した境界そのものなので、厳密に比べる。許容誤差は範囲の途中の値だけに使う。
func _run_and_count_boundary_turns(model: SimModel, lower: float, upper: float) -> Dictionary:
	var counts: Dictionary = {"lower": 0, "upper": 0, "middle": 0}
	for turn in 300:
		assert_int(model.advance_turn()).is_equal(OK)
		var food := _stock(model, "food")
		if food == lower:
			counts["lower"] += 1
		elif food == upper:
			counts["upper"] += 1
		else:
			counts["middle"] += 1
			assert_float(food).is_between(lower + TOLERANCE, upper - TOLERANCE)
	return counts


func test_values_stick_to_lower_bound_over_many_turns() -> void:
	# 消費が生産より多く、50 から減って 0 に張り付く。範囲が無ければ負になり続ける。
	var model := SimModel.new()
	model.add_stock("food", 50.0, StockRange.between(0.0, 100.0))
	model.add_stock("pop", 10.0)
	model.add_flow_expr("harvest", "", "food", "0.3 * pop")
	model.add_flow_expr("eat", "food", "", "0.1 * food + 0.37 * pop")
	var counts := _run_and_count_boundary_turns(model, 0.0, 100.0)
	assert_int(counts["lower"]).is_greater(0)
	assert_int(counts["upper"]).is_equal(0)
	assert_int(counts["middle"]).is_greater(0)
	assert_float(_stock(model, "food")).is_equal(0.0)


func test_values_stick_to_upper_bound_over_many_turns() -> void:
	# 生産が消費より多く、50 から増えて 100 に張り付く。範囲が無ければ増え続ける。
	var model := SimModel.new()
	model.add_stock("food", 50.0, StockRange.between(0.0, 100.0))
	model.add_stock("pop", 10.0)
	model.add_flow_expr("harvest", "", "food", "0.7 * pop + 3.3")
	model.add_flow_expr("eat", "food", "", "0.01 * food + 0.37 * pop")
	var counts := _run_and_count_boundary_turns(model, 0.0, 100.0)
	assert_int(counts["upper"]).is_greater(0)
	assert_int(counts["lower"]).is_equal(0)
	assert_int(counts["middle"]).is_greater(0)
	assert_float(_stock(model, "food")).is_equal(100.0)
