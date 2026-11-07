## SimModel の補助変数（add_auxiliary・validate・step）のテスト。シーンを使わない。
## 受け入れ基準（#11）ごとに節を分けている。
class_name SimModelAuxiliaryTest
extends GdUnitTestSuite

## 長さ1000の鎖の規模。ModelCheck.MAX_DEFINITIONS と同じで、補助変数だけでモデルの定義の上限まで使う。
const CHAIN_LENGTH: int = 1000


# 1人あたりの食料を補助変数に持つモデル。補助変数の定義順を引数で入れ替えられる。
func _per_capita(reverse: bool) -> SimModel:
	var model := SimModel.new()
	model.add_stock("population", 50.0)
	model.add_stock("food", 200.0)
	model.add_stock("mood", 0.0)
	model.add_constant("k", 0.5)
	var definitions: Array[Array] = [
		["per_capita", "food / population"],
		["comfort", "per_capita * k + bonus"],
		["bonus", "min(per_capita, 3)"],
	]
	if reverse:
		definitions.reverse()
	for definition: Array in definitions:
		assert_int(model.add_auxiliary(definition[0], definition[1])).is_equal(OK)
	assert_int(model.add_flow_expr("lift", "", "mood", "comfort")).is_equal(OK)
	return model


# 鎖 a0 = 1、a1 = a0 + 1、... を作る。reverse が true なら、定義を逆順に並べる。
func _chain(length: int, reverse: bool) -> SimModel:
	var model := SimModel.new()
	var names: Array[int] = []
	for i in length:
		names.append(i)
	if reverse:
		names.reverse()
	for i: int in names:
		var expression := "1" if i == 0 else "a%d + 1" % (i - 1)
		assert_int(model.add_auxiliary("a%d" % i, expression)).is_equal(OK)
	return model


# --- 基準1：補助変数を式で書ける。ストック・定数・補助変数を名前で参照できる ---

func test_auxiliary_can_reference_stocks_constants_and_other_auxiliaries() -> void:
	var model := SimModel.new()
	model.add_stock("food", 90.0)
	model.add_stock("population", 30.0)
	model.add_stock("out", 0.0)
	model.add_constant("k", 2.0)
	assert_int(model.add_auxiliary("per_capita", "food / population")).is_equal(OK)
	assert_int(model.add_auxiliary("scaled", "per_capita * k")).is_equal(OK)
	assert_int(model.add_flow_expr("f", "", "out", "scaled + per_capita")).is_equal(OK)
	assert_int(model.step()).is_equal(OK)
	assert_float(model.get_stock("out").value).is_equal(9.0)


func test_flow_expression_uses_the_auxiliary_value_from_before_the_update() -> void:
	var model := SimModel.new()
	model.add_stock("a", 10.0)
	model.add_stock("b", 0.0)
	model.add_auxiliary("half", "a / 2")
	model.add_flow_expr("move", "a", "b", "half")
	model.add_flow_expr("again", "a", "b", "half")
	assert_int(model.step()).is_equal(OK)
	# half は更新前の a から 1 度だけ求めた 5。2 本のフローがどちらも 5 を使う。
	assert_float(model.get_stock("a").value).is_equal(0.0)
	assert_float(model.get_stock("b").value).is_equal(10.0)


func test_auxiliary_is_recomputed_every_turn_from_the_current_stocks() -> void:
	var model := SimModel.new()
	model.add_stock("a", 8.0)
	model.add_stock("sink", 0.0)
	model.add_auxiliary("half", "a / 2")
	model.add_flow_expr("move", "a", "sink", "half")
	model.step()
	assert_float(model.get_stock("a").value).is_equal(4.0)
	model.step()
	assert_float(model.get_stock("a").value).is_equal(2.0)


func test_auxiliary_syntax_error_is_reported_when_defined() -> void:
	var model := SimModel.new()
	assert_int(model.add_auxiliary("bad", "1 +")).is_equal(ERR_PARSE_ERROR)
	assert_str(model.last_error).contains("bad")


func test_undefined_name_in_an_auxiliary_is_an_error_at_validate() -> void:
	var model := SimModel.new()
	model.add_stock("s", 1.0)
	assert_int(model.add_auxiliary("x", "nowhere + 1")).is_equal(OK)
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains("x").contains("nowhere")
	assert_int(model.step()).is_equal(ERR_INVALID_DATA)
	assert_int(model.get_turn()).is_equal(0)


