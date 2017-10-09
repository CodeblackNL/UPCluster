
function Update-UPCluster {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,
        [Parameter(Mandatory = $false)]
        [switch]$Publish,
        [Parameter(Mandatory = $false)]
        [switch]$Update,
        [Parameter(Mandatory = $false)]
        [switch]$Wait
    )

    if (-not $script:clusterConfiguration) {
        Write-Error "No current configuration; nothing to update."
    }

    if (-not $script:clusterConfiguration.Nodes) {
        Write-Error "Current configuration has no nodes; nothing to update."
    }

    $nodes = $script:clusterConfiguration.Nodes
    $dscPullNode = $script:clusterConfiguration.Nodes | Where-Object { $_.Roles | Where-Object { $_.Name -eq 'DscPullServer' } }

    Update-UPClusterNode -Node $nodes -DscPullNode $dscPullNode -OutputPath $OutputPath `
        -Publish:($Publish.IsPresent) `
        -Update:($Update.IsPresent) `
        -Wait:($Wait.IsPresent)
}
