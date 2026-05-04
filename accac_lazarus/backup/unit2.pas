unit Unit2;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, SQLDB, PQConnection, Forms, Controls,
  Graphics, Dialogs, StdCtrls;

type
  TFormSQL = class(TForm)
    btnClose: TButton;
    btnExecute: TButton;
    Label1: TLabel;
    MemoSQL: TMemo;
    PQConnection1: TPQConnection;
    SQLQuery1: TSQLQuery;
    SQLTransaction1: TSQLTransaction;
    procedure btnCloseClick(Sender: TObject);
    procedure btnExecuteClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  end;

var
  FormSQL: TFormSQL;

implementation

uses Unit1;

{$R *.lfm}

procedure TFormSQL.FormCreate(Sender: TObject);
var
  Ini: TIniFile;
  IniPath: string;
begin
  IniPath := ExtractFilePath(ParamStr(0)) + 'accac.ini';

  if not FileExists(IniPath) then
  begin
    ShowMessage('Не найден файл настроек: ' + IniPath);
    Exit;
  end;

  Ini := TIniFile.Create(IniPath);
  try
    PQConnection1.HostName :=
      Ini.ReadString('database', 'Host', 'localhost');
    PQConnection1.DatabaseName :=
      Ini.ReadString('database', 'Database', 'db_ics_accac');
    PQConnection1.UserName :=
      Ini.ReadString('database', 'User', 'postgres');
    PQConnection1.Password :=
      Ini.ReadString('database', 'Password', '1234');
    PQConnection1.Params.Values['port'] :=
      Ini.ReadString('database', 'Port', '5433');

    PQConnection1.Connected := True;

    MemoSQL.Lines.Text :=
      'INSERT INTO sc_accac."tb_ANT" ' + LineEnding +
      '("ni_id", "ni_MDL_id", "ni_CITY_id", "ni_STAT_id", "cv_note") ' + LineEnding +
      'VALUES ' + LineEnding +
      '(3004, 201, 102, 1, ''ПС-LRPT'');' + LineEnding + LineEnding +

      'INSERT INTO sc_accac."tb_CMP" ' + LineEnding +
      '("ni_id", "ni_ANT_id", "ni_CITY_id", "ni_CTR_id", "ni_parent_id", ' + LineEnding +
      '"ni_LYT_id", "cv_type", "ni_x", "ni_y", "ni_width", "ni_height", "cv_text", "bl_visible") ' + LineEnding +
      'VALUES ' + LineEnding +
      '(14, 3004, 102, 1, 6, 1, ''rectangle_antenna'', 140, 100, 45, 80, NULL, TRUE);' + LineEnding + LineEnding +

      'INSERT INTO sc_accac."tb_CMP" ' + LineEnding +
      '("ni_id", "ni_ANT_id", "ni_CITY_id", "ni_CTR_id", "ni_parent_id", ' + LineEnding +
      '"ni_LYT_id", "cv_type", "ni_x", "ni_y", "ni_width", "ni_height", "cv_text", "bl_visible") ' + LineEnding +
      'VALUES ' + LineEnding +
      '(15, 3004, 102, 1, 14, 1, ''antenna_text'', 145, 180, 45, 15, ''ПС-LRPT'', TRUE);';
  except
    on E: Exception do
      ShowMessage('Ошибка подключения: ' + E.Message);
  end;

  Ini.Free;
end;

procedure TFormSQL.btnExecuteClick(Sender: TObject);
begin
  try
    if not PQConnection1.Connected then
    begin
      ShowMessage('Нет подключения к БД');
      Exit;
    end;

    PQConnection1.ExecuteDirect(MemoSQL.Lines.Text);
    SQLTransaction1.Commit;
    SQLTransaction1.StartTransaction;

    ShowMessage('Все SQL-команды выполнены успешно');

    if Assigned(FormMain) then
      FormMain.Invalidate;
  except
    on E: Exception do
    begin
      SQLTransaction1.Rollback;
      SQLTransaction1.StartTransaction;
      ShowMessage('Ошибка выполнения SQL: ' + E.Message);
    end;
  end;
end;

procedure TFormSQL.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
