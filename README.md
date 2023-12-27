# PowerShell 独自モジュールの例
## 各ファイルの説明
### CustomFunction.psm1
ルート モジュール。実際に function を定義したスクリプト ファイルをドット ソーシングで呼び出し、Export-ModuleMember で function を公開している。
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