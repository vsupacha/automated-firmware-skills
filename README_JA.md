# automated-firmware-skills（日本語）

マイコンのファームウェア開発を「ツールはそろっているか」から「実機でテストに合格した」まで、各段階に
ゲート（合否判定）を設けて進める AI エージェント（Claude Code）用のスキル集です。スクリプトはすべて
普通の bash / Python なので、エージェントを使わずに開発者が一段ずつ手で実行することもできます。

主要ドキュメントは英語です。このページは考え方を短くまとめ、各ドキュメントへのリンクを示します。

## 考え方

- **スキル = ツールチェーン + フレームワーク + ボード**（例: `cubemx-hal-stm32l475iot`、`pio-arduino-unor4wifi`）
- **ゲート付きの段階**: どのスキルも同じ段階・同じスクリプト名（ツール確認 → プロジェクト作成 → IDE で開く →
  ビルド → ボード接続 → 書き込み → テスト → 後片付け）。PASS が出たら次の段階へ進みます。
- **判断するのは開発者**: ツールのインストール、ボードの接続、ボタン操作、**書き込みの承認**など人にしかできない
  作業では、スクリプトが `ACTION: ...` を表示して止まり、確認を待ちます。許可なく書き込むことはありません。
- **二つの進め方（いつでも切り替え可能）**: IDE で自分でコーディング・ビルド・書き込み・デバッグする方法と、
  エージェントにゲート付きの段階を実行させる方法。
- **立ち上げ用デモ**: hello-world（UART）、blink（LED）、push-to-light（ボタンで LED 点灯）。

## 使い方

1. Claude Code にプラグインをインストール:
   `/plugin marketplace add vsupacha/automated-firmware-skills` の後
   `/plugin install automated-firmware-skills@automated-firmware-skills`
2. [boards/README.md](boards/README.md) でボードを選びます。各ボードの README に必要なツールとコマンドがあります。
3. 自然な言葉で依頼します。例:「使い方を教えて」「blink アプリを作ってビルドして」「書き込んでテストして」

## ドキュメント（英語）

| ドキュメント | 内容 |
| --- | --- |
| [README.md](README.md) | 概要、考え方、使い方、スキルと IDE の一覧 |
| [boards/README.md](boards/README.md) | 対応ボード、ボード上の I/O、デモの検証状況 |
| [docs/milestones.md](docs/milestones.md) | マイルストーン M1〜M5 の計画と現状 |
| [docs/workflow.md](docs/workflow.md) | 全スキル共通の取り決め: 段階、ゲート、終了コード、ACTION |
| [docs/board-api.md](docs/board-api.md) | `board.h` API とレイヤー分けのルール |
| [docs/walkthrough-edgi-talk-ide.md](docs/walkthrough-edgi-talk-ide.md) | IDE での作業の実例 |
