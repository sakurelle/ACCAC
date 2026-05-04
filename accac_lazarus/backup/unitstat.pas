unit UnitStat;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SQLDB, Grids, StdCtrls;

procedure SetupStatGrid(AGrid: TStringGrid);
procedure LoadStatData(AQuery: TSQLQuery; AGrid: TStringGrid);
procedure SelectStatRow(AGrid: TStringGrid; ARow: Integer; AEditId, AEditName, AEditColor: TEdit);

procedure AddStat(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditId, AEditName, AEditColor: TEdit
);

procedure EditStat(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditId, AEditName, AEditColor: TEdit
);

procedure DeleteStat(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditId, AEditName, AEditColor: TEdit
);

implementation

procedure SetupStatGrid(AGrid: TStringGrid);
begin
  AGrid.ColCount := 3;
  AGrid.RowCount := 1;
  AGrid.FixedRows := 1;
  AGrid.FixedCols := 0;

  AGrid.Cells[0, 0] := 'ID';
  AGrid.Cells[1, 0] := 'Н';
  AGrid.Cells[2, 0] := 'Цвет';

  AGrid.ColWidths[0] := 80;
  AGrid.ColWidths[1] := 250;
  AGrid.ColWidths[2] := 80;
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
    AGrid.Cells[0, RowNum] := AQuery.FieldByName('ni_id').AsString;
    AGrid.Cells[1, RowNum] := AQuery.FieldByName('cv_name').AsString;
    AGrid.Cells[2, RowNum] := AQuery.FieldByName('cv_color').AsString;
    Inc(RowNum);
    AQuery.Next;
  end;

  AQuery.Close;
end;

procedure SelectStatRow(AGrid: TStringGrid; ARow: Integer; AEditId, AEditName, AEditColor: TEdit);
begin
  if ARow <= 0 then Exit;
  AEditId.Text := AGrid.Cells[0, ARow];
  AEditName.Text := AGrid.Cells[1, ARow];
  AEditColor.Text := AGrid.Cells[2, ARow];
end;

procedure AddStat(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditId, AEditName, AEditColor: TEdit);
begin
  if Trim(AEditId.Text) = '' then raise Exception.Create('Введите ID');
  if Trim(AEditName.Text) = '' then raise Exception.Create('Введите название');
  if Trim(AEditColor.Text) = '' then raise Exception.Create('Введите цвет');

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'INSERT INTO sc_accac."tb_STAT" ("ni_id", "cv_name", "cv_color") ' +
      'VALUES (:p_id, :p_name, :p_color)';
    AQuery.Params.ParamByName('p_id').AsInteger := StrToInt(AEditId.Text);
    AQuery.Params.ParamByName('p_name').AsString := Trim(AEditName.Text);
    AQuery.Params.ParamByName('p_color').AsInteger := StrToInt(AEditColor.Text);
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadStatData(AQuery, AGrid);

    AEditId.Clear;
    AEditName.Clear;
    AEditColor.Clear;
  except
    on E: Exception do
    begin
      if ATransaction.Active then ATransaction.Rollback;
      ATransaction.StartTransaction;
      raise Exception.Create('Ошибка добавления: ' + E.Message);
    end;
  end;
end;

procedure EditStat(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditId, AEditName, AEditColor: TEdit);
begin
  if Trim(AEditId.Text) = '' then raise Exception.Create('Введите ID');
  if Trim(AEditName.Text) = '' then raise Exception.Create('Введите название');
  if Trim(AEditColor.Text) = '' then raise Exception.Create('Введите цвет');

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'UPDATE sc_accac."tb_STAT" ' +
      'SET "cv_name" = :p_name, "cv_color" = :p_color ' +
      'WHERE "ni_id" = :p_id';
    AQuery.Params.ParamByName('p_id').AsInteger := StrToInt(AEditId.Text);
    AQuery.Params.ParamByName('p_name').AsString := Trim(AEditName.Text);
    AQuery.Params.ParamByName('p_color').AsInteger := StrToInt(AEditColor.Text);
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadStatData(AQuery, AGrid);
  except
    on E: Exception do
    begin
      if ATransaction.Active then ATransaction.Rollback;
      ATransaction.StartTransaction;
      raise Exception.Create('Ошибка изменения: ' + E.Message);
    end;
  end;
end;

procedure DeleteStat(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditId, AEditName, AEditColor: TEdit);
begin
  if Trim(AEditId.Text) = '' then raise Exception.Create('Введите ID записи для удаления');

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'DELETE FROM sc_accac."tb_STAT" WHERE "ni_id" = :p_id';
    AQuery.Params.ParamByName('p_id').AsInteger := StrToInt(AEditId.Text);
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadStatData(AQuery, AGrid);

    AEditId.Clear;
    AEditName.Clear;
    AEditColor.Clear;
  except
    on E: Exception do
    begin
      if ATransaction.Active then ATransaction.Rollback;
      ATransaction.StartTransaction;
      raise Exception.Create('Ошибка удаления: ' + E.Message);
    end;
  end;
end;

end.
