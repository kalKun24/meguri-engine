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

## TownModel と同じ内容のフロー（名前, 流出元, 流入先, 式）。定義順は TownModel と同じ。
## 補助変数 deficit の展開は、TownModel の build() と同じ文字列にしてある。
const DEFICIT: String = "max(0, population * ration - food)"


# 町の初期値のパラメータ。DEFAULT_PARAMS から、ストックと定数を取り出す。
func _flows_in_town_order() -> Array[Array]:
	return [
		["births", "", "population", "population * birth_rate"],
		["deaths", "population", "", "population * death_rate + starvation_rate * %s" % DEFICIT],
		["production", "", "food", "productivity * min(population, farmland)"],
		["consumption", "food", "", "min(food, population * ration)"],
		["taxes", "", "money", "population * tax_rate"],
		["expenses", "money", "", "min(money, population * upkeep + relief_cost * %s)" % DEFICIT],
	]


# overrides を反映した町を組み立てる。
func _build_town(overrides: Dictionary) -> SimModel:
	var town := TownModel.new()
	var model: SimModel = town.build(overrides)
	assert_object(model).is_not_null()
	return model


# フローの定義順を逆にして、TownModel と同じ値のストック・定数から組み直す。
func _build_reversed(overrides: Dictionary) -> SimModel:
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
	var flows := _flows_in_town_order()
	flows.reverse()
	for flow: Array in flows:
		assert_int(model.add_flow_expr(flow[0], flow[1], flow[2], flow[3])).is_equal(OK)
	assert_int(model.validate()).is_equal(OK)
	return model


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


func test_reversed_flow_order_is_exactly_equal_to_the_town_order() -> void:
	for overrides: Dictionary in [{}, {"food": 0.0}]:
		var forward := _run(_build_town(overrides))
		var reversed := _run(_build_reversed(overrides))
		assert_array(reversed).is_equal(forward)


# テストで組み直した式が、TownModel の式と一致することを確かめる。
# 一致しないと、逆順のテストが別のモデルを確かめていることになる。
# 公開の取得関数が無いので、SimModel の内部の _flows を get() で読む。
func test_rebuilt_flows_match_the_town_model_flows() -> void:
	var town_flows: Array = _build_town({}).get("_flows")
	var expected := _flows_in_town_order()
	assert_int(town_flows.size()).is_equal(expected.size())
	for i in range(expected.size()):
		var flow: Dictionary = town_flows[i]
		assert_str(flow["name"]).is_equal(expected[i][0])
		assert_str(flow["source"]).is_equal(expected[i][1])
		assert_str(flow["sink"]).is_equal(expected[i][2])
		assert_str(flow["expression"]).is_equal(expected[i][3])
	var reversed_flows: Array = _build_reversed({}).get("_flows")
	assert_int(reversed_flows.size()).is_equal(expected.size())
	for i in range(expected.size()):
		var flow: Dictionary = reversed_flows[i]
		var original: Array = expected[expected.size() - 1 - i]
		assert_str(flow["name"]).is_equal(original[0])
		assert_str(flow["expression"]).is_equal(original[3])
