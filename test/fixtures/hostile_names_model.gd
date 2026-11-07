## 自動実行の入口のテスト用。CSV の見出しで注意が要る名前のストックを持つモデル。
## 不可視文字は char() で作る。
## add_stock は名前の規則（#22）でこれらの名前を拒否するので、規則を通らないモデル（他の実装が作った状態）を、
## 内部の表へ直接入れて再現する。CSV の見出しの防御（csv_format）を確かめるためである。
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
		model._stocks[stock_name] = 1.5
	return model