func test_auxiliary_defined_after_the_flow_that_uses_it_is_resolved() -> void:
	var model := SimModel.new()
	model.add_stock("out", 0.0)
	assert_int(model.add_flow_expr("f", "", "out", "late + 1")).is_equal(OK)
	assert_int(model.add_auxiliary("late", "4")).is_equal(OK)
	assert_int(model.step()).is_equal(OK)
	assert_float(model.get_stock("out").value).is_equal(5.0)


func test_action_and_condition_expressions_cannot_reference_auxiliaries() -> void:
	# 補助変数の値はターンの開始時にだけ求めるので、ターンの合間のアクションと終了判定は参照できない（assumptions を参照）。
	var model := SimModel.new()
	model.add_stock("s", 1.0)
	model.add_auxiliary("x", "s * 2")
	assert_int(model.add_action("act", "x > 0", ["s = s + 1"])).is_equal(ERR_INVALID_DATA)
	assert_int(model.add_victory_condition("win", "x > 0")).is_equal(ERR_INVALID_DATA)


# --- 基準2：名前空間の重複禁止と名前の規則 ---

func test_auxiliary_name_conflicts_with_every_other_kind_of_name() -> void:
	var cases: Dictionary = {
		"ストック": "s",
		"定数": "c",
		"フロー": "f",
		"許可関数": "min",
		"補助変数": "x",
	}
	for label: String in cases:
		var model := SimModel.new()
		model.add_stock("s", 1.0)
		model.add_constant("c", 1.0)
		model.add_flow_expr("f", "", "s", "1")
		model.add_auxiliary("x", "1")
		assert_int(model.add_auxiliary(cases[label], "2")).override_failure_message("%s と同名の補助変数が通った" % label).is_equal(ERR_ALREADY_EXISTS)
		assert_str(model.last_error).is_not_empty()


func test_other_definitions_cannot_reuse_an_auxiliary_name() -> void:
	var model := SimModel.new()
	model.add_stock("s", 1.0)
	model.add_auxiliary("x", "1")
	assert_int(model.add_stock("x", 1.0)).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_constant("x", 1.0)).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_flow("x", "", "s", 1.0)).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_flow_expr("x", "", "s", "1")).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_action("x", "1", ["s = 1"])).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_victory_condition("x", "1")).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_defeat_condition("x", "1")).is_equal(ERR_ALREADY_EXISTS)


func test_auxiliary_name_follows_the_identifier_rule_for_every_hostile_string() -> void:
	var strings: Dictionary = HostileValues.strings()
	for label: String in strings:
		var value: String = strings[label]
		if ModelCheck.check_identifier(value, "補助変数名").is_empty():
			continue
		var model := SimModel.new()
		model.add_stock("s", 1.0)
		assert_int(model.add_auxiliary(value, "1")).override_failure_message("%s が補助変数名として通った" % label).is_equal(ERR_INVALID_PARAMETER)
		assert_bool(ModelCheck.limit_last_error(model.last_error) == model.last_error).is_true()
		assert_array(model.get_stock_names()).is_equal(["s"])
		# 拒否された名前でモデルが壊れていないこと。
		assert_int(model.add_auxiliary("ok", "1")).is_equal(OK)


func test_auxiliary_name_rule_is_the_same_as_the_shared_check() -> void:
	for name_value: String in ["人口", " pop", "pop ", "1st", "a-b", "", "   ", "pop", "_a", "A1"]:
		var model := SimModel.new()
		var expected := ModelCheck.check_identifier(name_value, "補助変数名")
		var code := model.add_auxiliary(name_value, "1")
		if expected.is_empty():
			assert_int(code).is_equal(OK)
		else:
			assert_int(code).is_equal(ERR_INVALID_PARAMETER)
			assert_str(model.last_error).is_equal(ModelCheck.limit_last_error(expected))


func test_auxiliary_counts_toward_the_definition_limit() -> void:
	var model := SimModel.new()
	for i in ModelCheck.MAX_DEFINITIONS:
		assert_int(model.add_auxiliary("a%d" % i, "1")).is_equal(OK)
	assert_int(model.add_auxiliary("over", "1")).is_equal(ERR_OUT_OF_MEMORY)
	assert_int(model.add_stock("s", 1.0)).is_equal(ERR_OUT_OF_MEMORY)


# --- 基準3：依存の順に一度だけ求める。定義の順で結果が変わらない ---

func test_definition_order_of_auxiliaries_does_not_change_the_result() -> void:
	var forward := _per_capita(false)
	var reversed := _per_capita(true)
	for turn in 5:
		assert_int(forward.step()).is_equal(OK)
		assert_int(reversed.step()).is_equal(OK)
		for stock_name: String in ["population", "food", "mood"]:
			assert_bool(forward.get_stock(stock_name).value == reversed.get_stock(stock_name).value) \
				.override_failure_message("ターン %d の %s が定義順で変わった" % [turn + 1, stock_name]).is_true()


