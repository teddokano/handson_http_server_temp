<#
.SYNOPSIS
  Zephyrデビュー会: 会場PCの準備をまとめて行う．

.DESCRIPTION
  次の作業を順に行います．済んでいる作業は飛ばすので，何度実行しても大丈夫です．

    1. このフォルダのスクリプトの「インターネットから取得した」印を外す（Unblock-File）
    2. 実行ポリシーを RemoteSigned にする（CurrentUser）
    3. zinit をプロファイルに登録する（install_zinit.ps1）
    4. LinkServer に PATH を通す（C:\NXP\LinkServer_* のうち新しいもの）
    5. ccache をインストールする（winget）
    5b. Tera Term の設定ファイル（同じフォルダの TERATERM.INI）をコピーする
        （115200 / UTF-8 などを設定済みのもの．既存のファイルはバックアップしてから置き換える）
    6. Microsoft Defender の除外設定（管理者権限が必要なので，確認画面が出ます）
       対象: ~\zephyrproject，~\handson，Zephyr SDK，ccache のキャッシュフォルダ
       他社製のウイルス対策ソフトが入っている場合は警告を出します（そのソフト側での設定が必要）
    7. 5章のリポジトリを ~\handson_seed にクローンする（-CloneSeed を付けたときだけ）
    8. ccache のキャッシュを作る（prewarm_ccache.ps1．数分〜十数分かかります）
    9. 会場PCの状態を確認する（venue_check.ps1）

  次の作業は自動ではできないので，最後に一覧で表示します．
    - Ethernet の固定IP設定，電源モード，スリープの設定

  このスクリプトは，「管理者として実行」ではなく，普通に起動した PowerShell から実行してください
  （管理者で実行すると，プロファイルや ccache の設定先が受講者の環境とずれることがあります）．

.PARAMETER CloneSeed
  5章のリポジトリを事前クローンする運用の場合に指定する（~\handson_seed に git clone）．

.PARAMETER SkipDefender
  Defender の除外設定を行わない．

.PARAMETER SkipPrewarm
  ccache のキャッシュ作成を行わない（時間がないときなど．あとで prewarm_ccache.ps1 を単独で実行できます）．

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\setup_venue.ps1
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\setup_venue.ps1 -CloneSeed
#>
[CmdletBinding()]
param(
    [string]$Workspace = (Join-Path $HOME 'zephyrproject'),
    [string]$RepoUrl = 'https://github.com/teddokano/handson_http_server_temp',
    [switch]$CloneSeed,
    [switch]$SkipDefender,
    [switch]$SkipPrewarm
)

$here = $PSScriptRoot
$psExe = (Get-Process -Id $PID).Path   # 今動いている PowerShell（5.1 なら powershell.exe）で子スクリプトを動かす
$summary = New-Object System.Collections.Generic.List[object]

function Write-Step([string]$Text) {
    Write-Host ''
    Write-Host "=== $Text ===" -ForegroundColor Cyan
}
function Add-Summary([string]$Status, [string]$Item, [string]$Detail = '') {
    $summary.Add([pscustomobject]@{ Status = $Status; Item = $Item; Detail = $Detail })
    $color = switch ($Status) { 'OK' { 'Green' } 'NG' { 'Red' } 'スキップ' { 'Gray' } default { 'Yellow' } }
    Write-Host ("[{0}] {1} {2}" -f $Status, $Item, $Detail) -ForegroundColor $color
}
function Update-SessionPath {
    # インストールや PATH の変更を，このウィンドウにも反映する
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ';'
}
function Invoke-Child([string]$Script, [string[]]$ArgList = @()) {
    # 子スクリプトは別プロセスで動かす（色付きの表示や確認の入力がそのまま使えるよう，同じウィンドウで）
    $path = Join-Path $here $Script
    if (-not (Test-Path $path)) { Write-Host "見つかりません: $path" -ForegroundColor Red; return 1 }
    $all = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $path) + $ArgList
    $quotedArgs = ($all | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join ' '
    $p = Start-Process -FilePath $psExe -ArgumentList $quotedArgs -NoNewWindow -Wait -PassThru
    return $p.ExitCode
}

Write-Host '##### Zephyrデビュー会 会場PC 一括セットアップ #####' -ForegroundColor Cyan
Write-Host ("PC名: {0}  ユーザー: {1}" -f $env:COMPUTERNAME, $env:USERNAME)

# 管理者で実行されていないか
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Host '「管理者として実行」した PowerShell で動いています．普通に起動した PowerShell から実行し直すことをおすすめします．' -ForegroundColor Yellow
    $ans = Read-Host 'このまま続けますか？ (y/N)'
    if ($ans -notmatch '^[yY]') { exit 1 }
}

