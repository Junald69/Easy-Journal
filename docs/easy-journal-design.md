# Easy Journal（仮）実装前設計資料

> **Write Freely. Track Effortlessly.**
> 簡単に使えて、長続きするデジタル手帳 / バレットジャーナルアプリ

- 作成日: 2026-10-27
- 対象: iPhone（まず優先） / iPad（将来は見開き表示）
- 読む人: 開発者 Jun（開発初心者）、実装担当 AI「Codie」
- 開発環境: Windows + Google Antigravity + GitHub + GitHub Actions（macOS でビルド）+ Codex などの AI
- この文書のルール:
  - コードは「骨組み」「構造体の例」までにとどめます。
  - 事実として確かめきれていないこと（API が使える iOS バージョンなど）には **【要確認】** を付けています。実装前に Apple の公式ドキュメントで確認してください。
  - 機能は盛りすぎません。「毎日書かなくても成り立つ」ことを最優先にします。SNS・共有機能は入れません。

---

## 0. はじめに：この文書で使う言葉（用語ミニ辞典）

| 言葉 | やさしい説明 |
|---|---|
| MVP | 「最小限で使える最初の版」。まず出すべき一番小さなアプリのこと。 |
| SwiftUI | Apple の画面づくりの仕組み。「こういう画面にしたい」とコードで書くと画面ができる。 |
| SwiftData | Apple のデータ保存の仕組み。アプリの中に記録を保存するための道具。 |
| Xcode | Apple 公式の開発アプリ。Mac でしか動かない。今回は「画面操作では使わない」方針。 |
| GitHub Actions | GitHub 上で自動で作業（ビルド・テスト）をしてくれる仕組み。Mac を借りて動かせる。 |
| ビルド | 書いたコードを、実際に動くアプリの形に組み立てること。 |
| シミュレーター | パソコンの中で動く「仮想の iPhone」。 |
| TestFlight | 正式公開の前に、自分の iPhone にテスト版アプリを入れられる Apple の仕組み。 |
| 署名（コード署名） | 「このアプリは確かにこの開発者が作った」と証明する手続き。実機に入れるのに必要。 |
| XcodeGen | 設定ファイル（文字だけ）から Xcode のプロジェクトを自動で作る道具。Xcode の画面操作が不要になる。 |
| チケット | 作業を小さく分けた 1 単位。「これが終われば完了」という条件付き。 |
| PR（プルリクエスト） | 「この変更を取り込んでください」という GitHub 上のお願い。ここで確認してから取り込む。 |
| リポジトリ | コード一式を置く GitHub 上の保管場所。 |
| データモデル | 「どんな情報を、どんな形で保存するか」の設計図。 |
| enum（列挙型） | 決まった選択肢だけを持てる型。例：タスクの状態「未完・完了・一部」。 |
| App Group | 本体アプリとウィジェットなどがデータを共有するための共有フォルダのような仕組み。 |
| ウィジェット | ホーム画面に置ける小さな表示パーツ。 |
| dateKey（日付キー） | `"2026-10-27"` のような文字列で日付を表す方法。時差のずれを防ぎやすい。 |

---

## 1. プロダクト概要

### 1-1. アプリの目的
紙のバレットジャーナルのような「手帳の気持ちよさ」を、**30 秒で記録が終わる手軽さ**で毎日の生活に届けること。
「ちゃんと書かなきゃ」というプレッシャーをなくし、**書かない日があっても続けられる**デジタル手帳をつくります。

### 1-2. 想定ユーザー
- 紙の手帳やバレットジャーナルに憧れるが、毎日きれいに書くのは続かなかった人
- 多機能なメモ・手帳アプリが「重い」と感じる人
- 気分（Mood）や睡眠（Sleep）、習慣（Habit）を、ゆるく記録したい人
- iPad mini などで「本のように見開きで」手帳を見たい人（将来）

### 1-3. コアバリュー（このアプリが約束すること）
1. **30 秒で記録完了**：一言日記・Mood・Sleep・Habit を 1 か所でさっと入力できる。
2. **毎日書かなくていい**：空いている日があっても責めない。連続記録（ストリーク）で追い立てない。
3. **シンプルだけど自由**：普段は Monthly だけで完結。書きたい日だけ Daily で深く書ける。

### 1-4. 差別化ポイント
- **Monthly 中心**：多くの日記アプリは「1 日 1 ページ」が前提。Easy Journal は「月 1 枚」が主役で、Daily はおまけ（任意）。
- **バレットジャーナル式のタスク記号**：□ 未完 / ■ 完了 / ◧ 一部進捗 / □> ◧> 翌日へ繰越。紙の手帳の記法をそのまま使える。
- **繰越すると翌日の Daily が自動でできる**：手で書き写す手間がない。でも前の日の記録は残る。
- **紙の手帳らしい見た目**：温かいオフホワイト、落ち着いたグリーン/グレー、方眼。
- **iPad で見開き**（将来）：左に Monthly、右に Daily のような「本」の体験。
- **余計なものがない**：SNS・共有・ランキングなし。自分のためだけの手帳。

---

## 2. 開発ロードマップ

> 方針：**小さく作って、早く自分の iPhone で触る**。Mac がないので「GitHub Actions でビルド → TestFlight で実機確認」の流れを最初に作ります。

### Phase 0：準備（開発の土台づくり）
目的：「コードを書いたら自動でビルドされ、自分の iPhone で動く」状態を作る。アプリの中身はほぼ空でよい。

- Apple Developer Program に登録（有料・年額。実機テストと App Store 公開に必要）【要確認：現在の価格】
- GitHub リポジトリ作成
- XcodeGen 設定（`project.yml`）で空のアプリを作る
- GitHub Actions でシミュレーター向けビルド＋テスト
- シミュレーターのスクリーンショットを自動で保存（Mac がなくても画面を目で確認できるように）
- 署名と TestFlight へのアップロードを自動化
- 「Hello Easy Journal」が自分の iPhone で開ける

### Phase 1：MVP（最初の公開版）
目的：Monthly 中心で毎日使える最小のジャーナル。

- Monthly Log（1 日 1 行の一言日記・予定・要約）
- Monthly Task
- Habit Tracker（月ごとの習慣チェック）
- Sleep / Mood Tracker
- 「今日の記録」クイック入力シート（30 秒記録の入口）
- Daily Log（+Daily で作成、上部 Task List［折りたたみ可］、下部メモ）
- タスク状態管理（未完 / 完了 / 一部進捗 / 翌日繰越）
- 繰越時の翌日 Daily 自動作成
- ページ一覧（Index）と基本ナビゲーション
- 紙の手帳風デザイン（背景オフホワイト・方眼 固定）
- 日本語 / 英語
- iPhone 前提（iPad では iPhone 版の画面をそのまま表示）

### Phase 2：使い心地の向上と iPad
- iPad 見開き表示（左右 2 ページ）
- 用紙スタイル選択（方眼 / 横線 / 無地）、背景（白 / オフホワイト / 黒）、文字色
- ホーム画面ウィジェット（今日のタスク表示・当日 Daily を開く）
- 未完タスクの「まとめて繰越」
- Monthly Task の翌月繰越
- データの書き出し（JSON などのバックアップ）
- ダークモードの調整

### Phase 3：拡張
- 片側ページ固定（例：左 Monthly 固定・右 Daily をめくる）
- ウィジェットからのタスク完了チェック・クイック追加（App Intents）
- ロック画面ウィジェット・ショートカット連携
- iCloud 同期
- PDF 出力 / 印刷 / 冊子化（半月・1 か月単位）
- ペン入力（Apple Pencil）、音声入力、写真添付
- ブロックの自由配置

> Phase 2・3 は「やりたいことリスト」です。MVP の利用状況を見て、順番を入れ替えてよいものです。

---

## 3. MVP 仕様書

### 3-1. 機能一覧

| No | 機能 | 内容 | MVP |
|---|---|---|---|
| F1 | Monthly Log | その月の日付が 1 日 1 行で並ぶ。各行に短い文章（予定・一言日記・要約）を書ける | ○ |
| F2 | Monthly Task | その月のタスク一覧。状態は □ / ◧ / ■ | ○ |
| F3 | Habit Tracker | 月ごとに習慣を設定（最大 8 個を推奨）。日付 × 習慣のマス目をタップでチェック | ○ |
| F4 | Mood Tracker | 1 日 1 つ、5 段階の気分 | ○ |
| F5 | Sleep Tracker | 1 日 1 つ、睡眠時間（0.5 時間きざみ） | ○ |
| F6 | 今日の記録シート | 一言日記・Mood・Sleep・Habit を 1 画面で入力（30 秒記録） | ○ |
| F7 | Daily Log | +Daily で作成。上部 Task List（折りたたみ可）、下部 自由メモ（テキスト） | ○ |
| F8 | タスク状態管理 | 未完 / 完了 / 一部進捗 / 翌日繰越 | ○ |
| F9 | Daily 自動作成 | 繰越先の翌日 Daily がなければ自動で作る | ○ |
| F10 | タスク履歴 | 状態の変化と繰越の流れを記録し、タスク詳細で見られる | ○（簡易表示） |
| F11 | Index（ページ一覧） | 左上メニューから月・Daily の一覧を開き、ジャンプできる | ○ |
| F12 | 設定 | 週の始まり（日/月）、言語は端末設定に従う、アプリ情報 | ○（最小） |
| — | 用紙・背景・文字色の選択 | データには項目だけ用意し、画面は Phase 2 | × |
| — | iPad 見開き / ウィジェット / 同期 / PDF / ペン / 写真 / 音声 | 将来 | × |
| — | 共有・SNS・アカウント | **作らない** | × |

