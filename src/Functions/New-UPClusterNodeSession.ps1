function New-UPClusterNodeSession {
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Name')]
        [string]$Name,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Node', ValueFromPipeline = $true)]
        [UPClusterNode]$Node,
        [Parameter(Mandatory = $false)]
        [switch]$UseCredSSP
    )

    if ($($PSCmdlet.ParameterSetName) -eq 'Name') {
        $nodes = Get-UPClusterNode -Name $Name
        if ($nodes -and @($nodes).Length -eq 1) {
            $Node = $nodes[0]
        }
        else {
            throw "Name '$Name' does not result in a single node."
        }
    }

    if ($Node) {
        $connectionInfo = Get-UPClusterNodeConnectionInfo -Node $Node
        if ($connectionInfo.ComputerName -and $connectionInfo.Credential) {
            $parameters = @{
                Name = "$($Node.Name) $($connectionInfo.Credential.UserName)"
                ComputerName = $connectionInfo.ComputerName
                Credential = $connectionInfo.Credential
            }
            if ($UseCredSSP) {
                # TODO: move this to Enable-UPClusterNodeSessionClient; and add PS-Remoting & CredSSP, as in SetupComplete.ps1
                Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Credssp\PolicyDefaults\AllowFreshCredentials' -Name 'WSMan' -Value 'WSMAN/*' -ErrorAction SilentlyContinue
                Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Credssp\PolicyDefaults\AllowFreshCredentialsDomain' -Name 'WSMan' -Value 'WSMAN/*' -ErrorAction SilentlyContinue
                Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Credssp\PolicyDefaults\AllowFreshCredentialsWhenNTLMOnly' -Name 'WSMan' -Value 'WSMAN/*' -ErrorAction SilentlyContinue
                Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Credssp\PolicyDefaults\AllowFreshCredentialsWhenNTLMOnlyDomain' -Name 'WSMan' -Value 'WSMAN/*' -ErrorAction SilentlyContinue

                $parameters.Authentication = 'CredSSP'
                $parameters.Name += ' CredSSP'
            }

            $session = $script:sessions.($parameters.Name)
            if (-not $session -or ($session -and $session.State -ne 'Opened')) {
                $session = Get-PSSession `
                    | Where-Object { $_.Name -eq $parameters.Name -and $_.State -eq 'Opened' -and $_.ComputerName -eq $parameters.ComputerName } `
                    | Select-Object -First 1
                if (-not $session) {
                    for ($index = 0; $index -lt 5; $index++) {
                        $session = New-PSSession @parameters -ErrorAction SilentlyContinue
                        if ($session) {
                            break
                        }
                    }
                }

                $script:sessions.($parameters.Name) = $session
            }
        }

        return $script:sessions.($parameters.Name)
    }
}
