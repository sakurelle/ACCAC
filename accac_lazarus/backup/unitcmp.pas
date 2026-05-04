unit UnitCmp;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SQLDB, Grids, StdCtrls, Variants;

procedure SetupCmpGrid(AGrid: TStringGrid);
procedure LoadCmpData(AQuery: TSQLQuery; AGrid: TStringGrid);

procedure LoadAntToCombo(AQuery: TSQLQuery; ACombo: TComboBox);
procedure LoadLytToCombo(AQuery: TSQLQuery; ACombo: TComboBox);
procedure LoadCmpTypeToCombo(ACombo: TComboBox);

procedure SelectCmpRow(
  AGrid: TStringGrid; ARow: Integer;
  AEditX, AEditY, AEditWidth, AEditHeight, AEditText: TEdit;
  AComboAnt, AComboLyt, AComboType: TComboBox;
  ACheckVisible: TCheckBox
);

procedure AddCmp(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditX, AEditY, AEditWidth, AEditHeight, AEditText: TEdit;
  AComboAnt, AComboLyt, AComboType: TComboBox;
  ACheckVisible: TCheckBox
);

procedure EditCmp(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditX, AEditY, AEditWidth, AEditHeight, AEditText: TEdit;
  AComboAnt, AComboLyt, AComboType: TComboBox;
  ACheckVisible: TCheckBox
);

procedure DeleteCmp(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditX, AEditY, AEditWidth, AEditHeight, AEditText: TEdit;
  AComboAnt, AComboLyt, AComboType: TComboBox;
  ACheckVisible: TCheckBox
);

implementation

const
  CMP_COL_ID        = 0;  // скрытый
  CMP_COL_TYPE      = 1;
  CMP_COL_X         = 2;
  CMP_COL_Y         = 3;
  CMP_COL_WIDTH     = 4;
  CMP_COL_HEIGHT    = 5;
  CMP_COL_TEXT      = 6;
  CMP_COL_VISIBLE   = 7;

  // скрытые служебные колонки
  CMP_COL_ANT_ID    = 8;
  CMP_COL_CITY_ID   = 9;
  CMP_COL_CTR_ID    = 10;
  CMP_COL_PARENT_ID = 11;
  CMP_COL_LYT_ID    = 12;

function GetComboObjectId(ACombo: TComboBox): Integer;
begin
  if (ACombo = nil) or (ACombo.ItemIndex < 0) then
    raise Exception.Create('Не выбран элемент списка');

  if ACombo.Items.Objects[ACombo.ItemIndex] = nil then
    raise Exception.Create('Не выбран элемент списка');

  Result := PtrInt(ACombo.Items.Objects[ACombo.ItemIndex]);
end;

function TryGetComboObjectId(ACombo: TComboBox; out AId: Integer): Boolean;
begin
  Result := False;
  AId := 0;

  if (ACombo = nil) or (ACombo.ItemIndex < 0) then
    Exit;

  if ACombo.Items.Objects[ACombo.ItemIndex] = nil then
    Exit;

  AId := PtrInt(ACombo.Items.Objects[ACombo.ItemIndex]);
  Result := True;
end;

procedure SetNullableIntParam(AQuery: TSQLQuery; const ParamName: string;
  const TextValue: string);
begin
  if Trim(TextValue) = '' then
    AQuery.Params.ParamByName(ParamName).Clear
  else
    AQuery.Params.ParamByName(ParamName).AsInteger := StrToInt(TextValue);
end;

procedure SelectComboById(ACombo: TComboBox; const AIdText: string);
var
  i, WantedId: Integer;
begin
  if ACombo = nil then Exit;

  if Trim(AIdText) = '' then
  begin
    if ACombo.Items.Count > 0 then
      ACombo.ItemIndex := 0
    else
      ACombo.ItemIndex := -1;
    Exit;
  end;

  WantedId := StrToInt(AIdText);
  ACombo.ItemIndex := -1;

  for i := 0 to ACombo.Items.Count - 1 do
    if (ACombo.Items.Objects[i] <> nil) and
       (PtrInt(ACombo.Items.Objects[i]) = WantedId) then
    begin
      ACombo.ItemIndex := i;
      Exit;
    end;
end;

procedure SelectComboByText(ACombo: TComboBox; const AText: string);
var
  i: Integer;