# ---------------------------------------------------------------- 1. Unblock
Write-Step '1. スクリプトの印を外す'
Get-ChildItem (Join-Path $here '*.ps1') | Unblock-File
Add-Summary 'OK' 'Unblock-File' $here

# ---------------------------------------------------------------- 2. 実行ポリシー
Write-Step '2. 実行ポリシー'
$cur = "$(Get-ExecutionPolicy -Scope CurrentUser)"
if ($cur -in 'RemoteSigned', 'Unrestricted', 'Bypass') {
    Add-Summary 'OK' '実行ポリシー' "CurrentUser = $cur（設定済み）"
} else {
    try {
        Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force -ErrorAction Stop
        Add-Summary 'OK' '実行ポリシー' 'CurrentUser = RemoteSigned に設定しました'
    } catch {
        # グループポリシーで上書きされている場合など
        Add-Summary 'NG' '実行ポリシー' $_.Exception.Message
    }
}

# ---------------------------------------------------------------- 3. zinit
Write-Step '3. zinit の登録'
$rc = Invoke-Child 'install_zinit.ps1' @('-Workspace', $Workspace)
if ($rc -eq 0) { Add-Summary 'OK' 'zinit' '新しく開いた PowerShell から使えます' } else { Add-Summary 'NG' 'zinit' "install_zinit.ps1 が失敗しました（終了コード $rc）" }

# ---------------------------------------------------------------- 4. LinkServer の PATH
Write-Step '4. LinkServer の PATH'
Update-SessionPath
if (Get-Command LinkServer -ErrorAction SilentlyContinue) {
    Add-Summary 'OK' 'LinkServer' "PATH 設定済み: $((Get-Command LinkServer).Source)"
} else {
    $lsDir = $null
    if (Test-Path 'C:\NXP') {
        $lsDir = Get-ChildItem 'C:\NXP' -Directory -Filter 'LinkServer*' -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName 'LinkServer.exe') } |
            Sort-Object Name -Descending | Select-Object -First 1
    }
    if ($lsDir) {
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        if (-not $userPath) { $userPath = '' }
        if (($userPath -split ';') -notcontains $lsDir.FullName) {
            [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ';' + $lsDir.FullName).TrimStart(';'), 'User')
        }
        Update-SessionPath
        Add-Summary 'OK' 'LinkServer' "PATH に追加しました: $($lsDir.FullName)"
    } else {
        Add-Summary 'NG' 'LinkServer' 'C:\NXP\LinkServer_* が見つかりません．LinkServer をインストールしてから再実行してください'
    }
}

# ---------------------------------------------------------------- 5. ccache
Write-Step '5. ccache のインストール'
if (Get-Command ccache -ErrorAction SilentlyContinue) {
    Add-Summary 'OK' 'ccache' "インストール済み: $((Get-Command ccache).Source)"
} elseif (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Add-Summary 'NG' 'ccache' 'winget がありません．ccache を手動でインストールしてください'
} else {
    & winget install --id Ccache.Ccache -e --accept-source-agreements --accept-package-agreements
    Update-SessionPath
    # winget のポータブル版は %LOCALAPPDATA%\Microsoft\WinGet\Links に置かれる
    $links = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
    if (-not (Get-Command ccache -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $links 'ccache.exe'))) {
        $env:Path += ";$links"
    }
    if (Get-Command ccache -ErrorAction SilentlyContinue) {
        Add-Summary 'OK' 'ccache' "インストールしました: $((Get-Command ccache).Source)"
    } else {
        Add-Summary 'NG' 'ccache' 'インストール後も見つかりません．PowerShell を開き直してから，このスクリプトを再実行してください'
    }
}

# ---------------------------------------------------------------- 5b. Tera Term の設定ファイル
Write-Step '5b. Tera Term の設定ファイル'
$srcIni = Join-Path $here 'TERATERM.INI'
# Tera Term 5 は，ユーザーごとの設定を %APPDATA%\teraterm5 に保存する
$dstDir = Join-Path $env:APPDATA 'teraterm5'
$dstIni = Join-Path $dstDir 'TERATERM.INI'
if (-not (Test-Path $srcIni)) {
    Add-Summary 'NG' 'Tera Term の設定' "コピー元がありません: $srcIni"
} elseif (Get-Process ttermpro -ErrorAction SilentlyContinue) {
    Add-Summary 'NG' 'Tera Term の設定' 'Tera Term が起動しています．閉じてから再実行してください（起動中に置き換えると，終了時に上書きされることがあります）'
} else {
    New-Item -ItemType Directory -Force $dstDir | Out-Null
    if ((Test-Path $dstIni) -and ((Get-FileHash $dstIni).Hash -eq (Get-FileHash $srcIni).Hash)) {
        Add-Summary 'OK' 'Tera Term の設定' "コピー済み: $dstIni"
    } else {
        if (Test-Path $dstIni) {
            $bak = "$dstIni.bak-" + (Get-Date -Format 'yyyyMMddHHmmss')
            Copy-Item $dstIni $bak
            Write-Host "既存の設定をバックアップしました: $bak"
        }
        Copy-Item $srcIni $dstIni -Force
        Add-Summary 'OK' 'Tera Term の設定' "コピーしました: $dstIni"
    }
}

