
$imagesPath = "D:\WIP\EASYPIM\EasyPIM\Documentation\Gallery\images"
$outputPath = "D:\WIP\EASYPIM\EasyPIM\Documentation\Gallery\gallery.html"

$imageExtensions = @("*.png", "*.jpg", "*.jpeg", "*.gif", "*.bmp", "*.webp")
$imageFiles = @()

foreach ($ext in $imageExtensions) {
    $imageFiles += Get-ChildItem -Path $imagesPath -Filter $ext
}

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>EasyPIM Gallery</title>
    <style>
        body { font-family: Arial, sans-serif; padding: 20px; background-color: #f9f9f9; }
        h1 { text-align: center; }
        .gallery { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 15px; padding: 20px; }
        .gallery img { width: 100%; height: auto; border: 1px solid #ccc; border-radius: 5px; box-shadow: 2px 2px 6px rgba(0,0,0,0.1); }
    </style>
</head>
<body>
    <h1>📸 EasyPIM Gallery</h1>
    <div class="gallery">
"@

foreach ($file in $imageFiles) {
    $relativePath = "images/" + $file.Name
    $html += "        <img src='$relativePath' alt='$($file.BaseName)' />`n"
}

$html += @"
    </div>
</body>
</html>
"@

$html | Out-File -FilePath $outputPath -Encoding UTF8

Write-Host "✅ Gallery generated at: $outputPath"
