# Define project directories
$projectDirs = @(
    "chunk_video_content",
    "index_file_api",
    "summarize_video_content"
)

# Current location
$currentDir = Get-Location

foreach ($dir in $projectDirs) {
    Write-Host "Processing $dir..."
    
    # Navigate to project directory
    Push-Location "$currentDir\$dir"
    
    # Check if uv is installed
    try {
        $uvVersion = uv --version
        Write-Host "uv version: $uvVersion"
    }
    catch {
        Write-Host "uv is not installed. Installing uv..."
        pip install uv
    }
    
    # Run uv export
    Write-Host "Running uv export in $dir..."
    try {
        uv export > requirements.txt
        
        # Verify the file was created and display its contents
        if (Test-Path requirements.txt) {
            Write-Host "Successfully created requirements.txt"
            Write-Host "First 10 lines of requirements.txt:"
            Get-Content requirements.txt -TotalCount 10
        } else {
            Write-Host "Failed to create requirements.txt" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Error running uv export: $_" -ForegroundColor Red
    }
    
    # Return to the original directory
    Pop-Location
}

Write-Host "Export complete for all projects!" -ForegroundColor Green