# この行をコメントアウト解除すると、デバッグ出力が表示される。(規定値は "SilentContinue")
#$DebugPreference = "Continue"

# 他の .psm1 ファイルをドットソーシング
. $PSScriptRoot\Write-Log.ps1
. $PSScriptRoot\Disable-Ipv6.ps1
. $PSScriptRoot\New-OldFile.ps1
. $PSScriptRoot\Remove-OldFile.ps1
. $PSScriptRoot\Remove-UnknownAccountProfile.ps1
. $PSScriptRoot\Set-EventLogConfiguration.ps1
. $PSScriptRoot\Set-ProfilesDirectory.ps1

# 必要な関数や変数をエクスポート
Export-ModuleMember -Function `
    'Write-Log', `
    'Disable-Ipv6', `
    'New-OldFile', `
    'Remove-OldFile', `
    'Remove-UnknownAccountProfile', `
    'Set-EventLogConfiguration', `
    'Set-ProfilesDirectory'