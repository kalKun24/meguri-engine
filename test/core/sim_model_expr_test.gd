## SimModel の式のフロー（add_flow_expr・validate・step）のテスト。シーンを使わない。
class_name SimModelExprTest
extends GdUnitTestSuite

var _signal_turns: Array[int] = []


func _on_turn_finished(turn: int) -> void:
	_signal_turns.append(turn)


# 人口が増えると食料が減るモデル。
func _town() -> SimModel:
	var model := SimModel.new()
	model.add_stock("population", 100.0)
	model.add_stock("food", 1000.0)
	model.add_constant("birth_rate", 0.1)
	model.add_constant("ration", 0.5)
	return model


# 式を1本だけ持つモデルを1ターン進めた後の out の値を返す。
func _one_step(expression: String) -> float:
	var model := SimModel.new()
	model.add_stock("out", 0.0)
	model.add_stock("s", 8.0)
	model.add_constant("c", 3.0)
	assert_int(model.add_flow_expr("f", "", "out", expression)).is_equal(OK)
	assert_int(model.step()).is_equal(OK)
	return model.get_stock("out").value


# --- フローの量を式で書く ---

func test_flow_amount_from_expression_changes_values_by_the_formula() -> void:
	var model := _town()
	assert_int(model.add_flow_expr("births", "", "population", "population * birth_rate")).is_equal(OK)
	assert_int(model.add_flow_expr("eating", "food", "", "population * ration")).is_equal(OK)
	assert_int(model.step()).is_equal(OK)
	assert_float(model.get_stock("population").value).is_equal_approx(110.0, 0.0001)
	assert_float(model.get_stock("food").value).is_equal_approx(950.0, 0.0001)
	model.step()
	assert_float(model.get_stock("population").value).is_equal_approx(121.0, 0.0001)
	assert_float(model.get_stock("food").value).is_equal_approx(895.0, 0.0001)
	assert_int(model.get_turn()).is_equal(2)


func test_expressions_use_values_before_the_update() -> void:
	# a_to_b は a の半分を b へ送り、b_to_a は b の半分を a へ送る。一斉更新なら両方とも更新前の値で決まる。
	var model := SimModel.new()
	model.add_stock("a", 10.0)
	model.add_stock("b", 0.0)
	model.add_flow_expr("a_to_b", "a", "b", "a / 2")
	model.add_flow_expr("b_to_a", "b", "a", "b / 2 + 1")
	model.step()
	assert_float(model.get_stock("a").value).is_equal(6.0)
	assert_float(model.get_stock("b").value).is_equal(4.0)


func test_definition_order_does_not_change_the_result() -> void:
	var forward := SimModel.new()
	var reversed := SimModel.new()
	for model in [forward, reversed]:
		model.add_stock("a", 10.0)
		model.add_stock("b", 3.0)
	forward.add_flow_expr("f1", "a", "b", "a / 2")
	forward.add_flow_expr("f2", "b", "a", "b + 1")
	reversed.add_flow_expr("f2", "b", "a", "b + 1")
	reversed.add_flow_expr("f1", "a", "b", "a / 2")
	for i in 3:
		forward.step()
		reversed.step()
	assert_float(forward.get_stock("a").value).is_equal(reversed.get_stock("a").value)
	assert_float(forward.get_stock("b").value).is_equal(reversed.get_stock("b").value)


func test_expression_and_fixed_flows_can_be_mixed() -> void:
	var model := SimModel.new()
	model.add_stock("a", 10.0)
	model.add_stock("b", 0.0)
	assert_int(model.add_flow("fixed", "a", "b", 2.0)).is_equal(OK)
	assert_int(model.add_flow_expr("dyn", "a", "b", "a / 10")).is_equal(OK)
	model.step()
	assert_float(model.get_stock("a").value).is_equal(7.0)
	assert_float(model.get_stock("b").value).is_equal(3.0)


func test_all_values_are_float() -> void:
	assert_float(_one_step("1/2")).is_equal(0.5)
	assert_float(_one_step("s / 16")).is_equal(0.5)
	assert_float(_one_step("c < s")).is_equal(1.0)
	assert_float(_one_step("s < c")).is_equal(0.0)
	assert_float(_one_step("s % c")).is_equal(2.0)
	assert_float(_one_step("round(2.5) + round(-2.5)")).is_equal(0.0)
	assert_float(_one_step("clamp(s * c, 0, 20)")).is_equal(20.0)


# --- 入口：構文は add_flow_expr、名前と引数の数は検証関数 ---

