## プレイヤーなしで N ターン回して CSV を出す入口。引数の意味は AutoRunCli に書いてある。
## 実行：godot --headless --no-header --path . -s res://src/auto_run/auto_run_main.gd -- --model=res://src/sample/town_model.gd --turns=30 --seed=1
## --no-header を付けないと、標準出力の先頭に Godot のバナーが出て、CSV に混ざる。
extends SceneTree


func _init() -> void:
	quit(AutoRunCli.new().execute(OS.get_cmdline_user_args()))
