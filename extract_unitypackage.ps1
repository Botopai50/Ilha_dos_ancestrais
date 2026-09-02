$source = "C:\Users\juliano.silva\.gemini\antigravity\scratch\ilha_dos_ancestrais\Assets\TerrainUnity"
$dest = "C:\Users\juliano.silva\.gemini\antigravity\scratch\ilha_dos_ancestrais\Assets\TerrainExtracted"

New-Item -ItemType Directory -Force -Path $dest | Out-Null

$guids = Get-ChildItem -Path $source -Directory

foreach ($guid in $guids) {
    $pathnameFile = Join-Path -Path $guid.FullName -ChildPath "pathname"
    $assetFile = Join-Path -Path $guid.FullName -ChildPath "asset"
    
    if ((Test-Path $pathnameFile) -and (Test-Path $assetFile)) {
        # Read the first line of the pathname file to get the original file path
        $originalPath = (Get-Content -Path $pathnameFile -TotalCount 1).Trim()
        
        # Replace forward slashes with backslashes
        $originalPath = $originalPath -replace '/', '\'
        
        # Create full destination path
        $fullDestPath = Join-Path -Path $dest -ChildPath $originalPath
        
        # Get the directory of the destination path and create it if it doesn't exist
        $destDir = Split-Path -Path $fullDestPath -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        }
        
        # Copy the asset file to the destination path
        Copy-Item -Path $assetFile -Destination $fullDestPath -Force
    }
}
Write-Output "Extraction complete!"
