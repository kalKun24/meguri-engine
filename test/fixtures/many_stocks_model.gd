## 自動実行の入口のテスト用。ストックが 11 個あるモデル。N = 100000 だと（N+1）×11 が 1,000,000 を超える。
extends RefCounted


func build() -> SimModel:
	var model := SimModel.new()
	for i in 11:
		model.add_stock("s%d" % i, 1.0)
	return model
