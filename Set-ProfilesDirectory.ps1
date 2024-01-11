Import-Module $PSScriptRoot\InternalUtils.psm1 -Scope Local

<#
.SYNOPSIS
ユーザー プロファイルが生成される既定のディレクトリを変更します。
.DESCRIPTION
Windows システムで、ユーザー プロファイルが生成される既定のディレクトリを変更します。
.PARAMETER Path
このパラメータは、プロファイル ディレクトリの移動先を指定します。
.PARAMETER Force
プロファイル ディレクトリの移動先がすでに存在する場合、強制的に移動するか否かを指定します。
.EXAMPLE
Set-ProfilesDirectory D:\Users
このコマンドは、プロファイル ディレクトリを D:\Users に移動します。
.NOTES
このスクリプトは、管理者権限で実行する必要があります。
.LINK
https://docs.microsoft.com/powershell/
#>
function Set-ProfilesDirectory {
    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String]$Path,

        [Parameter()]
        [Switch]$Force,

        [Parameter()]
        [switch]$Json
    )
    $Path = $Path.TrimEnd('\', '/')

    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
    $regName = "ProfilesDirectory"
    $oldPath = (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList").GetValue("ProfilesDirectory")
    $oldIniFile = "$($oldPath)\desktop.ini"
    $newIniFile = "$($Path)\desktop.ini"
    
    $changed = $false

    $expandedOldPath = [System.Environment]::ExpandEnvironmentVariables($oldPath)
    $expandedNewPath = [System.Environment]::ExpandEnvironmentVariables($Path)
    $fullOldPath = [System.IO.Path]::GetFullPath($expandedOldPath)
    $fullNewPath = [System.IO.Path]::GetFullPath($expandedNewPath)

    if (-not $Force -and $fullOldPath -eq $fullNewPath) {
        $msg = "No changes are made."
        New-ResultJson $msg -Failed $false -Changed $false -Json:$Json
        return
    }

    if (Test-Path $Path) {
        if (-not $Force) {
            $msg = "'$($Path)' already exists. Use the '-Force' option to proceed forcibly."
            New-ResultJson $msg -Failed $true -Changed $false -Json:$Json
            Write-Error $msg
            return
        }

        Write-Warning "'$($Path)' already exists."
        if (-not (Get-Item $Path -Force).PSIsContainer -and $PSCmdlet.ShouldProcess($Path, "Remove item")) {
            Remove-Item $Path -Force
            $changed = $true
        }
    }

    $errorActionPref = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'

    try {
        if ($PSCmdlet.ShouldProcess($Path, "Create directory")) {
            New-Item -ItemType Directory $Path -Force | Out-Null
        }

        if ($PSCmdlet.ShouldProcess($newIniFile, "Copy '$($oldIniFile)'")) {
            Remove-Item $newIniFile -Force -ErrorAction SilentlyContinue
            Get-Content $oldIniFile | Out-File $newIniFile -Force
            $changed = $true
        }

        $oldIniAttr = (Get-Item $oldIniFile -Force).Attributes

        if ($PSCmdlet.ShouldProcess($newIniFile, "Assign the same attributes as '$($oldIniFile)'")) {
            Set-ItemProperty -Path $newIniFile -Name Attributes -Value $oldIniAttr
        }

        $oldDirAcl = Get-Acl -Path $oldPath -Audit
        $oldDirAttr = (Get-Item $oldPath).Attributes -band -bnot [System.IO.FileAttributes]::Directory

        if ($PSCmdlet.ShouldProcess($Path, "Assign the same ACL as '$($oldPath)'")) {
            Set-Acl -Path $Path -AclObject $oldDirAcl
        }

        if ($PSCmdlet.ShouldProcess($Path, "Assign the same attributes as '$($oldPath)'")) {
            Set-ItemProperty -Path $Path -Name Attributes -Value $oldDirAttr
        }

        if ($PSCmdlet.ShouldProcess($regPath, "Change property '$($regName)'")) {
            Set-ItemProperty $regPath -Name $regName -Value $Path
        }

        New-ResultJson "The default directory for user profiles has been successfully changed to '$($Path)'. The previous directory was '$($oldPath)'." -Failed $false -Changed $true -Json:$Json
    }
    catch {
        $ErrorActionPreference = $errorActionPref
        New-ResultJson $_ -Failed $true -Changed $changed -Json:$Json
        Write-Error $_
    }
}