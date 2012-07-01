use [Lab1]
go

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Lab1]') AND type in (N'P', N'PC'))
  DROP PROCEDURE [dbo].[sp_Lab1]
go

create procedure [dbo].[sp_Lab1] (
  @X int
 ,@datefrom datetime
 ,@dateto datetime
)
as

set nocount on;

-- Проверяем входные параметры

if @X is null or @X <= 0
begin
  raiserror('Неверное значение параметра @X', 16, 1);
  return -1;
end;

-- Даты не должны содержать время

if @datefrom is null
  or datepart(hh, @datefrom) <> 0
  or datepart(mi, @datefrom) <> 0
  or datepart(ss, @datefrom) <> 0
  or datepart(ms, @datefrom) <> 0
begin
  raiserror('Неверное значение параметра @datefrom', 16, 1);
  return -1;
end;

if @dateto is null
  or datepart(hh, @dateto) <> 0
  or datepart(mi, @dateto) <> 0
  or datepart(ss, @dateto) <> 0
  or datepart(ms, @dateto) <> 0
begin
  raiserror('Неверное значение параметра @dateto', 16, 1);
  return -1;
end;

if @dateto < @datefrom
begin
  raiserror('Неверный диапазон дат', 16, 1);
  return -1;
end;

-- Определяем проекты, которые находились в статусах 2, 3, 4 в указанном диапазоне. Согласно условиям задачи,
-- статус проекта может только увеличиваться. Определяем все проекты, перешедшие во второй статус ПО @dateto, НО
-- не переходившие в пятый статус ПО @datefrom. Для каждого из найденных проектов определяем диапазон его нахождения
-- в статусах 2, 3, 4 ВНУТРИ указанного диапазона.

create table #projects (
  [prj_id] int not null primary key clustered
 ,[from] datetime not null
 ,[to] datetime not null
);

insert into #projects (
  [prj_id], [from], [to]
)
select
  ph_2.[prj_id]
 ,case when ph_2.[dt] < @datefrom
    then @datefrom
    else ph_2.[dt]
  end as [from]
 ,case
    when ph_5.[dt] is null   then @dateto -- Проект вообще не переходил в пятый статус
    when ph_5.[dt] > @dateto then @dateto -- Проект перешёл в пятый статус вне указанного диапазона
    else dateadd(day, -1, ph_5.[dt])      -- Последний день проекта в четвёртом статусе
  end as [to]
from
  [project_history] ph_2
  left outer join [project_history] ph_5 on -- Проект мог не переходить в пятый статус вообще, поэтому используем LEFT JOIN
    ph_5.[prj_id] = ph_2.[prj_id]
    and ph_5.[attrib_name] = 'status'
    and cast(ph_5.[attrib_value] as int) = 5
where
  ph_2.[attrib_name] = 'status'
  and cast(ph_2.[attrib_value] as int) = 2
  and ph_2.[dt] <= @dateto -- Включаем перешедших во второй статус в последний день диапазона
  and (
    ph_5.[dt] is null -- Проект не переходил в пятый статус
    or ph_5.[dt] > @datefrom -- Исключаем перешедших в пятый статус в первый день диапазона
  )
;
  
-- Для каждого полученного на предыдущем шаге проекта определяем всех руководителей, работавших над ним во время нахождения
-- этого проекта в нужных статусах в указанном диапазоне (то есть в диапазоне проекта, рассчитанном в предыдущем выражении).
-- Исходим из того, что для любого дня из диапазона ПРОЕКТА для него существует руководитель. Руководители могут сменяться,
-- а также возвращаться в проект. Для каждого проекта получаем код руководителя (не уникальный в случае возвращения в проект)
-- и диапазон дат (фрагмента) его работы над ним. Руководитель должен начать работать над проектом ДО последней даты диапазона
-- проекта включительно И не должен кончить над ним работать ДО первой даты диапазона проекта.