**あえて入れないもの（続けやすさのため）**
- 連続記録日数（ストリーク）や「今日まだ書いていません」という催促通知
- 書かなかった日を目立たせる表示（空欄はただの空欄として静かに表示）

### 3-2. 各画面の役割

| 画面 | 役割 |
|---|---|
| Monthly（左ページ：Log + Task） | 月全体の見渡し。毎日の一言を書く場所。アプリを開いたら最初にここ（今月）が出る |
| Monthly（右ページ：Habit + Sleep/Mood） | 習慣・睡眠・気分を月単位で見る・付ける |
| 今日の記録シート | 30 秒で今日の分を全部入力する入口 |
| Daily Log | 書きたい日だけ使う詳しいページ。タスクとメモ |
| タスク詳細シート | 状態の変更、繰越、履歴の確認 |
| Index（ページ一覧） | 好きな月・Daily へジャンプ |
| Habit 編集 | その月の習慣の追加・並べ替え・削除 |
| 設定 | 最小限の設定 |

### 3-3. ユーザーフロー

**フロー A：毎日の 30 秒記録（一番大事）**
1. アプリを開く → 今月の Monthly（今日の行が見える位置）
2. 「今日を記録」ボタン（または今日の行）をタップ → 今日の記録シート
3. 一言を書く → Mood をタップ → Sleep を選ぶ → Habit をチェック
4. 「完了」→ Monthly に反映。ここで終わり。

**フロー B：詳しく書きたい日**
1. Monthly の「+Daily」をタップ
2. 今日の Daily がなければ作成、あれば開く
3. Task List にタスクを追加 / メモを書く

**フロー C：過去・未来の日の Daily**
1. Monthly の日付部分をタップ
2. Daily があれば開く。なければ「この日の Daily を作る」ボタンだけの空ページを表示 → タップで作成
   （空の Daily が勝手に増えないようにするため）

**フロー D：タスクの繰越**
1. Daily のタスクの記号をタップ → □ → ◧ → ■ → □ と順番に切り替わる
2. 長押し（またはタスク詳細）→「翌日へ繰越」
3. 元のタスクは □> / ◧> 表示になり、翌日の Daily にタスクがコピーされる（翌日 Daily がなければ自動作成）

**フロー E：ページ移動**
1. 左上メニュー → Index
2. 月を選ぶ / Daily を選ぶ / 「今日へ」 → ジャンプ

**フロー F：月が変わったとき**
1. 新しい月を初めて開くと、その月の Monthly を自動作成
2. 習慣は「前の月の習慣を引き継ぐ」（設定でオフ可にするかは未決）

### 3-4. タスク状態遷移

**状態の持ち方（シンプルにするため 2 つの情報に分ける）**
- `progress`（進み具合）：`open`（未完 □） / `partial`（一部 ◧） / `done`（完了 ■）
- `isCarriedForward`（繰越済みか）：`true` なら記号の横に `>` を付ける

| 表示 | progress | isCarriedForward |
|---|---|---|
| □ | open | false |
| ◧ | partial | false |
| ■ | done | false |
| □> | open | true |
| ◧> | partial | true |
| ■> | （作らない：完了したものは繰越できない） | — |

**状態遷移図（テキスト版）**

```
          タップ          タップ          タップ
   [□ 未完] ───▶ [◧ 一部] ───▶ [■ 完了] ───▶ [□ 未完]（戻る）

   [□ 未完] ──「翌日へ繰越」──▶ [□> 繰越済み]  ＋ 翌日Dailyに [□ 未完] のコピー
   [◧ 一部] ──「翌日へ繰越」──▶ [◧> 繰越済み]  ＋ 翌日Dailyに [◧ 一部] のコピー

   [□>] / [◧>] ──「繰越を取り消す」──▶ 元の [□] / [◧] に戻る
                                       （翌日側のコピーが未変更なら削除。変更済みなら残す）
```

**ルール**
- 繰越済み（`>` 付き）のタスクは、その日の中では「終わった扱い」。記号タップで状態は変えられない（取り消しのみ）。
- 繰越でできた翌日のタスクは、元タスクへのつながり（`carriedFromTaskID`）を持つ。何度繰り越しても、たどれば最初のタスクまで戻れる。
- 状態が変わるたびに TaskHistory（履歴）を 1 件追加する。
- 完了 ■ のタスクは繰越メニューを出さない。
- Monthly Task の繰越（翌月へ）は Phase 2。MVP では □ / ◧ / ■ のみ。

### 3-5. Daily 自動作成ルール

| きっかけ | 対象日 | Daily がない時 | Daily がある時 |
|---|---|---|---|
| 「+Daily」ボタン | 今日 | 作成して開く | そのまま開く |
| Monthly の日付タップ | タップした日 | 「この日の Daily を作る」ボタン付きの空画面を表示（押したら作成） | 開く |
| タスクの繰越 | **元タスクがある Daily の日付の翌日** | 自動作成し、タスクを追加 | そのタスク一覧の末尾に追加 |
| Index | — | （作成はしない） | 開く |

**共通ルール**
- 1 つの日付に Daily は **1 枚だけ**（同じ日付の Daily を 2 枚作らない）。作る前に必ず「あるか」を確認する。
- Daily を作ると、その日付が属する月の Monthly Page とリンク（PageLink）する。その月の Monthly がまだなければ Monthly も作る。
- 自動作成された Daily は「繰越で作られた」ことを記録しておく（`createdBy = .carryOver`）。中身が繰越タスクだけでも普通の Daily として扱う。
- 日付は端末のカレンダー・タイムゾーンで「年-月-日」に変換した `dateKey` で判定する（時刻は使わない）。
- 【未決】古い Daily（例：3 日前）から繰り越すとき、「その翌日（2 日前）」に送るか「今日」に送るか。MVP は仕様どおり「翌日」とし、利用してみて見直す。

---

## 4. 画面設計

> デザインの方向性：紙の手帳感 / 温かいオフホワイト / 落ち着いたグリーン・グレー / 方眼 / ミニマル / 可愛すぎない / 海外でも通用する

### 4-0. 共通デザイン（デザイントークン案）
「デザイントークン」とは、色や余白を名前つきで 1 か所にまとめたものです。あとから一括で変えられます。

| 名前 | 用途 | 値（仮） |
|---|---|---|
| paper | 紙の背景 | オフホワイト `#F7F4EC` 付近 |
| ink | 文字 | 濃いグレー `#2F3430` 付近 |
| inkSub | 補助文字・日付 | グレー `#8A8F88` 付近 |
| accent | ボタン・チェック | 落ち着いたグリーン `#5E7D63` 付近 |
| grid | 方眼の線 | 薄いグレーグリーン（透明度低め） |
| 方眼サイズ | 方眼 1 マス | 20pt 前後 |
| 文字 | 本文 | システムフォント（日本語の読みやすさ優先）。見出しだけセリフ体も検討 |

- 色は実機で見て調整。数値は仮です。
- 文字サイズは iOS の「文字を大きく」設定（Dynamic Type）に追従させる。

### 4-1. Monthly Log 画面（iPhone）

iPhone では **2 ページを横スワイプで切り替え** ます（紙の見開きの左ページ・右ページに対応）。

**左ページ：Monthly Log + Monthly Task**

```
┌─────────────────────────────┐
│ ☰   2026年 10月  ◀ ▶      +Daily │ ← ☰=Index / 月移動 / +Daily
├─────────────────────────────┤
│ ● ○   (左ページ / 右ページ)          │ ← ページ位置の点
├─────────────────────────────┤
│ MONTHLY LOG                          │
│ 1 木 │ 歯医者 15:00                  │
│ 2 金 │                               │ ← 空欄は空欄のまま（責めない）
│ 3 土 │ 雨。家で読書。                 │
│ …                                    │
│27 火 │ 設計資料をつくった 📄          │ ← 📄= Dailyあり の小さな印
│      │ （今日の行は薄いグリーンの帯） │
│ …                                    │
│31 土 │                               │
├─────────────────────────────┤
│ MONTHLY TASK                     ＋  │
│ □ 年賀状の準備                        │
│ ◧ 部屋の片付け                        │
│ ■ 保険の更新                          │
├─────────────────────────────┤
│        [ 今日を記録 ]                 │ ← 30秒記録シートを開く（下に固定）
└─────────────────────────────┘
```

