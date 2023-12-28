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
function Set-EventLogConfiguration {
    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string[]]$LogName,

        [Parameter()]
        [string[]]$Path,

        [Parameter()]
        [Nullable[int]]$Size,

        [Parameter()]
        [Nullable[bool]]$Retention,

        [Parameter()]
        [Nullable[bool]]$AutoBackup
    )

        #Write-Host "LogName: $($LogName)"
        #Write-Host "LogName is null?: $($null -eq $LogName)"
        #Write-Host "Path: $($Path)"
        #Write-Host "Path is null?: $($null -eq $Path)"
        #Write-Host "Size: $($Size)"
        #Write-Host "Size is null?: $($null -eq $Size)"
        #Write-Host "Retention: $($Retention)"
        #Write-Host "Retention is null?: $($null -eq $Retention)"
        #Write-Host "AutoBackup: $($AutoBackup)"
        #Write-Host "AutoBackup is null?: $($null -eq $AutoBackup)"


    if ($null -ne $Path -and $Path -ne "") {
        $DirPath = [System.Environment]::ExpandEnvironmentVariables("$($Path)\..")
        $FullDirPath = [System.IO.Path]::GetFullPath($DirPath)
        if (Test-Path $FullDirPath) {
            $pathOption = "/logfilename:$($Path)"
        }
        else {
            Write-Error "'Path' is invalid."
            return
        }
    }

    if ($null -ne $Retention) {
        $retentionStr = $Retention ? "true" : "false"
        $retentionOption = "/retention:$($retentionStr)"
    }

    if ($null -ne $AutoBackup) {
        $autoBackupStr = $AutoBackup ? "true" : "false"
        $autoBackupOption = "/autobackup:$($autoBackupStr)"
    }

    if ($null -ne $Size) {
        $maxSizeOption = "/maxsize:$($Size)"
    }

    if ($null -eq $pathOption -and $null -eq $retentionOption -and $null -eq $autoBackupOption -and $null -eq $maxSizeOption) {
        Write-Warning "No change."
        return
    }
    
    foreach ($item in $LogName) {
        if ($PSCmdlet.ShouldProcess("EventLog: $($LogName)", "Change setting of event log.")) {
        $output = (WEVTUTIL "set-log" "$($item)" "/quiet:true" $pathOption $retentionOption $autoBackupOption $maxSizeOption 2>&1)
        
        if (-not $?) {
            Write-Error "$($output)"
        }else{
            Write-Debug "$($output)"
        }}
    }
}