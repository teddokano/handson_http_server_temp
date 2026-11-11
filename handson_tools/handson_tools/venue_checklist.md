# Zephyrデビュー会 会場準備チェックリスト

記事「Zephyrデビュー会 〜FRDM-MCXN947でつまずかず動かす90分〜」の手順は，会場PCが以下の状態になっていることを前提にしています．1台でもずれていると，その席の受講者の手が止まります．全台で確認してください．

## 同梱のスクリプト

| ファイル | 用途 | いつ使う |
|---|---|---|
| `setup_venue.ps1` | 下の準備作業（zinitの登録，LinkServerのPATH，ccacheのインストール，Defenderの除外，キャッシュ作成，状態確認）を**まとめて**行う | 準備時に各PCで1回（何度実行してもよい） |
| `install_zinit.ps1` | `zinit`関数をPowerShellプロファイルに登録する | `setup_venue.ps1`から呼ばれる（単独でも実行可） |
| `venue_check.ps1` | 前提条件をまとめて確認する（何も変更しない）．`-Build`でビルド時間の計測，`-Flash`で書き込み確認も行う | 準備時，当日の開場前，回の間 |
| `prewarm_ccache.ps1` | 記事と同じフォルダ・同じ設定で全サンプルを一度ビルドし，ccacheのキャッシュを作る．終わったら作業用フォルダを片付ける | 準備の最後に各PCで1回（Zephyrや記事の手順を変えたら再実行） |
| `reset_handson.ps1` | 受講者の作業用フォルダ（`~\handson`）を消して初期状態に戻す（ccacheのキャッシュは消さない） | 回と回の間，終了後 |

スクリプトは，会場PCのスタッフ用フォルダ（例: `C:\handson_tools`）に置いて，次のように実行します．`install_zinit.ps1`以外は受講者が使うものではありません．受講者が`git clone`する5章のリポジトリには入れず，プロファイルにも登録しないでください（特に`reset_handson.ps1`は作業用フォルダを削除します）．

```powershell
cd C:\handson_tools
Get-ChildItem *.ps1 | Unblock-File
powershell -ExecutionPolicy Bypass -File .\venue_check.ps1
```

`Unblock-File`は，ダウンロードやUSBメモリ経由でコピーしたスクリプトに付く「インターネットから取得した」印を外すためのものです．これを外さないと，実行ポリシーが`RemoteSigned`のPCでは「デジタル署名されていません」というエラーで実行できません（`-ExecutionPolicy Bypass`で起動する場合は不要ですが，念のため）．zipでダウンロードした場合は，展開する**前に**zipを右クリック→「プロパティ」→「全般」タブの「許可する」にチェックを入れておくと，展開したファイルに印が付きません．

`venue_check.ps1`は，結果を`[OK]`／`[NG]`／`[注意]`／`[情報]`で表示し，最後にNGと注意の件数をまとめます．

---

## 1. 事前準備（各PCで1回）

### まとめて行う

Zephyr開発環境・LinkServer・VSCode・Git・Tera Termをインストールしたら，**普通に起動したPowerShell**（「管理者として実行」ではなく）で次を実行します．下の「ソフトウェア」「設定」「動作確認」のうち，自動でできるものを一度に行います．済んでいる作業は飛ばすので，途中で失敗したら原因を直して再実行してください．

```powershell
cd C:\handson_tools
powershell -ExecutionPolicy Bypass -File .\setup_venue.ps1
```

- 5章のリポジトリを事前クローンする運用なら，`-CloneSeed`を付けます
- Defenderの除外設定のところで，管理者の確認画面が出ます．「はい」を押してください
- キャッシュの作成に，数分〜十数分かかります
- 最後に「まとめ」と「手作業で行ってください」の一覧が出ます．手作業の項目（固定IP，電源モードなど）は，下のチェック項目に沿って行います
- Tera Termの設定ファイルをコピーするので，実行前にTera Termを閉じておきます

以下は，`setup_venue.ps1`が行う内容も含めた，個別のチェック項目です．

### ソフトウェア

