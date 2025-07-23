function New-1PassHoundNode
{
    Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [String]
        $Id,

        [Parameter(Position = 1, Mandatory = $true)]
        [String]
        $Kind,

        [Parameter(Position = 2, Mandatory = $true)]
        [PSObject]
        $Properties
    )

    $props = [pscustomobject]@{
        id = $Id
        kinds = @($Kind, 'OPBase')
        properties = $Properties
    }

    Write-Output $props
}

function New-1PassHoundItemNode
{
    Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [String]
        $Id,

        [Parameter(Position = 1, Mandatory = $true)]
        [String]
        $Kind,

        [Parameter(Position = 2, Mandatory = $true)]
        [PSObject]
        $Properties
    )

    $props = [pscustomobject]@{
        id = $Id
        kinds = @($Kind, 'OPItem', 'OPBase')
        properties = $Properties
    }

    Write-Output $props
}

function New-1PassHoundEdge
{
    Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [String]
        $Kind,

        [Parameter(Position = 1, Mandatory = $true)]
        [PSObject]
        $StartId,

        [Parameter(Position = 2, Mandatory = $true)]
        [PSObject]
        $EndId
    )

    $edge = [PSCustomObject]@{
        kind = $Kind
        start = [PSCustomObject]@{
            value = $StartId
        }
        end = [PSCustomObject]@{
            value = $EndId
        }
        properties = @{}
    }

    Write-Output $edge
}

function Get-1PassAccount
{
    $nodes = New-Object System.Collections.ArrayList

    $account = op account get --format json | ConvertFrom-Json

    $props = [pscustomobject]@{
        id      = Normalize-Null $account.id
        name    = Normalize-Null $account.name
        domain  = Normalize-Null $account.domain
        type    = Normalize-Null $account.type
        state   = Normalize-Null $account.state
        created = Normalize-Null $account.created_at
    }

    $null = $nodes.Add((New-1PassHoundNode -Id $account.id -Kind 'OPAccount' -Properties $props))

    Write-Output $nodes
}

function Get-1PassUser
{
    $nodes = New-Object System.Collections.ArrayList
    $edges = New-Object System.Collections.ArrayList

    $account = op account get --format json | ConvertFrom-Json

    foreach($user in (op user list --format json | ConvertFrom-Json))
    {
        $props = [pscustomobject]@{
            id           = Normalize-Null $user.id
            name         = Normalize-Null $user.name
            email        = Normalize-Null $user.email
            state        = Normalize-Null $user.state
            type         = Normalize-Null $user.type
            account_name = Normalize-Null $account.name
            account_id   = Normalize-Null $account.id
        }

        $null = $nodes.Add((New-1PassHoundNode -Id $user.id -Kind 'OPUser' -Properties $props))
        $null = $edges.Add((New-1PassHoundEdge -Kind 'OPContains' -StartId $account.id -EndId $user.id))
    }

    $output = [PSCustomObject]@{
        Nodes = $nodes
        Edges = $edges
    }

    Write-Output $output
}

