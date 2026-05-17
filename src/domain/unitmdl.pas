unit UnitMdl;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, DB, SQLDB, Grids, StdCtrls;

procedure SetupMdlGrid(AGrid: TStringGrid);
procedure LoadMdlData(AQuery: TSQLQuery; AGrid: TStringGrid);
procedure SelectMdlRow(
  AGrid: TStringGrid; ARow: Integer;
  AEditName, AEditType, AEditWidth, AEditHeight: TEdit
);

procedure AddMdl(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditName, AEditType, AEditWidth, AEditHeight: TEdit;
  const AImagePath: string
);

procedure EditMdl(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditName, AEditType, AEditWidth, AEditHeight: TEdit;
  const AImagePath: string
);

procedure DeleteMdl(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditName, AEditType, AEditWidth, AEditHeight: TEdit
);

implementation

const
  MDL_COL_ID     = 0; // скрытая служебная колонка
  MDL_COL_NAME   = 1;
  MDL_COL_TYPE   = 2;
  MDL_COL_WIDTH  = 3;
  MDL_COL_HEIGHT = 4;

function IsMdlGridCellValid(AGrid: TStringGrid; ACol, ARow: Integer): Boolean;
begin
  Result :=
    Assigned(AGrid) and
    (ACol >= 0) and
    (ACol < AGrid.ColCount) and
    (ARow > 0) and
    (ARow < AGrid.RowCount);
end;

procedure SetupMdlGrid(AGrid: TStringGrid);
begin
  AGrid.ColCount := 5;
  AGrid.RowCount := 1;
  AGrid.FixedRows := 1;
  AGrid.FixedCols := 0;

  AGrid.Cells[MDL_COL_ID, 0]     := '';
  AGrid.Cells[MDL_COL_NAME, 0]   := 'Название';
  AGrid.Cells[MDL_COL_TYPE, 0]   := 'Тип';
  AGrid.Cells[MDL_COL_WIDTH, 0]  := 'Ширина';
  AGrid.Cells[MDL_COL_HEIGHT, 0] := 'Высота';

  AGrid.ColWidths[MDL_COL_ID]     := 0;
  AGrid.ColWidths[MDL_COL_NAME]   := 220;
  AGrid.ColWidths[MDL_COL_TYPE]   := 140;
  AGrid.ColWidths[MDL_COL_WIDTH]  := 80;
  AGrid.ColWidths[MDL_COL_HEIGHT] := 80;
end;

procedure LoadMdlData(AQuery: TSQLQuery; AGrid: TStringGrid);
var
  RowNum: Integer;
begin
  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT "ni_id", "cv_name", "cv_type", "ni_width", "ni_height" ' +
    'FROM sc_accac."tb_MDL" ' +
    'ORDER BY "ni_id"';
  AQuery.Open;

  AGrid.RowCount := 1;
  RowNum := 1;

  while not AQuery.EOF do
  begin
    AGrid.RowCount := RowNum + 1;
    AGrid.Cells[MDL_COL_ID, RowNum]     := AQuery.FieldByName('ni_id').AsString;
    AGrid.Cells[MDL_COL_NAME, RowNum]   := AQuery.FieldByName('cv_name').AsString;
    AGrid.Cells[MDL_COL_TYPE, RowNum]   := AQuery.FieldByName('cv_type').AsString;
    AGrid.Cells[MDL_COL_WIDTH, RowNum]  := AQuery.FieldByName('ni_width').AsString;
    AGrid.Cells[MDL_COL_HEIGHT, RowNum] := AQuery.FieldByName('ni_height').AsString;
    Inc(RowNum);
    AQuery.Next;
  end;

  AQuery.Close;
end;

procedure SelectMdlRow(AGrid: TStringGrid; ARow: Integer;
  AEditName, AEditType, AEditWidth, AEditHeight: TEdit);
begin
  if not IsMdlGridCellValid(AGrid, MDL_COL_HEIGHT, ARow) then
    Exit;

  if Assigned(AEditName) then
    AEditName.Text := AGrid.Cells[MDL_COL_NAME, ARow];
  if Assigned(AEditType) then
    AEditType.Text := AGrid.Cells[MDL_COL_TYPE, ARow];
  if Assigned(AEditWidth) then
    AEditWidth.Text := AGrid.Cells[MDL_COL_WIDTH, ARow];
  if Assigned(AEditHeight) then
    AEditHeight.Text := AGrid.Cells[MDL_COL_HEIGHT, ARow];
end;

procedure ClearMdlEdits(
  AEditName, AEditType, AEditWidth, AEditHeight: TEdit
);
begin
  AEditName.Clear;
  AEditType.Clear;
  AEditWidth.Clear;
  AEditHeight.Clear;
end;

