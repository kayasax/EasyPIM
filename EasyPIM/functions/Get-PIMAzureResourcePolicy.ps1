function Get-PIMAzureResourcePolicy{
    [CmdletBinding()]
    param (
        $scope, $rolename
    )
    $out=@()
    $rolename | ForEach-Object {
        
        #get curent config
        $config = get-config $scope $_
        $out += $config
    }
    return $config
}