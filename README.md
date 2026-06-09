# FreeTime

SwiftUI + WidgetKitで作ったiPhone向けの時間管理アプリです。

## 主な機能

- 今日と週間の空き時間計算
- ON / OFF予定
- 週間の横向き24時間タイムライン
- `すべて` / `ON＋空き` / `ONのみ`表示
- 課題、締切、見積時間、進捗
- 課題を複数の空き時間へ配置
- 平日テンプレート
- 曜日別集計
- ホーム画面・ロック画面ウィジェット

## 起動

1. Xcode 16以降で `FreeTime.xcodeproj` を開く
2. `FreeTime` ターゲットのSigning Teamを選ぶ
3. App GroupとBundle IDを自分のDeveloper Account向けに変更する
4. iPhoneシミュレータまたは実機で実行する

App Groupの初期値は `group.com.example.FreeTime` です。アプリとWidgetの両ターゲットで同じ値にしてください。
