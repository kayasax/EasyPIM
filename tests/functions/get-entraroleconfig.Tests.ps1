# Import the module that contains the function to test
#Import-Module ../Easypim

Describe 'get-EntraRoleConfig' {
    It 'processes the response correctly' {   
        # Act
        $Script:tenantID = "$8d4fd732-58aa-4643-8cae-974854a66a2d"
        $result = get-EntraRoleConfig -rolename 'Pester'
        # Assert
        $result.ActivationDuration | Should -Be "PT8H"
        $result.EnablementRules | Should -Be "Justification,Ticketing"
        $result.MaximumEligibleAssignmentDuration | Should -Be "P365D"
        $result.AllowPermanentEligibleAssignment |Should -Be "true"
        $result.Notification_Eligibility_Alert_Recipients | Should -Be "Alert@dom.com,alert2@domaine.com"
        #$result.Notification_Admin_Admin_Eligibility | Should -Not -BeNullOrEmpty
    }
    
}