use [Lab2]
go

-- ��������� ������ � ������ ���������� ����������� �� ����� ����������.

-- ��� ������ ������� �������� ���������� � �������� ���� �������� �� �������.
-- ��� ������ ������� ������������� �������� ��������� ��������� � ��������� ���������.

if @@trancount = 0
begin
  begin transaction
  
  create table #t (
    [id] int not null
   ,[Doc] ntext null
  )
  
  insert into #t exec [dbo].[sp_GetDoc]
  
  select * from #t
end
else
begin
  declare @id int
  select @id = [id] from #t
  
  drop table #t
  
  if @id is null
    print '�������� �� ��� �������'
  else
  begin
    exec [dbo].[sp_SetProcessed] @id
    
    select * from [_BizTalkReceive] where [id] = @id
  end
    
  commit transaction
end
