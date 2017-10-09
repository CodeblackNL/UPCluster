
function Invoke-UPClusterNodeCommand {
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Name')]
        [string]$Name,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Node', ValueFromPipeline = $true)]
        [UPClusterNode]$Node,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Session')]
        [System.Management.Automation.Runspaces.PSSession]$Session,
        [Parameter(Mandatory = $false, ParameterSetName = 'Name')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Node')]
        [switch]$UseCredSSP,
        [Parameter(Mandatory = $false, ParameterSetName = 'Name')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Node')]
        [switch]$CacheSession,
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$ScriptBlock,
        [Parameter(Mandatory = $false)]
        [Object[]]$ArgumentList
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

    if ($($PSCmdlet.ParameterSetName) -in 'Name','Node' -and $Node) {
        $sessionName = $Node.Name
        if ($UseCredSSP.IsPresent) {
            $sessionName += ' CredSSP'
        }
        $Session = $script:sessions.$sessionName

        if (-not $Session -and $CacheSession.IsPresent) {
            $Session = New-UPClusterNodeSession -Node $Node -UseCredSSP:($UseCredSSP.IsPresent)
        }
    }

    if ($Session) {
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
    }
    elseif ($Node) {
        $connectionInfo = Get-UPClusterNodeConnectionInfo -Node $Node
        $parameters = @{
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
        }

        Invoke-Command @parameters -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
    }
}
