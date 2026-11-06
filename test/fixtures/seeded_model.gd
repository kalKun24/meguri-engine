## 自動実行の入口のテスト用。毎ターン、モデルの乱数（get_rng）の値を noise に足すモデル。
## シードが入口から set_seed を通ってモデルに届くことを確かめるために使う（乱数を使う本物の処理は #34 から）。
extends RefCounted


## advance_turn() のあとに、モデルの乱数を使うモデル。
class NoisyModel:
	extends SimModel

	func advance_turn() -> Error:
		var code := super.advance_turn()
		if code == OK:
			_stocks["noise"] = float(_stocks["noise"]) + get_rng().randf()
		return code


func build() -> SimModel:
	var model := NoisyModel.new()
	model.add_stock("noise", 0.0)
	return model
