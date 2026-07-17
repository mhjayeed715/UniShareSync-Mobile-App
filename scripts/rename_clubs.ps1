# PowerShell script to rename all Club references to Community in lib directory

$dartFiles = Get-ChildItem -Path "lib" -Filter "*.dart" -Recurse

foreach ($file in $dartFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    
    if ($content -match 'club|Club') {
        Write-Host "Processing: $($file.FullName)"
        
        # Core string replacements
        $content = $content -replace 'events_clubs/', 'events/'
        $content = $content -replace 'club_model.dart', 'community_model.dart'
        $content = $content -replace 'clubs_service.dart', 'communities_service.dart'
        
        # Word boundaries replacements
        $content = $content -replace '\bclubs\b', 'communities'
        $content = $content -replace '\bClubs\b', 'Communities'
        $content = $content -replace '\bclub\b', 'community'
        $content = $content -replace '\bClub\b', 'Community'
        
        # Enums/Keys mappings
        $content = $content -replace 'organizerClub', 'organizingCommunityName'
        $content = $content -replace 'organizer_club', 'organizing_community_name'
        
        Set-Content -Path $file.FullName -Value $content -Encoding utf8
    }
}

# Rename files containing 'club' in lib folder
$filesToRename = Get-ChildItem -Path "lib" -Filter "*club*" -Recurse
foreach ($file in $filesToRename) {
    $newName = $file.Name -replace 'club', 'community'
    $newPath = Join-Path $file.DirectoryName $newName
    Write-Host "Renaming: $($file.FullName) -> $newName"
    Rename-Item -Path $file.FullName -NewName $newName -Force
}
