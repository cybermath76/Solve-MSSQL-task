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

-- ��������� ������� ���������

if @X is null or @X <= 0
begin
  raiserror('�������� �������� ��������� @X', 16, 1);
  return -1;
end;

-- ���� �� ������ ��������� �����

if @datefrom is null
  or datepart(hh, @datefrom) <> 0
  or datepart(mi, @datefrom) <> 0
  or datepart(ss, @datefrom) <> 0
  or datepart(ms, @datefrom) <> 0
begin
  raiserror('�������� �������� ��������� @datefrom', 16, 1);
  return -1;
end;

if @dateto is null
  or datepart(hh, @dateto) <> 0
  or datepart(mi, @dateto) <> 0
  or datepart(ss, @dateto) <> 0
  or datepart(ms, @dateto) <> 0
begin
  raiserror('�������� �������� ��������� @dateto', 16, 1);
  return -1;
end;

if @dateto < @datefrom
begin
  raiserror('�������� �������� ���', 16, 1);
  return -1;
end;

-- ���������� �������, ������� ���������� � �������� 2, 3, 4 � ��������� ���������. �������� �������� ������,
-- ������ ������� ����� ������ �������������. ���������� ��� �������, ���������� �� ������ ������ �� @dateto, ��
-- �� ������������ � ����� ������ �� @datefrom. ��� ������� �� ��������� �������� ���������� �������� ��� ����������
-- � �������� 2, 3, 4 ������ ���������� ���������.

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
    when ph_5.[dt] is null   then @dateto -- ������ ������ �� ��������� � ����� ������
    when ph_5.[dt] > @dateto then @dateto -- ������ ������� � ����� ������ ��� ���������� ���������
    else dateadd(day, -1, ph_5.[dt])      -- ��������� ���� ������� � �������� �������
  end as [to]
from
  [project_history] ph_2
  left outer join [project_history] ph_5 on -- ������ ��� �� ���������� � ����� ������ ������, ������� ���������� LEFT JOIN
    ph_5.[prj_id] = ph_2.[prj_id]
    and ph_5.[attrib_name] = 'status'
    and cast(ph_5.[attrib_value] as int) = 5
where
  ph_2.[attrib_name] = 'status'
  and cast(ph_2.[attrib_value] as int) = 2
  and ph_2.[dt] <= @dateto -- �������� ���������� �� ������ ������ � ��������� ���� ���������
  and (
    ph_5.[dt] is null -- ������ �� ��������� � ����� ������
    or ph_5.[dt] > @datefrom -- ��������� ���������� � ����� ������ � ������ ���� ���������
  )
;
  
-- ��� ������� ����������� �� ���������� ���� ������� ���������� ���� �������������, ���������� ��� ��� �� ����� ����������
-- ����� ������� � ������ �������� � ��������� ��������� (�� ���� � ��������� �������, ������������ � ���������� ���������).
-- ������� �� ����, ��� ��� ������ ��� �� ��������� ������� ��� ���� ���������� ������������. ������������ ����� ���������,
-- � ����� ������������ � ������. ��� ������� ������� �������� ��� ������������ (�� ���������� � ������ ����������� � ������)
-- � �������� ��� (���������) ��� ������ ��� ���. ������������ ������ ������ �������� ��� �������� �� ��������� ���� ���������
-- ������� ������������ � �� ������ ������� ��� ��� �������� �� ������ ���� ��������� �������.

create table #bosses (
  [prj_id] int not null
 ,[person_id] int not null
 ,[from] datetime not null
 ,[to] datetime not null
 ,primary key clustered ([prj_id], [from])
);

with cte as (
  select -- �������� � �������������� ��������������� �������� ����� ������������� ��������
    ph.[prj_id]
   ,cast(ph.[attrib_value] as int) as [person_id]
   ,ph.[dt]
   ,row_number() over (partition by ph.[prj_id] order by ph.[dt]) as [row_number] -- ���������� ����� ������������
  from
    [project_history] ph
    inner join #projects p on -- ������ �������, ���������� �� ���������� ����
      p.[prj_id] = ph.[prj_id]
      and ph.[dt] <= p.[to] -- ��������� ����� ����������� ����� ��������� ���� ��������� �������
  where
    ph.[attrib_name] = 'rp_per_id'
)
insert into #bosses (
  [prj_id], [person_id], [from], [to]
)
select
  p.[prj_id]
 ,h_from.[person_id]
 ,case when h_from.[dt] < p.[from] -- ������������ ��� �������� �� ������ ��������� �������
    then p.[from]
    else h_from.[dt]
  end as [from]
 ,case when h_to.[dt] is null -- ����������� ������������ �� ����� ��������� �������
    then p.[to]
    else dateadd(day, -1, h_to.[dt]) -- ���� ����� ����������� ���������� ������������, ������ ����� < p.[to], ������ INNER JOIN � cte
  end as [to]
from
  #projects p -- ������ ������������ ��� �������
  inner join cte h_from on -- ������ � ���������� ������������ (�� ����� ��������� �������, ������ INNER JOIN � cte)
    h_from.[prj_id] = p.[prj_id]
  left outer join cte as h_to on -- ������ � ���������� ���������� ������������. ����� ������ �������� -- ���� ����� ����������� ����������.
    h_to.[prj_id] = h_from.[prj_id]
    and h_to.[row_number] = h_from.[row_number] + 1 -- ������ ���������� ���������� ������������, ���� ������� ���
