## SimModel を受け取り、プレイヤーなしで N ターン回して、全ストックの値の表を返す。
## Node に依存しない。ターンは advance_turn() で進める。
class_name AutoRunner
extends RefCounted

## ターン数 N の上限。
const MAX_TURNS: int = 100000
## 表のセルの上限（（N+1）× ストックの数）。超える指定は、実行の前に Error にする。
const MAX_CELLS: int = 1000000


## 引数の検査だけを行い、問題があれば理由を、無ければ空文字を返す。実行の前の検査に使う。
static func check_request(turns: int, stock_count: int) -> String:
	if turns < 1 or turns > MAX_TURNS:
		return "ターン数は 1 以上 %d 以下にする（指定：%d）" % [MAX_TURNS, turns]
	# 乗算が溢れないよう、割り算で比べる。
	if stock_count > 0 and turns + 1 > MAX_CELLS / stock_count:
		return "表が大きすぎる（（ターン数 + 1）×ストックの数 が %d 以下になるようにする。ターン数 %d、ストック %d 個）" % [MAX_CELLS, turns, stock_count]
	return ""


## model を turns ターン進め、結果の表を返す。種は model.set_seed() に渡し、結果に残す。
## 引数が不正なら、何も実行せず error = ERR_INVALID_PARAMETER の結果を返す（表は空）。
## 実行時エラー（advance_turn() の失敗）で止まったときは、止まるまでの表を返し、error と message にその理由を入れる。
## 値が NaN・無限大のときも、その時点で止める。
## ゲームが勝利か敗北で終わったときは、N に達する前でも、そこで止まる。error は OK のままで、表の最後の行は終了したターンである。
## 終わった結果は game_result に入る。条件の式の評価に失敗したときは、advance_turn() の失敗として扱う（上と同じ）。
func run(model: SimModel, turns: int, seed_value: int = 0) -> AutoRunResult:
	var result := AutoRunResult.new()
	result.seed = seed_value
	result.turns_requested = turns
	if model == null:
		return _reject(result, "モデルが無い")
	result.stock_names = model.get_stock_names()
	var problem := check_request(turns, result.stock_names.size())
	if not problem.is_empty():
		return _reject(result, problem)
	model.set_seed(seed_value)
	var first := _read_row(model, result)
	if first.error != OK:
		return first
	for turn in range(1, turns + 1):
		var code: Error = model.advance_turn()
		if code != OK:
			# 取得関数は last_error を空にするので、先に取っておく。
			return _stop(result, code, "ターン %d で止まった（%s）：%s" % [turn, error_string(code), model.last_error])
		var stopped := _read_row(model, result)
		if stopped.error != OK:
			return stopped
		result.turns_completed = turn
		# 勝利か敗北で終わったら、N に達していなくても、そこで止まる。最終行は終了したターンである。
		if model.is_ended():
			result.game_result = model.get_result()
			return result
	return result


func _read_row(model: SimModel, result: AutoRunResult) -> AutoRunResult:
	var values := PackedFloat64Array()
	for stock_name in result.stock_names:
		var stock := model.get_stock(stock_name)
		if not stock.is_ok():
			return _stop(result, stock.error, "ストックを読めない（%s）：%s" % [error_string(stock.error), model.last_error])
		var problem := ModelCheck.check_finite(stock.value, "ターン %d のストック「%s」" % [result.rows.size(), ModelCheck.escape(stock_name)])
		if not problem.is_empty():
			return _stop(result, FAILED, problem)
		values.append(stock.value)
	result.rows.append(values)
	return result


func _reject(result: AutoRunResult, message: String) -> AutoRunResult:
	return _stop(result, ERR_INVALID_PARAMETER, message)


func _stop(result: AutoRunResult, code: Error, message: String) -> AutoRunResult:
	result.error = code
	result.message = ModelCheck.limit_last_error(message)
	return result