create table #bosses (
  [prj_id] int not null
 ,[person_id] int not null
 ,[from] datetime not null
 ,[to] datetime not null
 ,primary key clustered ([prj_id], [from])
);

with cte as (
  select -- Работаем с хронологически пронумерованной историей смены руководителей проектов
    ph.[prj_id]
   ,cast(ph.[attrib_value] as int) as [person_id]
   ,ph.[dt]
   ,row_number() over (partition by ph.[prj_id] order by ph.[dt]) as [row_number] -- Порядковый номер руководителя
  from
    [project_history] ph
    inner join #projects p on -- Только проекты, полученные на предыдущем шаге
      p.[prj_id] = ph.[prj_id]
      and ph.[dt] <= p.[to] -- Исключаем смены руководства после последней даты диапазона проекта
  where
    ph.[attrib_name] = 'rp_per_id'
)
insert into #bosses (
  [prj_id], [person_id], [from], [to]
)
select
  p.[prj_id]
 ,h_from.[person_id]
 ,case when h_from.[dt] < p.[from] -- Руководитель был назначен ДО начала диапазона проекта
    then p.[from]
    else h_from.[dt]
  end as [from]
 ,case when h_to.[dt] is null -- Действующий руководитель на конец диапазона проекта
    then p.[to]
    else dateadd(day, -1, h_to.[dt]) -- День перед назначением следующего руководителя, всегда будет < p.[to], смотри INNER JOIN в cte
  end as [to]
from
  #projects p -- Только интересующие нас проекты
  inner join cte h_from on -- Запись о назначении руководителя (до конца диапазона проекта, смотри INNER JOIN в cte)
    h_from.[prj_id] = p.[prj_id]
  left outer join cte as h_to on -- Запись о назначении СЛЕДУЮЩЕГО руководителя. Конец работы текущего -- день перед назначением следующего.
    h_to.[prj_id] = h_from.[prj_id]
    and h_to.[row_number] = h_from.[row_number] + 1 -- Запись назначения СЛЕДУЮЩЕГО руководителя, если таковой был
where
  h_to.[dt] is null -- Последний руководитель
  or h_to.[dt] > p.[from] -- dateadd(day, -1, h_to.[dt]) >= p.[from]
;

-- На предыдущем шаге для каждого интересующего нас проекта мы получили список диапазонов непрерывной работы над ним каждого
-- из руководителей в рамках продолжительности пребывания проектов в нужных статусах в указанном диапазоне. Для каждого из 
-- диапазонов работы руководителя надо определить все расписания его работы, чтобы посчитать количество рабочих дней. История
-- назначения расписания руководителю аналогична истории изменения руководителей проекта, используем сходную технику.

create table #results (
  [prj_id] int not null
 ,[rp_per_id] int not null
 ,primary key clustered ([prj_id], [rp_per_id])
);

with cte as (
  select
    ps.[person_id]
   ,ps.[schedule_id]
   ,ps.[datefrom]
   ,row_number() over (partition by ps.[person_id] order by ps.[datefrom]) as [row_number]
  from
    (select -- Подучаем уникальный список руководителей всех интересующих нас проектов
      [person_id]
     ,max([to]) as [max_to] -- Последняя дата работы этого руководителя над интересующими нас проектами
    from
      #bosses
    group by
      [person_id]
    ) b
    inner join [person_schedule] ps on
      ps.[person_id] = b.[person_id]
      and ps.[datefrom] <= b.[max_to] -- Исключаем смены расписания после оканчания работы над проектами 
)
insert into #results (
  [prj_id], [rp_per_id]
)
select
  b.[prj_id]
 ,b.[person_id] as [rp_per_id]
