function Get-DbaResourceGovernorClassifierFunction {
<#
.SYNOPSIS
Gets the Resource Governor custom classifier Function

.DESCRIPTION
Gets the Resource Governor custom classifier Function which is used for customize the workload groups usage

.PARAMETER SqlInstance
The target SQL Server instance(s)

.PARAMETER SqlCredential
Allows you to login to SQL Server using alternative credentials

.PARAMETER EnableException
By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

.NOTES
Tags: Migration, ResourceGovernor
Author: Alessandro Alpi (@suxstellino), alessandroalpi.blog
Website: https://dbatools.io
Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
License: MIT https://opensource.org/licenses/MIT

.LINK
https://dbatools.io/Get-DbaResourceGovernorClassifierFunction

.EXAMPLE
Get-DbaResourceGovernorClassifierFunction -SqlInstance sql2016

Gets the classifier function object of the SqlInstance sql2016

.EXAMPLE
'Sql1','Sql2/sqlexpress' | Get-DbaResourceGovernorClassifierFunction

Gets the classifier function object on Sql1 and Sql2/sqlexpress instances

#>
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [switch]$EnableException
    )

    process {
        foreach ($instance in $SqlInstance) {
            try {
                Write-Message -Level Verbose -Message "Connecting to $instance"
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $sqlcredential -MinimumVersion 10
            }
            catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            $classifierFunction = $null

            foreach ($currentFunction in $server.Databases["master"].UserDefinedFunctions)
            {
                $fullyQualifiedFunctionName = [string]::Format("[{0}].[{1}]", $currentFunction.Schema, $currentFunction.Name)
                if ($fullyQualifiedFunctionName -eq $server.ResourceGovernor.ClassifierFunction)
                {
                    $classifierFunction = $currentFunction
                }
            }

            if ($classifierFunction) {
                Add-Member -Force -InputObject $classifierFunction -MemberType NoteProperty -Name ComputerName -value $server.NetName
                Add-Member -Force -InputObject $classifierFunction -MemberType NoteProperty -Name InstanceName -value $server.ServiceName
                Add-Member -Force -InputObject $classifierFunction -MemberType NoteProperty -Name SqlInstance -value $server.DomainInstanceName
                Add-Member -Force -InputObject $classifierFunction -MemberType NoteProperty -Name Database -value 'master'
            }

            Select-DefaultView -InputObject $classifierFunction -Property ComputerName, InstanceName, SqlInstance, Database, Schema, CreateDate, DateLastModified, Name, DataType
        }
    }
}
