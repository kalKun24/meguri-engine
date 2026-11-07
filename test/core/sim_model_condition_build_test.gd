## 勝利・敗北の条件の式の組み立ての使い回し（#37）のテスト。
## 条件の式は validate() で一度だけ組み立て、組み立てた結果（命令列）を条件ごとに持つ。_validated が false の間だけ組み立て直す。
## 組み立てた回数は SimModel._condition_build_count で数える。
class_name SimModelConditionBuildTest
extends GdUnitTestSuite


func _new_model() -> SimModel:
	var model := SimModel.new()
	model.add_stock("population", 100.0)
	model.add_stock("money", 1000000.0)
	model.add_constant("goal", 1000000.0)
	model.add_flow("growth", "", "population", 1.0)
	model.add_flow("cost", "money", "", 1.0)
	model.add_victory_condition("rich", "population >= goal")
	model.add_defeat_condition("broke", "money <= 0")
	model.add_defeat_condition("empty", "population <= 0")
	return model


# 組み立ては validate() の1回だけで、ターン数に比例しない。
func test_conditions_are_built_once_not_per_turn() -> void:
	var model := _new_model()
	for i in 50:
		assert_int(model.advance_turn()).is_equal(OK)
	assert_int(model._condition_build_count).is_equal(3)


func test_build_count_does_not_depend_on_turn_count() -> void:
	var counts: Array[int] = []
	for turns: int in [1, 10, 200]:
		var model := _new_model()
		for i in turns:
			model.advance_turn()
		counts.append(model._condition_build_count)
	assert_array(counts).is_equal([3, 3, 3])


# validate() を先に呼んでおけば、advance_turn() は組み立て直さない。
func test_explicit_validate_builds_and_turns_reuse() -> void:
	var model := _new_model()
	assert_int(model._condition_build_count).is_equal(0)
	assert_int(model.validate()).is_equal(OK)
	assert_int(model._condition_build_count).is_equal(3)
	model.advance_turn()
	model.advance_turn()
	assert_int(model._condition_build_count).is_equal(3)


# 組み立てた結果（命令列）は、条件ごとに持つ。補助変数やフローと同じく、命令の数を数えられる。
func test_built_program_is_kept_per_condition() -> void:
	var model := _new_model()
	assert_object(model._conditions[0]["program"]).is_null()
	model.validate()
	for condition: Dictionary in model._conditions:
		var program: ExprProgram = condition["program"]
		assert_object(program).is_not_null()
		assert_int(program.ops.size()).is_greater(0)
	# 使い回している：ターンを進めても同じ命令列である。
	var first: ExprProgram = model._conditions[0]["program"]
	model.advance_turn()
	assert_bool(model._conditions[0]["program"] == first).is_true()


# 後から足したストックの名前を使う条件も動く。足したのは組み立て済みの後なので、_validated の仕組みで組み立て直す。
func test_condition_using_stock_added_later_works() -> void:
	var model := _new_model()
	model.advance_turn()
	model.advance_turn()
	assert_int(model._condition_build_count).is_equal(3)
	assert_int(model.add_stock("late", 0.0)).is_equal(OK)
	assert_int(model.add_flow("late_growth", "", "late", 2.0)).is_equal(OK)
	assert_int(model.add_victory_condition("late_win", "late >= 6")).is_equal(OK)
	# 足したあとの最初のターンで、条件を全部組み立て直す（既存の3つと新しい1つ）。
	assert_int(model.advance_turn()).is_equal(OK)
	assert_int(model._condition_build_count).is_equal(3 + 4)
	assert_bool(model.is_ended()).is_false()
	assert_int(model.advance_turn()).is_equal(OK)
	assert_int(model.advance_turn()).is_equal(OK)
	assert_bool(model.is_ended()).is_true()
	assert_str(model.get_result().condition_name).is_equal("late_win")
	assert_int(model.get_result().turn).is_equal(5)
	# 終わるまで、組み立て直しは1回だけである。
	assert_int(model._condition_build_count).is_equal(7)


# 条件だけを後から足したときも、次のターンで組み立てる（ストックや定数は足していない）。
func test_condition_added_alone_after_validation_is_built() -> void:
	var model := _new_model()
	model.advance_turn()
	assert_int(model.add_victory_condition("soon", "population >= 103")).is_equal(OK)
	assert_int(model.advance_turn()).is_equal(OK)
	assert_int(model.advance_turn()).is_equal(OK)
	assert_bool(model.is_ended()).is_true()
	assert_str(model.get_result().condition_name).is_equal("soon")
	assert_int(model._condition_build_count).is_equal(3 + 4)


# ストックを足しても、足す前から持つ条件の結果は変わらない。
func test_existing_conditions_still_work_after_adding_stock() -> void:
	var model := _new_model()
	model.advance_turn()
	model.add_stock("late", 0.0)
	model.add_defeat_condition("late_negative", "late < 0")
	assert_int(model.advance_turn()).is_equal(OK)
	assert_bool(model.is_ended()).is_false()
	assert_float(model.get_stock("population").value).is_equal(102.0)


