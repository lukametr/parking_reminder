Add-Type -AssemblyName System.IO.Compression.FileSystem
try {
    $extractPath = "apk_extracted_new"
    if (Test-Path $extractPath) {
        Remove-Item $extractPath -Recurse -Force
    }
    [System.IO.Compression.ZipFile]::ExtractToDirectory("app-release.apk", $extractPath)
    Write-Host "APK extracted successfully to $extractPath!"
} catch {
    Write-Host "Error extracting APK: $_"
}
