function Write-DebugMulti($lines) {
    foreach ($line in $lines) {
        Write-Debug $line
    }
}

function Write-WarningToHostAndLog([string]$message, [string]$source, [bool]$logging) {
    Write-Warning $message
    if ($logging) {
        Write-Log $message -Source $source -EntryType Warning
    }
}

function Write-InformationToHostAndLog([string]$message, [string]$source, [bool]$logging) {
    Write-Information "INFO: $($message)" -InformationAction Continue
    if ($logging) {
        Write-Log $message -Source $source
    }
}