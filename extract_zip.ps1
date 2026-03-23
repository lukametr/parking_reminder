Add-Type -AssemblyName System.IO.Compression.FileSystem

$apkPath = "app-release.apk"
$extractPath = "apk_extracted_final"

# Remove existing folder
if (Test-Path $extractPath) {
    Remove-Item $extractPath -Recurse -Force
}

# Create extraction folder
New-Item -ItemType Directory -Path $extractPath | Out-Null

try {
    # Open ZIP file
    $zip = [System.IO.Compression.ZipFile]::OpenRead($apkPath)
    
    # Extract each entry
    foreach ($entry in $zip.Entries) {
        $destinationPath = Join-Path $extractPath $entry.FullName
        
        # Create directory if needed
        $destinationDir = Split-Path $destinationPath -Parent
        if (-not (Test-Path $destinationDir)) {
            New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
        }
        
        # Extract file (not directory)
        if (-not $entry.FullName.EndsWith('/')) {
            try {
                $fileStream = [System.IO.File]::Create($destinationPath)
                $entryStream = $entry.Open()
                $entryStream.CopyTo($fileStream)
                $fileStream.Close()
                $entryStream.Close()
            } catch {
                Write-Host "Warning: Could not extract $($entry.FullName): $_"
            }
        }
    }
    
    $zip.Dispose()
    Write-Host "APK extracted successfully to $extractPath!"
    
} catch {
    Write-Host "Error extracting APK: $_"
}
