## 敵対的な値の共有一覧（HostileValues）を、勝利・敗北の条件の公開関数に全件流すテスト（T2-1）。
## 対象：SimModel の add_victory_condition・add_defeat_condition（名前・式）、set_simultaneous_priority、
## 判定の失敗（advance_turn）、終了後の拒否と、結果の理由の文（AutoRunResult.describe_end）。
## 各呼び出しについて、落ちない、失敗なら last_error が空でなく生の不可視文字を含まない、モデルは変わらない、を確かめる。
class_name HostileEndTest
extends GdUnitTestSuite


func _new_model() -> SimModel:
	var model := SimModel.new()
	model.add_stock("a", 1.0)
	model.add_constant("k", 2.0)
	model.add_flow("tick", "", "a", 1.0)
	return model


func _snapshot(model: SimModel) -> String:
	return "%s|%d|%s|%s|%s" % [model.get_stock_names(), model.get_turn(), model.get_stock("a").value, model.get_constant("k").value, model.get_result().outcome]


func _check(model: SimModel, code: Error, before: String, label: String) -> void:
	var raw := HostileValues.find_raw_invisible(model.last_error)
	assert_str(raw).override_failure_message("%s：last_error に %s" % [label, raw]).is_empty()
	assert_int(model.last_error.length()).override_failure_message(label + "：last_error が長すぎる").is_less_equal(ModelCheck.MAX_LAST_ERROR_LENGTH)
	if code == OK:
		assert_str(model.last_error).override_failure_message(label + "：成功なのに last_error が残っている").is_empty()
	else:
		assert_str(model.last_error).override_failure_message(label + "：失敗なのに last_error が空").is_not_empty()
		assert_str(_snapshot(model)).override_failure_message(label + "：失敗なのにモデルが変わった").is_equal(before)


func test_add_conditions_with_hostile_strings() -> void:
	for label: String in HostileValues.strings():
		var value: String = HostileValues.strings()[label]
		for add_victory in [true, false]:
			var kind := "勝利" if add_victory else "敗北"
			var model := _new_model()
			var before := _snapshot(model)
			var code := model.add_victory_condition(value, "a > 0") if add_victory else model.add_defeat_condition(value, "a > 0")
			_check(model, code, before, "%s条件 名前 %s" % [kind, label])
			model = _new_model()
			code = model.add_victory_condition("x", value) if add_victory else model.add_defeat_condition("x", value)
			_check(model, code, before, "%s条件 式 %s" % [kind, label])


func test_add_conditions_with_hostile_floats_as_expression_text() -> void:
	for label: String in HostileValues.floats():
		var value: float = HostileValues.floats()[label]
		var model := _new_model()
		var before := _snapshot(model)
		var code := model.add_defeat_condition("x", "a < " + str(value))
		_check(model, code, before, "式の数 " + label)
		if code == OK:
			model.advance_turn()
			assert_str(HostileValues.find_raw_invisible(model.last_error)).is_empty()


# 敵対的な名前で定義が通った条件の、判定失敗・終了後の拒否・終了の理由の文に、生の不可視文字が出ない。
func test_defined_hostile_names_are_escaped_everywhere() -> void:
	for label: String in HostileValues.strings():
		var value: String = HostileValues.strings()[label]
		var model := _new_model()
		model.add_stock("zero", 0.0)
		if model.add_defeat_condition(value, "1 / zero > 0") != OK:
			continue
		var before := _snapshot(model)
		_check(model, model.advance_turn(), before, "判定失敗 " + label)
		var ending := _new_model()
		ending.add_victory_condition(value, "a > 0")
		ending.advance_turn()
		assert_bool(ending.is_ended()).override_failure_message(label).is_true()
		var ended_before := _snapshot(ending)
		_check(ending, ending.advance_turn(), ended_before, "終了後 " + label)
		var result := AutoRunResult.new()
		result.game_result = ending.get_result()
		var text := result.describe_end()
		assert_str(HostileValues.find_raw_invisible(text)).override_failure_message("describe_end " + label).is_empty()
		assert_int(text.length()).override_failure_message("describe_end の長さ " + label).is_less(300)


# 足すと無限大になる有限の2数が、条件の式の中で起きても、ターン全体が取り消される。
func test_overflow_pairs_in_condition_cancel_the_turn() -> void:
	for pair: Array in HostileValues.overflow_pairs():
		var model := SimModel.new()
		model.add_stock("a", pair[0])
		model.add_stock("t", 0.0)
		model.add_constant("k", pair[1])
		model.add_flow("tick", "", "t", 1.0)
		assert_int(model.add_defeat_condition("overflow", "a + k > 0")).is_equal(OK)
		assert_int(model.advance_turn()).is_equal(FAILED)
		assert_str(model.last_error).is_not_empty()
		assert_str(HostileValues.find_raw_invisible(model.last_error)).is_empty()
		assert_float(model.get_stock("t").value).is_equal(0.0)
		assert_int(model.get_turn()).is_equal(0)
		assert_bool(model.is_ended()).is_false()


func test_set_priority_with_hostile_strings() -> void:
	for label: String in HostileValues.strings():
		var value: String = HostileValues.strings()[label]
		var model := _new_model()
		var before := _snapshot(model)
		_check(model, model.set_simultaneous_priority(value), before, "優先 " + label)
		assert_str(model.get_simultaneous_priority()).is_equal(GameResult.OUTCOME_DEFEAT)


# 長い式が実行時に失敗しても、last_error は抜粋と上限に収まる。
func test_long_condition_expression_failure_is_excerpted() -> void:
	var model := _new_model()
	model.add_stock("zero", 0.0)
	var expression := "1 / zero > 0" + " ".repeat(500)
	assert_int(model.add_defeat_condition("long", expression)).is_equal(OK)
	assert_int(model.advance_turn()).is_equal(FAILED)
	assert_int(model.last_error.length()).is_less_equal(ModelCheck.MAX_LAST_ERROR_LENGTH)
	assert_str(model.last_error).contains("...")