func test_syntax_error_is_reported_when_the_flow_is_added() -> void:
	var model := _town()
	assert_int(model.add_flow_expr("f", "", "population", "1 +")).is_equal(ERR_PARSE_ERROR)
	assert_str(model.last_error).contains("1 +")
	assert_str(model.last_error).contains("位置 3")
	# 失敗したフローは定義されない。同じ名前でもう一度定義できる。
	assert_int(model.add_flow_expr("f", "", "population", "1")).is_equal(OK)
	assert_str(model.last_error).is_equal("")


func test_host_access_is_rejected_when_the_flow_is_added() -> void:
	var model := _town()
	for expression: String in ["OS.get_name()", "a.b", "population.x"]:
		assert_int(model.add_flow_expr("f", "", "population", expression)).is_equal(ERR_PARSE_ERROR)
		assert_str(model.last_error).contains(expression)
		assert_str(model.last_error).contains("位置")
	assert_int(model.add_flow_expr("f", "", "population", "1 + OS.get_name()")).is_equal(ERR_PARSE_ERROR)
	assert_str(model.last_error).contains("位置 6")


func test_get_stock_call_is_rejected_when_validated() -> void:
	var model := _town()
	assert_int(model.add_flow_expr("f", "", "population", "get_stock(1)")).is_equal(OK)
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains("許可されていない関数")
	assert_str(model.last_error).contains("get_stock(1)")
	assert_str(model.last_error).contains("位置 0")


func test_validate_reports_full_expression_position_and_cause() -> void:
	var model := _town()
	var expression := "population * birth_rate + lost_name * ration + population"
	model.add_flow_expr("f", "", "population", expression)
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains(expression)
	assert_str(model.last_error).contains("位置 26")
	assert_str(model.last_error).contains("未定義の名前")
	assert_str(model.last_error).contains("lost_name")
	assert_str(model.last_error).contains("「f」")


func test_validate_checks_all_flows_and_succeeds_when_all_are_valid() -> void:
	var model := _town()
	model.add_flow_expr("good", "", "population", "population * birth_rate")
	model.add_flow_expr("bad", "", "food", "unknown")
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains("「bad」")
	var ok_model := _town()
	ok_model.add_flow_expr("good", "", "population", "population * birth_rate")
	assert_int(ok_model.validate()).is_equal(OK)
	assert_str(ok_model.last_error).is_equal("")


func test_names_can_be_defined_after_the_flow_that_uses_them() -> void:
	var model := SimModel.new()
	model.add_stock("a", 1.0)
	model.add_flow_expr("f", "", "a", "later * 2")
	model.add_constant("later", 5.0)
	assert_int(model.step()).is_equal(OK)
	assert_float(model.get_stock("a").value).is_equal(11.0)


func test_step_validates_before_the_first_step_and_does_not_advance() -> void:
	var model := _town()
	model.add_flow_expr("f", "", "population", "missing")
	model.turn_finished.connect(_on_turn_finished)
	_signal_turns.clear()
	assert_int(model.step()).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains("未定義の名前")
	assert_int(model.get_turn()).is_equal(0)
	assert_float(model.get_stock("population").value).is_equal(100.0)
	assert_array(_signal_turns).is_empty()


func test_wrong_argument_count_is_a_validation_error() -> void:
	var model := _town()
	model.add_flow_expr("f", "", "population", "min(population)")
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains("引数は 2 個")
	assert_str(model.last_error).contains("位置 0")


func test_type_constructor_is_rejected_as_disallowed_function() -> void:
	var model := _town()
	model.add_flow_expr("f", "", "population", "Vector2(1, 2)")
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains("許可されていない関数")
	assert_str(model.last_error).contains("Vector2")


func test_bare_function_name_tells_how_to_fix() -> void:
	var model := _town()
	model.add_flow_expr("f", "", "population", "min")
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains("関数は () を付けて呼ぶ")


func test_flow_name_cannot_be_referenced_from_an_expression() -> void:
	var model := _town()
	model.add_flow("births", "", "population", 1.0)
	model.add_flow_expr("f", "", "population", "births")
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains("未定義の名前")


func test_nonfinite_literal_is_rejected_with_position_when_the_flow_is_added() -> void:
	var model := _town()
	assert_int(model.add_flow_expr("f", "", "population", "1 + " + "9".repeat(400))).is_equal(ERR_PARSE_ERROR)
	assert_str(model.last_error).contains("位置 4")
	assert_str(model.last_error).contains("有限")


