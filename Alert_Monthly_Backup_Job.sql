USE [msdb]

GO


/****** Object:  Job [AOM - Monthly_Backup_Job]    Script Date: 3/11/2024 12:37:34 PM ******/

BEGIN TRANSACTION

DECLARE @ReturnCode INT

SELECT @ReturnCode = 0

/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 3/11/2024 12:37:34 PM ******/

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)

BEGIN

EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

 

END

 

DECLARE @jobId BINARY(16)

EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'AOM - Monthly_Backup_Job',

                             @enabled=1,

                             @notify_level_eventlog=0,

                             @notify_level_email=2,

                             @notify_level_netsend=0,

                             @notify_level_page=0,

                             @delete_level=0,

                             @description=N'No description available.',

                             @category_name=N'[Uncategorized (Local)]',

                             @owner_login_name=N'admsa',

                             @notify_email_operator_name=N'AOMLDS', @job_id = @jobId OUTPUT

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

/****** Object:  Step [Backup]    Script Date: 3/11/2024 12:37:34 PM ******/

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Backup',

                             @step_id=1,

                             @cmdexec_success_code=0,

                             @on_success_action=1,

                             @on_success_step_id=0,

                             @on_fail_action=2,

                             @on_fail_step_id=0,

                             @retry_attempts=0,

                             @retry_interval=0,

                             @os_run_priority=0, @subsystem=N'TSQL',

                             @command=N'declare @dbname nvarchar(800)

Declare @sql nvarchar (max), @date varchar(20),@BackupPathname nvarchar(1000),

@FolderPath nvarchar(100)

 

Set @date=cast(convert(varchar(8), getdate(), 112) as int)

Set @FolderPath=''\\udgotn0412\lssteam\DB_Backups\Prod\Monthly\''

 

 

DECLARE curDatabases CURSOR FOR

select name from sys.sysdatabases where name in(''LDS_G_LSSLiteral'',''LDS_G_LSSVDA'',''LDS_G_LSSCustomer'',

''LDS_G_LSSVehicleApproval'',

''LDS_G_LSSVehicleAuth'',

''LDS_G_LSSVehicleConfiguration'',

''LDS_G_LSSVehicleFI'',

''LDS_G_LSSVehicleIntegration'',

''LDS_G_LSSVehicleIntegrationTransaction'',

''LDS_G_LSSVehicleInventory'',

''LDS_G_LSSVehicleNotification'',

''LDS_G_LSSVehiclePurchaseOrder'',

''LDS_G_LSSVehicleSalesOrder'',

''LDS_G_LSSVehicleSalesOrderItemType'',

''LDS_G_LSSVehicleSalesOrderProposal'',

''LDS_G_LSSVehicleSystemManagement'')

 

OPEN curDatabases 

FETCH NEXT FROM curDatabases INTO  @dbname 

WHILE @@FETCH_STATUS = 0 

BEGIN

 

Set @BackupPathname=@FolderPath+@dbname+''_''+@date+''.bak''''''

set @sql = ''Backup Database '' +

''['' +@dbname+''] TO DISK='' + ''''''''+@BackupPathname+'' With COPY_ONLY''

 

Print @SQL

Set @dbname=(Select Upper(@dbname))

 

Print ''---FULL BACKUP COPY for ''+@dbname+'' Database ----Path-''+@BackupPathname

--Print @sql

Exec sp_executesql @sql

Print ''---BACKUP COPY ends for ''+@dbname+'' Database''

Print ''''

 

FETCH NEXT FROM curDatabases INTO  @dbname

END 

CLOSE curDatabases 

DEALLOCATE curDatabases

 

--- Backup SCRIPT ENDS

 

',

                             @database_name=N'master',

                             @flags=0

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Monthly schedule',

                             @enabled=1,

                             @freq_type=16,

                             @freq_interval=3,

                             @freq_subday_type=1,

                             @freq_subday_interval=0,

                             @freq_relative_interval=0,

                             @freq_recurrence_factor=1,

                             @active_start_date=20221121,

                             @active_end_date=99991231,

                             @active_start_time=0,

                             @active_end_time=235959,

                             @schedule_uid=N'cbe0357e-ad34-41f7-95d6-9b2b917e2623'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

COMMIT TRANSACTION

GOTO EndSave

QuitWithRollback:

    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION

EndSave:

GO