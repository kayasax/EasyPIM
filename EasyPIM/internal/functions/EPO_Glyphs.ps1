function Get-EasyPIMGlyphs {
    <#
        .SYNOPSIS
            Returns a hashtable of glyphs (emojis / symbols) used for rich console output.
        .DESCRIPTION
            Provides either Unicode emoji symbols or plain ASCII fallbacks depending on host capability.
        .NOTES
            Centralizing glyph selection prevents parse/encoding issues and allows graceful degradation.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $supportsUnicode = $false
    try {
        if ($PSVersionTable.PSVersion.Major -ge 6 -and [Console]::OutputEncoding) {
            $enc = [Console]::OutputEncoding
            $supportsUnicode = $enc.WebName -match 'utf' -or $enc.CodePage -in 65001,1200,1201
        }
    } catch {
        Write-Verbose "Get-EasyPIMGlyphs: Unicode capability detection failed: $($_.Exception.Message)"
    }

    if (-not $supportsUnicode) {
        return @{
            Kept        = 'KEPT'
            Removed     = 'REM'
            WouldRemove = 'PRE'
            Skipped     = 'SKIP'
            Protected   = 'PROT'
            Warning     = 'WARN'
            Fail        = 'FAIL'
            Inspect     = 'CHK'
            Duplicate   = 'DUP'
            Note        = 'NOTE'
            Timer       = 'TIME'
            Stats       = 'STAT'
            Success     = 'OK'
        }
    }

    # Build emojis at runtime from Unicode code points (ASCII-only source; no literal emojis needed)
    function New-Utf32Char([int]$codePoint) {
        # Returns a string for the provided Unicode code point (handles BMP and supplementary planes)
        return [System.Text.Encoding]::UTF32.GetString([BitConverter]::GetBytes($codePoint))
    }

    # Common glyphs (prefer widely supported symbols)
    $Check      = New-Utf32Char 0x2705   # ✅
    $Cross      = New-Utf32Char 0x274C   # ❌
    $Warn       = New-Utf32Char 0x26A0   # ⚠
    $Skip       = New-Utf32Char 0x23ED   # ⏭
    $Trash      = (New-Utf32Char 0x0001F5D1) + (New-Utf32Char 0x0000FE0F) # 🗑️
    $Shield     = (New-Utf32Char 0x0001F6E1) # 🛡
    $Info       = New-Utf32Char 0x2139   # ℹ
    $Search     = New-Utf32Char 0x0001F50D # 🔍
    $Note       = New-Utf32Char 0x0001F4DD # 📝
    $Timer      = (New-Utf32Char 0x23F1) # ⏱
    $Chart      = New-Utf32Char 0x0001F4CA # 📊

    return @{
        Kept        = $Check
        Removed     = $Trash
        WouldRemove = $Info
        Skipped     = $Skip
        Protected   = $Shield
        Warning     = $Warn
        Fail        = $Cross
        Inspect     = $Search
        Duplicate   = $Skip
        Note        = $Note
        Timer       = $Timer
        Stats       = $Chart
        Success     = $Check
    }
}
