# 要確認リスト（リハーサルで実機確認する項目）

記事`article_draft.md`と`handson_tools/`のスクリプトのうち，**Zephyrのソースやリポジトリの実物で確認できず，記憶や推測で書いた記述**の一覧です．リハーサルで実際の画面と照らし合わせ，違っていたら記事を直してください．

- 「場所」の行番号は，2026-11-11時点の`article_draft.md`のものです．編集すると行番号がずれるので，「探す文字列」で検索してください．
- 優先度 **高** は，違っていると手順そのものが通らないもの．**中** は，受講者が画面と見比べて戸惑うもの．**低** は，説明の正確さの問題で，進行には影響しないもの．

## ソースで確認済みの記述（参考）

次の記述は，Zephyr本体（main）とhandson_http_server_tempリポジトリの実物で確認しています．ただし会場PCのZephyrのバージョンが古い場合は，内容が違うことがあります．

- blinkyの`SLEEP_TIME_MS 1000`，`DT_ALIAS(led0)`，シリアル出力`LED state: ON/OFF`
- blinkyの`boards/`にFRDM-MCXN947用のoverlayがないこと
- FRDM-MCXN947のdtsiで`led0 = &red_led`（GPIO0の10番ピン）
- 図C8（2.4節）の内容（Zephyr main 2026-11-03で確認）: blinkyの`prj.conf`は`CONFIG_GPIO=y`の1行．`red_led`は`frdm_mcxn947.dtsi`では`status = "disabled"`で，`frdm_mcxn947_mcxn947_cpu0.dtsi`の`&red_led { status = "okay"; }`で有効になる．`gpio0`は`nxp_mcxnx4x_common.dtsi`で`compatible = "nxp,kinetis-gpio"`．ドライバは`drivers/gpio/gpio_mcux.c`で，`CONFIG_GPIO_MCUX`は`DT_HAS_NXP_KINETIS_GPIO_ENABLED`のとき`default y`
- thermometerの出力`Thermometer Example (%s)`，`Temperature device is %p, name is %s`，`Temperature is %0.1lf°C`
- thermometerの`boards/`に`frdm_mcxn947_mcxn947_cpu0.overlay`があること
- `west flash`の書き込みツールの設定（board.cmakeにLinkServerの設定があること）
- handson_http_server_tempの`/temperature`・`/temperature.json`，1秒ごとの更新，`prj.conf`のIPアドレス`192.168.1.100`，`%.3f`と`toFixed(3)`の位置
- Zephyrが対応しているFRDM-MCXの基板名（付録Dの表）

---

## 高：手順が通らなくなるもの

