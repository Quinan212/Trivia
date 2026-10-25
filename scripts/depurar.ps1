param([string]$Avd = 'Recorridos_API_36')

$ErrorActionPreference = 'Stop'
$raizProyecto = Split-Path -Parent $PSScriptRoot
$sdkAndroid = $env:ANDROID_HOME
if (-not $sdkAndroid) {
    $sdkAndroid = Join-Path $env:LOCALAPPDATA 'Android/Sdk'
}
$adbJuego = Join-Path $sdkAndroid 'platform-tools/adb.exe'
$flutterJuego = Join-Path $env:USERPROFILE 'flutter/bin/flutter.bat'
if (-not (Test-Path -LiteralPath $flutterJuego)) {
    $flutterJuego = (Get-Command flutter -ErrorAction Stop).Source
}
if (-not (Test-Path -LiteralPath $adbJuego)) {
    throw 'No se encontró ADB en el SDK Android.'
}

Push-Location -LiteralPath $raizProyecto
try {
    $env:PATH = (Join-Path $sdkAndroid 'platform-tools') + [IO.Path]::PathSeparator + $env:PATH
    $dispositivo = (& $adbJuego devices) |
        Where-Object { $_ -match '^emulator-\d+\s+device$' } |
        Select-Object -First 1
    if (-not $dispositivo) {
        & $flutterJuego emulators --launch $Avd
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo abrir el emulador.' }
        $limite = [DateTime]::UtcNow.AddMinutes(3)
        do {
            Start-Sleep -Seconds 2
            $dispositivo = (& $adbJuego devices) |
                Where-Object { $_ -match '^emulator-\d+\s+device$' } |
                Select-Object -First 1
        } while (-not $dispositivo -and [DateTime]::UtcNow -lt $limite)
    }
    if (-not $dispositivo) { throw 'El emulador no respondió a tiempo.' }
    $idDispositivo = ($dispositivo -split '\s+')[0]
    $limite = [DateTime]::UtcNow.AddMinutes(3)
    do {
        $arranco = (& $adbJuego -s $idDispositivo shell getprop sys.boot_completed).Trim()
        if ($arranco -ne '1') { Start-Sleep -Seconds 2 }
    } while ($arranco -ne '1' -and [DateTime]::UtcNow -lt $limite)
    if ($arranco -ne '1') { throw 'Android no terminó de arrancar.' }
    & $flutterJuego pub get
    if ($LASTEXITCODE -ne 0) { throw 'Falló la preparación de dependencias.' }
    & $flutterJuego run -d $idDispositivo --debug --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'La depuración terminó con un error.' }
} finally {
    Pop-Location
}