操作
- 行の **文章部分をタップ** → その場で 1 行編集（キーボード表示）。
- 行の **日付部分をタップ** → その日の Daily へ（なければ作成ボタンのある画面）。
- **◀** で前の月、**▶** で次の月。12月の次は翌年1月、1月の前は前年12月。開いている月は Router だけが持つ。◀▶ も、Index やリンクなど外からの依頼も、同じ順で片付ける。削除の確認、タスク欄の未確定、一言日記の保存、移る先を保存して読めたときだけ、Router の月を変える。失敗したら Router は変えず、今の月と下書きを残して理由を出す。開いた月の Monthly が無ければ作る。すでにあればそれを使う。空にして消す下書きは、確認を出して止める。確認なしでは消さない。タスク追加欄に未確定の文字があるときは、一言日記の保存や編集終了より前に止め、両方の下書きを残す。止めたときだけ「タスクを追加するか、入力を消してから月を移動してください」と出す。止めたあと入力を消すと、一言日記を編集中ならその欄に焦点が戻る。外からの入口は月を直接変えず、開く依頼だけを出す。移動が成功した画面だけが作る承諾の値が無いと、表示月は変わりません。起動時と `-openPage` だけは、最初の月を直接開きます。確認が出ているあいだの依頼は、理由を出して動きません。画面が出る前の依頼は、画面が現れたときに同じ手順で片付けます。（T-114。日付タップと Daily は、まだ別タスク）
- 開いた時、今日の行が見える位置まで自動スクロール。
- 1 行は短い前提（目安 40〜60 文字）。長い文章は Daily へ誘導（「続きは Daily に」リンク）。【未決：文字数上限を設けるか】
- 祝日表示は MVP では行わない（日本以外の地域もあるため）。土日は文字色を少し変える程度。

**右ページ：Habit Tracker + Sleep / Mood**

```
┌─────────────────────────────┐
│ ☰   2026年 10月  ◀ ▶      +Daily │
│ ○ ●                                  │
├─────────────────────────────┤
│ HABIT              [編集]            │
│      読 運 水 早 英                   │ ← 習慣の頭文字/アイコン（列）
│ 1 木 ■ □ ■ □ □                       │
│ 2 金 □ □ □ □ □                       │
│ …                                    │
│27 火 ■ ■ □ ■ □   ← 今日の行          │
├─────────────────────────────┤
│ SLEEP / MOOD                         │
│      睡眠       気分                  │
│ 1 木 7.0h ▮▮▮▮▮▮▮  🙂                │
│ 2 金 5.5h ▮▮▮▮▮    😐                │
│ …                                    │
├─────────────────────────────┤
│        [ 今日を記録 ]                 │
└─────────────────────────────┘
```

- Habit のマスはタップで切り替え（□ ⇄ ■）。誤タップ防止のため、**今日以外の日**は長押しで変更、などは【未決】。
- Sleep は小さな横棒グラフ、Mood は 5 段階のシンプルな記号（顔アイコンか、色の丸か）【未決：絵文字は国やOSで見た目が変わるので、自作アイコンの方が手帳らしい】。
- 習慣は横に並ぶので、iPhone では **最大 8 個** を推奨上限にする（画面幅の都合）。

### 4-2. 今日の記録シート（30 秒記録）

```
┌─────────────────────────────┐
│ 10月27日（火）              [完了] │
├─────────────────────────────┤
│ 一言                                  │
│ [ 設計資料をつくった            ]     │
│                                      │
│ 気分   ①  ②  ③  ④  ⑤               │ ← 1タップ
│ 睡眠   [ − ]  7.0 時間  [ ＋ ]        │ ← 0.5h きざみ。前日と同じ値を初期表示
│ 習慣   [読書✓] [運動 ] [水2L✓] …     │ ← チップをタップ
│                                      │
│  詳しく書く → Daily を開く            │
└─────────────────────────────┘
```

- 下から出るシート（ハーフシート）。どれか 1 つだけ入力して閉じても OK。
- 入力はその場で保存（「保存」ボタンを押し忘れても消えない）。
- 日付を左右に切り替えて、昨日の分を後から書ける。

### 4-3. Daily Log 画面

```
┌─────────────────────────────┐
│ ‹ 10月      10月27日（火）    ⋯   │ ← 戻る=Monthly / ⋯=メニュー
├─────────────────────────────┤
│ ▼ TASKS (2/4)                 ＋    │ ← タップで折りたたみ/展開
│ ■ 設計資料の章立て                    │
│ ◧ データモデル案                      │
│ □> 画面のラフ          (→ 10/28)      │ ← 繰越済み。薄く表示
│ □ App Store文言                       │
├─────────────────────────────┤
│ ┌┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┐         │
│ ├ 自由メモ（方眼の背景）──────┤         │
│ │ 今日は設計を進めた。             │    │
│ │ ・Monthly中心がやっぱり良い      │    │
│ │                                │    │
│ └┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┘         │
└─────────────────────────────┘
```

**Task List**
- 折りたたむと「▶ TASKS (2/4)」の 1 行だけ（完了数/全体数）。折りたたみ状態はページごとに保存。
- 記号タップ：□ → ◧ → ■ → □。
- 長押し（コンテキストメニュー）：「翌日へ繰越」「編集」「削除」「履歴を見る」。
- 繰越済みタスクには繰越先の日付を小さく表示し、タップで翌日 Daily へ。
- 繰越されてきたタスクには「← 10/26 から」と小さく表示。
- 並べ替え：MVP は追加順。ドラッグ並べ替えは Phase 2【未決】。

**メモエリア**
- MVP はテキストのみ（SwiftUI の `TextEditor` 相当）。自動保存。
- 背景は MVP では「オフホワイト + 方眼」固定。ただしデータには `paperStyle` / `background` / `textColor` を持たせ、Phase 2 で選べるようにする。
- 注意：方眼の線と文字の行をぴったり合わせるのは難しい。MVP は「背景として方眼を描くだけ」で、行揃えはしない。

**⋯ メニュー**：前の日 / 次の日の Daily へ、この Daily を削除（確認あり）。

### 4-4. ページ一覧 / Index

```
┌─────────────────────────────┐
│ INDEX                       [閉じる] │
├─────────────────────────────┤
│ [ 今日へ ]                            │
│                                      │
│ 2026                                 │
│ ▼ 10月  Monthly                      │
│     📄 10/27 (火)  タスク 2/4         │
│     📄 10/25 (日)                     │
│     📄 10/12 (月)                     │
│ ▶ 9月   Monthly   (Daily 3)           │
│ ▶ 8月   Monthly   (Daily 0)           │
│                                      │
│ ⚙ 設定                               │
└─────────────────────────────┘
```

- 左上 ☰ で開く（iPhone は左から出るシートまたは全画面シート）。
- 月は新しい順。月を開くとその月の Daily 一覧。
- 「他ページ」（将来の自由ページ・コレクションなど）用に、一覧の仕組みは `Page` 共通で作っておく。MVP では Monthly と Daily のみ。
- 検索は MVP では入れない（Phase 2 候補）。
- **月は自由に閲覧できるが、Index には記録のある月だけを表示する。** ◀▶ で存在しない月を開くと、今までどおり月ページを作る。Index では、完全に空の月は出さない。一言日記、Monthly Task、Habit、Sleep、Mood、Daily のどれかがあれば出す。中身が空の MonthlyPage が保存されているだけでは出さない。今月は、記録が無くても Index から開ける。Index の画面自体は、まだ作らない。判定だけ `IndexMonthList` に置いてある。

### 4-5. iPad 見開き構想（Phase 2 以降。MVP は構造だけ用意）

```
┌────────────────────────┬────────────────────────┐
│ 左ページ                │ 右ページ                │
│ MONTHLY LOG             │ HABIT                   │
│ MONTHLY TASK            │ SLEEP / MOOD            │
└────────────────────────┴────────────────────────┘
  ▲ 月を見るとき：Monthly の左右を見開きで

┌────────────────────────┬────────────────────────┐
│ 左：Monthly（固定📌）   │ 右：Daily 10/27         │
│                        │  ← めくると 10/28 へ    │
└────────────────────────┴────────────────────────┘
  ▲ Phase 3：片側ページ固定
```

**将来対応しやすくするための設計（MVP から守ること）**
1. **ページ部品を「1 ページ分」で作る**：`MonthlyLogPageView`（左）、`MonthlyTrackerPageView`（右）、`DailyPageView` を、それぞれ単独で表示できる部品にする。iPhone は 1 つずつ、iPad は 2 つ並べるだけで済む。
2. **「何を表示するか」を値で表す**：`PageRef`（例：`.monthlyLog(month)`, `.monthlyTracker(month)`, `.daily(dateKey)`）という小さな型で表示中のページを表す。見開きは `Spread(left: PageRef?, right: PageRef?)`、片側固定は `pinned: Side?` を足すだけにする。
3. **画面幅で切り替える**：横幅が広い（`horizontalSizeClass == .regular`）なら見開き、狭いなら 1 ページ。iPad mini や折りたたみ端末のような中間サイズは、横向き時だけ見開き、などを実機で調整【未決】。
4. ナビゲーション（どのページを開いているか）を 1 か所（`Router`）で管理する。

---

## 5. データモデル案

