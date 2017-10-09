
function Stop-UPCluster {
    [CmdletBinding()]
    param (
    )

    $nodes = Test-UPClusterNode -Node ($script:clusterConfiguration.Nodes) -PassThru
    if ($nodes) {
        $dcNode = $nodes | Where-Object { $_.Roles | Where-Object { $_.Name -eq 'DomainController' } }
        if ($dcNode) {
            $nodes = $nodes | Where-Object { $_.Name -ne $dcNode.Name }
        }

        Stop-UPClusterNode -Node $nodes
        if ($dcNode) {
            Stop-UPClusterNode -Node $dcNode
        }
    }
}
