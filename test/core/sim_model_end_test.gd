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


# --- 基準2：advance_turn() が成功したターンの最後に、1回だけ判定する ---

func test_judged_after_flows_at_end_of_turn() -> void:
	var model := _new_model()
	model.add_victory_condition("rich", "population >= goal")
	# ターン 1 で人口は 110。ターン 2 で 120 になって初めて成り立つ。
	assert_int(model.advance_turn()).is_equal(OK)
	assert_bool(model.is_ended()).is_false()
	assert_int(model.advance_turn()).is_equal(OK)
	assert_bool(model.is_ended()).is_true()
	assert_int(model.get_result().turn).is_equal(2)


func test_initial_state_is_not_judged() -> void:
	var model := _new_model()
	# ターン 0 の時点で成り立っている条件。
	model.add_defeat_condition("always", "money > 0")
	assert_bool(model.is_ended()).is_false()
	assert_str(model.get_result().outcome).is_equal(GameResult.OUTCOME_PENDING)
	assert_int(model.get_turn()).is_equal(0)
	# 最初の advance_turn() で、ターン 1 の終わりに判定される（ターン 0 ではない）。
	assert_int(model.advance_turn()).is_equal(OK)
	assert_int(model.get_result().turn).is_equal(1)


func test_action_does_not_judge() -> void:
	var model := _new_model()
	model.add_victory_condition("rich", "population >= goal")
	model.add_action("boom", "1", ["population = 500"])
	model.game_ended.connect(_on_game_ended)
	_log.clear()
	assert_int(model.apply_action("boom")).is_equal(OK)
	model.game_ended.disconnect(_on_game_ended)
	assert_bool(model.is_ended()).is_false()
	assert_array(_log).is_empty()
	# 次の advance_turn() の終わりで判定される。
	assert_int(model.advance_turn()).is_equal(OK)
	assert_str(model.get_result().condition_name).is_equal("rich")
	assert_int(model.get_result().turn).is_equal(1)


func test_step_does_not_judge() -> void:
	var model := _new_model()
	model.add_defeat_condition("always", "money > -1000")
	model.game_ended.connect(_on_game_ended)
	_log.clear()
	assert_int(model.step()).is_equal(OK)
	model.game_ended.disconnect(_on_game_ended)
	assert_bool(model.is_ended()).is_false()
	assert_array(_log).is_empty()


func test_game_ended_fires_once() -> void:
	var model := _new_model()
	model.add_victory_condition("rich", "population >= goal")
	model.game_ended.connect(_on_game_ended)
	_log.clear()
	for i in 5:
		model.advance_turn()
	model.game_ended.disconnect(_on_game_ended)
	assert_array(_log).has_size(1)


func test_no_conditions_never_ends() -> void:
	var model := _new_model()
	for i in 20:
		assert_int(model.advance_turn()).is_equal(OK)
	assert_bool(model.is_ended()).is_false()
	assert_int(model.get_turn()).is_equal(20)


# --- 基準3：同時に成り立ったときの優先 ---

# ターン 1 で、勝利 win_b と敗北 lose_a・lose_b が同時に成り立つ。
func _new_both_model() -> SimModel:
	var model := _new_model()
	model.add_victory_condition("win_a", "population >= goal")
	model.add_victory_condition("win_b", "population >= 110")
	model.add_defeat_condition("lose_a", "money <= 100")
	model.add_defeat_condition("lose_b", "money <= 1000")
	return model


func test_default_priority_is_defeat() -> void:
	var model := _new_both_model()
	assert_str(model.get_simultaneous_priority()).is_equal(GameResult.OUTCOME_DEFEAT)
	model.advance_turn()
	assert_str(model.get_result().outcome).is_equal(GameResult.OUTCOME_DEFEAT)
	# 同じ種類の中では、定義の順で最初のもの。
	assert_str(model.get_result().condition_name).is_equal("lose_a")