# ---------------------------------------------------------------- 6. Defender
Write-Step '6. ウイルス対策ソフトの除外設定（Microsoft Defender）'

# 有効なウイルス対策ソフトを調べる（Defender 以外が有効なら，Defender の除外は効かない）
$avNames = @()
try {
    $avNames = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop |
        ForEach-Object { $_.displayName } | Sort-Object -Unique)
} catch { }
$otherAv = @($avNames | Where-Object { $_ -notmatch 'Defender' })
if ($avNames.Count) { Write-Host ("登録されているウイルス対策ソフト: {0}" -f ($avNames -join ', ')) }
if ($otherAv.Count) {
    Add-Summary '注意' '他社製のウイルス対策ソフト' ("{0} が入っています．Defender の除外は効かないことがあるので，そのソフト側でも下のフォルダを除外してください" -f ($otherAv -join ', '))
}

# 除外するフォルダ
$paths = New-Object System.Collections.Generic.List[string]
$paths.Add((Join-Path $HOME 'zephyrproject'))
$paths.Add((Join-Path $HOME 'handson'))
# Zephyr SDK（ホームの下，C:\ の直下，環境変数で指定された場所）
$sdkDirs = @()
foreach ($base in @($HOME, 'C:\')) {
    if (Test-Path $base) { $sdkDirs += @(Get-ChildItem $base -Directory -Filter 'zephyr-sdk-*' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }) }
}
if ($env:ZEPHYR_SDK_INSTALL_DIR -and (Test-Path $env:ZEPHYR_SDK_INSTALL_DIR)) { $sdkDirs += $env:ZEPHYR_SDK_INSTALL_DIR }
$sdkDirs | Sort-Object -Unique | ForEach-Object { $paths.Add($_) }
if (-not $sdkDirs) { Write-Host 'Zephyr SDK のフォルダが見つかりませんでした（除外の対象から外します）' -ForegroundColor Yellow }
# ccache のキャッシュフォルダ
if (Get-Command ccache -ErrorAction SilentlyContinue) {
    $ccDir = (& ccache -k cache_dir 2>$null | Out-String).Trim()
    if (-not $ccDir) { $ccDir = Join-Path $env:LOCALAPPDATA 'ccache' }
    $paths.Add($ccDir)
}
$paths = @($paths | Sort-Object -Unique)
Write-Host '除外するフォルダ:'
$paths | ForEach-Object { Write-Host "  $_" }

