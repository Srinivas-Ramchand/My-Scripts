----
Select name, is_encrypted from sys.databases

--Step1:Take the full database backup of Dba
BACKUP DATABASE [dba] TO  DISK = N'D:\sqlbackups\dba.bak' WITH NOFORMAT, NOINIT,  
NAME = N'dba-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10
GO

--Step2:Create database master key
USE master;
Go
CREATE MASTER KEY 
ENCRYPTION BY PASSWORD = 'HYd@123';
GO

--Step3:Create certificate
USE master;
GO 
CREATE CERTIFICATE TDE_Certificate
       WITH SUBJECT='Certificate for TDE';
GO

--Step4:Create database encryption key
USE dba
GO
CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_256
ENCRYPTION BY SERVER CERTIFICATE TDE_Certificate;  

--Step5:Back up the certificate and the private key associated with the certificate
USE master;
GO
BACKUP CERTIFICATE [TDE_Certificate]
TO FILE = 'D:\harsha\TDE_Certificate_For_dbadatabase.cer'
WITH PRIVATE KEY (file='D:\harsha\TDE_dba_private_CertKey.pvk',
ENCRYPTION BY PASSWORD='HYd@123');

--Step6:Turn on encryption on database
ALTER DATABASE dba
SET ENCRYPTION ON

--Step8:Check encryption enabled
Select name, is_encrypted from sys.databases
Select * from sys.certificates


----------------------------------------------------------------------------Restoring TDE Ebnabled Back up to other server : ----------------------------------------------------------

Create the master key with same password (which was used on Primary server (step1))

USE master;
Go
CREATE MASTER KEY 
ENCRYPTION BY PASSWORD = 'HYd@123';
GO


Create certificate (repeat step5 with below command)

USE master;
GO
create CERTIFICATE [TDE_Certificate]
From FILE ='\\node1\LOG_SHIPPING\TDE_Certificate_For__TDE.cer'
WITH PRIVATE KEY (file='\\node1\LOG_SHIPPING\TDE_dba_private_CertKey.pvk',
DECRYPTION BY PASSWORD='HYd@123');


Restore the database to the secondary server 

---------------------------------------------------------------------------------------Roll back up steps For TDE-----------------------------------------------------------------------------------------------------

--Step1:
Use AdventureWorks2016
Go
Alter Database dba Set Encryption off 

--Step2:
Use AdventureWorks2016
go
Drop database encryption key 

--Step3:
Use Master
Go
Drop certificate TDE_Certificate

--Step4:--************Optional***********************8
Use master
Go
Drop master key 


Source - https://www.youtube.com/watch?v=dYSGWizkVy0

TDE IN ALways on - https://www.youtube.com/watch?v=reB_TStdkwU
