## AutoRunCli のテスト（同じプロセスの中で呼ぶ）。引数の検査、モデルの読み込み、ファイルへの書き出しを確かめる。
## 実際のプロセスを起動する境界のテストは auto_run_process_test.gd にある。シーンを使わない。
class_name AutoRunCliTest
extends GdUnitTestSuite

const TOWN: String = "res://src/sample/town_model.gd"
const FIXTURES: String = "res://test/fixtures/"

var _temp_paths: Array[String] = []


func after_test() -> void:
	for path in _temp_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	for path in _temp_paths:
		if DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)
	_temp_paths.clear()


# 一時ディレクトリを作って返す。after_test で消す。
func _temp_dir() -> String:
	var path := OS.get_temp_dir().path_join("meguri_cli_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(path)
	_temp_paths.append(path)
	return path


# 引数を渡して実行し、{"code", "stdout", "stderr"} を返す。
func _run(args: Array[String]) -> Dictionary:
	var out: Array[String] = []
	var err: Array[String] = []
	var cli := AutoRunCli.new(func(text: String) -> void: out.append(text), func(text: String) -> void: err.append(text))
	var code := cli.execute(PackedStringArray(args))
	return {"code": code, "stdout": "".join(out), "stderr": "".join(err)}


## サンプルの町を入口から呼ぶ。見出し、ターン0、行数、終了コード 0、標準エラーが空であること。
func test_town_runs_through_the_entry() -> void:
	var result := _run(["--model=" + TOWN, "--turns=30", "--seed=1"])
	assert_int(result["code"]).is_equal(0)
	assert_str(result["stderr"]).is_empty()
	var lines: PackedStringArray = String(result["stdout"]).split("\r\n")
	# 見出し + ターン 0〜30 + 末尾の空要素。
	assert_int(lines.size()).is_equal(1 + 31 + 1)
	assert_str(lines[0]).is_equal("turn,population,food,money")
	assert_str(lines[1]).is_equal("0,100.0,120.0,100.0")
	assert_str(lines[31]).starts_with("30,")


## 同じ指定で2回回すと、出力は同じである。
func test_same_arguments_give_same_output() -> void:
	var args: Array[String] = ["--model=" + TOWN, "--turns=30", "--seed=7"]
	assert_str(_run(args)["stdout"]).is_equal(_run(args)["stdout"])


## --seed を省くと 0 になる。
func test_seed_defaults_to_zero_and_is_parsed() -> void:
	var options := AutoRunCli.parse_args(PackedStringArray(["--model=" + TOWN, "--turns=3"]))
	assert_str(options["error"]).is_empty()
	assert_int(options["seed"]).is_equal(0)
	assert_int(options["turns"]).is_equal(3)
	options = AutoRunCli.parse_args(PackedStringArray(["--model=" + TOWN, "--turns=3", "--seed=-42"]))
	assert_int(options["seed"]).is_equal(-42)
	options = AutoRunCli.parse_args(PackedStringArray(["--model=" + TOWN, "--turns=3", "--seed=123456789012345678"]))
	assert_int(options["seed"]).is_equal(123456789012345678)


## シードは入口からモデルの set_seed に届く。同じシードなら同じ出力、違うシードなら違う出力になる。
func test_seed_reaches_the_model() -> void:
	var model := FIXTURES + "seeded_model.gd"
	var one: String = _run(["--model=" + model, "--turns=5", "--seed=1"])["stdout"]
	var again: String = _run(["--model=" + model, "--turns=5", "--seed=1"])["stdout"]
	var other: String = _run(["--model=" + model, "--turns=5", "--seed=2"])["stdout"]
	assert_str(one).is_equal(again)
	assert_str(one).is_not_equal(other)


## --turns は 1 以上 100000 以下の整数。範囲外・整数でないものは、何も出さずに終了コード 2 で終わる。
func test_turns_is_validated() -> void:
	for value in ["0", "-1", "100001", "99999999", "abc", "1.5", "1e3", "+5", " 5", "5 ", "", "99999999999999999999"]:
		var result := _run(["--model=" + TOWN, "--turns=" + value])
		assert_int(result["code"]).override_failure_message("turns=" + value).is_equal(2)
		assert_str(result["stdout"]).is_empty()
		assert_str(result["stderr"]).override_failure_message("turns=" + value).contains("--turns")
	for value in ["1", "100000"]:
		var options := AutoRunCli.parse_args(PackedStringArray(["--model=" + TOWN, "--turns=" + value]))
		assert_str(options["error"]).is_empty()


## --seed は整数だけ。
func test_seed_is_validated() -> void:
	for value in ["abc", "1.5", "--1", "+1", "", "-", "1234567890123456789", "0x10"]:
		var result := _run(["--model=" + TOWN, "--turns=1", "--seed=" + value])
		assert_int(result["code"]).override_failure_message("seed=" + value).is_equal(2)
		assert_str(result["stdout"]).is_empty()


## 引数の形の誤り：足りない、知らない、重複、= が無い、多すぎる。
func test_argument_shape_errors() -> void:
	var cases: Array[Array] = [
		[],
		["--turns=3"],
		["--model=" + TOWN],
		["--model=" + TOWN, "--turns=3", "--bogus=1"],
		["--model=" + TOWN, "--turns=3", "--turns=4"],
		["--model=" + TOWN, "--turns=3", "extra"],
		["--model=" + TOWN, "--turns"],
		["-model=" + TOWN, "--turns=3"],
		["--model=" + TOWN, "--turns=3", "--out="],
	]
	for args: Array in cases:
		var typed: Array[String] = []
		for arg: String in args:
			typed.append(arg)
		var result := _run(typed)
		assert_int(result["code"]).override_failure_message(str(args)).is_equal(2)
		assert_str(result["stdout"]).is_empty()
		assert_str(result["stderr"]).is_not_empty()
	var many: Array[String] = []
	for i in AutoRunCli.MAX_ARGS + 1:
		many.append("--turns=1")
	assert_int(_run(many)["code"]).is_equal(2)


## モデルのパス：res:// の下の .gd に限る。長さの上限。NUL・制御文字・「..」・バックスラッシュは Error。
func test_model_path_rules() -> void:
	var bad: Array[String] = [
		"", "res://", "res://x", "res://x.txt", "/etc/passwd", "user://x.gd", "file:///x.gd", "x.gd",
		"res://../x.gd", "res://a/../x.gd", "res://a\\b.gd", "res://a" + char(0x0A) + ".gd",
		"res://a" + char(0x202E) + ".gd", "res://" + "a".repeat(AutoRunCli.MAX_MODEL_PATH_LENGTH) + ".gd",
	]
	for path in bad:
		assert_str(AutoRunCli.check_model_path(path)).override_failure_message(path.left(40)).is_not_empty()
	assert_str(AutoRunCli.check_model_path(TOWN)).is_empty()
	# 上限ちょうどは、長さの検査を通る。
	var exact := "res://" + "a".repeat(AutoRunCli.MAX_MODEL_PATH_LENGTH - 9) + ".gd"
	assert_int(exact.length()).is_equal(AutoRunCli.MAX_MODEL_PATH_LENGTH)
	assert_str(AutoRunCli.check_model_path(exact)).is_empty()
	# NUL は GDScript の文字列に入れられない（エンジンが U+FFFD に置き換える）。引数に NUL が来ても、モデルのファイルが無いので Error になる。
	var replaced := "res://a" + char(0xFFFD) + ".gd"
	assert_str(String(AutoRunCli.load_model(replaced)["error"])).is_not_empty()


## build が無い、必須引数がある、null を返す、SimModel でない、Node のクラス、ファイルが無い：どれも Error で、実行しない。
func test_model_errors() -> void:
	var cases: Dictionary = {
		"no_build_model.gd": "build()",
		"build_args_model.gd": "build()",
		"null_build_model.gd": "SimModel",
		"wrong_type_model.gd": "SimModel",
		"node_model.gd": "RefCounted",
		"missing_model.gd": "無い",
	}
	for file_name: String in cases:
		var result := _run(["--model=" + FIXTURES + file_name, "--turns=3"])
		assert_int(result["code"]).override_failure_message(file_name).is_equal(2)
		assert_str(result["stdout"]).is_empty()
		assert_str(result["stderr"]).override_failure_message(file_name).contains(cases[file_name])


## （N+1）×ストックの数が 1,000,000 を超える指定は、実行の前に Error になり、CSV を出さない。
func test_cell_limit_through_the_entry() -> void:
	var model := FIXTURES + "many_stocks_model.gd"
	var result := _run(["--model=" + model, "--turns=100000"])
	assert_int(result["code"]).is_equal(2)
	assert_str(result["stdout"]).is_empty()
	assert_str(result["stderr"]).contains("大きすぎる")
	# 10 ターンなら通る。
	assert_int(_run(["--model=" + model, "--turns=10"])["code"]).is_equal(0)


## 実行時エラー：そのターンまでの CSV を出し、理由は標準エラーに分け、終了コードは 1 である。
func test_runtime_error_prints_partial_csv_and_reason_separately() -> void:
	var result := _run(["--model=" + FIXTURES + "failing_model.gd", "--turns=10", "--seed=9"])
	assert_int(result["code"]).is_equal(1)
	assert_str(result["stdout"]).is_equal("turn,a,b\r\n0,3.0,0.0\r\n1,2.0,0.3333333333333333\r\n2,1.0,0.8333333333333333\r\n3,0.0,1.8333333333333333\r\n")
	assert_str(result["stderr"]).contains("ターン 4")
	assert_str(result["stderr"]).contains("シード：9")
	assert_bool(String(result["stdout"]).contains("エラー")).is_false()


## 見出しの名前は、RFC 4180 のクォートと、式の文字の無効化と、T2-1 のエスケープを通る。
func test_hostile_names_in_header() -> void:
	var result := _run(["--model=" + FIXTURES + "hostile_names_model.gd", "--turns=1"])
	assert_int(result["code"]).is_equal(0)
	var header: String = String(result["stdout"]).split("\r\n")[0]
	assert_str(header).is_equal("turn,'=cmd,'+1,'-1,'@sum,\"a,b\",\"x\"\"y\",rtl\\u{202E}end,line\\u{000A}break")


## 出力先を指定すると、標準出力には何も出ず、ファイルに書かれる。
func test_output_file_is_written() -> void:
	var path := _temp_dir().path_join("out.csv")
	var result := _run(["--model=" + TOWN, "--turns=5", "--seed=1", "--out=" + path])
	assert_int(result["code"]).is_equal(0)
	assert_str(result["stdout"]).is_empty()
	var expected: String = _run(["--model=" + TOWN, "--turns=5", "--seed=1"])["stdout"]
	assert_str(FileAccess.get_file_as_string(path)).is_equal(expected)


## 既にあるファイルは上書きする（確認しない）。短い結果で、古い内容が残らない。
func test_existing_output_file_is_overwritten() -> void:
	var path := _temp_dir().path_join("out.csv")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("古い内容\n".repeat(1000))
	file.close()
	var result := _run(["--model=" + TOWN, "--turns=1", "--out=" + path])
	assert_int(result["code"]).is_equal(0)
	var text := FileAccess.get_file_as_string(path)
	assert_str(text).starts_with("turn,population")
	assert_bool(text.contains("古い")).is_false()


## 親ディレクトリが無いとき、作らずに Error（終了コード 3）にする。ファイルはできない。
func test_missing_parent_directory_fails() -> void:
	var path := _temp_dir().path_join("no_such_dir").path_join("out.csv")
	var result := _run(["--model=" + TOWN, "--turns=1", "--out=" + path])
	assert_int(result["code"]).is_equal(3)
	assert_str(result["stderr"]).contains("ファイルを開けない")
	assert_bool(DirAccess.dir_exists_absolute(path.get_base_dir())).is_false()


## 出力先がディレクトリのとき、Error（終了コード 3）にする。
func test_output_path_is_a_directory() -> void:
	var result := _run(["--model=" + TOWN, "--turns=1", "--out=" + _temp_dir()])
	assert_int(result["code"]).is_equal(3)
	assert_str(result["stderr"]).is_not_empty()


## 出力先がソースを指す res:// と uid:// は拒否する。
func test_output_path_cannot_be_res() -> void:
	for path in ["res://src/core/sim_model.gd", "uid://abc", "res://x.csv"]:
		var result := _run(["--model=" + TOWN, "--turns=1", "--out=" + path])
		assert_int(result["code"]).override_failure_message(path).is_equal(2)


## 実行時エラーのときも、ファイルにそこまでの CSV を書き、理由は標準エラーに出す。
func test_runtime_error_with_output_file() -> void:
	var path := _temp_dir().path_join("partial.csv")
	var result := _run(["--model=" + FIXTURES + "failing_model.gd", "--turns=10", "--out=" + path])
	assert_int(result["code"]).is_equal(1)
	assert_str(result["stdout"]).is_empty()
	assert_str(FileAccess.get_file_as_string(path)).is_equal("turn,a,b\r\n0,3.0,0.0\r\n1,2.0,0.3333333333333333\r\n2,1.0,0.8333333333333333\r\n3,0.0,1.8333333333333333\r\n")
	assert_str(result["stderr"]).contains("ターン 4")


## 実行時エラーで、出力先にも書けないとき、終了コードは 3 で、両方の理由を出す。
func test_runtime_error_and_unwritable_output() -> void:
	var path := _temp_dir().path_join("no_such_dir").path_join("out.csv")
	var result := _run(["--model=" + FIXTURES + "failing_model.gd", "--turns=10", "--out=" + path])
	assert_int(result["code"]).is_equal(3)
	assert_str(result["stderr"]).contains("ターン 4")
	assert_str(result["stderr"]).contains("出力先に書けない")


## 列3〜6：共有一覧の文字列を、--model・--turns・--seed・--out の値と、引数そのものに流す。
## 標準エラーに生の不可視文字が残らず、1行が上限を超えず、何も書かれず、終了コードが 0 以外である。
func test_hostile_strings_through_every_argument() -> void:
	var all := HostileValues.strings()
	var line_limit: int = ModelCheck.MAX_LAST_ERROR_LENGTH + 1
	for label: String in all:
		var value: String = all[label]
		var cases: Array[Array] = [
			["--model=" + value, "--turns=1"],
			["--model=" + TOWN, "--turns=" + value],
			["--model=" + TOWN, "--turns=1", "--seed=" + value],
			[value],
			["--" + value + "=1"],
		]
		for args: Array in cases:
			var typed: Array[String] = []
			for arg: String in args:
				typed.append(arg)
			var result := _run(typed)
			var stderr_text: String = String(result["stderr"]).replace("\n", "")
			var context := "%s：%s" % [label, str(args).left(60)]
			# 「--out=」が空文字のとき等は、引数の誤りになる。成功する組は無い（共有一覧は model・turns・seed・out のどれにも合わない）。
			assert_int(result["code"]).override_failure_message(context).is_not_equal(0)
			assert_str(result["stdout"]).override_failure_message(context).is_empty()
			assert_str(HostileValues.find_raw_invisible(stderr_text)).override_failure_message(context).is_empty()
			assert_int(stderr_text.length()).override_failure_message(context).is_less_equal(line_limit + AutoRunCli.USAGE.length())


## --out に共有一覧の文字列を流す。一時ディレクトリの下のファイル名として渡す（作られたファイルは消す）。
## 拒否されても、書かれても、標準出力には何も出ず、標準エラーに生の不可視文字が残らない。空白だけのパスそのものは拒否される。
func test_hostile_strings_as_output_path() -> void:
	var dir := _temp_dir()
	var all := HostileValues.strings()
	for label: String in all:
		var result := _run(["--model=" + TOWN, "--turns=1", "--out=" + dir.path_join(all[label])])
		assert_str(result["stdout"]).override_failure_message(label).is_empty()
		assert_str(HostileValues.find_raw_invisible(String(result["stderr"]).replace("\n", ""))).override_failure_message(label).is_empty()
		for file_name in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file_name))
	for blank in ["", " ", " ".repeat(10), char(0x200B), char(0x3000)]:
		assert_int(_run(["--model=" + TOWN, "--turns=1", "--out=" + blank])["code"]).override_failure_message("out=" + blank).is_equal(2)


## 出力先が拒否されたとき、ファイルは作られない。共有一覧の文字列を、一時ディレクトリの下のファイル名として流す。
## 拒否されなかった名前（通常の文字だけの名前）で作られたファイルは、ディレクトリの外に出ない。
func test_hostile_output_paths_create_nothing_when_rejected() -> void:
	var dir := _temp_dir()
	var all := HostileValues.strings()
	for label: String in all:
		var path := dir.path_join(all[label])
		var rejected := not AutoRunCli.check_out_path(path).is_empty()
		var before := DirAccess.get_files_at(dir).size()
		var problem := AutoRunCli.write_file(path, "x")
		if rejected:
			assert_str(problem).override_failure_message(label).is_not_empty()
			assert_int(DirAccess.get_files_at(dir).size()).override_failure_message(label).is_equal(before)
		for file_name in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file_name))
	assert_int(DirAccess.get_directories_at(dir).size()).is_equal(0)