func test_dependent_auxiliary_defined_first_still_sees_the_computed_value() -> void:
	var model := _per_capita(true)
	model.step()
	# per_capita = 4、bonus = 3、comfort = 4 * 0.5 + 3 = 5。
	assert_float(model.get_stock("mood").value).is_equal(5.0)


func test_each_auxiliary_is_evaluated_once_per_turn() -> void:
	# 補助変数は評価のたびに値が変わるわけではないので、「フロー 3 本が、フローの反映前の同じ値を見る」ことで更新前に 1 度だけ求めたことを確かめる。
	var model := SimModel.new()
	model.add_stock("a", 10.0)
	model.add_stock("x", 0.0)
	model.add_stock("y", 0.0)
	model.add_auxiliary("half", "a / 2")
	model.add_flow_expr("to_x", "", "x", "half")
	model.add_flow_expr("to_y", "", "y", "half + 0")
	model.add_flow_expr("drain", "a", "", "a")
	model.step()
	assert_float(model.get_stock("x").value).is_equal(5.0)
	assert_float(model.get_stock("y").value).is_equal(5.0)


func test_auxiliary_value_does_not_see_changes_made_by_flows_in_the_same_turn() -> void:
	var model := SimModel.new()
	model.add_stock("a", 10.0)
	model.add_stock("b", 0.0)
	model.add_auxiliary("snapshot", "a")
	model.add_flow_expr("empty", "a", "", "a")
	model.add_flow_expr("copy", "", "b", "snapshot")
	model.step()
	assert_float(model.get_stock("b").value).is_equal(10.0)
	assert_float(model.get_stock("a").value).is_equal(0.0)


# --- 基準4：循環参照は組み立て時のエラー。経路を含める。再帰に頼らない ---

func test_self_reference_is_an_error_at_validate_with_the_path() -> void:
	var model := SimModel.new()
	assert_int(model.add_auxiliary("a", "a + 1")).is_equal(OK)
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains("a -> a")


func test_two_step_cycle_shows_the_path_a_b_a() -> void:
	var model := SimModel.new()
	model.add_auxiliary("a", "b + 1")
	model.add_auxiliary("b", "a + 1")
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains("a -> b -> a")


func test_cycle_path_starts_at_the_cycle_even_when_reached_through_other_auxiliaries() -> void:
	var model := SimModel.new()
	model.add_auxiliary("entry", "x + 1")
	model.add_auxiliary("x", "y + 1")
	model.add_auxiliary("y", "z + 1")
	model.add_auxiliary("z", "x + 1")
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains("x -> y -> z -> x")
	assert_str(model.last_error).not_contains("entry")


func test_step_returns_the_same_error_and_changes_nothing() -> void:
	var model := SimModel.new()
	model.add_stock("s", 5.0)
	model.add_auxiliary("a", "b")
	model.add_auxiliary("b", "a")
	model.add_flow_expr("f", "", "s", "1")
	assert_int(model.step()).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains("a -> b -> a")
	assert_float(model.get_stock("s").value).is_equal(5.0)
	assert_int(model.get_turn()).is_equal(0)


func test_long_cycle_path_is_shortened_from_the_head() -> void:
	var model := SimModel.new()
	var length := 300
	for i in length:
		assert_int(model.add_auxiliary("n%d" % i, "n%d + 1" % ((i + 1) % length))).is_equal(OK)
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains("n0 -> n1 -> n2")
	assert_str(model.last_error).contains("...")
	assert_str(model.last_error).not_contains("n299")
	assert_bool(model.last_error.length() <= ModelCheck.MAX_LAST_ERROR_LENGTH).is_true()


func test_cycle_path_length_is_limited_by_the_constant() -> void:
	var model := SimModel.new()
	var length := ModelCheck.MAX_CYCLE_PATH_LENGTH + 5
	for i in length:
		model.add_auxiliary("n%d" % i, "n%d" % ((i + 1) % length))
	model.validate()
	assert_bool(model.last_error.contains("n%d" % (ModelCheck.MAX_CYCLE_PATH_LENGTH - 1))).is_true()
	assert_bool(model.last_error.contains("n%d -> " % ModelCheck.MAX_CYCLE_PATH_LENGTH)).is_false()


