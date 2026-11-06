## ゲームの結果。SimModel.get_result() が返す。種類（勝利・敗北・未決）、満たした条件の名前、終わったターン番号を持つ。
## 呼ぶたびに新しく作られる写しなので、書き換えてもモデルには効かない。
class_name GameResult
extends RefCounted

## 種類を表す文字列。game_ended シグナルの outcome も同じ値である。
const OUTCOME_VICTORY: String = "victory"
const OUTCOME_DEFEAT: String = "defeat"
## まだ終わっていない。
const OUTCOME_PENDING: String = "pending"

## OUTCOME_VICTORY・OUTCOME_DEFEAT・OUTCOME_PENDING のどれか。
var outcome: String = OUTCOME_PENDING
## 終了の決め手になった条件の名前。未決のときは空である。利用者由来の文字列なので、出すときはエスケープする。
var condition_name: String = ""
## 終わったターン番号。未決のときは 0 である。
var turn: int = 0


func _init(outcome_value: String = OUTCOME_PENDING, condition_name_value: String = "", turn_value: int = 0) -> void:
	outcome = outcome_value
	condition_name = condition_name_value
	turn = turn_value


## ゲームが終わっているか（未決でないか）を返す。
func is_ended() -> bool:
	return outcome != OUTCOME_PENDING


## 種類を日本語の言葉（勝利・敗北・未決）で返す。
func outcome_label() -> String:
	match outcome:
		OUTCOME_VICTORY:
			return "勝利"
		OUTCOME_DEFEAT:
			return "敗北"
	return "未決"
