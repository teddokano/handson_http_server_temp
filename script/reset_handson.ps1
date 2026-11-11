<#
.SYNOPSIS
  Zephyrデビュー会: 回と回の間に，会場PCを受講者が来る前の状態に戻す．

.DESCRIPTION
  次のことを行います．
    1. ~\handson（受講者の作業用フォルダ）を削除する
    2. seed フォルダ（既定は ~\handson_seed）があれば，その中身を ~\handson にコピーする
       （5章のリポジトリを事前にクローンしておく運用の場合に使います）
    3. -ClearHistory を付けた場合は，PowerShell のコマンド履歴を消す
  ~\zephyrproject（Zephyr本体と元のサンプル）には一切手を触れません．

  ウィンドウを閉じる，ブラウザの履歴を消す，などの手作業は，
  最後に一覧で表示します（チェックリストも参照）．

.PARAMETER Seed
  事前クローンしたリポジトリなどを置いておくフォルダ．既定は ~\handson_seed．
  存在しなければ，~\handson は作らずに削除だけします（2.2節で受講者が作ります）．

.PARAMETER ClearHistory
  PowerShell のコマンド履歴（上矢印キーで出てくる履歴）を消す．

.PARAMETER Force
  確認せずに実行する．

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\reset_handson.ps1 -ClearHistory
#>
[CmdletBinding()]
param(
    [string]$Seed = (Join-Path $HOME 'handson_seed'),
    [switch]$ClearHistory,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$handson = Join-Path $HOME 'handson'

# 念のため，削除対象が「ホーム直下の handson」そのものであることを確認する
$expected = [System.IO.Path]::GetFullPath((Join-Path $HOME 'handson')).TrimEnd('\')
if ([System.IO.Path]::GetFullPath($handson).TrimEnd('\') -ne $expected) {
    throw "削除対象のパスが想定と異なります: $handson"
}

Write-Host '=== Zephyrデビュー会 会場PCリセット ===' -ForegroundColor Cyan
Write-Host "削除するフォルダ : $handson"
if (Test-Path $Seed) {
    Write-Host "コピーし直すもの : $Seed の中身（$((Get-ChildItem $Seed | ForEach-Object { $_.Name }) -join ', ')）"
} else {
    Write-Host "コピーし直すもの : なし（$Seed がありません）"
}
if ($ClearHistory) { Write-Host 'PowerShell の履歴 : 消去する' }
Write-Host ''

if (-not $Force) {
    $ans = Read-Host '実行しますか？ (y/N)'
    if ($ans -notmatch '^[yY]') { Write-Host '中止しました．'; exit 1 }
}

# 作業用フォルダの中にいると削除できないので，ホームに移動しておく
Set-Location $HOME

# 1. 作業用フォルダを削除
if (Test-Path $handson) {
    try {
        Remove-Item -Recurse -Force $handson
        Write-Host "[OK] $handson を削除しました" -ForegroundColor Green
    } catch {
        Write-Host "[NG] $handson を削除できませんでした: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host '     VSCode や PowerShell，エクスプローラーでこのフォルダを開いていないか確認して，もう一度実行してください．' -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[OK] $handson はありません" -ForegroundColor Green
}

# 2. seed をコピー
if (Test-Path $Seed) {
    New-Item -ItemType Directory -Force $handson | Out-Null
    Get-ChildItem $Seed -Force | ForEach-Object {
        Copy-Item -Recurse -Force $_.FullName (Join-Path $handson $_.Name)
        Write-Host "[OK] $($_.Name) をコピーしました" -ForegroundColor Green
    }
    # seed 内の git リポジトリが変更されていないか念のため確認
    Get-ChildItem $handson -Directory | Where-Object { Test-Path (Join-Path $_.FullName '.git') } | ForEach-Object {
        $st = (& git -C $_.FullName status --porcelain 2>&1 | Out-String).Trim()
        if ($st) { Write-Host "[注意] $($_.Name) に未コミットの変更があります（seed 自体が変更されている可能性）:`n$st" -ForegroundColor Yellow }
    }
}

# 3. PowerShell の履歴を消す
if ($ClearHistory) {
    try {
        $histPath = (Get-PSReadLineOption).HistorySavePath
        if ($histPath -and (Test-Path $histPath)) {
            Remove-Item -Force $histPath
            Write-Host '[OK] PowerShell の履歴を消しました（開いているウィンドウを閉じると反映されます）' -ForegroundColor Green
        }
    } catch {
        Write-Host "[注意] 履歴を消せませんでした: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host '=== 次は手作業で確認してください ===' -ForegroundColor Cyan
Write-Host '  - PowerShell / VSCode / エクスプローラーのウィンドウをすべて閉じる'
Write-Host '  - Tera Term を閉じる（次の受講者が 2.2節の手順で接続し直します）'
Write-Host '  - ブラウザのタブを閉じ，192.168.1.100 の閲覧履歴を消す（https:// への自動切り替えを防ぐため）'
Write-Host '  - 基板の USB ケーブルは挿したまま，Ethernet ケーブルは基板側を抜いておく'
Write-Host '  - venue_check.ps1 を実行して NG がないことを確認する'
