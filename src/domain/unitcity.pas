unit UnitCity;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SQLDB, Grids, StdCtrls;

procedure SetupCityGrid(AGrid: TStringGrid);
procedure LoadCityData(AQuery: TSQLQuery; AGrid: TStringGrid);
procedure LoadCtrToCombo(AQuery: TSQLQuery; ACombo: TComboBox);
procedure SelectCityRow(
  AGrid: TStringGrid; ARow: Integer;
  AEditName: TEdit; AComboCtr: TComboBox
);

procedure AddCity(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditName: TEdit;
  AComboCtr: TComboBox
);

procedure EditCity(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditName: TEdit;
  AComboCtr: TComboBox
);

procedure DeleteCity(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditName: TEdit;
  AComboCtr: TComboBox
);

implementation

const
  CITY_COL_ID   = 0; // скрытая служебная колонка
  CITY_COL_NAME = 1;
  CITY_COL_CTR  = 2;

function IsCityGridCellValid(AGrid: TStringGrid; ACol, ARow: Integer): Boolean;
begin
  Result :=
    Assigned(AGrid) and
    (ACol >= 0) and
    (ACol < AGrid.ColCount) and
    (ARow > 0) and
    (ARow < AGrid.RowCount);
end;

function GetSelectedCityId(AGrid: TStringGrid): Integer;
begin
  if AGrid = nil then
    raise Exception.Create('Выберите запись в таблице');

  if not IsCityGridCellValid(AGrid, CITY_COL_ID, AGrid.Row) then
    raise Exception.Create('Выберите запись в таблице');

  if Trim(AGrid.Cells[CITY_COL_ID, AGrid.Row]) = '' then
    raise Exception.Create('Не удалось определить ID выбранной записи');

  Result := StrToInt(AGrid.Cells[CITY_COL_ID, AGrid.Row]);
end;

function GetSelectedComboId(ACombo: TComboBox): Integer;
begin
  if (ACombo = nil) or (ACombo.ItemIndex < 0) then
    raise Exception.Create('Выберите центр');

  if ACombo.Items.Objects[ACombo.ItemIndex] = nil then
    raise Exception.Create('Выберите центр');

  Result := PtrInt(ACombo.Items.Objects[ACombo.ItemIndex]);
end;

procedure SelectComboByText(ACombo: TComboBox; const AText: string);
var
  i: Integer;
begin
  if ACombo = nil then Exit;

  ACombo.ItemIndex := -1;
  for i := 0 to ACombo.Items.Count - 1 do
    if SameText(Trim(ACombo.Items[i]), Trim(AText)) then
    begin
      ACombo.ItemIndex := i;
      Exit;
    end;
end;

procedure ClearCityControls(AEditName: TEdit; AComboCtr: TComboBox);
begin
  if Assigned(AEditName) then
    AEditName.Clear;

  if Assigned(AComboCtr) then
    AComboCtr.ItemIndex := -1;
end;

procedure SetupCityGrid(AGrid: TStringGrid);
begin
  AGrid.ColCount := 3;
  AGrid.RowCount := 1;
  AGrid.FixedRows := 1;
  AGrid.FixedCols := 0;

  AGrid.Cells[CITY_COL_ID, 0]   := '';
  AGrid.Cells[CITY_COL_NAME, 0] := 'Название';
  AGrid.Cells[CITY_COL_CTR, 0]  := 'Центр';

  AGrid.ColWidths[CITY_COL_ID]   := 0;
  AGrid.ColWidths[CITY_COL_NAME] := 250;
  AGrid.ColWidths[CITY_COL_CTR]  := 250;
end;

procedure LoadCityData(AQuery: TSQLQuery; AGrid: TStringGrid);
var
  RowNum: Integer;