### 5-1. 基本方針
- **保存は SwiftData を推奨**（比較は 6-3）。
- **日付は `dateKey`（"yyyy-MM-dd" の文字列）で持つ**。`Date`（時刻つき）だけで判定すると、タイムゾーンや夏時間で「別の日」と判定されるバグが起きやすいため。月は `monthKey`（"yyyy-MM"）。
- **将来の iCloud 同期に備えて**：SwiftData + CloudKit 同期では「ユニーク制約（`@Attribute(.unique)`）が使えない」「プロパティは省略可能（Optional）かデフォルト値が必要」「リレーションは Optional が必要」といった制限がある、と言われています【要確認】。そのため **最初からユニーク制約は使わず、"1 日 1 枚" はアプリのコード側で保証** し、全プロパティにデフォルト値を付けます。
- **`Task` という名前は使わない**：Swift には並行処理用の `Task` という同名の型があり、AI が書くコードで衝突・混乱しやすい。コード上は `JournalTask` とします。
- SwiftData の「クラスの継承」は対応 iOS バージョンが新しい【要確認】ため使わず、`Page`（共通の見出し情報）＋ `MonthlyPage` / `DailyPage`（中身）という **組み合わせ方式** にします。

### 5-2. モデル一覧と関係

```
Journal（ジャーナル本体。MVPでは1冊だけ）
 └─ Page（全ページ共通の「目次カード」）kind = monthly / daily / (将来: custom)
      ├─ MonthlyPage（月の中身）
      │    ├─ MonthlyLogLine（1日1行の文章）×日数分（書いた日だけ作る）
      │    ├─ JournalTask（Monthly Task）
      │    └─ Habit（その月の習慣の定義）
      └─ DailyPage（日の中身）
           ├─ JournalTask（Daily の Task List）
           └─ メモ本文
PageLink（ページ同士のつながり：Daily → Monthly など）
HabitEntry（習慣 × 日付 のチェック）
MoodEntry / SleepEntry（日付ごとの記録）
TaskHistory（タスクの状態変化・繰越の履歴）
```

> 要求リストにある 10 個（Journal, Page, DailyPage, MonthlyPage, Task, HabitEntry, MoodEntry, SleepEntry, PageLink, TaskHistory）に加え、必要最小限として **Habit**（習慣の定義）と **MonthlyLogLine**（1 日 1 行）を足しています。

### 5-3. Swift 構造体風の定義（骨組み）

> ここは「形の例」です。実際の SwiftData では `@Model final class` で書きます。細かい書き方は Codie が最新の公式ドキュメントで確認してください【要確認】。

```swift
// MARK: - 選択肢（enum）

enum PageKind: String, Codable { case monthly, daily /* 将来: custom */ }

enum TaskProgress: String, Codable {
    case open      // □ 未完
    case partial   // ◧ 一部進捗
    case done      // ■ 完了
}

enum TaskScope: String, Codable { case monthly, daily }

enum PageCreatedBy: String, Codable { case user, carryOver, system }

enum PaperStyle: String, Codable { case grid, lined, plain }        // 方眼/横線/無地
enum PaperBackground: String, Codable { case white, offWhite, black }

enum TaskHistoryAction: String, Codable {
    case created, progressChanged, carriedForward, carryCancelled, edited, deleted
}

enum PageLinkType: String, Codable {
    case dailyToMonthly   // Daily → その月の Monthly
    case carryOver        // 繰越元 Daily → 繰越先 Daily
}

// MARK: - モデル

struct Journal {
    var id: UUID = UUID()
    var title: String = "My Journal"
    var weekStartsOnMonday: Bool = true
    var createdAt: Date = .now
    // pages: [Page]
}

struct Page {                         // 全ページ共通の「目次カード」
    var id: UUID = UUID()
    var kind: PageKind = .daily
    var dateKey: String? = nil        // daily: "2026-10-27"
    var monthKey: String = ""         // 両方: "2026-10"（Indexでのまとめ用）
    var createdBy: PageCreatedBy = .user
    var createdAt: Date = .now
    var updatedAt: Date = .now
    // journal: Journal?
    // monthly: MonthlyPage?   （kind == .monthly のとき）
    // daily: DailyPage?       （kind == .daily のとき）
}

struct MonthlyPage {
    var id: UUID = UUID()
    var monthKey: String = ""         // "2026-10"
    var reflection: String = ""       // 軽い振り返り（月末用、任意）
    // page: Page?
    // logLines: [MonthlyLogLine]
    // tasks: [JournalTask]   （scope == .monthly）
    // habits: [Habit]
}

struct MonthlyLogLine {               // 1日1行
    var id: UUID = UUID()
    var dateKey: String = ""          // "2026-10-27"
    var text: String = ""
    var updatedAt: Date = .now
    // monthly: MonthlyPage?
}

struct DailyPage {
    var id: UUID = UUID()
    var dateKey: String = ""          // "2026-10-27"（1日1枚はコード側で保証）
    var memo: String = ""             // MVPはテキストのみ
    var isTaskListCollapsed: Bool = false
    var paperStyle: PaperStyle = .grid            // MVPは固定値、Phase2で選択
    var background: PaperBackground = .offWhite
    var textColorHex: String? = nil               // nil = 標準の文字色
    // page: Page?
    // tasks: [JournalTask]   （scope == .daily）
    // 将来: attachments（写真・音声・手書き）
}

struct JournalTask {                  // 要求の「Task」
    var id: UUID = UUID()
    var title: String = ""
    var scope: TaskScope = .daily
    var progress: TaskProgress = .open
    var isCarriedForward: Bool = false   // true なら「>」表示
    var carriedFromTaskID: UUID? = nil   // 繰越元タスク
    var carriedToTaskID: UUID? = nil     // 繰越先タスク
    var sortOrder: Int = 0
    var createdAt: Date = .now
    var completedAt: Date? = nil
    // daily: DailyPage? / monthly: MonthlyPage?（どちらか一方）
    // history: [TaskHistory]
}

struct TaskHistory {
    var id: UUID = UUID()
    var taskID: UUID = UUID()
    var action: TaskHistoryAction = .created
    var fromProgress: TaskProgress? = nil
    var toProgress: TaskProgress? = nil
    var relatedTaskID: UUID? = nil    // 繰越先/元のタスク
    var relatedDateKey: String? = nil // 繰越先の日付など
    var at: Date = .now
}

struct Habit {                        // 習慣の定義（月ごと）
    var id: UUID = UUID()
    var name: String = ""
    var shortLabel: String = ""       // 列見出し用の1〜2文字 or アイコン名
    var colorHex: String? = nil
    var sortOrder: Int = 0
    var carriedFromHabitID: UUID? = nil  // 前月から引き継いだ元
    // monthly: MonthlyPage?
}

struct HabitEntry {
    var id: UUID = UUID()
    var habitID: UUID = UUID()
    var dateKey: String = ""
    var isDone: Bool = true           // 記録があれば基本 true。外したら削除でもよい
    var updatedAt: Date = .now
}

struct MoodEntry {
    var id: UUID = UUID()
    var dateKey: String = ""          // 1日1件（コード側で保証）
    var level: Int = 3                // 1〜5
    var note: String? = nil           // 将来用
    var updatedAt: Date = .now
}

struct SleepEntry {
    var id: UUID = UUID()
    var dateKey: String = ""          // 「起きた日」で記録する（下記ルール）
    var hours: Double = 0             // 0.5 きざみ
    var quality: Int? = nil           // 将来用（1〜5）
    var updatedAt: Date = .now
}

struct PageLink {
    var id: UUID = UUID()
    var fromPageID: UUID = UUID()
    var toPageID: UUID = UUID()
    var type: PageLinkType = .dailyToMonthly
    var createdAt: Date = .now
}
```

### 5-4. JSON 風の例（イメージ）

```json
{
  "page": { "kind": "daily", "dateKey": "2026-10-27", "monthKey": "2026-10", "createdBy": "user" },
  "daily": {
    "memo": "今日は設計を進めた。",
    "isTaskListCollapsed": false,
    "paperStyle": "grid",
    "tasks": [
      { "title": "画面のラフ", "progress": "open", "isCarriedForward": true,
        "carriedToTaskID": "B-…" }
    ]
  },
  "links": [ { "type": "dailyToMonthly", "to": "Page(2026-10 monthly)" } ]
}
```

### 5-5. データのルール（大事なところ）
- **1 日 1 枚**：`DailyPage`・`MoodEntry`・`SleepEntry`・`MonthlyLogLine` は同じ `dateKey` で 2 件作らない。作成・保存はすべて「探す → なければ作る」関数（例：`findOrCreateDaily(dateKey:)`）を通す。画面から直接作らない。
- **1 か月 1 枚**：`MonthlyPage` も同様（`findOrCreateMonthly(monthKey:)`）。
- **睡眠の日付**：「起きた日」の日付で記録する（10/26 夜に寝て 10/27 朝起きた → 10/27）。画面に一言説明を出す。
- **Mood / Sleep / HabitEntry を `dateKey` 単位で独立させる理由**：Daily を作らなくても記録できるようにするため（毎日書かなくても成立）。またウィジェットやグラフから扱いやすい。
- **削除**：Daily を削除しても Mood / Sleep / Habit / Monthly Log の 1 行は消さない（別の記録だから）。Daily 内のタスクは削除。繰越のつながりは相手側の ID を `nil` にする。
- **履歴**：TaskHistory は追記のみ（書き換えない）。

