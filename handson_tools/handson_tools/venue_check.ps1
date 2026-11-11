<#
.SYNOPSIS
  Zephyrデビュー会: 会場PCが記事の手順どおりに動く状態かを確認する．

.DESCRIPTION
  記事の手順が前提にしている設定（実行ポリシー，仮想環境，west，LinkServer，
  Tera Term，ネットワーク設定，作業用フォルダなど）を確認し，
  OK / NG / 注意 の一覧を表示します．何も変更しません（-Build / -Flash を除く）．

  -Build を付けると，hello_world と http_server を一時フォルダでビルドし，
  かかった時間を表示します（タイムテーブルの見積もりに使えます）．
  -Flash を付けると，さらに hello_world を基板に書き込みます．

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\venue_check.ps1
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\venue_check.ps1 -Build -Flash
#>
[CmdletBinding()]
param(
    [string]$Workspace = (Join-Path $HOME 'zephyrproject'),
    [string]$BoardIp = '192.168.1.100',
    [string]$Board = 'frdm_mcxn947/mcxn947/cpu0',
    [string]$Seed = (Join-Path $HOME 'handson_seed'),
    [switch]$Build,
    [switch]$Flash
)

$results = New-Object System.Collections.Generic.List[object]
function Add-Result([string]$Status, [string]$Item, [string]$Detail) {
    $results.Add([pscustomobject]@{ Status = $Status; Item = $Item; Detail = $Detail })
    $color = switch ($Status) { 'OK' { 'Green' } 'NG' { 'Red' } '注意' { 'Yellow' } default { 'Gray' } }
    Write-Host ("[{0}] {1}: {2}" -f $Status, $Item, $Detail) -ForegroundColor $color
}

Write-Host '=== Zephyrデビュー会 会場PCチェック ===' -ForegroundColor Cyan
Write-Host ("PC名: {0}  ユーザー: {1}  PowerShell: {2}" -f $env:COMPUTERNAME, $env:USERNAME, $PSVersionTable.PSVersion)
Write-Host ''

# ---------------------------------------------------------------- 実行ポリシー
# -ExecutionPolicy Bypass で起動されている場合でも，受講者が普通に開いた PowerShell での値を判定する
$policyList = Get-ExecutionPolicy -List
$effective = 'Restricted'
foreach ($scope in 'MachinePolicy', 'UserPolicy', 'CurrentUser', 'LocalMachine') {
    $p = ($policyList | Where-Object { "$($_.Scope)" -eq $scope }).ExecutionPolicy
    if ($p -and "$p" -ne 'Undefined') { $effective = "$p"; break }
}
if ($effective -in 'Restricted', 'AllSigned') {
    Add-Result 'NG' '実行ポリシー' "$effective （Activate.ps1 が実行できません．Set-ExecutionPolicy -Scope CurrentUser RemoteSigned を実行）"
} else {
    Add-Result 'OK' '実行ポリシー' $effective
}

# ---------------------------------------------------------------- ワークスペース
$activate = Join-Path $Workspace '.venv\Scripts\Activate.ps1'
$zephyrBase = Join-Path $Workspace 'zephyr'
if (Test-Path $activate) { Add-Result 'OK' 'Python仮想環境' $activate }
else { Add-Result 'NG' 'Python仮想環境' "見つかりません: $activate" }

if (Test-Path (Join-Path $Workspace '.west')) { Add-Result 'OK' 'westワークスペース' $Workspace }
else { Add-Result 'NG' 'westワークスペース' "$Workspace に .west がありません" }

$versionFile = Join-Path $zephyrBase 'VERSION'
if (Test-Path $versionFile) {
    $v = @{}
    Get-Content $versionFile | ForEach-Object {
        if ($_ -match '^\s*(\w+)\s*=\s*(\S*)') { $v[$Matches[1]] = $Matches[2] }
    }
    $ver = "v{0}.{1}.{2}" -f $v['VERSION_MAJOR'], $v['VERSION_MINOR'], $v['PATCHLEVEL']
    if ($v['EXTRAVERSION']) { $ver += "-" + $v['EXTRAVERSION'] }
    Add-Result '情報' 'Zephyrのバージョン' "$ver （記事の付録Fに記入）"
} else {
    Add-Result 'NG' 'Zephyr本体' "見つかりません: $zephyrBase"
}

# ---------------------------------------------------------------- zinit
$profilePath = $PROFILE.CurrentUserAllHosts
if ((Test-Path $profilePath) -and ((Get-Content $profilePath -Raw) -match '>>> zephyr-handson >>>')) {
    Add-Result 'OK' 'zinit' "プロファイルに登録済み: $profilePath"
} else {
    Add-Result 'NG' 'zinit' 'プロファイルに未登録（install_zinit.ps1 を実行）'
}

