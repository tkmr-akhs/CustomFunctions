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