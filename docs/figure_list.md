# 図のリスト（article_draft.md）

記事`docs/article_draft.md`の図の一覧と，これから撮影・差し替えが必要なものです．

- 図はすべて`docs/img/`にあります．作図した図の元のファイル（HTML）は`docs/img/src/`にあり，各ファイルの冒頭に，PNGに書き出すコマンドを書いています．
- 2026-11-23時点の作業用の表（プレースホルダの行番号，追加候補，撮影順の案）は，図がすべて入ったので削除しました（必要ならgitの履歴を参照）．

---

## 現状（2026-11-26）

図はすべて`docs/img/`にあり，記事に挿入済みです．記事では，図の下に「**図2.1-1** 説明」の形で番号と説明を付けています．

- **図番号は「節番号-節の中での通し番号」**です（コマンド例の番号と同じ付け方．付録A.6の図は「図A.6-1」）．図を追加しても，その節の番号を振り直すだけで済みます．
- 節の外（章の冒頭など）には図を置きません．4章冒頭にあった接続図は，4.1節に移しました．
- 本文から図を参照するときは，「図2.1-1のように」「[図1.3-1](#1-3)の①」のように番号で書きます．
- 「旧番号」は，2026-11-23時点の作業用の番号（図1〜9，C1〜C8）です．以前のメモや会話でこの番号が出てきたときの対応に使ってください．

| 記事の図番号 | 旧番号 | ファイル | 説明（記事のキャプション）・メモ |
|---|---|---|---|
| （なし） | タイトル | `title.png` | 記事冒頭のタイトル画像 |
| 図0.2-1 | — | `fig_flow_overview.png` | 今日の流れ（2章→3章・4章→5章）．元のファイルは`docs/img/src/fig_flow_overview.html` |
| 図1.3-1 | 1 | `frdm-mcxn947_parts_location.png` | FRDM-MCXN947で使う部品．本文は「図1.3-1の①」のように参照する |
| 図2.1-1 | 2 | `powershell.png` | スタートメニューから「Windows PowerShell」を開く |
| 図2.1-2 | 2 | `powershell_launched.png` | 起動したPowerShell（`C:\WINDOWS\system32`で開いた例） |
| 図2.1-3 | 3 | `activated.png` | コマンド例2.1-1の実行結果 |
| 図2.2-1 | — | `copying_sample.png` | サンプルを作業用フォルダにコピーして使う（macOSのFinderの画面） |
| 図2.2-2 | 4 | `usb_connected.jpg` | USBケーブルを図1.3-1の①につなぐ |
| 図2.2-3 | 5 | `teraterm.png` | デスクトップのTera Termのアイコン |
| 図2.2-4 | 5 | `teraterm_port.png` | 「新しい接続」でシリアルポートを選ぶ |
| 図2.2-5 | 5 | `teraterm_baud.png` | 「設定」→「シリアルポート」でスピードを115200にする（初期値は`9600`．会場PCでは`TERATERM.INI`を使わない） |
| 図2.2-6 | 6 | `hello_world.png` | Tera TermにHello Worldが表示された画面 |
| 図2.3-1 | C1 | `led_red.jpg` | blinkyでRGB LEDが赤く点滅する |
| 図2.4-1 | C8 | `fig_c8_blinky_devicetree.png` | blinkyでの，アプリケーション・デバイスツリー・Kconfig・ドライバの関係．元のファイルは`docs/img/src/fig_c8_blinky_devicetree.html`（作り直し方はファイル冒頭のコメント） |
| 図3.2-1 | — | `temperature.png` | Tera Termに温度が表示された画面 |
| 図3.3-1 | C5 | `fig_c5_devicetree_kconfig.png` | thermometerでの，アプリケーション・デバイスツリー・Kconfig・ドライバの関係．元のファイルがないため，「図1の④」を「図1.3-1の④」にする部分だけ重ね書きした（`docs/img/src/fig_c5_patch_fig_number.html`，元の画像は`fig_c5_devicetree_kconfig_orig.png`） |
| 図4.1-1 | 7 | `pc_and_board_connection.png` | PCとボードの接続とIPアドレス．元の画像`pc_and_board_connection_orig.png`に，ボード`192.168.1.100`とPC`192.168.1.x`を重ね書きした（`docs/img/src/pc_and_board_connection_ip.html`）．PC側の値は要確認リスト#44で決まったら書き換える |
| 図4.1-2 | C4 | `prj_conf_edit.png` | `prj.conf`の`MY_IPV4_ADDR`を書き換えて保存したところ（`MY_IPV4_GW`は元のまま．直結ではGatewayは不要なので撮り直さない） |
| 図4.1-3 | C3 | `ether_connected.jpg` | EthernetケーブルをボードのEthernetコネクタに挿す |
| 図4.1-4 | — | `ping.png` | `ping`の実行結果 |
| 図4.2-1 | 8 | `page_view.png` | ブラウザで開いたLED制御ページ（背景にTera TermとPowerShellが写っているので，必要ならトリミング） |
| 図4.2-2 | C2 | `led_green.jpg` | ブラウザの操作でRGB LEDが緑に光る |
| 図5.1-1 | C6 | `fig_c6_http_flow.png` | `/temperature`のページが温度を表示し，1秒ごとに更新する流れ |
| 図5.2-1 | 9 | `temp_on_browser.png` | ブラウザに表示された温度 |
| 図A.6-1 | C7 | `ip_address_setting.png` | Windowsの「設定」でEthernetを固定IPにする画面（PCのIP設定は要確認リスト#44） |

### リハーサルで撮影したい図（追加の候補）

| 入れる場所 | 内容 | 理由 |
|---|---|---|
| 4.3節 | ブラウザで`http://192.168.1.100/uptime`を開いた画面 | 「✔ ここまでできればOK」に成功時の見た目がない．表示の形式（ミリ秒の数値など）も本文に書ける |
| 2.2節（手順4） | `west flash`が成功したときのPowerShellの画面（最後の数行） | LinkServerのログは長く，成功か失敗か初めての人には判断しにくい |
| 2.2節（Tera Termの手順4） | Tera Term 5の「その他の設定」の「エンコーディング」タブで，受信をUTF-8にした画面 | 手順4に図がない．図2.2-5（シリアルポートタブ）と同じ画面なので続けて撮れる |

## テキストの出力例で，まだ差し替えが必要なもの

記事中の```text```ブロックのうち，会場PCで実際に出た内容に差し替えるものです．図の撮影と同じタイミングで記録しておくと効率的です．

| 節 | 探す文字列 | 差し替える内容 |
|---|---|---|
| 2.2 | `Memory region` | hello_worldのビルド成功時のメモリ使用量の表（`【会場PCでの実際の出力に差し替え】`） |
| 2.2，2.3，3.2，付録F | `v4.x.x` | 会場PCのZephyrのバージョン（スクリーンショットのPCは`v4.5.0-rc3-33-g0436e9d188e0`．会場で使う版を決めてから） |

`west --version`・`west topdir`（2.1節），thermometerの出力（3.2節），`ping`の出力（4.1節）は，スクリーンショットの内容に差し替え済みです．
