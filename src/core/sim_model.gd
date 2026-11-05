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


## ストックを定義する。成功すると OK、同名の定義があると ERR_ALREADY_EXISTS を返す。
func add_stock(stock_name: String, initial_value: float) -> Error:
	if _names.has(stock_name):
		return _fail(ERR_ALREADY_EXISTS, "同名の定義がある：%s" % stock_name)
	_names[stock_name] = true
	_stocks[stock_name] = initial_value
	return OK


## 定数を定義する。成功すると OK、同名の定義があると ERR_ALREADY_EXISTS を返す。
func add_constant(constant_name: String, value: float) -> Error:
	if _names.has(constant_name):
		return _fail(ERR_ALREADY_EXISTS, "同名の定義がある：%s" % constant_name)
	_names[constant_name] = true
	_constants[constant_name] = value
	return OK


## フローを定義する。source は流出元、sink は流入先のストック名で、片方は空文字でもよい。
## 同名の定義は ERR_ALREADY_EXISTS、存在しないストックや両方が空の場合は ERR_INVALID_PARAMETER を返す。
func add_flow(flow_name: String, source: String, sink: String, amount: float) -> Error:
	if _names.has(flow_name):
		return _fail(ERR_ALREADY_EXISTS, "同名の定義がある：%s" % flow_name)
	if source.is_empty() and sink.is_empty():
		return _fail(ERR_INVALID_PARAMETER, "流出元と流入先の両方が無いフロー：%s" % flow_name)
	if not source.is_empty() and not _stocks.has(source):
		return _fail(ERR_INVALID_PARAMETER, "存在しない流出元のストック：%s" % source)
	if not sink.is_empty() and not _stocks.has(sink):
		return _fail(ERR_INVALID_PARAMETER, "存在しない流入先のストック：%s" % sink)
	_names[flow_name] = true
	_flows.append({"name": flow_name, "source": source, "sink": sink, "amount": amount})
	return OK


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


## ストックの現在の値を返す。未定義の名前では last_error を設定し、NAN を返す。
func get_stock(stock_name: String) -> float:
	if not _stocks.has(stock_name):
		_fail(ERR_DOES_NOT_EXIST, "未定義のストック：%s" % stock_name)
		return NAN
	return _stocks[stock_name]


## ストックが定義されているかを返す。
func has_stock(stock_name: String) -> bool:
	return _stocks.has(stock_name)


## 定数の値を返す。未定義の名前では last_error を設定し、NAN を返す。
func get_constant(constant_name: String) -> float:
	if not _constants.has(constant_name):
		_fail(ERR_DOES_NOT_EXIST, "未定義の定数：%s" % constant_name)
		return NAN
	return _constants[constant_name]


## 現在のターン番号を返す。初期状態は 0 である。
func get_turn() -> int:
	return _turn


## 定義済みのストック名を、定義順に返す。
func get_stock_names() -> Array[String]:
	var result: Array[String] = []
	for stock_name: String in _stocks:
		result.append(stock_name)
	return result


func _fail(code: Error, message: String) -> Error:
	last_error = message
	return code