- [ ] Zephyr開発環境が`~\zephyrproject`にある（公式Getting Started Guideの手順．Python仮想環境は`~\zephyrproject\.venv`）
- [ ] Zephyr SDKがインストールされている
- [ ] LinkServerがインストールされ，**PATHが通っている**（インストーラーはPATHを通さない．通っていないと`west flash`だけが「見つからない」で失敗する）
  ```powershell
  $ls = (Get-ChildItem C:\NXP -Directory -Filter 'LinkServer*' | Sort-Object Name -Descending | Select-Object -First 1).FullName
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (($userPath -split ';') -notcontains $ls) { [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ';' + $ls), 'User') }
  ```
  PowerShellを開き直して`LinkServer probes`を実行し，基板のMCU-Linkが表示されることを確認する（`setx`は長いPATHを切り捨てることがあるので使わない）
- [ ] ccacheがインストールされている（ないとビルドが数倍遅くなる．実測でhttp_serverが約4分半→73秒）
  ```powershell
  winget install --id Ccache.Ccache -e
  ```
  PowerShellを開き直して`ccache --version`が表示されることを確認する
- [ ] FRDM-MCXN947をつないだとき，デバイスマネージャーの「ポート (COM と LPT)」に`MCU-Link VCom Port (COMx)`が出る（MCU-Linkのドライバ）
- [ ] Visual Studio Codeがインストールされ，PowerShellから`code`コマンドが使える
- [ ] Gitがインストールされている
- [ ] Tera Termがインストールされている
- [ ] ブラウザ（EdgeまたはChrome）

### 設定

- [ ] PowerShellの実行ポリシーが`RemoteSigned`になっている
  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
  ```
- [ ] `install_zinit.ps1`を実行して，`zinit`を登録した
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\install_zinit.ps1
  ```
  新しいPowerShellを開いて`zinit`と打ち，`west --version`と`west topdir`が表示されることを確認する．VSCodeのターミナルでも同じく使えることを確認する．
- [ ] Tera Termの設定ファイルをコピーした（`setup_venue.ps1`が，同じフォルダの`TERATERM.INI`を`%APPDATA%\teraterm5\TERATERM.INI`にコピーする．既存のファイルは`.bak-日時`を付けてバックアップされる）
  - コピーの前にTera Termを閉じておく
  - Tera Termを起動し，「設定」→「シリアルポート」が`115200`，「設定」→「端末」の漢字（受信）が`UTF-8`になっていることを確認する．なっていなければ，そのPCのTera Termが別の場所の設定ファイルを読んでいる（「ヘルプ」→「バージョン情報」などで設定ファイルの場所を確認）
  - この`TERATERM.INI`はCOMポートが`COM3`で保存されている．PCによってMCU-LinkのCOM番号が違う場合は，受講者が「新しい接続」の画面でポートを選び直す（記事2.2節の手順どおり）
- [ ] PCのEthernetアダプタを固定IPにした
  - IPアドレス: `192.168.1.10`など（**`192.168.1.100`はボードが使うので避ける**）
  - サブネットマスク: `255.255.255.0`
  - ゲートウェイ: 空欄
- [ ] Wi-Fiが`192.168.1.x`のネットワークにつながっていない（会場のWi-Fiのアドレス帯を確認．同じなら，ハンズオン中はWi-Fiを切る）
- [ ] ブラウザでプロキシを使う設定になっていない（使う場合は`192.168.1.100`を例外に追加）
- [ ] Windows Updateや再起動の通知が当日に出ないよう，事前に更新を済ませた
- [ ] Microsoft DefenderのスキャンからZephyr関係のフォルダを除外した（ビルドが大幅に遅くなるのを防ぐ）．`setup_venue.ps1`が，`~\zephyrproject`・`~\handson`・Zephyr SDK・ccacheのキャッシュフォルダを除外し，反映されたかも確認する（管理者の確認画面で「はい」を押す）
  - 手動で行う場合は，「Windows セキュリティ」→「ウイルスと脅威の防止」→「設定の管理」→「除外」で追加する
  - **他社製のウイルス対策ソフト**（HP Wolf Security，トレンドマイクロ，ESETなど）が有効なPCでは，Defenderの除外は効かない．`setup_venue.ps1`が警告を出すので，そのソフト側で同じフォルダを除外する
  - 組織の管理下にあるPCでは，ポリシーで除外が禁止・上書きされることがある．`setup_venue.ps1`がNGを出したら情報システム部門に相談する
