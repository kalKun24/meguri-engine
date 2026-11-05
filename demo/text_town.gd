## テキスト版の小さな町。Enter で次のターンに進み、番号か名前でアクションを選び、q か EOF で終わる。
## 実行：godot --headless --path . -s res://demo/text_town.gd
extends SceneTree


func _init() -> void:
	var builder := TownModel.new()
	var model := builder.build()
	if model == null:
		print("町を組み立てられない：%s" % builder.last_error)
		quit(1)
		return
	var player := TextPlayer.new(model, StdioTextPlayIO.new(), TownModel.LABELS, TownModel.ACTION_LABELS, TownModel.PARAM_LABELS)
	var code := player.run()
	quit(0 if code == OK else 1)
