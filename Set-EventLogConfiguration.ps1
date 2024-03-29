﻿Import-Module $PSScriptRoot\InternalUtils.psm1 -Scope Local

<#
.SYNOPSIS
イベント ログの設定を変更します。
.DESCRIPTION
Set-EventLogConfiguration は、指定されたイベントログの設定を変更するための関数です。
イベント ログ ファイルのパス、サイズ、保持期間、自動バックアップの設定を変更できます。
.PARAMETER LogName
変更するイベント ログの名前。このパラメータは必須です。
.PARAMETER Path
イベント ログ ファイルの新しい場所。指定しない場合、この設定は変更されません。
.PARAMETER Size
イベント ログ ファイルの最大サイズ (バイト単位)。指定しない場合、この設定は変更されません。
.PARAMETER Retention
イベント ログの保持設定 (true または false)。指定しない場合、この設定は変更されません。
.PARAMETER AutoBackup
イベント ログがいっぱいになった時の自動バックアップ設定 (true または false)。指定しない場合、この設定は変更されません。
.EXAMPLE
Set-EventLogConfiguration -LogName "Application" -Size 20MB -Retention $true -AutoBackup $false
アプリケーション ログの最大サイズを20MBに設定し、ログの保持と自動バックアップを無効にします。
.NOTES
このスクリプトは、管理者権限で実行する必要があります。
.LINK
https://docs.microsoft.com/powershell/
#>
function Set-EventLogConfiguration {
    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [ValidateLength(1, 2147483647)]
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$LogName,

        [Parameter()]
        [string]$Path,

        [ValidateRange(1052672, 2147483647)]
        [Parameter()]
        [Nullable[int]]$Size,

        [Parameter()]
        [Nullable[bool]]$Retention,

        [Parameter()]
        [Nullable[bool]]$AutoBackup
    )

    #### Local Functions ################
    function Get-EventLogConfiguration([string]$LogName) {
        $output = (WEVTUTIL "get-log" $LogName 2>&1)

        if (-not $?) {
            Write-Error "$($output)"
            return
        }

        return [EventLogConfiguration]::new($output)
    }

    function Test-EventLogConfigurationChange([EventLogConfiguration]$evtConfig, [string]$Path, [Nullable[int]]$Size, [Nullable[bool]]$Retention, [Nullable[bool]]$AutoBackup) {
        return ([System.String]::IsNullOrEmpty($Path) -or $currentLogConfig.Logging.LogFileName -eq $Path) `
            -and ($null -eq $Retention -or $currentLogConfig.Logging.Retention -eq $Retention) `
            -and ($null -eq $AutoBackup -or $currentLogConfig.Logging.AutoBackup -eq $AutoBackup) `
            -and ($null -eq $Size -or $currentLogConfig.Logging.MaxSize -eq $Size)
    }

    #### Main ################
    [EventLogConfiguration]$currentLogConfig
    try {
        $currentLogConfig = Get-EventLogConfiguration $LogName -ErrorAction Stop
    }
    catch {
        New-FunctionResult $_ -Changed $false -Failed $true
        Write-Error $_
        return
    }

    if (-not [System.String]::IsNullOrEmpty($Path)) {
        $DirPath = Get-ParentPath $Path
        if (-not $Path.EndsWith("\") -and -not $Path.EndsWith("/") -and (Test-FullyQualifiedAbsolutePath $Path) -and (Test-Path $DirPath)) {
            $pathOption = "/logfilename:$($Path)"
        }
        else {
            $msg = "'Path' is invalid."
            New-FunctionResult $msg -Changed $false -Failed $false
            Write-Error $msg
            return
        }
    }

    if ($null -ne $Retention) {
        #$retentionStr = $Retention ? "true" : "false"
        if ($Retention) {
            $retentionStr = "true"
        }
        else {
            $retentionStr = "false"
        }

        $retentionOption = "/retention:$($retentionStr)"

        if (-not $Retention -and $null -eq $AutoBackup) {
            $AutoBackup = $false
        }
    }

    if ($null -ne $AutoBackup) {
        #$autoBackupStr = $AutoBackup ? "true" : "false"
        if ($AutoBackup) {
            $autoBackupStr = "true"
        }
        else {
            $autoBackupStr = "false"
        }

        $autoBackupOption = "/autobackup:$($autoBackupStr)"
    }

    if ($null -ne $Size) {
        $maxSizeOption = "/maxsize:$($Size)"
    }

    if (Test-EventLogConfigurationChange $currentLogConfig $Path $Size $Retention $AutoBackup) {
        New-FunctionResult "No changes are made." -Changed $false -Failed $false
        return
    }

    Write-Debug "WEVTUTIL set-log $LogName /quiet:true $pathOption $retentionOption $autoBackupOption $maxSizeOption 2>&1"
    if ($PSCmdlet.ShouldProcess("EventLog: $($LogName)", "Change setting of event log.")) {
        $output = (WEVTUTIL "set-log" $LogName "/quiet:true" $pathOption $retentionOption $autoBackupOption $maxSizeOption 2>&1)
        
        if (-not $?) {
            New-FunctionResult "$($output)" -Changed $false -Failed $true
            Write-Error "$($output)"
            return
        }
        else {
            New-FunctionResult "Event log configuration updated successfully." -Changed $true -Failed $false
            return
        }
    }
    else {
        New-FunctionResult "(dry-run) Event log configuration updated successfully." -Changed $true -Failed $false
        return
    }
}

class EventLogLoggingConfiguration {
    [string]$LogFileName
    [bool]$Retention
    [bool]$AutoBackup
    [int]$MaxSize
}

class EventLogPublishingConfiguration {
    [int]$FileMax
}

class EventLogConfiguration {
    [string]$Name
    [bool]$Enabled
    [string]$Type
    [string]$OwningPublisher
    [string]$Isolation
    [string]$channelAccess
    [EventLogLoggingConfiguration]$Logging
    [EventLogPublishingConfiguration]$Publishing

    EventLogConfiguration([string[]]$stdout) {
        foreach ($line in $stdout) {
            if ($line -match '^\s*(\w+):\s*(.*)') {

                switch ($Matches[1]) {
                    "name" { $this.Name = $Matches[2] }
                    "enabled" { $this.Enabled = [System.Boolean]::Parse($Matches[2]) }
                    "type" { $this.Type = $Matches[2] }
                    "owningPublisher" { $this.OwningPublisher = $Matches[2] }
                    "isolation" { $this.Isolation = $Matches[2] }
                    "channelAccess" { $this.channelAccess = $Matches[2] }
                    "logging" { $this.Logging = [EventLogLoggingConfiguration]::new() }
                    "logFileName" { $this.Logging.LogFileName = $Matches[2] }
                    "retention" { $this.Logging.Retention = [System.Boolean]::Parse($Matches[2]) }
                    "autoBackup" { $this.Logging.AutoBackup = [System.Boolean]::Parse($Matches[2]) }
                    "maxSize" { $this.Logging.MaxSize = [System.Int32]::Parse($Matches[2]) }
                    "publishing" { $this.Publishing = [EventLogPublishingConfiguration]::new() }
                    "fileMax" { $this.Publishing.FileMax = [System.Int32]::Parse($Matches[2]) }
                    Default { Write-Debug $line }
                }
            }
        }
    }
}