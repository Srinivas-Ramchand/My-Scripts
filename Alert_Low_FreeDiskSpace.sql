USE [msdb]

GO

 

/****** Object:  Job [AOM - Alert_Low_FreeDiskSpace]    Script Date: 3/11/2024 12:36:34 PM ******/

BEGIN TRANSACTION

DECLARE @ReturnCode INT

SELECT @ReturnCode = 0

/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 3/11/2024 12:36:34 PM ******/

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)

BEGIN

EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

 

END

 

DECLARE @jobId BINARY(16)

EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'AOM - Alert_Low_FreeDiskSpace',

                             @enabled=1,

                             @notify_level_eventlog=0,

                             @notify_level_email=2,

                             @notify_level_netsend=0,

                             @notify_level_page=2,

                             @delete_level=0,

                             @description=N'No description available.',

                             @category_name=N'[Uncategorized (Local)]',

                             @owner_login_name=N'admsa',

                             @notify_email_operator_name=N'AOMLSS',

                             @notify_page_operator_name=N'AOMLSS', @job_id = @jobId OUTPUT

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

/****** Object:  Step [DiskSpace monitoring]    Script Date: 3/11/2024 12:36:34 PM ******/

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DiskSpace monitoring',

                             @step_id=1,

                             @cmdexec_success_code=0,

                             @on_success_action=1,

                             @on_success_step_id=0,

                             @on_fail_action=2,

                             @on_fail_step_id=0,

                             @retry_attempts=0,

                             @retry_interval=0,

                             @os_run_priority=0, @subsystem=N'TSQL',

                             @command=N'DECLARE @LogicalName varchar(25)

DECLARE @TotalSpaceInGB smallint

DECLARE @FreeSpaceInGB smallint

DECLARE @FreeSpace_inPer  tinyint

DECLARE @volume_mount_point varchar(125)

DECLARE @DiskSpaceDetails nvarchar(max)=''''

DECLARE @Row_cnt tinyint=0

 

SET NOCOUNT ON

              BEGIN

                             DECLARE @msg_body varchar(MAX)

 

                             SELECT DISTINCT dovs.logical_volume_name,

                                           CONVERT(INT,dovs.total_bytes/1048576.0)/1024 total_bytes,

                                           CONVERT(INT,dovs.available_bytes/1048576.0)/1024 available_bytes,

                             FLOOR((100/(CONVERT(INT,dovs.total_bytes/1048576.0)/1024.0))*(CONVERT(INT,dovs.available_bytes/1048576.0)/1024.0)) available_bytes_per

                             INTO #temp

                             FROM sys.master_files mf

                             CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.FILE_ID) dovs

             

                             SELECT @Row_cnt=COUNT(*) FROM #temp WHERE (available_bytes_per<20 AND logical_volume_name=''SQL1_UserDBLog'')

                                                                                                                                                                             OR (available_bytes_per<10)

 

                             IF @Row_cnt>0

                             BEGIN

 

                                           SET @DiskSpaceDetails=@DiskSpaceDetails+

                                           N''<H3>Free Disk Space Report</H3>'' + N''<table border="1">'' + N''<tr>'' + N''<th>LogicalName</th>''  +

                                                                                                      N''<th>TotalSpaceInGB</th><th>FreeSpaceInGB</th><th>FreeSpace in %</th>'' + ''</tr>'' + CAST((

                                                                                      SELECT td = ISNULL(logical_volume_name,'''')

                                                                                                     ,''''

                                                                                     

                                                                                                     ,''''

                                                                                                     ,td = ISNULL(total_bytes,0)

                                                                                                     ,''''

                                                                                                     ,td = ISNULL(CONVERT(INT,available_bytes),0)

                                                                                                     ,''''

                                                                                                     ,td = ISNULL(CONVERT(VARCHAR(25),available_bytes_per) ,'''')

                                                                                     

                                                                          FROM #temp

                                                                          WHERE (available_bytes_per<20 AND logical_volume_name=''SQL1_UserDBLog'')

                                                                                                                                                                             OR (available_bytes_per<10)

                                                         

                                                                                      FOR XML PATH(''tr'')

                                                                                                     ,TYPE

                                                                                      ) AS NVARCHAR(MAX)) + N''</table>'';

 

                            

                            

                                           EXEC msdb.dbo.sp_send_dbmail 

                                           @profile_name = ''Alerts'',  

                                           @recipients = '' ppdl.aom.g1.ud@hcl.com; support.aom.g1.ud@hcl.com; PPDLLSSMaintenance@udtrucks.com; PPDL LDS Application Support PPDL.LDS.AS@udtrucks.com; commercial.support@udtrucks.com '',

                                           @body = @DiskSpaceDetails, 

                                           @body_format =''HTML'',

                                           @subject = ''LSS Alert: Free disk space - UDGOTN0453-001'' ;

                             END

 

                             DROP TABLE #temp

              END

',

                             @database_name=N'master',

                             @flags=0

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'DiskSpace monitoring',

                             @enabled=1,

                             @freq_type=4,

                             @freq_interval=1,

                             @freq_subday_type=8,

                             @freq_subday_interval=2,

                             @freq_relative_interval=0,

                             @freq_recurrence_factor=0,

                             @active_start_date=20201125,

                             @active_end_date=99991231,

                             @active_start_time=0,

                             @active_end_time=235959,

                             @schedule_uid=N'4280344a-55a9-4934-9707-8fb6f52484f6'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

COMMIT TRANSACTION

GOTO EndSave

QuitWithRollback:

    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION

EndSave:

GO

 