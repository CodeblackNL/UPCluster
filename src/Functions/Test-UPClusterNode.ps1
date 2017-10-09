
function Test-UPClusterNode {
    [CmdletBinding(DefaultParameterSetName = 'Node')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Name')]
        [string[]]$Name,
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'Node', ValueFromPipeline = $true)]
        [UPClusterNode[]]$Node = (Get-UPClusterNode),
        [Parameter(Mandatory = $false)]
        [switch]$PassThru
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
            $nodeConnection = Get-UPClusterNodeConnectionInfo -Node $_
            $nodeConnection | Add-Member -MemberType 'NoteProperty' -Name 'Node' -Value $_ -PassThru
        }

        $activeConnections = ForEach-Parallel -Items $nodeConnections -ScriptBlock {
            $nodeConnection = $_

            try {
                #Test-Connection -ComputerName $nodeConnection.ComputerName -ErrorAction Stop | Out-Null # -Count 2 -Delay 1 
                Test-WSMan -ComputerName $nodeConnection.ComputerName -ErrorAction Stop | Out-Null
                Write-Verbose "OK: $($nodeConnection.ComputerName)"
                Write-Output $nodeConnection
            }
            catch {
                Write-Warning "NOK: $($nodeConnection.ComputerName)"
            }
        }

        if ($PassThru.IsPresent) {
            return $activeConnections.Node
        }
    }
}