### 5-6. 将来拡張のための余白
- `PageKind` に `custom` を足せば、自由ページ（コレクション、読書リストなど）を Index に並べられる。
- `DailyPage` に `attachments` を足せば写真・音声・手書きに対応できる（手書きは PencilKit のデータを保存する形が候補【要確認】）。
- PDF 出力は「ページ部品（View）をそのまま PDF に描く」方式が候補（SwiftUI の `ImageRenderer` など【要確認】）。Daily は「上部 Task List・下部メモ」の順を守っておけば、メモ量に応じてページ分割する処理を後から足せる。

---

## 6. 実装方針

### 6-1. 開発環境の前提と、全体の流れ

Jun は Mac も Xcode も使えないため、**「Windows で書く → GitHub に送る → GitHub Actions の Mac でビルド・テスト → TestFlight で自分の iPhone に入れて確認」** という流れにします。

```
[Windows + Antigravity]       [GitHub]                   [GitHub Actions (macOS)]        [Jun の iPhone]
 Codie がコードを書く  ──push──▶ PR を作る  ──自動──▶ ビルド / テスト / 画面写真  ──▶  (main に取り込み後)
 Jun が PR を確認       ◀──結果・スクショ──                                     TestFlight 配信 ──▶ 実機で確認
```

**Mac がないことで起きる制約（先に知っておくこと）**
- Xcode の「プレビュー」（コードを書きながら画面を見る機能）は使えない → **CI でシミュレーターのスクリーンショットを撮って、PR に添付（Artifacts）** して確認する。
- 無料の「自分の iPhone に直接インストール」は Mac + Xcode が必要 → **Apple Developer Program（有料）+ TestFlight** を使う。
- 証明書（署名に必要なファイル）は通常 Mac で作るが、App Store Connect API キーと fastlane などのツールを使えば CI 上で作成・管理できる【要確認：手順は Codie が最新情報で確認】。
- エラーの原因が分かりにくいので、**1 回の変更を小さく**する（=チケットを小さくする理由）。
- GitHub Actions の macOS 実行は、非公開リポジトリだと無料枠の消費が大きい（Linux より何倍も多くカウントされる）【要確認：現在の料金と無料枠】。不要な実行を減らす設定（PR とmain だけで動かす、ドキュメントだけの変更では動かさない）を入れる。

### 6-2. 技術選定（おすすめ）

| 項目 | おすすめ | 理由・メモ |
|---|---|---|
| 言語 | Swift | iOS の標準。 |
| UI | **SwiftUI** | コードだけで画面が作れ、Xcode の画面操作（Storyboard）が不要。iPad 対応もしやすい。 |
| 最低 iOS バージョン | **iOS 18 を推奨**（iOS 17 も可） | SwiftData と新しい状態管理（`@Observable`）は iOS 17 から使えるとされる。iOS 17 の SwiftData は初期の不具合報告が多かったため、安定性を重視して iOS 18 を推奨【要確認：各機能の対応バージョン、利用者の iOS 普及率】。 |
| 保存 | **SwiftData**（ただし「保存係」の層で包む） | 下の比較表を参照。 |
| 状態管理 | `@Observable`（Observation）+ SwiftData の `@Query` | 6-4 を参照。 |
| プロジェクト管理 | **XcodeGen**（`project.yml` から `.xcodeproj` を生成） | 設定が文字だけのファイルなので、Windows でも AI でも編集できる。`.xcodeproj` は CI で毎回生成し、Git には入れない。Tuist という別の選択肢もあるが、初心者には XcodeGen の方が覚えることが少ない。 |
| ビルド | GitHub Actions `macos-26` ランナー + `xcodebuild` | 2026-10 時点で `macos-26` に Xcode 26 系が入っている（runner-images の README より）。**Xcode のバージョンは明示的に固定**する（勝手に変わるとビルドが壊れることがある）。 |
| 配信 | fastlane（または xcodebuild + App Store Connect API）→ TestFlight | API キーは GitHub の Secrets（秘密の値を安全に置く場所）に保存。 |
| Swift の言語モード | まず Swift 5 モード → 慣れたら Swift 6 へ | Swift 6 は並行処理のチェックが厳しく、初心者 + AI だとコンパイルエラーで詰まりやすい【未決】。 |
| 外部ライブラリ | **MVP では使わない**（XcodeGen・fastlane などの開発ツールは除く） | 依存を減らし、壊れる場所を減らす。 |
| 多言語 | String Catalog（`Localizable.xcstrings`）で日本語・英語 | XcodeGen 構成で問題なく扱えるか【要確認】。 |

> App Store に提出するアプリは、Apple が指定する新しい SDK（Xcode）でビルドする必要がある【要確認：2026 年時点の要件】。CI の Xcode を固定しつつ、年に 1 回程度は更新する前提にします。

### 6-3. 保存方法の比較

| 候補 | 良いところ | 気になるところ | 判定 |
|---|---|---|---|
| **SwiftData** | Apple 標準。SwiftUI と相性が良い（`@Query` で自動更新）。コード量が少ない。将来 iCloud 同期（CloudKit）やウィジェットとの共有（App Group）に道がある。 | 比較的新しく、OS バージョンによって挙動差や不具合の報告がある。iCloud 同期には制限（ユニーク制約不可など）がある【要確認】。 | **推奨** |
| Core Data | 歴史が長く安定。情報が多い。iCloud 同期の実績も多い。 | 書き方が古く、コード量が多い。初心者と AI にはミスが増えやすい。 | 次点（SwiftData で困った時の逃げ道） |
| SQLite + GRDB など | 速い・細かく制御できる・SQL で調べやすい。 | 外部ライブラリが必要。iCloud 同期は自作になる。設計の負担が大きい。 | 今回は不採用 |
| JSON ファイル保存 | 仕組みが一番単純。中身を目で見られる。 | データが増えると遅い。一部だけ更新しにくい。同時書き込みに弱い。 | バックアップ（書き出し）用として Phase 2 で使う |
| UserDefaults | 簡単。 | 設定値向け。日記データには不向き。 | 設定値だけに使う |

**推奨のしかた**：SwiftData を使うが、画面から SwiftData を直接いじる場所を最小限にし、**`JournalStore`（保存係）** に「Daily を探す/作る」「タスクを繰り越す」などの操作をまとめます。こうすると、
- ルール（1 日 1 枚、繰越の処理）が 1 か所にまとまり、テストしやすい
- 万一 SwiftData から Core Data などに移る時も、変更範囲が小さい
- ウィジェットからも同じ保存係を使える

### 6-4. 状態管理の考え方

「状態」とは、画面に表示するためにアプリが覚えている情報のことです。3 種類に分けます。

1. **保存するデータ**（日記・タスク・習慣など）→ SwiftData。画面は `@Query` で読み、変更は `JournalStore` 経由で行う。
2. **画面の一時的な状態**（シートが開いているか、編集中の文字など）→ その画面の `@State`。
3. **アプリ全体のナビゲーション**（今どのページを開いているか）→ `@Observable` な `Router`（道案内係）1 つで管理。`PageRef` の配列で表す（iPad の見開きにもそのまま使える）。

**ルール（ビジネスロジック）は「純粋な関数」に分ける**
- 例：`DateKey.next(of:)`（翌日の dateKey）、`TaskRules.nextProgress(_:)`（□→◧→■→□）、`TaskRules.canCarryForward(_:)`。
- 保存に依存しないので、テストが簡単で、AI が書いても間違いに気づきやすい。

```swift
// 骨組みの例（中身は Codie が実装）
enum PageRef: Hashable {
    case monthlyLog(monthKey: String)
    case monthlyTracker(monthKey: String)
    case daily(dateKey: String)
}

@Observable final class Router {
    var current: PageRef = .monthlyLog(monthKey: DateKey.currentMonth())
    var isIndexPresented = false
    // 将来（iPad）: var spread: Spread? / var pinned: Side?
}

protocol JournalStore {
    func findOrCreateMonthly(monthKey: String) throws -> MonthlyPageModel
    func findDaily(dateKey: String) throws -> DailyPageModel?
    func findOrCreateDaily(dateKey: String, createdBy: PageCreatedBy) throws -> DailyPageModel
    func cycleProgress(of task: JournalTaskModel) throws
    func carryForward(_ task: JournalTaskModel) throws -> JournalTaskModel   // 翌日Dailyのコピーを返す
    func cancelCarryForward(_ task: JournalTaskModel) throws
    func setMood(dateKey: String, level: Int?) throws
    func setSleep(dateKey: String, hours: Double?) throws
    func toggleHabit(habitID: UUID, dateKey: String) throws
    func setLogLine(dateKey: String, text: String) throws
}
```

