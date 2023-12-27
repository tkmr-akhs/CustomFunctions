<#
.SYNOPSIS
概要。
.DESCRIPTION
詳細。
.PARAMETER Param1
引数の説明。
.PARAMETER Param1
引数の説明。
.EXAMPLE
使用例
.NOTES
注意書き。
.LINK
参考 URL。
#>
function Set-EventLogArchive {
    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Param1,

        [Parameter(Position = 1)]
        [string]$Param2 = "DefaultValue"
    )

    # 処理
}