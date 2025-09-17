# Simple script to fix problematic emojis in README
$content = Get-Content -Path "README.md" -Raw -Encoding UTF8

# Replace the most problematic emoji combinations
$content = $content -replace "🛡️", "🛡"
$content = $content -replace "🏗️", "🏗"
$content = $content -replace "🛠️", "🛠"
$content = $content -replace "🖥️", "🖥"
$content = $content -replace "❤️", "❤"

# Fix any remaining variation selector issues
$content = $content -replace "�️", "🔧"  # Fix the production-tested emoji
$content = $content -replace "�", "🏢"   # Fix enterprise ready emoji

# Write back with UTF8 encoding
Set-Content -Path "README.md" -Value $content -Encoding UTF8 -NoNewline

Write-Host "✅ Fixed problematic emojis in README.md"