func test_chain_of_1000_does_not_fail_in_either_definition_order() -> void:
	for reverse: bool in [false, true]:
		var model := _chain(CHAIN_LENGTH, reverse)
		assert_int(model.validate()).override_failure_message("鎖 %d の validate が失敗（reverse=%s）：%s" % [CHAIN_LENGTH, reverse, model.last_error]).is_equal(OK)
		assert_int(model.step()).is_equal(OK)


func test_chain_of_1000_gives_the_same_flow_result_whichever_way_it_is_defined() -> void:
	var results: Array[float] = []
	for reverse: bool in [false, true]:
		var model := SimModel.new()
		model.add_stock("out", 0.0)
		for i in CHAIN_LENGTH - 2:
			var index := CHAIN_LENGTH - 3 - i if reverse else i
			assert_int(model.add_auxiliary("a%d" % index, "1" if index == 0 else "a%d + 1" % (index - 1))).is_equal(OK)
		assert_int(model.add_flow_expr("f", "", "out", "a%d" % (CHAIN_LENGTH - 3))).is_equal(OK)
		assert_int(model.step()).is_equal(OK)
		results.append(model.get_stock("out").value)
	assert_float(results[0]).is_equal(float(CHAIN_LENGTH - 2))
	assert_bool(results[0] == results[1]).is_true()


func test_cycle_closing_a_chain_of_1000_is_detected() -> void:
	var model := SimModel.new()
	for i in CHAIN_LENGTH:
		model.add_auxiliary("a%d" % i, "a%d" % ((i + 1) % CHAIN_LENGTH))
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains("a0 -> a1 -> a2")
	assert_bool(model.last_error.length() <= ModelCheck.MAX_LAST_ERROR_LENGTH).is_true()


# --- 基準5：補助変数はフローの量を参照できない ---

func test_auxiliary_cannot_reference_a_flow() -> void:
	var model := SimModel.new()
	model.add_stock("s", 1.0)
	model.add_flow_expr("f", "", "s", "1")
	assert_int(model.add_auxiliary("x", "f + 1")).is_equal(OK)
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains("x").contains("f").contains("フロー")
	assert_int(model.step()).is_equal(ERR_INVALID_DATA)


func test_reference_to_a_flow_defined_after_the_auxiliary_is_also_an_error() -> void:
	var model := SimModel.new()
	model.add_stock("s", 1.0)
	model.add_auxiliary("x", "later")
	model.add_flow_expr("later", "", "s", "1")
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains("later").contains("フロー")


func test_flow_reference_through_another_auxiliary_is_still_an_error() -> void:
	var model := SimModel.new()
	model.add_stock("s", 1.0)
	model.add_flow("fixed", "", "s", 1.0)
	model.add_auxiliary("y", "fixed")
	model.add_auxiliary("x", "y + 1")
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains("y").contains("fixed")


# --- 基準6：非有限は補助変数の名前を含む実行時エラー。ターンを止め、状態を変えない ---

func test_non_finite_auxiliary_stops_the_turn_with_its_name_and_keeps_the_state() -> void:
	var model := SimModel.new()
	model.add_stock("s", 10.0)
	model.add_stock("divisor", 1.0)
	model.add_stock("out", 0.0)
	model.add_auxiliary("ratio", "s / divisor")
	model.add_flow_expr("shrink", "divisor", "", "1")
	model.add_flow_expr("f", "", "out", "ratio")
	assert_int(model.step()).is_equal(OK)
	assert_float(model.get_stock("divisor").value).is_equal(0.0)
	var out_before: float = model.get_stock("out").value
	assert_int(model.step()).is_equal(FAILED)
	assert_str(model.last_error).contains("ターン 2").contains("補助変数「ratio」")
	assert_int(model.get_turn()).is_equal(1)
	assert_float(model.get_stock("out").value).is_equal(out_before)
	assert_float(model.get_stock("divisor").value).is_equal(0.0)


func test_overflowing_auxiliary_is_reported_by_name() -> void:
	var model := SimModel.new()
	model.add_stock("big", 1e308)
	model.add_auxiliary("boom", "big * 10")
	model.add_flow_expr("f", "", "big", "boom")
	assert_int(model.step()).is_equal(FAILED)
	assert_str(model.last_error).contains("boom")
	assert_float(model.get_stock("big").value).is_equal(1e308)


func test_auxiliary_error_in_advance_turn_leaves_the_game_unchanged() -> void:
	var model := SimModel.new()
	model.add_stock("zero", 0.0)
	model.add_auxiliary("bad", "1 / zero")
	assert_int(model.advance_turn()).is_equal(FAILED)
	assert_str(model.last_error).contains("bad")
	assert_int(model.get_turn()).is_equal(0)
	assert_bool(model.is_ended()).is_false()
