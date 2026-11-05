## 敵対的な値の共有一覧（HostileValues）を、アクションの公開関数に全件流すテスト（T2-1）。
## 対象：SimModel の add_action（名前・条件・効果の文字列・効果の対象と式）と apply_action（名前）。
## 各呼び出しについて、次を確かめる。
##   - 落ちない
##   - 失敗なら last_error が空でなく、生の不可視文字を含まない。モデルは変わらない
##   - 成功なら last_error が空である
class_name HostileActionTest
extends GdUnitTestSuite


func _new_model() -> SimModel:
	var model := SimModel.new()
	model.add_stock("a", 1.0)
	model.add_constant("k", 2.0)
	model.add_action("base", "a > 0", ["a = a + 1"])
	return model


func _snapshot(model: SimModel) -> String:
	return "%s|%s|%d|%s|%s" % [model.get_stock_names(), model.get_action_names(), model.get_turn(), model.get_stock("a").value, model.get_constant("k").value]


func _check_result(model: SimModel, code: Error, before: String, label: String) -> void:
	var raw := HostileValues.find_raw_invisible(model.last_error)
	assert_str(raw).override_failure_message("%s：last_error に %s" % [label, raw]).is_empty()
	if code == OK:
		assert_str(model.last_error).override_failure_message("%s：成功なのに last_error が残っている" % label).is_empty()
	else:
		assert_str(model.last_error).override_failure_message("%s：失敗なのに last_error が空" % label).is_not_empty()
		assert_str(_snapshot(model)).override_failure_message("%s：失敗なのにモデルが変わった" % label).is_equal(before)


func test_add_action_with_hostile_strings() -> void:
	for label: String in HostileValues.strings():
		var value: String = HostileValues.strings()[label]
		var model := _new_model()
		var before := _snapshot(model)
		_check_result(model, model.add_action(value, "1", ["a = 1"]), before, "add_action 名前 " + label)
		model = _new_model()
		_check_result(model, model.add_action("x", value, ["a = 1"]), before, "add_action 条件 " + label)
		model = _new_model()
		_check_result(model, model.add_action("x", "1", [value]), before, "add_action 効果全体 " + label)
		model = _new_model()
		_check_result(model, model.add_action("x", "1", [value + " = 1"]), before, "add_action 効果の対象 " + label)
		model = _new_model()
		_check_result(model, model.add_action("x", "1", ["a = " + value]), before, "add_action 効果の式 " + label)
		model = _new_model()
		_check_result(model, model.add_action("x", "1", ["a = 1", value + " = 2"]), before, "add_action 2つ目の効果 " + label)


func test_add_action_with_non_string_effects() -> void:
	var model := _new_model()
	var before := _snapshot(model)
	var bad: Array = [null, 1, 1.5, [], {}, true, Vector2.ZERO]
	for item in bad:
		_check_result(model, model.add_action("x", "1", [item]), before, "非文字列の効果 " + str(item))


func test_add_action_with_hostile_floats_as_expression_text() -> void:
	for label: String in HostileValues.floats():
		var value: float = HostileValues.floats()[label]
		var model := _new_model()
		var before := _snapshot(model)
		var code := model.add_action("x", "1", ["a = " + str(value)])
		_check_result(model, code, before, "add_action 数 " + label)
		if code == OK:
			var applied := model.apply_action("x")
			assert_bool(is_finite(model.get_stock("a").value)).override_failure_message("apply_action 数 " + label).is_true()
			assert_str(HostileValues.find_raw_invisible(model.last_error)).is_empty()
			if applied != OK:
				assert_float(model.get_stock("a").value).is_equal(1.0)


func test_apply_action_with_hostile_names() -> void:
	for label: String in HostileValues.strings():
		var value: String = HostileValues.strings()[label]
		var model := _new_model()
		var before := _snapshot(model)
		var code := model.apply_action(value)
		_check_result(model, code, before, "apply_action 名前 " + label)
		assert_bool(model.has_action(value)).is_false()


# 敵対的な名前で定義が通った場合も、実行時のエラー文に生の不可視文字が出ない。
func test_apply_defined_hostile_action() -> void:
	for label: String in HostileValues.strings():
		var value: String = HostileValues.strings()[label]
		var model := _new_model()
		if model.add_action(value, "a > 100", ["a = 1"]) != OK:
			continue
		var before := _snapshot(model)
		_check_result(model, model.apply_action(value), before, "apply_action 定義済み " + label)
		model.add_stock("zero", 0.0)
		model.add_action(value + "2", "1", ["a = 1 / zero"])
		before = _snapshot(model)
		_check_result(model, model.apply_action(value + "2"), before, "apply_action 0除算 " + label)


# 足すと無限大になる有限の2数でも、アクションが FAILED になり、状態を変えない。
func test_overflow_pairs_fail_the_action() -> void:
	for pair: Array in HostileValues.overflow_pairs():
		var model := SimModel.new()
		model.add_stock("a", pair[0])
		model.add_stock("b", 3.0)
		model.add_constant("k", pair[1])
		assert_int(model.add_action("grow", "1", ["b = 9", "a = a + k"])).is_equal(OK)
		assert_int(model.apply_action("grow")).is_equal(FAILED)
		assert_str(model.last_error).is_not_empty()
		assert_str(HostileValues.find_raw_invisible(model.last_error)).is_empty()
		assert_float(model.get_stock("a").value).is_equal(pair[0])
		assert_float(model.get_stock("b").value).is_equal(3.0)
