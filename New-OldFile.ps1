﻿<#
.SYNOPSIS
指定されたディレクトリ内に複数のランダムファイルを生成します。
.DESCRIPTION
このスクリプトは、指定されたディレクトリに、指定されたファイルサイズ、数、名前フォーマット、および時間間隔を持つランダムファイルを生成します。各ファイルの作成時刻と最終変更時刻は、指定された開始時間から逆算して設定されます。
.PARAMETER Directory
ランダムファイルを生成するディレクトリのパス。
.PARAMETER Start
ファイルの作成時刻と最終変更時刻の開始点となる日時。
.PARAMETER FormatString
生成するファイルの名前フォーマット。DateTime.ToString(string) の引数となる文字列。デフォルトは 'Arc\hive-Applica\tion-yyyy-MM-dd-HH-mm-ss-fff.ev\tx'。
.PARAMETER IntervalHours
連続するファイル間の時間間隔（時間単位）。デフォルトは 30 時間。
.PARAMETER Count
生成するファイルの総数。デフォルトは 32。
.PARAMETER FileLength
生成するファイルのサイズ（バイト単位）。デフォルトは 64 バイト。
.EXAMPLE
New-OldFile -Directory "C:\Test" -Start "2023-12-01T00:00:00" -Count 10 -FileLength 1024

この例では、C:\Test ディレクトリに、10 個の 1KB サイズのランダムファイルを生成します。ファイルの作成時刻と最終変更時刻は、2023年12月1日から始まります。
.LINK
https://docs.microsoft.com/powershell/
#>
function New-OldFile {
    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Directory,

        [Parameter()]
        [datetime]$Start = [System.DateTime]::Now,

        [Parameter()]
        [string]$FormatString = "Arc\hive-Applica\tion-yyyy-MM-dd-HH-mm-ss-fff.ev\tx",

        [ValidateRange(1, 2147483647)]
        [Parameter()]
        [int]$IntervalHours = 30,

        [ValidateRange(1, 2147483647)]
        [Parameter()]
        [int]$Count = 32,

        [ValidateRange(1, 2147483647)]
        [Parameter()]
        [string]$FileLength = 64
    )

    function New-RandomFile([Parameter(Mandatory = $true)][string]$OutPath, [Parameter(Mandatory = $true)][long]$FileSize, [int]$ChunkSize = 16MB) {
        $bin1 = [byte[]]::new($ChunkSize);
        $bin2 = [byte[]]::new($ChunkSize);
        $r = [System.Random]::new();
        [long]$progress = 0;
        [int]$nextLen = 0;
        $fs = [System.IO.File]::Create($OutPath);
        try {
            do {
                $task = $fs.WriteAsync($bin1, 0, $nextLen);
                $r.NextBytes($bin2);
                $task.Wait();
                $bin1, $bin2 = $bin2, $bin1;
                $progress += $nextLen;
                $nextLen = [System.Math]::Min([long]$ChunkSize, $FileSize - $progress);
            } while ($nextLen -gt 0);
        }
        finally {
            $fs.Dispose();
        }
    }

    if ($null -eq $FormatString -or $FormatString -eq "") {
        $FormatString = "Arc\hive-Applica\tion-yyyy-MM-dd-HH-mm-ss-fff.ev\tx"
    }

    if (-not (Test-Path $Directory)) {
        New-Item -ItemType Directory -Path $Directory -Force -WhatIf:$WhatIfPreference | Out-Null
    }
    $Directory = (Resolve-Path $Directory)

    
    $i = 0
    $threashold = $Count - $Count % 5

    if ($threashold -le 0) {
        $mtime = $Start
    }
    else {
        $mtime = $Start.AddHours($IntervalHours * 5)
    }
    for (; $i -lt $threashold; $i++) {
        if ($i % 5 -eq 0) {
            $mtime = $mtime.AddHours(-$IntervalHours * 9)
        }
        else {
            $mtime = $mtime.AddHours($IntervalHours)
        }
        $ctime = $mtime.AddHours(-$IntervalHours)

        $filePath = "$($Directory)\$($mtime.ToString($FormatString))"
        if ($PSCmdlet.ShouldProcess($filePath, "Create a file of size $($FileLength)")) {
            New-RandomFile $filePath -FileSize $FileLength
            [System.IO.File]::SetLastWriteTime($filePath, $mtime)
            [System.IO.File]::SetCreationTime($filePath, $ctime)
            Write-Debug "Creating a file at '$($filePath)' with a size of '$($FileLength) bytes'"
        }
    }

    Write-Debug "--------------------------"
    if (0 -lt $threashold) {
        $mtime = $mtime.AddHours(-$IntervalHours * 5)
    }
    $ctime = $mtime.AddHours(-$IntervalHours)

    for (; $i -lt $Count; $i++) {
        $filePath = "$($Directory)\$($mtime.ToString($FormatString))"
        if ($PSCmdlet.ShouldProcess($filePath, "Create a file of size $($FileLength)")) {
            New-RandomFile $filePath -FileSize $FileLength
            [System.IO.File]::SetLastWriteTime($filePath, $mtime)
            [System.IO.File]::SetCreationTime($filePath, $ctime)
            Write-Debug "Creating a file at '$($filePath)' with a size of '$($FileLength) bytes'"
        }

        $mtime = $ctime
        $ctime = $mtime.AddHours(-$IntervalHours)
    }
}