procedure SetNullableIntParam(AQuery: TSQLQuery; const ParamName, TextValue: string);
begin
  if Trim(TextValue) = '' then
    AQuery.Params.ParamByName(ParamName).Clear
  else
    AQuery.Params.ParamByName(ParamName).AsInteger := StrToInt(TextValue);
end;

procedure LoadImageToParam(AQuery: TSQLQuery; const ParamName, AImagePath: string);
var
  FS: TFileStream;
begin
  if not FileExists(AImagePath) then
    raise Exception.Create('Файл изображения не найден: ' + AImagePath);

  FS := TFileStream.Create(AImagePath, fmOpenRead or fmShareDenyWrite);
  try
    AQuery.Params.ParamByName(ParamName).LoadFromStream(FS, ftBlob);
  finally
    FS.Free;
  end;
end;

function GetSelectedMdlId(AGrid: TStringGrid): Integer;
begin
  if AGrid = nil then
    raise Exception.Create('Выберите запись в таблице');

  if not IsMdlGridCellValid(AGrid, MDL_COL_ID, AGrid.Row) then
    raise Exception.Create('Выберите запись в таблице');

  if Trim(AGrid.Cells[MDL_COL_ID, AGrid.Row]) = '' then
    raise Exception.Create('Не удалось определить ID выбранной записи');

  Result := StrToInt(AGrid.Cells[MDL_COL_ID, AGrid.Row]);
end;

procedure AddMdl(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditName, AEditType, AEditWidth, AEditHeight: TEdit;
  const AImagePath: string);
begin
  if Trim(AEditName.Text) = '' then
    raise Exception.Create('Введите название');

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'INSERT INTO sc_accac."tb_MDL" ' +
      '("cv_name", "cv_type", "bh_img", "ni_width", "ni_height") ' +
      'VALUES (:p_name, :p_type, :p_img, :p_width, :p_height)';

    AQuery.Params.ParamByName('p_name').AsString := Trim(AEditName.Text);
    AQuery.Params.ParamByName('p_type').AsString := Trim(AEditType.Text);

    SetNullableIntParam(AQuery, 'p_width', AEditWidth.Text);
    SetNullableIntParam(AQuery, 'p_height', AEditHeight.Text);

    if Trim(AImagePath) = '' then
      AQuery.Params.ParamByName('p_img').Clear
    else
      LoadImageToParam(AQuery, 'p_img', AImagePath);

    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadMdlData(AQuery, AGrid);

    ClearMdlEdits(AEditName, AEditType, AEditWidth, AEditHeight);
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

procedure EditMdl(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditName, AEditType, AEditWidth, AEditHeight: TEdit;
  const AImagePath: string);
var
  MdlId: Integer;
begin
  if Trim(AEditName.Text) = '' then
    raise Exception.Create('Введите название');

  MdlId := GetSelectedMdlId(AGrid);

  try
    AQuery.Close;

    if Trim(AImagePath) = '' then
    begin
      AQuery.SQL.Text :=
        'UPDATE sc_accac."tb_MDL" SET ' +
        '"cv_name" = :p_name, ' +
        '"cv_type" = :p_type, ' +
        '"ni_width" = :p_width, ' +
        '"ni_height" = :p_height ' +
        'WHERE "ni_id" = :p_id';
    end
    else
    begin
      AQuery.SQL.Text :=
        'UPDATE sc_accac."tb_MDL" SET ' +
        '"cv_name" = :p_name, ' +
        '"cv_type" = :p_type, ' +
        '"bh_img" = :p_img, ' +
        '"ni_width" = :p_width, ' +
        '"ni_height" = :p_height ' +
        'WHERE "ni_id" = :p_id';
    end;

    AQuery.Params.ParamByName('p_id').AsInteger := MdlId;
    AQuery.Params.ParamByName('p_name').AsString := Trim(AEditName.Text);
    AQuery.Params.ParamByName('p_type').AsString := Trim(AEditType.Text);

    SetNullableIntParam(AQuery, 'p_width', AEditWidth.Text);
    SetNullableIntParam(AQuery, 'p_height', AEditHeight.Text);

    if Trim(AImagePath) <> '' then
      LoadImageToParam(AQuery, 'p_img', AImagePath);

    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadMdlData(AQuery, AGrid);
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

procedure DeleteMdl(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditName, AEditType, AEditWidth, AEditHeight: TEdit);
var
  MdlId: Integer;
begin
  MdlId := GetSelectedMdlId(AGrid);

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'DELETE FROM sc_accac."tb_MDL" WHERE "ni_id" = :p_id';
    AQuery.Params.ParamByName('p_id').AsInteger := MdlId;
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadMdlData(AQuery, AGrid);

    ClearMdlEdits(AEditName, AEditType, AEditWidth, AEditHeight);
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
