﻿<#
.SYNOPSIS
システムのイベントログにイベントを作成します。
.DESCRIPTION
Windows システムのイベントログにイベントを作成します。
.PARAMETER LogName
イベントが作成されるログの名前。
.PARAMETER Source
イベントのソース名。
.PARAMETER EntryType
イベントのタイプ（"Success", "Error", "Warning", "Information"）。
.PARAMETER EventId
イベントID（1 から 1000 の範囲）。
.PARAMETER Message
イベントの説明メッセージ。
.PARAMETER ComputerName
イベントが作成されるコンピュータの名前。指定されていない場合は現在のコンピュータ名が使用されます。
.EXAMPLE
Write-Log -LogName "Application" -Source "MyApp" -EntryType "Error" -EventId 100 -Message "エラーが発生しました"

この例では、アプリケーションログに "MyApp" ソースのエラーイベントを作成します。
.NOTES
この関数の実行には管理者権限が必要です。
.LINK
https://docs.microsoft.com/powershell/
#>
function Write-Log {
    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String]$Message,

        [Parameter()]
        [String]$LogName = "Application",

        [Parameter(Mandatory = $true)]
        [String]$Source,

        [Parameter()]
        [String]$EntryType = "Information",

        [Parameter()]
        [Int32]$EventId = 1,

        [Parameter()]
        [String]$ComputerName
    )

    if ($LogName -eq "") {
        Write-Error "'LogName' must not be empty."
    }

    if ($Source -eq "") {
        Write-Error "'Source' must not be empty."
    }

    if ($Message -eq "") {
        Write-Error "'Message' must not be empty."
    }

    if ($EventId -lt 1 -or 1000 -lt $EventId) {
        Write-Error "'EventId' must be between 1 and 1000."
        return
    }

    if ($EntryType -ne "Success" -and $EntryType -ne "Error" -and $EntryType -ne "Warning" -and $EntryType -ne "Information") {
        Write-Error "'EntryType' must be one of 'Success', 'Error', 'Warning', or 'Information'."
        return
    }

    if ($null -eq $ComputerName -or $ComputerName -eq "" -or $ComputerName -eq "." -or $ComputerName -eq "localhost") {
        $ComputerName = $env:COMPUTERNAME
    }

    $output = (EVENTCREATE "/S" "$ComputerName" "/ID" "$EventId" "/L" "$LogName" "/SO" "$Source" "/T" "$EntryType" "/D" "$Message" 2>&1)

    if (-not $?) {
        Write-Error "$output"
    }
    Write-Debug "EVENTCREATE `"/S`" `"$($ComputerName)`" `"/ID`" `"$($EventId)`" `"/L`" `"$($LogName)`" `"/SO`" `"$($Source)`" `"/T`" `"$($EntryType)`" `"/D`" `"$($Message)`" 2>&1 1> `$null"
}