### 6-5. 将来の Widget 連携を考えた構成
- **保存場所を最初から App Group の共有コンテナにする**（あとから場所を移すとデータ移行が必要になるため）【要確認：SwiftData の保存先を App Group に指定する方法】。App Group の ID は Phase 0 で決めて登録する。
- モデル定義・`JournalStore`・日付ルールは **アプリ本体とウィジェットの両方から使える場所**（共有フォルダ or ローカル Swift Package `JournalCore`）に置く。
- 画面から「今日の Daily を開く」などに使える **URL（ディープリンク）** を最初から決めておく。例：`easyjournal://daily/today`、`easyjournal://daily/2026-10-27`、`easyjournal://monthly/2026-10`。ウィジェットやショートカットはこの URL を開くだけで済む。
- タスク完了などの操作は、将来 App Intents（ウィジェットのボタンやショートカットから呼べる「アプリの操作」）から `JournalStore` を呼ぶ形にする【要確認：対応 iOS バージョン】。

### 6-6. ディレクトリ構成案

```
easy-journal/
├─ project.yml                  # XcodeGen の設定（ターゲット、iOSバージョン、Bundle IDなど）
├─ README.md                    # ビルド方法・ルール（初心者向け）
├─ docs/
│   └─ easy-journal-design.md   # この文書
├─ App/
│   ├─ EasyJournalApp.swift     # アプリの入口
│   ├─ Info.plist（必要なら）
│   └─ Resources/
│       ├─ Assets.xcassets      # 色・アイコン
│       └─ Localizable.xcstrings
├─ Sources/
│   ├─ Core/                    # ★ウィジェットとも共有する部分
│   │   ├─ Models/              # SwiftData のモデル
│   │   ├─ Store/               # JournalStore（保存係）
│   │   └─ Rules/               # DateKey, TaskRules など純粋なルール
│   ├─ Features/
│   │   ├─ Monthly/             # MonthlyLogPageView, MonthlyTrackerPageView
│   │   ├─ Daily/               # DailyPageView, TaskListSection, MemoSection
│   │   ├─ QuickEntry/          # 今日の記録シート
│   │   ├─ Index/               # ページ一覧
│   │   ├─ Habit/               # 習慣の編集
│   │   └─ Settings/
│   ├─ Navigation/              # Router, PageRef, DeepLink
│   └─ DesignSystem/            # 色・フォント・方眼背景・タスク記号の部品
├─ Tests/
│   ├─ CoreTests/               # ルールと保存係のテスト（最重要）
│   └─ UITests/                 # スクリーンショット撮影用の最小 UI テスト
├─ fastlane/                    # TestFlight 配信設定（Phase 0 後半）
└─ .github/workflows/
    ├─ ci.yml                   # PR ごと: 生成 → ビルド → テスト → スクショ
    └─ testflight.yml           # main/タグ: 署名 → TestFlight へアップロード
```

- `.xcodeproj` は CI で `xcodegen generate` して作るので Git に入れない（`.gitignore`）。
- 将来ウィジェットを足す時は `Widgets/` フォルダと `project.yml` にターゲットを 1 つ追加する。

### 6-7. 「画面を目で確認する」仕組み（Mac なし対策）
- アプリに **起動オプション**（例：`-sampleData`、`-openPage daily:2026-10-27`）を用意し、決まったサンプルデータ・決まった画面で起動できるようにする。
- CI でシミュレーターを起動 → 各画面のスクリーンショットを撮る → GitHub Actions の Artifacts（成果物の置き場）に保存。Jun は PR からダウンロードして見る。
- 撮影方法は UI テスト（XCUITest）の添付機能か、`xcrun simctl io booted screenshot` が候補【要確認】。
- 撮る画面（固定）：Monthly 左 / Monthly 右 / 今日の記録シート / Daily（展開・折りたたみ）/ Index。iPhone の小さい画面と大きい画面の 2 機種。

### 6-8. テスト方針
- **必ずテストするもの**：日付キー（月末・年末・うるう年）、タスク状態の切り替え、繰越（翌日 Daily がある/ない、取り消し、2 回繰越）、1 日 1 枚の保証、Daily 削除時に Mood などが残ること。
- 保存係のテストは「メモリ上だけの SwiftData」（保存ファイルを作らない設定）で行う【要確認：設定方法】。
- 画面のテストはスクリーンショット撮影程度にとどめる（壊れやすいため）。

---

## 7. App Store 訴求ポイント

### 7-1. 訴求ポイント（5 個）

1. **30 秒で、今日がおわる。**
   一言・気分・睡眠・習慣を 1 画面でさっと記録。
2. **毎日書かなくていい手帳。**
   空いた日も、そのままで大丈夫。催促も連続記録のプレッシャーもありません。
3. **Monthly が主役、Daily はお好みで。**
   月の 1 ページで暮らしを見渡し、書きたい日だけ Daily を開く。
4. **バレットジャーナルのタスク記法。**
   □ ◧ ■ と繰越 >。繰り越すと翌日のページが自動で用意されます。
5. **紙の手帳みたいな、落ち着いたデザイン。**
   オフホワイトと方眼、静かなグリーン。長く使える、シンプルな見た目。（iPad 見開きは今後対応予定と書く場合は、出す時期が決まってから）

### 7-2. 短いコピー案

| 用途 | English | 日本語 |
|---|---|---|
| メイン | Write Freely. Track Effortlessly. | 自由に書いて、かんたんに記録。 |
| 30 秒 | Your day, logged in 30 seconds. | 30秒で、今日を記録。 |
| 続けやすさ | No streaks. No pressure. Just your journal. | 連続記録も、プレッシャーもない手帳。 |
| 続けやすさ | Skip a day. Your journal waits. | 書かない日があっても、大丈夫。 |
| Monthly | One page a month. Daily when you want. | 月に1ページ。Dailyは書きたい日だけ。 |
| タスク | Bullet-journal tasks that carry over for you. | 繰り越しも、翌日のページも自動で。 |
| デザイン | The calm feel of a paper planner. | 紙の手帳の、落ち着いた書き心地。 |
| サブタイトル候補（30 文字以内【要確認】） | Simple monthly bullet journal | ゆるく続く、マンスリー手帳 |

- 「プライバシー：データは端末内に保存、アカウント不要」も訴求になる（MVP は外部送信なし）。App Store のプライバシー表示（「データの収集なし」）の扱いは提出時に確認【要確認】。

---

## 8. 実装チケット一覧（AI が 1 つずつ実装する単位）

**チケットの約束**
- 1 チケット = 1 つの PR。できるだけ小さく（目安：変更ファイル数個、半日以内で終わる量）。
- 「完了条件」をすべて満たしたら完了。CI（自動ビルド・テスト）が緑（成功）であることは **全チケット共通の完了条件**。
- 画面を変えるチケットは、CI のスクリーンショットを PR に添付（またはリンク）して Jun が目で確認する。
- 依存：先に終わっている必要があるチケット。

### Phase 0：土台づくり

**T-001 リポジトリの初期化**
- 作業：GitHub リポジトリ作成、`README.md`、`.gitignore`（`.xcodeproj`、`DerivedData`、ビルド成果物、秘密情報を除外）、`docs/` にこの設計資料を置く。
- 完了条件：README に「このアプリは何か」「ビルドは GitHub Actions で行う」「ブランチと PR のルール」が書かれている。
- 依存：なし

**T-002 XcodeGen で空のアプリを作る**
- 作業：`project.yml` を作成（アプリ名、Bundle ID［例：`com.<名前>.easyjournal`］、最低 iOS バージョン、iPhone のみ、Swift バージョン）。`App/EasyJournalApp.swift` に「Easy Journal」と表示するだけの画面。
- 完了条件：`xcodegen generate` で `.xcodeproj` が生成される手順が README にある。
- 依存：T-001

**T-003 CI：シミュレーター向けビルドとテスト**
- 作業：`.github/workflows/ci.yml` を作成。`macos-26` ランナー、Xcode バージョン固定、XcodeGen のインストール → 生成 → `xcodebuild build` と `xcodebuild test`。空のテストを 1 つ用意。PR と main への push のときだけ動く。`docs/` だけの変更では動かない。
- 完了条件：PR を作ると CI が動き、成功する。失敗した時にログのどこを見ればよいか README に書いてある。
- 依存：T-002

**T-004 CI：スクリーンショットを Artifacts に保存**
- 作業：シミュレーターでアプリを起動し、画面写真を撮って Artifacts にアップロードする手順を CI に追加。起動オプションの受け取り口（`-sampleData` など、まだ中身は空でよい）を用意。
- 完了条件：PR の CI 結果から PNG をダウンロードでき、「Easy Journal」の画面が写っている。
- 依存：T-003

**T-005 署名と TestFlight 配信（Jun の作業を含む）**
- 作業：Jun が Apple Developer Program 登録・App Store Connect でアプリ登録・API キー発行を行う（Codie は手順書を `docs/release.md` に書く）。CI 側は fastlane などで証明書・プロファイルを用意し、ビルドして TestFlight にアップロードする `testflight.yml` を作成。秘密の値はすべて GitHub Secrets。
- 完了条件：手動実行（workflow_dispatch）で TestFlight にビルドが届き、Jun の iPhone で起動できる。秘密情報がリポジトリに含まれていない。
- 依存：T-003
- 注意：ここが一番つまずきやすい。うまくいかなければ先に T-101 以降の開発を進め、並行で解決してよい。

