## SimModel の advance_turn() と set_seed() のテスト。シーンを使わない。
class_name SimModelTurnTest
extends GdUnitTestSuite


## advance_turn() の呼び出しを数える SimModel。
class CountingModel:
	extends SimModel

	var advance_calls: int = 0

	func advance_turn() -> Error:
		advance_calls += 1
		return super.advance_turn()


func _model() -> SimModel:
	var model := SimModel.new()
	model.add_stock("A", 10.0)
	model.add_stock("B", 0.0)
	model.add_flow("a_to_b", "A", "B", 3.0)
	return model


## advance_turn() は step() と同じ結果になる（値・ターン番号・戻り値）。
func test_advance_turn_matches_step() -> void:
	var by_step := _model()
	var by_advance := _model()
	for i in 4:
		assert_int(by_advance.advance_turn()).is_equal(by_step.step())
	assert_int(by_advance.get_turn()).is_equal(4)
	assert_float(by_advance.get_stock("A").value).is_equal(by_step.get_stock("A").value)
	assert_float(by_advance.get_stock("B").value).is_equal(by_step.get_stock("B").value)


## advance_turn() の失敗は、step() の失敗と同じ形で返る（ストックもターンも変わらない）。
func test_advance_turn_failure_is_same_as_step() -> void:
	var model := SimModel.new()
	model.add_stock("A", 1.0)
	model.add_stock("B", 0.0)
	model.add_flow_expr("bad", "A", "B", "1 / 0")
	assert_int(model.advance_turn()).is_equal(FAILED)
	assert_int(model.get_turn()).is_equal(0)
	assert_str(model.last_error).contains("ターン 1")


## turn_finished は advance_turn() でも発火する。
func test_advance_turn_emits_turn_finished() -> void:
	var model := _model()
	var turns: Array[int] = []
	model.turn_finished.connect(func(turn: int) -> void: turns.append(turn))
	model.advance_turn()
	assert_array(turns).is_equal([1])


## テキスト版は、ターンを進めるのに advance_turn() を呼ぶ。
func test_text_player_calls_advance_turn() -> void:
	var model := CountingModel.new()
	model.add_stock("A", 10.0)
	model.add_flow("out", "A", "", 1.0)
	var io := BufferTextPlayIO.new(["", "", "q"] as Array[String])
	TextPlayer.new(model, io).run()
	assert_int(model.advance_calls).is_equal(2)
	assert_int(model.get_turn()).is_equal(2)


## set_seed() の種は get_seed() で読め、既定は 0 である。
func test_set_seed_is_recorded() -> void:
	var model := SimModel.new()
	assert_int(model.get_seed()).is_equal(0)
	model.set_seed(12345)
	assert_int(model.get_seed()).is_equal(12345)
	model.set_seed(-7)
	assert_int(model.get_seed()).is_equal(-7)


## 同じ種なら同じ乱数列、違う種なら違う乱数列になる。種を決め直すと、列の先頭に戻る。
func test_set_seed_makes_rng_reproducible() -> void:
	var a := SimModel.new()
	var b := SimModel.new()
	a.set_seed(42)
	b.set_seed(42)
	var first: Array[int] = []
	for i in 5:
		first.append(a.get_rng().randi())
		assert_int(b.get_rng().randi()).is_equal(first[i])
	a.set_seed(42)
	assert_int(a.get_rng().randi()).is_equal(first[0])
	b.set_seed(43)
	assert_int(b.get_rng().randi()).is_not_equal(first[0])


## 種に int の端の値を渡しても落ちない。
func test_set_seed_accepts_extreme_ints() -> void:
	var model := SimModel.new()
	for value: int in [0, -1, 9223372036854775807, -9223372036854775808]:
		model.set_seed(value)
		assert_int(model.get_seed()).is_equal(value)
		assert_int(model.get_rng().randi()).is_greater_equal(0)
