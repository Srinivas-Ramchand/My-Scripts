/*	1. this step flushes dirty pages to disk
	it usually frees up space on tempdb data files
	can be run independently, without further shrinking data files
	if shrinking is required, proceed to next steps*/
/*	if we do not know the number of tempdb data files, proceed to step 5 
	to generate the shrink script*/
USE TEMPDB;  
GO  
CHECKPOINT;
GO

/*	2. this step attempts to shrink the data files for tempdb on SQLRPT
	if not successful, proceed to step 3*/
USE [tempdb]
GO
DBCC SHRINKFILE (N'tempdev' , 8192)
GO
DBCC SHRINKFILE (N'temp2' , 8192)
GO
DBCC SHRINKFILE (N'temp3' , 8192)
GO
DBCC SHRINKFILE (N'temp4' , 8192)
GO
DBCC SHRINKFILE (N'temp5' , 8192)
GO
DBCC SHRINKFILE (N'temp6' , 8192)
GO
DBCC SHRINKFILE (N'temp7' , 8192)
GO
DBCC SHRINKFILE (N'temp8' , 8192)
GO

/*	3. this step attempts to shrink the data files for tempdb on SQLRPT
	if not successful, proceed to step 4*/
DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;
DBCC FREEPROCCACHE WITH NO_INFOMSGS;
GO
-- repeat step 2

/*	4. this step attempts to shrink the data files for tempdb on SQLRPT
	if not successful, the only way is to restart the SQL Server service*/
DBCC FREESESSIONCACHE WITH NO_INFOMSGS;
DBCC FREESYSTEMCACHE ('ALL');
GO
-- repeat step 2

/*	5. script if we do not know the number of data files for tempdb*/
DECLARE @ScriptToExecute VARCHAR(MAX);
SET @ScriptToExecute = '';
SELECT
@ScriptToExecute = @ScriptToExecute +
'USE '+ QUOTENAME(d.name) + '; DBCC SHRINKFILE ('+ QUOTENAME(f.name) +' ,8192);'
FROM sys.master_files f
INNER JOIN sys.databases d ON d.database_id = f.database_id
WHERE d.database_id = 2
AND f.type_desc = 'ROWS'
PRINT (@ScriptToExecute) -- REPLACE WITH EXEC(@ScriptToExecute) for execution



