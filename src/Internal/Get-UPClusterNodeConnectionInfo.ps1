
function Get-UPClusterNodeConnectionInfo {
    param (
        [Parameter(Mandatory = $true)]
        [UPClusterNode]$Node
    )

    $ipAddress = $Node.NetworkAdapters.StaticIPAddress | Where-Object { $_ } | Select-Object -First 1
    if ($Node.Domain -and $Node.Domain.AdministratorPassword) {
        $credential = New-Object -TypeName 'PSCredential' -ArgumentList "$($Node.Domain.NetbiosName)\Administrator", $Node.Domain.AdministratorPassword
    }
    elseif ($Node.AdministratorPassword) {
        $credential = New-Object -TypeName 'PSCredential' -ArgumentList "$($Node.Name)\Administrator", $Node.AdministratorPassword
    }

    return New-Object -TypeName 'PSCustomObject' -Property @{ ComputerName = $ipAddress; Credential = $credential }
}