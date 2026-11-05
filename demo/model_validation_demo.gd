## 壊れた値を SimModel に渡すと、Error と、制御文字をエスケープした理由が返ることを見るデモ。
## 最後に正しい定義を1つ行い、last_error が空に戻ることを見る。
## 実行：godot --headless --path . -s res://demo/model_validation_demo.gd
extends SceneTree


func _init() -> void:
	var model := SimModel.new()
	var evil := "x" + char(0x0A) + char(0x202E) + "y"
	_show(model, "NaN の初期値", model.add_stock("pop", NAN))
	model.add_stock("pop", 1.0)
	_show(model, "無限大の量", model.add_flow("grow", "", "pop", INF))
	_show(model, "空の名前", model.add_stock("", 1.0))
	model.add_stock(evil, 1.0)
	_show(model, "制御文字を含む名前の重複", model.add_stock(evil, 2.0))
	_show(model, "未定義の名前の取得", model.get_stock("no" + char(0x09) + "pe").error)
	_show(model, "正しい定義", model.add_constant("rate", 0.5))
	print("  last_error が空: %s" % str(model.last_error.is_empty()))
	quit()


func _show(model: SimModel, title: String, error: Error) -> void:
	print("%s -> %s / last_error=\"%s\"" % [title, error_string(error), model.last_error])
