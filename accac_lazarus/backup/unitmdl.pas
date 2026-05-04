unit UnitMdl;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, DB, SQLDB, Grids, StdCtrls;

procedure SetupMdlGrid(AGrid: TStringGrid);
procedure LoadMdlData(AQuery: TSQLQuery; AGrid: TStringGrid);
procedure SelectMdlRow(
  AGrid: TStringGrid; ARow: Integer;
  AEditId, AEditName, AEditType, AEditFormat, AEditWidth, AEditHeight: TEdit
);

procedure AddMdl(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditId, AEditName, AEditType, AEditFormat, AEditWidth, AEditHeight: TEdit;
  const AImagePath: string
);

procedure EditMdl(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditId, AEditName, AEditType, AEditFormat, AEditWidth, AEditHeight: TEdit;
  const AImagePath: string
);

procedure DeleteMdl(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditId, AEditName, AEditType, AEditFormat, AEditWidth, AEditHeight: TEdit
);

implementation

procedure SetupMdlGrid(AGrid: TStringGrid);
begin
  AGrid.ColCount := 6;
  AGrid.RowCount := 1;
  AGrid.FixedRows := 1;
  AGrid.FixedCols := 0;

  AGrid.Cells[0, 0] := 'ID';
  AGrid.Cells[1, 0] := 'Название';
  AGrid.Cells[2, 0] := 'Тип';
  AGrid.Cells[3, 0] := 'Формат';
  AGrid.Cells[4, 0] := 'Ширина';
  AGrid.Cells[5, 0] := 'Высота';

  AGrid.ColWidths[0] := 70;
  AGrid.ColWidths[1] := 220;
  AGrid.ColWidths[2] := 140;
  AGrid.ColWidths[3] := 100;
  AGrid.ColWidths[4] := 80;
  AGrid.ColWidths[5] := 80;
end;

procedure LoadMdlData(AQuery: TSQLQuery; AGrid: TStringGrid);
var
  RowNum: Integer;
begin
  AQuery.Close;
  AQuery.SQL.Text :=
    'SELECT "ni_id", "cv_name", "cv_type", "cv_img_format", "ni_width", "ni_height" ' +
    'FROM sc_accac."tb_MDL" ' +
    'ORDER BY "ni_id"';
  AQuery.Open;

  AGrid.RowCount := 1;
  RowNum := 1;

  while not AQuery.EOF do
  begin
    AGrid.RowCount := RowNum + 1;
    AGrid.Cells[0, RowNum] := AQuery.FieldByName('ni_id').AsString;
    AGrid.Cells[1, RowNum] := AQuery.FieldByName('cv_name').AsString;
    AGrid.Cells[2, RowNum] := AQuery.FieldByName('cv_type').AsString;
    AGrid.Cells[3, RowNum] := AQuery.FieldByName('cv_img_format').AsString;
    AGrid.Cells[4, RowNum] := AQuery.FieldByName('ni_width').AsString;
    AGrid.Cells[5, RowNum] := AQuery.FieldByName('ni_height').AsString;
    Inc(RowNum);
    AQuery.Next;
  end;

  AQuery.Close;
end;

procedure SelectMdlRow(AGrid: TStringGrid; ARow: Integer;
  AEditId, AEditName, AEditType, AEditFormat, AEditWidth, AEditHeight: TEdit);
begin
  if ARow <= 0 then Exit;

  AEditId.Text := AGrid.Cells[0, ARow];
  AEditName.Text := AGrid.Cells[1, ARow];
  AEditType.Text := AGrid.Cells[2, ARow];
  AEditFormat.Text := AGrid.Cells[3, ARow];
  AEditWidth.Text := AGrid.Cells[4, ARow];
  AEditHeight.Text := AGrid.Cells[5, ARow];
end;

procedure ClearMdlEdits(
  AEditId, AEditName, AEditType, AEditFormat, AEditWidth, AEditHeight: TEdit
);
begin
  AEditId.Clear;
  AEditName.Clear;
  AEditType.Clear;
  AEditFormat.Clear;
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

procedure AddMdl(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditId, AEditName, AEditType, AEditFormat, AEditWidth, AEditHeight: TEdit;
  const AImagePath: string);
begin
  if Trim(AEditId.Text) = '' then
    raise
Exception.Create('Введите ID');

  if Trim(AEditName.Text) = '' then
    raise Exception.Create('Введите название');

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'INSERT INTO sc_accac."tb_MDL" ' +
      '("ni_id", "cv_name", "cv_type", "bh_img", "cv_img_format", "ni_width", "ni_height") ' +
      'VALUES (:p_id, :p_name, :p_type, :p_img, :p_format, :p_width, :p_height)';

    AQuery.Params.ParamByName('p_id').AsInteger := StrToInt(AEditId.Text);
    AQuery.Params.ParamByName('p_name').AsString := Trim(AEditName.Text);
    AQuery.Params.ParamByName('p_type').AsString := Trim(AEditType.Text);
    AQuery.Params.ParamByName('p_format').AsString := Trim(AEditFormat.Text);

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

    ClearMdlEdits(AEditId, AEditName, AEditType, AEditFormat, AEditWidth, AEditHeight);
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
  AEditId, AEditName, AEditType, AEditFormat, AEditWidth, AEditHeight: TEdit;
  const AImagePath: string);
begin
  if Trim(AEditId.Text) = '' then
    raise Exception.Create('Введите ID');

  if Trim(AEditName.Text) = '' then
    raise Exception.Create('Введите название');

  try
    AQuery.Close;

    if Trim(AImagePath) = '' then
    begin
      AQuery.SQL.Text :=
        'UPDATE sc_accac."tb_MDL" SET ' +
        '"cv_name" = :p_name, ' +
        '"cv_type" = :p_type, ' +
        '"cv_img_format" = :p_format, ' +
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
        '"cv_img_format" = :p_format, ' +
        '"ni_width" = :p_width, ' +
        '"ni_height" = :p_height ' +
        'WHERE "ni_id" = :p_id';
    end;

    AQuery.Params.ParamByName('p_id').AsInteger := StrToInt(AEditId.Text);
    AQuery.Params.ParamByName('p_name').AsString := Trim(AEditName.Text);
    AQuery.Params.ParamByName('p_type').AsString := Trim(AEditType.Text);
    AQuery.Params.ParamByName('p_format').AsString := Trim(AEditFormat.Text);

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
  AEditId, AEditName, AEditType, AEditFormat, AEditWidth, AEditHeight: TEdit);
begin
  if Trim(AEditId.Text) = '' then
    raise Exception.Create('Введите ID записи для удаления');

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'DELETE FROM sc_accac."tb_MDL" WHERE "ni_id" = :p_id';
    AQuery.Params.ParamByName('p_id').AsInteger := StrToInt(AEditId.Text);
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadMdlData(AQuery, AGrid);

    ClearMdlEdits(AEditId, AEditName, AEditType, AEditFormat, AEditWidth, AEditHeight);
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
