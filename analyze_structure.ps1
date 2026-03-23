# პროექტის სტრუქტურის ანალიზი
Write-Host "=== Flutter Project Structure Analysis ==="

# ძიება კონკრეტული კლასებისთვის
$classes = @(
    "LocationService",
    "ParkingService", 
    "BackgroundService",
    "MainActivity",
    "SplashScreen",
    "ServiceButtons",
    "ParkingDatabase",
    "ParkingZone",
    "ParkingMonitor"
)

$dexFiles = @(
    "apk_extracted_final\classes.dex",
    "apk_extracted_final\classes2.dex", 
    "apk_extracted_final\classes3.dex",
    "apk_extracted_final\classes4.dex",
    "apk_extracted_final\classes5.dex"
)

foreach ($dexFile in $dexFiles) {
    if (Test-Path $dexFile) {
        Write-Host "`n--- Analyzing $dexFile ---"
        $content = [System.IO.File]::ReadAllBytes($dexFile)
        $text = [System.Text.Encoding]::UTF8.GetString($content)
        
        foreach ($class in $classes) {
            if ($text -match [regex]::Escape($class)) {
                Write-Host "  Found class: $class"
            }
        }
        
        # ძიება ფაილის გზებისთვის
        $filePaths = @("lib/", "screens/", "widgets/", "models/", "services/", "database/")
        foreach ($path in $filePaths) {
            if ($text -match [regex]::Escape($path)) {
                Write-Host "  Found path: $path"
            }
        }
    }
}

# ძიება მნიშვნელოვანი მეთოდებისთვის
Write-Host "`n=== Important Methods ==="
$methods = @(
    "onLocationChanged",
    "startLocationUpdates", 
    "checkParkingZone",
    "showNotification",
    "startForegroundService",
    "stopService",
    "initDatabase"
)

foreach ($dexFile in $dexFiles) {
    if (Test-Path $dexFile) {
        $content = [System.IO.File]::ReadAllBytes($dexFile)
        $text = [System.Text.Encoding]::UTF8.GetString($content)
        
        foreach ($method in $methods) {
            if ($text -match [regex]::Escape($method)) {
                Write-Host "  Found method: $method in $dexFile"
            }
        }
    }
}