func test_victory_priority_when_configured() -> void:
	var model := _new_both_model()
	assert_int(model.set_simultaneous_priority(GameResult.OUTCOME_VICTORY)).is_equal(OK)
	assert_str(model.get_simultaneous_priority()).is_equal(GameResult.OUTCOME_VICTORY)
	model.advance_turn()
	assert_str(model.get_result().outcome).is_equal(GameResult.OUTCOME_VICTORY)
	assert_str(model.get_result().condition_name).is_equal("win_b")


func test_first_in_definition_order_within_same_kind() -> void:
	var model := _new_model()
	model.add_victory_condition("not_met", "population >= 9999")
	model.add_victory_condition("first_met", "population >= 100")
	model.add_victory_condition("later_met", "population >= 100")
	model.advance_turn()
	assert_str(model.get_result().condition_name).is_equal("first_met")
	var defeat_model := _new_model()
	defeat_model.add_defeat_condition("d1", "money < 0")
	defeat_model.add_defeat_condition("d2", "money < 1000")
	defeat_model.add_defeat_condition("d3", "money < 1000")
	defeat_model.advance_turn()
	assert_str(defeat_model.get_result().condition_name).is_equal("d2")


func test_only_one_side_met_ignores_priority() -> void:
	for priority in [GameResult.OUTCOME_VICTORY, GameResult.OUTCOME_DEFEAT]:
		var model := _new_model()
		model.set_simultaneous_priority(priority)
		model.add_victory_condition("win", "population >= 110")
		model.add_defeat_condition("lose", "money < 0")
		model.advance_turn()
		assert_str(model.get_result().outcome).is_equal(GameResult.OUTCOME_VICTORY)
		model = _new_model()
		model.set_simultaneous_priority(priority)
		model.add_victory_condition("win", "population >= 9999")
		model.add_defeat_condition("lose", "money < 1000")
		model.advance_turn()
		assert_str(model.get_result().outcome).is_equal(GameResult.OUTCOME_DEFEAT)


func test_invalid_priority_is_rejected() -> void:
	var model := _new_model()
	for value in ["", "pending", "win", "VICTORY", char(0x202E)]:
		assert_int(model.set_simultaneous_priority(value)).is_equal(ERR_INVALID_PARAMETER)
		assert_str(HostileValues.find_raw_invisible(model.last_error)).is_empty()
		assert_str(model.get_simultaneous_priority()).is_equal(GameResult.OUTCOME_DEFEAT)


# --- 基準4：get_result() と game_ended ---

func test_get_result_before_and_after() -> void:
	var model := _new_model()
	var pending := model.get_result()
	assert_str(pending.outcome).is_equal(GameResult.OUTCOME_PENDING)
	assert_str(pending.condition_name).is_empty()
	assert_int(pending.turn).is_equal(0)
	assert_bool(pending.is_ended()).is_false()
	model.add_victory_condition("rich", "population >= goal")
	model.advance_turn()
	model.advance_turn()
	var result := model.get_result()
	assert_str(result.outcome).is_equal(GameResult.OUTCOME_VICTORY)
	assert_str(result.condition_name).is_equal("rich")
	assert_int(result.turn).is_equal(2)
	assert_str(result.outcome_label()).is_equal("勝利")
	# 写しを書き換えても、モデルの結果は変わらない。
	result.outcome = GameResult.OUTCOME_PENDING
	assert_str(model.get_result().outcome).is_equal(GameResult.OUTCOME_VICTORY)
	var defeat := _new_model()
	defeat.add_defeat_condition("broke", "money <= 0")
	for i in 4:
		defeat.advance_turn()
	assert_str(defeat.get_result().outcome).is_equal(GameResult.OUTCOME_DEFEAT)
	assert_str(defeat.get_result().outcome_label()).is_equal("敗北")
	assert_int(defeat.get_result().turn).is_equal(4)


