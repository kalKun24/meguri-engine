## 開発環境の確認用テスト。Godot と gdUnit4 がヘッドレスで動くことを確かめる。
class_name EnvironmentTest
extends GdUnitTestSuite

## Godot 4 系で動いている。
func test_runs_on_godot_4() -> void:
	var version: Dictionary = Engine.get_version_info()
	assert_int(version["major"]).is_equal(4)


## RandomNumberGenerator は、シードを指定すると同じ並びを返す。
func test_seeded_random_is_reproducible() -> void:
	var first := RandomNumberGenerator.new()
	var second := RandomNumberGenerator.new()
	first.seed = 42
	second.seed = 42
	assert_int(first.randi()).is_equal(second.randi())
