## 自動実行の入口を、実際の godot プロセスとして起動して確かめるテスト（チーム合意 T3-2 の、外から入る境界のテスト）。
## 標準出力と標準エラーは bash でファイルに分けて受け取り、バイト単位で比べる。
## 起動するのはこのテストを動かしている godot 自身（OS.get_executable_path）である。シーンを使わない。
class_name AutoRunProcessTest
extends GdUnitTestSuite

const TOWN: String = "res://src/sample/town_model.gd"
const FIXTURES: String = "res://test/fixtures/"

var _temp_paths: Array[String] = []


func after_test() -> void:
	for path in _temp_paths:
		for file_name in DirAccess.get_files_at(path):
			DirAccess.remove_absolute(path.path_join(file_name))
		DirAccess.remove_absolute(path)
	_temp_paths.clear()


func _temp_dir() -> String:
	var path := OS.get_temp_dir().path_join("meguri_proc_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(path)
	_temp_paths.append(path)
	return path


# godot を起動する。args は -- より後ろの引数である。{"code": int, "stdout": PackedByteArray, "stderr": PackedByteArray} を返す。
# raw_arg_script は、引数の末尾に足す bash の断片である。$'\xff' のような、GDScript の文字列にできないバイト列を含む引数を渡すのに使う。
func _launch(args: Array[String], raw_arg_script: String = "") -> Dictionary:
	var dir := _temp_dir()
	var out_path := dir.path_join("stdout.bin")
	var err_path := dir.path_join("stderr.bin")
	var project := ProjectSettings.globalize_path("res://")
	# 標準出力と標準エラーをファイルに分ける小さな bash のスクリプトを、一時ディレクトリに書いて起動する。
	var runner := dir.path_join("run.sh")
	var file := FileAccess.open(runner, FileAccess.WRITE)
	file.store_string("out=\"$1\"\nerr=\"$2\"\nshift 2\nexec \"$@\" %s >\"$out\" 2>\"$err\"\n" % raw_arg_script)
	file.close()
	var command: Array[String] = [runner, out_path, err_path, OS.get_executable_path(),
		"--headless", "--no-header", "--path", project, "-s", "res://src/auto_run/auto_run_main.gd", "--"]
	command.append_array(args)
	var output: Array = []
	var code := OS.execute("bash", PackedStringArray(command), output, false)
	return {
		"code": code,
		"stdout": FileAccess.get_file_as_bytes(out_path),
		"stderr": FileAccess.get_file_as_bytes(err_path),
	}


func _text(bytes: PackedByteArray) -> String:
	return bytes.get_string_from_utf8()


## サンプルの町を、シードを指定して 30 ターン回す。終了コード 0、標準エラーは空、CSV は見出し + ターン 0〜30 の行である。
func test_town_30_turns_to_stdout() -> void:
	var run := _launch(["--model=" + TOWN, "--turns=30", "--seed=1"])
	assert_int(run["code"]).is_equal(0)
	assert_int(run["stderr"].size()).is_equal(0)
	var lines := _text(run["stdout"]).split("\r\n")
	assert_int(lines.size()).is_equal(33)
	assert_str(lines[0]).is_equal("turn,population,food,money")
	assert_str(lines[1]).is_equal("0,100.0,120.0,100.0")
	assert_str(lines[32]).is_empty()


## 同じ指定で2回起動すると、標準出力はバイト単位で同じである（Godot のバナーも混ざらない）。
func test_same_arguments_give_byte_identical_output() -> void:
	var args: Array[String] = ["--model=" + FIXTURES + "seeded_model.gd", "--turns=50", "--seed=12345"]
	var first := _launch(args)
	var second := _launch(args)
	assert_int(first["code"]).is_equal(0)
	assert_int(first["stdout"].size()).is_greater(100)
	assert_bool(first["stdout"] == second["stdout"]).is_true()
	# シードを変えると変わる（シードが入口からモデルに届いている）。
	var other := _launch(["--model=" + FIXTURES + "seeded_model.gd", "--turns=50", "--seed=12346"])
	assert_bool(first["stdout"] == other["stdout"]).is_false()


## 標準出力の CSV は、--out のファイルと同じバイト列である。--out のときは標準出力に何も出ない。
func test_output_file_matches_stdout() -> void:
	var args: Array[String] = ["--model=" + TOWN, "--turns=20", "--seed=3"]
	var to_stdout := _launch(args)
	var path := _temp_dir().path_join("town.csv")
	var with_out := args.duplicate()
	with_out.append("--out=" + path)
	var to_file := _launch(with_out)
	assert_int(to_file["code"]).is_equal(0)
	assert_int(to_file["stdout"].size()).is_equal(0)
	assert_bool(FileAccess.get_file_as_bytes(path) == to_stdout["stdout"]).is_true()


## 既にあるファイルは上書きされる。
func test_existing_file_is_overwritten() -> void:
	var path := _temp_dir().path_join("town.csv")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("old\n".repeat(5000))
	file.close()
	var run := _launch(["--model=" + TOWN, "--turns=2", "--out=" + path])
	assert_int(run["code"]).is_equal(0)
	assert_str(FileAccess.get_file_as_string(path)).starts_with("turn,population")
	assert_bool(FileAccess.get_file_as_string(path).contains("old")).is_false()


## 親ディレクトリが無いと、終了コード 3、標準エラーに理由、標準出力は空、ファイルもディレクトリもできない。
func test_missing_parent_directory() -> void:
	var path := _temp_dir().path_join("no_such").path_join("town.csv")
	var run := _launch(["--model=" + TOWN, "--turns=2", "--out=" + path])
	assert_int(run["code"]).is_equal(3)
	assert_int(run["stdout"].size()).is_equal(0)
	assert_str(_text(run["stderr"])).contains("ファイルを開けない")
	assert_bool(DirAccess.dir_exists_absolute(path.get_base_dir())).is_false()


## N が上限を超える、0、整数でない：終了コード 2、標準エラーに理由、標準出力は空。
func test_invalid_turns() -> void:
	for value in ["100001", "0", "-3", "abc", "1.5"]:
		var run := _launch(["--model=" + TOWN, "--turns=" + value])
		assert_int(run["code"]).override_failure_message("turns=" + value).is_equal(2)
		assert_int(run["stdout"].size()).is_equal(0)
		assert_str(_text(run["stderr"])).contains("--turns")


## （N+1）×ストックの数が 1,000,000 を超える指定は、実行の前に終了コード 2 になる。
func test_cell_limit() -> void:
	var run := _launch(["--model=" + FIXTURES + "many_stocks_model.gd", "--turns=100000"])
	assert_int(run["code"]).is_equal(2)
	assert_int(run["stdout"].size()).is_equal(0)
	assert_str(_text(run["stderr"])).contains("大きすぎる")


## build の無いクラス、res:// の外、.gd でないものは、終了コード 2 と理由になる。
func test_invalid_model() -> void:
	for model in [FIXTURES + "no_build_model.gd", "/etc/passwd", "res://project.godot", "user://x.gd", "res://nope.gd"]:
		var run := _launch(["--model=" + model, "--turns=3"])
		assert_int(run["code"]).override_failure_message(model).is_equal(2)
		assert_int(run["stdout"].size()).is_equal(0)
		assert_str(_text(run["stderr"])).override_failure_message(model).starts_with("エラー")


## 実行時エラー：終了コード 1。標準出力にはそのターンまでの CSV だけ、理由は標準エラーだけにある。
func test_runtime_error_splits_csv_and_reason() -> void:
	var run := _launch(["--model=" + FIXTURES + "failing_model.gd", "--turns=10", "--seed=5"])
	assert_int(run["code"]).is_equal(1)
	var csv := _text(run["stdout"])
	assert_int(csv.split("\r\n").size()).is_equal(6)
	assert_bool(csv.contains("エラー") or csv.contains("ターン 4")).is_false()
	var reason := _text(run["stderr"])
	assert_str(reason).contains("ターン 4")
	assert_str(reason).contains("シード：5")
	assert_bool(reason.contains("turn,a,b")).is_false()


## 引数の不正な UTF-8（bash の $'\xff'）は、終了コード 2 で、落ちない。標準エラーにも不正なバイトは残らない。
func test_invalid_utf8_argument() -> void:
	var run := _launch([], "--turns=3 $'--model=res://\\xff\\xfe.gd'")
	assert_int(run["code"]).is_equal(2)
	assert_int(run["stdout"].size()).is_equal(0)
	var stderr_bytes: PackedByteArray = run["stderr"]
	assert_int(stderr_bytes.size()).is_greater(0)
	# 標準エラーが正しい UTF-8 であること（不正なバイトを、そのまま出していない）。
	var decoded := stderr_bytes.get_string_from_utf8()
	assert_bool(decoded.to_utf8_buffer() == stderr_bytes).is_true()
	assert_str(HostileValues.find_raw_invisible(decoded.replace("\n", ""))).is_empty()


## 引数の U+202E と、長さ 10 万の引数は、標準エラーでエスケープ・切り詰めされる。
func test_hostile_arguments_are_escaped_on_stderr() -> void:
	var run := _launch(["--model=res://a" + char(0x202E) + "b.gd", "--turns=3"])
	assert_int(run["code"]).is_equal(2)
	var reason := _text(run["stderr"])
	assert_str(reason).contains("U+202E")
	assert_str(HostileValues.find_raw_invisible(reason.replace("\n", ""))).is_empty()
	var unknown := _launch(["--bad" + char(0x202E) + "=1", "--model=" + TOWN, "--turns=3"])
	assert_int(unknown["code"]).is_equal(2)
	assert_str(_text(unknown["stderr"])).contains("\\u{202E}")
	var long := _launch(["--model=res://" + "a".repeat(100000) + ".gd", "--turns=3"])
	assert_int(long["code"]).is_equal(2)
	assert_int(long["stderr"].size()).is_less(3000)


## 標準エラーに、Godot の ERROR や WARNING の行が出ない（失敗の理由は「エラー：」で始まる行だけである）。
func test_success_has_no_engine_messages() -> void:
	var run := _launch(["--model=" + TOWN, "--turns=5"])
	assert_int(run["stderr"].size()).is_equal(0)
	var failure := _launch(["--model=" + FIXTURES + "failing_model.gd", "--turns=10"])
	var lines := _text(failure["stderr"]).strip_edges().split("\n")
	assert_int(lines.size()).is_equal(1)
	assert_bool(_text(failure["stderr"]).contains("ERROR")).is_false()
	assert_bool(_text(failure["stderr"]).contains("WARNING")).is_false()