# ---------------------------------------------------------------- west（仮想環境を有効化して確認）
$westOk = $false
if (Test-Path $activate) {
    . $activate
    $env:ZEPHYR_BASE = $zephyrBase
    $westVer = (& west --version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -eq 0) { Add-Result 'OK' 'west' $westVer } else { Add-Result 'NG' 'west' $westVer }

    Push-Location $HOME
    $topdir = (& west topdir 2>&1 | Out-String).Trim()
    $topOk = ($LASTEXITCODE -eq 0)
    Pop-Location
    if ($topOk -and ((Resolve-Path $topdir).Path -eq (Resolve-Path $Workspace).Path)) {
        Add-Result 'OK' 'west topdir（ワークスペース外から）' $topdir
        $westOk = $true
    } else {
        Add-Result 'NG' 'west topdir（ワークスペース外から）' $topdir
    }
}

# ---------------------------------------------------------------- Zephyr SDK
$sdkFound = $null
if ($env:ZEPHYR_SDK_INSTALL_DIR -and (Test-Path $env:ZEPHYR_SDK_INSTALL_DIR)) { $sdkFound = $env:ZEPHYR_SDK_INSTALL_DIR }
if (-not $sdkFound -and (Test-Path 'HKCU:\Software\Kitware\CMake\Packages\Zephyr-sdk')) { $sdkFound = 'CMakeパッケージレジストリに登録済み' }
if (-not $sdkFound) {
    $cand = @($HOME, 'C:\', "$env:LOCALAPPDATA") | Where-Object { $_ -and (Test-Path $_) } |
        ForEach-Object { Get-ChildItem $_ -Directory -Filter 'zephyr-sdk-*' -ErrorAction SilentlyContinue } |
        Select-Object -First 1
    if ($cand) { $sdkFound = $cand.FullName }
}
if ($sdkFound) { Add-Result 'OK' 'Zephyr SDK' $sdkFound }
else { Add-Result '注意' 'Zephyr SDK' '見つかりません（-Build で実際にビルドできるか確認してください）' }

# ---------------------------------------------------------------- コマンド
foreach ($cmd in 'git', 'cmake', 'ninja', 'code', 'ccache') {
    $c = Get-Command $cmd -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { Add-Result 'OK' "コマンド: $cmd" $c.Source }
    elseif ($cmd -eq 'ccache') { Add-Result 'NG' "コマンド: $cmd" 'PATH にありません（winget install --id Ccache.Ccache -e．ないとビルドが数倍遅くなります）' }
    else { Add-Result 'NG' "コマンド: $cmd" 'PATH にありません' }
}

if (Get-Command ccache -ErrorAction SilentlyContinue) {
    $ccStats = (& ccache -s 2>&1 | Out-String)
    $sizeLine = ($ccStats -split "`r?`n" | Where-Object { $_ -match '(?i)cache size' } | Select-Object -First 1)
    if ($sizeLine) { $sizeLine = $sizeLine.Trim() } else { $sizeLine = '（ccache -s で確認）' }
    Add-Result '情報' 'ccacheのキャッシュ' "$sizeLine （prewarm_ccache.ps1 で準備．空に近ければ未準備）"
}

$ls = Get-Command 'LinkServer' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($ls) {
    Add-Result 'OK' 'LinkServer' $ls.Source
} else {
    $lsDir = $null
    if (Test-Path 'C:\NXP') { $lsDir = Get-ChildItem 'C:\NXP' -Directory -Filter 'LinkServer*' -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if ($lsDir) { Add-Result 'NG' 'LinkServer' "インストール済みだが PATH にありません: $($lsDir.FullName) を PATH に追加" }
    else { Add-Result 'NG' 'LinkServer' '見つかりません（west flash ができません）' }
}

# ---------------------------------------------------------------- Tera Term
# 「すべてのユーザー」向けのインストール（Program Files）と，
# 「自分だけ」向けのインストール（%LOCALAPPDATA%\Programs）の両方を探す
$ttCandidates = @()
foreach ($base in @("${env:ProgramFiles(x86)}", "$env:ProgramFiles", (Join-Path "$env:LOCALAPPDATA" 'Programs'))) {
    if ($base) {
        foreach ($name in 'teraterm5', 'teraterm') {
            $ttCandidates += (Join-Path (Join-Path $base $name) 'ttermpro.exe')
        }
    }
}
$ttExe = $ttCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

# 上で見つからなければ，「アプリと機能」に登録されているインストール先を調べる
if (-not $ttExe) {
    $uninstallKeys = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $ttExe = Get-ItemProperty $uninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like 'Tera Term*' -and $_.InstallLocation } |
        ForEach-Object { Join-Path $_.InstallLocation 'ttermpro.exe' } |
        Where-Object { Test-Path $_ } |
        Select-Object -First 1
}
if ($ttExe) { Add-Result 'OK' 'Tera Term' $ttExe }
else { Add-Result 'NG' 'Tera Term' '見つかりません' }

$ttIni = @(
    "$env:APPDATA\teraterm5\TERATERM.INI",
    "$env:APPDATA\teraterm\TERATERM.INI"
)
if ($ttExe) { $ttIni += (Join-Path (Split-Path $ttExe -Parent) 'TERATERM.INI') }
$ttIni = $ttIni | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($ttIni) {
    $ini = Get-Content $ttIni
    $baud = ($ini | Where-Object { $_ -match '^\s*BaudRate\s*=' } | Select-Object -First 1)
    $kanji = ($ini | Where-Object { $_ -match '^\s*KanjiReceive\s*=' } | Select-Object -First 1)
    $baudOk = $baud -match '=\s*115200\s*$'
    $kanjiOk = $kanji -match '=\s*UTF-?8'
    if ($baudOk -and $kanjiOk) {
        Add-Result 'OK' 'Tera Termの保存設定' "$ttIni （$baud, $kanji）"
    } else {
        Add-Result '注意' 'Tera Termの保存設定' "$ttIni （$baud, $kanji）．115200 / UTF-8 を設定して「設定の保存」をしてください（実機での目視確認を推奨）"
    }
} else {
    Add-Result '注意' 'Tera Termの保存設定' 'TERATERM.INI が見つかりません（実機で 115200 / UTF-8 を目視確認）'
}

# ---------------------------------------------------------------- ネットワーク
$prefix = ($BoardIp -replace '\.\d+$', '.')
$ips = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue)
$adapters = @(Get-NetAdapter -ErrorAction SilentlyContinue)
$same = @($ips | Where-Object { $_.IPAddress.StartsWith($prefix) })
if ($same.Count -eq 0) {
    Add-Result 'NG' 'PCのIPアドレス' "${prefix}x のアドレスを持つアダプタがありません（Ethernetを固定IPに設定）"
}
foreach ($ip in $same) {
    $ad = $adapters | Where-Object { $_.ifIndex -eq $ip.InterfaceIndex } | Select-Object -First 1
    $isWifi = $ad -and (("$($ad.PhysicalMediaType)" -match '802\.11') -or ($ad.InterfaceDescription -match 'Wi-?Fi|Wireless'))
    $label = "$($ip.InterfaceAlias) = $($ip.IPAddress)/$($ip.PrefixLength)"
    if ($ip.IPAddress -eq $BoardIp) {
        Add-Result 'NG' 'PCのIPアドレス' "$label （ボードと同じアドレスです）"
    } elseif ($isWifi) {
        Add-Result 'NG' 'PCのIPアドレス' "$label （Wi-Fiが同じネットワーク．ボードへの通信がWi-Fiに流れます）"
    } elseif ($ip.PrefixLength -ne 24) {
        Add-Result '注意' 'PCのIPアドレス' "$label （サブネットマスクが 255.255.255.0 ではありません）"
    } else {
        Add-Result 'OK' 'PCのIPアドレス' $label
    }
}

