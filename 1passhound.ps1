# TODO: Add documentation to each collector function regarding which 1Password permissions are necessary to collect the data

function New-1PassHoundNode
{
    <#
    .SYNOPSIS
    Creates a 1PassHound Node object.
    
    .DESCRIPTION
    Author: Jared Atkinson (@cobbler) at SpecterOps
    
    This function creates a node object for use in 1PassHound's graph structure.

    .PARAMETER Id
    
    The unique identifier for the node. This is derived from 1Password's internal IDs which are returned for each object from the CLI.
    
    .PARAMETER Kind

    The type or category of the node (e.g., OPUser, OPGroup).

    .PARAMETER Properties

    A PSObject containing the properties of the node.

    .EXAMPLE

    $node = New-1PassHoundNode -Id "12345" -Kind "OPUser" -Properties $props

    This example creates a new node of kind "OPUser" with the specified ID and properties.
    #>
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
        kinds = @($Kind)
        properties = $Properties
    }

    Write-Output $props
}

function New-1PassHoundItemNode
{
    <#
    .SYNOPSIS
    Creates a 1PassHound Item Node object. This is a subset of New-1PassHoundNode with additional kinds. Each item node will also have 'OPItem' and 'OPBase' kinds.

    .DESCRIPTION
    Author: Jared Atkinson (@cobbler) at SpecterOps

    This function creates a node object for use in 1PassHound's graph structure, specifically for item nodes. 
    
    Supported item node kinds are: OPApiCredential, OPCreditCard, OPDocument, OPLogin, OPPassport, OPPassword, OPSecureNote, OPServer, OPSoftwareLicense, OPSshKey, OPWirelessRouter.

    .PARAMETER Id
    The unique identifier for the item node. This is derived from 1Password's internal IDs which are returned for each object from the CLI.

    .PARAMETER Kind
    The specific type or category of the item node (e.g., OPLogin, OPCreditCard).

    .PARAMETER Properties
    A PSObject containing the properties of the item node.

    .EXAMPLE
    $itemNode = New-1PassHoundItemNode -Id "67890" -Kind "OPLogin" -Properties $itemProps
    #>
    Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [String]
        $Id,

        [Parameter(Position = 1, Mandatory = $true)]
        [ValidateSet('OPApiCredential', 'OPCreditCard', 'OPDocument', 'OPLogin', 'OPPassport', 'OPPassword', 'OPSecureNote', 'OPServer', 'OPSoftwareLicense', 'OPSshKey', 'OPWirelessRouter')]
        [String]
        $Kind,

        [Parameter(Position = 2, Mandatory = $true)]
        [PSObject]
        $Properties
    )

    $props = [pscustomobject]@{
        id = $Id
        kinds = @($Kind, 'OPItem')
        properties = $Properties
    }

    Write-Output $props
}

