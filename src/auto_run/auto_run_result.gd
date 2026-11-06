## AutoRunner.run() の結果。実行の記録（種・要求したターン数・進んだターン数）と、結果の表を持つ。
class_name AutoRunResult
extends RefCounted

## 成功なら OK。引数が不正なら ERR_INVALID_PARAMETER。実行時エラーで止まったなら、そのターンの advance_turn() の戻り値（FAILED など）である。
var error: Error = OK
## 失敗の理由。成功なら空である。エスケープ済みで、ModelCheck.MAX_LAST_ERROR_LENGTH 文字までである。
var message: String = ""
## 実行に使った種（set_seed に渡した値）。
var seed: int = 0
## 要求したターン数 N。
var turns_requested: int = 0
## 実際に進んだターン数。成功なら turns_requested と同じである。
var turns_completed: int = 0
## 列の順に並ぶストック名。
var stock_names: Array[String] = []
## 結果の表。rows[t] は、ターン t のすべてのストックの値（stock_names の順）である。ターン 0 を含む。
## 失敗したときは、止まる前のターンまでが入る。
var rows: Array[PackedFloat64Array] = []


## ゲームが終わって止まったときの結果（GameResult の写し）。N ターンを回し切ったときは、種類が未決（OUTCOME_PENDING）である。
## 終わって止まったときも error は OK で、turns_completed は終わったターンと同じ（turns_requested より小さいことがある）。
var game_result: GameResult = GameResult.new()


## ゲームが N に達する前か N ちょうどで終わって、そこで止まったかを返す。
func is_game_ended() -> bool:
	return game_result.is_ended()


## 終わった理由を1行にして返す。終わっていなければ空文字を返す。標準エラーに出す文である。
## 条件の名前は、エスケープして省いた形で入れる。
func describe_end() -> String:
	if not game_result.is_ended():
		return ""
	return "ゲームが終わった：%s（条件「%s」、ターン %d、要求 %d ターン、シード：%d）" % [
		game_result.outcome_label(), ModelCheck.escape(game_result.condition_name), game_result.turn, turns_requested, seed
	]


## 成功したかを返す。
func is_ok() -> bool:
	return error == OK


## 表を CSV の文字列にする。失敗した結果でも、そこまでの表を出す。理由は含めない。
func to_csv() -> String:
	return CsvFormat.format_table(stock_names, rows)
