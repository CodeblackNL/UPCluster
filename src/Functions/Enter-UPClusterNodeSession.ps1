function Enter-UPClusterNodeSession {
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
        $session = New-UPClusterNodeSession -Name $Name -UseCredSSP:($UseCredSSP.IsPresent)
    }
    else {
        $session = New-UPClusterNodeSession -Node $Node -UseCredSSP:($UseCredSSP.IsPresent)
    }

    if ($session) {
        Enter-PSSession -Session $session
    }
}