where
  h_to.[dt] is null -- ��������� ������������
  or h_to.[dt] > p.[from] -- dateadd(day, -1, h_to.[dt]) >= p.[from]
;

-- �� ���������� ���� ��� ������� ������������� ��� ������� �� �������� ������ ���������� ����������� ������ ��� ��� �������
-- �� ������������� � ������ ����������������� ���������� �������� � ������ �������� � ��������� ���������. ��� ������� �� 
-- ���������� ������ ������������ ���� ���������� ��� ���������� ��� ������, ����� ��������� ���������� ������� ����. �������
-- ���������� ���������� ������������ ���������� ������� ��������� ������������� �������, ���������� ������� �������.

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
    (select -- �������� ���������� ������ ������������� ���� ������������ ��� ��������
      [person_id]
     ,max([to]) as [max_to] -- ��������� ���� ������ ����� ������������ ��� ������������� ��� ���������
    from
      #bosses
    group by
      [person_id]
    ) b
    inner join [person_schedule] ps on
      ps.[person_id] = b.[person_id]
      and ps.[datefrom] <= b.[max_to] -- ��������� ����� ���������� ����� ��������� ������ ��� ��������� 
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
    and ps_from.[datefrom] <= b.[to] -- ���������� ������ ����������� �� ��������� ������ ��� ��������
  left outer join cte ps_to on
    ps_to.[person_id] = ps_from.[person_id]
    and ps_to.[row_number] = ps_from.[row_number] + 1
  inner join [worktime] wt on
    wt.[schedule_id] = ps_from.[schedule_id]
    and wt.[date] >= -- ���������� ����� ����� ����, � ������� ������������ �� ������� ��� ���������� ��������
      case when ps_from.[datefrom] < b.[from]
        then b.[from]
        else ps_from.[datefrom]
      end
    and wt.[date] <= 
      case
        when ps_to.[datefrom] is null  then b.[to] -- ����������� ����������
        when ps_to.[datefrom] > b.[to] then b.[to]
        else dateadd(day, -1, ps_to.[datefrom]) -- ��������� ���� �������� ���������� -- ���� ����� ������ ������
      end
where
  wt.[workHours] = 8 -- ��������� ������ ������� ���
  and (
    ps_to.[datefrom] is null -- ����������� ����������
    or ps_to.[datefrom] > b.[from] -- dateadd(day, -1, ps_to.[datefrom]) >= b.[from]
  )
group by
  b.[prj_id]
 ,b.[person_id]
having
  count(*) >= @X -- ��� �������� ������������ � ����� ��������� ������� @X ������� ���� ��� �����
;

-- ������� �������� � ������������� ��������, �������� � ������ ������ ����������� ���������

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
 
-- ���������� ����� ������������� ��������� ��������

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

�����������:

1. �������� ����������� �� ���� ���� datetime, ����� ���������� ������� ������������� (��� ������������ ��� date � SQL Server 2008).

2. ������� ������� ��������� �������� � ������������� �������� � ��������� ������� [project_status_history] �
   [project_boss_history]. ��� ����� �� ��������� �� ���������� ����� � ������ �������� ������� �����.
   
     create table [project_status_history] (
        [prj_id] int not null references [project]([prj_id])
       ,[status] int not null
       ,[dt] datetime not null 
       ,check (datepart(hh, [dt]) = 0 and datepart(mi, [dt]) = 0 and datepart(ss, [dt]) = 0 and datepart(ms, [dt]) <> 0)
       ,primary key nonclustered ([prj_id], [status]) -- ������ ������ ���� ��� ����� ������� � ����������� ������
     )
     
     create table [project_boss_history] (
        [prj_id] int not null references [project]([prj_id])
       ,[rp_per_id] int not null references [person]([person_id])
       ,[dt] datetime not null
       ,check (datepart(hh, [dt]) = 0 and datepart(mi, [dt]) = 0 and datepart(ss, [dt]) = 0 and datepart(ms, [dt]) <> 0)
       ,primary key clustered ([prj_id], [dt]) -- ������ ����� ������������ ����������� ������� ���������� � ������ � "���������� ����"
     )
   
3. ������� ��������� *����������* ������� ��� ����, ����� ������ ��������� ��������� � ��������������� �������:
     � [project_status_history]([status], [dt]) -- ������� ��������� ������ ��������, ����������� � ������ ��������
       � ��������� ��������� (������ insert into #projects... � ���������)
     � [project_boss_history]([prj_id], [dt]) -- ������� ��������� ������ �������������, ���������� ��� ��������� �
       ���������� ���������� �� � ������ �������� (������ insert into #bosses... � ���������)
     � [person_schedule]([person_id], [datefrom]) -- ������� ��������� ������ ���������� ������������� (������ with cte... � ���������)
     � [worktime]([schedule_id], [date]) -- ������� ���������� ������� ����, � ����� ������� �� ���������� (������ insert into #results... � ���������)

*/

go