**T-006 App Group と保存場所の準備**
- 作業：App Group ID を決めて `project.yml` の entitlements（アプリに許可する機能の宣言）に追加。SwiftData の保存先を App Group 内にする準備。
- 完了条件：CI ビルドが通る。保存先の決め方がコードコメントと README に書いてある。
- 依存：T-002（署名が必要な部分は T-005 後に確認）

### Phase 1：MVP

**基礎（ルール・データ）**

**T-101 デザイントークンと方眼背景**
- 作業：`DesignSystem/` に色（paper, ink, inkSub, accent, grid）、余白、フォント、方眼背景 View（`GridPaperBackground`）を作る。
- 完了条件：サンプル画面に方眼背景とオフホワイトが表示されたスクショがある。
- 依存：T-004

**T-102 日付キーのルール（DateKey）**
- 作業：`Date` ⇄ `"yyyy-MM-dd"` / `"yyyy-MM"` の変換、翌日、前日、その月の日数、月の日付一覧、曜日。暦はグレゴリオ暦固定、タイムゾーンは端末設定。
- 完了条件：月末・年末（12/31→1/1）・うるう年（2/29）・各月の日数のテストが通る。
- 依存：T-003

**T-103 タスク状態のルール（TaskRules）**
- 作業：`TaskProgress`、記号の決定（□ ◧ ■ □> ◧>）、タップ時の次の状態、繰越できるかの判定。
- 完了条件：3-4 の表のとおりにテストが通る（完了は繰越不可、繰越済みはタップで変わらない など）。
- 依存：T-003

**T-104 SwiftData モデルの定義**
- 作業：5-3 のモデルを `@Model` で定義（`Journal`, `Page`, `MonthlyPage`, `MonthlyLogLine`, `DailyPage`, `JournalTask`, `TaskHistory`, `Habit`, `HabitEntry`, `MoodEntry`, `SleepEntry`, `PageLink`）。全プロパティにデフォルト値、ユニーク制約は使わない。`ModelContainer` を App で作成。
- 完了条件：アプリが起動し、テストで各モデルを 1 件ずつ保存・読み込みできる。
- 依存：T-006, T-102

**T-105 JournalStore：ページを探す / 作る**
- 作業：`findOrCreateMonthly`、`findDaily`、`findOrCreateDaily`（Monthly も必要なら作成、PageLink 作成）。初回起動時に Journal を 1 冊作成。
- 完了条件：同じ日付で 2 回呼んでも Daily が 1 枚だけのテスト、Daily 作成で Monthly と PageLink ができるテストが通る。
- 依存：T-104

**T-106 JournalStore：日ごとの記録**
- 作業：`setLogLine`、`setMood`、`setSleep`、`toggleHabit`（いずれも「1 日 1 件」を保証。値を消したら削除）。
- 完了条件：上書き・削除・1 日 1 件のテストが通る。
- 依存：T-105

**T-107 JournalStore：タスク操作と履歴**
- 作業：タスク追加・編集・削除・`cycleProgress`。すべての変化で TaskHistory を追加。
- 完了条件：状態変更ごとに履歴が 1 件増えるテストが通る。
- 依存：T-103, T-105

**T-108 JournalStore：繰越と取り消し**
- 作業：`carryForward`（翌日 Daily を findOrCreate、`createdBy = .carryOver`、コピー作成、双方向の ID、PageLink(carryOver)、履歴）、`cancelCarryForward`（3-4 のルール）。
- 完了条件：翌日 Daily がない/あるの両方、2 回連続の繰越、取り消し（翌日側が未変更/変更済み）のテストが通る。
- 依存：T-107

**T-109 サンプルデータと起動オプション**
- 作業：`-sampleData` で 1 か月分のサンプル（空いた日もある）を入れる。`-openPage <PageRef>` で指定画面から起動。CI のスクショ撮影対象を 6-7 のリストに更新（画面ができた順に追加）。
- 完了条件：サンプルデータ入りでアプリが起動するスクショがある。
- 依存：T-105, T-004

**ナビゲーション**

**T-110 Router と PageRef、ディープリンク**
- 作業：`PageRef`、`Router`、`easyjournal://` の URL 解析（今日の Daily / 指定日 / 指定月）。起動時は今月の Monthly。
- 完了条件：URL → PageRef 変換のテストが通る。起動すると今月の Monthly（仮画面）が出る。
- 依存：T-102

**Monthly**

**T-111 Monthly 左ページ：Monthly Log の表示**
- 作業：日付 1 行ずつの一覧、今日の行の強調、土日の色、Daily がある日の印、今日の位置まで自動スクロール。上部バー（☰、月表示、◀▶、+Daily はボタンだけ）。
- 完了条件：サンプルデータで 1 か月分が表示されたスクショ（iPhone 小・大）。
- 依存：T-101, T-109, T-110

**T-112 Monthly Log の 1 行編集**
- 作業：文章部分タップでその場で編集、自動保存（`setLogLine`）。
- 完了条件：編集して別の行へ移っても保存されている（テストまたは UI テスト）。
- 依存：T-111, T-106

**T-113 Monthly Task**
- 作業：左ページ下部に Monthly Task の一覧・追加・記号タップで状態切り替え・削除。
- 完了条件：□◧■ が並んだスクショ。状態変更で履歴が残る。
- 依存：T-111, T-107

**T-114 月の移動と新しい月の作成**
- 作業：◀▶ で前後の月へ。開いた月の Monthly がなければ作成。
- 完了条件：12 月→1 月の移動で年が変わる。存在しない月を開くと作成される。
- 実装メモ：ページの作成は、すでにある `findOrCreateMonthly` だけ。同じ月は増やさない。習慣のコピーは T-116 までしない。編集中に移るときは、T-113 の `MonthlyTaskActionRule` と同じく、保存か読み込みに失敗したら移動を中止する。データモデルと保存のしくみは変えていない。開いている月は Router だけ。◀▶ と外からの依頼は、同じ確認と保存の成功後にだけ Router を変える。成功した移動が作る承諾の値が無いと、表示月は変わらない。失敗したら今の月と下書きを残す。タスク欄の未確定は、一言日記を保存するより前に止める。月の画面が出たあとの直接の月変更は、依頼になる。画面が出る前の依頼は、画面が現れたときに同じ手順で片付ける。
- 依存：T-111

**T-115 Monthly 右ページ：Habit Tracker**
- 作業：横スワイプで右ページへ（ページ位置の点を表示）。日付 × 習慣のマス目、タップでチェック。
- 完了条件：サンプルデータでマスが埋まったスクショ。タップで保存される。
- 依存：T-111, T-106

**T-116 Habit の編集と前月からの引き継ぎ**
- 作業：習慣の追加・名前変更・並べ替え・削除（最大 8 個）。新しい月を作る時、前月の習慣をコピー。
- 完了条件：新しい月に前月の習慣が引き継がれるテストが通る。9 個目は追加できない。
- 依存：T-115, T-114

**T-117 Sleep / Mood の月表示**
- 作業：右ページ下部に睡眠（時間＋小さな棒）と気分（5 段階の記号）を日付ごとに表示。
- 完了条件：サンプルデータのスクショ。データがない日は空欄。
- 依存：T-115

**30 秒記録**

**T-118 今日の記録シート**
- 作業：4-2 のハーフシート（一言・Mood・Sleep・Habit）。入力ごとに即保存。日付の左右切り替え。Sleep の初期値は前日の値。
- 完了条件：シートで入力 → 閉じる → Monthly の左右ページに反映されている。スクショあり。
- 依存：T-112, T-115, T-117

**Daily**

**T-119 Daily 画面の骨組みと作成導線**
- 作業：`DailyPageView`（上部 Task 領域・下部メモ領域・方眼背景）。+Daily（今日を findOrCreate）。Monthly の日付タップで Daily へ（なければ「この日の Daily を作る」ボタン画面）。戻るで Monthly。
- 完了条件：3-5 の表のうち +Daily・日付タップの行どおりに動く（テスト＋スクショ）。
- 依存：T-111, T-105

**T-120 Daily のメモ入力**
- 作業：テキストのメモ、自動保存。キーボードで隠れないようにする。
- 完了条件：入力して画面を離れ、戻っても残っている。
- 依存：T-119

**T-121 Daily の Task List**
- 作業：タスク追加・編集・削除・記号タップ、折りたたみ/展開（状態をページに保存）、「完了数/全体数」表示。
- 完了条件：展開・折りたたみ両方のスクショ。
- 依存：T-119, T-107

**T-122 繰越の画面操作**
- 作業：長押しメニュー「翌日へ繰越」「繰越を取り消す」。繰越済みは薄く表示＋繰越先の日付、タップで翌日へ。繰越されてきたタスクに「← 元の日付」表示。
- 完了条件：繰越 → 翌日 Daily が自動作成されタスクが入っているスクショ。取り消しで元に戻る。
- 依存：T-121, T-108

**T-123 タスク詳細と履歴表示**
- 作業：タスク詳細シート（タイトル編集、状態、履歴の一覧：いつ何が起きたか、繰越の流れ）。
- 完了条件：2 回繰り越したタスクの履歴が時系列で表示されたスクショ。
- 依存：T-122

