<#
.SYNOPSIS
不明なアカウントのユーザー プロファイルを削除します。
.DESCRIPTION
特定の期間内に使用されていない、かつ、不明なアカウント (多くの場合、削除されたユーザー アカウント) のユーザー プロファイルを削除します。Windows システムのメンテナンスやクリーンアップのために使用されます。
.PARAMETER CutoffDays
このパラメータは、削除を検討するユーザー プロファイルの古さを日単位で指定します。デフォルト値は 30 日です。この値に基づいて、最終使用日から算出された日付より古いプロファイルが削除対象となります。
.PARAMETER Logging
処理中の警告、および削除成功をイベント ログに記録します。
.EXAMPLE
Remove-UnknownAccountProfile
このコマンドは、デフォルトの 30 日のカットオフ期間を使用して、未知のアカウントプロファイルを削除します。
.EXAMPLE
Remove-UnknownAccountProfile -CutoffDays 5
このコマンドは、5 日のカットオフ期間を使用して、未知のアカウントプロファイルを削除します。
.NOTES
このスクリプトは、管理者権限で実行する必要があります。また、実行する前に影響を受ける可能性のあるプロファイルを確認してください。
.LINK
https://docs.microsoft.com/powershell/
#>
function Remove-UnknownAccountProfile {
    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter()]
        [Int]$CutoffDays = 30,

        [Parameter()]
        [Switch]$Logging
    )

    # 最終仕様日時がこれ以前のアカウントのプロファイルを削除する。
    $cutoffDate = (Get-Date).AddDays(-$CutoffDays)

    # ユーザー プロファイルの CIM インスタンスのリストを取得する。
    $userProfiles = Get-CimInstance -ClassName Win32_UserProfile

    $unknownUserProfiles = foreach ($userProfile in $userProfiles) {
        # SID を SecurityIdentifier オブジェクトにする
        $securityId = New-Object System.Security.Principal.SecurityIdentifier($userProfile.SID)
    
        try {
            # SecurityIdentifier オブジェクトを NtAccount オブジェクトに変換する。
            $ntAccount = $securityId.Translate([System.Security.Principal.NTAccount])
            Write-Debug "$($ntAccount) is exist."
        }
        catch [System.Security.Principal.IdentityNotMappedException] {
            # Translate メソッドが IdentityNotMappedException を発生させたら、不明なアカウント
            $userProfile
        }
        catch {
            # それ以外の例外が発生したらエラーを吐く。
            $message = "$($_)".Replace("\", "\\").Replace("`r", "\r").Replace("`n", "\n")
            $message += "`r`nSID: $($userProfile.SID)"
            $message += "`r`nLocalPath: $($userProfile.LocalPath)"
            $message += "`r`nLastUseTime: $($userProfile.LastUseTime)"
            $message += "`r`ncutoffDate: $($cutoffDate)"

            Write-WarningToHostAndLog $message $MyInvocation.MyCommand.Name $Logging
        }
    }

    # 不明なアカウントについて処理する。
    foreach ($userProfile in $unknownUserProfiles) {
        # 特殊アカウントでなく
        if (-not $userProfile.Special) {
            # かつ、最終使用日時が cutoffDate より前なら
            if ($userProfile.LastUseTime -lt $cutoffDate) {
                $path = $userProfile.LocalPath
                $userProfile | Remove-CimInstance -WhatIf:$WhatIfPreference
                Write-InformationToHostAndLog $message $MyInvocation.MyCommand.Name $Logging
            }
            else {
                Write-Debug "$($userProfile.SID) is not expired. $($userProfile.LastUseTime)"
                Write-Debug "LastUseTime: $($userProfile.LastUseTime)"
                Write-Debug "cutoffDate: $($cutoffDate)"
            }
        }
        else {
            Write-Debug "$($userProfile.SID) is special account."
        }
    }
}