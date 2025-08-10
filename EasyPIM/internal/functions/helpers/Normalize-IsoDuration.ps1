# Internal helper: Normalize-IsoDuration
function Normalize-IsoDuration {
    [CmdletBinding()]
    param(
        [string]$Duration,
        [switch]$AllowNull
    )
    if([string]::IsNullOrWhiteSpace($Duration)){
        if($AllowNull){ return $null } else { throw "Duration value is empty" }
    }
    $orig = $Duration
    if($Duration -match '^P[0-9]+[HMS]$'){ $Duration = $Duration -replace '^P','PT' }
    $isoPattern = '^(?=P)(P(?=.+)(\d+Y)?(\d+M)?(\d+D)?(T(\d+H)?(\d+M)?(\d+S)?)?)$'
    if($Duration -notmatch $isoPattern){ throw "Duration '$orig' is not a valid ISO8601 duration token after normalization ('$Duration')." }
    try { [void][System.Xml.XmlConvert]::ToTimeSpan($Duration) } catch { throw "Duration '$orig' (normalized '$Duration') cannot be parsed: $($_.Exception.Message)" }
    return $Duration
}
