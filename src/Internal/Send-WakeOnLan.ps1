<#
.SYNOPSIS
    Sends a WakeOnLan UDP package to the provided node(s).
.DESCRIPTION
    Sends a WakeOnLan UDP package to the provided node(s).

.PARAMETER Node
    The node(s) to wake up. Default is all nodes for the current location.
#>
<#function Send-WakeOnLan {
    # TODO-JS: determine what to do with ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '')]
    param (
        [AgmsNode[]]$Node = (Get-AgmsNode)
    )

    $mgmtNode = Get-AgmsManagementNode
    Write-AgmsLog -Node $mgmtNode -Message "> $($MyInvocation.InvocationName)" -Trace
    Write-AgmsLog -Node $mgmtNode -Message "> - Node: $(($Node).NodeName)" -Trace

    if (!(Test-IsAgmsManagementServer) -and !(Test-IsAgmsDevSeat)) {
        Write-AgmsLog -Node $mgmtNode -Message "Only allowed on management-server or devseat." -Fatal
    }

    ForEach-Parallel -Items $Node -ScriptBlock {
        Write-AgmsLog -Node $_ -Message "Sending WOL to $($_.NodeName)..." -Trace
            
        $broadcast = [Net.IPAddress]::Parse("255.255.255.255")
        $mac = (($($_.MACAdress).Replace(":","")).Replace("-","")).Replace(".","")
        $target = 0,2,4,6,8,10 | ForEach-Object { [convert]::ToByte($mac.substring($_,2),16) }
        $packet = (,[byte]255 * 6) + ($target * 16)
 
        $UDPclient = New-Object System.Net.Sockets.UdpClient
        $UDPclient.Connect($broadcast,9)
        [void]$UDPclient.Send($packet, 102)

        Write-AgmsLog -Node $_ -Message "WOL sent to $($_.NodeName)" -Trace
    }

    Write-AgmsLog -Node $mgmtNode -Message "> /$($MyInvocation.InvocationName)" -Trace
}
#>