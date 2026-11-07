## 「小さな町」(TownModel) の推移を、ゴールデン値で固定するテスト。シーンを使わない。
##
## 期待値は、extra-review 枠が Python（3.14.4）で独立に計算したものである。
## 出典：https://github.com/kalKun24/meguri-engine/issues/20#issuecomment-6659177879
## 値は repr() の全桁である。実装の出力から写してはならない。
##
## 期待値を変えるときの注意：
##   このテストが失敗したときは、先に「どちらが正しいか」を調べる。
##   町の式や定数、SimModel.step() の計算順序を意図して変えたときに限り、期待値を更新してよい。
##   更新するときは、新しい値を実装の出力から写さず、独立した計算（Python など）で求め直す。
##   そして、変えた理由をコミットメッセージとこのコメントに書く。理由が書けない変更は、退行として扱う。
##
## T2-1 の経路の表：該当なし（新しい外部入力が無い）。
class_name TownGoldenTest
extends GdUnitTestSuite

## Python の値との比較の許容誤差。
## 許容誤差を 0 にすると 3 か所が 1 ulp（約 1.4e-14）ずれる。原因は、Godot が 17 桁の小数の文字列を
## 1 ulp 低い側の double に読むことで、シミュレーションの計算は Python と同じ値になっている。
const TOLERANCE: float = 1e-9

## 追う回数。ターン 0（初期値）からターン 12 まで。
const TURNS: int = 12

## 既定のパラメータの推移。各行は [人口, 食料, お金]。添字がターン番号である。
const GOLDEN_DEFAULT: Array = [
	[100.0, 120.0, 100.0],
	[106.0, 120.0, 110.0],
	[112.36, 114.0, 120.6],
	[119.1016, 101.64, 131.83599999999998],
	[117.516896, 100.0, 136.76152],
	[115.80946176, 100.0, 141.5064512],
	[114.8532985856, 100.0, 146.763612672],
	[114.317847207936, 100.0, 152.30762309632],
	[114.01799443644416, 100.0, 158.0122689339392],
	[113.85007688440872, 100.0, 163.80687060300593],
	[113.75604305526889, 100.0, 169.65184753768332],
	[113.70338411095058, 100.0, 175.52503462110266],
	[113.67389510213232, 100.0, 181.4140193878175],
]

## food=0.0 だけを変えた設定の推移。食料が不足する分岐（deficit > 0）を通る。
const GOLDEN_NO_FOOD: Array = [
	[100.0, 0.0, 100.0],
	[56.0, 100.0, 70.0],
	[59.36, 100.0, 75.6],
	[62.9216, 100.0, 81.536],
	[66.696896, 100.0, 87.82816],
	[70.69870976, 100.0, 94.4978496],
	[74.9406323456, 100.0, 101.567720576],
	[79.437070286336, 100.0, 109.06178381056],
	[84.20329450351616, 100.0, 117.0054908391936],
	[89.25549217372713, 100.0, 125.42582028954521],
	[94.61082170415077, 100.0, 134.35136950691793],
	[100.28747100639981, 100.0, 143.812451677333],
	[106.1609837635839, 100.0, 153.72621037541305],
]

const STOCK_NAMES: Array[String] = ["population", "food", "money"]

## フローと補助変数の定義は TownModel.FLOWS と TownModel.AUXILIARIES を使う。式をこのテストで二重に持たない。
## 期待値（上の GOLDEN_*）は、式を変えても独立に求めた値のままである。


# overrides を反映した町を組み立てる。
func _build_town(overrides: Dictionary) -> SimModel:
	var town := TownModel.new()
	var model: SimModel = town.build(overrides)
	assert_object(model).is_not_null()
	return model


# TownModel と同じ値のストック・定数から、フローと補助変数の定義順だけを変えて組み直す。
# reverse_flows が true ならフローを逆順に、auxiliaries_last が true なら補助変数をフローの後に定義する。
func _build_reordered(overrides: Dictionary, reverse_flows: bool, auxiliaries_last: bool) -> SimModel:
	var params: Dictionary = TownModel.DEFAULT_PARAMS.duplicate()
	for key: Variant in overrides:
		params[key] = overrides[key]
	var model := SimModel.new()
	for stock_name: String in TownModel.LABELS:
		assert_int(model.add_stock(stock_name, params[stock_name])).is_equal(OK)
	for constant_name: String in TownModel.DEFAULT_PARAMS:
		if TownModel.LABELS.has(constant_name):
			continue
		assert_int(model.add_constant(constant_name, params[constant_name])).is_equal(OK)
	if not auxiliaries_last:
		_add_auxiliaries(model)
	var flows: Array = TownModel.FLOWS.duplicate()
	if reverse_flows:
		flows.reverse()
	for flow: Array in flows:
		assert_int(model.add_flow_expr(flow[0], flow[1], flow[2], flow[3])).is_equal(OK)
	if auxiliaries_last:
		_add_auxiliaries(model)
	assert_int(model.validate()).is_equal(OK)
	return model


func _add_auxiliaries(model: SimModel) -> void:
	var auxiliaries: Array = TownModel.AUXILIARIES.duplicate()
	auxiliaries.reverse()
	for auxiliary: Array in auxiliaries:
		assert_int(model.add_auxiliary(auxiliary[0], auxiliary[1])).is_equal(OK)


func _build_reversed(overrides: Dictionary) -> SimModel:
	return _build_reordered(overrides, true, false)


