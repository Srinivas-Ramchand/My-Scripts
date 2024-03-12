USE [msdb]

GO

 

/****** Object:  Job [AOM - Alert_Missing backups]    Script Date: 3/11/2024 12:37:03 PM ******/

BEGIN TRANSACTION

DECLARE @ReturnCode INT

SELECT @ReturnCode = 0

/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 3/11/2024 12:37:03 PM ******/

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)

BEGIN

EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

 

END

 

DECLARE @jobId BINARY(16)

EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'AOM - Alert_Missing backups',

                             @enabled=1,

                             @notify_level_eventlog=0,

                             @notify_level_email=0,

                             @notify_level_netsend=0,

                             @notify_level_page=0,

                             @delete_level=0,

                             @description=N'No description available.',

                             @category_name=N'[Uncategorized (Local)]',

                             @owner_login_name=N'admsa', @job_id = @jobId OUTPUT

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

/****** Object:  Step [Checking for missing backups]    Script Date: 3/11/2024 12:37:03 PM ******/

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Checking for missing backups',

                             @step_id=1,

                             @cmdexec_success_code=0,

                             @on_success_action=1,

                             @on_success_step_id=0,

                             @on_fail_action=2,

                             @on_fail_step_id=0,

                             @retry_attempts=0,

                             @retry_interval=0,

                             @os_run_priority=0, @subsystem=N'TSQL',

                             @command=N'SELECT DISTINCT

              msdb.dbo.backupset.database_name,

              MAX(msdb.dbo.backupset.backup_finish_date) ''Backup Date'',

              msdb.dbo.backupset.name AS backupset_name

INTO #BackupsInfo

FROM msdb.dbo.backupmediafamily

INNER JOIN msdb.dbo.backupset ON msdb.dbo.backupmediafamily.media_set_id = msdb.dbo.backupset.media_set_id

WHERE  msdb.dbo.backupset.database_name NOT IN (''msdb'',''model'',''master'',''UD_DBA_MAINTENANCE'')

GROUP BY database_name,msdb.dbo.backupset.name

ORDER BY database_name

 

SELECT * INTO #MissingBackups

FROM  #BackupsInfo

WHERE ((backupset_name=''full'' AND (CONVERT(datetime, [Backup Date], 102) <= GETDATE() - 8) )

              OR  (backupset_name=''difffull''            AND (CONVERT(datetime, [Backup Date], 102) <= GETDATE() - 2) )

              OR (DATEDIFF(hh,[Backup Date],GETDATE())>3             AND backupset_name=''log''))

 

--Testing the Backup Script--

--            SELECT * 

--FROM  #BackupsInfo

--WHERE ((backupset_name=''full'' AND (CONVERT(datetime, [Backup Date], 102) <= GETDATE() - 8) )

--            OR  (backupset_name=''difffull''            AND (CONVERT(datetime, [Backup Date], 102) <= GETDATE() - 2) )

--            OR (DATEDIFF(hh,[Backup Date],GETDATE())>3             AND backupset_name=''log''))

 

IF (SELECT COUNT(1) FROM #MissingBackups)>0

BEGIN

 

              DECLARE @Missing_Backups NVARCHAR(MAX)='''';

 

 

              SET @Missing_Backups = N''<H1>Missing backups</H1>'' + N''<table border="1">'' + N''<tr>'' + N''<th>Database Name</th>''

                                                                                                                                  + N''<th>Last Backup Date</th>'' + N''<th>Backup Type</th>''

                    

                                                                                                                    + CAST((

                                                                                                     SELECT td = ISNULL(database_name,'''')

                                                                                                                   ,''''

                                                                                                                   ,td = ISNULL([Backup Date],'''')

                                                                                                                   ,''''

                                                                                                                   ,td = ISNULL([backupset_name],'''')

                                                                                                                   ,''''

                                                                                                    

                                                                                                     FROM  #MissingBackups

                                                                                                     ORDER BY backupset_name DESC,database_name

                                                                                                    

                                                                                                     FOR XML PATH(''tr'')

                                                                                                                   ,TYPE

                                                                                                     ) AS NVARCHAR(MAX)) + N''</table>'';

 

 

              EXEC msdb.dbo.sp_send_dbmail

              @profile_name = ''Alerts'',

              @body = @Missing_Backups,

              @body_format =''HTML'',

              @recipients = '' ppdl.aom.g1.ud@hcl.com; support.aom.g1.ud@hcl.com; PPDLLSSMaintenance@udtrucks.com; PPDL LDS Application Support PPDL.LDS.AS@udtrucks.com; commercial.support@udtrucks.com '',

              @subject = ''LSS Alert: Missing backups alert in LSS DB'';

END

 

DROP TABLE #MissingBackups

DROP TABLE #BackupsInfo

',

                             @database_name=N'master',

                             @flags=0

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Missing backups schedule',

                             @enabled=1,

                             @freq_type=4,

                             @freq_interval=1,

                             @freq_subday_type=1,

                             @freq_subday_interval=0,

                             @freq_relative_interval=0,

                             @freq_recurrence_factor=0,

                             @active_start_date=20230413,

                             @active_end_date=99991231,

                             @active_start_time=60000,

                             @active_end_time=235959,

                             @schedule_uid=N'39d5d5e0-a310-4d88-9ae1-03626c97627d'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

COMMIT TRANSACTION

GOTO EndSave

QuitWithRollback:

    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION

EndSave:

GO

