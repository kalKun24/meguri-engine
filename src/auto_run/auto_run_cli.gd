## godot --headless の入口。コマンドライン引数を検査し、モデルを読み込み、AutoRunner で回して、CSV を出す。
## シミュレーションのロジックは持たない。引数は OS.get_cmdline_user_args() の形（-- より後ろ）で受け取る。
##
## 引数（すべて --名前=値 の形）：
##   --model=res://….gd   必須。build() -> SimModel を持つ GDScript。res:// の下の .gd に限る。
##   --turns=N            必須。1 以上 100000 以下の整数。
##   --seed=S             省略時は 0。整数（符号つき 18 桁まで）。
##   --out=FILE           省略時は標準出力。
##
## 終了コード：0 成功、1 実行時エラー（そのターンまでの CSV は出す）、2 引数・モデルの誤り（何も出さない）、3 出力先に書けない。
## モデルの勝利・敗北の条件で N の前にゲームが終わったときは、そこで止まる。CSV の最終行は終了したターン、終了コードは 0 で、
## 終了の理由（種類・条件の名前・ターン）を標準エラーに1行で出す。
## CSV は標準出力かファイルへ、理由は標準エラーへ出す。CSV に理由は混ぜない。
class_name AutoRunCli
extends RefCounted

const EXIT_OK: int = 0
const EXIT_RUN_FAILED: int = 1
const EXIT_USAGE: int = 2
const EXIT_OUTPUT_FAILED: int = 3

## 引数の個数の上限。
const MAX_ARGS: int = 8
## 引数1つの長さの上限（文字数）。
const MAX_ARG_LENGTH: int = 1100
## モデルのパスの長さの上限（文字数）。
const MAX_MODEL_PATH_LENGTH: int = 256
## 出力先のパスの長さの上限（文字数）。
const MAX_OUT_PATH_LENGTH: int = 1024
## --turns の桁数の上限。
const MAX_TURNS_DIGITS: int = 7
## --seed の桁数の上限（符号を除く）。int の範囲に収まる。
const MAX_SEED_DIGITS: int = 18
## 標準エラーに値を出すときの抜粋の長さ。
const MAX_ECHO_LENGTH: int = ModelCheck.MAX_EXPRESSION_EXCERPT_LENGTH

const USAGE: String = "使い方：godot --headless --no-header --path . -s res://src/auto_run/auto_run_main.gd -- --model=res://….gd --turns=N [--seed=S] [--out=FILE]"

var _stdout_sink: Callable
var _stderr_sink: Callable


## stdout_sink と stderr_sink は、文字列を1つ受け取る Callable である。省略すると、実際の標準出力と標準エラーに書く。
## 標準出力へは改行を足さずに書く。
func _init(stdout_sink: Callable = Callable(), stderr_sink: Callable = Callable()) -> void:
	_stdout_sink = stdout_sink if stdout_sink.is_valid() else _write_stdout
	_stderr_sink = stderr_sink if stderr_sink.is_valid() else _write_stderr


## 引数を受け取り、実行して、終了コードを返す。
func execute(args: PackedStringArray) -> int:
	var options := parse_args(args)
	if not String(options["error"]).is_empty():
		_fail("引数が正しくない", options["error"])
		_stderr_sink.call(USAGE + "\n")
		return EXIT_USAGE
	var loaded := load_model(options["model"])
	if not String(loaded["error"]).is_empty():
		_fail("モデルを読み込めない", loaded["error"])
		return EXIT_USAGE
	var model: SimModel = loaded["model"]
	var problem := AutoRunner.check_request(options["turns"], model.get_stock_names().size())
	if not problem.is_empty():
		_fail("実行の指定が正しくない", problem)
		return EXIT_USAGE

	var result := AutoRunner.new().run(model, options["turns"], options["seed"])
	var csv := result.to_csv()
	var code: int = EXIT_OK
	var out_path: String = options["out"]
	if out_path.is_empty():
		_stdout_sink.call(csv)
	else:
		var write_problem := write_file(out_path, csv)
		if not write_problem.is_empty():
			_fail("出力先に書けない", write_problem)
			code = EXIT_OUTPUT_FAILED
	if result.is_game_ended():
		# 勝利か敗北で N の前に終わっても、成功である（終了コードは 0）。理由は標準エラーに出す。
		_stderr_sink.call(ModelCheck.escape_excerpt(result.describe_end(), ModelCheck.MAX_LAST_ERROR_LENGTH, false) + "\n")
	if not result.is_ok():
		_fail("実行時エラー（シード：%d）" % result.seed, result.message)
		if code == EXIT_OK:
			code = EXIT_RUN_FAILED
	return code


