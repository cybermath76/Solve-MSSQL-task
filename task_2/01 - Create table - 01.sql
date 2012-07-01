use [Lab2]
go

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[_BizTalkReceive]') AND type in (N'U'))
  DROP TABLE [dbo].[_BizTalkReceive]
go

create table [_BizTalkReceive] (
  [id]                  bigint    not null identity(1, 1)
 ,[Date]                datetime  not null default (getdate())
 ,[Processed]           bit       not null default (0)
 ,[ProcessedDate]       datetime      null
 ,[Doc]                 ntext         null
 ,[SuccessfulDocuments] int           null
 ,[ErrorsCount]         int           null
 ,[InsertedDocuments]   int           null
 ,[updatedDocuments]    int           null
 ,[Header]              nvarchar(128) null
 ,[StartProcessing]     datetime      null
 ,constraint [PK__BizTalkReceive] primary key clustered ([id])
)
go
