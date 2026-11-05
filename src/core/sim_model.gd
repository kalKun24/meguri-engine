## ストック・フロー・定数を持ち、1ターンずつ一斉に更新するシミュレーションのコア。
## Node に依存しない。定義の読み込みはこのクラスの外で行い、add_* 関数を呼ぶ。
class_name SimModel
extends RefCounted

## step() で、すべてのストックへの反映が終わった後に発火する。turn は増えた後のターン番号である。
signal turn_finished(turn: int)

## 直近の定義・取得で起きたエラーの説明。エラーが無ければ空である。
var last_error: String = ""

var _stocks: Dictionary = {}
var _flows: Array[Dictionary] = []
var _constants: Dictionary = {}
var _names: Dictionary = {}
var _turn: int = 0


## ストックを定義する。成功すると OK を返し、last_error を空にする。
## 名前が空、または ModelCheck.MAX_NAME_LENGTH（64 文字）を超える、初期値が NaN・無限大のときは ERR_INVALID_PARAMETER を返す。
## 定義の個数が ModelCheck.MAX_DEFINITIONS（1000 個。ストック・定数・フローの合計）に達していると ERR_OUT_OF_MEMORY を返す。
## 同名の定義があると ERR_ALREADY_EXISTS を返す。失敗のとき、モデルは変わらない。
func add_stock(stock_name: String, initial_value: float) -> Error:
	var error := _check_new_name(stock_name, "ストック名")
	if error != OK:
		return error
	var problem := ModelCheck.check_finite(initial_value, "ストック「%s」の初期値" % ModelCheck.escape(stock_name))
	if not problem.is_empty():
		return _fail(ERR_INVALID_PARAMETER, problem)
	_names[stock_name] = true
	_stocks[stock_name] = initial_value
	return _succeed()


## 定数を定義する。成功すると OK を返し、last_error を空にする。
## エラーの条件は add_stock と同じである（値が NaN・無限大のときも ERR_INVALID_PARAMETER）。
func add_constant(constant_name: String, value: float) -> Error:
	var error := _check_new_name(constant_name, "定数名")
	if error != OK:
		return error
	var problem := ModelCheck.check_finite(value, "定数「%s」の値" % ModelCheck.escape(constant_name))
	if not problem.is_empty():
		return _fail(ERR_INVALID_PARAMETER, problem)
	_names[constant_name] = true
	_constants[constant_name] = value
	return _succeed()


## フローを定義する。source は流出元、sink は流入先のストック名で、片方は空文字でもよい。
## 成功すると OK を返し、last_error を空にする。
## ERR_INVALID_PARAMETER：フロー名が空または長すぎる、amount が NaN・無限大、存在しないストックを指す、流出元と流入先の両方が空。
## ERR_OUT_OF_MEMORY：定義の個数が上限（ModelCheck.MAX_DEFINITIONS）に達している。ERR_ALREADY_EXISTS：同名の定義がある。
func add_flow(flow_name: String, source: String, sink: String, amount: float) -> Error:
	var error := _check_new_name(flow_name, "フロー名")
	if error != OK:
		return error
	var escaped := ModelCheck.escape(flow_name)
	var problem := ModelCheck.check_finite(amount, "フロー「%s」の量" % escaped)
	if not problem.is_empty():
		return _fail(ERR_INVALID_PARAMETER, problem)
	if source.is_empty() and sink.is_empty():
		return _fail(ERR_INVALID_PARAMETER, "流出元と流入先の両方が無いフロー：%s" % escaped)
	if not source.is_empty() and not _stocks.has(source):
		return _fail(ERR_INVALID_PARAMETER, "存在しない流出元のストック：%s" % ModelCheck.escape(source))
	if not sink.is_empty() and not _stocks.has(sink):
		return _fail(ERR_INVALID_PARAMETER, "存在しない流入先のストック：%s" % ModelCheck.escape(sink))
	_names[flow_name] = true
	_flows.append({"name": flow_name, "source": source, "sink": sink, "amount": amount})
	return _succeed()


## 1ターン進める。すべてのフローの量を更新前の値から求め、ストックに一斉に反映する。
func step() -> void:
	var deltas: Dictionary = {}
	for flow: Dictionary in _flows:
		var amount: float = flow["amount"]
		if flow["source"] != "":
			deltas[flow["source"]] = deltas.get(flow["source"], 0.0) - amount
		if flow["sink"] != "":
			deltas[flow["sink"]] = deltas.get(flow["sink"], 0.0) + amount
	for stock_name: String in deltas:
		_stocks[stock_name] += deltas[stock_name]
	_turn += 1
	turn_finished.emit(_turn)


## ストックの現在の値を SimValue で返す。成功か失敗かは result.error で、値は result.value で受け取る。
## 未定義の名前は ERR_DOES_NOT_EXIST、空の名前は ERR_INVALID_PARAMETER になり、last_error に理由を入れる。
## 成功すると last_error を空にする。失敗のとき value は 0.0 で、NAN は返さない。
func get_stock(stock_name: String) -> SimValue:
	return _lookup(_stocks, stock_name, "ストック")


## ストックが定義されているかを返す。
func has_stock(stock_name: String) -> bool:
	return _stocks.has(stock_name)


## 定数の値を SimValue で返す。形とエラーは get_stock と同じである。
func get_constant(constant_name: String) -> SimValue:
	return _lookup(_constants, constant_name, "定数")


## 現在のターン番号を返す。初期状態は 0 である。
func get_turn() -> int:
	return _turn


## 定義済みのストック名を、定義順に返す。
func get_stock_names() -> Array[String]:
	var result: Array[String] = []
	for stock_name: String in _stocks:
		result.append(stock_name)
	return result


func _lookup(table: Dictionary, key: String, what: String) -> SimValue:
	if key.is_empty():
		_fail(ERR_INVALID_PARAMETER, "%s名が空である" % what)
		return SimValue.new(ERR_INVALID_PARAMETER)
	if not table.has(key):
		_fail(ERR_DOES_NOT_EXIST, "未定義の%s：%s" % [what, ModelCheck.escape(key)])
		return SimValue.new(ERR_DOES_NOT_EXIST)
	_succeed()
	return SimValue.new(OK, table[key])


## 新しい定義の名前を検査する。問題が無ければ OK を返す（last_error は変えない）。
func _check_new_name(name_value: String, what: String) -> Error:
	var problem := ModelCheck.check_name(name_value, what)
	if not problem.is_empty():
		return _fail(ERR_INVALID_PARAMETER, problem)
	if _names.size() >= ModelCheck.MAX_DEFINITIONS:
		return _fail(ERR_OUT_OF_MEMORY, "定義の個数が上限（%d）に達している" % ModelCheck.MAX_DEFINITIONS)
	if _names.has(name_value):
		return _fail(ERR_ALREADY_EXISTS, "同名の定義がある：%s" % ModelCheck.escape(name_value))
	return OK


func _succeed() -> Error:
	last_error = ""
	return OK


func _fail(code: Error, message: String) -> Error:
	last_error = message
	return code
