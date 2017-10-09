
function Copy-UPClusterConfiguration {
    [CmdletBinding(DefaultParameterSetName = 'Node')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Name')]
        [string[]]$Name,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Node', ValueFromPipeline = $true)]
        [UPClusterNode[]]$Node,
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = (Join-Path -Path $env:windir -ChildPath 'Temp\UPClusterConfiguration'),
        [Parameter(Mandatory = $false)]
        [string]$Destination = 'C:\_provisioning\cluster.json'
    )

    if (-not (Test-Path -Path $OutputPath -PathType Container)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    Write-Log -Scope $MyInvocation -Message "Updating cluster-configuration..."
    $filePath = Join-Path -Path $OutputPath -ChildPath 'cluster.json'
    Export-UPClusterConfiguration -OutputPath $filePath -Force

    $parameters = @{}
    if ($($PSCmdlet.ParameterSetName) -eq 'Name') {
        $parameters.Name = $Name
    }
    else {
        $parameters.Node = $Node
    }

    Copy-UPClusterNodeFile @parameters -Path $filePath -Destination $Destination -Force
}
