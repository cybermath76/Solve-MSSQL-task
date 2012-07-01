use [Lab2]
go

-- Запускать скрипт в режиме сохранения подключения БД после выполнения.

-- Пре первом запуске начинает транзакцию и выбирает один документ из очереди.
-- При втором запуске устанавливает признаки обработки документа и фиксирует транзацию.

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
    print 'Документ не был получен'
  else
  begin
    exec [dbo].[sp_SetProcessed] @id
    
    select * from [_BizTalkReceive] where [id] = @id
  end
    
  commit transaction
end