function New-1PassHoundEdge
{
    <#
    .SYNOPSIS
    Creates a 1PassHound Edge object.

    .DESCRIPTION
    Author: Jared Atkinson (@cobbler) at SpecterOps

    This function creates an edge object for use in 1PassHound's graph structure.

    .PARAMETER Kind
    The type or category of the edge (e.g., OPContains, OPMemberOf).

    .PARAMETER StartId
    The unique identifier of the starting node for the edge.

    .PARAMETER EndId
    The unique identifier of the ending node for the edge.

    .EXAMPLE
    $edge = New-1PassHoundEdge -Kind "OPContains" -StartId "12345" -EndId "67890"

    This example creates a new edge of kind "OPContains" from the node with ID "12345" to the node with ID "67890".
    #>
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

function ConvertTo-PascalCase
{
    <#
    .SYNOPSIS
    Converts a given string to PascalCase format.

    .DESCRIPTION
    Author: Jared Atkinson (@cobbler) at SpecterOps

    This function takes a string input and converts it to PascalCase format, where the first letter of each word is capitalized and all words are concatenated without spaces or delimiters.

    This function is used in 1PassHound to standardize permission names when creating edges in the graph structure.

    .PARAMETER String
    The input string to be converted to PascalCase.

    .EXAMPLE
    $pascalCaseString = ConvertTo-PascalCase -String "example_string-to_convert"

    This example converts the input string "example_string-to_convert" to "ExampleStringToConvert".
    #>
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
    <#
    .SYNOPSIS
    Normalizes null values to empty strings.

    .DESCRIPTION
    Author: Jared Atkinson (@cobbler) at SpecterOps


    #>
    param($Value)
    if ($null -eq $Value) { return "" }
    return $Value
}

function Get-1PassAccount
{
    <#
    .SYNOPSIS
    Retrieves and constructs the 1PassHound node for the 1Password account.

    .DESCRIPTION
    Author: Jared Atkinson (@cobbler) at SpecterOps

    The 1Password Account node represents the overall account in 1PassHound's graph structure. This function fetches account details using the 1Password CLI and constructs a node with relevant properties.

    It is built on top of the `op account get` and `op account list` commands to gather account information.

    .EXAMPLE
    $accountNode = Get-1PassAccount

    This example retrieves the 1Password account information and returns it as a node object.
    #>
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
    <#
    .SYNOPSIS
    Retrieves and constructs 1PassHound nodes and edges for 1Password users.

    .DESCRIPTION
    Author: Jared Atkinson (@cobbler) at SpecterOps

    This function fetches user details from the 1Password account using the 1Password CLI and constructs nodes and edges representing users in 1PassHound's graph structure.

    It is built on top of the `op user list` command to gather user information.

    .EXAMPLE
    $userGraph = Get-1PassUser

    This example retrieves the list of users in the 1Password account and returns them as nodes and edges.
    #>
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
    <#
    .SYNOPSIS
    Retrieves and constructs 1PassHound nodes and edges for 1Password groups.

    .DESCRIPTION
    Author: Jared Atkinson (@cobbler) at SpecterOps

    This function fetches group details from the 1Password account using the 1Password CLI and constructs nodes and edges representing groups in 1PassHound's graph structure.

    It is built on top of the `op group list` and `op group get` commands to gather group information.

    .EXAMPLE
    $groupGraph = Get-1PassGroup

    This example retrieves the list of groups in the 1Password account and returns them as nodes and edges.
    #>
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
            
                # If the group has the MANAGE_GROUPS permission, they can add members to any USER_DEFINED group
                # This appears to be the only relevant Account-level permission
                if($perm -eq "MANAGE_GROUPS"){
                    # I realize this is not ideal, but I'm going to iterate through all of the groups again here to add those edges
                    foreach($g in (op group list --format json | ConvertFrom-Json))
                    {
                        foreach($gDetail in (op group get "$($g.id)" --format json | ConvertFrom-Json))
                        {
                            if($gDetail.type -eq "USER_DEFINED")
                            {
                                $null = $edges.Add((New-1PassHoundEdge -Kind OPAddMember -StartId $groupDetails.id -EndId $gDetail.id))
                            }
                        }
                    }
                }
            }
        }

        # Enumerate Group Members
        foreach($user in (op group user list $($groupDetails.id) --format json | ConvertFrom-Json))
        {
            $null = $edges.Add((New-1PassHoundEdge -Kind OPMemberOf -StartId $user.id -EndId $groupDetails.id))

            if($user.role -eq "MANAGER")
            {
                $null = $edges.Add((New-1PassHoundEdge -Kind OPManagerOf -StartId $user.id -EndId $groupDetails.id))
                $null = $edges.Add((New-1PassHoundEdge -Kind OPCanAddMember -StartId $user.id -EndId $gDetail.id))
            }
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
    <#
    .SYNOPSIS
    Retrieves and constructs 1PassHound nodes and edges for 1Password vaults.

    .DESCRIPTION
    Author: Jared Atkinson (@cobbler) at SpecterOps

    This function fetches vault details from the 1Password account using the 1Password CLI and constructs nodes and edges representing vaults in 1PassHound's graph structure.

    It is built on top of the `op vault list` and `op vault get` commands to gather vault information.

    .EXAMPLE
    $vaultGraph = Get-1PassVault

    This example retrieves the list of vaults in the 1Password account and returns them as nodes and edges.
    #>
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
    <#
    .SYNOPSIS
    Retrieves and constructs 1PassHound nodes and edges for 1Password items.

    .DESCRIPTION
    Author: Jared Atkinson (@cobbler) at SpecterOps

    This function fetches item details from the 1Password account using the 1Password CLI and constructs nodes and edges representing items in 1PassHound's graph structure.

    It is built on top of the `op item list` command to gather item information.

    It currently excludes items in the 'Employee' vault. This can be modified as needed, but is intended to reduce noise from personal items.

    Additionally, 1PassHound will only see the Employee vault for the user running the script.

    .EXAMPLE
    $itemGraph = Get-1PassItem

    This example retrieves the list of items in the 1Password account and returns them as nodes and edges.
    #>
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
    <#
    .SYNOPSIS
    Main function to execute 1PassHound enumeration and generate the output JSON file.

    .DESCRIPTION
    Author: Jared Atkinson (@cobbler) at SpecterOps

    This function orchestrates the enumeration of the 1Password account, users, groups, vaults, and items. It collects all nodes and edges into a single graph structure and outputs it as a JSON file.

    The output file name follows the format `1pass_<account_id>.json`.

    .EXAMPLE
    Invoke-1PassHound
    #>
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
