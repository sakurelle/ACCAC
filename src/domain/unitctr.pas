unit UnitCtr;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SQLDB, Grids, StdCtrls;

procedure SetupCtrGrid(AGrid: TStringGrid);
procedure LoadCtrData(AQuery: TSQLQuery; AGrid: TStringGrid);
procedure SelectCtrRow(AGrid: TStringGrid; ARow: Integer; AEditName: TEdit);

procedure AddCtr(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditName: TEdit
);

procedure EditCtr(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditName: TEdit
);

procedure DeleteCtr(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditName: TEdit
);

implementation

const
  CTR_COL_ID   = 0; // скрытая служебная колонка
  CTR_COL_NAME = 1;

function IsCtrGridCellValid(AGrid: TStringGrid; ACol, ARow: Integer): Boolean;
begin
  Result :=
    Assigned(AGrid) and
    (ACol >= 0) and
    (ACol < AGrid.ColCount) and
    (ARow > 0) and
    (ARow < AGrid.RowCount);
end;

function GetSelectedCtrId(AGrid: TStringGrid): Integer;
begin
  if AGrid = nil then
    raise Exception.Create('Выберите запись в таблице');

  if not IsCtrGridCellValid(AGrid, CTR_COL_ID, AGrid.Row) then
    raise Exception.Create('Выберите запись в таблице');

  if Trim(AGrid.Cells[CTR_COL_ID, AGrid.Row]) = '' then
    raise Exception.Create('Не удалось определить ID выбранной записи');

  Result := StrToInt(AGrid.Cells[CTR_COL_ID, AGrid.Row]);
end;

procedure ClearCtrControls(AEditName: TEdit);
begin
  if Assigned(AEditName) then
    AEditName.Clear;
end;

procedure SetupCtrGrid(AGrid: TStringGrid);
begin
  AGrid.ColCount := 2;
  AGrid.RowCount := 1;
  AGrid.FixedRows := 1;
  AGrid.FixedCols := 0;

  AGrid.Cells[CTR_COL_ID, 0]   := '';
  AGrid.Cells[CTR_COL_NAME, 0] := 'Название';

  AGrid.ColWidths[CTR_COL_ID]   := 0;
  AGrid.ColWidths[CTR_COL_NAME] := 300;
end;

procedure LoadCtrData(AQuery: TSQLQuery; AGrid: TStringGrid);
var
  RowNum: Integer;
begin
  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT "ni_id", "cv_name" ' +
    'FROM sc_accac."tb_CTR" ' +
    'ORDER BY "ni_id"';
  AQuery.Open;

  AGrid.RowCount := 1;
  RowNum := 1;

  while not AQuery.EOF do
  begin
    AGrid.RowCount := RowNum + 1;
    AGrid.Cells[CTR_COL_ID, RowNum]   := AQuery.FieldByName('ni_id').AsString;
    AGrid.Cells[CTR_COL_NAME, RowNum] := AQuery.FieldByName('cv_name').AsString;

    Inc(RowNum);
    AQuery.Next;
  end;

  AQuery.Close;
end;

procedure SelectCtrRow(AGrid: TStringGrid; ARow: Integer; AEditName: TEdit);
begin
  if not IsCtrGridCellValid(AGrid, CTR_COL_NAME, ARow) then
    Exit;

  if Assigned(AEditName) then
    AEditName.Text := AGrid.Cells[CTR_COL_NAME, ARow];
end;

procedure AddCtr(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditName: TEdit
);
begin
  if Trim(AEditName.Text) = '' then
    raise Exception.Create('Введите название');

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'INSERT INTO sc_accac."tb_CTR" ("cv_name") ' +
      'VALUES (:p_name)';
    AQuery.Params.ParamByName('p_name').AsString := Trim(AEditName.Text);
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;

    LoadCtrData(AQuery, AGrid);
    ClearCtrControls(AEditName);
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

procedure EditCtr(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditName: TEdit
);
var
  CtrId: Integer;
begin
  if Trim(AEditName.Text) = '' then
    raise Exception.Create('Введите название');

  CtrId := GetSelectedCtrId(AGrid);

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'UPDATE sc_accac."tb_CTR" ' +
      'SET "cv_name" = :p_name ' +
      'WHERE "ni_id" = :p_id';
    AQuery.Params.ParamByName('p_id').AsInteger := CtrId;
    AQuery.Params.ParamByName('p_name').AsString := Trim(AEditName.Text);
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;

    LoadCtrData(AQuery, AGrid);
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

procedure DeleteCtr(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditName: TEdit
);
var
  CtrId: Integer;
begin
  CtrId := GetSelectedCtrId(AGrid);

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'DELETE FROM sc_accac."tb_CTR" ' +
      'WHERE "ni_id" = :p_id';
    AQuery.Params.ParamByName('p_id').AsInteger := CtrId;
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;

    LoadCtrData(AQuery, AGrid);
    ClearCtrControls(AEditName);
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
