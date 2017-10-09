
function Stop-UPClusterNode {
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Name')]
        [string[]]$Name,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Node', ValueFromPipeline = $true)]
        [UPClusterNode[]]$Node
    )

    if ($($PSCmdlet.ParameterSetName) -eq 'Name') {
        $nodes = Get-UPClusterNode -Name $Name
    }
    elseif ($Input) {
        $nodes = $Input
    }
    else {
        $nodes = $Node
    }

    if ($nodes) {
        $nodeConnections = $nodes | ForEach-Object {
            Get-UPClusterNodeConnectionInfo -Node $_
        }

        ForEach-Parallel -Items $nodeConnections -ScriptBlock {
            Stop-Computer -ComputerName $_.ComputerName -Credential $_.Credential -Force
        }
    }
}
