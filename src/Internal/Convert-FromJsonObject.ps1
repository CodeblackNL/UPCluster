#Requires -Version 5.0

function Convert-FromJsonObject {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification = 'Don''t use ShouldProcess in internal functions.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'TODO: implement ShouldProcess')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Invoke-Expression is used to convert GB-notation to an integer-value.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'The passwords are coming from a file; conversion is necessary.')]
    param (
        [PSCustomObject]$InputObject,
        [string]$TypeName,
        $RootObject,
        $ParentObject
    )

    if (-not $InputObject) {
        return
    }

    function Update-ArrayWithMember {
        param (
            [Array]$InputObject
        )

        foreach ($item in $InputObject) {
            $name = $item.Name
            if (-not $name) {
                $name = $item.ToString()
            }
            Add-Member -InputObject $InputObject -MemberType NoteProperty -Name $name -Value $item
        }
    }

    switch ($TypeName) {
        'UPCluster' {
            $cluster = New-Object UPCluster -Property @{
                Name = $InputObject.Name
                ConfigurationFilePath = $InputObject.ConfigurationFilePath
                ConfigurationName = $InputObject.ConfigurationName
                Properties = Convert-PSObjectToHashtable -InputObject $InputObject.Properties
            }

            $cluster.Roles = $InputObject.Roles | ForEach-Object { Convert-FromJsonObject -InputObject $_ -TypeName 'UPClusterRole' -RootObject $cluster -ParentObject $cluster }
            Update-ArrayWithMember -InputObject $cluster.Roles
            $cluster.Domains = $InputObject.Domains | ForEach-Object { Convert-FromJsonObject -InputObject $_ -TypeName 'UPClusterDomain' -RootObject $cluster -ParentObject $cluster }
            Update-ArrayWithMember -InputObject $cluster.Domains
            $cluster.Networks = $InputObject.Networks | ForEach-Object { Convert-FromJsonObject -InputObject $_ -TypeName 'UPClusterNetwork' -RootObject $cluster -ParentObject $cluster }
            Update-ArrayWithMember -InputObject $cluster.Networks
            if ($InputObject.Nodes) {
                $cluster.Nodes = $InputObject.Nodes | ForEach-Object { Convert-FromJsonObject -InputObject $_ -TypeName 'UPClusterNode' -RootObject $cluster -ParentObject $cluster }
            }
            elseif ($InputObject.Machines) {
                $cluster.Nodes = $InputObject.Machines | ForEach-Object { Convert-FromJsonObject -InputObject $_ -TypeName 'UPClusterNode' -RootObject $cluster -ParentObject $cluster }
            }
            Update-ArrayWithMember -InputObject $cluster.Nodes

            return $cluster
        }
        'UPClusterRole' {
            $role = New-Object UPClusterRole -Property @{
                Name = $InputObject.Name
            }

            $InputObject | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -ne 'Name' } | ForEach-Object {
                $role | Add-Member -MemberType NoteProperty -Name $_.Name -Value $InputObject.($_.Name)
            }

            return $role
        }
        'UPClusterDomain' {
            $domain = New-Object UPClusterDomain -Property @{
                Name = $InputObject.Name
                NetbiosName = $InputObject.NetbiosName
            }

            if ($InputObject.AdministratorPassword) {
                try {
                    if ($InputObject.AdministratorPasswordType -eq 'PlainText') {
                        $domain.AdministratorPassword = ConvertTo-SecureString -String $InputObject.AdministratorPassword -AsPlainText -Force
                    }
                    else {
                        $domain.AdministratorPassword = $InputObject.AdministratorPassword | ConvertTo-SecureString -ErrorAction SilentlyContinue
                    }
                }
                catch {
                    Write-Warning -Message "Error reading the domain administrator password."
                }
            }

            return $domain
        }
        'UPClusterNetwork' {
            return New-Object UPClusterNetwork -Property @{
                Name = $InputObject.Name
                AddressFamily = $InputObject.AddressFamily
                PrefixLength = $InputObject.PrefixLength
                DefaultGateway = $InputObject.DefaultGateway
                DnsServerIPAddress = $InputObject.DnsServerIPAddress
            }
        }
        'UPClusterNode' {
            $node = New-Object UPClusterNode -Property @{
                Name = $InputObject.Name
                Properties = Convert-PSObjectToHashtable -InputObject $InputObject.Properties
            }
            if ($InputObject.AdministratorPassword) {
                try {
                    if ($InputObject.AdministratorPasswordType -eq 'PlainText') {
                        $node.AdministratorPassword = ConvertTo-SecureString -String $InputObject.AdministratorPassword -AsPlainText -Force
                    }
                    else {
                        $node.AdministratorPassword = $InputObject.AdministratorPassword | ConvertTo-SecureString -ErrorAction SilentlyContinue
                    }
                }
                catch {
                    Write-Warning -Message "Error reading the machine administrator password."
                }
            }

            $node.AllProperties = @{}
            if ($RootObject) {
                foreach ($propertyKey in $RootObject.Properties.Keys) {
                    $node.AllProperties[$propertyKey] = $RootObject.Properties.$propertyKey
                }
            }
            foreach ($propertyKey in $machine.Properties.Keys) {
                $node.AllProperties[$propertyKey] = $machine.Properties.$propertyKey
            }

            if ($InputObject.Domain) {
                $node.Domain = $RootObject.Domains.($InputObject.Domain)
            }

            $node.Roles = ($InputObject.Roles | ForEach-Object {
                $roleName = $_
                if ($roleName) {
                    $role = $RootObject.Roles | Where-Object { $_.Name -eq $roleName }
                    if (-not $role) {
                        $role = New-Object UPClusterRole -Property @{
                            Name = $roleName
                        }
                    }

                    return $role
                }
            })

            $node.NetworkAdapters = $InputObject.NetworkAdapters | ForEach-Object { Convert-FromJsonObject -InputObject $_ -TypeName 'UPClusterNetworkAdapter' -RootObject $RootObject -ParentObject $cluster }
            Update-ArrayWithMember -InputObject $node.NetworkAdapters

            return $node
        }
        'UPClusterNetworkAdapter' {
            $networkAdapter = New-Object UPClusterNetworkAdapter -Property @{
                StaticMacAddress = $InputObject.StaticMacAddress
                StaticIPAddress = $InputObject.StaticIPAddress
            }

            $networkAdapter.Network = $RootObject.Networks.($InputObject.Network)

            return $networkAdapter
        }
    }
}