# 12 ターン進めて、ターン 0〜12 の [人口, 食料, お金] を返す。
func _run(model: SimModel) -> Array:
	var rows: Array = []
	rows.append(_snapshot(model))
	for turn in range(1, TURNS + 1):
		assert_int(model.step()).is_equal(OK)
		rows.append(_snapshot(model))
	return rows


func _snapshot(model: SimModel) -> Array:
	var row: Array = []
	for stock_name in STOCK_NAMES:
		row.append(model.get_stock(stock_name).value)
	return row


# 推移を期待値と比べる。ずれたターンとストックを失敗の文に出す。
func _assert_matches_golden(rows: Array, golden: Array, label: String) -> void:
	assert_int(rows.size()).is_equal(golden.size())
	for turn in range(golden.size()):
		for i in range(STOCK_NAMES.size()):
			var actual: float = rows[turn][i]
			var expected: float = golden[turn][i]
			assert_float(actual) \
				.override_failure_message("%s：ターン %d の %s が期待値とずれた（期待 %s、実際 %s、差 %s）" % [
					label, turn, STOCK_NAMES[i], String.num(expected, 17), String.num(actual, 17), String.num(actual - expected, 17)
				]) \
				.is_equal_approx(expected, TOLERANCE)


# --- Python の期待値との一致 ---

func test_default_town_matches_python_golden_values() -> void:
	_assert_matches_golden(_run(_build_town({})), GOLDEN_DEFAULT, "既定")


func test_no_food_town_matches_python_golden_values() -> void:
	_assert_matches_golden(_run(_build_town({"food": 0.0})), GOLDEN_NO_FOOD, "food=0.0")


# --- 再現性 ---

func test_two_runs_in_the_same_environment_are_exactly_equal() -> void:
	for overrides: Dictionary in [{}, {"food": 0.0}]:
		var first := _run(_build_town(overrides))
		var second := _run(_build_town(overrides))
		for turn in range(first.size()):
			for i in range(STOCK_NAMES.size()):
				assert_bool(first[turn][i] == second[turn][i]) \
					.override_failure_message("ターン %d の %s が2回の実行で一致しない：%s と %s" % [
						turn, STOCK_NAMES[i], first[turn][i], second[turn][i]
					]) \
					.is_true()


# --- フローの定義順に依らないこと ---

func test_reversed_flow_order_gives_the_same_golden_values() -> void:
	_assert_matches_golden(_run(_build_reversed({})), GOLDEN_DEFAULT, "逆順・既定")
	_assert_matches_golden(_run(_build_reversed({"food": 0.0})), GOLDEN_NO_FOOD, "逆順・food=0.0")


# 完全一致を求めてよいのは、どのストックにも触れるフローが2本以下のときだけである。
# 0.0 + a + b と 0.0 + b + a は、2 項の足し算が交換できるので同じ値になる。
# 3 本以上になると (a + b) + c と (c + b) + a が 1 ulp ずれうるので、完全一致ではなく許容誤差で比べる。
# この前提を、定義から数えて固定する。補助変数 deficit は流れを持たないので、数は増えない。
func test_exact_equality_premise_each_stock_has_at_most_two_flows() -> void:
	var touching: Dictionary = {}
	for flow: Array in TownModel.FLOWS:
		for stock_name: String in [flow[1], flow[2]]:
			if stock_name != "":
				touching[stock_name] = touching.get(stock_name, 0) + 1
	for stock_name: String in TownModel.LABELS:
		assert_int(touching.get(stock_name, 0)) \
			.override_failure_message("%s に触れるフローが3本以上ある。完全一致のテストを許容誤差に変える" % stock_name) \
			.is_less_equal(2)


func test_reversed_flow_order_is_exactly_equal_to_the_town_order() -> void:
	for overrides: Dictionary in [{}, {"food": 0.0}]:
		var forward := _run(_build_town(overrides))
		var reversed := _run(_build_reversed(overrides))
		assert_array(reversed).is_equal(forward)


# 補助変数を、フローの後に定義しても、結果は変わらない（依存の順は定義の順ではなく、参照で決まる）。
func test_defining_the_auxiliary_after_the_flows_gives_the_same_result() -> void:
	for overrides: Dictionary in [{}, {"food": 0.0}]:
		var forward := _run(_build_town(overrides))
		var late := _run(_build_reordered(overrides, false, true))
		assert_array(late).is_equal(forward)


# TownModel が公開するフローと補助変数の定義が、使えること。
func test_town_model_publishes_flows_and_auxiliaries() -> void:
	assert_int(TownModel.FLOWS.size()).is_equal(6)
	assert_int(TownModel.AUXILIARIES.size()).is_equal(1)
	var names: Array[String] = []
	for flow: Array in TownModel.FLOWS:
		assert_int(flow.size()).is_equal(4)
		names.append(flow[0])
	assert_array(names).is_equal(["births", "deaths", "production", "consumption", "taxes", "expenses"])
	assert_str(TownModel.AUXILIARIES[0][0]).is_equal("deficit")
	# deaths と expenses は、不足分を式に繰り返さず、補助変数 deficit を参照する。
	for flow: Array in TownModel.FLOWS:
		if flow[0] == "deaths" or flow[0] == "expenses":
			assert_str(flow[3]).contains("deficit")
			assert_str(flow[3]).not_contains("ration - food")