# 定数をアクションで変えると、条件は新しい値で判定される（組み立て直す）。
func test_condition_sees_constant_changed_by_action() -> void:
	var model := SimModel.new()
	model.add_stock("population", 100.0)
	model.add_constant("goal", 120.0)
	model.add_flow("growth", "", "population", 5.0)
	model.add_victory_condition("rich", "population >= goal")
	model.add_action("lower_goal", "1", ["goal = 100"])
	assert_int(model.advance_turn()).is_equal(OK)
	assert_int(model._condition_build_count).is_equal(1)
	assert_bool(model.is_ended()).is_false()
	assert_int(model.apply_action("lower_goal")).is_equal(OK)
	assert_int(model.advance_turn()).is_equal(OK)
	assert_int(model._condition_build_count).is_equal(2)
	assert_bool(model.is_ended()).is_true()
	assert_str(model.get_result().condition_name).is_equal("rich")


# 定数が変わらなければ、アクションを実行しても条件は組み立て直さない（ストックだけを変えるアクション）。
func test_stock_only_action_does_not_rebuild() -> void:
	var model := SimModel.new()
	model.add_stock("population", 100.0)
	model.add_flow("growth", "", "population", 1.0)
	model.add_victory_condition("rich", "population >= 1000")
	model.add_action("bonus", "1", ["population = population + 1"])
	for i in 20:
		model.apply_action("bonus")
		model.advance_turn()
	assert_int(model._condition_build_count).is_equal(1)


# 取り消されたターン（条件の評価の失敗）でも、組み立てた結果は壊れず、次のターンで使える。
func test_failed_turn_keeps_built_conditions() -> void:
	var model := SimModel.new()
	model.add_stock("a", 1.0)
	model.add_stock("zero", 0.0)
	model.add_flow("tick", "", "a", 1.0)
	model.add_defeat_condition("div", "1 / zero > 0")
	assert_int(model.advance_turn()).is_equal(FAILED)
	assert_int(model.advance_turn()).is_equal(FAILED)
	assert_int(model.advance_turn()).is_equal(FAILED)
	assert_int(model.get_turn()).is_equal(0)
	assert_str(model.last_error).contains("終了判定")
	assert_bool(model._condition_build_count <= 3).is_true()


# --- 組み立てのエラー文は、エスケープと長さの上限を守る（T4-2 の列6） ---

# 条件の組み立てに失敗する状態を、ストックを内部から消して作る（公開関数では作れない）。
func _broken_model(condition_name: String, expression: String) -> SimModel:
	var model := SimModel.new()
	model.add_stock("a", 1.0)
	model.add_stock("b", 1.0)
	assert_int(model.add_defeat_condition(condition_name, expression)).is_equal(OK)
	model._stocks.erase("a")
	model._validated = false
	return model


func test_build_error_is_reported_and_state_unchanged() -> void:
	var model := _broken_model("broken", "a > 0")
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains("敗北条件「broken」の式に誤りがある")
	assert_str(model.last_error).contains("未定義の名前")
	assert_bool(model._validated).is_false()
	assert_int(model.advance_turn()).is_equal(ERR_INVALID_DATA)
	assert_int(model.get_turn()).is_equal(0)


func test_build_error_escapes_name() -> void:
	var raw_names: Array[String] = [
		"n" + char(0x202E) + "x",
		"n" + char(0x200B) + "x",
		"n" + char(0x0007) + "x",
		"n" + char(0x2028) + "x",
	]
	var defined := 0
	for condition_name in raw_names:
		var model := SimModel.new()
		model.add_stock("a", 1.0)
		if model.add_defeat_condition(condition_name, "a > 0") != OK:
			continue
		defined += 1
		model._stocks.erase("a")
		model._validated = false
		assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
		assert_str(HostileValues.find_raw_invisible(model.last_error)).override_failure_message("生の不可視文字：" + model.last_error).is_empty()
		assert_str(model.last_error).contains("\\u{")
	# 少なくとも1つは定義が通り、エスケープの検査が空振りになっていない。
	assert_int(defined).is_greater(0)


func test_build_error_excerpts_long_expression_and_stays_within_limit() -> void:
	var long_expression := "a" + "+b".repeat(380)
	var model := _broken_model("long", long_expression)
	assert_int(long_expression.length()).is_equal(761)
	assert_int(model.validate()).is_equal(ERR_INVALID_DATA)
	assert_int(model.last_error.length()).is_less_equal(ModelCheck.MAX_LAST_ERROR_LENGTH)
	assert_str(model.last_error).contains("...")
	var long_name := "n".repeat(ModelCheck.MAX_NAME_LENGTH)
	var named := _broken_model(long_name, long_expression)
	assert_int(named.validate()).is_equal(ERR_INVALID_DATA)
	assert_int(named.last_error.length()).is_less_equal(ModelCheck.MAX_LAST_ERROR_LENGTH)


# 敵対的な文字列を条件の名前にしたとき（定義が通ったものだけ）、組み立てのエラー文にも生の不可視文字が出ない。
func test_build_error_with_hostile_names_from_shared_list() -> void:
	for label: String in HostileValues.strings():
		var value: String = HostileValues.strings()[label]
		var model := SimModel.new()
		model.add_stock("a", 1.0)
		if model.add_victory_condition(value, "a > 0") != OK:
			continue
		model._stocks.erase("a")
		model._validated = false
		assert_int(model.validate()).override_failure_message(label).is_equal(ERR_INVALID_DATA)
		assert_str(HostileValues.find_raw_invisible(model.last_error)).override_failure_message("生の不可視文字：" + label).is_empty()
		assert_int(model.last_error.length()).override_failure_message(label).is_less_equal(ModelCheck.MAX_LAST_ERROR_LENGTH)
