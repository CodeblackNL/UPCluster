
function Restart-UPClusterNode {
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Name')]
        [string[]]$Name,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Node', ValueFromPipeline = $true)]
        [UPClusterNode[]]$Node,
        [Parameter(Mandatory = $false)]
        [switch]$NoWait
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

        ForEach-Parallel -Items $nodeConnections -ArgumentList !($NoWait.IsPresent) -ScriptBlock {
            param ([bool]$Wait)

            if ($Wait) {
                Restart-Computer -ComputerName $_.ComputerName -Credential $_.Credential -Force -Wait -For WinRM
            }
            else {
                Restart-Computer -ComputerName $_.ComputerName -Credential $_.Credential -Force
            }
        }
    }
}