**T-124 Daily の前後移動と削除**
- 作業：⋯ メニューから前日・翌日の Daily へ（なければ作成ボタン画面）、Daily 削除（確認ダイアログ。Mood などは残す）。
- 完了条件：削除後も Mood / Sleep / Habit / Monthly Log が残るテストが通る。
- 依存：T-121

**Index・設定・仕上げ**

**T-125 Index（ページ一覧）**
- 作業：☰ で開く一覧（今日へ、年 → 月 → Daily、タスク完了数）。タップでジャンプ。
- 方針：月は ◀▶ で自由に開ける。Index には記録のある月だけを出す。一言日記、Monthly Task、Habit、Sleep、Mood、Daily のどれかがあれば出す。空の MonthlyPage だけでは出さない。今月は記録が無くても出す。◀▶ が空の月ページを作る仕様は変えない。
- 完了条件：サンプルデータで複数月が並んだスクショ。ジャンプ先が正しい。空の月は一覧に無い。今月は記録が無くても開ける。
- 依存：T-110, T-119

**T-126 設定画面（最小）**
- 作業：週の始まり（日/月）、アプリのバージョン、プライバシーについての一文（データは端末内）。
- 完了条件：週の始まりの変更が Monthly の表示に反映される（必要な範囲で）。
- 依存：T-125

**T-127 日本語 / 英語対応**
- 作業：画面の文字を String Catalog に移し、英語訳を追加。日付表示は端末の言語・地域に合わせる。
- 完了条件：英語設定のシミュレーターでのスクショ。日本語が残っていない。
- 依存：T-118, T-125（画面がそろってから）

**T-128 アクセシビリティと文字サイズ**
- 作業：VoiceOver 用のラベル（例：「未完」「完了」と読み上げ）、文字を大きくした時のレイアウト崩れ確認。
- 完了条件：大きい文字サイズでのスクショで重要な情報が切れていない。
- 依存：T-127

**T-129 アプリアイコンと起動画面**
- 作業：アイコン（オフホワイト × グリーン、手帳モチーフ）、起動時の背景色。
- 完了条件：ホーム画面のアイコンが TestFlight 版で表示される。
- 依存：T-005

**T-130 MVP 総点検と App Store 提出準備**
- 作業：3 章の機能一覧の確認、TestFlight で Jun が 1 週間使う、App Store 用スクショ・説明文（7 章）・プライバシー情報・サポート URL の準備。
- 完了条件：チェックリスト（`docs/release-checklist.md`）がすべて埋まる。
- 依存：T-101〜T-129

### Phase 2 以降（チケット化は MVP 後）
iPad 見開き（`Spread` 導入）/ 用紙・背景・文字色の選択 / ウィジェット（今日のタスク・当日 Daily を開く）/ まとめて繰越 / Monthly Task の翌月繰越 / JSON 書き出し / ダークモード / 検索 など。

---

## 9. Codie への引き継ぎメモ

### 9-1. 最初に着手すべき順序
1. **T-001 → T-002 → T-003 → T-004**：まず「CI でビルド・テスト・スクショができる」状態を最優先。Jun は Mac がないので、これがないと何も確認できない。
2. **T-005（TestFlight）は Jun の手作業（Apple への登録など）が必要**。手順書を先に書いて渡し、Jun の準備待ちの間は T-101〜T-108 を進める。
3. **T-102 / T-103 / T-105〜T-108（ルールと保存係）を画面より先に**。テストで正しさを固めてから画面を作ると、画面側のバグが減る。
4. 画面は Monthly（T-111〜T-118）→ Daily（T-119〜T-124）→ Index・仕上げ（T-125〜）の順。「毎日使うところ」から作る。

### 9-2. 注意点
- **Jun は初心者**：PR の説明は「何を変えたか」「どう確認するか（どのスクショを見ればいいか）」をやさしい日本語で書く。専門用語には一言説明を付ける。
- **1 チケット 1 PR、小さく**。複数チケットをまとめない。完了条件にないことはしない（機能を盛らない）。
- **SNS・共有・アカウント・分析ツール・広告は入れない**。外部への通信も MVP ではしない。
- **Xcode の画面操作に頼らない**：設定はすべて `project.yml` とコードで行う。`.xcodeproj` を手で編集・コミットしない。Storyboard は使わない。
- **Xcode バージョンを CI で固定**し、変える時は専用の PR にする。
- **型名 `Task` は使わない**（Swift 標準の `Task` と衝突）。タスクは `JournalTask`。
- **日付は必ず `DateKey` 経由**。画面やモデルで直接 `Date` を比較して「同じ日か」を判定しない。
- **1 日 1 枚・1 か月 1 枚は JournalStore で保証**（ユニーク制約は将来の iCloud 同期のため使わない）。画面から直接 `insert` しない。
- **データを消す操作には確認**を入れる。モデルを変更する時は、既存データが壊れないか（マイグレーション＝データの引っ越し）を意識し、MVP 公開後のモデル変更は特に慎重に【要確認：SwiftData のマイグレーション方法】。
- **「書かない日」を責めない UI**：赤い警告・未記入の強調・ストリーク・催促通知を作らない。
- **不確かな API は推測で書かない**：対応 iOS バージョンや使い方が不確かなものは公式ドキュメントで確認し、分からなければ PR に「要確認」と書いて Jun に知らせる。
- **秘密情報（API キー・証明書・パスワード）をリポジトリや PR・ログに出さない**。GitHub Secrets を使う。
- GitHub Actions の macOS 実行時間を節約する（不要な実行を止める、キャッシュを使う）。

### 9-3. 未決事項（決める人：Jun。Codie は仮の値で進めてよいものは「仮」と明記）

| No | 未決事項 | 仮の案 |
|---|---|---|
| U-01 | 最低 iOS バージョン（17 か 18 か） | iOS 18（安定性重視）【要確認】 |
| U-02 | Swift の言語モード（5 か 6 か） | Swift 5 で開始 |
| U-03 | アプリ名「Easy Journal」が App Store で使えるか、正式名称 | 提出前に検索・確認 |
| U-04 | Bundle ID・App Group ID（あとから変えにくい） | `com.<Junの名前>.easyjournal` / `group.com.<…>.easyjournal` |
| U-05 | GitHub リポジトリを公開にするか非公開にするか（CI の料金に影響） | 非公開【要確認：macOS 実行の無料枠】 |
| U-06 | TestFlight 配信方法（fastlane か、xcodebuild + API 直か） | fastlane |
| U-07 | 古い Daily から繰り越す時の行き先（その翌日か、今日か） | 仕様どおり「翌日」 |
| U-08 | Monthly Log 1 行の文字数上限 | 上限なし・1〜2 行表示で省略 |
| U-09 | Mood の表現（絵文字 / 自作アイコン / 色の丸） | 自作の簡単な記号 |
| U-10 | Sleep の記録方法（時間のみ / 就寝・起床時刻） | 時間のみ（0.5h きざみ、起きた日に記録） |
| U-11 | Habit の上限数・過去日のチェック変更方法 | 最大 8 個・過去日もタップで変更可 |
| U-12 | 新しい月で習慣を自動で引き継ぐか（選べるようにするか） | 自動で引き継ぐ |
| U-13 | Daily タスクの並べ替え（MVP に入れるか） | MVP は追加順のみ |
| U-14 | 週の始まりの初期値 | 月曜 |
| U-15 | iPad mini・折りたたみ端末での見開き切り替え条件 | Phase 2 で実機確認して決定 |
| U-16 | 価格（無料 / 買い切り / 一部有料） | MVP は無料で検討 |
| U-17 | バックアップ（端末の iCloud バックアップ任せでよいか、書き出しをいつ入れるか） | MVP は端末バックアップ任せ、Phase 2 で JSON 書き出し |
| U-18 | デザインの最終的な色・フォント（見出しにセリフ体を使うか） | 4-0 の仮の値 |

### 9-4. 確認が必要な事実（【要確認】のまとめ）
- SwiftData・`@Observable`・App Intents・WidgetKit の各機能が使える iOS バージョン
- SwiftData のクラス継承の対応バージョン
- SwiftData + CloudKit 同期の制限（ユニーク制約不可、Optional 必須など）
- SwiftData の保存先を App Group に指定する方法、メモリ上だけで動かすテスト設定、マイグレーション方法
- GitHub Actions の macOS ランナーの Xcode バージョン（2026-10 時点では `macos-26` に Xcode 26 系。随時変わる）と料金・無料枠
- App Store 提出に必要な最低 Xcode / SDK バージョン
- Mac なしでの証明書・プロビジョニングプロファイル作成手順（fastlane + App Store Connect API キー）
- XcodeGen での String Catalog（`.xcstrings`）の扱い
- CI でのスクリーンショット撮影方法
- Apple Developer Program の現在の価格、App Store のサブタイトル文字数、プライバシー表示の扱い

---

*以上。この文書は「実装前の設計」です。作りながら分かったことは、この文書（`docs/easy-journal-design.md`）を更新して残してください。*
