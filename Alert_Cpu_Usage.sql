USE [msdb]

GO

 
/****** Object:  Job [AOM - Alert_CPU_Usage]    Script Date: 3/11/2024 12:35:45 PM ******/

BEGIN TRANSACTION

DECLARE @ReturnCode INT

SELECT @ReturnCode = 0

/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 3/11/2024 12:35:45 PM ******/

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)

BEGIN

EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

 

END

 

DECLARE @jobId BINARY(16)

EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'AOM - Alert_CPU_Usage',

                             @enabled=1,

                             @notify_level_eventlog=0,

                             @notify_level_email=2,

                             @notify_level_netsend=0,

                             @notify_level_page=2,

                             @delete_level=0,

                             @description=N'No description available.',

                             @category_name=N'[Uncategorized (Local)]',

                             @owner_login_name=N'admsa',

                             @notify_email_operator_name=N'AOMLDS',

                             @notify_page_operator_name=N'AOMLDS', @job_id = @jobId OUTPUT

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

/****** Object:  Step [CPU Usage monitoring]    Script Date: 3/11/2024 12:35:45 PM ******/

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'CPU Usage monitoring',

                             @step_id=1,

                             @cmdexec_success_code=0,

                             @on_success_action=1,

                             @on_success_step_id=0,

                             @on_fail_action=2,

                             @on_fail_step_id=0,

                             @retry_attempts=0,

                             @retry_interval=0,

                             @os_run_priority=0, @subsystem=N'TSQL',

                             @command=N'DECLARE @ts BIGINT;

DECLARE @lastNmin TINYINT;

SET @lastNmin = 15;

SELECT @ts =(SELECT cpu_ticks/(cpu_ticks/ms_ticks) FROM sys.dm_os_sys_info);

DECLARE @CPU_Usage tinyint=0;

DECLARE @Table_CPU TABLE (DBId smallint,DB_Name varchar(50),CPU_Time BIGINT);

DECLARE @CPU_UtilHTML NVARCHAR(MAX)='''', @subject_line VARCHAR(100)='''';

 

--SET NOCOUNT ON

SET QUOTED_IDENTIFIER ON

 

 

;WITH CTE AS

(

 

SELECT TOP(@lastNmin)

                             SQLProcessUtilization AS [SQLServer_CPU_Utilization],

                             100 - SystemIdle - SQLProcessUtilization AS [Other_Process_CPU_Utilization]

FROM (

                             SELECT record.value(''(./Record/@id)[1]'',''int'')AS record_id,

              record.value(''(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]'',''int'')AS [SystemIdle],

              record.value(''(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]'',''int'')AS [SQLProcessUtilization],

                             [timestamp]     

                             FROM (

                                                          SELECT[timestamp], convert(xml, record) AS [record]            

                                                          FROM sys.dm_os_ring_buffers            

                                                          WHERE ring_buffer_type =N''RING_BUFFER_SCHEDULER_MONITOR''AND record LIKE''%%'')AS x )AS y

              --ORDER BY record_id DESC;

 

              )

 

SELECT @CPU_Usage=AVG([SQLServer_CPU_Utilization]+ [Other_Process_CPU_Utilization]) FROM CTE

 

IF @CPU_Usage >= 70

BEGIN

             

              SET @subject_line=''LSS Alert: UDGOTN0453 : High CPU utilization :''+CAST (@CPU_Usage AS varchar(10))+''%''

 

 

                             SET @CPU_UtilHTML= N''<H3>Top CPU intensive queries</H3>'' +N''<font size="7">''+ N''<table border="1">'' + N''<tr>'' + N''<th>SP Id</th>'' + N''<th>Query</th>''

                                                                                                                   + N''<th>Database Name</th>'' + N''<th>Blocked by</th>'' + N''<th>CPU Time in Secs</th>'' + N''<th>Login Time</th>''

                                                                                                                   + N''<th>Open Transactions</th>'' + N''<th>Status</th>'' + N''<th>Host Name</th>'' + N''<th>User Name</th>''

                                                                                                                   +

                    

                                                                                       + CAST((

                                                                        SELECT TOP 5 td = spid,''''

                                                                                      ,'''',td = aa.text

                                                                                      ,'''',td = DB_NAME(sp.DBID)

                                                                                      ,'''',td = sp.blocked

                                                                                      ,'''',td = cpu/1000

                                                                                      ,'''',td = login_time

                                                                                      ,'''',td = open_tran

                                                                                      ,'''',td = sp.status

                                                                                      ,'''',td = ISNULL(hostname,'' '')

                                                                                      ,'''',td = ISNULL(nt_username,'' '')

                                                         

                                                                        FROM sys.sysprocesses sp

                                                                        CROSS APPLY sys.dm_exec_sql_text(sp.sql_handle) aa

                                                                        WHERE sp.dbid>4

                                                                        ORDER BY cpu DESC

                                                                       

                                                                        FOR XML PATH(''tr'')

                                                                                      ,TYPE

                                                                        ) AS NVARCHAR(MAX)) + N''</table>'';

 

 

              EXEC msdb.dbo.sp_send_dbmail

                                           @profile_name = ''Alerts'',

              @body = @CPU_UtilHTML,

              @body_format =''HTML'',

              @recipients = '' ppdl.aom.g1.ud@hcl.com; support.aom.g1.ud@hcl.com; PPDLLSSMaintenance@udtrucks.com; PPDL LDS Application Support PPDL.LDS.AS@udtrucks.com; commercial.support@udtrucks.com '',

              @subject = @subject_line

              --@query= ''SELECT spid,Query FROM MSDB..Temp '',

              --@attach_query_result_as_file = 1,

              --@query_attachment_filename   = ''Results.csv'',

              --@query_result_separator      = '','';

 

END',

                             @database_name=N'master',

                             @flags=0

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'CPU Usage monitoring',

                             @enabled=1,

                             @freq_type=4,

                             @freq_interval=1,

                             @freq_subday_type=4,

                             @freq_subday_interval=15,

                             @freq_relative_interval=0,

                             @freq_recurrence_factor=0,

                             @active_start_date=20201125,

                             @active_end_date=99991231,

                             @active_start_time=0,

                             @active_end_time=235959,

                             @schedule_uid=N'7295ea64-5e69-4727-9199-104a03e5ccb5'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

COMMIT TRANSACTION

GOTO EndSave

QuitWithRollback:

    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION

EndSave:

GO