begin
  if ACombo = nil then Exit;

  if Trim(AText) = '' then
  begin
    if ACombo.Items.Count > 0 then
      ACombo.ItemIndex := 0
    else
      ACombo.ItemIndex := -1;
    Exit;
  end;

  ACombo.ItemIndex := -1;

  for i := 0 to ACombo.Items.Count - 1 do
    if SameText(Trim(ACombo.Items[i]), Trim(AText)) then
    begin
      ACombo.ItemIndex := i;
      Exit;
    end;

  if ACombo.ItemIndex < 0 then
    ACombo.Text := AText;
end;

function GetSelectedCmpId(AGrid: TStringGrid): Integer;
begin
  if (AGrid = nil) or (AGrid.Row <= 0) then
    raise Exception.Create('Выберите запись в таблице');

  if Trim(AGrid.Cells[CMP_COL_ID, AGrid.Row]) = '' then
    raise Exception.Create('Не удалось определить ID выбранной записи');

  Result := StrToInt(AGrid.Cells[CMP_COL_ID, AGrid.Row]);
end;

procedure GetDerivedLocationFromAnt(AQuery: TSQLQuery; AAntId: Integer;
  out ACityId, ACtrId: Variant);
begin
  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT city."ni_id" AS city_id, ctr."ni_id" AS ctr_id ' +
    'FROM sc_accac."tb_ANT" ant ' +
    'JOIN sc_accac."tb_CITY" city ON city."ni_id" = ant."ni_CITY_id" ' +
    'JOIN sc_accac."tb_CTR" ctr ON ctr."ni_id" = city."ni_CTR_id" ' +
    'WHERE ant."ni_id" = :p_ant';
  AQuery.Params.ParamByName('p_ant').AsInteger := AAntId;
  AQuery.Open;

  if AQuery.EOF then
    raise Exception.Create('Не удалось определить город и центр по выбранной антенне');

  ACityId := AQuery.FieldByName('city_id').AsInteger;
  ACtrId  := AQuery.FieldByName('ctr_id').AsInteger;

  AQuery.Close;
end;

procedure ClearCmpControls(
  AEditX, AEditY, AEditWidth, AEditHeight, AEditText: TEdit;
  AComboAnt, AComboLyt, AComboType: TComboBox;
  ACheckVisible: TCheckBox
);
begin
  AEditX.Clear;
  AEditY.Clear;
  AEditWidth.Clear;
  AEditHeight.Clear;
  AEditText.Clear;

  if Assigned(AComboAnt) then
    if AComboAnt.Items.Count > 0 then
      AComboAnt.ItemIndex := 0
    else
      AComboAnt.ItemIndex := -1;

  if Assigned(AComboLyt) then
    AComboLyt.ItemIndex := -1;

  if Assigned(AComboType) then
    AComboType.ItemIndex := -1;

  if Assigned(ACheckVisible) then
    ACheckVisible.Checked := False;
end;

procedure SetupCmpGrid(AGrid: TStringGrid);
begin
  AGrid.ColCount := 13;
  AGrid.RowCount := 1;
  AGrid.FixedRows := 1;
  AGrid.FixedCols := 0;

  AGrid.Cells[CMP_COL_ID, 0]      := '';
  AGrid.Cells[CMP_COL_TYPE, 0]    := 'Тип';
  AGrid.Cells[CMP_COL_X, 0]       := 'X';
  AGrid.Cells[CMP_COL_Y, 0]       := 'Y';
  AGrid.Cells[CMP_COL_WIDTH, 0]   := 'Ш';
  AGrid.Cells[CMP_COL_HEIGHT, 0]  := 'В';
  AGrid.Cells[CMP_COL_TEXT, 0]    := 'Текст';
  AGrid.Cells[CMP_COL_VISIBLE, 0] := 'Видимый';

  AGrid.Cells[CMP_COL_ANT_ID, 0]    := 'ANT_ID';
  AGrid.Cells[CMP_COL_CITY_ID, 0]   := 'CITY_ID';
  AGrid.Cells[CMP_COL_CTR_ID, 0]    := 'CTR_ID';
  AGrid.Cells[CMP_COL_PARENT_ID, 0] := 'PARENT_ID';
  AGrid.Cells[CMP_COL_LYT_ID, 0]    := 'LYT_ID';

  AGrid.ColWidths[CMP_COL_ID]      := 0;
  AGrid.ColWidths[CMP_COL_TYPE]    := 140;
  AGrid.ColWidths[CMP_COL_X]       := 50;
  AGrid.ColWidths[CMP_COL_Y]       := 50;
  AGrid.ColWidths[CMP_COL_WIDTH]   := 50;
  AGrid.ColWidths[CMP_COL_HEIGHT]  := 50;
  AGrid.ColWidths[CMP_COL_TEXT]    := 220;
  AGrid.ColWidths[CMP_COL_VISIBLE] := 70;

  AGrid.ColWidths[CMP_COL_ANT_ID]    := 0;
  AGrid.ColWidths[CMP_COL_CITY_ID]   := 0;
  AGrid.ColWidths[CMP_COL_CTR_ID]    := 0;
  AGrid.ColWidths[CMP_COL_PARENT_ID] := 0;
  AGrid.ColWidths[CMP_COL_LYT_ID]    := 0;
