USE [msdb]

GO

 

/****** Object:  Job [Alert_Blocked_sessions]    Script Date: 3/11/2024 12:34:01 PM ******/

BEGIN TRANSACTION

DECLARE @ReturnCode INT

SELECT @ReturnCode = 0

/****** Object:  JobCategory [Maintenance]    Script Date: 3/11/2024 12:34:01 PM ******/

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Maintenance' AND category_class=1)

BEGIN

EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Maintenance'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

 

END

 

DECLARE @jobId BINARY(16)

EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Alert_Blocked_sessions',

                             @enabled=1,

                             @notify_level_eventlog=0,

                             @notify_level_email=2,

                             @notify_level_netsend=0,

                             @notify_level_page=2,

                             @delete_level=0,

                             @description=N'No description available.',

                             @category_name=N'Maintenance',

                             @owner_login_name=N'admsa',

                             @notify_email_operator_name=N'AOMLSS',

                             @notify_page_operator_name=N'AOMLSS', @job_id = @jobId OUTPUT

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

/****** Object:  Step [Block_Proc]    Script Date: 3/11/2024 12:34:01 PM ******/

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Block_Proc',

                             @step_id=1,

                             @cmdexec_success_code=0,

                             @on_success_action=1,

                             @on_success_step_id=0,

                             @on_fail_action=2,

                             @on_fail_step_id=0,

                             @retry_attempts=0,

                             @retry_interval=0,

                             @os_run_priority=0, @subsystem=N'TSQL',

                             @command=N'EXEC sp_Blocked_Sessions',

                             @database_name=N'msdb',

                             @flags=0

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Block_Schedule',

                             @enabled=1,

                             @freq_type=4,

                             @freq_interval=1,

                             @freq_subday_type=4,

                             @freq_subday_interval=10,

                             @freq_relative_interval=0,

                             @freq_recurrence_factor=0,

                             @active_start_date=20171216,

                             @active_end_date=99991231,

                             @active_start_time=0,

                             @active_end_time=235959,

                             @schedule_uid=N'162bf3b1-3759-4b52-b033-514de15923e6'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

COMMIT TRANSACTION

GOTO EndSave

QuitWithRollback:

    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION

EndSave:

GO