# I need to add the role for each user
# This requires some level of permission on the group because I cannot see the role information on most groups
function Get-1PassGroup
{
    $nodes = New-Object System.Collections.ArrayList
    $edges = New-Object System.Collections.ArrayList

    $account = op account get --format json | ConvertFrom-Json

    foreach($group in (op group list --format json | ConvertFrom-Json))
    {
        $groupDetails = op group get "$($group.id)" --format json | ConvertFrom-Json

        $props = [pscustomobject]@{
            id           = Normalize-Null $groupDetails.id
            name         = Normalize-Null $groupDetails.name
            state        = Normalize-Null $groupDetails.state
            created      = Normalize-Null $groupDetails.created_at
            updated      = Normalize-Null $groupDetails.updated_at
            type         = Normalize-Null $groupDetails.type
            permissions  = Normalize-Null $groupDetails.permissions
            account_name = Normalize-Null $account.name
            account_id   = Normalize-Null $account.id
        }
        
        $null = $nodes.Add((New-1PassHoundNode -Id $groupDetails.id -Kind 'OPGroup' -Properties $props))
        $null = $edges.Add((New-1PassHoundEdge -Kind 'OPContains' -StartId $account.id -EndId $groupDetails.id))

        # Enumerate Group Permissions on Account
        if($null -ne $groupDetails.permissions)
        {
            foreach($perm in $groupDetails.permissions)
            {
                switch($perm)
                {
                    'MANAGE_GROUPS' { $null = $edges.Add((New-1PassHoundEdge -Kind OPManageGroups -StartId $groupDetails.id -EndId $account.id)) }
                    'CHANGE_TEAM_SETTINGS' { $null = $edges.Add((New-1PassHoundEdge -Kind OPChangeTeamSettings -StartId $groupDetails.id -EndId $account.id)) }
                    'RECOVER_ACCOUNTS' { $null = $edges.Add((New-1PassHoundEdge -Kind OPRecoverAccounts -StartId $groupDetails.id -EndId $account.id)) }
                    'VIEW_ADMINISTRATIVE_SIDEBAR' { $null = $edges.Add((New-1PassHoundEdge -Kind OPViewAdministrativeSidebar -StartId $groupDetails.id -EndId $account.id)) }
                    'VIEW_PEOPLE' { $null = $edges.Add((New-1PassHoundEdge -Kind OPViewPeople -StartId $groupDetails.id -EndId $account.id)) }
                    #'DELETE_PERSON' {}
                    'MANAGE_TEMPLATES' { $null = $edges.Add((New-1PassHoundEdge -Kind OPManageTemplates -StartId $groupDetails.id -EndId $account.id)) }
                    'MANAGE_VAULTS' { $null = $edges.Add((New-1PassHoundEdge -Kind OPManageVaults -StartId $groupDetails.id -EndId $account.id)) }
                    'CHANGE_TEAM_ATTRIBUTES' { $null = $edges.Add((New-1PassHoundEdge -Kind OPChangeTeamAttributes -StartId $groupDetails.id -EndId $account.id)) }
                    #'SUSPEND_TEAM' {}
                    #'DELETE_TEAM' {}
                    'ADD_PERSON' { $null = $edges.Add((New-1PassHoundEdge -Kind OPAddPerson -StartId $groupDetails.id -EndId $account.id)) }
                    #'SUSPEND_PERSON' {}
                    'VIEW_VAULTS' { $null = $edges.Add((New-1PassHoundEdge -Kind OPViewVaults -StartId $groupDetails.id -EndId $account.id)) }
                    'VIEW_TEAM_SETTINGS' { $null = $edges.Add((New-1PassHoundEdge -Kind OPViewTeamSettings -StartId $groupDetails.id -EndId $account.id)) }
                    #'VIEW_BILLING' {}
                    #'CHANGE_PERSON_NAME' {}
                    'CREATE_VAULTS' { $null = $edges.Add((New-1PassHoundEdge -Kind OPCreateVaults -StartId $groupDetails.id -EndId $account.id)) }
                    'CHANGE_TEAM_DOMAIN' { $null = $edges.Add((New-1PassHoundEdge -Kind OPChangeTeamDomain -StartId $groupDetails.id -EndId $account.id)) }
                    'VIEW_ACTIVITIES_LOG' { $null = $edges.Add((New-1PassHoundEdge -Kind OPViewActivitiesLog -StartId $groupDetails.id -EndId $account.id)) }
                    'VIEW_TEMPLATES' { $null = $edges.Add((New-1PassHoundEdge -Kind OPViewTemplates -StartId $groupDetails.id -EndId $account.id)) }
                    #'MANAGE_BILLING' {}
                    'PROVISION_PEOPLE' { $null = $edges.Add((New-1PassHoundEdge -Kind OPProvisionPeople -StartId $groupDetails.id -EndId $account.id)) }
                }
            }
        }

        # Enumerate Group Members
        foreach($user in (op group user list $($groupDetails.id) --format json | ConvertFrom-Json))
        {
            $null = $edges.Add((New-1PassHoundEdge -Kind OPMemberOf -StartId $user.id -EndId $groupDetails.id))
        }
    }

    $output = [PSCustomObject]@{
        Nodes = $nodes
        Edges = $edges
    }

    Write-Output $output
}