# ---------------------------------------------------------------- 基板の接続
$mcuLink = @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'MCU-Link' -and $_.Name -match 'COM\d+' })
if ($mcuLink.Count -gt 0) {
    Add-Result 'OK' '基板（MCU-Link）' (($mcuLink | ForEach-Object { $_.Name }) -join ' / ')
} else {
    Add-Result '注意' '基板（MCU-Link）' 'COMポートが見つかりません（基板が未接続，またはドライバ未インストール）'
}

# ---------------------------------------------------------------- 作業用フォルダ
$handson = Join-Path $HOME 'handson'
if (-not (Test-Path $handson)) {
    Add-Result 'OK' '作業用フォルダ' '~\handson はありません（受講者が 2.2節で作成）'
} else {
    $items = @(Get-ChildItem $handson -Force)
    $seedNames = @()
    if (Test-Path $Seed) { $seedNames = @(Get-ChildItem $Seed -Force | ForEach-Object { $_.Name }) }
    $extra = @($items | Where-Object { $seedNames -notcontains $_.Name })
    if ($extra.Count -eq 0) {
        Add-Result 'OK' '作業用フォルダ' ('~\handson は初期状態です' + $(if ($items.Count) { "（$(($items | ForEach-Object { $_.Name }) -join ', ')）" } else { '' }))
    } else {
        Add-Result '注意' '作業用フォルダ' ("前の回の作業が残っています: {0} （reset_handson.ps1 を実行）" -f (($extra | ForEach-Object { $_.Name }) -join ', '))
    }
}

