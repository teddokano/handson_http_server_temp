# 引き継ぎメモ (Claude Code セッション間)

このファイルは、このリポジトリ (`teddokano/handson_http_server_temp`) を
ベースディレクトリとして起動する **別セッションのClaude Code** への
引き継ぎ用メモです。前セッションはこのリポジトリを追加ディレクトリとして
触っていましたが、以降はこのリポジトリを起点にした新しいセッションに
作業を引き継ぎます。

作成日: 2026-08-17

---

## 1. このリポジトリは何か

Zephyrハンズオンセミナー「Zephyrデビュー会 〜FRDM-MCXN947でつまずかず動かす90分〜」用の
out-of-treeアプリと、そのセミナーの進行ガイド記事(ドラフト)を置いているリポジトリです。

- ボード: **FRDM-MCXN947** (`frdm_mcxn947/mcxn947/cpu0`)
- ベース: `zephyr/samples/net/sockets/http_server` (公式サンプル) に、
  `zephyr/samples/sensor/thermometer` の温度センサー(P3T1755, I3C接続)読み取りを
  統合し、`/temperature`・`/temperature.json` エンドポイントを追加したもの
- GitHub: https://github.com/teddokano/handson_http_server_temp (Public、`main`ブランチ)
- `gh auth status` は `teddokano` アカウントでログイン済み

Zephyrワークスペース本体は `~/zephyrproject`(`west topdir`)。
`~/zephyrproject/zephyr` が Zephyr本体、SDKは `~/zephyr-sdk-1.0.1` など。

## 2. リポジトリ構成

```
handson_http_server_temp/
├── CMakeLists.txt        # generate_inc_file_for_target・zephyr_linker_sources を追加済み
├── Kconfig                # NET_SAMPLE_* シンボル定義。無いとKconfig警告でビルド停止する
├── prj.conf                # 固定IP設定 (192.168.1.100) など
├── sections-rom.ld         # HTTP_RESOURCE_DEFINE() が使うiterableリンカセクション定義。必須
├── boards/frdm_mcxn947_mcxn947_cpu0.overlay  # P3T1755(I3C)センサーのDT定義
├── src/
│   ├── main.c             # /temperature, /temperature.json ハンドラを追加した本体
│   ├── ws.h                # WebSocket機能は無効化しているが、main.cが直接includeするため必要
│   └── static_web_resources/{index.html,main.js}  # トップページ(ビルド時にgzip化される)
├── docs/article_draft.md   # ハンズオン進行ガイド記事のドラフト(本題、詳細は3節)
└── HANDOFF.md              # このファイル
```

ビルド確認コマンド(実際にこのセッションで通っている):

```
cd ~/zephyrproject
west build -p auto -b frdm_mcxn947/mcxn947/cpu0 ~/dev/Zephyr/handson_http_server_temp -d ~/dev/Zephyr/handson_http_server_temp/build
```

**注意**: `build/` は `.gitignore` 済みだが、確認後は `rm -rf build` で
消しておく習慣にしていた(前セッションの流儀。必須ではない)。

### ハマったポイント(再発しやすいので記録)

- `sections-rom.ld` と `CMakeLists.txt` の `zephyr_linker_sources()`/
  `zephyr_linker_section_ifdef()` が無いと、`HTTP_RESOURCE_DEFINE()` が
  `_http_resource_desc_test_http_service_list_start` 等の未定義参照でリンクエラーになる。
  実際に一度外して再現・確認済み。
- out-of-treeアプリには独自の `Kconfig` が必要(`NET_SAMPLE_HTTP_SERVICE` 等の
  シンボルと `source "samples/net/common/Kconfig"` を用意しないと
  `ZVFS_OPEN_ADD_SIZE_NET_SAMPLE` 等が undefined symbol 警告でビルド停止する)。
- `main.c` は `ws.h` を無条件includeするので、WebSocketを使わない場合でも
  `ws.h` 自体は必要(`ws.c` は不要。`prj.conf`で`CONFIG_NET_SAMPLE_WEBSOCKET_SERVICE=n`
  を明示しないと `HTTP_SERVER_WEBSOCKET=y` から自動でyになりリンクエラーになる)。
