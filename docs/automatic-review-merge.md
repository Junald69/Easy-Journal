# PRの自動レビューとマージ

Easy-Journal の main 向けPRを、毎回ChatGPTへ依頼せずに処理する設定です。
PRの作成・更新時に確認し、既存の `CI` が成功したイベントでCodexレビューを開始します。
レビューは読み取り専用です。コードの修正は行いません。

## 最初の設定（Junさんが1回だけ行う）

この設定用PRは、自分自身で自動マージしません。内容を確認して手動でマージしてください。

1. GitHub の Easy-Journal → **Settings → Secrets and variables → Actions → Secrets** で、
   `OPENAI_API_KEY` を追加します。値は [OpenAI APIのキー](https://platform.openai.com/api-keys) です。
   **キーをPR、コメント、この会話に貼らないでください。**
2. 同じ画面の **Variables** に `AUTO_REVIEW_MERGE_ENABLED` を追加し、値を `true` にすると有効です。
   まず無効のまま設定用PRを取り込んでから、有効にしてください。
3. **Settings → Actions → General** でActionsが利用できること、利用制限がある場合は
   `openai/codex-action` と `actions/*` が許可されていることを確認します。
   ワークフローが必要な権限を宣言します。組織側で書き込みが禁止されている場合は実行ログにエラーが出ます。

APIにはChatGPTの月額契約と**別の従量料金**がかかります。API側の使用量・予算設定を確認してください。
GitHub ActionsのLinux実行時間も利用します。APIキーがない・失効した場合は失敗し、マージしません。
ネイティブのCodexコードレビュー機能や `@codex review` の設定は、この方式には必要ありません。
GitHubの「Allow auto-merge」を有効にする必要もありません。条件確認後にマージAPIを呼びます。

## 自動で行うこと

1. Draft以外で、同じリポジトリ内のブランチからmainに向けたPRか確認。
2. PRブランチに最新mainが含まれ、そのコミットのCI・ビルド・テストが成功したことを確認。
3. Codexが差分・周辺コード・設計書を読み、問題点を日本語で判定。
4. PRにレビュー結果をコメント。
5. 指摘がなく、未解決のレビューや変更要求、失敗・実行中のチェックがなければ、
   head・base・CIが変わっていないことを再確認し、squash merge。
6. マージ後のmainに対してCIを明示的に起動。
   `GITHUB_TOKEN`によるマージでは通常のpushイベントが連鎖しないためです。

GitHubのブランチ保護ルールを回避しません。必要な承認などが不足していればマージは拒否されます。
この仕組みはAIレビューであり、すべての不具合を検出できる保証はありません。
マージAPIはheadの変更を拒否できますが、baseの更新との競合を完全に防ぐには、
GitHub側でも「最新ブランチであること」とCIを必須にするブランチ保護ルールを設定してください。

## 保留になる場合

- 指摘あり・判断できない：PRコメントを読んで修正し、pushしてください。新しいCI成功後に再レビューします。
- 最新mainが入っていない：PRブランチにmainを取り込み、pushしてください。
- CI失敗：CIログを確認してください。成功したCI完了イベントだけがレビューを起動します。
- `.github/` の追加・変更・削除・移動：自動化やCI自身の設定に関わるため、手動レビュー・マージが必要です。
- docs/ と README.md だけの変更：既存CIがスキップするため、自動マージせず手動扱いです。
- 未解決レビュー・外部チェック待ち・競合：解決後に、PRの編集やCIの再実行で再判定します。
- APIやGitHubのエラー：**Actions → Automatic review and merge** の失敗ログを確認してください。
  エラー・不正JSON・空のレビュー結果を合格扱いすることはありません。

同じheadを再実行した場合、もう一度API料金がかかり、追加のレビューコメントが投稿される場合があります。
有効化より前に作成済みのPRも、次回の更新・CI再実行イベントで対象になります。

## 停止するには

`AUTO_REVIEW_MERGE_ENABLED` を `false` にします。
すでに実行中の処理は **Actions** から **Cancel workflow** でキャンセルしてください。
停止変数はジョブ開始時に評価されるため、実行中ジョブの停止にはキャンセルが必要です。

## 開発者向けの確認

```sh
node --test .github/automation/review-merge.test.cjs
```

CI成功判定、古いレビューの拒否、指摘あり・Draft・外部PR・設定変更・未解決スレッドの保留、
SHAを指定したマージ、マージ後のmain CI起動を、GitHub APIのモックで検証します。
Codexへの実APIリクエストと実際のマージは、APIキー設定後に専用の小さなPRで確認してください。

使用: [openai/codex-action](https://github.com/openai/codex-action)