if (Test-Path $Seed) {
    Add-Result '情報' '事前クローン（seed）' ("{0}: {1}" -f $Seed, ((Get-ChildItem $Seed | ForEach-Object { $_.Name }) -join ', '))
} else {
    Add-Result '情報' '事前クローン（seed）' "なし（5章で受講者が git clone します．会場のインターネット接続が必要）"
}

# ---------------------------------------------------------------- インターネット
$net = $false
try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $ar = $tcp.BeginConnect('github.com', 443, $null, $null)
    $net = $ar.AsyncWaitHandle.WaitOne(3000) -and $tcp.Connected
    $tcp.Close()
} catch { $net = $false }
if ($net) { Add-Result '情報' 'インターネット接続' 'github.com に接続できます' }
elseif (Test-Path $Seed) { Add-Result '情報' 'インターネット接続' 'github.com に接続できません（seed があるので問題なし）' }
else { Add-Result 'NG' 'インターネット接続' 'github.com に接続できず，seed もありません（5章の git clone ができません）' }

# ---------------------------------------------------------------- ビルド・書き込みテスト
if ($Build -or $Flash) {
    if (-not $westOk) {
        Add-Result 'NG' 'ビルドテスト' 'west が使えないため実行しません'
    } else {
        $tmp = Join-Path $env:TEMP ('zephyr_venue_check_' + (Get-Date -Format 'yyyyMMddHHmmss'))
        New-Item -ItemType Directory -Force $tmp | Out-Null
        $tests = @(
            @{ Name = 'hello_world'; Src = 'samples\hello_world' },
            @{ Name = 'http_server'; Src = 'samples\net\sockets\http_server' }
        )
        foreach ($t in $tests) {
            $app = Join-Path $tmp $t.Name
            Copy-Item -Recurse (Join-Path $zephyrBase $t.Src) $app
            Write-Host "--- $($t.Name) をビルド中（数分かかることがあります） ---" -ForegroundColor Cyan
            $log = Join-Path $tmp "$($t.Name)_build.log"
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            & west build -p always -b $Board -d (Join-Path $app 'build') $app *> $log
            $code = $LASTEXITCODE
            $sw.Stop()
            $sec = [math]::Round($sw.Elapsed.TotalSeconds)
            if ($code -eq 0) { Add-Result 'OK' "ビルド: $($t.Name)" "$sec 秒（初回ビルド相当．タイムテーブルの見積もりに）" }
            else { Add-Result 'NG' "ビルド: $($t.Name)" "失敗（$sec 秒）．ログ: $log" }
        }
        if ($Flash) {
            $helloBuild = Join-Path (Join-Path $tmp 'hello_world') 'build'
            if (Test-Path (Join-Path $helloBuild 'zephyr\zephyr.elf')) {
                Write-Host '--- hello_world を書き込み中 ---' -ForegroundColor Cyan
                $log = Join-Path $tmp 'flash.log'
                & west flash -d $helloBuild *> $log
                if ($LASTEXITCODE -eq 0) { Add-Result 'OK' '書き込み: hello_world' 'Tera Term に Hello World! が出ているか目視で確認してください' }
                else { Add-Result 'NG' '書き込み: hello_world' "失敗．ログ: $log" }
            } else {
                Add-Result 'NG' '書き込み: hello_world' 'ビルドに失敗しているため実行しません'
            }
        }
        Add-Result '情報' 'テスト用フォルダ' "$tmp （確認が済んだら削除して構いません）"
    }
}

# ---------------------------------------------------------------- まとめ
if (Get-Command deactivate -ErrorAction SilentlyContinue) { deactivate }
Write-Host ''
$ng = @($results | Where-Object Status -eq 'NG').Count
$warn = @($results | Where-Object Status -eq '注意').Count
if ($ng -eq 0 -and $warn -eq 0) {
    Write-Host '=== すべてOKです ===' -ForegroundColor Green
} else {
    Write-Host ("=== NG: {0} 件 / 注意: {1} 件 ===" -f $ng, $warn) -ForegroundColor $(if ($ng) { 'Red' } else { 'Yellow' })
    $results | Where-Object { $_.Status -in 'NG', '注意' } | ForEach-Object {
        Write-Host ("  [{0}] {1}: {2}" -f $_.Status, $_.Item, $_.Detail) -ForegroundColor $(if ($_.Status -eq 'NG') { 'Red' } else { 'Yellow' })
    }
}
if ($ng) { exit 1 } else { exit 0 }
