<#
.SYNOPSIS
  WPF 창을 띄우지 않고 PNG로 그립니다. 포커스, 마우스, 키보드를 건드리지 않습니다.

.DESCRIPTION
  대상 앱의 빌드 결과(.dll)를 불러와 App.xaml 리소스를 적용하고, 창을 Show() 없이 만든 뒤
  내용을 RenderTargetBitmap으로 그립니다. 처음 실행할 때 렌더링 프로그램(render-window 폴더)을
  임시 폴더에 빌드하고, 다음부터는 재사용합니다. .NET SDK 8 이상이 필요합니다.

  출력:
    SAVED: <경로> (<폭>x<높이> DIP, <배율>x)   저장 완료
    FONT <개수>  <FontFamily> / <굵기> -> <실제 글꼴 파일>   글자 요소가 실제로 쓴 글꼴
    ERROR: ...                                  실패 이유 (exit code 1 이상)

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File render-window.ps1 -Assembly .\bin\Debug\net8.0-windows\MyApp.dll -Out .\before.png
#>
param(
    [Parameter(Mandatory = $true)][string]$Assembly,
    [Parameter(Mandatory = $true)][string]$Out,
    [string]$Window = 'MainWindow',
    [double]$Width = 0,
    [double]$Height = 0,
    [double]$Scale = 2,
    [string]$TargetFramework = 'net8.0-windows'
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$asmPath = [IO.Path]::GetFullPath($Assembly)
$outPath = [IO.Path]::GetFullPath($Out)
if (-not (Test-Path $asmPath)) { Write-Output "ERROR: 어셈블리가 없습니다: $asmPath (먼저 앱을 빌드합니다)"; exit 2 }

$src = Join-Path $PSScriptRoot 'render-window'
$hashInput = (Get-Content -Raw (Join-Path $src 'Program.cs')) + $TargetFramework
$sha = [Security.Cryptography.SHA256]::Create()
$hash = -join ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($hashInput)) | Select-Object -First 6 | ForEach-Object { $_.ToString('x2') })
$work = Join-Path $env:TEMP "wpf-unslop-render-window\$hash"
$exe = Join-Path $work 'bin\RenderWindow.exe'

if (-not (Test-Path $exe)) {
    New-Item -ItemType Directory -Force $work | Out-Null
    Copy-Item (Join-Path $src 'Program.cs') $work -Force
    $proj = Get-Content -Raw (Join-Path $src 'RenderWindow.csproj')
    $proj = $proj -replace '<TargetFramework>[^<]+</TargetFramework>', "<TargetFramework>$TargetFramework</TargetFramework>"
    [IO.File]::WriteAllText((Join-Path $work 'RenderWindow.csproj'), $proj, (New-Object Text.UTF8Encoding $false))
    $log = & dotnet build (Join-Path $work 'RenderWindow.csproj') -c Release -o (Join-Path $work 'bin') -nologo -v q 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $exe)) {
        Write-Output "ERROR: 렌더링 프로그램 빌드에 실패했습니다. .NET SDK가 설치되어 있는지 확인합니다."
        $log | Select-Object -Last 20 | ForEach-Object { Write-Output $_ }
        exit 6
    }
}

& $exe --assembly $asmPath --out $outPath --window $Window --width $Width --height $Height --scale $Scale
exit $LASTEXITCODE
