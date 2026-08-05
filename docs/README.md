# FreeTime Web

GitHub Pages 用の静的 Web 版です。

- `docs/index.html` を GitHub Pages の公開ルートにします。
- データはブラウザの `localStorage` に保存されます。
- 右上の「読み込み」から、iOS版の自動バックアップJSONまたはWeb版バックアップJSONを取り込めます。
- 右上の「Google同期」から、Google Drive の非公開アプリデータ領域に保存して別デバイスへ同期できます。
- 空き時間をクリックすると、連続した空き時間の開始〜終了を初期値にして予定追加画面を開きます。
- 空き時間の終了が 0:00 の場合、予定追加時の終了時刻は 23:55 になります。

## Google同期

既存予定データをGitHub Pagesの公開ファイルに含めず、Googleアカウントごとの非公開領域へ保存します。

1. Google Cloud ConsoleでOAuth 2.0 クライアントID（ウェブアプリ）を作成します。
2. 承認済みのJavaScript生成元に以下を追加します。
   - `https://kensuke5704.github.io`
   - `http://localhost:4173`
3. Google Drive APIを有効化します。
4. サイト右上の「Google同期」を押し、表示された入力欄にクライアントIDを貼り付けます。
   - コード側に固定したい場合は、`docs/src/google-config.js` の `GOOGLE_CLIENT_ID` に設定することもできます。
5. サイト右上の「読み込み」で既存JSONを取り込みます。
6. 「Google同期」を押すと、Google Drive の `appDataFolder` に保存されます。
7. 別デバイスでは同じGoogleアカウントで「Google同期」を押し、同じクライアントIDを入力してGoogle側のデータを読み込みます。

`appDataFolder` のデータは通常のDriveファイル一覧には表示されず、このアプリが要求する権限でのみ読み書きされます。
入力したクライアントIDは各ブラウザの `localStorage` に保存されます。これは識別子であり、予定データや秘密鍵ではありません。
同期時にはログイン中のGoogleアカウントのメールアドレスを確認し、設定した同期アカウントと違う場合は保存/読み込みを止めます。

## GitHub Pages 設定

GitHub のリポジトリ設定で以下を選んでください。

1. Settings
2. Pages
3. Build and deployment: `Deploy from a branch`
4. Branch: `main`
5. Folder: `/docs`