- 固定IPは `192.168.1.100`。GWは `192.168.1.1` にしているが、
  PC-ボード直結構成では実質未使用(同一サブネットならARPで解決されルーティングされない)。
  一度、IPアドレスのタイポ(`192.0.1.100` と `192.168.1.100` の混同)でpingが通らない
  不具合があったので、固定IP設定を触るときは値を要確認。

## 3. `docs/article_draft.md` について(引き継ぎの本題)

このMarkdownは、著者(teddokano)がハンズオン当日の進行ガイド兼、
不参加者向けの再現可能な作業ガイドとして書いているブログ記事のドラフトです。
公開時はNXPコミュニティブログのHTML規約に変換される想定(ファイル冒頭のコメント参照)。

### 作業の進め方(これまでの前セッションでの実績)

著者が本文中に `<!-- CLAUDE: ... -->` という形式でレビューコメント/指示を
埋め込んでいきます。Claude Code側の作業は毎回:

1. ファイル全体から `<!-- CLAUDE: ... -->` コメントを拾う
2. 指示された内容を本文に反映する(加筆・書き換え・書式変更など)
3. **対応が終わったコメントは削除する**
4. `【 】` で囲われたプレースホルダのうち、`main.c` / `boards/*.overlay` / `prj.conf` など
   リポジトリの実物を見て埋められるものは埋める(例: ボードターゲット文字列、
   実際のDT定義、確認済みの実URLなど)
5. 実写真・実スクリーンショット・未公開URLなど、こちらで用意できない `【 】` は
   そのまま残す(埋めない)
6. ビルドが絡む変更をしていない限り、通常はドキュメントのみの変更なので
   `west build` の再確認は不要(このファイル自体はC/DTS/Kconfigに影響しない)
7. **コミット・pushは、ユーザーから明示的に指示されるまで行わない**
   (このリポジトリはPublicなGitHub repoなので、pushは「公開範囲に影響する操作」に相当する)

このサイクルを、著者が新しいレビューを書き足すたびに繰り返しています。
つまり **`<!-- CLAUDE: ... -->` コメントは今後も本文中に追加され続ける前提**です。
新しいセッションでも、まず `grep -n "CLAUDE" docs/article_draft.md` で
未処理のコメントがないか確認するところから始めてください。

### 現在の状態 (2026-08-17 時点)

直近のコミット (`git log` 参照):

```
06d8e18 article draft edit is in progress   (著者による作業中コミット、未pushの可能性あり要確認)
8645b49 ブログ記事ドラフトにCLAUDE向け指示を追加
87bf69a Show temperature with 3 decimal places
84894dd Initial commit
```

現在 `docs/article_draft.md` は **未コミットの変更あり**(`git status`で確認)。
著者が直接編集してCLAUDEコメントを追記した状態。

ファイル内、`### 2.3 Blinkyサンプルを書き込む` の直前に以下のマーカーコメントが
著者によって置かれている(このセッション時点で唯一まだ削除されていないCLAUDEコメント群の末尾):

```
<!-- CLAUDE:
************************************ チェックとコメント追加はここまで 2026-08-17
-->
```

これは「著者が本文の頭からここまでは新しいレビューコメントを書き終えた」という
区切りマーカーです。**この時点で未処理の `<!-- CLAUDE: ... -->` コメントが
chapter 0 〜 2.2 の範囲に複数残っています**(このメモ作成時点で少なくとも以下)。
指示の粒度がかなり細かくなってきているので、1件ずつ本文へ丁寧に反映してください。

