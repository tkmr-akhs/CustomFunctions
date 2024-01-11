Import-Module $PSScriptRoot\InternalUtils.psm1 -Scope Local

<#
.SYNOPSIS
IPv6 を無効にします。
.DESCRIPTION
Windows システムで、IPv6 を無効にします。
.EXAMPLE
Disable-Ipv6
このコマンドは、IPv6 を無効にします。
.NOTES
このスクリプトは、管理者権限で実行する必要があります。
.LINK
https://docs.microsoft.com/powershell/
#>
function Disable-Ipv6 {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter()]
        [switch]$Json
    )

    #### Local Functions ################
    function IsEnabled([string[]]$output) {
        foreach ($line in $output) {
            if ($line -match '^(.*)\s*:\s(.*)') {
                if ($Matches[2] -eq "enabled") {
                    return $true
                }
                elseif ($Matches[2] -eq "disabled") {
                    return $false
                }
            }
        }
        return $true
    }

    #### Main ################
    $failed = $false
    $changed = $false
    $message = ""

    $prefix4Map6 = "::ffff:0:0/96"
    $prefixPolicies = Get-PrefixPolicy

    foreach ($netAdapter in Get-NetAdapter) {
        Disable-NetAdapterBinding $netAdapter.Name -ComponentID ms_tcpip6 -WhatIf:$WhatIfPreference
        Write-Debug "ms_tcpip6: $((Get-NetAdapterBinding $netAdapter.Name -ComponentID ms_tcpip6).Enabled)"
    }

    if (IsEnabled (NETSH "interface" "ipv6" "isatap" "show" "state" 2>&1)) {
        Write-Debug "Disable ISATAP."
        if ($PSCmdlet.ShouldProcess("interface ipv6 isatap", "set state disabled")) {
            $output = (NETSH "interface" "ipv6" "isatap" "set" "state" "disabled" 2>&1)
            if ($?) {
                $changed = $true
            }
            else {
                $failed = $true
                $message = "$($message)$($output.Trim()))`r`n"
                Write-Error $message
            }
        }
    }
    
    if (IsEnabled (NETSH "interface" "ipv6" "6to4" "show" "state")) {
        Write-Debug "Disable 6to4."
        if ($PSCmdlet.ShouldProcess("interface ipv6 6to4", "set state disabled")) {
            $output = (NETSH "interface" "ipv6" "6to4" "set" "state" "disabled" 2>&1)
            if ($?) {
                $changed = $true
            }
            else {
                $failed = $true
                $message = "$($message)$($output.Trim()))`r`n"
                Write-Error "$($output)"
            }
        }
    }

    if (IsEnabled (NETSH "interface" "ipv6" "show" "teredo")) {
        Write-Debug "Disable teredo."
        if ($PSCmdlet.ShouldProcess("interface ipv6 teredo", "set state disabled")) {
            $output = (NETSH "interface" "ipv6" "set" "teredo" "disabled" 2>&1)
            if ($?) {
                $changed = $true
            }
            else {
                $failed = $true
                $message = "$($message)$($output.Trim()))`r`n"
                Write-Error "$($output)"
            }
        }
    }
    
    $label = -1
    $currentPrecedence = -1
    $maxPrecedence = -1
    foreach ($prefixPolicy in $prefixPolicies) {
        if ($prefixPolicy.Prefix -eq $prefix4Map6) {
            $currentPrecedence = $prefixPolicy.Precedence
            $label = $prefixPolicy.Label
        }
        
        $maxPrecedence = [Math]::Max($maxPrecedence, $prefixPolicy.Precedence)
    }

    if ($label -ne -1 -and $maxPrecedence -ne -1 -and $currentPrecedence -ne -1 -and $currentPrecedence -ne $maxPrecedence) {
        foreach ($prefixPolicy in $prefixPolicies) {
            if ($prefixPolicy.Prefix -eq $prefix4Map6) {
                $prefixPolicy.Precedence = $maxPrecedence + 10
            }
        }

        if ($PSCmdlet.ShouldProcess("interface ipv6", "set prefixpolicy ::ffff:0:0/96 $($maxPrecedence + 10) $($label)")) {
            $setPrefixResult = Set-PrefixPolicy $prefixPolicies $message
            $failed = $setPrefixResult.failed
            $message = $setPrefixResult.message
        }
    }
    else {
        Write-Debug "label: $($label)"
        Write-Debug "maxPrecedence: $($maxPrecedence)"
        Write-Debug "currentPrecedence: $($currentPrecedence)"
    }

    if (-not $changed -and -not $failed) {
        return (New-ResultJson "No change." -Changed $false -Failed $false -Json:$Json)
    }
    elseif ($failed) {
        return (New-ResultJson $message -Changed $changed -Failed $true -Json:$Json)
    }
    else {
        return (New-ResultJson "Disable IPv6 functions successfully." -Changed $changed -Failed $failed -Json:$Json)
    }
}

function Get-PrefixPolicy() {
    $output = (NETSH "interface" "ipv6" "show" "prefixpolicies")

    $prefixPolicies = foreach ($line in $output) {
        if ($line -match '^\s*(\d+)\s+(\d+)\s+([\da-fA-F:\/]+)$') {
            $Precedence = [int]$matches[1]
            $label = [int]$matches[2]
            $prefix = $matches[3]
            [PrefixPolicy]::new($prefix, $Precedence, $label)
        }
    }
    
    return $prefixPolicies
}

function Set-PrefixPolicy($prefixPolicies, [string]$message) {
    $failed = $false
    foreach ($prefixPolicy in $prefixPolicies) {
        Write-Debug "Set $prefixPolicy"
        $output = (NETSH "interface" "ipv6" "set" "prefixpolicy" "$($prefixPolicy.Prefix)" "$($prefixPolicy.Precedence)" "$($prefixPolicy.Label)" 2>&1)
        
        if (-not $?) {
            Write-Debug "Add $prefixPolicy"
            $output = (NETSH "interface" "ipv6" "add" "prefixpolicy" "$($prefixPolicy.Prefix)" "$($prefixPolicy.Precedence)" "$($prefixPolicy.Label)" 2>&1)
            if (-not $?) {
                $failed = $true
                $message = "$($message)$($output.Trim()))`r`n"
                Write-Error "$($output.Trim())"
            }
        }
    }

    return @{
        failed  = $failed
        message = $message
    }
}

class PrefixPolicy {
    [string]$Prefix
    [int]$Precedence
    [int]$Label
    PrefixPolicy([string]$Prefix, [int]$Precedence, [int]$Label) {
        $this.Prefix = $Prefix
        $this.Precedence = $Precedence
        $this.Label = $Label
    }
    [string] ToString() {
        return "Prefix: $($this.Prefix), Precedence: $($this.Precedence), Label: $($this.Label)"
    }
}