from
  #bosses b
  inner join cte ps_from on
    ps_from.[person_id] = b.[person_id]
    and ps_from.[datefrom] <= b.[to] -- Расписание начало действовать до оканчания работы над проектом
  left outer join cte ps_to on
    ps_to.[person_id] = ps_from.[person_id]
    and ps_to.[row_number] = ps_from.[row_number] + 1
  inner join [worktime] wt on
    wt.[schedule_id] = ps_from.[schedule_id]
    and wt.[date] >= -- Расписание может иметь даты, в которые руководитель не работал над конкретным проектом
      case when ps_from.[datefrom] < b.[from]
        then b.[from]
        else ps_from.[datefrom]
      end
    and wt.[date] <= 
      case
        when ps_to.[datefrom] is null  then b.[to] -- Действующее расписание
        when ps_to.[datefrom] > b.[to] then b.[to]
        else dateadd(day, -1, ps_to.[datefrom]) -- Последняя дата действия расписания -- день перед вводом нового
      end
where
  wt.[workHours] = 8 -- Оставляем только рабочие дни
  and (
    ps_to.[datefrom] is null -- Действующее расписание
    or ps_to.[datefrom] > b.[from] -- dateadd(day, -1, ps_to.[datefrom]) >= b.[from]
  )
group by
  b.[prj_id]
 ,b.[person_id]
having
  count(*) >= @X -- Над проектом руководитель в общей сложности работал @X рабочих дней или более
;

-- Выводим сведения о руководителях проектов, добавляя в каждую строку коэффициент сложности

set nocount off;

select
  r.[prj_id]
 ,r.[rp_per_id]
 ,p.[difficulty]
from
  #results r
  inner join [project] p on
    p.[prj_id] = r.[prj_id]
order by
  r.[prj_id]
 ,r.[rp_per_id]
;
 
-- Возвращаем сумму коэффициентов сложности проектов

return (
  select
    sum([difficulty]) as [sum_difficulty]
  from
    [project]
  where
    [prj_id] in (
      select [prj_id] from #results
    )
);

/*

Оптимизации:

1. Наложить ограничения на поля типа datetime, чтобы компоненты времени отсутствовали (или использовать тип date в SQL Server 2008).

2. Вынести историю изменения статусов и руководителей проектов в отдельные таблицы [project_status_history] и
   [project_boss_history]. Тем самым мы избавимся от приведений типов и сможем добавить внешние ключи.
   
     create table [project_status_history] (
        [prj_id] int not null references [project]([prj_id])
       ,[status] int not null
       ,[dt] datetime not null 
       ,check (datepart(hh, [dt]) = 0 and datepart(mi, [dt]) = 0 and datepart(ss, [dt]) = 0 and datepart(ms, [dt]) <> 0)
       ,primary key nonclustered ([prj_id], [status]) -- Проект только один раз может перейти в определённый статус
     )
     
     create table [project_boss_history] (
        [prj_id] int not null references [project]([prj_id])
       ,[rp_per_id] int not null references [person]([person_id])
       ,[dt] datetime not null
       ,check (datepart(hh, [dt]) = 0 and datepart(mi, [dt]) = 0 and datepart(ss, [dt]) = 0 and datepart(ms, [dt]) <> 0)
       ,primary key clustered ([prj_id], [dt]) -- Каждый новый руководитель конкретного проекта приступает к работе в "уникальный день"
     )
   
3. Создать следующие *кластерные* индексы для того, чтобы записи физически следовали в хрогологическом порядке:
     • [project_status_history]([status], [dt]) -- ускорит получение списка проектов, находящихся в нужных статусах
       в указанном интервале (смотри insert into #projects... в процедуре)
     • [project_boss_history]([prj_id], [dt]) -- ускорит получение списка руководителей, работавших над проектами в
       интервалах нахождения их в нужных статусах (смотри insert into #bosses... в процедуре)
     • [person_schedule]([person_id], [datefrom]) -- Ускорит получение списка расписаний руководителей (смотри with cte... в процедуре)
     • [worktime]([schedule_id], [date]) -- Ускорит фильтрацию рабочих дней, а также подсчёт их количества (смитри insert into #results... в процедуре)

*/

go
