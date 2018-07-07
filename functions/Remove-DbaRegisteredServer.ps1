﻿#ValidationTags#Messaging,FlowControl,Pipeline,CodeStyle#
function Remove-DbaRegisteredServer {
    <#
        .SYNOPSIS
            Removes registered servers found in SQL Server Central Management Server (CMS).

        .DESCRIPTION
            Removes registered servers found in SQL Server Central Management Server (CMS).

        .PARAMETER SqlInstance
            SQL Server name or SMO object representing the SQL Server to connect to.

        .PARAMETER SqlCredential
            Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

        .PARAMETER Name
            Specifies one or more names to include. Name is the visible name in SSMS CMS interface (labeled Registered Server Name)

        .PARAMETER ServerName
            Specifies one or more server names to include. Server Name is the actual instance name (labeled Server Name)

        .PARAMETER Group
            Specifies one or more groups to include from SQL Server Central Management Server.

        .PARAMETER InputObject
            Allows results from Get-DbaRegisteredServer to be piped in

        .PARAMETER WhatIf
            Shows what would happen if the command were to run. No actions are actually performed.

        .PARAMETER Confirm
            Prompts you for confirmation before executing any changing operations within the command.

        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.

            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.

            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

        .NOTES
            Author: Chrissy LeMaire (@cl)
            Tags: RegisteredServer, CMS

            Website: https://dbatools.io
            Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
            License: MIT https://opensource.org/licenses/MIT

        .LINK
            https://dbatools.io/Remove-DbaRegisteredServer

        .EXAMPLE
            Remove-DbaRegisteredServer -SqlInstance sql2012 -Group HR, Accounting

            Removes all servers from the HR and Accounting groups on sql2012

        .EXAMPLE
            Remove-DbaRegisteredServer -SqlInstance sql2012 -Group HR\Development

            Removes all servers from the HR and sub-group Development from the CMS on sql2012.

        .EXAMPLE
            Remove-DbaRegisteredServer -SqlInstance sql2012 -Confirm:$false

            Removes all registered servers on sql2012 and turns off all prompting
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [Alias("ServerInstance", "SqlServer")]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [string[]]$Name,
        [string[]]$ServerName,
        [string[]]$Group,
        [parameter(ValueFromPipeline)]
        [Microsoft.SqlServer.Management.RegisteredServers.RegisteredServer[]]$InputObject,
        [switch]$EnableException
    )

    process {
        foreach ($instance in $SqlInstance) {
            $InputObject += Get-DbaRegisteredServer -SqlInstance $instance -SqlCredential $SqlCredential -Group $Group -ExcludeGroup $ExcludeGroup -Name $Name -ServerName $ServerName
        }

        foreach ($regserver in $InputObject) {
            $server = $regserver.Parent
            if ($Pscmdlet.ShouldProcess($regserver.Parent, "Removing $regserver")) {
                $null = $regserver.Drop()
                try {
                    [pscustomobject]@{
                        ComputerName = $regserver.ComputerName
                        InstanceName = $regserver.InstanceName
                        SqlInstance  = $regserver.SqlInstance
                        Name         = $regserver.Name
                        ServerName   = $regserver.ServerName
                        Status       = "Dropped"
                    }
                }
                catch {
                    Stop-Function -Message "Failed to drop $regserver on $server" -ErrorRecord $_ -Continue
                }
            }
        }
    }
}