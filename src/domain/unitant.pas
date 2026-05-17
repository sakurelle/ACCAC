unit UnitAnt;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SQLDB, Grids, StdCtrls;

procedure SetupAntGrid(AGrid: TStringGrid);
procedure LoadAntData(AQuery: TSQLQuery; AGrid: TStringGrid);

procedure LoadMdlToCombo(AQuery: TSQLQuery; ACombo: TComboBox);
procedure LoadCityToCombo(AQuery: TSQLQuery; ACombo: TComboBox);
procedure LoadStatToCombo(AQuery: TSQLQuery; ACombo: TComboBox);

procedure SelectAntRow(
  AGrid: TStringGrid; ARow: Integer;
  AEditNote: TEdit;
  AComboMdl, AComboCity, AComboStat: TComboBox
);

procedure AddAnt(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditNote: TEdit;
  AComboMdl, AComboCity, AComboStat: TComboBox
);

procedure EditAnt(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditNote: TEdit;
  AComboMdl, AComboCity, AComboStat: TComboBox
);

procedure DeleteAnt(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditNote: TEdit;
  AComboMdl, AComboCity, AComboStat: TComboBox
);

implementation

const
  ANT_COL_ID    = 0; // скрытая служебная колонка
  ANT_COL_MDL   = 1;
  ANT_COL_CITY  = 2;
  ANT_COL_STAT  = 3;
  ANT_COL_NOTE  = 4;

function IsAntGridCellValid(AGrid: TStringGrid; ACol, ARow: Integer): Boolean;
begin
  Result :=
    Assigned(AGrid) and
    (ACol >= 0) and
    (ACol < AGrid.ColCount) and
    (ARow > 0) and
    (ARow < AGrid.RowCount);
end;

function GetComboSelectedId(ACombo: TComboBox): Integer;
begin
  if (ACombo = nil) or (ACombo.ItemIndex < 0) then
    raise Exception.Create('Не выбран элемент списка');

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

function GetSelectedAntId(AGrid: TStringGrid): Integer;
begin
  if AGrid = nil then
    raise Exception.Create('Выберите запись в таблице');

  if not IsAntGridCellValid(AGrid, ANT_COL_ID, AGrid.Row) then
    raise Exception.Create('Выберите запись в таблице');

  if Trim(AGrid.Cells[ANT_COL_ID, AGrid.Row]) = '' then
    raise Exception.Create('Не удалось определить ID выбранной записи');

  Result := StrToInt(AGrid.Cells[ANT_COL_ID, AGrid.Row]);
end;

procedure ClearAntControls(
  AEditNote: TEdit;
  AComboMdl, AComboCity, AComboStat: TComboBox
);
begin
  if Assigned(AEditNote) then
    AEditNote.Clear;

  if Assigned(AComboMdl) then
    AComboMdl.ItemIndex := -1;

  if Assigned(AComboCity) then
    AComboCity.ItemIndex := -1;

  if Assigned(AComboStat) then
    AComboStat.ItemIndex := -1;
end;

procedure SetupAntGrid(AGrid: TStringGrid);
begin
  AGrid.ColCount := 5;
  AGrid.RowCount := 1;
  AGrid.FixedRows := 1;
  AGrid.FixedCols := 0;

  AGrid.Cells[ANT_COL_ID,   0] := '';
  AGrid.Cells[ANT_COL_MDL,  0] := 'Модель';
  AGrid.Cells[ANT_COL_CITY, 0] := 'Город';
  AGrid.Cells[ANT_COL_STAT, 0] := 'Состояние';
  AGrid.Cells[ANT_COL_NOTE, 0] := 'Примечание';

  AGrid.ColWidths[ANT_COL_ID]   := 0;
  AGrid.ColWidths[ANT_COL_MDL]  := 180;
  AGrid.ColWidths[ANT_COL_CITY] := 180;
  AGrid.ColWidths[ANT_COL_STAT] := 150;
  AGrid.ColWidths[ANT_COL_NOTE] := 300;
end;

procedure LoadAntData(AQuery: TSQLQuery; AGrid: TStringGrid);
var
  RowNum: Integer;
begin
  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT a."ni_id", mdl."cv_name" as mdl_name, city."cv_name" as city_name, ' +
    'st."cv_name" as stat_name, a."cv_note" ' +
    'FROM sc_accac."tb_ANT" a ' +
    'JOIN sc_accac."tb_MDL" mdl ON mdl."ni_id" = a."ni_MDL_id" ' +
    'JOIN sc_accac."tb_CITY" city ON city."ni_id" = a."ni_CITY_id" ' +
    'JOIN sc_accac."tb_STAT" st ON st."ni_id" = a."ni_STAT_id" ' +
    'ORDER BY a."ni_id"';
  AQuery.Open;

  AGrid.RowCount := 1;
  RowNum := 1;

  while not AQuery.EOF do
  begin
    AGrid.RowCount := RowNum + 1;
    AGrid.Cells[ANT_COL_ID, RowNum]   := AQuery.FieldByName('ni_id').AsString;
    AGrid.Cells[ANT_COL_MDL, RowNum]  := AQuery.FieldByName('mdl_name').AsString;
    AGrid.Cells[ANT_COL_CITY, RowNum] := AQuery.FieldByName('city_name').AsString;
    AGrid.Cells[ANT_COL_STAT, RowNum] := AQuery.FieldByName('stat_name').AsString;
    AGrid.Cells[ANT_COL_NOTE, RowNum] := AQuery.FieldByName('cv_note').AsString;
    Inc(RowNum);
    AQuery.Next;
  end;

  AQuery.Close;
