# Navigate to the script's directory
cd $PSScriptRoot

# Fetch the latest release tag
$latestTag = gh release view --repo brave/brave-browser --json tagName --jq ".tagName"

# Prompt the user to choose the version to download
Write-Host "Choose the version to download:"
Write-Host "1. win32-x64.zip"
Write-Host "2. win32-ia32.zip"
$userChoice = Read-Host "Enter the number (1 or 2):"

# Determine the ZIP file name and SHA256 file name based on the user's choice
if ($userChoice -eq '1') {
    $versionType = "win32-x64"
} elseif ($userChoice -eq '2') {
    $versionType = "win32-ia32"
} else {
    Write-Host "Invalid choice. Exiting..."
    exit
}

# Construct the file names based on the selected version
$zipFileName = "brave-$latestTag-$versionType.zip"
$sha256FileName = "$zipFileName.sha256"
$zipFilePath = Join-Path $PSScriptRoot $zipFileName
$sha256FilePath = Join-Path $PSScriptRoot $sha256FileName

# Define the download URL pattern based on the latest tag and user choice
$downloadUrl = "https://github.com/brave/brave-browser/releases/download/$latestTag/$zipFileName"
$sha256Url = "https://github.com/brave/brave-browser/releases/download/$latestTag/$sha256FileName"

# Function to download file with a progress bar
function Download-FileWithProgress {
    param (
        [string]$url,
        [string]$destinationPath
    )
    
    $request = [System.Net.HttpWebRequest]::Create($url)
    $request.Method = "GET"
    $response = $request.GetResponse()
    $totalSize = $response.ContentLength
    $responseStream = $response.GetResponseStream()
    $fileStream = [System.IO.File]::Create($destinationPath)
    
    $buffer = New-Object byte[] 8192
    $totalBytesRead = 0
    $bytesRead = 0

    do {
        $bytesRead = $responseStream.Read($buffer, 0, $buffer.Length)
        $fileStream.Write($buffer, 0, $bytesRead)
        $totalBytesRead += $bytesRead
        
        # Calculate progress percentage
        $percentComplete = ($totalBytesRead / $totalSize) * 100
        Write-Progress -Activity "Downloading $zipFileName" -PercentComplete $percentComplete `
            -Status "$totalBytesRead of $totalSize bytes downloaded..."
    } while ($bytesRead -gt 0)
    
    $fileStream.Close()
    $responseStream.Close()
}

# Download the ZIP file if it doesn't already exist
if (-not (Test-Path $zipFilePath)) {
    Download-FileWithProgress -url $downloadUrl -destinationPath $zipFilePath
}

# Download the SHA256 file if it doesn't already exist
if (-not (Test-Path $sha256FilePath)) {
    Invoke-WebRequest -Uri $sha256Url -OutFile $sha256FilePath
}

# Read the SHA-256 hash from the .SHA256 file
$sha256Content = Get-Content -Path $sha256FilePath
$expectedHash = $sha256Content.Split(' ')[0].Trim()

# Compute the SHA-256 hash of the downloaded ZIP file
$computedHash = Get-FileHash -Path $zipFilePath -Algorithm SHA256
$computedHashString = $computedHash.Hash

# Display the computed hash
Write-Host "Computed SHA-256 hash: $computedHashString"
Write-Host "Expected SHA-256 hash: $expectedHash"
if ($computedHashString -eq $expectedHash) {
    Write-Host "Verified" -ForegroundColor Green
} else {
    Write-Host "Expected-error" -ForegroundColor Red
}

# Pause for user input to verify hash
$response = Read-Host "Do you want to continue with this file? (Y/N)"
if ($response -ne 'Y') {
    Write-Host "File is either corrupted or not as expected. Exiting..."
    exit
}

# Define the extraction directory name (same as the ZIP file name without extension)
$extractDir = [System.IO.Path]::GetFileNameWithoutExtension($zipFilePath)
$extractDirPath = Join-Path $PSScriptRoot $extractDir

# Create extraction directory if it does not exist
if (-not (Test-Path $extractDirPath)) {
    New-Item -Path $extractDirPath -ItemType Directory
}

# Check if 7z is in the PATH, if not, set the full path to 7z.exe
$sevenZipPath = "7z"
if (-not (Get-Command $sevenZipPath -ErrorAction SilentlyContinue)) {
    # Set the path to 7z.exe if it's not in the PATH
    $sevenZipPath = "F:\Program_files\7-Zip\7z.exe"
}

# Extract the ZIP file using 7z directly into the newly created directory
& $sevenZipPath x $zipFilePath -o"$extractDirPath\" -y

Write-Host "Extracted $zipFilePath to $extractDirPath"
