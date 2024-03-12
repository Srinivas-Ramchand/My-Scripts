USE [msdb]

GO

 

/****** Object:  Job [Alert_NodeStatus]    Script Date: 3/11/2024 12:34:49 PM ******/

BEGIN TRANSACTION

DECLARE @ReturnCode INT

SELECT @ReturnCode = 0

/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 3/11/2024 12:34:49 PM ******/

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)

BEGIN

EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

 

END

 

DECLARE @jobId BINARY(16)

EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Alert_NodeStatus',

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

/****** Object:  Step [Step_NodeStatus]    Script Date: 3/11/2024 12:34:49 PM ******/

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step_NodeStatus',

                             @step_id=1,

                             @cmdexec_success_code=0,

                             @on_success_action=1,

                             @on_success_step_id=0,

                             @on_fail_action=2,

                             @on_fail_step_id=0,

                             @retry_attempts=0,

                             @retry_interval=0,

                             @os_run_priority=0, @subsystem=N'TSQL',

                             @command=N'DECLARE @ActiveNode VARCHAR(25), @PhysicalNetBios VARCHAR(25), @PrevNode VARCHAR(25),@Status VARCHAR(100)

 

SELECT @ActiveNode=NodeName, @PhysicalNetBios=CONVERT(VARCHAR(25),SERVERPROPERTY(''ComputerNamePhysicalNetBIOS''))

FROM sys.dm_os_cluster_nodes WHERE is_current_owner=1

 

SELECT @PrevNode=ActiveNode FROM MSDB..LDS_NodeInfo WHERE Sno=(SELECT MAX(Sno) FROM MSDB..LDS_NodeInfo)

 

IF @ActiveNode=@PhysicalNetBios  --This condition is just to cross check, will be removed later on

INSERT INTO MSDB..LDS_NodeInfo (ActiveNode,FailoverDate) VALUES (@ActiveNode,GETDATE())

 

IF @ActiveNode<>@PrevNode

BEGIN

           

              SET @Status=''Instance failed Over to ''+@ActiveNode

               EXEC msdb.dbo.sp_send_dbmail

                                                          @profile_name = ''Alerts'',

                             @body = @Status,

                             @body_format =''HTML'',

                             @recipients = '' ppdl.aom.g1.ud@hcl.com; support.aom.g1.ud@hcl.com; PPDLLSSMaintenance@udtrucks.com; PPDL LDS Application Support PPDL.LDS.AS@udtrucks.com; commercial.support@udtrucks.com '',

                             @subject = ''LSS SQL Instance failover on UDGOTN0453-001'';

END',

                             @database_name=N'msdb',

                             @flags=0

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Sch_NodeStatus',

                             @enabled=1,

                             @freq_type=4,

                             @freq_interval=1,

                             @freq_subday_type=4,

                             @freq_subday_interval=10,

                             @freq_relative_interval=0,

                             @freq_recurrence_factor=0,

                             @active_start_date=20200723,

                             @active_end_date=99991231,

                             @active_start_time=0,

                             @active_end_time=235959,

                             @schedule_uid=N'c8049014-8967-4114-97f3-6d3ac3818793'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

COMMIT TRANSACTION

GOTO EndSave

QuitWithRollback:

    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION

EndSave:

GO

 