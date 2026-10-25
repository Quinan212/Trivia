import os
import sys
import time
import subprocess
from pathlib import Path

sdk_dir = Path(os.environ["LOCALAPPDATA"]) / "Android" / "Sdk"
emulator_exe = sdk_dir / "emulator" / "emulator.exe"
adb_exe = sdk_dir / "platform-tools" / "adb.exe"

device = "emulator-5558"
avd = "Trivia_Antiguedad_Tablet_API_36"

# Check if device is already connected
def is_connected():
    res = subprocess.run([str(adb_exe), "devices"], capture_output=True, text=True)
    return f"{device}\tdevice" in res.stdout

if not is_connected():
    print(f"Iniciando emulador {avd} en el escritorio principal (WinSta0\\Default)...")
    si = subprocess.STARTUPINFO()
    si.lpDesktop = r"WinSta0\Default"
    
    args = [
        str(emulator_exe),
        "-avd", avd,
        "-port", "5558",
        "-gpu", "host",
        "-cores", "6",
        "-scale", "0.55"
    ]
    
    # Launch detached so it stays open even if the script finishes
    DETACHED_PROCESS = 0x00000008
    p = subprocess.Popen(
        args,
        startupinfo=si,
        creationflags=DETACHED_PROCESS,
        close_fds=True
    )
    print(f"Emulador lanzado con PID {p.pid}.")

print("Esperando inicio del sistema Android...")
limit = time.time() + 180
booted = False

while time.time() < limit:
    time.sleep(3)
    if is_connected():
        res = subprocess.run([str(adb_exe), "-s", device, "shell", "getprop", "sys.boot_completed"], capture_output=True, text=True)
        if res.stdout.strip() == "1":
            booted = True
            break

if not booted:
    print("Error: El emulador no completó el arranque a tiempo.")
    sys.exit(1)

print("Tableta lista. Iniciando aplicación...")
subprocess.run([str(adb_exe), "-s", device, "shell", "am", "start", "-n", "ar.maillet.triviaantiguedad/.MainActivity"], check=True)
print("¡Aplicación abierta exitosamente en la tableta!")
