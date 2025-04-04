<#
      .Synopsis
       Update policy with new rules
      .Description
       Patch $policyID with the rules $rules
      .Parameter PolicyID
       policy ID
      .Parameter rules
        rules
      .Example
        PS> Update-Policy -policyID $id -rules $rules

        Update $policyID with rules $rules
      .Link

      .Notes
#>
function Update-EntraRolePolicy  {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        $policyID,
        $rules
    )
    Log "Updating Policy $policyID" -noEcho
    #write-verbose "rules: $rules"
    $endpoint="policies/roleManagementPolicies/$policyID"

    $body = '

        {
            "rules": [
        '+ $rules +
    ']
    }'


    write-verbose "`n>> PATCH body: $body"
    write-verbose "Patch endpoint : $endpoint"
    $response = invoke-graph -Endpoint $endpoint -Method "PATCH" -Body $body
    #
    return $response
}