func test_game_ended_fires_after_turn_finished() -> void:
	var model := _new_model()
	model.add_victory_condition("rich", "population >= goal")
	model.turn_finished.connect(_on_turn_finished)
	model.game_ended.connect(_on_game_ended)
	_log.clear()
	model.advance_turn()
	model.advance_turn()
	model.turn_finished.disconnect(_on_turn_finished)
	model.game_ended.disconnect(_on_game_ended)
	assert_array(_log).is_equal(["turn_finished:1", "turn_finished:2", "game_ended:victory:rich:2"])


func test_get_result_does_not_change_last_error() -> void:
	var model := _new_model()
	model.add_stock("population", 1.0)
	assert_str(model.last_error).is_not_empty()
	model.get_result()
	model.is_ended()
	assert_str(model.last_error).is_not_empty()


# --- 基準5：終わった後の step・advance_turn・apply_action は、終了を区別できる Error を返し、状態を変えない ---

func _new_ended_model() -> SimModel:
	var model := _new_model()
	model.add_victory_condition("rich", "population >= goal")
	model.add_action("act", "1", ["money = money + 1"])
	model.advance_turn()
	model.advance_turn()
	assert_bool(model.is_ended()).is_true()
	return model


func _assert_locked(model: SimModel, code: Error, before: String) -> void:
	assert_int(code).is_equal(ERR_LOCKED)
	assert_str(model.last_error).is_equal("ゲームは終了している")
	assert_str(_state(model)).is_equal(before)
	assert_str(model.get_result().condition_name).is_equal("rich")
	assert_int(model.get_result().turn).is_equal(2)


func test_step_after_end_is_locked() -> void:
	var model := _new_ended_model()
	var before := _state(model)
	model.turn_finished.connect(_on_turn_finished)
	_log.clear()
	_assert_locked(model, model.step(), before)
	model.turn_finished.disconnect(_on_turn_finished)
	assert_array(_log).is_empty()


func test_advance_turn_after_end_is_locked() -> void:
	var model := _new_ended_model()
	var before := _state(model)
	model.turn_finished.connect(_on_turn_finished)
	model.game_ended.connect(_on_game_ended)
	_log.clear()
	_assert_locked(model, model.advance_turn(), before)
	model.turn_finished.disconnect(_on_turn_finished)
	model.game_ended.disconnect(_on_game_ended)
	assert_array(_log).is_empty()


func test_apply_action_after_end_is_locked() -> void:
	var model := _new_ended_model()
	var before := _state(model)
	model.action_applied.connect(_on_action_applied)
	_log.clear()
	_assert_locked(model, model.apply_action("act"), before)
	# 名前が空でも未定義でも、終了のエラーが先に返る。
	_assert_locked(model, model.apply_action(""), before)
	_assert_locked(model, model.apply_action("no_such"), before)
	model.action_applied.disconnect(_on_action_applied)
	assert_array(_log).is_empty()


func test_locked_error_is_distinguishable() -> void:
	var live := _new_model()
	live.add_action("act", "money > 99999", ["money = 1"])
	# 他の失敗（未定義、条件を満たさない）とは別のコードである。
	assert_int(live.apply_action("no_such")).is_not_equal(ERR_LOCKED)
	assert_int(live.apply_action("act")).is_not_equal(ERR_LOCKED)
	assert_int(_new_ended_model().advance_turn()).is_equal(ERR_LOCKED)


func test_turn_finished_receiver_sees_the_end_as_settled() -> void:
	# turn_finished の受け手の時点で、終了は確定している。
	var model := _new_model()
	model.add_victory_condition("rich", "population >= 110")
	model.advance_turn()
	assert_int(model.step()).is_equal(ERR_LOCKED)


# --- 基準6：条件の式の評価に失敗したら、ターン全体を取り消す。ゲームは終わらない ---

func _new_failing_model() -> SimModel:
	# t は毎ターン 1 増える。ターン 2 の判定で「1 / (t - 2)」が 0 除算になる。
	var model := SimModel.new()
	model.add_stock("t", 0.0)
	model.add_stock("out", 0.0)
	model.add_constant("price", 1.0)
	model.add_flow("tick", "", "t", 1.0)
	model.add_flow_expr("income", "", "out", "price")
	model.add_victory_condition("sure_win", "t >= 100")
	model.add_defeat_condition("bad", "1 / (t - 2) > 5")
	return model


