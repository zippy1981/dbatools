function Start-DbaAgentJob {
    <#
        .SYNOPSIS
            Starts a running SQL Server Agent Job.

        .DESCRIPTION
            This command starts a job then returns connected SMO object for SQL Agent Job information for each instance(s) of SQL Server.

        .PARAMETER SqlInstance
            SQL Server name or SMO object representing the SQL Server to connect to.

        .PARAMETER SqlCredential
            Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

        .PARAMETER Job
            The job(s) to process - this list is auto-populated from the server. If unspecified, all jobs will be processed.

        .PARAMETER ExcludeJob
            The job(s) to exclude - this list is auto-populated from the server.

        .PARAMETER AllJobs
            Retrieve all the jobs

        .PARAMETER Wait
            Wait for output until the job has started

        .PARAMETER WaitPeriod
            Wait period in seconds to use when -Wait is used

        .PARAMETER SleepPeriod
            Period in milliseconds to wait after a job has started

        .PARAMETER InputObject
            Internal parameter that enables piping

        .PARAMETER WhatIf
            If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

        .PARAMETER Confirm
            If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

        .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

        .NOTES
            Tags: Job, Agent
            Website: https://dbatools.io
            Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
            License: MIT https://opensource.org/licenses/MIT

        .LINK
            https://dbatools.io/Start-DbaAgentJob

        .EXAMPLE
            Start-DbaAgentJob -SqlInstance localhost

            Starts all running SQL Agent Jobs on the local SQL Server instance

        .EXAMPLE
            Get-DbaAgentJob -SqlInstance sql2016 -Job cdc.DBWithCDC_capture | Start-DbaAgentJob

            Starts the cdc.DBWithCDC_capture SQL Agent Job on sql2016

        .EXAMPLE
            Start-DbaAgentJob -SqlInstance sql2016 -Job cdc.DBWithCDC_capture

            Starts the cdc.DBWithCDC_capture SQL Agent Job on sql2016

        .EXAMPLE
            $servers | Find-DbaAgentJob -IsFailed | Start-DbaAgentJob

            Restarts all failed jobs on all servers in the $servers collection

        .EXAMPLE
            Start-DbaAgentJob -SqlInstance sql2016 -AllJobs

            Start all the jobs

    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = "Default")]
    param (
        [parameter(Mandatory, ParameterSetName = "Instance")]
        [Alias("ServerInstance", "SqlServer")]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [string[]]$Job,
        [string[]]$ExcludeJob,
        [parameter(Mandatory, ValueFromPipeline, ParameterSetName = "Object")]
        [Microsoft.SqlServer.Management.Smo.Agent.Job[]]$InputObject,
        [switch]$AllJobs,
        [switch]$Wait,
        [int]$WaitPeriod = 3,
        [int]$SleepPeriod = 300,
        [Alias('Silent')]
        [switch]$EnableException
    )
    process {
        if ((Test-Bound -not -ParameterName AllJobs) -and (Test-Bound -not -ParameterName Job) -and (Test-Bound -not -ParameterName InputObject)) {
            Stop-Function -Message "Please use one of the job parameters, either -Job or -AllJobs. Or pipe in a list of jobs." -Target $instance
            return
        }
        # Loop through each of the instances
        foreach ($instance in $SqlInstance) {
            try {
                Write-Message -Level Verbose -Message "Connecting to $instance."
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential
            }
            catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }
            
            # Check if all the jobs need to included
            if ($AllJobs) {
                $InputObject += $server.JobServer.Jobs
            }
            
            # If a specific job needs to be added
            if (-not $AllJobs -and $Job) {
                $InputObject = $server.JobServer.Jobs | Where-Object Name -In $Job
            }
            
            # If a job needs to be excluded
            if ($ExcludeJob) {
                $InputObject = $InputObject | Where-Object Name -NotIn $ExcludeJob
            }
        }
        
        # Loop through each of the jobs
        foreach ($currentjob in $InputObject) {
            $server = $currentjob.Parent.Parent
            $status = $currentjob.CurrentRunStatus
            
            if ($status -ne 'Idle') {
                Stop-Function -Message "$currentjob on $server is not idle ($status)" -Target $currentjob -Continue
            }
            
            If ($Pscmdlet.ShouldProcess($server, "Starting job $currentjob")) {
                # Start the job
                $lastrun = $currentjob.LastRunDate
                Write-Message -Level Verbose -Message "Last run date was $lastrun"
                $null = $currentjob.Start()
                
                # Wait and refresh so that it has a chance to change status
                Start-Sleep -Milliseconds $SleepPeriod
                $currentjob.Refresh()
                
                $i = 0
                # Check if the status is Idle
                while (($currentjob.CurrentRunStatus -eq 'Idle' -and $i++ -lt 60)) {
                    Write-Message -Level Verbose -Message "Job $($currentjob.Name) status is $($currentjob.CurrentRunStatus)"
                    Write-Message -Level Verbose -Message "Job $($currentjob.Name) last run date is $($currentjob.LastRunDate)"
                    
                    Write-Message -Level Verbose -Message "Sleeping for $SleepPeriod ms and refreshing"
                    Start-Sleep -Milliseconds $SleepPeriod
                    $currentjob.Refresh()
                    
                    # If it failed fast, speed up output
                    if ($lastrun -ne $currentjob.LastRunDate) {
                        $i = 600
                    }
                }
                
                # Wait for the job
                if (Test-Bound -ParameterName Wait) {
                    while ($currentjob.CurrentRunStatus -ne 'Idle') {
                        Write-Message -Level Output -Message "$currentjob is $($currentjob.CurrentRunStatus)"
                        Start-Sleep -Seconds $WaitPeriod
                        $currentjob.Refresh()
                    }
                    Get-DbaAgentJob -SqlInstance $server -Job $currentjob.Name
                }
                else {
                    Get-DbaAgentJob -SqlInstance $server -Job $currentjob.Name
                }
            }
        }
    }
}