begin
  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT c."ni_id", c."cv_name", ctr."cv_name" as ctr_name ' +
    'FROM sc_accac."tb_CITY" c ' +
    'JOIN sc_accac."tb_CTR" ctr ON ctr."ni_id" = c."ni_CTR_id" ' +
    'ORDER BY c."ni_id"';
  AQuery.Open;

  AGrid.RowCount := 1;
  RowNum := 1;

  while not AQuery.EOF do
  begin
    AGrid.RowCount := RowNum + 1;
    AGrid.Cells[CITY_COL_ID, RowNum]   := AQuery.FieldByName('ni_id').AsString;
    AGrid.Cells[CITY_COL_NAME, RowNum] := AQuery.FieldByName('cv_name').AsString;
    AGrid.Cells[CITY_COL_CTR, RowNum]  := AQuery.FieldByName('ctr_name').AsString;
    Inc(RowNum);
    AQuery.Next;
  end;

  AQuery.Close;
end;

procedure LoadCtrToCombo(AQuery: TSQLQuery; ACombo: TComboBox);
begin
  ACombo.Items.Clear;

  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT "ni_id", "cv_name" FROM sc_accac."tb_CTR" ORDER BY "ni_id"';
  AQuery.Open;

  while not AQuery.EOF do
  begin
    ACombo.Items.AddObject(
      AQuery.FieldByName('cv_name').AsString,
      TObject(PtrInt(AQuery.FieldByName('ni_id').AsInteger))
    );
    AQuery.Next;
  end;

  AQuery.Close;
end;

procedure SelectCityRow(AGrid: TStringGrid; ARow: Integer;
  AEditName: TEdit; AComboCtr: TComboBox);
begin
  if not IsCityGridCellValid(AGrid, CITY_COL_CTR, ARow) then
    Exit;

  if Assigned(AEditName) then
    AEditName.Text := AGrid.Cells[CITY_COL_NAME, ARow];
  SelectComboByText(AComboCtr, AGrid.Cells[CITY_COL_CTR, ARow]);
end;

procedure AddCity(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditName: TEdit; AComboCtr: TComboBox);
var
  CtrId: Integer;
begin
  if Trim(AEditName.Text) = '' then
    raise Exception.Create('Введите название');

  CtrId := GetSelectedComboId(AComboCtr);

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'INSERT INTO sc_accac."tb_CITY" ("ni_CTR_id", "cv_name") ' +
      'VALUES (:p_ctr_id, :p_name)';
    AQuery.Params.ParamByName('p_ctr_id').AsInteger := CtrId;
    AQuery.Params.ParamByName('p_name').AsString := Trim(AEditName.Text);
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadCityData(AQuery, AGrid);

    ClearCityControls(AEditName, AComboCtr);
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

procedure EditCity(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditName: TEdit; AComboCtr: TComboBox);
var
  CityId, CtrId: Integer;
begin
  if Trim(AEditName.Text) = '' then
    raise Exception.Create('Введите название');

  CityId := GetSelectedCityId(AGrid);
  CtrId := GetSelectedComboId(AComboCtr);

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'UPDATE sc_accac."tb_CITY" ' +
      'SET "ni_CTR_id" = :p_ctr_id, "cv_name" = :p_name ' +
      'WHERE "ni_id" = :p_id';
    AQuery.Params.ParamByName('p_id').AsInteger := CityId;
    AQuery.Params.ParamByName('p_ctr_id').AsInteger := CtrId;
    AQuery.Params.ParamByName('p_name').AsString := Trim(AEditName.Text);
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadCityData(AQuery, AGrid);
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

procedure DeleteCity(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditName: TEdit; AComboCtr: TComboBox);
var
  CityId: Integer;
begin
  CityId := GetSelectedCityId(AGrid);

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'DELETE FROM sc_accac."tb_CITY" WHERE "ni_id" = :p_id';
    AQuery.Params.ParamByName('p_id').AsInteger := CityId;
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadCityData(AQuery, AGrid);

    ClearCityControls(AEditName, AComboCtr);
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
