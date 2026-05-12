unit UnitDb;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, SQLDB, PQConnection;

procedure ConnectToDatabase(
  APQConnection: TPQConnection;
  ASQLTransaction: TSQLTransaction;
  ASQLQuery: TSQLQuery
);

implementation

function ResolveConfigPath: string;
var
  BaseDir: string;
  Candidates: array[0..2] of string;
  I: Integer;
  MessageText: string;
begin
  BaseDir := ExtractFilePath(ExpandFileName(ParamStr(0)));

  Candidates[0] := IncludeTrailingPathDelimiter(BaseDir) + 'accac.ini';
  Candidates[1] := IncludeTrailingPathDelimiter(BaseDir) + 'config' +
    DirectorySeparator + 'accac.ini';
  Candidates[2] := ExpandFileName(BaseDir + '..' + DirectorySeparator +
    'src' + DirectorySeparator + 'config' + DirectorySeparator + 'accac.ini');

  for I := Low(Candidates) to High(Candidates) do
  begin
    if FileExists(Candidates[I]) then
      Exit(Candidates[I]);
  end;

  MessageText := 'Configuration file accac.ini not found. Checked:' + LineEnding;

  for I := Low(Candidates) to High(Candidates) do
    MessageText := MessageText + Candidates[I] + LineEnding;

  raise Exception.Create(TrimRight(MessageText));
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
