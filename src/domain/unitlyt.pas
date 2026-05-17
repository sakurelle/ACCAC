unit UnitLyt;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SQLDB, Grids, StdCtrls;

procedure SetupLytGrid(AGrid: TStringGrid);
procedure LoadLytData(AQuery: TSQLQuery; AGrid: TStringGrid);
procedure SelectLytRow(AGrid: TStringGrid; ARow: Integer; AEditName: TEdit);

procedure AddLyt(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditName: TEdit
);

procedure EditLyt(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditName: TEdit
);

procedure DeleteLyt(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditName: TEdit
);

implementation

const
  LYT_COL_ID   = 0; // скрытая служебная колонка
  LYT_COL_NAME = 1;

function IsLytGridCellValid(AGrid: TStringGrid; ACol, ARow: Integer): Boolean;
begin
  Result :=
    Assigned(AGrid) and
    (ACol >= 0) and
    (ACol < AGrid.ColCount) and
    (ARow > 0) and
    (ARow < AGrid.RowCount);
end;

function GetSelectedLytId(AGrid: TStringGrid): Integer;
begin
  if AGrid = nil then
    raise Exception.Create('Выберите запись в таблице');

  if not IsLytGridCellValid(AGrid, LYT_COL_ID, AGrid.Row) then
    raise Exception.Create('Выберите запись в таблице');

  if Trim(AGrid.Cells[LYT_COL_ID, AGrid.Row]) = '' then
    raise Exception.Create('Не удалось определить ID выбранной записи');

  Result := StrToInt(AGrid.Cells[LYT_COL_ID, AGrid.Row]);
end;

procedure ClearLytControls(AEditName: TEdit);
begin
  if Assigned(AEditName) then
    AEditName.Clear;
end;

procedure SetupLytGrid(AGrid: TStringGrid);
begin
  AGrid.ColCount := 2;
  AGrid.RowCount := 1;
  AGrid.FixedRows := 1;
  AGrid.FixedCols := 0;

  AGrid.Cells[LYT_COL_ID, 0]   := '';
  AGrid.Cells[LYT_COL_NAME, 0] := 'Название';

  AGrid.ColWidths[LYT_COL_ID]   := 0;
  AGrid.ColWidths[LYT_COL_NAME] := 300;
end;

procedure LoadLytData(AQuery: TSQLQuery; AGrid: TStringGrid);
var
  RowNum: Integer;
begin
  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT "ni_id", "cv_name" ' +
    'FROM sc_accac."tb_LYT" ' +
    'ORDER BY "ni_id"';
  AQuery.Open;

  AGrid.RowCount := 1;
  RowNum := 1;

  while not AQuery.EOF do
  begin
    AGrid.RowCount := RowNum + 1;
    AGrid.Cells[LYT_COL_ID, RowNum]   := AQuery.FieldByName('ni_id').AsString;
    AGrid.Cells[LYT_COL_NAME, RowNum] := AQuery.FieldByName('cv_name').AsString;
    Inc(RowNum);
    AQuery.Next;
  end;

  AQuery.Close;
end;

procedure SelectLytRow(AGrid: TStringGrid; ARow: Integer; AEditName: TEdit);
begin
  if not IsLytGridCellValid(AGrid, LYT_COL_NAME, ARow) then
    Exit;

  if Assigned(AEditName) then
    AEditName.Text := AGrid.Cells[LYT_COL_NAME, ARow];
end;

procedure AddLyt(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditName: TEdit);
begin
  if Trim(AEditName.Text) = '' then
    raise Exception.Create('Введите название');

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'INSERT INTO sc_accac."tb_LYT" ("cv_name") ' +
      'VALUES (:p_name)';
    AQuery.Params.ParamByName('p_name').AsString := Trim(AEditName.Text);
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadLytData(AQuery, AGrid);

    ClearLytControls(AEditName);
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

procedure EditLyt(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditName: TEdit);
var
  LytId: Integer;
begin
  if Trim(AEditName.Text) = '' then
    raise Exception.Create('Введите название');

  LytId := GetSelectedLytId(AGrid);

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'UPDATE sc_accac."tb_LYT" ' +
      'SET "cv_name" = :p_name ' +
      'WHERE "ni_id" = :p_id';
    AQuery.Params.ParamByName('p_id').AsInteger := LytId;
    AQuery.Params.ParamByName('p_name').AsString := Trim(AEditName.Text);
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadLytData(AQuery, AGrid);
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

procedure DeleteLyt(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditName: TEdit);
var
  LytId: Integer;
begin
  LytId := GetSelectedLytId(AGrid);

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'DELETE FROM sc_accac."tb_LYT" WHERE "ni_id" = :p_id';
    AQuery.Params.ParamByName('p_id').AsInteger := LytId;
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadLytData(AQuery, AGrid);

    ClearLytControls(AEditName);
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
