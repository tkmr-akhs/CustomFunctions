function Write-DebugMulti($lines) {
    foreach ($line in $lines) {
        Write-Debug $line
    }
}

function Write-WarningToHostAndLog([string]$message, [string]$source, [bool]$logging, [bool]$whatIfPref) {
    Write-Warning $message
    
    if ($logging) {
        Write-Log $message -Source $source -EntryType Warning -WhatIf:$whatIfPref
    }
}

function Write-InformationToHostAndLog([string]$message, [string]$source, [bool]$logging, [bool]$whatIfPref) {
    Write-Information "INFO: $($message)" -InformationAction Continue
    
    if ($logging) {
        Write-Log $message -Source $source -WhatIf:$whatIfPref
    }
}

function Get-ParentPath([Parameter(Mandatory = $true)][string]$Path) {
    $expandedPath = [System.Environment]::ExpandEnvironmentVariables($Path)
    return Split-Path $expandedPath -Parent
}

function Test-FullyQualifiedAbsolutePath([Parameter(Mandatory = $true)][string]$Path) {
    $expandedPath = [System.Environment]::ExpandEnvironmentVariables($Path)
    
    if (-not [System.IO.Path]::IsPathRooted($expandedPath)) {
        return $false
    }

    try {
        Split-Path $expandedPath -Qualifier -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function New-ResultJson {
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String]$Message,

        [Parameter()]
        [bool]$Changed = $false,

        [Parameter()]
        [bool]$Failed = $false,

        [Parameter()]
        [switch]$Json
    )

    if ($Json) {
        return (@{
                changed = $Changed
                failed  = $Failed
                msg     = $Message
            } | ConvertTo-Json)
    }
    else {
        return (@{
                changed = $Changed
                failed  = $Failed
                msg     = $Message
            })
    }
}