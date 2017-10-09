
function Enable-UPClusterNodePXE {
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
        $sessions = $nodes | ForEach-Object {
            New-UPClusterNodeSession -Node $_
        }

        foreach ($_ in $sessions) {
        #ForEach-Parallel -Items $sessions -ScriptBlock {
            $bootEntries = Invoke-Command -Session $_ -ScriptBlock {
                $process = New-Object -TypeName 'System.Diagnostics.Process'
                $process.StartInfo.Filename = 'bcdedit'
                $process.StartInfo.Arguments = '/enum all'
                $process.StartInfo.RedirectStandardOutput = $true;
                $process.StartInfo.UseShellExecute = $false
                $process.Start() | Out-Null

                $output = $process.StandardOutput.ReadToEnd()
                $process.WaitForExit()

                $bootEntries = @()
                $bootEntry = $null
                $bootEntryPropertyName = $null
                $output.Split("`n") | ForEach-Object {
                    $line = $_.Trim()

                    if (-not $bootEntry -and $line) {
                        $bootEntry = @{ Name = $line }
                    }
                    elseif ($bootEntry) {
                        if ($line -and -not $line.StartsWith('-')) {
                            if (-not $_.StartsWith(' ')) {
                                if ($line -match '^(?<Name>\w*)\W*(?<Value>.*)$') {
                                    $bootEntryPropertyName = $Matches.Name
                                    $bootEntry.$bootEntryPropertyName = $Matches.Value
                                }
                            }
                            else {
                                if ($bootEntry.$bootEntryPropertyName -is [Array]) {
                                    $bootEntry.$bootEntryPropertyName += $line
                                }
                                else {
                                    $bootEntry.$bootEntryPropertyName = @($bootEntry.$bootEntryPropertyName, $line)
                                }
                            }
                        }
                        elseif (-not $line) {
                            $bootEntries += New-Object -TypeName 'PSCustomObject' -Property $bootEntry
                            $bootEntry = $null
                        }
                    }
                }
            
                $bootEntries
            }
        
            Invoke-Command -Session $_ -ArgumentList $bootEntries -ScriptBlock {
                param ($BootEntries)

            }
        }
    }
}
