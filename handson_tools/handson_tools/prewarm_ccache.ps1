<#
.SYNOPSIS
  Zephyrデビュー会: 記事と同じ条件で全サンプルを一度ビルドし，ccache のキャッシュを作っておく．

.DESCRIPTION
  ccache は，ソース・設定・コマンド・ビルドするフォルダがまったく同じときだけキャッシュを使います．
  このスクリプトは，受講者が記事の手順で行うビルドを，同じフォルダ・同じ prj.conf・同じコマンドで
  再現します．終わったら作業用フォルダ（~\handson）を片付けます．キャッシュは ccache の保存場所に残るので，
  受講者のビルドが速くなります．

  再現するビルド:
    2.2節  ~\handson\hello_world                -b frdm_mcxn947/mcxn947/cpu0
    2.3節  ~\handson\blinky                     -b frdm_mcxn947//cpu0
    3.1節  ~\handson\thermometer                -b frdm_mcxn947//cpu0
    4.1節  ~\handson\http_server（元の prj.conf のまま／IPアドレスとゲートウェイを書き換えた後の2通り．
           書き換えを保存し忘れてビルドした受講者のビルドも速くするため）
    5.2節  ~\handson\handson_http_server_temp（seed があればそこから，なければ git clone）

  次の場合は，もう一度実行してください:
    - Zephyr（~\zephyrproject）を更新したとき
    - 記事の手順（サンプル，基板名の書き方，prj.conf の書き換え内容）を変えたとき
    - 5章のリポジトリを更新したとき

.PARAMETER Workspace
  Zephyr ワークスペースの場所．既定は ~\zephyrproject．

.PARAMETER Seed
  5章のリポジトリを事前クローンしておくフォルダ．既定は ~\handson_seed．