- [ ] ノートPCはACアダプタをつなぎ，「設定」→「システム」→「電源」の電源モードを「最適なパフォーマンス」にした
- [ ] スリープ・画面ロックまでの時間を長めに設定した（ビルド待ちの間に画面が消えないように）
- [ ] `~\zephyrproject`や`~\handson`がOneDriveの同期対象になっていない（デスクトップや「ドキュメント」がOneDriveにバックアップされている設定に注意．同期対象だとビルドが極端に遅くなる）

### 5章のリポジトリ（どちらかに決める）

- [ ] **A. 事前にクローンしておく**（会場でインターネットが使えない，または不安定な場合）
  ```powershell
  New-Item -ItemType Directory -Force ~\handson_seed | Out-Null
  cd ~\handson_seed
  git clone https://github.com/teddokano/handson_http_server_temp
  ```
  `reset_handson.ps1`が，`~\handson_seed`の中身を毎回`~\handson`にコピーします．記事の5.2節は「`cd ~\handson\handson_http_server_temp`から」に書き換える．
- [ ] **B. 受講者が当日クローンする**（会場でインターネットが使える場合）
  `venue_check.ps1`の「インターネット接続」が`github.com に接続できます`になることを確認する．

### 動作確認

- [ ] `venue_check.ps1 -Build -Flash`を実行して，NGが0件
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\venue_check.ps1 -Build -Flash
  ```
  - 表示された**Zephyrのバージョン**を，記事の付録Fと出力例の`v4.x.x`に反映する
  - `-Build`は一時フォルダでビルドするのでccacheのキャッシュが効かず，表示される時間は**キャッシュなしの時間**になる．受講者のビルド時間は，次の`prewarm_ccache.ps1`の2回目で確認する
  - 書き込み後，Tera Termに`Hello World! frdm_mcxn947/mcxn947/cpu0`が出ることを目視で確認する
- [ ] 確認が済んだら，`reset_handson.ps1`を実行して作業用フォルダを初期状態に戻す
- [ ] **最後に**`prewarm_ccache.ps1`を実行して，ccacheのキャッシュを作った（5章のリポジトリの準備を決めてから実行する）
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\prewarm_ccache.ps1
  ```
  - 全サンプルが`[OK]`で，`ccache: 使用`になっていること
  - もう一度実行すると，各ビルドの時間が受講者のビルド時間の目安になる．これを記事0.4節のタイムテーブルに反映する（受講者は5回ビルドします）
  - Zephyr（`~\zephyrproject`）や5章のリポジトリを更新したとき，記事の手順（`-b`の書き方，`prj.conf`の書き換え内容）を変えたときは，再実行する．キャッシュは，フォルダの場所・設定・コマンドが受講者とまったく同じときだけ効くため

---

## 2. リハーサル（最低1台で通しで）

- [ ] 記事の手順を**コピー＆ペーストだけで**，2.1節から5.2節まで通して実行した
- [ ] 各章の所要時間を計り，0.4節のタイムテーブルを確定した
- [ ] 記事の【 】のプレースホルダ用に，次を撮影・記録した
  - [ ] ボード写真（①〜⑤の番号入り），USBケーブルの接続写真
  - [ ] PowerShellの起動画面，コマンド例2.1-1の実行結果
  - [ ] ビルド成功時の出力（メモリ使用量の表）
  - [ ] Tera Termの「新しい接続」画面とシリアルポート設定画面（メニュー名・ボタン名も確認）
  - [ ] Hello World，blinky，thermometerのシリアル出力
  - [ ] PCとボードの接続図，pingの実行結果
  - [ ] ブラウザの画面（4.2節のLED制御，5.2節の温度表示）
