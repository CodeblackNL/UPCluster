
function Copy-UPClusterNodeFile {
    [CmdletBinding(DefaultParameterSetName = 'Node')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Name')]
        [string[]]$Name,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Node', ValueFromPipeline = $true)]
        [UPClusterNode[]]$Node,
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Destination,
        [Parameter(Mandatory = $false)]
        [switch]$Force
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
        $sessions = $nodes | Foreach-Object {
            Write-Log -Scope $MyInvocation -Message "Connecting to '$($_.Name)'..."
            New-UPClusterNodeSession -Node $_
        }

        ForEach-Parallel -Items $sessions -ArgumentList $Path, $Destination, $Force.IsPresent -ScriptBlock {
            param (
                [string]$Path,
                [string]$Destination,
                [bool]$Force
            )

            Invoke-Command -Session $_ -ArgumentList $Destination -ScriptBlock {
                param ([string]$FolderPath)

                New-Item -Path (Split-Path -Path $FolderPath -Parent) -ItemType Directory -Force | Out-Null
            }

            Copy-Item -Path $Path -Destination $Destination -ToSession $_ -Force:$Force
        }
    }
}
