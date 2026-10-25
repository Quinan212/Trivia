param([ValidateSet('arm64', 'x64')][string]$Arquitectura = 'arm64')

$triviaRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $triviaRoot
try {
    $triviaVersion = ((Get-Content pubspec.yaml | Select-String '^version:').Line -replace '^version:\s*', '').Split('+')[0]
    & flutter build apk --release --no-pub --target-platform "android-$Arquitectura" --obfuscate "--split-debug-info=output/simbolos/$triviaVersion"
    if ($LASTEXITCODE -ne 0) { throw 'Falló la compilación compacta.' }
    $triviaSalida = "output/Trivia-Unidad-IV-$triviaVersion-$Arquitectura.apk"
    Copy-Item -LiteralPath build/app/outputs/flutter-apk/app-release.apk -Destination $triviaSalida
    $triviaBytes = (Get-Item -LiteralPath $triviaSalida).Length
    Write-Host "$triviaSalida - $triviaBytes bytes"
    if ($Arquitectura -eq 'arm64' -and $triviaBytes -gt 15000000) {
        throw 'La APK ARM64 supera el presupuesto de 15 MB.'
    }
} finally {
    Pop-Location
}
