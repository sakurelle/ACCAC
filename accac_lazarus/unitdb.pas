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

procedure ConnectToDatabase(
  APQConnection: TPQConnection;
  ASQLTransaction: TSQLTransaction;
  ASQLQuery: TSQLQuery
);
var
  Ini: TIniFile;
  IniPath: string;
begin
  IniPath := ExtractFilePath(ParamStr(0)) + 'accac.ini';

  if not FileExists(IniPath) then
    raise Exception.Create('Не найден файл настроек: ' + IniPath);

  Ini := TIniFile.Create(IniPath);
  try
    APQConnection.HostName :=
      Ini.ReadString('database', 'Host', 'localhost');
    APQConnection.DatabaseName :=
      Ini.ReadString('database', 'Database', 'db_ics_accac');
    APQConnection.UserName :=
      Ini.ReadString('database', 'User', 'postgres');
    APQConnection.Password :=
      Ini.ReadString('database', 'Password', '1234');
    APQConnection.Params.Values['port'] :=
      Ini.ReadString('database', 'Port', '5433');

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
