﻿#ValidationTags#Messaging,FlowControl,Pipeline,CodeStyle#
function Remove-DbaRegisteredServerGroup {
    <#
        .SYNOPSIS
            Gets list of Server Groups objects stored in SQL Server Central Management Server (CMS).

        .DESCRIPTION
            Returns an array of Server Groups found in the CMS.

        .PARAMETER SqlInstance
            SQL Server name or SMO object representing the SQL Server to connect to.

        .PARAMETER SqlCredential
            Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

        .PARAMETER Name
            Specifies one or more groups to include from SQL Server Central Management Server.

        .PARAMETER InputObject
            Allows results from Get-DbaRegisteredServerGroup to be piped in

        .PARAMETER Id
            Get group by Id(s)

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
            https://dbatools.io/Remove-DbaRegisteredServerGroup

        .EXAMPLE
            Remove-DbaRegisteredServerGroup -SqlInstance sql2012 -Group HR, Accounting

            Removes the HR and Accounting groups on sql2012

        .EXAMPLE
            Remove-DbaRegisteredServerGroup -SqlInstance sql2012 -Group HR\Development -Confirm:$false

            Removes the Development subgroup within the HR group on sql2012 and turns off all prompting

    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [Alias("ServerInstance", "SqlServer")]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [Alias("Group")]
        [string[]]$Name,
        [parameter(ValueFromPipeline)]
        [Microsoft.SqlServer.Management.RegisteredServers.ServerGroup[]]$InputObject,
        [switch]$EnableException
    )
    process {
        foreach ($instance in $SqlInstance) {
            $InputObject += Get-DbaRegisteredServerGroup -SqlInstance $instance -SqlCredential $SqlCredential -Group $Name
        }

        foreach ($regservergroup in $InputObject) {
            $parentserver = Get-RegServerParent -InputObject $regservergroup

            if ($null -eq $parentserver) {
                Stop-Function -Message "Something went wrong and it's hard to explain, sorry. This basically shouldn't happen." -Continue
            }

            if ($Pscmdlet.ShouldProcess($parentserver.DomainInstanceName, "Removing $($regservergroup.Name) CMS Group")) {
                $null = $parentserver.ServerConnection.ExecuteNonQuery($regservergroup.ScriptDrop().GetScript())
                try {
                    [pscustomobject]@{
                        ComputerName            = $parentserver.ComputerName
                        InstanceName            = $parentserver.InstanceName
                        SqlInstance             = $parentserver.SqlInstance
                        Name                    = $regservergroup.Name
                        Status                  = "Dropped"
                    }
                }
                catch {
                    Stop-Function -Message "Failed to drop $regservergroup on $parentserver" -ErrorRecord $_ -Continue
                }
            }
        }
    }
}