- [ ] `verification_list.md`（要確認リスト）の項目を実機で確認し，違っていた記述を記事とスクリプトに反映した（特に優先度「高」の8項目）
- [ ] 付録Aの「よくあるエラー」を，わざと起こして文言を確認した（手順は`verification_list.md`の末尾）
- [x] 4.2節で，ボタン操作でどの色のLEDが点灯するかを確認し，記事に反映した（緑．反映済み）

---

## 3. 当日 開場前（各PC）

- [ ] PCを起動してログインした．ACアダプタがつながっている
- [ ] 基板の①（MCU-Link側USB）をPCにつないだ
- [ ] Ethernetケーブルは**PC側だけ挿し，基板側は抜いておく**（4.1節で受講者が挿す）
- [ ] `venue_check.ps1`を実行して，NGが0件．「ccacheのキャッシュ」のサイズが空に近くない（空なら`prewarm_ccache.ps1`を実行）
- [ ] 作業用フォルダが初期状態（`venue_check.ps1`の「作業用フォルダ」がOK）
- [ ] 開いているウィンドウ（PowerShell，VSCode，Tera Term，ブラウザ）をすべて閉じた
- [ ] 記事を表示するための手段を用意した（印刷，別画面，URLの案内など）

---

## 4. 回と回の間

- [ ] 受講者が開いたウィンドウ（PowerShell，VSCode，Tera Term，エクスプローラー）をすべて閉じた
- [ ] `reset_handson.ps1`を実行した
  ```powershell
  powershell -ExecutionPolicy Bypass -File C:\handson_tools\reset_handson.ps1 -ClearHistory
  ```
  - 「削除できませんでした」と出たら，そのフォルダを開いているウィンドウを閉じてから再実行する
- [ ] ブラウザの`192.168.1.100`の閲覧履歴を消した（前の受講者の履歴から`https://`で開いてしまうのを防ぐ）
- [ ] Ethernetケーブルの基板側を抜いた
- [ ] `venue_check.ps1`を実行して，NGが0件
- [ ] 基板は書き換えなくてよい（受講者が2.2節で書き込むため）．動作がおかしい基板は，USBを抜き差しして電源を入れ直す

---

## 5. 終了後

- [ ] `reset_handson.ps1`を実行した
- [ ] 会場PCを返却・撤収する場合は，必要に応じて`install_zinit.ps1 -Uninstall`でプロファイルから`zinit`を削除する
- [ ] 当日起きたトラブルとその対処をメモし，記事の付録Aに反映する

---

## 当日スタッフ向け：席でつまずいたときの早見表

まず受講者に**コマンド例の番号**と**最初に出たエラー**を聞く（記事0.4節）．

| 症状 | まずやること | 記事 |
|---|---|---|
| `west`が認識されない，`unknown command "build"` | `zinit <作業中のサンプル名>`（例: `zinit thermometer`） | A.2 |
| 違うフォルダでビルドしている | プロンプトのフォルダ名を確認して，その節の`cd`をやり直す | A.1 |
| ビルドエラーが続く | `west build -p always ...`でクリーンビルド | A.3 |
| ビルドが他の席より明らかに遅い | その席で`venue_check.ps1`を実行し，ccache・ACアダプタを確認 | A.3 |
| `west flash`でプローブが見つからない | USBが①に挿さっているか，他のツールが使っていないか | A.4 |
| Tera Termに何も出ない | タイトルバーにCOMポートが出ているか → RESETボタン（②） | A.5 |
| `°C`が文字化けする | Tera Termの「設定」→「端末」で受信をUTF-8に | A.5 |
| pingが通らない | `prj.conf`を保存したか → ビルドし直したか → ケーブル | 4.1，A.6 |
| ブラウザで開けない | アドレスが`http://`になっているか | 4.2，A.6 |
| 手順がぐちゃぐちゃになった | その節のサンプルフォルダを消して最初から | A.7 |
| 時間が足りない | 今の章は置いて，次の章の最初のコマンド例から（`zinit`のあと） | 0.4 |