end;

procedure LoadCmpData(AQuery: TSQLQuery; AGrid: TStringGrid);
var
  RowNum: Integer;
begin
  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT ' +
    '  c."ni_id", c."cv_type", c."ni_x", c."ni_y", c."ni_width", c."ni_height", ' +
    '  c."cv_text", c."bl_visible", ' +
    '  c."ni_ANT_id", c."ni_CITY_id", c."ni_CTR_id", c."ni_parent_id", c."ni_LYT_id" ' +
    'FROM sc_accac."tb_CMP" c ' +
    'ORDER BY c."ni_id"';
  AQuery.Open;

  AGrid.RowCount := 1;
  RowNum := 1;

  while not AQuery.EOF do
  begin
    AGrid.RowCount := RowNum + 1;

    AGrid.Cells[CMP_COL_ID, RowNum]      := AQuery.FieldByName('ni_id').AsString;
    AGrid.Cells[CMP_COL_TYPE, RowNum]    := AQuery.FieldByName('cv_type').AsString;
    AGrid.Cells[CMP_COL_X, RowNum]       := AQuery.FieldByName('ni_x').AsString;
    AGrid.Cells[CMP_COL_Y, RowNum]       := AQuery.FieldByName('ni_y').AsString;
    AGrid.Cells[CMP_COL_WIDTH, RowNum]   := AQuery.FieldByName('ni_width').AsString;
    AGrid.Cells[CMP_COL_HEIGHT, RowNum]  := AQuery.FieldByName('ni_height').AsString;
    AGrid.Cells[CMP_COL_TEXT, RowNum]    := AQuery.FieldByName('cv_text').AsString;
    AGrid.Cells[CMP_COL_VISIBLE, RowNum] := AQuery.FieldByName('bl_visible').AsString;

    AGrid.Cells[CMP_COL_ANT_ID, RowNum]    := AQuery.FieldByName('ni_ANT_id').AsString;
    AGrid.Cells[CMP_COL_CITY_ID, RowNum]   := AQuery.FieldByName('ni_CITY_id').AsString;
    AGrid.Cells[CMP_COL_CTR_ID, RowNum]    := AQuery.FieldByName('ni_CTR_id').AsString;
    AGrid.Cells[CMP_COL_PARENT_ID, RowNum] := AQuery.FieldByName('ni_parent_id').AsString;
    AGrid.Cells[CMP_COL_LYT_ID, RowNum]    := AQuery.FieldByName('ni_LYT_id').AsString;

    Inc(RowNum);
    AQuery.Next;
  end;

  AQuery.Close;
end;

procedure LoadAntToCombo(AQuery: TSQLQuery; ACombo: TComboBox);
var
  DisplayText: string;
begin
  ACombo.Items.Clear;
  ACombo.Items.AddObject('', nil);

  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT ant."ni_id", mdl."cv_name" AS ant_name, ctr."cv_name" AS ctr_name, city."cv_name" AS city_name ' +
    'FROM sc_accac."tb_ANT" ant ' +
    'JOIN sc_accac."tb_MDL" mdl ON mdl."ni_id" = ant."ni_MDL_id" ' +
    'JOIN sc_accac."tb_CITY" city ON city."ni_id" = ant."ni_CITY_id" ' +
    'JOIN sc_accac."tb_CTR" ctr ON ctr."ni_id" = city."ni_CTR_id" ' +
    'ORDER BY ant."ni_id"';
  AQuery.Open;

  while not AQuery.EOF do
  begin
    DisplayText :=
      AQuery.FieldByName('ant_name').AsString + ' (' +
      AQuery.FieldByName('ctr_name').AsString + ', ' +
      AQuery.FieldByName('city_name').AsString + ')';

    ACombo.Items.AddObject(
      DisplayText,
      TObject(PtrInt(AQuery.FieldByName('ni_id').AsInteger))
    );
    AQuery.Next;
  end;

  AQuery.Close;
end;

procedure LoadLytToCombo(AQuery: TSQLQuery; ACombo: TComboBox);
begin
  ACombo.Items.Clear;

  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT "ni_id", "cv_name" FROM sc_accac."tb_LYT" ORDER BY "ni_id"';
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

