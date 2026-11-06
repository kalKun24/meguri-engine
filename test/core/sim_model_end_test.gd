## SimModel の勝利・敗北の条件（add_victory_condition・add_defeat_condition・advance_turn の終了判定・get_result・game_ended）のテスト。
## 受け入れ基準ごとに置く。シグナルは、メンバ関数につないで数える（ラムダに model を捕捉させない）。
class_name SimModelEndTest
extends GdUnitTestSuite

var _log: Array[String] = []


func _on_turn_finished(turn: int) -> void:
	_log.append("turn_finished:%d" % turn)


func _on_game_ended(outcome: String, condition_name: String, turn: int) -> void:
	_log.append("game_ended:%s:%s:%d" % [outcome, condition_name, turn])


func _on_action_applied(action_name: String) -> void:
	_log.append("action_applied:%s" % action_name)


# 人口が毎ターン 10 増え、お金が毎ターン 30 減る。
func _new_model() -> SimModel:
	var model := SimModel.new()
	model.add_stock("population", 100.0)
	model.add_stock("money", 100.0)
	model.add_constant("goal", 120.0)
	model.add_flow("growth", "", "population", 10.0)
	model.add_flow("cost", "money", "", 30.0)
	return model


func _state(model: SimModel) -> String:
	return "%s|%s|%s|%d|%s" % [model.get_stock("population").value, model.get_stock("money").value, model.get_constant("goal").value, model.get_turn(), model.get_result().outcome]


# --- 基準1：名前と式で、複数定義できる。名前は共通の名前空間、個数は MAX_DEFINITIONS を共有する ---

func test_define_multiple_conditions() -> void:
	var model := _new_model()
	assert_int(model.add_victory_condition("rich", "population >= goal")).is_equal(OK)
	assert_int(model.add_victory_condition("huge", "population >= 1000")).is_equal(OK)
	assert_int(model.add_defeat_condition("broke", "money <= 0")).is_equal(OK)
	assert_int(model.add_defeat_condition("empty", "population <= 0")).is_equal(OK)
	assert_str(model.last_error).is_empty()


func test_condition_name_shares_namespace() -> void:
	var model := _new_model()
	model.add_action("act", "1", ["money = money + 1"])
	model.add_victory_condition("win", "population >= goal")
	# 条件どうし、および条件とほかの定義の重複を禁止する。
	assert_int(model.add_victory_condition("win", "1")).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_defeat_condition("win", "1")).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_defeat_condition("population", "1")).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_victory_condition("goal", "1")).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_victory_condition("growth", "1")).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_victory_condition("act", "1")).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_victory_condition("min", "1")).is_equal(ERR_ALREADY_EXISTS)
	# 逆向き：条件の名前を、あとからほかの定義に使えない。
	assert_int(model.add_stock("win", 1.0)).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_constant("win", 1.0)).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_flow("win", "", "money", 1.0)).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_flow_expr("win", "", "money", "1")).is_equal(ERR_ALREADY_EXISTS)
	assert_int(model.add_action("win", "1", ["money = 1"])).is_equal(ERR_ALREADY_EXISTS)
	assert_str(model.last_error).contains("同名")


func test_conditions_share_max_definitions() -> void:
	var model := SimModel.new()
	model.add_stock("a", 0.0)
	var count: int = 1
	# 勝利・敗北を交互に定義して、上限ちょうどまで埋める。
	while count < ModelCheck.MAX_DEFINITIONS:
		var code := model.add_victory_condition("c%d" % count, "a > 1") if count % 2 == 0 else model.add_defeat_condition("c%d" % count, "a > 1")
		assert_int(code).is_equal(OK)
		count += 1
	assert_int(model.add_victory_condition("over", "a > 1")).is_equal(ERR_OUT_OF_MEMORY)
	assert_int(model.add_defeat_condition("over", "a > 1")).is_equal(ERR_OUT_OF_MEMORY)
	assert_int(model.add_stock("over", 1.0)).is_equal(ERR_OUT_OF_MEMORY)
	assert_int(model.add_action("over", "1", ["a = 1"])).is_equal(ERR_OUT_OF_MEMORY)
	# 逆に、ほかの定義で埋めると条件を足せない。
	var other := SimModel.new()
	other.add_stock("a", 0.0)
	for i in range(1, ModelCheck.MAX_DEFINITIONS):
		other.add_constant("k%d" % i, 1.0)
	assert_int(other.add_victory_condition("over", "a > 1")).is_equal(ERR_OUT_OF_MEMORY)


func test_invalid_condition_definitions() -> void:
	var model := _new_model()
	assert_int(model.add_victory_condition("", "1")).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.add_victory_condition(" ", "1")).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.add_victory_condition("x".repeat(ModelCheck.MAX_NAME_LENGTH + 1), "1")).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.add_victory_condition("x", "population >=")).is_equal(ERR_PARSE_ERROR)
	assert_str(model.last_error).contains("勝利条件")
	assert_int(model.add_defeat_condition("x", "nothing > 1")).is_equal(ERR_INVALID_DATA)
	assert_str(model.last_error).contains("敗北条件")
	assert_int(model.add_defeat_condition("x", "OS.get_name()")).is_not_equal(OK)
	# 失敗した名前は使われていない。
	assert_int(model.add_victory_condition("x", "population > 1")).is_equal(OK)