function Get-1PassVault
{
    $nodes = New-Object System.Collections.ArrayList
    $edges = New-Object System.Collections.ArrayList

    $account = op account get --format json | ConvertFrom-Json

    foreach($vault in (op vault list --format json | ConvertFrom-Json))
    {
        $vaultDetails = op vault get "$($vault.id)" --format json | ConvertFrom-Json

        if($vaultDetails.type -eq "PERSONAL")
        {
            $owner = op vault user list "$($vault.id)" --format json | ConvertFrom-Json
            $vaultName = "$($vault.name) - $($owner.name)"
        }
        else 
        {
            $vaultName = $vault.name    
        }

        $props = [pscustomobject]@{
            id           = Normalize-Null $vault.id
            name         = Normalize-Null $vaultName
            description  = Normalize-Null $vaultDetails.description
            type         = Normalize-Null $vaultDetails.type
            created      = Normalize-Null $vault.created_at
            updated      = Normalize-Null $vault.updated_at
            item_count   = Normalize-Null $vault.items
            account_name = Normalize-Null $account.name
            account_id   = Normalize-Null $account.id
        }

        $null = $nodes.Add((New-1PassHoundNode -Id $vault.id -Kind 'OPVault' -Properties $props))
        $null = $edges.Add((New-1PassHoundEdge -Kind 'OPContains' -StartId $account.id -EndId $vault.id))

        # Get Group permissions to vault
        foreach($group in (op vault group list "$($vault.id)" --format json | ConvertFrom-Json))
        {
            foreach($perm in $group.permissions)
            {
                switch($perm)
                {
                    'view_items' { $null = $edges.Add((New-1PassHoundEdge -Kind OPViewItems -StartId $group.id -EndId $vault.id)) }
                    #'create_items' {}
                    #'edit_items' {}
                    #'archive_items' {}
                    #'delete_items' {}
                    'view_and_copy_passwords' { $null = $edges.Add((New-1PassHoundEdge -Kind OPViewAndCopyPasswords -StartId $group.id -EndId $vault.id)) }
                    #'view_item_history' {}
                    #'import_items' {}
                    'export_items' { $null = $edges.Add((New-1PassHoundEdge -Kind OPExportItems -StartId $group.id -EndId $vault.id)) }
                    'copy_and_share_items' { $null = $edges.Add((New-1PassHoundEdge -Kind OPCopyAndShareItems -StartId $group.id -EndId $vault.id)) }
                    'print_items' { $null = $edges.Add((New-1PassHoundEdge -Kind OPPrintItems -StartId $group.id -EndId $vault.id)) }
                    'manage_vault' { $null = $edges.Add((New-1PassHoundEdge -Kind OPManageVault -StartId $group.id -EndId $vault.id)) }
                }
            }
        }

        # Get User permissions to vault
        foreach ($user in (op vault user list "$($vault.id)" --format json | ConvertFrom-Json))
        {
            foreach($perm in $user.permissions)
            {
                switch($perm)
                {
                    'view_items' { $null = $edges.Add((New-1PassHoundEdge -Kind OPViewItems -StartId $user.id -EndId $vault.id)) }
                    #'create_items' {}
                    #'edit_items' {}
                    #'archive_items' {}
                    #'delete_items' {}
                    'view_and_copy_passwords' { $null = $edges.Add((New-1PassHoundEdge -Kind OPViewAndCopyPasswords -StartId $user.id -EndId $vault.id)) }
                    #'view_item_history' {}
                    #'import_items' {}
                    'export_items' { $null = $edges.Add((New-1PassHoundEdge -Kind OPExportItems -StartId $user.id -EndId $vault.id)) }
                    'copy_and_share_items' { $null = $edges.Add((New-1PassHoundEdge -Kind OPCopyAndShareItems -StartId $user.id -EndId $vault.id)) }
                    'print_items' { $null = $edges.Add((New-1PassHoundEdge -Kind OPPrintItems -StartId $user.id -EndId $vault.id)) }
                    'manage_vault' { $null = $edges.Add((New-1PassHoundEdge -Kind OPManageVault -StartId $user.id -EndId $vault.id)) }
                }
            }         
        }
    }

    $output = [PSCustomObject]@{
        Nodes = $nodes
        Edges = $edges
    }

    Write-Output $output
}