procedure LoadCmpTypeToCombo(ACombo: TComboBox);
begin
  ACombo.Items.Clear;
  ACombo.Items.Add('');
  ACombo.Items.Add('title');
  ACombo.Items.Add('rectangle_header');
  ACombo.Items.Add('header');
  ACombo.Items.Add('rectangle_city');
  ACombo.Items.Add('city');
  ACombo.Items.Add('rectangle_antenna');
  ACombo.Items.Add('antenna_text');
end;

procedure SelectCmpRow(AGrid: TStringGrid; ARow: Integer;
  AEditX, AEditY, AEditWidth, AEditHeight, AEditText: TEdit;
  AComboAnt, AComboLyt, AComboType: TComboBox; ACheckVisible: TCheckBox);
begin
  if ARow <= 0 then Exit;

  AEditX.Text      := AGrid.Cells[CMP_COL_X, ARow];
  AEditY.Text      := AGrid.Cells[CMP_COL_Y, ARow];
  AEditWidth.Text  := AGrid.Cells[CMP_COL_WIDTH, ARow];
  AEditHeight.Text := AGrid.Cells[CMP_COL_HEIGHT, ARow];
  AEditText.Text   := AGrid.Cells[CMP_COL_TEXT, ARow];

  SelectComboByText(AComboType, AGrid.Cells[CMP_COL_TYPE, ARow]);
  SelectComboById(AComboAnt, AGrid.Cells[CMP_COL_ANT_ID, ARow]);
  SelectComboById(AComboLyt, AGrid.Cells[CMP_COL_LYT_ID, ARow]);

  ACheckVisible.Checked := SameText(AGrid.Cells[CMP_COL_VISIBLE, ARow], 'TRUE');
end;

procedure AddCmp(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditX, AEditY, AEditWidth, AEditHeight, AEditText: TEdit;
  AComboAnt, AComboLyt, AComboType: TComboBox; ACheckVisible: TCheckBox);
var
  AntId, LytId: Integer;
  HasAnt: Boolean;
  CityId, CtrId: Variant;
begin
  if Trim(AComboType.Text) = '' then
    raise Exception.Create('Выберите тип');

  LytId := GetComboObjectId(AComboLyt);

  HasAnt := TryGetComboObjectId(AComboAnt, AntId);

  CityId := Null;
  CtrId := Null;

  try
    if HasAnt then
      GetDerivedLocationFromAnt(AQuery, AntId, CityId, CtrId);

    AQuery.Close;
    AQuery.SQL.Text :=
      'INSERT INTO sc_accac."tb_CMP" ' +
      '("ni_ANT_id","ni_CITY_id","ni_CTR_id","ni_parent_id","ni_LYT_id",' +
      '"cv_type","ni_x","ni_y","ni_width","ni_height","cv_text","bl_visible") ' +
      'VALUES (:p_ant,:p_city,:p_ctr,:p_parent,:p_lyt,:p_type,:p_x,:p_y,:p_w,:p_h,:p_text,:p_vis)';

    if HasAnt then
      AQuery.Params.ParamByName('p_ant').AsInteger := AntId
    else
      AQuery.Params.ParamByName('p_ant').Clear;

    if VarIsNull(CityId) then
      AQuery.Params.ParamByName('p_city').Clear
    else
      AQuery.Params.ParamByName('p_city').AsInteger := CityId;

    if VarIsNull(CtrId) then
      AQuery.Params.ParamByName('p_ctr').Clear
    else
      AQuery.Params.ParamByName('p_ctr').AsInteger := CtrId;

    AQuery.Params.ParamByName('p_parent').Clear;
    AQuery.Params.ParamByName('p_lyt').AsInteger := LytId;
    AQuery.Params.ParamByName('p_type').AsString := Trim(AComboType.Text);

    SetNullableIntParam(AQuery, 'p_x', AEditX.Text);
    SetNullableIntParam(AQuery, 'p_y', AEditY.Text);
    SetNullableIntParam(AQuery, 'p_w', AEditWidth.Text);
    SetNullableIntParam(AQuery, 'p_h', AEditHeight.Text);

    if Trim(AEditText.Text) = '' then
      AQuery.Params.ParamByName('p_text').Clear
    else
      AQuery.Params.ParamByName('p_text').AsString := Trim(AEditText.Text);

    AQuery.Params.ParamByName('p_vis').AsBoolean := ACheckVisible.Checked;
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;

    LoadCmpData(AQuery, AGrid);
    ClearCmpControls(
      AEditX, AEditY, AEditWidth, AEditHeight, AEditText,
      AComboAnt, AComboLyt, AComboType, ACheckVisible
    );
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

