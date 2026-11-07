## モデル全体の命令数の上限（#45）のテスト。
## 対象は、補助変数・フロー・勝利と敗北の条件の式の命令の合計である。定義した時点で、構文木の節の数から数える。
## 超える定義は ERR_OUT_OF_MEMORY で拒否し、last_error に上限と実際の数を出す。モデルは変わらない。
class_name SimModelOpsLimitTest
extends GdUnitTestSuite

const LIMIT: int = ModelCheck.MAX_TOTAL_OPS


# ちょうど ops 個の命令になる式を作る。ops が奇数なら "1+1+...+1"、偶数なら先頭に符号の "-" を付ける。
func _expr(ops: int) -> String:
	var odd := ops if ops % 2 == 1 else ops - 1
	var text := "1" + "+1".repeat((odd - 1) / 2)
	return text if ops % 2 == 1 else "-" + text


# 補助変数 aux_i を、命令数の合計が total になるまで足す（1個あたり最大 999 命令）。
func _fill(model: SimModel, total: int) -> void:
	var remaining := total
	var i := 0
	while remaining > 0:
		var ops := mini(remaining, 999)
		assert_int(model.add_auxiliary("fill%d" % i, _expr(ops))).is_equal(OK)
		remaining -= ops
		i += 1


func _new_base() -> SimModel:
	var model := SimModel.new()
	model.add_stock("s", 1.0)
	return model


# --- 数え方：組み立てた命令の数と一致する ---

func test_count_ops_equals_compiled_program_size() -> void:
	var sources: Array[String] = [
		"1", "s", "-s", "s + 1 * 2", "min(s, 3) + max(1, 2)", "-(-(-s))", "s < 3", "abs(s - 10) % 4 >= 1",
	]
	for source in sources:
		var parsed: ExprParseResult = ExprParser.new().parse(source)
		assert_bool(parsed.ok).override_failure_message(source).is_true()
		var compiled := ExprCompiler.compile(parsed.root, source, {"s": 1.0}, {})
		assert_bool(compiled.ok).override_failure_message(source).is_true()
		assert_int(ExprCompiler.count_ops(parsed.root)).override_failure_message(source).is_equal(compiled.program.ops.size())


func test_expr_helper_makes_exact_op_counts() -> void:
	for ops: int in [1, 2, 3, 99, 100, 999]:
		var parsed: ExprParseResult = ExprParser.new().parse(_expr(ops))
		assert_bool(parsed.ok).is_true()
		assert_int(ExprCompiler.count_ops(parsed.root)).is_equal(ops)


# --- 上限：ちょうどは通り、1つ超えると拒否する ---

func test_exactly_at_limit_is_accepted() -> void:
	var model := _new_base()
	_fill(model, LIMIT - 1)
	assert_int(model.add_auxiliary("last", "1")).is_equal(OK)
	assert_int(model._total_ops).is_equal(LIMIT)
	assert_int(model.validate()).is_equal(OK)
	assert_str(model.last_error).is_empty()


func test_one_over_limit_is_rejected_for_each_kind() -> void:
	var kinds: Dictionary = {
		"補助変数": func(m: SimModel) -> Error: return m.add_auxiliary("over", "1"),
		"フロー": func(m: SimModel) -> Error: return m.add_flow_expr("over", "", "s", "1"),
		"勝利条件": func(m: SimModel) -> Error: return m.add_victory_condition("over", "s > 1"),
		"敗北条件": func(m: SimModel) -> Error: return m.add_defeat_condition("over", "s > 1"),
	}
	for label: String in kinds:
		var model := _new_base()
		_fill(model, LIMIT)
		var adder: Callable = kinds[label]
		var before := _state(model)
		var ops := ExprCompiler.count_ops(ExprParser.new().parse("s > 1").root) if label.ends_with("条件") else 1
		assert_int(adder.call(model)).override_failure_message(label).is_equal(ERR_OUT_OF_MEMORY)
		# 上限と、実際の数（足した後の合計）が出る。
		assert_str(model.last_error).override_failure_message(label).contains(str(LIMIT))
		assert_str(model.last_error).override_failure_message(label).contains(str(LIMIT + ops))
		assert_str(model.last_error).override_failure_message(label).contains("over")
		assert_dict(_state(model)).override_failure_message(label).is_equal(before)
		# 同じ名前をもう一度使える（名前が登録されていない）。
		assert_bool(model._names.has("over")).override_failure_message(label).is_false()


func test_rejection_then_smaller_definition_succeeds() -> void:
	var model := _new_base()
	_fill(model, LIMIT - 5)
	assert_int(model.add_auxiliary("big", _expr(6))).is_equal(ERR_OUT_OF_MEMORY)
	assert_int(model.add_auxiliary("big", _expr(5))).is_equal(OK)
	assert_str(model.last_error).is_empty()
	assert_int(model._total_ops).is_equal(LIMIT)


func test_total_counts_all_four_kinds() -> void:
	var model := _new_base()
	assert_int(model.add_auxiliary("a", _expr(10))).is_equal(OK)
	assert_int(model.add_flow_expr("f", "", "s", _expr(20))).is_equal(OK)
	assert_int(model.add_victory_condition("v", "s > 1")).is_equal(OK)
	assert_int(model.add_defeat_condition("d", "s < 0 - 1")).is_equal(OK)
	# s > 1 は3命令、s < 0 - 1 は5命令。
	assert_int(model._total_ops).is_equal(10 + 20 + 3 + 5)
	# 定数のフロー、ストック、定数、アクションは数えない。
	model.add_flow("g", "", "s", 1.0)
	model.add_constant("k", 1.0)
	model.add_stock("t", 1.0)
	model.add_action("act", "1", ["k = k + 1"])
	assert_int(model._total_ops).is_equal(38)