| # | 場所 | 探す文字列 | 確認すること |
|---|---|---|---|
| 1 | 2.1節（267行付近） | `ZEPHYR_BASE`を設定しておくと | **ワークスペースの外（`~\handson\...`）で`west build`が使えるか．** 記事全体がこの前提で組んであります．`ZEPHYR_BASE`を設定すればwestがワークスペースを見つけられる，という動作を前提にしています．会場PCで，2.2節の手順どおりに`~\handson\hello_world`で`west build`が通ることを最優先で確認してください．通らない場合は手順の組み直しが必要です（例: 作業用フォルダを`~\zephyrproject`の中に置く） |
| 2 | 2.1節（コマンド例2.1-2） | `zinit thermometer` | `zinit`を実行したあと，プロンプトに`(.venv)`が付き，`west build`が使えるか．関数の中から`Activate.ps1`を読み込む形にしているので，Windows PowerShell 5.1の実機で確認が必要です．VSCodeのターミナルでも確認してください |
| 3 | 2.2節の手順2（394行付近） | `MCU-Link VCom Port` | ~~Tera Termの「新しい接続」のポート一覧で，基板がどう表示されるか．`venue_check.ps1`は，デバイス名に`MCU-Link`を含むCOMポートを探しています．名前が違えば，記事とスクリプトの両方を直してください~~ → **確認済み（スクリーンショット）: `COM6: MCU-Link VCom Port (COM6)`．名前は記事どおり．番号はPCによって異なる** |
| 4 | 2.2節の手順3（396行付近） | `現在の接続を再設定` | ~~Tera Termのシリアルポート設定画面のボタン名．会場PCのTera Termのバージョンで確認してください~~ → **確認済み（スクリーンショット）: Tera Term 5では「Tera Term: その他の設定」の「シリアルポート」タブで，ボタンは「OK」．記事に反映済み** |
| 5 | 2.2節の手順4（398行付近） | `漢字（受信）` | Tera Termの「設定」→「端末」での，受信の文字コードの項目名と選択肢．UTF-8にしたとき，3章の`°C`が正しく表示されるか |
| 6 | `venue_check.ps1` | `KanjiReceive` | ~~Tera Termの設定ファイル（`TERATERM.INI`）での受信文字コードのキー名と値，ファイルの置き場所（`%APPDATA%\teraterm5\`など）．違っていると，スクリプトが毎回「注意」を出します~~ → **不要: `TERATERM.INI`は配らないことにし，`venue_check.ps1`の設定ファイルの確認も削除した** |
| 7 | 4.1節（728行付近） | `基板側のコネクタのLED` | FRDM-MCXN947のEthernetコネクタに，リンク状態を示すLEDがあるか．なければこの確認項目を削除してください |
| 8 | 4.1節（730行付近） | `IPアドレスの表示が出ているか` | 4章のhttp_serverサンプルが，起動時にシリアルにIPアドレスなどを表示するか．表示しなければ，この確認項目を書き換えてください　※`page_view.png`の背景のTera Termには`<dbg>`のログと`uart:~$`しか見えない．IPアドレスが出なければ，この項目を「ログが流れているか」に書き換える |

## 中：受講者が画面と見比べて戸惑うもの

| # | 場所 | 探す文字列 | 確認すること |
|---|---|---|---|
| 9 | 2.1節（250行付近） | `West version: v1.x.x` | ~~`west --version`の実際の表示~~ → **確認済み（スクリーンショット）: `West version: v1.5.0`．`west topdir`は`C:/Users/Owner/zephyrproject`と`/`区切り．記事に反映済み** |
| 10 | 2.2節（362行付近） | `Memory region` | ~~ビルド成功時の出力の形式（メモリ使用量の表の項目，`IDT_LIST`の行があるか，最後の行）~~ → **一部確認（http_serverのスクリーンショット）: FLASH・RAM（320 KB）・SRAMX（96 KB）・IDT_LISTの4行．記事の形式に反映済み．hello_worldの数値は未記入** |
| 11 | 2.2節（383行付近） | `ボードのLEDが点灯して` | USBをつないだとき，電源が入ったことが分かるLEDが点灯するか |
| 12 | 2.2節（420行付近） | `*** Booting Zephyr OS build` | 起動メッセージの形式．Tera Termで改行が二重になったり，行頭がずれたりしないか（Tera Termの「改行コード（受信）」の設定） |
| 13 | 2.3節（482行付近） | `赤色で1秒ごとに` | blinkyで実際に赤く点滅するか（dtsi上は`led0`が赤ですが，実物で確認） |
| 14 | 3.2節（570〜578行付近） | `Thermometer Example (arm)` | ~~実際の出力．P3T1755のドライバがしきい値の設定に対応していれば，`Set temperature lower limit to ...`などの行も出ます．出る行に合わせて，出力例と説明を直してください~~ → **確認済み（スクリーンショット，v4.5.0-rc3）: しきい値の行は出ない．デバイス行は`0x1000b23c, name is p3t1755@4800000236152a0090`．記事に反映済み** |
| 15 | 3.2節（583行付近） | `Tera Term VT` | ~~接続中のTera Termのタイトルバーの表示~~ → **確認済み（スクリーンショット）: `COM6 - Tera Term VT`** |
| 16 | 4.1節（715行付近） | `TTL=64` | ~~Windowsの`ping`の出力．TTLの値，「損失」の行の書き方~~ → **確認済み（スクリーンショット）: `TTL=64`，損失の行のあとに「ラウンド トリップの概算時間」の2行．記事に反映済み** |
| 17 | 4.1節（727・732行付近） | `要求がタイムアウトしました`，`宛先ホストに到達できません` | ケーブルを抜いた状態，PCのIPを変えた状態でそれぞれ`ping`して，実際のメッセージを確認 |
| 18 | 4.2節（737行付近） | `点灯/消灯` | ~~ブラウザのボタン操作でどの色のLEDが反応するか~~ → **確認済み: 緑．記事に反映済み** |
| 19 | 4.2節（742行付近） | `接続がプライベートではありません` | `https://`で開いたときに，EdgeやChromeで実際に表示されるメッセージ |
| 20 | 5.2節（833行付近） | `Temperature: 24.312°C` | ~~ブラウザの実際の表示（見出しの文字列，`← Back`のリンク）~~ → **確認済み（スクリーンショット）: 見出し`Hello FRDM-MCXN947 temp sensor: P3T1755`，`Temperature: 24.812°C`，`← Back`** |
| 21 | 5.2節（844行付近） | `404 Not Found` | 4章のサンプルが書き込まれた状態で`/temperature`を開いたときの，実際の表示 |
| 22 | 付録A.2（938行付近） | `用語 'west' は` | `(.venv)`なしで`west`を実行したときの，日本語版PowerShellの実際のエラーメッセージ |
| 23 | 付録A.2（939行付近） | `unknown command "build"` | `ZEPHYR_BASE`なしでワークスペースの外から`west build`したときのメッセージ |
| 24 | 2.1節，付録A.2（260・940行付近） | `スクリプトの実行が無効` | 実行ポリシーが`Restricted`のときのエラーメッセージ |
| 25 | 2.1節，付録A.2（262・941行付近） | `パスが存在しないため検出できません` | 存在しないフォルダに`cd`したときのメッセージ |
| 26 | 付録A.3（951〜953行付近） | `Invalid BOARD`，`does not contain a CMakeLists`，`is for application` | 基板名を間違えたとき，サンプル以外のフォルダでビルドしたとき，別のアプリのbuildフォルダが残っているときのメッセージ |
| 27 | 2.2節，付録A.4（430・980行付近） | `No probe found` | 基板を抜いた状態で`west flash`したときの，LinkServerの実際のメッセージ |
| 28 | 5.2節（842〜843行付近） | `already exists`，`Could not resolve host` | `git clone`を2回実行したとき，ネットワークがないときのメッセージ |
| 29 | 付録A.5（992・996行付近） | `新しい接続`，`接続断` | Tera Termのメニュー名（「ファイル」→「新しい接続」「接続断」） |
| 38 | 2.1節 | `PS C:\WINDOWS\system32>` | PowerShellの開始フォルダ．スクリーンショットでは，管理者でない起動でも`C:\WINDOWS\system32`で開いた例（`powershell_launched.png`）と，`C:\Users\Owner`で開いた例（`activated.png`）がある．記事は「どこで開いても`cd`で移動するので問題ない」に変更済み．会場PCでスタートメニューから開いたときの実際の場所を確認 |
| 39 | 2.2節の手順3 | `スピード` | ~~`teraterm_baud.png`ではスピードの初期値が`9600`だった．`TERATERM.INI`（115200，`ComPort=3`）が読まれていない可能性．会場PCでINIのコピー先と，COMポート番号（スクリーンショットでは`COM6`）を確認~~ → **対応済み: `TERATERM.INI`は会場PCで読まれていなかった．配るのをやめ，`setup_venue.ps1`のコピーを削除した．初期状態のまま`°C`が正しく表示されることを会場PCで確認済み．ボーレートは受講者が手順3で設定する** |
| 40 | 2.2節の手順4 | `Tera Term 5での画面名・項目名を確認` | Tera Term 5で受信の文字コードを設定する画面（「設定」→「端末」か，「その他の設定」の「エンコーディング」タブか）と項目名 |
| 41 | 4.1節 | `MCU-Link firmware update` | `west flash`で出るMCU-Linkのファームウェアが古いというINFO（スクリーンショットではV3.128，付属は3.174）．会場の基板のファームウェアを更新するか，記事の「気にせず進めてください」のままにするか決める |
| 42 | 4.2節 | `<dbg>` | http_serverを書き込んだあと，Tera Termに`<dbg>`のログと`uart:~$`が出ること（`page_view.png`の背景で確認）．ログがいつから流れるか（ブラウザでページを開く前から出るか）を確認 |
| 43 | 2.2節，3.2節，付録F | `v4.x.x` | スクリーンショットのZephyrは`v4.5.0-rc3-33-g0436e9d188e0`（正式版でない）．会場PCで使う版を決めて，出力例を確定 |
| 44 | 付録A.6，`venue_checklist.md`，`setup_venue.ps1` | `192.168.1.10`，`ゲートウェイは空欄` | PC側のIPアドレス設定．`ip_address_setting.png`（動作確認済み）では`192.168.1.2`／`255.255.255.0`／ゲートウェイ`192.168.1.1`／DNS`8.8.8.8`だが，本文・チェックリスト・スクリプトは「`192.168.1.10`，ゲートウェイは空欄」．リハーサルで，(1) 画像の設定でEthernetをつないだまま5章の`git clone`が通るか（Ethernet側にゲートウェイがあると，インターネット行きの通信がWi-FiではなくEthernetに流れることがある），(2) どちらの設定にするかを確認し，記事A.6の表とコラム，`venue_checklist.md`，`setup_venue.ps1`の「手作業」の表示をそろえる |
| 30 | 2.1節のコラム（228行付近） | `複数行のテキストを貼り付け` | Windows Terminalで複数行を貼り付けたときの確認ダイアログの文言．会場PCのPowerShellがWindows Terminal上で開くか，従来のコンソールで開くかも確認（従来のコンソールではダイアログは出ません） → **一部確認（スクリーンショット）: Windows Terminal（タブ付き）で開く．ダイアログの文言は未確認** |