end;

procedure LoadMdlToCombo(AQuery: TSQLQuery; ACombo: TComboBox);
begin
  ACombo.Items.Clear;
  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT "ni_id", "cv_name" FROM sc_accac."tb_MDL" ORDER BY "ni_id"';
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

procedure LoadCityToCombo(AQuery: TSQLQuery; ACombo: TComboBox);
begin
  ACombo.Items.Clear;
  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT "ni_id", "cv_name" FROM sc_accac."tb_CITY" ORDER BY "ni_id"';
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

procedure LoadStatToCombo(AQuery: TSQLQuery; ACombo: TComboBox);
begin
  ACombo.Items.Clear;
  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT "ni_id", "cv_name" FROM sc_accac."tb_STAT" ORDER BY "ni_id"';
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

procedure SelectAntRow(AGrid: TStringGrid; ARow: Integer; AEditNote: TEdit;
  AComboMdl, AComboCity, AComboStat: TComboBox);
begin
  if not IsAntGridCellValid(AGrid, ANT_COL_NOTE, ARow) then
    Exit;

  if Assigned(AEditNote) then
    AEditNote.Text := AGrid.Cells[ANT_COL_NOTE, ARow];

  SelectComboByText(AComboMdl,  AGrid.Cells[ANT_COL_MDL, ARow]);
  SelectComboByText(AComboCity, AGrid.Cells[ANT_COL_CITY, ARow]);
  SelectComboByText(AComboStat, AGrid.Cells[ANT_COL_STAT, ARow]);
end;

procedure AddAnt(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditNote: TEdit; AComboMdl, AComboCity, AComboStat: TComboBox);
begin
  if AComboMdl.ItemIndex < 0 then
    raise Exception.Create('Выберите модель');
  if AComboCity.ItemIndex < 0 then
    raise Exception.Create('Выберите город');
  if AComboStat.ItemIndex < 0 then
    raise Exception.Create('Выберите состояние');

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'INSERT INTO sc_accac."tb_ANT" ' +
      '("ni_MDL_id", "ni_CITY_id", "ni_STAT_id", "cv_note") ' +
      'VALUES (:p_mdl, :p_city, :p_stat, :p_note)';

    AQuery.Params.ParamByName('p_mdl').AsInteger := GetComboSelectedId(AComboMdl);
    AQuery.Params.ParamByName('p_city').AsInteger := GetComboSelectedId(AComboCity);
    AQuery.Params.ParamByName('p_stat').AsInteger := GetComboSelectedId(AComboStat);
    AQuery.Params.ParamByName('p_note').AsString := Trim(AEditNote.Text);
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadAntData(AQuery, AGrid);
    ClearAntControls(AEditNote, AComboMdl, AComboCity, AComboStat);
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

procedure EditAnt(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditNote: TEdit; AComboMdl, AComboCity, AComboStat: TComboBox);
var
  AntId: Integer;
begin
  if AComboMdl.ItemIndex < 0 then
    raise Exception.Create('Выберите модель');
  if AComboCity.ItemIndex < 0 then
    raise Exception.Create('Выберите город');
  if AComboStat.ItemIndex < 0 then
    raise Exception.Create('Выберите состояние');

  AntId := GetSelectedAntId(AGrid);

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'UPDATE sc_accac."tb_ANT" SET ' +
      '"ni_MDL_id" = :p_mdl, "ni_CITY_id" = :p_city, "ni_STAT_id" = :p_stat, "cv_note" = :p_note ' +
      'WHERE "ni_id" = :p_id';

    AQuery.Params.ParamByName('p_id').AsInteger := AntId;
    AQuery.Params.ParamByName('p_mdl').AsInteger := GetComboSelectedId(AComboMdl);
    AQuery.Params.ParamByName('p_city').AsInteger := GetComboSelectedId(AComboCity);
    AQuery.Params.ParamByName('p_stat').AsInteger := GetComboSelectedId(AComboStat);
    AQuery.Params.ParamByName('p_note').AsString := Trim(AEditNote.Text);
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadAntData(AQuery, AGrid);
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

procedure DeleteAnt(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditNote: TEdit; AComboMdl, AComboCity, AComboStat: TComboBox);
var
  AntId: Integer;
begin
  AntId := GetSelectedAntId(AGrid);

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'DELETE FROM sc_accac."tb_ANT" WHERE "ni_id" = :p_id';
    AQuery.Params.ParamByName('p_id').AsInteger := AntId;
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadAntData(AQuery, AGrid);
    ClearAntControls(AEditNote, AComboMdl, AComboCity, AComboStat);
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
