create function dbo.MyManualReverse (@String NVARCHAR(MAX))
returns NVARCHAR(MAX)
as 
begin 
   declare @ReversedString NVARCHAR(MAX)='';
   declare @Length INT =len(@String);

   while @Length>0
   begin 
   set @ReversedString=@ReversedString+substring(@String,@Length,1);
   set @Length=@Length-1;
end

return @ReversedString
end;

go
SELECT 
    'Hello World' AS Original,
    dbo.MyManualReverse('Hello World') AS ReversedResult;