# 条件だけで上限に達する。条件の命令数にも、補助変数・フローと同じ上限がかかる。
func test_conditions_alone_are_limited() -> void:
	var model := _new_base()
	var expression := "s" + "+s".repeat(497) + " < 0"
	var per := ExprCompiler.count_ops(ExprParser.new().parse(expression).root)
	var accepted := 0
	var code := OK
	while code == OK and accepted < 200:
		code = model.add_defeat_condition("c%d" % accepted, expression)
		if code == OK:
			accepted += 1
	assert_int(code).is_equal(ERR_OUT_OF_MEMORY)
	assert_int(accepted).is_equal(LIMIT / per)
	assert_int(model._total_ops).is_equal(accepted * per)
	assert_int(model._conditions.size()).is_equal(accepted)


# --- 組み立てに失敗した条件（program が null）と新旧の program の混在 ---

# 数えるのは定義した時点の構文木であり、program の有無に依らない。
# 組み立てに失敗して program が null の条件も、前の validate() で組み立てた古い program の条件も、同じように数える。
func test_null_and_stale_programs_do_not_change_the_count() -> void:
	var model := SimModel.new()
	model.add_stock("a", 1.0)
	model.add_stock("b", 1.0)
	model.add_defeat_condition("first", "a > 0")
	assert_int(model.validate()).is_equal(OK)
	var first_program: ExprProgram = model._conditions[0]["program"]
	model.add_defeat_condition("second", "a + b > 0")
	model.add_defeat_condition("third", "b > 0")
	var total := model._total_ops
	# 2番目の条件の組み立てを失敗させる（公開関数では作れないので、ストックを内部から消す）。
	model._stocks.erase("a")
	model._validated = false
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	# 1番目は失敗、残りは組み立てられていない：program は null か、古いままである。
	assert_object(model._conditions[0]["program"]).is_null()
	assert_object(model._conditions[1]["program"]).is_null()
	assert_object(model._conditions[2]["program"]).is_null()
	assert_bool(first_program != null).is_true()
	# 合計は変わらず、構文木の節の数の和と一致する。
	assert_int(model._total_ops).is_equal(total)
	var summed := 0
	for condition: Dictionary in model._conditions:
		summed += ExprCompiler.count_ops(condition["root"])
	assert_int(summed).is_equal(total)


func test_limit_still_applies_while_some_programs_are_null() -> void:
	var model := SimModel.new()
	model.add_stock("a", 1.0)
	model.add_stock("b", 1.0)
	model.add_defeat_condition("first", "a > 0")
	_fill(model, LIMIT - 3)
	model._stocks.erase("a")
	model._validated = false
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	assert_object(model._conditions[0]["program"]).is_null()
	assert_int(model._total_ops).is_equal(LIMIT)
	assert_int(model.add_defeat_condition("more", "b > 0")).is_equal(ERR_OUT_OF_MEMORY)
	assert_int(model._total_ops).is_equal(LIMIT)


# 組み立てに成功した後、program の命令の合計は _total_ops と一致する。
func test_total_equals_sum_of_built_programs() -> void:
	var model := _new_base()
	model.add_constant("k", 2.0)
	model.add_auxiliary("a", "s * k + 1")
	model.add_auxiliary("b", "a + a")
	model.add_flow_expr("f", "", "s", "b / 2")
	model.add_victory_condition("v", "s > k * 100")
	model.add_defeat_condition("d", "s < -5")
	assert_int(model.validate()).is_equal(OK)
	var summed := 0
	for auxiliary: Dictionary in model._auxiliaries:
		summed += (auxiliary["program"] as ExprProgram).ops.size()
	for flow: Dictionary in model._flows:
		if flow["program"] != null:
			summed += (flow["program"] as ExprProgram).ops.size()
	for condition: Dictionary in model._conditions:
		summed += (condition["program"] as ExprProgram).ops.size()
	assert_int(summed).is_equal(model._total_ops)


# ターンを進めても、アクションを実行しても、合計は変わらない（定義だけが数える）。
func test_total_does_not_change_by_turns_or_actions() -> void:
	var model := _new_base()
	model.add_constant("k", 1.0)
	model.add_flow_expr("f", "", "s", "k")
	model.add_action("bump", "1", ["k = k + 1", "s = s + k * 2 + 3 * 4 - 5"])
	model.add_defeat_condition("d", "s < -5")
	var total := model._total_ops
	for i in 5:
		model.apply_action("bump")
		model.advance_turn()
	assert_int(model._total_ops).is_equal(total)


# 凍結後は、上限の検査より先に ERR_LOCKED を返す。
func test_frozen_model_reports_locked_before_ops_limit() -> void:
	var model := _new_base()
	model.add_victory_condition("win", "s > 0")
	model.advance_turn()
	assert_bool(model.is_ended()).is_true()
	assert_int(model.add_auxiliary("late", "1")).is_equal(ERR_LOCKED)


func _state(model: SimModel) -> Dictionary:
	return {
		"total": model._total_ops,
		"names": model._names.size(),
		"auxiliaries": model._auxiliaries.size(),
		"flows": model._flows.size(),
		"conditions": model._conditions.size(),
		"validated": model._validated,
	}