# --- 名前の重複 ---

func test_names_cannot_collide_with_allowed_functions() -> void:
	for function_name in ExprFunctions.names():
		var model := SimModel.new()
		model.add_stock("a", 1.0)
		assert_int(model.add_stock(function_name, 1.0)).is_equal(ERR_ALREADY_EXISTS)
		assert_int(model.add_constant(function_name, 1.0)).is_equal(ERR_ALREADY_EXISTS)
		assert_int(model.add_flow(function_name, "", "a", 1.0)).is_equal(ERR_ALREADY_EXISTS)
		assert_int(model.add_flow_expr(function_name, "", "a", "1")).is_equal(ERR_ALREADY_EXISTS)
		assert_str(model.last_error).contains(function_name)


func test_names_cannot_collide_across_stock_constant_and_flow() -> void:
	var model := SimModel.new()
	model.add_stock("a", 1.0)
	model.add_constant("k", 1.0)
	model.add_flow_expr("f", "", "a", "1")
	assert_int(model.add_constant("a", 1.0)).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_stock("k", 1.0)).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_flow_expr("a", "", "a", "1")).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_flow_expr("f", "", "a", "1")).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_stock("f", 1.0)).is_equal(ERR_ALREADY_EXISTS)


func test_add_flow_expr_checks_name_and_endpoints_like_add_flow() -> void:
	var model := _town()
	assert_int(model.add_flow_expr("", "", "population", "1")).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.add_flow_expr("x".repeat(65), "", "population", "1")).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.add_flow_expr("f", "", "", "1")).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.add_flow_expr("f", "nothing", "", "1")).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.add_flow_expr("f", "", "nothing", "1")).is_equal(ERR_INVALID_PARAMETER)


func test_definition_limit_applies_to_expression_flows() -> void:
	var model := SimModel.new()
	model.add_stock("a", 0.0)
	for i in ModelCheck.MAX_DEFINITIONS - 1:
		assert_int(model.add_flow_expr("f%d" % i, "", "a", "1")).is_equal(OK)
	assert_int(model.add_flow_expr("last", "", "a", "1")).is_equal(ERR_OUT_OF_MEMORY)


func test_expression_longer_than_the_limit_is_rejected() -> void:
	var model := _town()
	assert_int(model.add_flow_expr("f", "", "population", "1+".repeat(600) + "1")).is_equal(ERR_PARSE_ERROR)
	assert_str(model.last_error).contains("長すぎる")


# --- 実行時エラー ---

func test_division_by_zero_fails_the_turn_without_changing_anything() -> void:
	var model := _town()
	model.add_stock("empty", 0.0)
	model.add_flow_expr("births", "", "population", "population * birth_rate")
	model.add_flow_expr("bad", "food", "", "population / empty")
	model.turn_finished.connect(_on_turn_finished)
	_signal_turns.clear()
	assert_int(model.step()).is_not_equal(OK)
	assert_str(model.last_error).contains("ターン 1")
	assert_str(model.last_error).contains("population / empty")
	assert_str(model.last_error).contains("0 で割った")
	assert_str(model.last_error).contains("「bad」")
	assert_int(model.get_turn()).is_equal(0)
	assert_float(model.get_stock("population").value).is_equal(100.0)
	assert_float(model.get_stock("food").value).is_equal(1000.0)
	assert_array(_signal_turns).is_empty()


func test_runtime_error_in_a_later_turn_reports_that_turn_and_keeps_state() -> void:
	var model := SimModel.new()
	model.add_stock("a", 2.0)
	model.add_stock("z", 0.0)
	model.add_flow_expr("drain", "a", "", "1")
	model.add_flow_expr("gain", "", "z", "1 / (a - 1)")
	assert_int(model.step()).is_equal(OK)
	assert_float(model.get_stock("a").value).is_equal(1.0)
	assert_float(model.get_stock("z").value).is_equal(1.0)
	assert_int(model.step()).is_not_equal(OK)
	assert_str(model.last_error).contains("ターン 2")
	assert_int(model.get_turn()).is_equal(1)
	assert_float(model.get_stock("a").value).is_equal(1.0)
	assert_float(model.get_stock("z").value).is_equal(1.0)