func _failing_state(model: SimModel) -> String:
	return "%s|%s|%s|%d|%s" % [model.get_stock("t").value, model.get_stock("out").value, model.get_constant("price").value, model.get_turn(), model.get_result().outcome]


func test_judge_failure_cancels_whole_turn() -> void:
	var model := _new_failing_model()
	assert_int(model.advance_turn()).is_equal(OK)
	var before := _failing_state(model)
	model.turn_finished.connect(_on_turn_finished)
	model.game_ended.connect(_on_game_ended)
	_log.clear()
	var code := model.advance_turn()
	model.turn_finished.disconnect(_on_turn_finished)
	model.game_ended.disconnect(_on_game_ended)
	assert_int(code).is_equal(FAILED)
	assert_str(model.last_error).contains("ターン 2")
	assert_str(model.last_error).contains("敗北条件")
	assert_str(model.last_error).contains("bad")
	assert_str(model.last_error).contains("取り消した")
	assert_str(_failing_state(model)).is_equal(before)
	assert_array(_log).is_empty()
	assert_bool(model.is_ended()).is_false()


func test_judge_failure_does_not_end_even_if_other_condition_met() -> void:
	# 成り立つ勝利条件が先にあっても、後ろの条件の評価に失敗したらターン全体を取り消す（全条件を評価する）。
	var model := SimModel.new()
	model.add_stock("t", 0.0)
	model.add_stock("zero", 0.0)
	model.add_flow("tick", "", "t", 1.0)
	model.add_victory_condition("met", "t >= 1")
	model.add_defeat_condition("broken", "1 / zero > 1")
	assert_int(model.advance_turn()).is_equal(FAILED)
	assert_bool(model.is_ended()).is_false()
	assert_int(model.get_turn()).is_equal(0)
	assert_float(model.get_stock("t").value).is_equal(0.0)


func test_judge_failure_restores_validated_and_rng() -> void:
	var model := _new_failing_model()
	model.set_seed(7)
	model.advance_turn()
	# 定数を変えるアクション（組み立て直しが要る状態にする）。
	model.add_action("raise", "1", ["price = 5"])
	model.add_action("fix", "1", ["t = 10"])
	model.apply_action("raise")
	var rng_state := model.get_rng().state
	assert_int(model.advance_turn()).is_equal(FAILED)
	assert_int(model.get_rng().state).is_equal(rng_state)
	assert_float(model.get_stock("out").value).is_equal(1.0)
	assert_float(model.get_constant("price").value).is_equal(5.0)
	# 失敗の原因を取り除くと、新しい定数で流れが計算される（取り消しの後も組み立てが正しい）。
	model.apply_action("fix")
	assert_int(model.advance_turn()).is_equal(OK)
	assert_float(model.get_stock("out").value).is_equal(6.0)
	assert_int(model.get_turn()).is_equal(2)


func test_judge_non_finite_value_cancels_turn() -> void:
	var model := SimModel.new()
	model.add_stock("big", 1.7e308)
	model.add_stock("a", 0.0)
	model.add_flow("tick", "", "a", 1.0)
	model.add_defeat_condition("overflow", "big + big > 0")
	assert_int(model.advance_turn()).is_equal(FAILED)
	assert_str(model.last_error).is_not_empty()
	assert_float(model.get_stock("a").value).is_equal(0.0)
	assert_int(model.get_turn()).is_equal(0)
	assert_bool(model.is_ended()).is_false()


func test_flow_failure_does_not_end_game() -> void:
	var model := SimModel.new()
	model.add_stock("a", 1.0)
	model.add_stock("zero", 0.0)
	model.add_flow_expr("bad", "", "a", "1 / zero")
	model.add_defeat_condition("any", "a > 0")
	assert_int(model.advance_turn()).is_equal(FAILED)
	assert_bool(model.is_ended()).is_false()
