[CmdletBinding()]
param()
$t=invoke-restmethod -uri "https://google.com" -method 'GET' -verbose:$false
$t