procedure EditCmp(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditX, AEditY, AEditWidth, AEditHeight, AEditText: TEdit;
  AComboAnt, AComboLyt, AComboType: TComboBox; ACheckVisible: TCheckBox);
var
  CmpId, AntId, LytId: Integer;
  HasAnt: Boolean;
  CityId, CtrId: Variant;
  ParentIdText: string;
begin
  if Trim(AComboType.Text) = '' then
    raise Exception.Create('Выберите тип');

  CmpId := GetSelectedCmpId(AGrid);
  LytId := GetComboObjectId(AComboLyt);
  HasAnt := TryGetComboObjectId(AComboAnt, AntId);

  ParentIdText := AGrid.Cells[CMP_COL_PARENT_ID, AGrid.Row];

  if HasAnt then
  begin
    GetDerivedLocationFromAnt(AQuery, AntId, CityId, CtrId);
  end
  else
  begin
    if Trim(AGrid.Cells[CMP_COL_CITY_ID, AGrid.Row]) = '' then
      CityId := Null
    else
      CityId := StrToInt(AGrid.Cells[CMP_COL_CITY_ID, AGrid.Row]);

    if Trim(AGrid.Cells[CMP_COL_CTR_ID, AGrid.Row]) = '' then
      CtrId := Null
    else
      CtrId := StrToInt(AGrid.Cells[CMP_COL_CTR_ID, AGrid.Row]);
  end;

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'UPDATE sc_accac."tb_CMP" SET ' +
      '"ni_ANT_id"=:p_ant,' +
      '"ni_CITY_id"=:p_city,' +
      '"ni_CTR_id"=:p_ctr,' +
      '"ni_parent_id"=:p_parent,' +
      '"ni_LYT_id"=:p_lyt,' +
      '"cv_type"=:p_type,' +
      '"ni_x"=:p_x,' +
      '"ni_y"=:p_y,' +
      '"ni_width"=:p_w,' +
      '"ni_height"=:p_h,' +
      '"cv_text"=:p_text,' +
      '"bl_visible"=:p_vis ' +
      'WHERE "ni_id"=:p_id';

    AQuery.Params.ParamByName('p_id').AsInteger := CmpId;

    if HasAnt then
      AQuery.Params.ParamByName('p_ant').AsInteger := AntId
    else
      AQuery.Params.ParamByName('p_ant').Clear;

    if VarIsNull(CityId) then
      AQuery.Params.ParamByName('p_city').Clear
    else
      AQuery.Params.ParamByName('p_city').AsInteger := CityId;

    if VarIsNull(CtrId) then
      AQuery.Params.ParamByName('p_ctr').Clear
    else
      AQuery.Params.ParamByName('p_ctr').AsInteger := CtrId;

    if Trim(ParentIdText) = '' then
      AQuery.Params.ParamByName('p_parent').Clear
    else
      AQuery.Params.ParamByName('p_parent').AsInteger := StrToInt(ParentIdText);

    AQuery.Params.ParamByName('p_lyt').AsInteger := LytId;
    AQuery.Params.ParamByName('p_type').AsString := Trim(AComboType.Text);

    SetNullableIntParam(AQuery, 'p_x', AEditX.Text);
    SetNullableIntParam(AQuery, 'p_y', AEditY.Text);
    SetNullableIntParam(AQuery, 'p_w', AEditWidth.Text);
    SetNullableIntParam(AQuery, 'p_h', AEditHeight.Text);

    if Trim(AEditText.Text) = '' then
      AQuery.Params.ParamByName('p_text').Clear
    else
      AQuery.Params.ParamByName('p_text').AsString := Trim(AEditText.Text);

    AQuery.Params.ParamByName('p_vis').AsBoolean := ACheckVisible.Checked;
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;

    LoadCmpData(AQuery, AGrid);
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

procedure DeleteCmp(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditX, AEditY, AEditWidth, AEditHeight, AEditText: TEdit;
  AComboAnt, AComboLyt, AComboType: TComboBox; ACheckVisible: TCheckBox);
var
  CmpId: Integer;
begin
  CmpId := GetSelectedCmpId(AGrid);

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'DELETE FROM sc_accac."tb_CMP" WHERE "ni_id" = :p_id';
    AQuery.Params.ParamByName('p_id').AsInteger := CmpId;
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;

    LoadCmpData(AQuery, AGrid);
    ClearCmpControls(
      AEditX, AEditY, AEditWidth, AEditHeight, AEditText,
      AComboAnt, AComboLyt, AComboType, ACheckVisible
    );
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
