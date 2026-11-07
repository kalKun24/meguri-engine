## アクションの効果でも、ストックの上限・下限を守ることのテスト（#39）。シーンを使わない。
class_name SimModelActionRangeTest
extends GdUnitTestSuite

var _applied: Array[String] = []


func _on_action_applied(action_name: String) -> void:
	_applied.append(action_name)


func _food_model(initial: float = 50.0) -> SimModel:
	var model := SimModel.new()
	assert_int(model.add_stock("food", initial, StockRange.between(0.0, 100.0))).is_equal(OK)
	return model


func test_effect_above_upper_is_clamped_and_succeeds() -> void:
	var model := _food_model()
	model.add_action("feast", "1", ["food = food + 1000"])
	assert_int(model.apply_action("feast")).is_equal(OK)
	assert_float(model.get_stock("food").value).is_equal(100.0)
	assert_str(model.last_error).is_empty()


func test_effect_below_lower_is_clamped_and_succeeds() -> void:
	var model := _food_model()
	model.add_action("famine", "1", ["food = food - 1000"])
	assert_int(model.apply_action("famine")).is_equal(OK)
	assert_float(model.get_stock("food").value).is_equal(0.0)


func test_effect_inside_range_is_unchanged() -> void:
	var model := _food_model()
	model.add_action("small", "1", ["food = food + 7.5"])
	assert_int(model.apply_action("small")).is_equal(OK)
	assert_float(model.get_stock("food").value).is_equal(57.5)


func test_one_sided_ranges() -> void:
	var model := SimModel.new()
	model.add_stock("low", 5.0, StockRange.at_least(0.0))
	model.add_stock("high", 5.0, StockRange.at_most(10.0))
	model.add_action("a", "1", ["low = low - 100", "high = high + 100"])
	assert_int(model.apply_action("a")).is_equal(OK)
	assert_float(model.get_stock("low").value).is_equal(0.0)
	assert_float(model.get_stock("high").value).is_equal(10.0)
	model.add_action("b", "1", ["low = low + 1000000", "high = high - 1000000"])
	assert_int(model.apply_action("b")).is_equal(OK)
	assert_float(model.get_stock("low").value).is_equal(1000000.0)
	assert_float(model.get_stock("high").value).is_equal(10.0 - 1000000.0)


func test_stock_without_range_still_grows() -> void:
	var model := SimModel.new()
	model.add_stock("gold", 50.0)
	model.add_action("feast", "1", ["gold = gold + 1000"])
	assert_int(model.apply_action("feast")).is_equal(OK)
	assert_float(model.get_stock("gold").value).is_equal(1050.0)


func test_stock_without_flow_is_clamped() -> void:
	# このモデルにはフローが無い。フローの更新を通らないストックも、範囲の外に残らない。
	var model := _food_model()
	model.add_action("feast", "1", ["food = food + 1000"])
	model.apply_action("feast")
	assert_float(model.get_stock("food").value).is_equal(100.0)


func test_action_applied_signal_is_unchanged() -> void:
	var model := _food_model()
	model.add_action("feast", "1", ["food = food + 1000"])
	_applied.clear()
	model.action_applied.connect(_on_action_applied)
	model.apply_action("feast")
	model.action_applied.disconnect(_on_action_applied)
	assert_array(_applied).contains_exactly(["feast"])


func test_clamped_amount_is_lost_not_carried() -> void:
	# 削った量は消える。次のアクションは収めた後の値（100）から計算する。
	var model := _food_model()
	model.add_action("feast", "1", ["food = food + 1000"])
	model.add_action("fast", "1", ["food = food - 10"])
	model.apply_action("feast")
	model.apply_action("fast")
	assert_float(model.get_stock("food").value).is_equal(90.0)


func test_effects_evaluate_with_unclamped_values_and_clamp_once_at_reflection() -> void:
	# 複数の効果は実行前の値で評価する。収めるのは反映の直前の1回だけで、
	# 別の効果の式は収める前の値ではなく、実行前の値を見る。
	var model := SimModel.new()
	model.add_stock("food", 50.0, StockRange.between(0.0, 100.0))
	model.add_stock("seen", 0.0)
	model.add_action("a", "1", ["food = food + 1000", "seen = food"])
	assert_int(model.apply_action("a")).is_equal(OK)
	assert_float(model.get_stock("food").value).is_equal(100.0)
	assert_float(model.get_stock("seen").value).is_equal(50.0)


func test_effect_on_constant_is_not_clamped() -> void:
	var model := SimModel.new()
	model.add_constant("rate", 1.0)
	model.add_action("a", "1", ["rate = rate + 1000"])
	assert_int(model.apply_action("a")).is_equal(OK)
	assert_float(model.get_constant("rate").value).is_equal(1001.0)


func test_non_finite_effect_still_fails_and_changes_nothing() -> void:
	# 収める前に非有限を拒否する。収めた後の値は、有限の上限・下限の中にあるので非有限にならない。
	var model := _food_model()
	assert_int(model.add_action("boom", "1", ["food = pow(10, 400)"])).is_equal(OK)
	var before := model.get_stock("food").value
	assert_int(model.apply_action("boom")).is_equal(FAILED)
	assert_float(model.get_stock("food").value).is_equal(before)


func test_victory_judgement_sees_clamped_value() -> void:
	# 範囲の外（1050）なら「food > 100」が成り立つ。収めた値（100）では成り立たない。
	var model := _food_model()
	model.add_stock("pop", 1.0)
	model.add_flow("tick", "", "pop", 1.0)
	model.add_victory_condition("overflow", "food > 100")
	model.add_defeat_condition("starved", "food <= 0")
	model.add_action("feast", "1", ["food = food + 1000"])
	assert_int(model.apply_action("feast")).is_equal(OK)
	assert_int(model.advance_turn()).is_equal(OK)
	assert_float(model.get_stock("food").value).is_equal(100.0)
	assert_str(model.get_result().outcome).is_equal(GameResult.OUTCOME_PENDING)


func test_defeat_judgement_sees_clamped_value() -> void:
	# 範囲の外（-950）でも、収めた値（0）でも「food <= 0」は成り立つ。境界で止まった値を見る。
	var model := _food_model()
	model.add_stock("pop", 1.0)
	model.add_flow("tick", "", "pop", 1.0)
	model.add_defeat_condition("starved", "food < 0")
	model.add_action("famine", "1", ["food = food - 1000"])
	assert_int(model.apply_action("famine")).is_equal(OK)
	assert_int(model.advance_turn()).is_equal(OK)
	assert_str(model.get_result().outcome).is_equal(GameResult.OUTCOME_PENDING)
