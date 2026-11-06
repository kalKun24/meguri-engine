## 自動実行の入口のテスト用。CSV の見出しで注意が要る名前のストックを持つモデル。
## 不可視文字は char() で作る。
extends RefCounted


func build() -> SimModel:
	var model := SimModel.new()
	var names: Array[String] = [
		"=cmd",
		"+1",
		"-1",
		"@sum",
		"a,b",
		"x\"y",
		"rtl" + char(0x202E) + "end",
		"line" + char(0x0A) + "break",
	]
	for stock_name in names:
		model.add_stock(stock_name, 1.5)
	return model
