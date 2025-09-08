<#
    .Synopsis
    Define if approval is required to activate a role, and who are the approvers
    .Description
    rule 4 in https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#activation-rules
    .Parameter ApprovalRequired
    Do we need an approval to activate a role?
    .Parameter Approvers
    Who is the approver?
    .Parameter EntraRole
    Set to $true when editing an Entra Role
    .EXAMPLE
    PS> Set-Approval -ApprovalRequired $true -Approvers @(@{"Id"=$UID;"Name"="John":"Type"="user"}, @{"Id"=$GID;"Name"="Group1":"Type"="group"})

    define John and Group1 as approvers and require approval

    .Link

    .Notes

#>
function Set-Approval ($ApprovalRequired, $Approvers, [switch]$entraRole) {
    try {
        Write-Verbose "Set-Approval started with ApprovalRequired=$ApprovalRequired and Approvers=$Approvers and entraRole=$entraRole"
        if ($null -eq $Approvers) { $Approvers = $script:config.Approvers }
        if ($ApprovalRequired -eq $false) { $req = "false" }else { $req = "true" }
        <#working sample
    {"properties":{"scope":"/subscriptions/eedcaa84-3756-4da9-bf87-40068c3dd2a2","rules":[
{"id":"Approval_EndUser_Assignment","ruleType":"RoleManagementPolicyApprovalRule",
"target":{"caller":"EndUser","operations":["All"],"level":"Assignment"},
"setting":{"isApprovalRequired":false,
"isApprovalRequiredForExtension":false,
"isRequestorJustificationRequired":true,
"approvalMode":"SingleStage",
"approvalStages":[{"approvalStageTimeOutInDays":1,"isApproverJustificationRequired":true,"escalationTimeInMinutes":0,"isEscalationEnabled":false,
"primaryApprovers":[{"id":"5dba24e0-00ef-4c21-9702-7c093a0775eb","userType":"Group","description":"0Ext_Partners","isBackup":false},
{"id":"00b34bb3-8a6b-45ce-a7bb-c7f7fb400507","userType":"User","description":"Bob MARLEY","isBackup":false},
{"id":"25f3deb5-1c8d-4035-942d-b3cbbad98b8e","userType":"User","description":"Loïc","isBackup":false},
{"id":"39014f60-8bf7-4d58-88e3-4d6f04f7c279","userType":"User","description":"Loic MICHEL","isBackup":false}
],
"escalationApprovers":[]
}]}}]}
    #>

        $rule = '{
    "id":"Approval_EndUser_Assignment",
    "ruleType":"RoleManagementPolicyApprovalRule",
    "target":{
        "caller":"EndUser",
        "operations":["All"],
        "level":"Assignment"
    },
    "setting":{
        "isApprovalRequired":"'+ $req + '",
        "isApprovalRequiredForExtension":false,
        "isRequestorJustificationRequired":true,
        "approvalMode":"SingleStage",
        "approvalStages":[{
            "approvalStageTimeOutInDays":1,
            "isApproverJustificationRequired":true,
            "escalationTimeInMinutes":0,
            "isEscalationEnabled":false,
            "primaryApprovers":[
                '
        if ($PSBoundParameters.Keys.Contains('Approvers') -and ($null -ne $Approvers)) {
        $cpt = 0
        $Approvers | ForEach-Object {
            #write-host $_
            $id = $_.Id
            $name = $_.Name
            $type = $_.Type
            if (-not $type) { $type = $_.type }
            if (-not $type) {
                # Auto-detect object type by querying Azure AD
                Write-Verbose "No type specified for approver $id, attempting automatic detection"
                try {
                    # Try as user first using Invoke-MgGraphRequest
                    $userResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$id" -Method GET -ErrorAction Stop
                    if ($userResult -and $userResult.id) {
                        $type = "User"
                        Write-Verbose "Auto-detected object type: User for approver $id (displayName: $($userResult.displayName))"
                    }
                }
                catch {
                    Write-Verbose "Object $id is not a User, checking if it's a Group"
                    try {
                        # Try as group using Invoke-MgGraphRequest
                        $groupResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$id" -Method GET -ErrorAction Stop
                        if ($groupResult -and $groupResult.id) {
                            $type = "Group"
                            Write-Verbose "Auto-detected object type: Group for approver $id (displayName: $($groupResult.displayName))"
                        }
                    }
                    catch {
                        $type = "User"  # Fallback to User if detection fails
                        Write-Warning "Could not auto-detect type for approver $id, defaulting to User. Ensure the ID exists and you have appropriate Graph permissions."
                    }
                }
            }
            
            if ($cpt -gt 0) {
                $rule += ","
            }
            $rule += '
            {
                "id": "'+ $id + '",
                "userType": "'+ $type + '",
                "description": "'+ $name + '",
                "isBackup": false
            }
            '
            $cpt++
        }
        $rule=$rule -replace ",$" #remove last comma
    }

        <#{"id":"5dba24e0-00ef-4c21-9702-7c093a0775eb","userType":"Group","description":"0Ext_Partners","isBackup":false},
                {"id":"00b34bb3-8a6b-45ce-a7bb-c7f7fb400507","userType":"User","description":"Bob MARLEY","isBackup":false},
                {"id":"25f3deb5-1c8d-4035-942d-b3cbbad98b8e","userType":"User","description":"Loïc","isBackup":false},
                {"id":"39014f60-8bf7-4d58-88e3-4d6f04f7c279","userType":"User","description":"Loic MICHEL","isBackup":false}#>
        $rule += '
            ],
            "escalationApprovers":[]
        }]
    }
}'


        <#    $rule = '
    {
        "setting": {'
        if ($null -ne $ApprovalRequired) {
            $rule += '"isApprovalRequired": ' + $req + ','
        }
        $rule += '
        "isApprovalRequiredForExtension": false,
        "isRequestorJustificationRequired": true,
        "approvalMode": "SingleStage",
        "approvalStages": [
            {
            "approvalStageTimeOutInDays": 1,
            "isApproverJustificationRequired": true,
            "escalationTimeInMinutes": 0,
        '

        if ($null -ne $Approvers) {
            #at least one approver required if approval is enable
            $rule += '
            "primaryApprovers": [
            '
            $cpt = 0
            $Approvers | ForEach-Object {
                #write-host $_
                $id = $_.Id
                $name = $_.Name
                $type = $_.Type

                if ($cpt -gt 0) {
                    $rule += ","
                }
                $rule += '
            {
                "id": "'+ $id + '",
                "description": "'+ $name + '",
                "isBackup": false,
                "userType": "'+ $type + '"
            }
            '
                $cpt++
            }

            $rule += '
            ],'
        }

        $rule += '
        "isEscalationEnabled": false,
            "escalationApprovers": null
                    }]
                 },
        "id": "Approval_EndUser_Assignment",
        "ruleType": "RoleManagementPolicyApprovalRule",
        "target": {
            "caller": "EndUser",
            "operations": [
                "All"
            ],
            "level": "Assignment",
            "targetObjects": null

            },


            "inheritableSettings": null,
            "enforcedSettings": null

        }}'
#>

        if ($entraRole) {
            # Normalize approvers: avoid treating arbitrary strings as approver objects
            # - If it's a whitespace/empty string, treat as null
            # - If it looks like a serialized hashtable list from Get-EntraRoleConfig (e.g. @{"id"="..."},@{...}), parse it
            if ($Approvers -is [string]) {
                $apTxt = $Approvers.Trim()
                if ([string]::IsNullOrWhiteSpace($apTxt)) {
                    $Approvers = $null
                }
                elseif ($apTxt.StartsWith('[') -or $apTxt.StartsWith('{')) {
                    # Try JSON first (preferred safe format)
                    try {
                        $parsed = $apTxt | ConvertFrom-Json -ErrorAction Stop
                        if ($parsed -is [array]) { $Approvers = $parsed }
                        elseif ($parsed) { $Approvers = @($parsed) } else { $Approvers = $null }
                    } catch { Write-Verbose "Approvers string was not valid JSON; skipping approver subjects."; $Approvers = $null }
                }
                else {
                    # Unknown string format; ignore to avoid generating empty subject entries
                    $Approvers = $null
                }
            }

            # Build approvers array JSON safely (no trailing commas)
            $approverItems = ''
            $approverGroups = 0; $approverUsers = 0
            # If approval is NOT required, force an empty approver list regardless of config/current policy
            if ($ApprovalRequired -eq $false -or $req -eq 'false') {
                $approverItems = ''
                $approverGroups = 0; $approverUsers = 0
            }
            elseif ($null -ne $Approvers -and -not ($Approvers -is [string]) -and (($Approvers | Measure-Object).Count -gt 0)) {
                $parts = @()
                foreach ($a in $Approvers) {
                    $id = $a.Id
                    if (-not $id) { $id = $a.id }
                    $name = $a.Name
                    if (-not $name) { $name = $a.name }
                    if (-not $name) { $name = $a.description }
                    # Determine approver subject set type for Graph (@odata.type)
                    $type = $a.Type; if (-not $type) { $type = $a.type }
                    if (-not $type -and $a.PSObject.Properties['userType']) { $type = $a.userType }
                    $odataType = '#microsoft.graph.singleUser'
                    $idPropName = 'userId'
                    if (-not [string]::IsNullOrWhiteSpace($type)) {
                        $t = ($type.ToString()).Trim().ToLowerInvariant()
                        if ($t -eq 'group' -or $t -eq 'groupmembers') { $odataType = '#microsoft.graph.groupMembers'; $idPropName = 'groupId' }
                    }
                    # Skip invalid/empty IDs to avoid Graph FormatException (Unrecognized Guid format)
                    if ([string]::IsNullOrWhiteSpace([string]$id)) { Write-Verbose "Skipping approver with empty id in approver list."; continue }
                    if ($odataType -eq '#microsoft.graph.groupMembers') { $approverGroups++ } else { $approverUsers++ }
                    $parts += @"
                                {
                                    "@odata.type": "$odataType",
                                    "$idPropName": "$id"
                                }
"@
                }
                $approverItems = ($parts -join ',')
            }

            $rule = '
    {
        "@odata.type": "#microsoft.graph.unifiedRoleManagementPolicyApprovalRule",
        "id": "Approval_EndUser_Assignment",
        "target": {
            "caller": "EndUser",
            "operations": [
                "All"
            ],
            "level": "Assignment",
            "inheritableSettings": [],
            "enforcedSettings": []
        },
        "setting": {
            "isApprovalRequired": ' + $req + ',
            "isApprovalRequiredForExtension": false,
            "isRequestorJustificationRequired": true,
            "approvalMode": "SingleStage",
            "approvalStages": [
                {
                    "approvalStageTimeOutInDays": 1,
                    "isApproverJustificationRequired": true,
                    "escalationTimeInMinutes": 0,
                    "isEscalationEnabled": false,
                    "primaryApprovers": [
                        ' + $approverItems + '
                    ],
                    "escalationApprovers": []
                }
            ]
        }
    }'
            Write-Verbose ("[Policy][Entra][Approval] Built subject sets: Users={0}, Groups={1}" -f $approverUsers, $approverGroups)
        }
        return $rule
    }
    catch {
        MyCatch $_
    }
}
