## 自動実行の入口のテスト用。引数が要る build()。
extends RefCounted


func build(_required: int) -> SimModel:
	return SimModel.new()
