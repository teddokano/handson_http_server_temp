# Zephyrデビュー会 一式

| ファイル | 内容 |
|---|---|
| `article_draft.md` | 記事ドラフト（Zephyrデビュー会 〜FRDM-MCXN947でつまずかず動かす90分〜） |
| `verification_list.md` | 要確認リスト．リハーサルで実機と照らし合わせる記述の一覧 |
| `handson_tools/venue_checklist.md` | 会場準備チェックリスト（事前準備・リハーサル・当日・回の間・終了後，スタッフ向け早見表） |
| `handson_tools/setup_venue.ps1` | 会場PCの準備をまとめて行う（zinit，LinkServerのPATH，ccache，Tera Termの設定，Defender除外，キャッシュ作成，状態確認） |
| `handson_tools/TERATERM.INI` | Tera Termの設定ファイル（115200 / UTF-8）．`setup_venue.ps1`が`%APPDATA%\teraterm5`にコピーする |
| `handson_tools/install_zinit.ps1` | `zinit`関数をPowerShellプロファイルに登録する（受講者用のコマンド） |
| `handson_tools/venue_check.ps1` | 会場PCの前提条件を確認する（`-Build`でビルド確認，`-Flash`で書き込み確認） |
| `handson_tools/prewarm_ccache.ps1` | 記事と同じ条件で全サンプルをビルドし，ccacheのキャッシュを作る |
| `handson_tools/reset_handson.ps1` | 回と回の間に作業用フォルダを初期状態に戻す |

`.ps1`ファイルはWindows PowerShell 5.1向けに，BOM付きUTF-8・CRLFで保存しています．
会場PCにコピーしたら，最初に `Get-ChildItem *.ps1 | Unblock-File` を実行してください．
`install_zinit.ps1`以外はスタッフ用です．受講者が clone するリポジトリには入れないでください．