## 引数を解釈する。返す Dictionary は、"error"（問題が無ければ空文字）、"model"、"turns"、"seed"、"out" を持つ。
## error があるとき、ほかの値は使わない。値の検査もここで行う。
static func parse_args(args: PackedStringArray) -> Dictionary:
	var options: Dictionary = {"error": "", "model": "", "turns": 0, "seed": 0, "out": ""}
	if args.size() > MAX_ARGS:
		return _invalid(options, "引数が多すぎる（上限 %d 個、実際 %d 個）" % [MAX_ARGS, args.size()])
	var seen: Dictionary = {}
	for arg in args:
		if arg.length() > MAX_ARG_LENGTH:
			return _invalid(options, "引数が長すぎる（上限 %d 文字、実際 %d 文字）：%s" % [MAX_ARG_LENGTH, arg.length(), _echo(arg)])
		var equals: int = arg.find("=")
		if not arg.begins_with("--") or equals < 0:
			return _invalid(options, "引数は --名前=値 の形で書く：%s" % _echo(arg))
		var key: String = arg.substr(2, equals - 2)
		var value: String = arg.substr(equals + 1)
		if not ["model", "turns", "seed", "out"].has(key):
			return _invalid(options, "知らない引数：%s" % _echo(arg.substr(0, equals)))
		if seen.has(key):
			return _invalid(options, "同じ引数が2回ある：--%s" % key)
		seen[key] = true
		var problem: String = ""
		match key:
			"model":
				problem = check_model_path(value)
				options["model"] = value
			"turns":
				problem = _parse_turns(value, options)
			"seed":
				problem = _parse_seed(value, options)
			"out":
				problem = check_out_path(value)
				options["out"] = value
		if not problem.is_empty():
			return _invalid(options, "--%s：%s" % [key, problem])
	if not seen.has("model"):
		return _invalid(options, "--model が無い")
	if not seen.has("turns"):
		return _invalid(options, "--turns が無い")
	return options


## モデルのパスを検査する。問題が無ければ空文字を、あれば理由を返す。
## res:// の下の .gd で、MAX_MODEL_PATH_LENGTH 文字以下、NUL・制御文字・不可視文字・バックスラッシュ・「..」の区切りを含まないものに限る。
static func check_model_path(path: String) -> String:
	if path.length() > MAX_MODEL_PATH_LENGTH:
		return "パスが長すぎる（上限 %d 文字、実際 %d 文字）" % [MAX_MODEL_PATH_LENGTH, path.length()]
	var problem := _check_characters(path)
	if not problem.is_empty():
		return problem
	if not path.begins_with("res://") or not path.ends_with(".gd"):
		return "res:// の下の .gd だけを指定できる：%s" % _echo(path)
	if path.contains("\\") or path.split("/").has(".."):
		return "パスに「\\」と「..」は使えない：%s" % _echo(path)
	return ""


## 出力先のパスを検査する。問題が無ければ空文字を、あれば理由を返す。
## 空（空白だけ・不可視文字だけを含む）、MAX_OUT_PATH_LENGTH 文字超、NUL・制御文字・不可視文字を含むもの、res:// と uid:// で始まるもの（ソースを上書きしない）は拒否する。
static func check_out_path(path: String) -> String:
	if ModelCheck.is_blank(path):
		return "パスが空である"
	if path.length() > MAX_OUT_PATH_LENGTH:
		return "パスが長すぎる（上限 %d 文字、実際 %d 文字）" % [MAX_OUT_PATH_LENGTH, path.length()]
	var problem := _check_characters(path)
	if not problem.is_empty():
		return problem
	if path.begins_with("res://") or path.begins_with("uid://"):
		return "res:// と uid:// には書けない：%s" % _echo(path)
	return ""


