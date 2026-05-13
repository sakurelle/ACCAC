unit UnitDb;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, SQLDB, PQConnection;

function BuildDatabaseSetupMessage(const ADetails: string): string;
function BuildStartupErrorMessage(const ADetails: string): string;

procedure ConnectToDatabase(
  APQConnection: TPQConnection;
  ASQLTransaction: TSQLTransaction;
  ASQLQuery: TSQLQuery
);

implementation

function ResolveConfigPath: string;
var
  BaseDir: string;
  Candidates: array[0..3] of string;
  I: Integer;
  MessageText: string;
begin
  BaseDir := ExtractFilePath(ExpandFileName(ParamStr(0)));

  Candidates[0] := IncludeTrailingPathDelimiter(BaseDir) + 'accac.ini';
  Candidates[1] := IncludeTrailingPathDelimiter(BaseDir) + 'config' +
    DirectorySeparator + 'accac.ini';
  Candidates[2] := ExpandFileName(BaseDir + '..' + DirectorySeparator +
    'accac.ini');
  Candidates[3] := ExpandFileName(BaseDir + '..' + DirectorySeparator +
    'src' + DirectorySeparator + 'config' + DirectorySeparator + 'accac.ini');

  for I := Low(Candidates) to High(Candidates) do
  begin
    if FileExists(Candidates[I]) then
      Exit(Candidates[I]);
  end;

  MessageText := 'Файл конфигурации accac.ini не найден.' + LineEnding +
    'Создайте его на основе примера:' + LineEnding +
    'cp src/config/accac.example.ini accac.ini' + LineEnding +
    'Затем укажите корректные параметры подключения к PostgreSQL.' +
    LineEnding + LineEnding + 'Проверены пути:' + LineEnding;

  for I := Low(Candidates) to High(Candidates) do
    MessageText := MessageText + Candidates[I] + LineEnding;

  raise Exception.Create(TrimRight(MessageText));
end;

function BuildDatabaseSetupMessage(const ADetails: string): string;
begin
  Result := 'Не удалось получить данные из PostgreSQL.' + LineEnding +
    'Проверьте, что база ACCAC развёрнута, пользователь из accac.ini ' +
    'имеет доступ к схеме sc_accac, а миграция 008_grants.sql была ' +
    'применена.' + LineEnding + LineEnding + 'Техническая информация:' +
    LineEnding + ADetails;
end;

function BuildStartupErrorMessage(const ADetails: string): string;
begin
  if Pos('accac.ini', LowerCase(ADetails)) > 0 then
    Exit(ADetails);

  Result := BuildDatabaseSetupMessage(ADetails);
end;

procedure ConnectToDatabase(
  APQConnection: TPQConnection;
  ASQLTransaction: TSQLTransaction;
  ASQLQuery: TSQLQuery
);
var
  Ini: TIniFile;
  IniPath: string;
begin
  IniPath := ResolveConfigPath;
  Ini := TIniFile.Create(IniPath);
  try
    APQConnection.HostName :=
      Ini.ReadString('database', 'Host', 'localhost');
    APQConnection.DatabaseName :=
      Ini.ReadString('database', 'Database', 'accac');
    APQConnection.UserName :=
      Ini.ReadString('database', 'User', 'accac_user');
    APQConnection.Password :=
      Ini.ReadString('database', 'Password', 'change_me');
    APQConnection.Params.Values['port'] :=
      Ini.ReadString('database', 'Port', '5432');

    APQConnection.Transaction := ASQLTransaction;
    ASQLQuery.DataBase := APQConnection;
    ASQLQuery.Transaction := ASQLTransaction;

    APQConnection.Connected := True;

    if not ASQLTransaction.Active then
      ASQLTransaction.StartTransaction;
  finally
    Ini.Free;
  end;
end;

end.