func test_runtime_errors_for_modulo_sqrt_and_overflow_name_the_cause() -> void:
	var cases: Dictionary = {
		"s % 0": "0 による剰余",
		"sqrt(0 - s)": "sqrt(-8.0)",
		"pow(10, 400)": "pow(10.0, 400.0)",
		"s * 1" + "0".repeat(300) + " * 1" + "0".repeat(300): "無限大",
	}
	for expression: String in cases:
		var model := SimModel.new()
		model.add_stock("out", 0.0)
		model.add_stock("s", 8.0)
		model.add_flow_expr("f", "", "out", expression)
		assert_int(model.step()).is_not_equal(OK)
		assert_str(model.last_error).contains(cases[expression])
		assert_str(model.last_error).contains(ModelCheck.escape_expression(expression))
		assert_str(model.last_error).contains("ターン 1")
		assert_int(model.get_turn()).is_equal(0)
		assert_float(model.get_stock("out").value).is_equal(0.0)


func test_stock_overflow_fails_the_turn_and_keeps_state() -> void:
	var model := SimModel.new()
	model.add_stock("a", 1.0)
	model.add_stock("b", 1.0)
	model.add_flow_expr("f", "", "a", "1" + "0".repeat(308))
	model.add_flow_expr("g", "", "a", "1" + "0".repeat(308))
	model.add_flow_expr("h", "", "a", "1" + "0".repeat(308))
	model.add_flow_expr("i", "", "b", "1")
	assert_int(model.step()).is_not_equal(OK)
	assert_str(model.last_error).contains("ターン 1")
	assert_str(model.last_error).contains("無限大")
	assert_float(model.get_stock("a").value).is_equal(1.0)
	assert_float(model.get_stock("b").value).is_equal(1.0)
	assert_int(model.get_turn()).is_equal(0)


func test_successful_step_clears_last_error() -> void:
	var model := _town()
	model.add_flow_expr("f", "", "population", "1")
	model.get_stock("nothing")
	assert_str(model.last_error).is_not_empty()
	assert_int(model.step()).is_equal(OK)
	assert_str(model.last_error).is_equal("")


# --- 制御文字のエスケープ（T1-1） ---

func test_control_characters_in_expression_are_escaped_in_errors() -> void:
	var newline := char(0x0A)
	var bidi := char(0x202E)
	var model := _town()
	var expression := "population" + newline + "+ missing" + bidi
	assert_int(model.add_flow_expr("f", "", "population", expression)).is_equal(ERR_PARSE_ERROR)
	for text in [newline, bidi]:
		assert_bool(model.last_error.contains(text)).is_false()
	assert_str(model.last_error).contains("\\u{000A}")
	# 構文は正しく、名前が未定義の式でも同じである。
	var model2 := _town()
	model2.add_flow_expr("f", "", "population", "population" + newline + "+ missing")
	assert_int(model2.validate()).is_equal(ERR_INVALID_DATA)
	assert_bool(model2.last_error.contains(newline)).is_false()
	assert_str(model2.last_error).contains("population\\u{000A}+ missing")
	# 実行時エラーでも同じである。
	var model3 := _town()
	model3.add_flow_expr("f", "", "population", "1" + newline + "/ 0")
	assert_int(model3.step()).is_not_equal(OK)
	assert_bool(model3.last_error.contains(newline)).is_false()
	assert_str(model3.last_error).contains("1\\u{000A}/ 0")


func test_full_expression_is_shown_even_when_longer_than_the_name_limit() -> void:
	var model := _town()
	var expression := "population + population + population + population + population + missing"
	model.add_flow_expr("f", "", "population", expression)
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains(expression)
	assert_bool(model.last_error.contains("...")).is_false()


# --- 長い式 ---

func test_long_expression_of_1000_characters_runs_in_a_flow() -> void:
	var model := SimModel.new()
	model.add_stock("a", 0.0)
	var expression := "1" + "+1".repeat(499) + " "
	assert_int(expression.length()).is_equal(1000)
	assert_int(model.add_flow_expr("f", "", "a", expression)).is_equal(OK)
	assert_int(model.step()).is_equal(OK)
	assert_float(model.get_stock("a").value).is_equal(500.0)


# --- ホストへの到達 ---

func test_no_host_call_reaches_through_an_expression() -> void:
	for expression: String in ["OS.get_name()", "get_stock(1)", "a.b", "OS.execute('ls', [])", "load('res://x')", "Engine.get_version_info()", "self", "Vector2(1, 2)"]:
		var model := _town()
		var added := model.add_flow_expr("f", "", "population", expression)
		var rejected := added != OK
		if not rejected:
			rejected = model.validate() != OK
		assert_bool(rejected).is_true()
		assert_str(model.last_error).is_not_empty()