## モデルを読み込む。返す Dictionary は、"error"（問題が無ければ空文字）と "model"（SimModel）を持つ。
## path は check_model_path を通ったものとする（ここでも検査する）。
## パスの GDScript を読み込み、引数なしで呼べる build() を持つことと、build() が SimModel を返すことを確かめる。
## 注意：指定した GDScript のコードを実行する。信頼できないモデルを読み込まない。
static func load_model(path: String) -> Dictionary:
	var result: Dictionary = {"error": "", "model": null}
	var problem := check_model_path(path)
	if not problem.is_empty():
		result["error"] = problem
		return result
	if not ResourceLoader.exists(path):
		result["error"] = "モデルのファイルが無い：%s" % _echo(path)
		return result
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		result["error"] = "GDScript として読み込めない：%s" % _echo(path)
		return result
	if not _has_callable_build(script):
		result["error"] = "引数なしで呼べる build() が無い：%s" % _echo(path)
		return result
	var builder: Variant = script.new()
	if not builder is RefCounted:
		# Node など、自動で解放されないオブジェクトは使わない。解放して断る。
		if builder is Object:
			(builder as Object).free()
		result["error"] = "RefCounted のクラスだけを指定できる：%s" % _echo(path)
		return result
	var model: Variant = (builder as Object).call("build")
	if not model is SimModel:
		result["error"] = "build() が SimModel を返さなかった：%s" % _echo(path)
		return result
	result["model"] = model
	return result


## CSV をファイルに書く。既にあれば上書きする（確認はしない）。親ディレクトリが無いときは作らずに失敗する。
## 問題が無ければ空文字を、失敗したら理由を返す。
static func write_file(path: String, csv: String) -> String:
	var problem := check_out_path(path)
	if not problem.is_empty():
		return problem
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "ファイルを開けない（%s）：%s" % [error_string(FileAccess.get_open_error()), _echo(path)]
	var stored: bool = file.store_string(csv)
	var write_error: Error = file.get_error()
	file.close()
	if not stored or write_error != OK:
		return "ファイルへの書き込みに失敗した（%s）：%s" % [error_string(write_error), _echo(path)]
	return ""


static func _check_characters(path: String) -> String:
	if path.is_empty():
		return "パスが空である"
	for i in path.length():
		var code: int = path.unicode_at(i)
		if code == 0:
			return "パスに NUL を含む"
		if ModelCheck.needs_escape(code):
			return "パスに制御文字か不可視文字を含む（位置 %d、U+%04X）" % [i, code]
	return ""


static func _has_callable_build(script: GDScript) -> bool:
	for method: Dictionary in script.get_script_method_list():
		if method["name"] == "build":
			var required: int = (method["args"] as Array).size() - (method["default_args"] as Array).size()
			return required == 0
	return false


static func _parse_turns(value: String, options: Dictionary) -> String:
	if not _is_digits(value, MAX_TURNS_DIGITS):
		return "1 以上 %d 以下の整数にする（%d 桁まで）：%s" % [AutoRunner.MAX_TURNS, MAX_TURNS_DIGITS, _echo(value)]
	var turns: int = value.to_int()
	if turns < 1 or turns > AutoRunner.MAX_TURNS:
		return "1 以上 %d 以下にする：%s" % [AutoRunner.MAX_TURNS, _echo(value)]
	options["turns"] = turns
	return ""


static func _parse_seed(value: String, options: Dictionary) -> String:
	var digits: String = value.substr(1) if value.begins_with("-") else value
	if not _is_digits(digits, MAX_SEED_DIGITS):
		return "整数にする（符号を除いて %d 桁まで）：%s" % [MAX_SEED_DIGITS, _echo(value)]
	options["seed"] = value.to_int()
	return ""


# 1 文字以上 max_digits 文字以下の、0〜9 だけの文字列かを返す。
static func _is_digits(text: String, max_digits: int) -> bool:
	if text.is_empty() or text.length() > max_digits:
		return false
	for i in text.length():
		var code: int = text.unicode_at(i)
		if code < 0x30 or code > 0x39:
			return false
	return true


static func _invalid(options: Dictionary, message: String) -> Dictionary:
	options["error"] = message
	return options


# 利用者由来の文字列を、標準エラーに出す形（エスケープして、抜粋にする）にする。
static func _echo(text: String) -> String:
	return ModelCheck.escape_excerpt(text, MAX_ECHO_LENGTH)


# 標準エラーに「エラー：種類：理由」を1行で出す。理由は、エスケープ済みの文でも、安全に出すために再び通す。
func _fail(kind: String, reason: String) -> void:
	var line := "エラー：%s：%s" % [kind, reason]
	_stderr_sink.call(ModelCheck.escape_excerpt(line, ModelCheck.MAX_LAST_ERROR_LENGTH, false) + "\n")


func _write_stdout(text: String) -> void:
	printraw(text)


func _write_stderr(text: String) -> void:
	printerr(text.trim_suffix("\n"))
