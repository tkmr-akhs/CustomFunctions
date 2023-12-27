# PowerShell 独自モジュールの例
## 各ファイルの説明
### CustomFunction.psm1
ルート モジュール。実際に function を定義したスクリプト ファイルをドット ソーシングで呼び出し、Export-ModuleMember で function を公開している。このファイルの`$DebugPreference = "Continue"`をコメントアウト解除すると、デバッグ出力されるようになる。
### CustomFunction.psd1
モジュール マニフェスト。以下のコマンドで生成したもの。
```powershell
New-ModuleManifest -Path .\CustomFunctions.psd1 -RootModule .\CustomFunctions.psm1
```
### InternalUtils.psm1
内部のみで使用されるユーティリティ関数群。function を定義する他ファイルで以下のようにインポートされ使用される。
```powershell
Import-Module $PSScriptRoot\InternalUtils.psm1 -Scope Local 
```

## 操作方法
以下のようにインポートする。
```powershell
Import-Module C:\Path\To\Folder\CustomFunctions
```
環境によっては、以下のように .psd1 ファイルを指定する必要がある。
```powershell
Import-Module C:\Path\To\Folder\CustomFunctions\CustomFunctions.psd1
```
-Verbose オプションをつけると、インポート処理の詳細が表示される。
```powershell
Import-Module C:\Path\To\Folder\CustomFunctions -Verbose
```
以下のようにすることで、コマンド一覧が表示される。
```powershell
Get-Command -Module C:\Path\To\Folder\CustomFunctions
```
以下のようにすることで、インポート済みのモジュールを解除できる。
```powershell
Remove-Module CustomFunctions
```

## function を追加するには
1. function を定義する .ps1 ファイルを UTF-8 with BOM で作成する。
```powershell
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
function Example-Function {
    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Param1,

        [Parameter(Position = 1)]
        [string]$Param2 = "DefaultValue"
    )

    # 処理
}
```
2. `CustomFunctions.psm1` のドット ソーシングに作成したファイルを追加し、Export-ModuleMember に function を追加する。