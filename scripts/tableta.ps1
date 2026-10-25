param(
    [switch]$Depurar,
    [switch]$ModoBateria,
    [switch]$ConGpu
)

$triviaRoot = Split-Path -Parent $PSScriptRoot
$triviaSdk = Join-Path $env:LOCALAPPDATA 'Android/Sdk'
$triviaAdb = Join-Path $triviaSdk 'platform-tools/adb.exe'
$triviaEmulator = Join-Path $triviaSdk 'emulator/emulator.exe'
$triviaDevice = 'emulator-5558'
$triviaAvd = 'Trivia_Antiguedad_Tablet_API_36'
$triviaConnected = (& $triviaAdb devices 2>$null) -match '^emulator-5558\s+device$'

if (-not $triviaConnected) {
    if ($ModoBateria) {
        Write-Host "==========================================================" -ForegroundColor Yellow
        Write-Host " [MODO BATERIA] Emulador por CPU (SwiftShader, 2 cores)   " -ForegroundColor Yellow
        Write-Host "==========================================================" -ForegroundColor Yellow
        $emulatorArgs = @(
            '-avd', $triviaAvd,
            '-port', '5558',
            '-gpu', 'swiftshader',
            '-feature', '-Vulkan',
            '-no-snapshot-load',
            '-no-snapshot-save',
            '-cores', '2',
            '-scale', '0.55'
        )
    } else {
        Write-Host "==========================================================" -ForegroundColor Green
        Write-Host " [MODO RENDIMIENTO] GPU Host al maximo (6 cores + Vulkan) " -ForegroundColor Green
        Write-Host "==========================================================" -ForegroundColor Green
        $emulatorArgs = @(
            '-avd', $triviaAvd,
            '-port', '5558',
            '-gpu', 'host',
            '-cores', '6',
            '-no-snapshot-load',
            '-no-snapshot-save',
            '-scale', '0.55'
        )
    }

    Start-Process -FilePath $triviaEmulator -ArgumentList $emulatorArgs -WindowStyle Normal
}

Write-Host "Esperando inicio de la tableta ($triviaDevice)..." -ForegroundColor Cyan
$triviaLimit = [DateTime]::UtcNow.AddMinutes(3)
$triviaBoot = '0'

while ([DateTime]::UtcNow -lt $triviaLimit) {
    Start-Sleep -Seconds 3
    $devices = (& $triviaAdb devices 2>$null)
    if ($devices -match 'emulator-5558\s+device') {
        $triviaBoot = (& $triviaAdb -s $triviaDevice shell getprop sys.boot_completed 2>$null)
        if ($triviaBoot -eq '1') { break }
    }
}

if ($triviaBoot -ne '1') { throw 'La tableta no termino de arrancar.' }

Write-Host "Tableta lista y conectada." -ForegroundColor Green
$triviaActualAvd = & $triviaAdb -s $triviaDevice emu avd name 2>$null
if ($triviaActualAvd -notcontains $triviaAvd) { throw 'El dispositivo conectado no es la tableta de Trivia.' }

Push-Location -LiteralPath $triviaRoot
try {
    if ($Depurar) {
        Write-Host "Iniciando Flutter en modo depuracion..." -ForegroundColor Cyan
        & flutter run -d $triviaDevice --debug -t lib/main.dart
        if ($LASTEXITCODE -ne 0) { throw 'Fallo la depuracion en tableta.' }
    } else {
        Write-Host "Iniciando aplicacion instalada..." -ForegroundColor Cyan
        & $triviaAdb -s $triviaDevice shell am start -n ar.maillet.triviaantiguedad/.MainActivity
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo abrir la app instalada.' }
    }
} finally {
    Pop-Location
}