.PARAMETER Force
  ~\handson に前の作業が残っていても，確認せずに削除して実行する．

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\prewarm_ccache.ps1
#>
[CmdletBinding()]
param(
    [string]$Workspace = (Join-Path $HOME 'zephyrproject'),
    [string]$Seed = (Join-Path $HOME 'handson_seed'),
    [string]$RepoUrl = 'https://github.com/teddokano/handson_http_server_temp',
    [string]$BoardIp = '192.168.1.100',
    [string]$BoardGw = '192.168.1.1',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$handson = Join-Path $HOME 'handson'
$zephyrBase = Join-Path $Workspace 'zephyr'
$activate = Join-Path $Workspace '.venv\Scripts\Activate.ps1'

Write-Host '=== Zephyrデビュー会 ccache キャッシュ準備 ===' -ForegroundColor Cyan

# ---------------------------------------------------------------- 前提の確認
if (-not (Get-Command ccache -ErrorAction SilentlyContinue)) {
    throw 'ccache が見つかりません．winget install --id Ccache.Ccache -e でインストールし，PowerShell を開き直してから実行してください．'
}
if (-not (Test-Path $activate)) { throw "Python仮想環境が見つかりません: $activate" }

# 作業用フォルダに前の作業が残っていないか（seed からコピーしたものは除く）
if (Test-Path $handson) {
    $seedNames = @()
    if (Test-Path $Seed) { $seedNames = @(Get-ChildItem $Seed -Force | ForEach-Object { $_.Name }) }
    $extra = @(Get-ChildItem $handson -Force | Where-Object { $seedNames -notcontains $_.Name })
    if ($extra.Count -gt 0 -and -not $Force) {
        Write-Host ("~\handson に作業が残っています: {0}" -f (($extra | ForEach-Object { $_.Name }) -join ', ')) -ForegroundColor Yellow
        $ans = Read-Host '削除して続けますか？ (y/N)'
        if ($ans -notmatch '^[yY]') { Write-Host '中止しました．'; exit 1 }
    }
}

# 受講者と同じ環境にする（記事のコマンド例2.1-1と同じ）
Set-Location $HOME
. $activate
$env:ZEPHYR_BASE = $zephyrBase

if (Test-Path $handson) { Remove-Item -Recurse -Force $handson }
New-Item -ItemType Directory -Force $handson | Out-Null

& ccache -z | Out-Null

$results = New-Object System.Collections.Generic.List[object]
function Invoke-HandsonBuild([string]$Name, [string]$Board, [string]$Label = $Name) {
    $dir = Join-Path $handson $Name
    Set-Location $dir
    Write-Host "--- $Label をビルド中 ---" -ForegroundColor Cyan
    $log = Join-Path $env:TEMP ("prewarm_" + ($Label -replace '[^\w]', '_') + ".log")
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    # 受講者と同じく，サンプルのフォルダの中で「.」を指定してビルドする
    # （Windows PowerShell 5.1 では，Stop のまま外部コマンドの stderr をリダイレクトすると
    #   警告1行でスクリプトが止まるので，ここだけ Continue にする）
    $ErrorActionPreference = 'Continue'
    & west build -p auto -b $Board . *> $log
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $sw.Stop()
    $sec = [math]::Round($sw.Elapsed.TotalSeconds)
    $cc = $false
    $cache = Join-Path $dir 'build\CMakeCache.txt'
    if (Test-Path $cache) {
        # 見つからなかった場合は「CCACHE:FILEPATH=CCACHE-NOTFOUND」になるので除外する
        $cc = [bool](Select-String -Path $cache -Pattern '^CCACHE:FILEPATH=' |
            Where-Object { $_.Line -notmatch 'NOTFOUND' -and $_.Line -match '(?i)ccache(\.exe)?\s*$' })
    }
    if ($code -eq 0) {
        $msg = "$sec 秒"
        if (-not $cc) { $msg += '（注意: ccache が使われていません）' }
        Write-Host "[OK] $Label : $msg" -ForegroundColor $(if ($cc) { 'Green' } else { 'Yellow' })
    } else {
        Write-Host "[NG] $Label : 失敗（$sec 秒）．ログ: $log" -ForegroundColor Red
    }
    $results.Add([pscustomobject]@{ Sample = $Label; Seconds = $sec; OK = ($code -eq 0); Ccache = $cc })
    Set-Location $HOME
}

try {
    # 2.2節 hello_world（2.2節だけ基板名を省略せずに書いている）
    Copy-Item -Recurse (Join-Path $zephyrBase 'samples\hello_world') (Join-Path $handson 'hello_world')
    Invoke-HandsonBuild 'hello_world' 'frdm_mcxn947/mcxn947/cpu0'

    # 2.3節 blinky
    Copy-Item -Recurse (Join-Path $zephyrBase 'samples\basic\blinky') (Join-Path $handson 'blinky')
    Invoke-HandsonBuild 'blinky' 'frdm_mcxn947//cpu0'

    # 3.1節 thermometer
    Copy-Item -Recurse (Join-Path $zephyrBase 'samples\sensor\thermometer') (Join-Path $handson 'thermometer')
    Invoke-HandsonBuild 'thermometer' 'frdm_mcxn947//cpu0'

    # 4.1節 http_server
    $http = Join-Path $handson 'http_server'
    Copy-Item -Recurse (Join-Path $zephyrBase 'samples\net\sockets\http_server') $http

    # (1) 元の prj.conf のまま（書き換えを保存し忘れてビルドした場合）
    Invoke-HandsonBuild 'http_server' 'frdm_mcxn947//cpu0' 'http_server（元の設定）'

    # (2) 記事どおりに prj.conf の2行を書き換えてから（同じフォルダで，受講者と同じく -p auto）
    $conf = Join-Path $http 'prj.conf'
    $text = [System.IO.File]::ReadAllText($conf)
    $pairs = @{
        'CONFIG_NET_CONFIG_MY_IPV4_ADDR' = $BoardIp
        'CONFIG_NET_CONFIG_MY_IPV4_GW'   = $BoardGw
    }
    foreach ($key in $pairs.Keys) {
        $pattern = '(?m)^' + [regex]::Escape($key) + '=.*$'
        if (-not [regex]::IsMatch($text, $pattern)) { throw "prj.conf に $key の行がありません（サンプルの内容が記事と違います）" }
        $text = [regex]::Replace($text, $pattern, ('{0}="{1}"' -f $key, $pairs[$key]))
    }
    [System.IO.File]::WriteAllText($conf, $text, (New-Object System.Text.UTF8Encoding($false)))
    Invoke-HandsonBuild 'http_server' 'frdm_mcxn947//cpu0' 'http_server（IP書き換え後）'

    # 5.2節 改変版リポジトリ
    $repoName = 'handson_http_server_temp'
    $seedRepo = Join-Path $Seed $repoName
    if (Test-Path $seedRepo) {
        Copy-Item -Recurse $seedRepo (Join-Path $handson $repoName)
    } else {
        Set-Location $handson
        $ErrorActionPreference = 'Continue'
        & git clone -q $RepoUrl 2>&1 | Out-Host
        $code = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        if ($code -ne 0) { throw "git clone に失敗しました: $RepoUrl" }
        Set-Location $HOME
    }
    Invoke-HandsonBuild $repoName 'frdm_mcxn947//cpu0'
}
finally {
    Set-Location $HOME
    Write-Host ''
    Write-Host '--- ccache の統計 ---' -ForegroundColor Cyan
    & ccache -s
}

# 片付け: 受講者が来る前の状態に戻す（seed があれば ~\handson にコピーし直す）
Remove-Item -Recurse -Force $handson
if (Test-Path $Seed) {
    New-Item -ItemType Directory -Force $handson | Out-Null
    Get-ChildItem $Seed -Force | ForEach-Object { Copy-Item -Recurse -Force $_.FullName (Join-Path $handson $_.Name) }
}
if (Get-Command deactivate -ErrorAction SilentlyContinue) { deactivate }

Write-Host ''
Write-Host '=== 結果 ===' -ForegroundColor Cyan
foreach ($r in $results) {
    $status = if (-not $r.OK) { 'NG ' } elseif (-not $r.Ccache) { '注意' } else { 'OK ' }
    Write-Host ("[{0}] {1,-26} {2,4} 秒  ccache: {3}" -f $status, $r.Sample, $r.Seconds, $(if ($r.Ccache) { '使用' } else { '未使用' }))
}
$ng = @($results | Where-Object { -not $_.OK -or -not $_.Ccache }).Count
if ($ng) {
    Write-Host '失敗したビルド，または ccache が使われていないビルドがあります．上の結果を確認してください．' -ForegroundColor Red
    exit 1
}
Write-Host 'キャッシュの準備ができました．~\handson は受講者が来る前の状態に戻してあります．' -ForegroundColor Green
Write-Host '確認したい場合は，このスクリプトをもう一度実行してください．2回目は各ビルドが大幅に速くなり，ccache の Hits が増えるはずです．'
