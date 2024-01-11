Import-Module $PSScriptRoot\InternalUtils.psm1 -Scope Local

<#
.SYNOPSIS
システムのイベント ログにイベントを記録します。
.DESCRIPTION
Windows システムのイベント ログにイベントを記録します。新しい PowerShell では Write-EventLog がなくなったため、EVENTCRATE に基づいた代替手段です。
.PARAMETER LogName
イベントが記録されるログの名前。デフォルト値は Application です。
.PARAMETER Source
イベントのソース名。
.PARAMETER EntryType
イベントのタイプ（"Success", "Error", "Warning", "Information"）。デフォルト値は Information です。
.PARAMETER EventId
イベントID（1 から 1000 の範囲）。デフォルト値は 1 です。
.PARAMETER Message
イベントの説明メッセージ。
.PARAMETER ComputerName
イベントが作成されるコンピューターの名前。指定されていない場合は現在のコンピューター名が使用されます。
.EXAMPLE
Write-Log -LogName "Application" -Source "MyApp" -EntryType "Error" -EventId 100 -Message "エラーが発生しました"

この例では、アプリケーション ログに "MyApp" ソースのエラーイベントを作成します。
.NOTES
このスクリプトは、管理者権限で実行する必要があります。
.LINK
https://docs.microsoft.com/powershell/
#>
function Write-Log {
    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String]$Message,

        [ValidateLength(1, 2147483647)]
        [Parameter()]
        [String]$LogName = "Application",

        [Parameter(Mandatory = $true)]
        [String]$Source,

        [ValidateSet(1, 2147483647)]
        [Parameter("Success", "Error", "Warning", "Information")]
        [String]$EntryType = "Information",

        [ValidateRange(1, 1000)]
        [Parameter()]
        [Int32]$EventId = 1,

        [Parameter()]
        [String]$ComputerName
    )

    if ($null -eq $ComputerName -or $ComputerName -eq "" -or $ComputerName -eq "." -or $ComputerName -eq "localhost") {
        $ComputerName = $env:COMPUTERNAME
    }

    if ($PSCmdlet.ShouldProcess("EventLog: $($LogName)", "Write Event. Message: '$($Message)', ComputerName: $($ComputerName), Source: $($Source), EventId: $($EventId), EntryType: $($EntryType)")) {
        $output = (EVENTCREATE "/S" "$ComputerName" "/ID" "$EventId" "/L" "$LogName" "/SO" "$Source" "/T" "$EntryType" "/D" "$Message" 2>&1)

        if (-not $?) {
            Write-Error "$output"
        }
    }
}