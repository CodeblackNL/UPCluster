[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Invoke-Expression is used to convert expressions into a value.')]

class UPClusterObject {
    [void] ReplaceExpressions([UPCluster]$Configuration) {
        $this | Get-Member -MemberType Properties | ForEach-Object {
            $value = $this.($_.Name)
            if ($value) {
                if ($value -is [string]) {
                    if ($value.Contains('$Environment')) {
                        $this.($_.Name) = Invoke-Expression -Command $value
                    }
                }
                elseif ($value -is [System.Collections.Hashtable]) {
                    $value.Keys | ForEach-Object {
                        $item = $value.$_
                        if ($item -is [UPClusterObject]) {
                            ($value.$_).ReplaceExpressions($Configuration)
                        }
                    }
                }
                elseif ($value -is [System.Collections.IEnumerable] -and $value.GetType().GetElementType().BaseType -eq [UPClusterObject]) {
                    $value | ForEach-Object { $_.ReplaceExpressions($Configuration) }
                }
                elseif ($value -is [UPClusterObject]) {
                    $value.ReplaceExpressions($Configuration)
                }
            }
        }
    }
}

class UPClusterRole : UPClusterObject {
    [string]$Name

    [string] ToString() {
        return $this.Name
    }

    [Hashtable] ToHashtable() {
        $hashtable = @{
            Name = $this.Name
        }

        foreach ($property in ($this.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' })) {
            $hashtable.($property.Name) = $property.Value
        }

        return $hashtable
    }

    [Hashtable] Export() {
        return $this.ToHashtable()
    }
}

class UPClusterDomain : UPClusterObject {
    [string]$Name
    [string]$NetbiosName
    [SecureString]$AdministratorPassword

    [string] ToString() {
        return $this.Name
    }

    [Hashtable] ToHashtable() {
        $hashtable = @{
            Name = $this.Name
            NetbiosName = $this.NetbiosName
            AdministratorPassword = $this.AdministratorPassword
        }

        #if ($this.AdministratorPassword) {
        #    $hashtable.AdministratorPassword = $this.AdministratorPassword
        #}

        return $hashtable
    }

    [Hashtable] Export() {
        $hashtable = @{
            Name = $this.Name
            NetbiosName = $this.NetbiosName
        }

        if ($this.AdministratorPassword) {
            $hashtable.AdministratorPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($this.AdministratorPassword))
        }

        return $hashtable
    }
}

class UPClusterNetwork : UPClusterObject {
    [string]$Name
    [string]$AddressFamily             # IPV4
    [int]$PrefixLength
    [string]$DefaultGateway
    [string]$DnsServerIPAddress

    [string] ToString() {
        return $this.Name
    }

    [Hashtable] ToHashtable() {
        return @{
            Name = $this.Name
            AddressFamily = $this.AddressFamily
            PrefixLength = $this.PrefixLength
            DefaultGateway = $this.DefaultGateway
            DnsServerIPAddress = $this.DnsServerIPAddress
        }
    }

    [Hashtable] Export() {
        return $this.ToHashtable()
    }
}

class UPClusterNetworkAdapter : UPClusterObject {
    [UPClusterNetwork]$Network
    [string]$StaticMacAddress
    [string]$StaticIPAddress

    [string] ToString() {
        $toString = "$($this.Network.Name)"
        if ($this.StaticIPAddress) {
            $toString += " ($($this.StaticIPAddress))"
        }
        if ($this.StaticMacAddress) {
            $toString += " [$($this.StaticMacAddress)]"
        }

        return $toString
    }

    [Hashtable] ToHashtable() {
        $hashtable = @{
            StaticMacAddress = $this.StaticMacAddress
            StaticIPAddress = $this.StaticIPAddress
        }

        if ($this.Network) {
            $hashtable.Network = $this.Network.ToHashtable()
        }

        return $hashtable
    }

    [Hashtable] Export() {
        return $this.ToHashtable()
    }
}

class UPClusterNode : UPClusterObject {
    [string]$Name
    [SecureString]$AdministratorPassword
    [Hashtable]$Properties
    [Hashtable]$AllProperties
    [UPClusterRole[]]$Roles
    [UPClusterNetworkAdapter[]]$NetworkAdapters
    [UPClusterDomain]$Domain

    [string] ToString() {
        return $this.Name
    }

    [Hashtable] ToHashtable() {
        $hashtable = @{
            Name = $this.Name
            AdministratorPassword = $this.AdministratorPassword
        }

        #if ($this.AdministratorPassword) {
        #    $hashtable.AdministratorPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($this.AdministratorPassword))
        #}

        if ($this.Properties) {
            $hashtable.Properties = $this.Properties
        }
        if ($this.AllProperties) {
            $hashtable.AllProperties = $this.AllProperties
        }

        if ($this.Roles) {
            $hashtable.Roles = @($this.Roles | ForEach-Object { $_.ToHashtable() })
        }
        if ($this.NetworkAdapters) {
            $hashtable.NetworkAdapters = @($this.NetworkAdapters | ForEach-Object { $_.ToHashtable() })
        }
        if ($this.Domain) {
            $hashtable.Domain = $this.Domain.ToHashtable()
        }

        return $hashtable
    }

    [Hashtable] Export() {
        $hashtable = @{
            Name = $this.Name
        }

        if ($this.AdministratorPassword) {
            $hashtable.AdministratorPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($this.AdministratorPassword))
        }

        if ($this.Properties) {
            $hashtable.Properties = $this.Properties
        }
        if ($this.AllProperties) {
            $hashtable.AllProperties = $this.AllProperties
        }

        if ($this.Roles) {
            $hashtable.Roles = @($this.Roles | ForEach-Object { $_.Export() })
        }
        if ($this.NetworkAdapters) {
            $hashtable.NetworkAdapters = @($this.NetworkAdapters | ForEach-Object { $_.Export() })
        }
        if ($this.Domain) {
            $hashtable.Domain = $this.Domain.Export()
        }

        return $hashtable
    }
}

class UPCluster : UPClusterObject {
    [string]$Name
    [string]$Path
    [string]$ConfigurationFilePath
    [string]$ConfigurationName
    [Hashtable]$Properties
    [UPClusterRole[]]$Roles
    [UPClusterDomain[]]$Domains
    [UPClusterNetwork[]]$Networks
    [UPClusterNode[]]$Nodes

    [string] ToString() {
        return $this.Name
    }

    [Hashtable] ToHashtable() {
        $hashtable = @{
            Name = $this.Name
        }

        if ($this.Properties) {
            $hashtable.Properties = $this.Properties
        }
        if ($this.Domains) {
            $hashtable.Domains = @($this.Domains | ForEach-Object { $_.ToHashtable() })
        }
        if ($this.Networks) {
            $hashtable.Networks = @($this.Networks | ForEach-Object { $_.ToHashtable() })
        }
        if ($this.Nodes) {
            $hashtable.Nodes = @($this.Nodes | ForEach-Object { $_.ToHashtable() })
        }

        return $hashtable
    }

    [Hashtable] Export() {
        $hashtable = @{
            Name = $this.Name
        }

        if ($this.Properties) {
            $hashtable.Properties = $this.Properties
        }
        if ($this.Domains) {
            $hashtable.Domains = @($this.Domains | ForEach-Object { $_.Export() })
        }
        if ($this.Networks) {
            $hashtable.Networks = @($this.Networks | ForEach-Object { $_.Export() })
        }
        if ($this.Nodes) {
            $hashtable.Nodes = @($this.Nodes | ForEach-Object { $_.Export() })
        }

        return $hashtable
    }
}
