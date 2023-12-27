Import-Module $PSScriptRoot\InternalUtils.psm1 -Scope Local

<#
.SYNOPSIS
指定されたディレクトリ内の古いファイルを削除または圧縮します。
.DESCRIPTION
指定されたディレクトリから、特定の条件（日付、空き容量など）に基づいて古いファイルを削除します。このスクリプトは、Windows システムのメンテナンスやクリーンアップのために使用されます。
.PARAMETER Directory
処理の対象となるディレクトリを指定します。
.PARAMETER FilePattern
処理の対象となるファイルパターンを指定します。デフォルトは全ファイル("*")です。
.PARAMETER CutoffDays
このパラメータは、削除するファイルの古さを日単位で指定します。デフォルト値は 366 日です。
.PARAMETER CutoffPercent
ディスクの空き容量がこのパーセンテージ未満の場合に、ファイルの削除処理を開始します。
.PARAMETER Compress
このオプションが指定された場合、パターンに合致するファイルが圧縮されます。
.PARAMETER Logging
処理中の警告、および削除または圧縮成功をイベント ログに記録します。
.EXAMPLE
Remove-OldFile "C:\Temp"
このコマンドは、C:\Temp ディレクトリ内の古いファイルをデフォルトの設定で削除します。
.EXAMPLE
Remove-OldFile "C:\Temp" "Archive-*-*-*-*-*-*-*-*.evtx" -CutoffDays 30 -Compress
このコマンドは、30 日以上古い、「Archive-*-*-*-*-*-*-*-*.evtx」という形式の名前のファイルを C:\Temp ディレクトリから削除します。
.NOTES
このスクリプトは、管理者権限で実行する必要があります。
.LINK
https://docs.microsoft.com/powershell/
#>
function Remove-OldFile {
    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Directory,

        [Parameter(Position = 1)]
        [string]$FilePattern = "*",
        #[string]$FilePattern = "Archive-*-*-*-*-*-*-*-*.evtx"

        [Parameter()]
        [Int]$CutoffDays,

        [Parameter()]
        [Int]$CutoffPercent,

        [Parameter()]
        [Switch]$Compress,

        [Parameter()]
        [Switch]$Logging
    )
    
    #### Consts ################
    $maxidx = 500
    
    #### Local Functions ################
    function _checkFileNameForRemove([string]$fileName, [string]$pattern, [bool]$compress) {
        if ($compress) {
            return $fileName -like $FilePattern
        }
        else {
            $compressName = "$($filename).zip"
            return $fileName -like $FilePattern -or $fileName -like $compressName
        }
    }

    #### Main ################
    if ($null -eq $Directory -or $Directory -eq "") {
        Write-Error "'Directory' must not be empty."
        return
    }

    if ($CutoffPercent -lt 1 -or 100 -lt $CutoffPercent) {
        Write-Error "'CutoffPercent' must be between 1 and 100."
        return
    }

    $DateBased = ($null -eq $CutoffDays)
    $FreeSpaceBased = ($null -eq $CutoffPercent)

    if (-not $DateBased -and -not $FreeSpaceBased) {
        $CutoffDays = 366
        $DateBased = $true
    }

    if ($CutoffDays -lt 1) {
        Write-Error "'CutoffDays' must be greater than 0."
        return
    }

    Write-InformationToHostAndLog "フォルダー '$($Directory)' の処理を開始します。" $MyInvocation.MyCommand.Name $Logging

    # 圧縮処理
    if ($Compress) {
        $target_files = (Get-ChildItem $Directory | where { $_.Name -like $FilePattern -and $_ -is [System.IO.FileInfo] })
 
        if ($target_files.Length -gt 0) {
            foreach ($target_file in $target_files) {
                try {
                    Compress-Archive -Path $target_file.FullName -DestinationPath $target_file.FullName -WhatIf:$WhatIfPreference
                    Remove-Item $target_file.FullName -WhatIf:$WhatIfPreference
                    Write-InformationToHostAndLog "ファイル '$($target_file)' を圧縮しました。" $MyInvocation.MyCommand.Name $Logging
                }
                catch {
                    Write-WarningToHostAndLog "ファイル '$($target_file)' の圧縮処理ができませんでした。" $MyInvocation.MyCommand.Name $Logging
                }
            }
        }
    }
    # 空き容量に基づく削除処理
    if ($FreeSpaceBased) {
        # 対象ファイルの取得
        $target_files = (Get-ChildItem $Directory | where { _checkFileNameForRemove($_.Name, $FilePattern, $Compress) -and $_ -is [System.IO.FileInfo] } | sort LastWriteTime)
 
        if ($target_files.Length -gt 0) {
            # PSDrive オブジェクトを取得
            $target_drive = $target_files[0].PSDrive
 
            # ドライブ空き容量
            $drive_free = $target_drive.Free
 
            # ドライブ使用済み容量
            $drive_used = $target_drive.Used
 
            # ドライブ合計容量
            $drive_all = $drive_free + $drive_used
 
            if (($drive_free / $drive_all * 100) -lt $CutoffPercent) {
                $idx = 0
                while (($drive_free / $drive_all * 100) -lt $CutoffPercent -and $idx -lt $target_files.Length -and $idx -lt $maxidx) {
                    $target_file = $target_files[$idx]
                    try {
                        Remove-Item $target_file.FullName -WhatIf:$WhatIfPreference

                        Write-InformationToHostAndLog "ファイル '$($target_file)' を削除しました。" $MyInvocation.MyCommand.Name $Logging
 
                        # 空き容量の更新
                        $drive_free = $target_drive.Free
 
                        # インデックスのインクリメント
                        $idx ++
                    }
                    catch {
                        if ($null -ne $target_file -and $target_file -ne "") {
                            Write-WarningToHostAndLog "ファイル '$($target_file)' の削除処理ができませんでした。" $MyInvocation.MyCommand.Name $Logging
                        }
                        $idx ++
                    }
                }
            }
        }
    }
    $today = (Get-Date).Date

    # 日付に基づく削除処理
    if ($DateBased) {
        # 対象ファイルの取得
        $target_files = (Get-ChildItem $Directory | where { _checkFileNameForRemove($_.Name, $FilePattern, $Compress) -and $_ -is [System.IO.FileInfo] } | sort LastWriteTime)
 
        if ($target_files.Length -gt 0) {
            $idx = 0
            while ($idx -lt $target_files.Length -and $idx -lt $maxidx) {
                $target_file = $target_files[$idx]
 
                $lastwrite = $target_file.LastWriteTime
                $elapsed = ($today - $lastwrite).TotalDays
                if ($elapsed -lt $CutoffDays) {
                    break
                }
                else {
                    try {
                        Remove-Item $target_file.FullName -WhatIf:$WhatIfPreference
                        Write-InformationToHostAndLog "ファイル '$($target_file)' を削除しました。" $MyInvocation.MyCommand.Name $Logging
                        $idx ++
                    }
                    catch {
                        if ($null -ne $target_file -and $target_file -ne "") {
                            Write-WarningToHostAndLog "ファイル '$($target_file)' の削除処理ができませんでした。" $MyInvocation.MyCommand.Name $Logging
                        }
                        $idx ++
                    }
                }
            }
        }
    }

    Write-InformationToHostAndLog "フォルダー '$($Directory)' の処理が完了しました。" $MyInvocation.MyCommand.Name $Logging
}