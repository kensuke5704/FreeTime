// financeアプリと同じFirebaseプロジェクトを使い、Googleログイン状態をブラウザに永続化します。
// この設定値は公開されるFirebaseクライアント識別子であり、秘密鍵ではありません。
export const FIREBASE_CONFIG = {
  apiKey: "AIzaSyDV7v35UOCwRi8hxXPg7u_ijaqFw5phle8",
  authDomain: "finance-55694.firebaseapp.com",
  projectId: "finance-55694",
  storageBucket: "finance-55694.firebasestorage.app",
  messagingSenderId: "189181380819",
  appId: "1:189181380819:web:e9b4a9a7e2800d8fe02c26"
};

// Firestore上の同期先。予定データはGitHub Pagesの公開ファイルには含めません。
export const FIREBASE_SYNC_COLLECTION = "shared";
export const FIREBASE_SYNC_DOCUMENT = "freetime";

// FreeTimeの同期を許可するGoogleアカウント。
export const SHARED_EMAILS = ["kensuke5704@gmail.com"];
