use [Lab1]
go

set implicit_transactions on
go

-----------------------------------------------------------------------------------------------------------------------------

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[project_history]') AND type in (N'U'))
  DROP TABLE [dbo].[project_history]
go

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[project]') AND type in (N'U'))
  DROP TABLE [dbo].[project]
go

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[worktime]') AND type in (N'U'))
  DROP TABLE [dbo].[worktime]
go

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[person_schedule]') AND type in (N'U'))
  DROP TABLE [dbo].[person_schedule]
go

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[schedule]') AND type in (N'U'))
  DROP TABLE [dbo].[schedule]
go

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[person]') AND type in (N'U'))
  DROP TABLE [dbo].[person]
go

-----------------------------------------------------------------------------------------------------------------------------

create table [dbo].[person] (
  [person_id] int not null
 ,[name] nchar(10) not null
 ,constraint [PK_Person] primary key clustered ([person_id])
)
go

create table [dbo].[schedule] (
  [schedule_id] int not null
 ,[name] nchar(10) not null
 ,constraint [PK_Schedule] primary key clustered ([schedule_id])
)
go

create table [dbo].[person_schedule] (
  [person_id] int not null
 ,[schedule_id] int not null
 ,[datefrom] datetime not null
 ,constraint [PK_Person_Schedule] primary key clustered ([person_id], [schedule_id])
 ,constraint [FK_Person_Schedule_Person] foreign key ([person_id])
    references [person]([person_id])
 ,constraint [FK_Person_Schedule_Schedule] foreign key ([schedule_id])
    references [schedule]([schedule_id])
)
go

create table [dbo].[worktime] (
  [schedule_id] int not null
 ,[date] datetime not null
 ,[workHours] int not null
 ,constraint [PK_Worktime] primary key clustered ([schedule_id], [date])
 ,constraint [FK_Worktime_Schedule] foreign key ([schedule_id])
    references [schedule]([schedule_id])
)
go

create table [dbo].[project] (
  [prj_id] int not null
 ,[rp_per_id] int not null
 ,[enterprise] nchar(10) not null
 ,[description] nchar(255) not null
 ,[status] int not null
 ,[difficulty] int not null
 ,constraint [PK_Project] primary key clustered ([prj_id])
 ,constraint [FK_Project_Person] foreign key ([rp_per_id])
    references [person]([person_id])
)
go

create table [dbo].[project_history] (
  [id] int not null
 ,[prj_id] int not null
 ,[attrib_name] nchar(50) not null
 ,[attrib_value] nchar(50) not null
 ,[dt] datetime not null
 ,constraint [PK_Project_History] primary key clustered ([id])
 ,constraint [FK_Project_History_Project] foreign key ([prj_id])
    references [project]([prj_id])
)
go

-----------------------------------------------------------------------------------------------------------------------------

exec sp_addextendedproperty 
  @name  = 'MS_Description'
 ,@value = 'Текущий руководитель проекта'
 ,@level0type = 'Schema', @level0name = 'dbo'
 ,@level1type = 'Table',  @level1name = 'project'
 ,@level2type = 'Column', @level2name = 'rp_per_id'
 
exec sp_addextendedproperty 
  @name  = 'MS_Description'
 ,@value = 'Текущий статус проекта'
 ,@level0type = 'Schema', @level0name = 'dbo'
 ,@level1type = 'Table',  @level1name = 'project'
 ,@level2type = 'Column', @level2name = 'status'
 
exec sp_addextendedproperty 
  @name  = 'MS_Description'
 ,@value = 'коэффициент сложности'
 ,@level0type = 'Schema', @level0name = 'dbo'
 ,@level1type = 'Table',  @level1name = 'project'
 ,@level2type = 'Column', @level2name = 'difficulty'
go

exec sp_addextendedproperty 
  @name  = 'MS_Description'
 ,@value = 'id проекта'
 ,@level0type = 'Schema', @level0name = 'dbo'
 ,@level1type = 'Table',  @level1name = 'project_history'
 ,@level2type = 'Column', @level2name = 'prj_id'

exec sp_addextendedproperty 
  @name  = 'MS_Description'
 ,@value = 'имя атрибута'
 ,@level0type = 'Schema', @level0name = 'dbo'
 ,@level1type = 'Table',  @level1name = 'project_history'
 ,@level2type = 'Column', @level2name = 'attrib_name'

exec sp_addextendedproperty 
  @name  = 'MS_Description'
 ,@value = 'новое значение атрибута'
 ,@level0type = 'Schema', @level0name = 'dbo'
 ,@level1type = 'Table',  @level1name = 'project_history'
 ,@level2type = 'Column', @level2name = 'attrib_value'

exec sp_addextendedproperty 
  @name  = 'MS_Description'
 ,@value = 'время изменения атрибута'
 ,@level0type = 'Schema', @level0name = 'dbo'
 ,@level1type = 'Table',  @level1name = 'project_history'
 ,@level2type = 'Column', @level2name = 'dt'
go 

-----------------------------------------------------------------------------------------------------------------------------

if @@trancount > 0
--  rollback transaction
  commit transaction
go

-----------------------------------------------------------------------------------------------------------------------------