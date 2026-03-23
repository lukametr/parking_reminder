# სტრიქონების ექსტრაქცია DEX ფაილებიდან
$dexFiles = @(
    "apk_extracted_final\classes.dex",
    "apk_extracted_final\classes2.dex", 
    "apk_extracted_final\classes3.dex",
    "apk_extracted_final\classes4.dex",
    "apk_extracted_final\classes5.dex"
)

Write-Host "=== Extracting Flutter Project Information ==="

# კლასების და მეთოდების ძიება
$patterns = @(
    "L.*Service",           # სერვისები
    "L.*Location",          # ლოკაცია
    "L.*Parking",           # პარკინგი
    "L.*Background",        # ფონური
    "L.*Main",              # მთავარი
    "L.*Screen",            # ეკრანები
    "L.*Widget",            # ვიჯეტები
    "L.*Database",          # ბაზა
    "L.*Firebase",          # Firebase
    "com/example/pr_app"     # პროექტის პაკეტი
)

foreach ($dexFile in $dexFiles) {
    if (Test-Path $dexFile) {
        Write-Host "`n--- $dexFile ---"
        $content = [System.IO.File]::ReadAllBytes($dexFile)
        $text = [System.Text.Encoding]::UTF8.GetString($content)
        
        foreach ($pattern in $patterns) {
            $matches = [regex]::Matches($text, $pattern)
            if ($matches.Count -gt 0) {
                $uniqueMatches = $matches | Select-Object -Unique | Select-Object -First 10
                foreach ($match in $uniqueMatches) {
                    Write-Host "  $match"
                }
            }
        }
    }
}

# ქართული სიმბოლოების ძიება
Write-Host "`n=== Georgian Texts ==="
$georgianWords = @("parking", "location", "monitor", "service", "zone", "control")

foreach ($dexFile in $dexFiles) {
    if (Test-Path $dexFile) {
        $content = [System.IO.File]::ReadAllBytes($dexFile)
        $text = [System.Text.Encoding]::UTF8.GetString($content)
        
        foreach ($word in $georgianWords) {
            if ($text -match [regex]::Escape($word)) {
                Write-Host "Found Georgian: $word in $dexFile"
            }
        }
    }
}
