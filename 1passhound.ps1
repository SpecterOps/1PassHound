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

function ConvertTo-PascalCase {
    param (
        [string]$String
    )

    if ([string]::IsNullOrEmpty($String)) {
        return $String
    }

    # Replace common delimiters with spaces and convert to lowercase to handle various input formats
    $cleanedString = $String -replace '[-_]', ' ' | ForEach-Object { $_.ToLower() }

    # Use TextInfo.ToTitleCase to capitalize the first letter of each word
    # Then remove spaces to achieve PascalCase
    $pascalCaseString = (Get-Culture).TextInfo.ToTitleCase($cleanedString).Replace(' ', '')

    return $pascalCaseString
}

function Normalize-Null
{
    param($Value)
    if ($null -eq $Value) { return "" }
    return $Value
}

function Get-1PassAccount
{
    $nodes = New-Object System.Collections.ArrayList

    $account = op account get --format json | ConvertFrom-Json
    $accountDetails = op account list --format json | ConvertFrom-Json | Where-Object { $_.account_uuid -eq $account.id }
    $props = [pscustomobject]@{
        id           = Normalize-Null $account.id
        name         = Normalize-Null $accountDetails.url
        display_name = Normalize-Null $account.name
        domain       = Normalize-Null $account.domain
        type         = Normalize-Null $account.type
        state        = Normalize-Null $account.state
        created      = Normalize-Null $account.created_at
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
            name         = Normalize-Null $user.email
            display_name = Normalize-Null $user.name
            email        = Normalize-Null $user.email
            state        = Normalize-Null $user.state
            type         = Normalize-Null $user.type
            account_id   = Normalize-Null $account.id
            account_name = Normalize-Null $account.domain
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
            account_id   = Normalize-Null $account.id
            account_name = Normalize-Null $account.domain
        }
        
        $null = $nodes.Add((New-1PassHoundNode -Id $groupDetails.id -Kind 'OPGroup' -Properties $props))
        $null = $edges.Add((New-1PassHoundEdge -Kind 'OPContains' -StartId $account.id -EndId $groupDetails.id))

        # Enumerate Group Permissions on Account
        if($null -ne $groupDetails.permissions)
        {
            foreach($perm in $groupDetails.permissions)
            {
                $null = $edges.Add((New-1PassHoundEdge -Kind "OP$(ConvertTo-PascalCase -String $perm)" -StartId $groupDetails.id -EndId $account.id))
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
            account_id   = Normalize-Null $account.id
            account_name = Normalize-Null $account.domain
        }

        $null = $nodes.Add((New-1PassHoundNode -Id $vault.id -Kind 'OPVault' -Properties $props))
        $null = $edges.Add((New-1PassHoundEdge -Kind 'OPContains' -StartId $account.id -EndId $vault.id))

        # Get Group permissions to vault
        foreach($group in (op vault group list "$($vault.id)" --format json | ConvertFrom-Json))
        {
            foreach($perm in $group.permissions)
            {
                $null = $edges.Add((New-1PassHoundEdge -Kind "OP$(ConvertTo-PascalCase -String $perm)" -StartId $group.id -EndId $vault.id))
            }
        }

        # Get User permissions to vault
        foreach ($user in (op vault user list "$($vault.id)" --format json | ConvertFrom-Json))
        {
            foreach($perm in $user.permissions)
            {
                $null = $edges.Add((New-1PassHoundEdge -Kind "OP$(ConvertTo-PascalCase -String $perm)" -StartId $user.id -EndId $vault.id))
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
        if($item.vault.name -ne 'Employee')
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
                account_id             = Normalize-Null $account.id
                account_name           = Normalize-Null $account.domain
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

    Write-Host "[*] Enumerating Account"
    $account = Get-1PassAccount
    $nodes.Add($account) | Out-Null

    Write-Host "[*] Enumerating Users"
    $users = Get-1PassUser
    if($users.nodes) { $nodes.AddRange(@($users.nodes)) }
    if($users.edges) { $edges.AddRange(@($users.edges)) }

    Write-Host "[*] Enumerating Groups"
    $groups = Get-1PassGroup
    if($groups.nodes) { $nodes.AddRange(@($groups.nodes)) }
    if($groups.edges) { $edges.AddRange(@($groups.edges)) }

    Write-Host "[*] Enumerating Vaults"
    $vaults = Get-1PassVault
    if($vaults.nodes) { $nodes.AddRange(@($vaults.nodes)) }
    if($vaults.edges) { $edges.AddRange(@($vaults.edges)) }

    Write-Host "[*] Enumerating Items"
    $items = Get-1PassItem
    if($items.nodes) { $nodes.AddRange(@($items.nodes)) }
    if($items.edges) { $edges.AddRange(@($items.edges)) }

    $payload = [PSCustomObject]@{
        metadata = [PSCustomObject]@{
            source_kind = "OPBase"
        }
        graph = [PSCustomObject]@{
            nodes = $nodes.ToArray()
            edges = $edges.ToArray()
        }
    } | ConvertTo-Json -Depth 10

    $payload | Out-File -FilePath "./1pass_$($account.id).json"
    #$payload | BHDataUploadJSON
}
