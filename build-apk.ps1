param([string]$FlutterRoot)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
if (-not $FlutterRoot) {
    $flutterCommand = Get-Command flutter -ErrorAction Stop
    $FlutterRoot = Split-Path -Parent (Split-Path -Parent $flutterCommand.Source)
}
$dartExecutable = Join-Path $FlutterRoot 'bin\cache\dart-sdk\bin\dart.exe'
$flutterSnapshot = Join-Path $FlutterRoot 'bin\cache\flutter_tools.snapshot'
function Invoke-FlutterStep {
    param([string[]]$StepArguments)
    & $dartExecutable $flutterSnapshot --no-version-check @StepArguments
    if ($LASTEXITCODE -ne 0) { throw "Flutter terminó con código $LASTEXITCODE" }
}
Invoke-FlutterStep -StepArguments @('pub', 'get', '--offline')
Invoke-FlutterStep -StepArguments @('analyze', '--no-pub')
Invoke-FlutterStep -StepArguments @('test', '--no-pub')
Invoke-FlutterStep -StepArguments @('build', 'apk', '--release', '--no-pub')
New-Item -ItemType Directory -Path 'entrega' -Force | Out-Null
$versionLine = (Get-Content -LiteralPath 'pubspec.yaml' | Select-String '^version:').Line
$appVersion = ($versionLine -replace '^version:\s*', '').Split('+')[0].Trim()
$apkName = "fiscore-v$appVersion.apk"
$apkPath = Join-Path 'entrega' $apkName
function Copy-ApkArtifact {
    param([string]$Source, [string]$Destination)
    # Replace the directory entry rather than writing into an APK that a
    # Windows indexer/viewer may still have memory-mapped.
    $deliveryTarget = [System.IO.Path]::GetFullPath($Destination)
    $deliveryTemp = "$deliveryTarget.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [System.IO.File]::Copy([System.IO.Path]::GetFullPath($Source), $deliveryTemp)
        [System.IO.File]::Move($deliveryTemp, $deliveryTarget, $true)
    } finally {
        if (Test-Path -LiteralPath $deliveryTemp) {
            Remove-Item -LiteralPath $deliveryTemp -Force
        }
    }
}
Copy-ApkArtifact -Source 'build\app\outputs\flutter-apk\app-release.apk' -Destination $apkPath
Copy-ApkArtifact -Source $apkPath -Destination 'entrega\FISCORE.apk'
$apkHash = (Get-FileHash -LiteralPath $apkPath -Algorithm SHA256).Hash
Set-Content -LiteralPath 'entrega\SHA256.txt' -Value "$apkHash  $apkName"
Write-Output "APK generada: $apkPath"

