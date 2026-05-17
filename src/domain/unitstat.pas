unit UnitStat;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SQLDB, Grids, StdCtrls;

procedure SetupStatGrid(AGrid: TStringGrid);
procedure LoadStatData(AQuery: TSQLQuery; AGrid: TStringGrid);
procedure SelectStatRow(AGrid: TStringGrid; ARow: Integer; AEditName, AEditColor: TEdit);

procedure AddStat(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditName, AEditColor: TEdit
);

procedure EditStat(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditName, AEditColor: TEdit
);

procedure DeleteStat(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditName, AEditColor: TEdit
);

implementation

const
  STAT_COL_ID    = 0; // скрытая служебная колонка
  STAT_COL_NAME  = 1;
  STAT_COL_COLOR = 2;

function IsStatGridCellValid(AGrid: TStringGrid; ACol, ARow: Integer): Boolean;
begin
  Result :=
    Assigned(AGrid) and
    (ACol >= 0) and
    (ACol < AGrid.ColCount) and
    (ARow > 0) and
    (ARow < AGrid.RowCount);
end;

function GetSelectedStatId(AGrid: TStringGrid): Integer;
begin
  if AGrid = nil then
    raise Exception.Create('Выберите запись в таблице');

  if not IsStatGridCellValid(AGrid, STAT_COL_ID, AGrid.Row) then
    raise Exception.Create('Выберите запись в таблице');

  if Trim(AGrid.Cells[STAT_COL_ID, AGrid.Row]) = '' then
    raise Exception.Create('Не удалось определить ID выбранной записи');

  Result := StrToInt(AGrid.Cells[STAT_COL_ID, AGrid.Row]);
end;

procedure ClearStatControls(AEditName, AEditColor: TEdit);
begin
  if Assigned(AEditName) then
    AEditName.Clear;
  if Assigned(AEditColor) then
    AEditColor.Clear;
end;

procedure SetupStatGrid(AGrid: TStringGrid);
begin
  AGrid.ColCount := 3;
  AGrid.RowCount := 1;
  AGrid.FixedRows := 1;
  AGrid.FixedCols := 0;

  AGrid.Cells[STAT_COL_ID, 0]    := '';
  AGrid.Cells[STAT_COL_NAME, 0]  := 'Название';
  AGrid.Cells[STAT_COL_COLOR, 0] := 'Цвет';

  AGrid.ColWidths[STAT_COL_ID]    := 0;
  AGrid.ColWidths[STAT_COL_NAME]  := 250;
  AGrid.ColWidths[STAT_COL_COLOR] := 80;
end;

procedure LoadStatData(AQuery: TSQLQuery; AGrid: TStringGrid);
var
  RowNum: Integer;
begin
  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT "ni_id", "cv_name", "cv_color" ' +
    'FROM sc_accac."tb_STAT" ' +
    'ORDER BY "ni_id"';
  AQuery.Open;

  AGrid.RowCount := 1;
  RowNum := 1;

  while not AQuery.EOF do
  begin
    AGrid.RowCount := RowNum + 1;
    AGrid.Cells[STAT_COL_ID, RowNum]    := AQuery.FieldByName('ni_id').AsString;
    AGrid.Cells[STAT_COL_NAME, RowNum]  := AQuery.FieldByName('cv_name').AsString;
    AGrid.Cells[STAT_COL_COLOR, RowNum] := AQuery.FieldByName('cv_color').AsString;
    Inc(RowNum);
    AQuery.Next;
  end;

  AQuery.Close;
end;

procedure SelectStatRow(AGrid: TStringGrid; ARow: Integer; AEditName, AEditColor: TEdit);
begin
  if not IsStatGridCellValid(AGrid, STAT_COL_COLOR, ARow) then
    Exit;

  if Assigned(AEditName) then
    AEditName.Text := AGrid.Cells[STAT_COL_NAME, ARow];
  if Assigned(AEditColor) then
    AEditColor.Text := AGrid.Cells[STAT_COL_COLOR, ARow];
end;

procedure AddStat(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditName, AEditColor: TEdit);
begin
  if Trim(AEditName.Text) = '' then
    raise Exception.Create('Введите название');
  if Trim(AEditColor.Text) = '' then
    raise Exception.Create('Введите цвет');

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'INSERT INTO sc_accac."tb_STAT" ("cv_name", "cv_color") ' +
      'VALUES (:p_name, :p_color)';
    AQuery.Params.ParamByName('p_name').AsString := Trim(AEditName.Text);
    AQuery.Params.ParamByName('p_color').AsInteger := StrToInt(AEditColor.Text);
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadStatData(AQuery, AGrid);

    ClearStatControls(AEditName, AEditColor);
  except
    on E: Exception do
    begin
      if ATransaction.Active then
        ATransaction.Rollback;
      ATransaction.StartTransaction;
      raise Exception.Create('Ошибка добавления: ' + E.Message);
    end;
  end;
end;

procedure EditStat(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditName, AEditColor: TEdit);
var
  StatId: Integer;
begin
  if Trim(AEditName.Text) = '' then
    raise Exception.Create('Введите название');
  if Trim(AEditColor.Text) = '' then
    raise Exception.Create('Введите цвет');

  StatId := GetSelectedStatId(AGrid);

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'UPDATE sc_accac."tb_STAT" ' +
      'SET "cv_name" = :p_name, "cv_color" = :p_color ' +
      'WHERE "ni_id" = :p_id';
    AQuery.Params.ParamByName('p_id').AsInteger := StatId;
    AQuery.Params.ParamByName('p_name').AsString := Trim(AEditName.Text);
    AQuery.Params.ParamByName('p_color').AsInteger := StrToInt(AEditColor.Text);
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadStatData(AQuery, AGrid);
  except
    on E: Exception do
    begin
      if ATransaction.Active then
        ATransaction.Rollback;
      ATransaction.StartTransaction;
      raise Exception.Create('Ошибка изменения: ' + E.Message);
    end;
  end;
end;

procedure DeleteStat(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditName, AEditColor: TEdit);
var
  StatId: Integer;
begin
  StatId := GetSelectedStatId(AGrid);

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'DELETE FROM sc_accac."tb_STAT" WHERE "ni_id" = :p_id';
    AQuery.Params.ParamByName('p_id').AsInteger := StatId;
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadStatData(AQuery, AGrid);

    ClearStatControls(AEditName, AEditColor);
  except
    on E: Exception do
    begin
      if ATransaction.Active then
        ATransaction.Rollback;
      ATransaction.StartTransaction;
      raise Exception.Create('Ошибка удаления: ' + E.Message);
    end;
  end;
end;

end.
