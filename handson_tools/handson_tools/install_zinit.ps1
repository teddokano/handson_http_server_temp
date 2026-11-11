<#
.SYNOPSIS
  Zephyrデビュー会: zinit 関数を PowerShell プロファイルに登録する．

.DESCRIPTION
  全ホスト共通のユーザープロファイル（$PROFILE.CurrentUserAllHosts）に，
  zinit 関数を書き込みます．Windows PowerShell のウィンドウでも，
  VSCode のターミナルでも zinit が使えるようになります．

  プロファイル内の「# >>> zephyr-handson >>>」から「# <<< zephyr-handson <<<」
  までをこのスクリプトが管理します．何度実行しても重複せず，最新の内容に置き換わります．
  それ以外の行には手を触れません．

  zinit の使い方:
    zinit              ... 仮想環境の有効化と ZEPHYR_BASE の設定（記事のコマンド例2.1-1と同じ）
    zinit thermometer  ... 上に加えて ~\handson\thermometer に移動する
                           （サンプル名は Tab キーで補完できます）

.PARAMETER Workspace
  Zephyr ワークスペースの場所．既定は ~\zephyrproject．

.PARAMETER Uninstall
  プロファイルから zinit を削除する．

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install_zinit.ps1
#>
[CmdletBinding()]
param(
    [string]$Workspace = (Join-Path $HOME 'zephyrproject'),
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$beginMark = '# >>> zephyr-handson >>>'
$endMark   = '# <<< zephyr-handson <<<'

# プロファイルに書き込む内容．Workspace のパスはここで埋め込む．
$block = @'
# >>> zephyr-handson >>>
# Zephyrデビュー会 ハンズオン用（install_zinit.ps1 が管理．この範囲は手で編集しないでください）
function zinit {
    param([string]$Sample)

    $ws = '__WORKSPACE__'
    $activate = Join-Path $ws '.venv\Scripts\Activate.ps1'
    if (-not (Test-Path $activate)) {
        Write-Host "Zephyrのワークスペースが見つかりません: $ws" -ForegroundColor Red
        return
    }

    Set-Location $ws
    . $activate
    $env:ZEPHYR_BASE = Join-Path $ws 'zephyr'

    west --version
    west topdir

    if ($Sample) {
        $dir = Join-Path (Join-Path $HOME 'handson') $Sample
        if (Test-Path $dir) {
            Set-Location $dir
            Write-Host "作業フォルダに移動しました: $dir" -ForegroundColor Green
        } else {
            Write-Host "フォルダが見つかりません: $dir" -ForegroundColor Yellow
            $root = Join-Path $HOME 'handson'
            if (Test-Path $root) {
                $names = (Get-ChildItem $root -Directory | ForEach-Object { $_.Name }) -join ', '
                if ($names) { Write-Host "  ~\handson にあるフォルダ: $names" }
            }
        }
    } else {
        Write-Host "準備ができました．作業していたサンプルのフォルダに cd で移動してください（例: cd ~\handson\thermometer）" -ForegroundColor Green
    }
}

Register-ArgumentCompleter -CommandName zinit -ParameterName Sample -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete)
    $root = Join-Path $HOME 'handson'
    if (Test-Path $root) {
        Get-ChildItem $root -Directory |
            Where-Object { $_.Name -like "$wordToComplete*" } |
            ForEach-Object { $_.Name }
    }
}
# <<< zephyr-handson <<<
'@
$block = $block.Replace('__WORKSPACE__', $Workspace.Replace("'", "''"))

$profilePath = $PROFILE.CurrentUserAllHosts
$profileDir = Split-Path $profilePath -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Force $profileDir | Out-Null
}

$current = ''
if (Test-Path $profilePath) {
    $current = [System.IO.File]::ReadAllText($profilePath)
}

# 既存の管理ブロックを取り除く
$pattern = '(?s)\r?\n?' + [regex]::Escape($beginMark) + '.*?' + [regex]::Escape($endMark) + '\r?\n?'
$stripped = [regex]::Replace($current, $pattern, "`r`n").TrimEnd()

if ($Uninstall) {
    $newText = $stripped
    $message = "zinit をプロファイルから削除しました: $profilePath"
} else {
    if (-not (Test-Path (Join-Path $Workspace '.venv\Scripts\Activate.ps1'))) {
        Write-Warning "ワークスペースに仮想環境が見つかりません: $Workspace （登録は続行します）"
    }
    if ($stripped) {
        $newText = $stripped + "`r`n`r`n" + ($block -replace "`r?`n", "`r`n")
    } else {
        $newText = ($block -replace "`r?`n", "`r`n")
    }
    $message = "zinit をプロファイルに登録しました: $profilePath"
}

# Windows PowerShell 5.1 が日本語を正しく読めるよう，BOM付きUTF-8で保存する
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($profilePath, $newText.TrimEnd() + "`r`n", $utf8Bom)

Write-Host $message -ForegroundColor Green
if (-not $Uninstall) {
    Write-Host '新しく開いた PowerShell のウィンドウから zinit が使えます．'
}