- 0章: (処理済み・削除済み)
- 2.1節 (`### 2.1 環境の確認`) 内に複数の未処理コメントあり:
  - 「帰ってから自身の環境をセットアップするには」の情報を追加
    (公式ガイド: https://docs.zephyrproject.org/latest/develop/getting_started/index.html、
    NXPツールを使った簡単セットアップ: 著者提供のNXP Tech Blog記事URL、
    本文中に実際にURLが書かれているのでそのまま使ってよい)
  - 会場PCには公式ガイド通りのZephyrツールがコマンドライン中心でセットアップ済みで、
    MCUXpresso for VSCも使えるが、あえてベンダー非依存のコマンドラインで
    体験してもらう方針である旨を明記
  - 「叩く」という言葉を使わない、もう少しフォーマルな言い回しに修正
  - 記事内の全コマンドに、コマンド・オプションの解説を「本文の流れを乱さない別枠
    (quoteやコラム形式)」で用意する
  - ユーザーが再入力の手間を省けるよう、シェルスクリプトやコマンドエイリアスを
    用意しておく旨を追加(`【 】`プレースホルダとして残っている箇所)
- 2.2節 (`### 2.2 HelloWorldサンプルを実行してみる`、見出しが
  「書き込む」から「実行してみる」に著者によって変更されている点に注意) 内:
  - `-b`オプションの説明(ターゲット基板指定、FRDM-MCXN947がデュアルコアなので
    `frdm_mcxn947/mcxn947/cpu0`という指定が必要なこと、FRDM-MCXA153のような
    シングルコア機は`frdm_mcxa153`だけで済むこと、`frdm_mcxn947/mcxn947/cpu0`は
    `frdm_mcxn947//cpu0`と省略記法で書けること、その理由)、
    `-p`(pristine)オプションの説明、を別枠コラムに追加
  - ビルド成果物の場所についての解説を別枠で追加、`--pristine`オプションにも言及
  - シリアルコンソールを開く手順(CoolTermを使う、ポート指定・ボーレート設定)を追加
  - `hello_world/src/main.c`を受講者PCで開く方法を追加
  - `main.c`が「普通のC言語のHello Worldコード」であることを強調
    (`CONFIG_BOARD_TARGET`マクロ以外に特別なものはない、クロック設定や
    ペリフェラル初期化が無いことにも言及)
  - 次節(RTOSコードとの比較)の前振りとして「マイコンのコードっぽくない」に加え
    「RTOSのコードっぽくない」ことにも触れる
  - `main.c`以外に必要な最低限のファイル(`prj.conf`・`CMakeLists.txt`など)の説明を追加
- 2.3節導入部: これ以降のボードターゲット表記を `frdm_mcxn947/mcxn947/cpu0` から
  簡略形式 `frdm_mcxn947//cpu0` に統一する、という指示あり
  (本文中の既存コード例をこの表記に合わせて書き換える作業が必要)

上記より後ろ(2.4節〜6章)は前セッションで一通り処理済みで、CLAUDEコメントは
残っていない状態でした。ただし著者が今後さらにレビューを進める可能性が高いです。

### スタイル・トーンで学んだ著者の好み(今後も踏襲すること)

- 「叩く」のようなくだけた言い回しは避け、ややフォーマルな文体にする
- コマンドの解説は本文の流れを妨げないよう、`>` の引用ブロックや
  「コラム」形式の別枠に切り出す(これまでも「コラム: ○○」という見出しで
  何度か使っているパターンを踏襲すればよい)
- 実URLが本文中や著者コメント中に明記されている場合はそのまま使ってよいが、
  こちらで存在を確認できないURLは絶対に捏造しない(`【 】`プレースホルダのまま残す)
- ボード写真・スクリーンショット・画面キャプチャ等の実画像が必要な `【 】` は
  埋めずに残す(実行して撮影する必要があるため)
- 章・節番号やアンカーID(`<a id="...">`)は変更しない
- コード例やコマンド例は、実際にこのリポジトリの `main.c`/`overlay`/`prj.conf`の
  内容と食い違わないよう、常に実物を確認してから書く

## 4. スコープの確認

- 作業対象はこのリポジトリ (`~/dev/Zephyr/handson_http_server_temp`) のみ。
- `~/dev/Zephyr/ichigojam-firm` は無関係の別プロジェクト(IchigoJam_Z、M7: CVBS DMA実装)。
  誤って触らないこと。
- コミット・pushは、ユーザーから明示的な指示があるまで行わない
  (このリポジトリはPublic GitHub repoのため)。
