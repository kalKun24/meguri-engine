## 終了コードと CI の失敗を確かめるための、意図的に失敗するテスト。確認後に削除する。
class_name IntentionalFailureTest
extends GdUnitTestSuite

func test_intentional_failure() -> void:
	assert_int(1).is_equal(2)
