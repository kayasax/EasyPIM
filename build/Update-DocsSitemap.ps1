param(
    [string]$DocsRoot = (Join-Path $PSScriptRoot '..\docs'),
    [string]$BaseUrl = 'https://kayasax.github.io/EasyPIM',
    [string]$FallbackDate = '2000-01-01'
)

$ErrorActionPreference = 'Stop'

$parsedDate = [datetime]::MinValue
if (-not [datetime]::TryParseExact($FallbackDate, 'yyyy-MM-dd',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
    throw 'FallbackDate must be a valid yyyy-MM-dd date.'
}
$baseUri = $null
if (-not [uri]::TryCreate($BaseUrl, [UriKind]::Absolute, [ref]$baseUri) -or
    $baseUri.Scheme -notin @('http', 'https') -or $baseUri.Query -or $baseUri.Fragment) {
    throw 'BaseUrl must be an absolute HTTP(S) URL without a query or fragment.'
}
$BaseUrl = $baseUri.AbsoluteUri.TrimEnd('/')
$resolvedDocsRoot = (Get-Item -LiteralPath $DocsRoot).FullName

$hasGitMetadata = $false
if (Get-Command git -ErrorAction SilentlyContinue) {
    $null = & git -C $resolvedDocsRoot rev-parse --verify HEAD 2>$null
    $hasGitMetadata = $LASTEXITCODE -eq 0
}

function Get-GitCommitDate {
    param([string]$RelativePath)

    $date = & git -C $resolvedDocsRoot --literal-pathspecs log -1 --format=%cs -- $RelativePath
    if ($LASTEXITCODE -ne 0) {
        throw "Cannot read Git history for $RelativePath"
    }
    return $date
}

# New pages use the latest docs commit as a reproducible baseline, not their
# filesystem timestamps. Source archives use an explicit sentinel date.
$defaultDate = $FallbackDate
if ($hasGitMetadata) {
    $docsDate = Get-GitCommitDate -RelativePath '.'
    if ($docsDate) { $defaultDate = $docsDate }
} else {
    Write-Warning "Git metadata unavailable; using fallback lastmod $FallbackDate."
}

$priorities = @{
    'index.html' = '1.0'
    'install.html' = '0.9'
    'core.html' = '0.8'
    'template-guide.html' = '0.8'
    'event-driven.html' = '0.8'
    'compare.html' = '0.7'
    'snippets.html' = '0.6'
}
$rootPrefix = $resolvedDocsRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$pages = [string[]]@(Get-ChildItem -LiteralPath $resolvedDocsRoot -Recurse -File -Filter '*.html' |
    ForEach-Object { $_.FullName.Substring($rootPrefix.Length).Replace('\', '/') })
if (-not $pages.Count) { throw "No public HTML pages found in $resolvedDocsRoot" }
[Array]::Sort($pages, [StringComparer]::Ordinal)
$pages = @($pages | Where-Object { $_ -eq 'index.html' }) +
    @($pages | Where-Object { $_ -ne 'index.html' })

$xml = New-Object System.Text.StringBuilder
[void]$xml.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
[void]$xml.AppendLine('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
foreach ($page in $pages) {
    $lastmod = $defaultDate
    if ($hasGitMetadata) {
        $tracked = & git -C $resolvedDocsRoot --literal-pathspecs ls-files -- $page
        if ($LASTEXITCODE -ne 0) { throw "Cannot read Git index for $page" }
        if ($tracked) {
            $pageDate = Get-GitCommitDate -RelativePath $page
            if ($pageDate) { $lastmod = $pageDate }
        }
    }
    $urlPath = ($page.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    $loc = if ($page -eq 'index.html') { "$BaseUrl/" } else { "$BaseUrl/$urlPath" }
    $escapedLoc = [System.Security.SecurityElement]::Escape($loc)
    $priority = if ($priorities.ContainsKey($page)) { $priorities[$page] } else { '0.6' }
    [void]$xml.AppendLine('  <url>')
    [void]$xml.AppendLine("    <loc>$escapedLoc</loc>")
    [void]$xml.AppendLine("    <lastmod>$lastmod</lastmod>")
    [void]$xml.AppendLine("    <priority>$priority</priority>")
    [void]$xml.AppendLine('  </url>')
}
[void]$xml.AppendLine('</urlset>')

$sitemapPath = Join-Path $resolvedDocsRoot 'sitemap.xml'
[IO.File]::WriteAllText($sitemapPath, $xml.ToString().Replace("`r`n", "`n"),
    [System.Text.UTF8Encoding]::new($false))
