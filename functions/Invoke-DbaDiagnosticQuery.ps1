function Invoke-DbaDiagnosticQuery {
    <#
    .SYNOPSIS
    Invoke-DbaDiagnosticQuery runs the scripts provided by Glenn Berry's DMV scripts on specified servers

    .DESCRIPTION
    This is the main function of the Sql Server Diagnostic Queries related functions in dbatools.
    The diagnostic queries are developed and maintained by Glenn Berry and they can be found here along with a lot of documentation:
    http://www.sqlskills.com/blogs/glenn/category/dmv-queries/

    The most recent version of the diagnostic queries are included in the dbatools module.
    But it is possible to download a newer set or a specific version to an alternative location and parse and run those scripts.
    It will run all or a selection of those scripts on one or multiple servers and return the result as a PowerShell Object

    .PARAMETER SqlInstance
    The target SQL Server. Can be either a string or SMO server

    .PARAMETER SqlCredential
    Allows alternative Windows or SQL login credentials to be used

    .PARAMETER Path
    Alternate path for the diagnostic scripts

    .PARAMETER Database
    The database(s) to process. If unspecified, all databases will be processed

    .PARAMETER ExcludeDatabase
    The database(s) to exclude

    .PARAMETER UseSelectionHelper
    Provides a gridview with all the queries to choose from and will run the selection made by the user on the Sql Server instance specified.

    .PARAMETER QueryName
    Only run specific query

    .PARAMETER InstanceOnly
    Run only instance level queries

    .PARAMETER DatabaseSpecific
    Run only database level queries

    .PARAMETER NoQueryTextColumn
    Use this switch to exclude the [Complete Query Text] column from relevant queries

    .PARAMETER NoPlanColumn
    Use this switch to exclude the [Query Plan] column from relevant queries

    .PARAMETER NoColumnParsing
    Does not parse the [Complete Query Text] and [Query Plan] columns and disregards the NoQueryTextColumn and NoColumnParsing switches

    .PARAMETER EnableException
    By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
    This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
    Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .PARAMETER Confirm
    Prompts to confirm certain actions

    .PARAMETER WhatIf
    Shows what would happen if the command would execute, but does not actually perform the command

    .PARAMETER OutputPath
    Directory to parsed diagnostict queries to. This will split them based on server, databasename, and query.

    .PARAMETER ExportQueries
    Use this switch to export the diagnostic queries to sql files. I
    nstead of running the queries, the server will be evaluated to find the appropriate queries to run based on SQL Version.
    These sql files will then be created in the OutputDirectory.



    .NOTES
    Tags: Database, DMV
    Author: André Kamman (@AndreKamman), http://clouddba.io
    Website: https://dbatools.io
    Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
    License: MIT https://opensource.org/licenses/MIT

    .LINK
    https://dbatools.io/Invoke-DbaDiagnosticQuery

    .EXAMPLE
    Invoke-DbaDiagnosticQuery -SqlInstance sql2016

    Run the selection made by the user on the Sql Server instance specified.

    .EXAMPLE
    Invoke-DbaDiagnosticQuery -SqlInstance sql2016 -UseSelectionHelper | Export-DbaDiagnosticQuery -Path C:\temp\gboutput

    Provides a gridview with all the queries to choose from and will run the selection made by the user on the SQL Server instance specified.
    Then it will export the results to Export-DbaDiagnosticQuery.

    .Example
    # Exporting Queries To SQL Files
    - Parse the appropriate diagnostic queries by connecting to server to get version matched queries
    - Instead of running the diagnostic queries, export them to SQL files

    # Export All Queries to Disk
    Invoke-DbaDiagnosticQuery -sqlinstance localhost -ExportQueries -outputpath "C:\temp\DiagnosticQueries"

    # Export Database Specific Queries for all User Dbs
    Invoke-DbaDiagnosticQuery -sqlinstance localhost -DatabaseSpecific -DatabaseName 'tempdb' -ExportQueries -outputpath "C:\temp\DiagnosticQueries"

    # Export Database Specific Queries For One Target Database
    Invoke-DbaDiagnosticQuery -sqlinstance localhost -DatabaseSpecific -DatabaseName 'tempdb' -ExportQueries -outputpath "C:\temp\DiagnosticQueries"

    # Export Database Specific Queries For One Target Database and One Specific Query
    Invoke-DbaDiagnosticQuery -sqlinstance localhost -DatabaseSpecific -DatabaseName 'tempdb' -ExportQueries -outputpath "C:\temp\DiagnosticQueries" -queryname 'Database-scoped Configurations'

    # Choose Queries To Export
    Invoke-DbaDiagnosticQuery -sqlinstance localhost -UseSelectionHelper

    This will export with SqlInstance, DatabaseName, and QueryName as appropriate based on query.

    .Example
    # Export Queries (not run) as returned object

    [System.Management.Automation.PSObject[]]$results = Invoke-DbaDiagnosticQuery -SqlInstance localhost -whatif

    Parse the appropriate diagnostic queries by connecting to server, and instead of running them, return as [pscustomobject[]] to work with further

    .Example
    # Database Specific Handling
    $results = Invoke-DbaDiagnosticQuery -SqlInstance $script:instance2 -DatabaseSpecific -queryname 'Database-scoped Configurations' -databasename $database

    Run diagnostic queries targeted at specific database, and only run database level queries against this database.

    #>

    [CmdletBinding(SupportsShouldProcess)]
    [outputtype([pscustomobject[]])]
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [Alias("ServerInstance", "SqlServer")]
        [DbaInstanceParameter[]]$SqlInstance,

        [Alias('DatabaseName')]
        [object[]]$Database,

        [object[]]$ExcludeDatabase,

        [Alias('Credential')]
        [PSCredential]$SqlCredential,
        [System.IO.FileInfo]$Path,
        [string[]]$QueryName,
        [switch]$UseSelectionHelper,
        [switch]$InstanceOnly,
        [switch]$DatabaseSpecific,
        [Switch]$NoQueryTextColumn,
        [Switch]$NoPlanColumn,
        [Switch]$NoColumnParsing,

        [string]$OutputPath,
        [switch]$ExportQueries,

        [switch][Alias('Silent')]
        [switch]$EnableException
    )

    begin {
        $ProgressId = Get-Random

        function Invoke-DiagnosticQuerySelectionHelper {
            [CmdletBinding()]
            Param (
                [parameter(Mandatory = $true)]
                $ParsedScript
            )

            $ParsedScript | Select-Object QueryNr, QueryName, DBSpecific, Description | Out-GridView -Title "Diagnostic Query Overview" -OutputMode Multiple | Sort-Object QueryNr | Select-Object -ExpandProperty QueryName

        }

        Write-Message -Level Verbose -Message "Interpreting DMV Script Collections"

        $module = Get-Module -Name dbatools
        $base = $module.ModuleBase

        if (!$Path) {
            $Path = "$base\bin\diagnosticquery"
        }

        $scriptversions = @()
        $scriptfiles = Get-ChildItem "$Path\SQLServerDiagnosticQueries_*_*.sql"

        if (!$scriptfiles) {
            Write-Message -Level Warning -Message "Diagnostic scripts not found in $Path. Using the ones within the module."

            $Path = "$base\bin\diagnosticquery"

            $scriptfiles = Get-ChildItem "$base\bin\diagnosticquery\SQLServerDiagnosticQueries_*_*.sql"
            if (!$scriptfiles) {
                Stop-Function -Message "Unable to download scripts, do you have an internet connection? $_" -ErrorRecord $_
                return
            }
        }

        [int[]]$filesort = $null

        foreach ($file in $scriptfiles) {
            $filesort += $file.BaseName.Split("_")[2]
        }

        $currentdate = $filesort | Sort-Object -Descending | Select-Object -First 1

        foreach ($file in $scriptfiles) {
            if ($file.BaseName.Split("_")[2] -eq $currentdate) {
                $parsedscript = Invoke-DbaDiagnosticQueryScriptParser -filename $file.fullname -NoQueryTextColumn:$NoQueryTextColumn -NoPlanColumn:$NoPlanColumn -NoColumnParsing:$NoColumnParsing

                $newscript = [pscustomobject]@{
                    Version = $file.Basename.Split("_")[1]
                    Script  = $parsedscript
                }
                $scriptversions += $newscript
            }
        }
    }

    process {
        if (Test-FunctionInterrupt) { return }

        foreach ($instance in $SqlInstance) {
            $counter = 0
            try {
                Write-Message -Level Verbose -Message "Connecting to $instance"
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $sqlcredential
            }
            catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            Write-Message -Level Verbose -Message "Collecting diagnostic query data from server: $instance"

            if ($server.VersionMinor -eq 50) {
                $version = "2008R2"
            }
            else {
                $version = switch ($server.VersionMajor) {
                    9 { "2005" }
                    10 { "2008" }
                    11 { "2012" }
                    12 { "2014" }
                    13 { "2016" }
                    14 { "2017" }
                }
            }

            if (!$instanceOnly) {
                if (-not $Database) {
                    $databases = (Get-DbaDatabase -SqlInstance $server -ExcludeAllSystemDb -ExcludeDatabase $ExcludeDatabase).Name
                }
                else {
                    $databases = (Get-DbaDatabase -SqlInstance $server -ExcludeAllSystemDb -Database $Database -ExcludeDatabase $ExcludeDatabase).Name
                }
            }

            $parsedscript = $scriptversions | Where-Object -Property Version -eq $version | Select-Object -ExpandProperty Script

            if ($null -eq $first) { $first = $true }
            if ($UseSelectionHelper -and $first) {
                $QueryName = Invoke-DiagnosticQuerySelectionHelper $parsedscript
                $first = $false
            }
            #since some database level queries can take longer (such as fragmentation) calculate progress with database specific queries * count of databases to run against into context
            $CountOfDatabases = ($databases).Count


            if ($QueryName.Count -ne 0) {
                #if running all queries, then calculate total to run by instance queries count + (db specific count * databases to run each against)
                $countDBSpecific = @($parsedscript | Where-Object {$_.QueryName -in $QueryName -and $_.DBSpecific -eq $true}).Count
                $countInstanceSpecific = @($parsedscript | Where-Object {$_.QueryName -in $QueryName -and $_.DBSpecific -eq $false}).Count
            }
            else {
                #if narrowing queries to database specific, calculate total to process based on instance queries count + (db specific count * databases to run each against)
                $countDBSpecific = @($parsedscript | Where-Object DBSpecific).Count
                $countInstanceSpecific = @($parsedscript | Where-Object DBSpecific -eq $false).Count

            }
            if (!$instanceonly -and !$DatabaseSpecific -and !$QueryName) {
                $scriptcount = $countInstanceSpecific + ($countDBSpecific * $CountOfDatabases )
            }
            elseif ($instanceOnly) {
                $scriptcount = $countInstanceSpecific
            }
            elseif ($DatabaseSpecific) {
                $scriptcount = $countDBSpecific * $CountOfDatabases
            }
            elseif ($QueryName.Count -ne 0) {
                $scriptcount = $countInstanceSpecific + ($countDBSpecific * $CountOfDatabases )


            }

            foreach ($scriptpart in $parsedscript) {

                if (($QueryName.Count -ne 0) -and ($QueryName -notcontains $scriptpart.QueryName)) { continue }
                if (!$scriptpart.DBSpecific -and !$DatabaseSpecific) {
                    if ($ExportQueries) {
                        $null = New-Item -Path $OutputPath -ItemType Directory -Force
                        $FileName = Remove-InvalidFileNameChars ('{0}.sql' -f $Scriptpart.QueryName)
                        $FullName = Join-Path $OutputPath $FileName
                        Write-Message -Level Verbose -Message  "Creating file: $FullName"
                        $scriptPart.Text | out-file -FilePath $FullName -Encoding UTF8 -force
                        continue
                    }

                    if ($PSCmdlet.ShouldProcess($instance, $scriptpart.QueryName)) {

                        if (-not $EnableException) {
                            $Counter++
                            Write-Progress -Id $ProgressId -ParentId 0 -Activity "Collecting diagnostic query data from $instance" -Status "Processing $counter of $scriptcount" -CurrentOperation $scriptpart.QueryName -PercentComplete (($counter / $scriptcount) * 100)
                        }

                        try {
                            $result = $server.Query($scriptpart.Text)
                            Write-Message -Level Verbose -Message "Processed $($scriptpart.QueryName) on $instance"
                            if (!$result) {
                                [pscustomobject]@{
                                    ComputerName     = $server.NetName
                                    InstanceName     = $server.ServiceName
                                    SqlInstance      = $server.DomainInstanceName
                                    Number           = $scriptpart.QueryNr
                                    Name             = $scriptpart.QueryName
                                    Description      = $scriptpart.Description
                                    DatabaseSpecific = $scriptpart.DBSpecific
                                    Database         = $null
                                    Notes            = "Empty Result for this Query"
                                    Result           = $null
                                }
                                Write-Message -Level Verbose -Message ("Empty result for Query {0} - {1} - {2}" -f $scriptpart.QueryNr, $scriptpart.QueryName, $scriptpart.Description)
                            }
                        }
                        catch {
                            Write-Message -Level Verbose -Message ('Some error has occured on Server: {0} - Script: {1}, result unavailable' -f $instance, $scriptpart.QueryName) -Target $instance -ErrorRecord $_
                        }
                        if ($result) {
                            [pscustomobject]@{
                                ComputerName     = $server.NetName
                                InstanceName     = $server.ServiceName
                                SqlInstance      = $server.DomainInstanceName
                                Number           = $scriptpart.QueryNr
                                Name             = $scriptpart.QueryName
                                Description      = $scriptpart.Description
                                DatabaseSpecific = $scriptpart.DBSpecific
                                Database         = $null
                                Notes            = $null
                                Result           = Select-DefaultView -InputObject $result -Property *
                            }

                        }
                    }
                    else {
                        # if running WhatIf, then return the queries that would be run as an object, not just whatif output

                        [pscustomobject]@{
                            ComputerName     = $server.NetName
                            InstanceName     = $server.ServiceName
                            SqlInstance      = $server.DomainInstanceName
                            Number           = $scriptpart.QueryNr
                            Name             = $scriptpart.QueryName
                            Description      = $scriptpart.Description
                            DatabaseSpecific = $scriptpart.DBSpecific
                            Database         = $null
                            Notes            = "WhatIf - Bypassed Execution"
                            Result           = $null
                        }
                    }

                }
                elseif ($scriptpart.DBSpecific -and !$instanceOnly) {

                    foreach ($currentdb in $databases) {
                        if ($ExportQueries) {
                            $null = New-Item -Path $OutputPath -ItemType Directory -Force
                            $FileName = Remove-InvalidFileNameChars ('{0}-{1}-{2}.sql' -f $server.DomainInstanceName, $currentDb, $Scriptpart.QueryName)
                            $FullName = Join-Path $OutputPath $FileName
                            Write-Message -Level Verbose -Message  "Creating file: $FullName"
                            $scriptPart.Text | out-file -FilePath $FullName -encoding UTF8 -force
                            continue
                        }


                        if ($PSCmdlet.ShouldProcess(('{0} ({1})' -f $instance, $currentDb), $scriptpart.QueryName)) {

                            if (-not $EnableException) {
                                $Counter++
                                Write-Progress -Id $ProgressId -ParentId 0 -Activity "Collecting diagnostic query data from $($currentDb) on $instance" -Status ('Processing {0} of {1}' -f $counter, $scriptcount) -CurrentOperation $scriptpart.QueryName -PercentComplete (($Counter / $scriptcount) * 100)
                            }

                            Write-Message -Level Verbose -Message "Collecting diagnostic query data from $($currentDb) for $($scriptpart.QueryName) on $instance"
                            try {
                                $result = $server.Query($scriptpart.Text, $currentDb)
                                if (!$result) {
                                    [pscustomobject]@{
                                        ComputerName     = $server.NetName
                                        InstanceName     = $server.ServiceName
                                        SqlInstance      = $server.DomainInstanceName
                                        Number           = $scriptpart.QueryNr
                                        Name             = $scriptpart.QueryName
                                        Description      = $scriptpart.Description
                                        DatabaseSpecific = $scriptpart.DBSpecific
                                        Database         = $null
                                        Notes            = "Empty Result for this Query"
                                        Result           = $null
                                    }
                                    Write-Message -Level Verbose -Message ("Empty result for Query {0} - {1} - {2}" -f $scriptpart.QueryNr, $scriptpart.QueryName, $scriptpart.Description) -Target $scriptpart -ErrorRecord $_
                                }
                            }
                            catch {
                                Write-Message -Level Verbose -Message ('Some error has occured on Server: {0} - Script: {1} - Database: {2}, result will not be saved' -f $instance, $scriptpart.QueryName, $currentDb) -Target $currentdb -ErrorRecord $_
                            }

                            [pscustomobject]@{
                                ComputerName     = $server.NetName
                                InstanceName     = $server.ServiceName
                                SqlInstance      = $server.DomainInstanceName
                                Number           = $scriptpart.QueryNr
                                Name             = $scriptpart.QueryName
                                Description      = $scriptpart.Description
                                DatabaseSpecific = $scriptpart.DBSpecific
                                Database         = $currentDb
                                Notes            = $null
                                Result           = Select-DefaultView -InputObject $result -Property *
                            }
                        }
                        else {
                            # if running WhatIf, then return the queries that would be run as an object, not just whatif output

                            [pscustomobject]@{
                                ComputerName     = $server.NetName
                                InstanceName     = $server.ServiceName
                                SqlInstance      = $server.DomainInstanceName
                                Number           = $scriptpart.QueryNr
                                Name             = $scriptpart.QueryName
                                Description      = $scriptpart.Description
                                DatabaseSpecific = $scriptpart.DBSpecific
                                Database         = $null
                                Notes            = "WhatIf - Bypassed Execution"
                                Result           = $null
                            }
                        }
                    }
                }
            }
        }
    }
    end {
        Write-Progress -Id $ProgressId -Activity 'Invoke-DbaDiagnosticQuery' -Completed
    }
}