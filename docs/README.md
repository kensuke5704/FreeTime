# FreeTime Web

GitHub Pages 用の静的 Web 版です。

- `docs/index.html` を GitHub Pages の公開ルートにします。
- データはブラウザの `localStorage` に保存されます。
- 空き時間をクリックすると、連続した空き時間の開始〜終了を初期値にして予定追加画面を開きます。
- 空き時間の終了が 0:00 の場合、予定追加時の終了時刻は 23:55 になります。

## GitHub Pages 設定

GitHub のリポジトリ設定で以下を選んでください。

1. Settings
2. Pages
3. Build and deployment: `Deploy from a branch`
4. Branch: `main`
5. Folder: `/docs`
