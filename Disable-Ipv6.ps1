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
    Param()

    $prefix4Map6 = "::ffff:0:0/96"
    $prefixPolicies = Get-PrefixPolicy

    foreach ($netAdapter in Get-NetAdapter) {
        Disable-NetAdapterBinding $netAdapter.Name -ComponentID ms_tcpip6 -WhatIf:$WhatIfPreference
        Write-Debug "ms_tcpip6: $((Get-NetAdapterBinding $netAdapter.Name -ComponentID ms_tcpip6).Enabled)"
    }

    if ($PSCmdlet.ShouldProcess("interface ipv6 isatap", "set state disabled")) {
        NETSH "interface" "ipv6" "isatap" "set" "state" "disabled" > $null
    }
    Write-DebugMulti(NETSH "interface" "ipv6" "isatap" "show" "state")
    
    if ($PSCmdlet.ShouldProcess("interface ipv6 6to4", "set state disabled")) {
        NETSH "interface" "ipv6" "6to4" "set" "state" "disabled" > $null
    }
    Write-DebugMulti(NETSH "interface" "ipv6" "6to4" "show" "state")

    if ($PSCmdlet.ShouldProcess("interface ipv6 teredo", "set state disabled")) {
        NETSH "interface" "ipv6" "set" "teredo" "disabled" > $null
    }
    Write-DebugMulti(NETSH "interface" "ipv6" "show" "teredo")
    
    $label = -1
    $currentPrecedence = -1
    $maxPrecedence = -1
    foreach ($prefixPolicy in $prefixPolicies) {
        if ($prefixPolicy.Prefix -eq $prefix4Map6) {
            $currentPrecedence = $prefixPolicy.Precedence
            $label = $prefixPolicy.Label
        }
        else {
            $maxPrecedence = [Math]::Max($maxPrecedence, $prefixPolicy.Precedence)
        }
    }

    if ($label -ne -1 -and $maxPrecedence -ne -1 -and $currentPrecedence -ne -1 -and $currentPrecedence -ne $maxPrecedence) {
        foreach ($prefixPolicy in $prefixPolicies) {
            if ($prefixPolicy.Prefix -eq $prefix4Map6) {
                $prefixPolicy.Precedence = $maxPrecedence + 10
            }
        }

        if ($PSCmdlet.ShouldProcess("interface ipv6", "set prefixpolicy ::ffff:0:0/96 $($maxPrecedence + 10) $($label)")) {
            Set-PrefixPolicy($prefixPolicies)
        }
    }
    else {
        Write-Debug "label: $($label)"
        Write-Debug "maxPrecedence: $($maxPrecedence)"
        Write-Debug "currentPrecedence: $($currentPrecedence)"
    }
    
    Write-DebugMulti(NETSH "interface" "ipv6" "show" "prefixpolicies")
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

function Set-PrefixPolicy($prefixPolicies) {
    foreach ($prefixPolicy in $prefixPolicies) {
        NETSH "interface" "ipv6" "set" "prefixpolicy" "$($prefixPolicy.Prefix)" "$($prefixPolicy.Precedence)" "$($prefixPolicy.Label)" > $null
    }
    foreach ($prefixPolicy in $prefixPolicies) {
        NETSH "interface" "ipv6" "add" "prefixpolicy" "$($prefixPolicy.Prefix)" "$($prefixPolicy.Precedence)" "$($prefixPolicy.Label)" > $null
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