## 低：説明の正確さ（進行には影響しない）

| # | 場所 | 探す文字列 | 確認すること |
|---|---|---|---|
| 31 | 付録A.3 | `Out-File build_log.txt` | Windows PowerShell 5.1の`Out-File`はUTF-16で保存します．VSCodeでは問題なく開けますが，AIに貼り付けるときなどに文字化けしないか |
| 32 | 付録A.6（1020行付近） | `IP割り当て` | Windows 11の「設定」アプリの，固定IP設定の画面名・ボタン名．Windows 10では画面構成が異なります |
| 33 | 付録B（1162行付近） | `udev` | Linuxで`west flash`する場合の，LinkServerのudevルールの設定手順の案内 |
| 34 | 付録B（1264行付近） | `Shell Command: Install` | macOSのVSCodeのコマンド名 |
| 35 | 付録D（1608行付近） | `west boards -n` | 会場PCのwestで，`west boards`に`-n`（名前で絞り込む）オプションがあるか |
| 36 | 付録F（1681行付近） | `west debug` | FRDM-MCXN947で`west debug`がそのまま使えるか（LinkServerのGDBサーバー経由） |
| 37 | 0.4節 | `それぞれ独立しています` | 4章・5章を，3章をやらずに始めても問題なく進めるか（リハーサルで1度試す） |

---

## リハーサルでわざと起こしておくとよいエラー

付録Aの表と照らし合わせるために，リハーサルの1台で次を試し，実際の文言をメモしておくと確実です．

1. 新しいPowerShellで，`(.venv)`なしのまま`west --version`を実行する（#22）
2. 仮想環境だけ有効にし，`ZEPHYR_BASE`を設定せずに`~\handson\hello_world`で`west build`を実行する（#1，#23）
3. `-b frdm_mcxn947/cpu0`のように基板名を間違えてビルドする（#26）
4. `~\handson`で（サンプルのフォルダでなく）`west build`を実行する（#26）
5. USBケーブルを抜いて`west flash`を実行する（#27）
6. Ethernetケーブルを抜いて`ping 192.168.1.100`を実行する（#17）
7. ブラウザで`https://192.168.1.100/`を開く（#19）
8. 4章のサンプルを書き込んだまま，`http://192.168.1.100/temperature`を開く（#21）
9. `git clone`を2回実行する（#28）
