# FreeTime Web

GitHub Pages 用の静的 Web 版です。

- `docs/index.html` を GitHub Pages の公開ルートにします。
- データはブラウザの `localStorage` に保存されます。
- 右上の「読み込み」から、iOS版の自動バックアップJSONまたはWeb版バックアップJSONを取り込めます。
- 右上の「Googleで同期」からGoogleログインし、Firestoreの非公開同期ドキュメント経由で別デバイスへ同期できます。
- 空き時間をクリックすると、連続した空き時間の開始〜終了を初期値にして予定追加画面を開きます。
- 空き時間の終了が 0:00 の場合、予定追加時の終了時刻は 23:55 になります。

## Google同期

既存予定データをGitHub Pagesの公開ファイルに含めず、financeアプリと同じFirebase Auth + Firestore方式で保存します。

1. サイト右上の「Googleで同期」を押してGoogleログインします。
2. 初回ログイン後はFirebase Authがブラウザ内にログイン状態を保持します。
3. 同期中に予定・課題・テンプレートを編集すると、Firestoreの `shared/freetime` ドキュメントへ自動保存されます。
4. 別デバイスでも同じGoogleアカウントでログインすると、同じ同期データが表示されます。

同期対象のGoogleアカウントは `docs/src/google-config.js` の `SHARED_EMAILS` で制限しています。
予定データはGitHub Pagesの公開ファイルには含まれません。

## GitHub Pages 設定

GitHub のリポジトリ設定で以下を選んでください。

1. Settings
2. Pages
3. Build and deployment: `Deploy from a branch`
4. Branch: `main`
5. Folder: `/docs`
