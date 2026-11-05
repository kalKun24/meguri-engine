## 「小さな町」の仮モデルを組み立てる。モデルの定義形式は M2 で決めるため、いまは GDScript のコードで書く。
## コア（SimModel など）はこのクラスを参照しない。形式が決まったら、このクラスごと読み込み部分に置き換える。
##
## ストック：population（人口）、food（食料）、money（お金）。
## フロー：births・deaths（人口）、production・consumption（食料）、taxes・expenses（お金）。
##
## 補助変数（#11）がまだ無いので、「食料の不足分」max(0, population * ration - food) を、
## deaths と consumption と expenses の式に繰り返して書いている。
## TODO: #11 の後で、補助変数 deficit に書き直す。
## 食料やお金が負にならないよう、いまは式で防いでいる（consumption と expenses の min）。
## TODO: 上限・下限の PBI が終わった後に、ストックの下限の設定へ書き換える。
class_name TownModel
extends RefCounted

## ストック名から、表示に使う名前への対応。定義順に並べる。
const LABELS: Dictionary = {
	"population": "人口",
	"food": "食料",
	"money": "お金",
}

## 既定のパラメータ。初期値と定数の両方を含む。理由は報告に書いた。
const DEFAULT_PARAMS: Dictionary = {
	# 初期値
	"population": 100.0,
	"food": 120.0,
	"money": 100.0,
	# 定数
	"birth_rate": 0.08,  # 毎ターンの出生率。人口がまず伸びる。
	"death_rate": 0.02,  # 毎ターンの自然な死亡率。
	"starvation_rate": 0.5,  # 食料の不足 1 あたりに増える死者。大きいほど飢えが効く。
	"farmland": 100.0,  # 食料を作れる人数の上限。これを超えた人口は生産を増やさない。
	"productivity": 1.0,  # 働く 1 人あたりの食料の生産量。
	"ration": 1.0,  # 1 人あたりの毎ターンの消費量。
	"tax_rate": 0.3,  # 1 人あたりの税収。
	"upkeep": 0.2,  # 1 人あたりの町の維持費。
	"relief_cost": 0.4,  # 食料の不足 1 あたりの救援費。
}

## 直近の build() の失敗の説明。成功したら空である。
var last_error: String = ""


## 仮モデルを組み立てて返す。overrides で、DEFAULT_PARAMS の値を差し替えられる（食料が不足する設定を作るときなど）。
## 組み立てに失敗したら null を返し、last_error に理由を入れる。overrides に未知の名前があっても失敗にする。
func build(overrides: Dictionary = {}) -> SimModel:
	last_error = ""
	var params: Dictionary = DEFAULT_PARAMS.duplicate()
	for key: Variant in overrides:
		if not params.has(key):
			last_error = "未知のパラメータ：%s" % ModelCheck.escape(str(key), 0)
			return null
		params[key] = overrides[key]

	var model := SimModel.new()
	for stock_name: String in LABELS:
		if not _check(model.add_stock(stock_name, params[stock_name]), model):
			return null
	for constant_name: String in DEFAULT_PARAMS:
		if LABELS.has(constant_name):
			continue
		if not _check(model.add_constant(constant_name, params[constant_name]), model):
			return null

	var deficit := "max(0, population * ration - food)"
	var flows: Array[Array] = [
		["births", "", "population", "population * birth_rate"],
		["deaths", "population", "", "population * death_rate + starvation_rate * %s" % deficit],
		["production", "", "food", "productivity * min(population, farmland)"],
		["consumption", "food", "", "min(food, population * ration)"],
		["taxes", "", "money", "population * tax_rate"],
		["expenses", "money", "", "min(money, population * upkeep + relief_cost * %s)" % deficit],
	]
	for flow: Array in flows:
		if not _check(model.add_flow_expr(flow[0], flow[1], flow[2], flow[3]), model):
			return null
	if not _check(model.validate(), model):
		return null
	return model


func _check(code: Error, model: SimModel) -> bool:
	if code != OK:
		last_error = "%s：%s" % [error_string(code), model.last_error]
		return false
	return true
