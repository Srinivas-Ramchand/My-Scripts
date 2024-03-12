USE [msdb]

GO

/****** Object:  Job [Alert_Open_Transactions]    Script Date: 3/11/2024 12:35:17 PM ******/

BEGIN TRANSACTION

DECLARE @ReturnCode INT

SELECT @ReturnCode = 0

/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 3/11/2024 12:35:17 PM ******/

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)

BEGIN

EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

 

END

 

DECLARE @jobId BINARY(16)

EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Alert_Open_Transactions',

                             @enabled=1,

                             @notify_level_eventlog=0,

                             @notify_level_email=2,

                             @notify_level_netsend=0,

                             @notify_level_page=0,

                             @delete_level=0,

                             @description=N'No description available.',

                             @category_name=N'[Uncategorized (Local)]',

                             @owner_login_name=N'admsa',

                             @notify_email_operator_name=N'AOMLSS', @job_id = @jobId OUTPUT

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

/****** Object:  Step [Step_Open_Tran]    Script Date: 3/11/2024 12:35:17 PM ******/

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step_Open_Tran',

                             @step_id=1,

                             @cmdexec_success_code=0,

                             @on_success_action=1,

                             @on_success_step_id=0,

                             @on_fail_action=2,

                             @on_fail_step_id=0,

                             @retry_attempts=0,

                             @retry_interval=0,

                             @os_run_priority=0, @subsystem=N'TSQL',

                             @command=N'

-- Checked for currenlty running queries by putting data in temp table

SELECT SP.SPID

              ,[TEXT] AS SQLcode

              ,db_name (sp.dbid) ''Database''

              ,floor(waittime / (1000 * 60)) % 60 waitmin

              ,open_tran

              ,status

              ,hostname

              ,program_name

              ,loginame

              ,login_time

INTO #temp_open_trans

FROM SYS.SYSPROCESSES SP  

CROSS APPLY SYS.DM_EXEC_SQL_TEXT(SP.[SQL_HANDLE])AS DEST

WHERE OPEN_TRAN > 1

              AND DATEDIFF(MINUTE,LOGIN_TIME,GETDATE())>10

              AND SP.SPID<>@@SPID

 

              -- If open transactions found running over 10 minutes, then send alert

IF (

        SELECT count(*)

        FROM #temp_open_trans

        ) <> 0

BEGIN

   

    DECLARE @tableHTML NVARCHAR(MAX);

 

    SET @tableHTML = N''<H1>Open Transactions</H1>'' + N''<table border="1">'' + N''<tr>'' + N''<th>SessionId</th>'' + N''<th>SQLCoded</th>'' +

                     N''<th>Database</th>'' +

                     N''<th>Waitmin</th>'' + N''<th>open_tran</th>'' +

                     N''<th>Status</th>'' + N''<th>hostname</th>'' + N''<th>program_name</th>'' +

                     N''<th>loginame</th>''  +

                     N''<th>login_time</th>''  + CAST((

                SELECT td = SPID

                    ,''''

                    ,td = SQLcode

                    ,''''

                    ,td = [Database]

                    ,''''

                    ,td = waitmin

                    ,''''

                    ,td = open_tran

                    ,''''

                   

                    ,td = status

                    ,''''

                    ,td = hostname

                    ,''''

                    ,td = program_name

                    ,''''

                    ,td = loginame

                    ,''''

                    ,td = login_time

                   

                FROM #temp_open_trans

                FOR XML PATH(''tr'')

                    ,TYPE

                ) AS NVARCHAR(MAX)) + N''</table>'';

 

                                          

EXEC msdb.dbo.sp_send_dbmail

                             @profile_name = ''Alerts'',

@body = @tableHTML,

@body_format =''HTML'',

@recipients = '' ppdl.aom.g1.ud@hcl.com; support.aom.g1.ud@hcl.com; PPDLLSSMaintenance@udtrucks.com; PPDL LDS Application Support PPDL.LDS.AS@udtrucks.com; commercial.support@udtrucks.com '',

@subject = ''LSS ALERT: Open Transactions Alerts -- UDGOTN0453\SQL1'';

 

DROP TABLE #temp_open_trans

end

GO

 

 

',

                             @database_name=N'master',

                             @flags=0

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Sch_Open_Tran',

                             @enabled=1,

                             @freq_type=4,

                             @freq_interval=1,

                             @freq_subday_type=4,

                             @freq_subday_interval=10,

                             @freq_relative_interval=0,

                             @freq_recurrence_factor=0,

                             @active_start_date=20180117,

                             @active_end_date=99991231,

                             @active_start_time=0,

                             @active_end_time=235959,

                             @schedule_uid=N'5c6d54c6-0524-4d02-b437-a7fe365d5a3c'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

COMMIT TRANSACTION

GOTO EndSave

QuitWithRollback:

    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION

EndSave:

GO