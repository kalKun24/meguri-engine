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


## 成功したかを返す。
func is_ok() -> bool:
	return error == OK


## 表を CSV の文字列にする。失敗した結果でも、そこまでの表を出す。理由は含めない。
func to_csv() -> String:
	return CsvFormat.format_table(stock_names, rows)
