## AutoRunner のテスト。シーンを使わない。
class_name AutoRunnerTest
extends GdUnitTestSuite


## advance_turn() の呼び出しを数える SimModel。
class CountingModel:
	extends SimModel

	var advance_calls: int = 0

	func advance_turn() -> Error:
		advance_calls += 1
		return super.advance_turn()


func _model(model: SimModel = null) -> SimModel:
	var result: SimModel = model if model != null else SimModel.new()
	result.add_stock("A", 10.0)
	result.add_stock("B", 0.5)
	result.add_flow("a_to_b", "A", "B", 3.0)
	return result


## 結果の表はターン0を含み、行の数は N+1、列はストックの数である。ターン0は初期値である。
func test_table_includes_turn_zero() -> void:
	var result := AutoRunner.new().run(_model(), 4)
	assert_bool(result.is_ok()).is_true()
	assert_array(result.stock_names).is_equal(["A", "B"])
	assert_int(result.rows.size()).is_equal(5)
	assert_array(result.rows[0]).is_equal(PackedFloat64Array([10.0, 0.5]))
	assert_array(result.rows[1]).is_equal(PackedFloat64Array([7.0, 3.5]))
	assert_array(result.rows[4]).is_equal(PackedFloat64Array([-2.0, 12.5]))
	assert_int(result.turns_completed).is_equal(4)
	assert_int(result.turns_requested).is_equal(4)


## 自動実行は advance_turn() を N 回呼ぶ。
func test_run_calls_advance_turn() -> void:
	var model := _model(CountingModel.new()) as CountingModel
	AutoRunner.new().run(model, 7)
	assert_int(model.advance_calls).is_equal(7)
	assert_int(model.get_turn()).is_equal(7)


## シードは model.set_seed() に渡り、結果に残る。
func test_seed_is_passed_and_recorded() -> void:
	var model := _model()
	var result := AutoRunner.new().run(model, 1, 987654321)
	assert_int(model.get_seed()).is_equal(987654321)
	assert_int(result.seed).is_equal(987654321)
	assert_int(AutoRunner.new().run(_model(), 1).seed).is_equal(0)


## N は 1 以上 100000 以下。範囲の外は、何も実行せずに Error にする。
func test_turns_out_of_range_is_rejected_before_running() -> void:
	for turns: int in [0, -1, AutoRunner.MAX_TURNS + 1, 9223372036854775807, -9223372036854775808]:
		var model := _model(CountingModel.new()) as CountingModel
		var result := AutoRunner.new().run(model, turns)
		assert_int(result.error).override_failure_message(str(turns)).is_equal(ERR_INVALID_PARAMETER)
		assert_int(model.advance_calls).is_equal(0)
		assert_int(result.rows.size()).is_equal(0)
		assert_str(result.message).is_not_empty()


## N の上限ちょうど（100000）は実行できる。
func test_max_turns_runs() -> void:
	var model := SimModel.new()
	model.add_stock("A", 0.0)
	model.add_flow("in", "", "A", 1.0)
	var result := AutoRunner.new().run(model, AutoRunner.MAX_TURNS)
	assert_bool(result.is_ok()).is_true()
	assert_int(result.rows.size()).is_equal(AutoRunner.MAX_TURNS + 1)
	assert_float(result.rows[AutoRunner.MAX_TURNS][0]).is_equal(100000.0)


## （N+1）×ストックの数が 1,000,000 を超える指定は、実行の前に Error にする。ちょうど 1,000,000 は通る。
func test_cell_limit_is_checked_before_running() -> void:
	assert_str(AutoRunner.check_request(99999, 10)).is_empty()
	assert_str(AutoRunner.check_request(100000, 10)).is_not_empty()
	assert_str(AutoRunner.check_request(1, 500000)).is_empty()
	assert_str(AutoRunner.check_request(1, 500001)).is_not_empty()
	assert_str(AutoRunner.check_request(100000, 9223372036854775807)).is_not_empty()
	var model := CountingModel.new()
	for i in 11:
		model.add_stock("s%d" % i, 1.0)
	var result := AutoRunner.new().run(model, 100000)
	assert_int(result.error).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.advance_calls).is_equal(0)
	assert_int(model.get_turn()).is_equal(0)


## モデルが無いとき、Error にする。
func test_null_model() -> void:
	var result := AutoRunner.new().run(null, 3)
	assert_int(result.error).is_equal(ERR_INVALID_PARAMETER)


## 実行時エラーで止まったら、そのターンまでの表と理由を返す。ストックはそのターンの前の値のままである。
func test_stops_at_runtime_error_with_partial_table() -> void:
	var model := SimModel.new()
	model.add_stock("a", 3.0)
	model.add_stock("b", 0.0)
	model.add_flow("drain", "a", "", 1.0)
	model.add_flow_expr("bad", "", "b", "1 / a")
	var result := AutoRunner.new().run(model, 10)
	assert_int(result.error).is_equal(FAILED)
	assert_int(result.turns_completed).is_equal(3)
	assert_int(result.rows.size()).is_equal(4)
	assert_str(result.message).contains("ターン 4")
	assert_str(result.message).contains("0 で割った")
	var csv := result.to_csv()
	assert_bool(csv.contains("0 で割った")).is_false()
	assert_int(csv.split("\r\n").size()).is_equal(6)


## 足して溢れるモデルは、そのターンで止まる。共有一覧の組を流す。
func test_overflow_stops_the_run() -> void:
	for pair: Array in HostileValues.overflow_pairs():
		var model := SimModel.new()
		model.add_stock("a", pair[0])
		model.add_flow("grow", "", "a", pair[1])
		var result := AutoRunner.new().run(model, 3)
		assert_int(result.error).is_equal(FAILED)
		assert_int(result.rows.size()).is_equal(1)
		assert_int(result.turns_completed).is_equal(0)
		assert_int(result.message.length()).is_less_equal(ModelCheck.MAX_LAST_ERROR_LENGTH)
		assert_str(HostileValues.find_raw_invisible(result.message)).is_empty()


## 敵対的な名前のストックでも、理由と見出しに生の不可視文字が残らない。
func test_hostile_stock_names() -> void:
	var all := HostileValues.strings()
	for label: String in all:
		var model := SimModel.new()
		if model.add_stock(all[label], 1e308) != OK:
			continue
		var result := AutoRunner.new().run(model, 2)
		assert_bool(result.is_ok()).override_failure_message(label).is_true()
		assert_str(HostileValues.find_raw_invisible(result.to_csv().replace(CsvFormat.LINE_END, ""))).override_failure_message(label).is_empty()


## 同じモデル・同じシード・同じ N なら、表は同じである。
func test_same_input_gives_same_csv() -> void:
	var first := AutoRunner.new().run(_model(), 25, 5).to_csv()
	var second := AutoRunner.new().run(_model(), 25, 5).to_csv()
	assert_str(first).is_equal(second)