function Get-1PassItem
{
    $nodes = New-Object System.Collections.ArrayList
    $edges = New-Object System.Collections.ArrayList

    $account = op account get --format json | ConvertFrom-Json

    # Get Items in Vault
    foreach($item in (op item list --format json | ConvertFrom-Json))
    {
        $urls = New-Object System.Collections.ArrayList

        $props = [pscustomobject]@{
            id                     = Normalize-Null $item.id
            name                   = Normalize-Null $item.title
            category               = Normalize-Null $item.category
            last_edited_by         = Normalize-Null $item.last_edited_by
            created                = Normalize-Null $item.created_at
            updated                = Normalize-Null $item.updated_at
            additional_information = Normalize-Null $item.additional_information
            account_name           = Normalize-Null $account.name
            account_id             = Normalize-Null $account.id
        }

        if($item.urls)
        {
            foreach($url in $item.urls)
            {
                $urls.Add($url.href) | Out-Null
            }

            $props | Add-Member -MemberType NoteProperty -Name urls -Value $urls.ToArray()
        }

        switch($item.category)
        {
            'API_CREDENTIAL' { $Kind = 'OPApiCredential' }
            'CREDIT_CARD' { $Kind = 'OPCreditCard' }
            'DOCUMENT' { $Kind = 'OPDocument' }
            'LOGIN' { $Kind = 'OPLogin' }
            'PASSPORT' { $Kind = 'OPPassport' }
            'PASSWORD' { $Kind = 'OPPassword' }
            'SECURE_NOTE' { $Kind = 'OPSecureNote' }
            'SERVER' { $Kind = 'OPServer' }
            'SOFTWARE_LICENSE' { $Kind = 'OPSoftwareLicense' }
            'SSH_KEY' { $Kind = 'OPSshKey' }
            'WIRELESS_ROUTER' { $Kind = 'OPWirelessRouter' }
            default { $Kind = 'OPItem' }
        }
        
        $null = $nodes.Add((New-1PassHoundNode -Id $item.id -Kind $Kind -Properties $props))
        $null = $edges.Add((New-1PassHoundEdge -Kind OPContains -StartId $account.id -EndId $item.id))
        $null = $edges.Add((New-1PassHoundEdge -Kind OPHasItem -StartId $item.vault.id -EndId $item.id))
    }

    $output = [PSCustomObject]@{
        Nodes = $nodes
        Edges = $edges
    }

    Write-Output $output
}

function Invoke-1PassHound
{
    $edges = New-Object System.Collections.ArrayList
    $nodes = New-Object System.Collections.ArrayList

    $account = Get-1PassAccount
    $nodes.Add($account) | Out-Null

    $users = Get-1PassUser
    if($users.nodes) { $nodes.AddRange(@($users.nodes)) }
    if($users.edges) { $edges.AddRange(@($users.edges)) }

    $groups = Get-1PassGroup
    if($groups.nodes) { $nodes.AddRange(@($groups.nodes)) }
    if($groups.edges) { $edges.AddRange(@($groups.edges)) }

    $vaults = Get-1PassVault
    if($vaults.nodes) { $nodes.AddRange(@($vaults.nodes)) }
    if($vaults.edges) { $edges.AddRange(@($vaults.edges)) }

    $items = Get-1PassItem
    if($items.nodes) { $nodes.AddRange(@($items.nodes)) }
    if($items.edges) { $edges.AddRange(@($items.edges)) }

    $payload = [PSCustomObject]@{
        graph = [PSCustomObject]@{
            nodes = $nodes.ToArray()
            edges = $edges.ToArray()
        }
    } | ConvertTo-Json -Depth 10

    $payload | Out-File -FilePath ./1pass.json
    #$payload | BHDataUploadJSON
}