if ($SkipDefender) {
    Add-Summary 'スキップ' 'Defender の除外' '-SkipDefender が指定されました'
} else {
    # 管理者権限の側で除外を追加し，追加後の一覧をファイルに書き出して確認する
    $resultFile = Join-Path $env:TEMP ('zephyr_defender_' + [guid]::NewGuid().ToString('N') + '.txt')
    $quoted = ($paths | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ','
    $resultQuoted = "'" + ($resultFile -replace "'", "''") + "'"
    $cmd = @"
`$ErrorActionPreference = 'Stop'
try {
    Add-MpPreference -ExclusionPath $quoted
    (Get-MpPreference).ExclusionPath | Set-Content -Encoding UTF8 $resultQuoted
    exit 0
} catch {
    ('ERROR: ' + `$_.Exception.Message) | Set-Content -Encoding UTF8 $resultQuoted
    exit 1
}
"@
    $ok = $false
    if ($isAdmin) {
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
        & $psExe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded
        $ok = ($LASTEXITCODE -eq 0)
    } else {
        Write-Host '管理者権限が必要です．「このアプリがデバイスに変更を加えることを許可しますか？」が出たら「はい」を押してください．'
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
        try {
            $p = Start-Process -FilePath $psExe -Verb RunAs -Wait -PassThru -WindowStyle Hidden `
                -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded)
            $ok = ($p.ExitCode -eq 0)
        } catch {
            Add-Summary 'NG' 'Defender の除外' '管理者の確認がキャンセルされました．再実行するか，「Windows セキュリティ」から手動で設定してください'
            $resultFile = $null
        }
    }

    if ($resultFile -and (Test-Path $resultFile)) {
        $registered = @(Get-Content $resultFile | Where-Object { $_ })
        Remove-Item $resultFile -Force -ErrorAction SilentlyContinue
        if (-not $ok) {
            Add-Summary 'NG' 'Defender の除外' ("{0}（組織のポリシーで禁止されている可能性があります）" -f ($registered -join ' '))
        } else {
            $missing = @($paths | Where-Object { $registered -notcontains $_ })
            if ($missing.Count -eq 0) {
                Add-Summary 'OK' 'Defender の除外' ("{0} 件を確認しました" -f $paths.Count)
            } else {
                Add-Summary 'NG' 'Defender の除外' ("一覧に反映されていません: {0}（組織のポリシーで上書きされている可能性があります）" -f ($missing -join ', '))
            }
        }
    } elseif ($resultFile) {
        Add-Summary 'NG' 'Defender の除外' '結果を確認できませんでした．「Windows セキュリティ」→「ウイルスと脅威の防止」→「設定の管理」→「除外」で確認してください'
    }
}

# ---------------------------------------------------------------- 7. seed
Write-Step '7. 5章のリポジトリ（事前クローン）'
$seed = Join-Path $HOME 'handson_seed'
$seedRepo = Join-Path $seed 'handson_http_server_temp'
if (-not $CloneSeed) {
    if (Test-Path $seedRepo) { Add-Summary 'OK' '事前クローン' "既にあります: $seedRepo" }
    else { Add-Summary 'スキップ' '事前クローン' '受講者が当日 git clone する運用（事前クローンする場合は -CloneSeed を付けて再実行）' }
} elseif (Test-Path $seedRepo) {
    & git -C $seedRepo pull -q 2>&1 | Out-Host
    Add-Summary 'OK' '事前クローン' "既にあるので最新に更新しました: $seedRepo"
} else {
    New-Item -ItemType Directory -Force $seed | Out-Null
    & git -C $seed clone -q $RepoUrl 2>&1 | Out-Host
    if ($LASTEXITCODE -eq 0) { Add-Summary 'OK' '事前クローン' $seedRepo }
    else { Add-Summary 'NG' '事前クローン' "git clone に失敗しました: $RepoUrl" }
}

# ---------------------------------------------------------------- 8. prewarm
Write-Step '8. ccache のキャッシュ作成'
if ($SkipPrewarm) {
    Add-Summary 'スキップ' 'キャッシュ作成' '-SkipPrewarm が指定されました．あとで prewarm_ccache.ps1 を実行してください'
} elseif (-not (Get-Command ccache -ErrorAction SilentlyContinue)) {
    Add-Summary 'NG' 'キャッシュ作成' 'ccache がないため実行しません'
} else {
    Write-Host '全サンプルをビルドします．数分〜十数分かかります．'
    $rc = Invoke-Child 'prewarm_ccache.ps1' @('-Workspace', $Workspace)
    if ($rc -eq 0) { Add-Summary 'OK' 'キャッシュ作成' '全サンプルで ccache が使われました' }
    else { Add-Summary 'NG' 'キャッシュ作成' '失敗したビルドがあります．上の結果を確認してください' }
}

# ---------------------------------------------------------------- 9. venue_check
Write-Step '9. 会場PCの状態確認（venue_check.ps1）'
$rc = Invoke-Child 'venue_check.ps1' @('-Workspace', $Workspace)
if ($rc -eq 0) { Add-Summary 'OK' '状態確認' 'NG なし' } else { Add-Summary 'NG' '状態確認' 'venue_check.ps1 に NG があります．上の結果を確認してください' }

# ---------------------------------------------------------------- まとめ
Write-Host ''
Write-Host '##### まとめ #####' -ForegroundColor Cyan
foreach ($s in $summary) {
    $color = switch ($s.Status) { 'OK' { 'Green' } 'NG' { 'Red' } 'スキップ' { 'Gray' } default { 'Yellow' } }
    Write-Host ("[{0}] {1}: {2}" -f $s.Status, $s.Item, $s.Detail) -ForegroundColor $color
}

Write-Host ''
Write-Host '##### 手作業で行ってください #####' -ForegroundColor Cyan
Write-Host '  - Tera Term を起動し，「設定」→「シリアルポート」が 115200，「設定」→「端末」の漢字（受信）が UTF-8 になっていることを確認'
Write-Host '  - Ethernet を固定IPに（例: 192.168.1.10 / 255.255.255.0，ゲートウェイは空欄．192.168.1.100 は使わない）'
Write-Host '  - ノートPCは AC アダプタをつなぎ，電源モードを「最適なパフォーマンス」に．スリープまでの時間を長めに'
Write-Host '  - Wi-Fi が 192.168.1.x のネットワークにつながっていないか確認'
Write-Host '  - 終わったら PowerShell を開き直し，zinit が使えることを確認'

if (@($summary | Where-Object Status -eq 'NG').Count) { exit 1 } else { exit 0 }
