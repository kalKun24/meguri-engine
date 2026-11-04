# チーム編成

| 枠 | Agent | 出典 | 選定理由 |
|---|---|---|---|
| implement | game-developer | 07-specialized-domains/game-developer.md@82b73821baa7 | カタログで唯一、ゲーム開発と Godot GDScript を扱うため |
| design | ui-designer | 01-core-development/ui-designer.md@82b73821baa7 | 画面の構成・操作・状態の UI 仕様を書けるため |
| code-review | code-reviewer | 04-quality-security/code-reviewer.md@82b73821baa7 | 正しさ・テスト・保守性を幅広く見るため |
| security-review | security-auditor | 04-quality-security/security-auditor.md@82b73821baa7 | 読み取り専用で入力検証と第三者データの扱いを見られ、計算式の評価の制限（デッキのリスク7）の確認に合うため |
| extra-review | data-scientist | 05-data-ai/data-scientist.md@82b73821baa7 | 自動実行の CSV を時系列で分析し、ループの暴走・停滞・振動を数値で指摘できるため（デッキのリスク1のうちバランスの観点） |
