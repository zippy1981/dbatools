function Copy-DbaResourceGovernor {
    <#
        .SYNOPSIS
            Migrates Resource Pools

        .DESCRIPTION
            By default, all non-system resource pools are migrated. If the pool already exists on the destination, it will be skipped unless -Force is used.

            The -ResourcePool parameter is auto-populated for command-line completion and can be used to copy only specific objects.

        .PARAMETER Source
            Source SQL Server. You must have sysadmin access and server version must be SQL Server version 2008 or higher.

        .PARAMETER SourceSqlCredential
            Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

        .PARAMETER Destination
            Destination SQL Server. You must have sysadmin access and the server must be SQL Server 2008 or higher.

        .PARAMETER DestinationSqlCredential
            Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

        .PARAMETER ResourcePool
            Specifies the resource pool(s) to process. Options for this list are auto-populated from the server. If unspecified, all resource pools will be processed.

        .PARAMETER ExcludeResourcePool
            Specifies the resource pool(s) to exclude. Options for this list are auto-populated from the server

        .PARAMETER WhatIf
            If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

        .PARAMETER Confirm
            If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

        .PARAMETER Force
            If this switch is enabled, the policies will be dropped and recreated on Destination.

        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

        .NOTES
            Tags: Migration, ResourceGovernor
            Author: Chrissy LeMaire (@cl), netnerds.net
            Requires: sysadmin access on SQL Servers

            Website: https://dbatools.io
            Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
            License: MIT https://opensource.org/licenses/MIT

        .LINK
            https://dbatools.io/Copy-DbaResourceGovernor

        .EXAMPLE
            Copy-DbaResourceGovernor -Source sqlserver2014a -Destination sqlcluster

            Copies all extended event policies from sqlserver2014a to sqlcluster using Windows credentials to connect to the SQL Server instances..

        .EXAMPLE
            Copy-DbaResourceGovernor -Source sqlserver2014a -Destination sqlcluster -SourceSqlCredential $cred

            Copies all extended event policies from sqlserver2014a to sqlcluster using SQL credentials to connect to sqlserver2014a and Windows credentials to connect to sqlcluster.

        .EXAMPLE
            Copy-DbaResourceGovernor -Source sqlserver2014a -Destination sqlcluster -WhatIf

            Shows what would happen if the command were executed.
    #>
    [CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldProcess = $true)]
    param (
        [parameter(Mandatory = $true)]
        [DbaInstanceParameter]$Source,
        [PSCredential]$SourceSqlCredential,
        [parameter(Mandatory = $true)]
        [DbaInstanceParameter]$Destination,
        [PSCredential]$DestinationSqlCredential,
        [object[]]$ResourcePool,
        [object[]]$ExcludeResourcePool,
        [switch]$Force,
        [Alias('Silent')]
        [switch]$EnableException
    )
    process {
        $sourceServer = Connect-SqlInstance -SqlInstance $Source -SqlCredential $SourceSqlCredential
        $destServer = Connect-SqlInstance -SqlInstance $Destination -SqlCredential $DestinationSqlCredential

        $sourceClassifierFunction = Get-DbaResourceGovernorClassifierFunction -SqlInstance $sourceServer
        $destClassifierFunction = Get-DbaResourceGovernorClassifierFunction -SqlInstance $destServer

        $copyResourceGovSetting = [pscustomobject]@{
            SourceServer       = $sourceServer.Name
            DestinationServer  = $destServer.Name
            Type               = "Resource Governor Settings"
            Name               = "All Settings"
            Status             = $null
            Notes              = $null
            DateTime           = [DbaDateTime](Get-Date)
        }

        $copyResourceGovClassifierFunc = [pscustomobject]@{
            SourceServer       = $sourceServer.Name
            DestinationServer  = $destServer.Name
            Type               = "Resource Governor Settings"
            Name               = "Classifier Function"
            Status             = $null
            Notes              = $null
            DateTime           = [DbaDateTime](Get-Date)
        }

        if ($Pscmdlet.ShouldProcess($destination, "Updating Resource Governor settings")) {
            if ($destServer.Edition -notmatch 'Enterprise' -and $destServer.Edition -notmatch 'Datacenter' -and $destServer.Edition -notmatch 'Developer') {
                Write-Message -Level Verbose -Message "The resource governor is not available in this edition of SQL Server. You can manipulate resource governor metadata but you will not be able to apply resource governor configuration. Only Enterprise edition of SQL Server supports resource governor."
            }
            else {
                try {
                    Write-Message -Level Verbose -Message "Managing classifier function."
                    if (!$sourceClassifierFunction) {
                        $copyResourceGovClassifierFunc.Status = "Skipped"
                        $copyResourceGovClassifierFunc.Notes = $null
                        $copyResourceGovClassifierFunc | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                    }
                    else {
                        $fullyQualifiedFunctionName = $sourceClassifierFunction.Schema + "." + $sourceClassifierFunction.Name

                        if (!$destClassifierFunction) {
                            $destServer = Connect-SqlInstance -SqlInstance $Destination -SqlCredential $DestinationSqlCredential
                            $destFunction = $destServer.Databases["master"].UserDefinedFunctions[$sourceClassifierFunction.Name]
                            if ($destFunction) {
                                Write-Message -Level Verbose -Message "Dropping the function with the source classifier function name."
                                $destFunction.Drop()
                            }

                            Write-Message -Level Verbose -Message "Creating function."
                            $destServer.Query($sourceClassifierFunction.Script())

                            $sql = "ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = $fullyQualifiedFunctionName);"
                            Write-Message -Level Debug -Message $sql
                            Write-Message -Level Verbose -Message "Mapping Resource Governor classifier function."
                            $destServer.Query($sql)

                            $copyResourceGovClassifierFunc.Status = "Successful"
                            $copyResourceGovClassifierFunc.Notes = "The new classifier function has been created"
                            $copyResourceGovClassifierFunc | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                        }
                        else {
                            if ($Force -eq $false) {
                                $copyResourceGovClassifierFunc.Status = "Skipped"
                                $copyResourceGovClassifierFunc.Notes = "A classifier function already exists"
                                $copyResourceGovClassifierFunc | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                            }
                            else {

                                $sql = "ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = NULL);"
                                Write-Message -Level Debug -Message $sql
                                Write-Message -Level Verbose -Message "Disabling the Resource Governor."
                                $destServer.Query($sql)

                                $sql = "ALTER RESOURCE GOVERNOR RECONFIGURE;"
                                Write-Message -Level Debug -Message $sql
                                Write-Message -Level Verbose -Message "Reconfiguring Resource Governor."
                                $destServer.Query($sql)

                                Write-Message -Level Verbose -Message "Dropping the destination classifier function."
                                $destServer = Connect-SqlInstance -SqlInstance $Destination -SqlCredential $DestinationSqlCredential
                                $destFunction = $destServer.Databases["master"].UserDefinedFunctions[$sourceClassifierFunction.Name]
                                $destClassifierFunction.Drop()

                                Write-Message -Level Verbose -Message "Re-creating the Resource Governor classifier function."
                                $destServer.Query($sourceClassifierFunction.Script())

                                $sql = "ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = $fullyQualifiedFunctionName);"
                                Write-Message -Level Debug -Message $sql
                                Write-Message -Level Verbose -Message "Mapping Resource Governor classifier function."
                                $destServer.Query($sql)

                                $copyResourceGovClassifierFunc.Status = "Successful"
                                $copyResourceGovClassifierFunc.Notes = "The old classifier function has been overwritten."
                                $copyResourceGovClassifierFunc | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                            }
                        }
                    }
                }
                catch {
                    $copyResourceGovSetting.Status = "Failed"
                    $copyResourceGovSetting.Notes = (Get-ErrorMessage -Record $_)
                    $copyResourceGovSetting | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject

                    Stop-Function -Message "Not able to update settings." -Target $destServer -ErrorRecord $_
                }
            }
        }

        # Pools
        if ($ResourcePool) {
            $pools = $sourceServer.ResourceGovernor.ResourcePools | Where-Object Name -In $ResourcePool
        }
        elseif ($ExcludeResourcePool) {
            $pool = $sourceServer.ResourceGovernor.ResourcePools | Where-Object Name -NotIn $ExcludeResourcePool
        }
        else {
            $pools = $sourceServer.ResourceGovernor.ResourcePools | Where-Object { $_.Name -notin "internal", "default" }
        }

        Write-Message -Level Verbose -Message "Migrating pools."
        foreach ($pool in $pools) {
            $poolName = $pool.Name

            $copyResourceGovPool = [pscustomobject]@{
                SourceServer       = $sourceServer.Name
                DestinationServer  = $destServer.Name
                Type               = "Resource Governor Pool"
                Name               = $poolName
                Status             = $null
                Notes              = $null
                DateTime           = [DbaDateTime](Get-Date)
            }

            if ($null -ne $destServer.ResourceGovernor.ResourcePools[$poolName]) {
                if ($force -eq $false) {
                    Write-Message -Level Verbose -Message "Pool '$poolName' was skipped because it already exists on $destination. Use -Force to drop and recreate."

                    $copyResourceGovPool.Status = "Skipped"
                    $copyResourceGovPool.Notes = "Already exists"
                    $copyResourceGovPool | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                    continue
                }
                else {
                    if ($Pscmdlet.ShouldProcess($destination, "Attempting to drop $poolName")) {
                        Write-Message -Level Verbose -Message "Pool '$poolName' exists on $destination."
                        Write-Message -Level Verbose -Message "Force specified. Dropping $poolName."

                        try {
                            $destServer = Connect-SqlInstance -SqlInstance $Destination -SqlCredential $DestinationSqlCredential
                            $destPool = $destServer.ResourceGovernor.ResourcePools[$poolName]
                            $workloadGroups = $destPool.WorkloadGroups
                            foreach ($workloadGroup in $workloadGroups) {
                                $workloadGroup.Drop()
                            }
                            $destPool.Drop()
                            $destServer.ResourceGovernor.Alter()
                        }
                        catch {
                            $copyResourceGovPool.Status = "Failed to drop from Destination"
                            $copyResourceGovPool.Notes = (Get-ErrorMessage -Record $_)
                            $copyResourceGovPool | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject

                            Stop-Function -Message "Unable to drop: $_ Moving on." -Target $destPool -ErrorRecord $_ -Continue
                        }
                    }
                }
            }

            if ($Pscmdlet.ShouldProcess($destination, "Migrating pool $poolName")) {
                try {
                    $sql = $pool.Script() | Out-String
                    Write-Message -Level Debug -Message $sql
                    Write-Message -Level Verbose -Message "Copying pool $poolName."
                    $destServer.Query($sql)

                    $copyResourceGovPool.Status = "Successful"
                    $copyResourceGovPool | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject

                    $workloadGroups = $pool.WorkloadGroups
                    foreach ($workloadGroup in $workloadGroups) {
                        $workgroupName = $workloadGroup.Name

                        $copyResourceGovWorkGroup = [pscustomobject]@{
                            SourceServer       = $sourceServer.Name
                            DestinationServer  = $destServer.Name
                            Type               = "Resource Governor Pool Workgroup"
                            Name               = $workgroupName
                            Status             = $null
                            Notes              = $null
                            DateTime           = [DbaDateTime](Get-Date)
                        }

                        $sql = $workloadGroup.Script() | Out-String
                        Write-Message -Level Debug -Message $sql
                        Write-Message -Level Verbose -Message "Copying $workgroupName."
                        $destServer.Query($sql)

                        $copyResourceGovWorkGroup.Status = "Successful"
                        $copyResourceGovWorkGroup | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                    }
                }
                catch {
                    if ($copyResourceGovWorkGroup) {
                        $copyResourceGovWorkGroup.Status = "Failed"
                        $copyResourceGovWorkGroup.Notes = (Get-ErrorMessage -Record $_)
                        $copyResourceGovWorkGroup | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                    }
                    Stop-Function -Message "Unable to migrate pool." -Target $pool -ErrorRecord $_
                }
            }
        }

        if ($Pscmdlet.ShouldProcess($destination, "Reconfiguring")) {
            if ($destServer.Edition -notmatch 'Enterprise' -and $destServer.Edition -notmatch 'Datacenter' -and $destServer.Edition -notmatch 'Developer') {
                Write-Message -Level Verbose -Message "The resource governor is not available in this edition of SQL Server. You can manipulate resource governor metadata but you will not be able to apply resource governor configuration. Only Enterprise edition of SQL Server supports resource governor."
            }
            else {

                Write-Message -Level Verbose -Message "Reconfiguring Resource Governor."
                try {
                    if (!$sourceServer.ResourceGovernor.Enabled) {
                        $sql = "ALTER RESOURCE GOVERNOR DISABLE"
                        $destServer.Query($sql)
                    }
                    else {
                        $sql = "ALTER RESOURCE GOVERNOR RECONFIGURE"
                        $destServer.Query($sql)
                    }
                } catch {
                    $altermsg = $_.Exception
                }


                $copyResourceGovReconfig = [pscustomobject]@{
                    SourceServer       = $sourceServer.Name
                    DestinationServer  = $destServer.Name
                    Type               = "Reconfigure Resource Governor"
                    Name               = "Reconfigure Resource Governor"
                    Status             = "Successful"
                    Notes              = $altermsg
                    DateTime           = [DbaDateTime](Get-Date)
                }
                $copyResourceGovReconfig | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
            }
        }
    }
    end {
        Test-DbaDeprecation -DeprecatedOn "1.0.0" -EnableException:$false -Alias Copy-SqlResourceGovernor
    }
}