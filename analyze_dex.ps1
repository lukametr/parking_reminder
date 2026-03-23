# DEX ფაილების ანალიზი
$dexFiles = @(
    "apk_extracted_final\classes.dex",
    "apk_extracted_final\classes2.dex", 
    "apk_extracted_final\classes3.dex",
    "apk_extracted_final\classes4.dex",
    "apk_extracted_final\classes5.dex"
)

Write-Host "=== DEX Files Analysis ==="
foreach ($dexFile in $dexFiles) {
    if (Test-Path $dexFile) {
        $size = (Get-Item $dexFile).Length
        Write-Host "$dexFile : $size bytes"
    }
}

# ძიება Flutter-სთან დაკავშირებული სიმბოლოებისთვის
Write-Host "`n=== Searching for Flutter-related strings ==="
foreach ($dexFile in $dexFiles) {
    if (Test-Path $dexFile) {
        Write-Host "`n--- Analyzing $dexFile ---"
        $content = [System.IO.File]::ReadAllBytes($dexFile)
        $text = [System.Text.Encoding]::UTF8.GetString($content)
        
        # Flutter სიმბოლოების ძიება
        $flutterStrings = @("Flutter", "flutter", "Dart", "dart", "main.dart", "lib/", "location", "gps", "parking", "service", "background", "firebase")
        
        foreach ($str in $flutterStrings) {
            if ($text -match [regex]::Escape($str)) {
                Write-Host "Found: $str"
            }
        }
    }
}
