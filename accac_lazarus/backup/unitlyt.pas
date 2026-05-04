unit UnitLyt;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SQLDB, Grids, StdCtrls;

procedure SetupLytGrid(AGrid: TStringGrid);
procedure LoadLytData(AQuery: TSQLQuery; AGrid: TStringGrid);
procedure SelectLytRow(AGrid: TStringGrid; ARow: Integer; AEditId, AEditName: TEdit);

procedure AddLyt(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditId, AEditName: TEdit
);

procedure EditLyt(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditId, AEditName: TEdit
);

procedure DeleteLyt(
  AQuery: TSQLQuery;
  ATransaction: TSQLTransaction;
  AGrid: TStringGrid;
  AEditId, AEditName: TEdit
);

implementation

procedure SetupLytGrid(AGrid: TStringGrid);
begin
  AGrid.ColCount := 2;
  AGrid.RowCount := 1;
  AGrid.FixedRows := 1;
  AGrid.FixedCols := 0;

  AGrid.Cells[0, 0] := 'ID';
  AGrid.Cells[1, 0] := 'ÐÐ°Ð·Ð²Ð°Ð½Ð¸Ðµ';

  AGrid.ColWidths[0] := 80;
  AGrid.ColWidths[1] := 300;
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
    AGrid.Cells[0, RowNum] := AQuery.FieldByName('ni_id').AsString;
    AGrid.Cells[1, RowNum] := AQuery.FieldByName('cv_name').AsString;
    Inc(RowNum);
    AQuery.Next;
  end;

  AQuery.Close;
end;

procedure SelectLytRow(AGrid: TStringGrid; ARow: Integer; AEditId, AEditName: TEdit);
begin
  if ARow <= 0 then Exit;
  AEditId.Text := AGrid.Cells[0, ARow];
  AEditName.Text := AGrid.Cells[1, ARow];
end;

procedure AddLyt(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditId, AEditName: TEdit);
begin
  if Trim(AEditId.Text) = '' then raise Exception.Create('Ð’Ð²ÐµÐ´Ð¸Ñ‚Ðµ ID');
  if Trim(AEditName.Text) = '' then raise Exception.Create('Ð’Ð²ÐµÐ´Ð¸Ñ‚Ðµ Ð½Ð°Ð·Ð²Ð°Ð½Ð¸Ðµ');

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'INSERT INTO sc_accac."tb_LYT" ("ni_id", "cv_name") ' +
      'VALUES (:p_id, :p_name)';
    AQuery.Params.ParamByName('p_id').AsInteger := StrToInt(AEditId.Text);
    AQuery.Params.ParamByName('p_name').AsString := Trim(AEditName.Text);
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadLytData(AQuery, AGrid);

    AEditId.Clear;
    AEditName.Clear;
  except
    on E: Exception do
    begin
      if ATransaction.Active then ATransaction.Rollback;
      ATransaction.StartTransaction;
      raise Exception.Create('ÐžÑˆÐ¸Ð±ÐºÐ° Ð´Ð¾Ð±Ð°Ð²Ð»ÐµÐ½Ð¸Ñ: ' + E.Message);
    end;
  end;
end;

procedure EditLyt(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditId, AEditName: TEdit);
begin
  if Trim(AEditId.Text) = '' then raise Exception.Create('Ð’Ð²ÐµÐ´Ð¸Ñ‚Ðµ ID');
  if Trim(AEditName.Text) = '' then raise Exception.Create('Ð’Ð²ÐµÐ´Ð¸Ñ‚Ðµ Ð½Ð°Ð·Ð²Ð°Ð½Ð¸Ðµ');

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'UPDATE sc_accac."tb_LYT" ' +
      'SET "cv_name" = :p_name ' +
      'WHERE "ni_id" = :p_id';
    AQuery.Params.ParamByName('p_id').AsInteger := StrToInt(AEditId.Text);
    AQuery.Params.ParamByName('p_name').AsString := Trim(AEditName.Text);
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadLytData(AQuery, AGrid);
  except
    on E: Exception do
    begin
      if ATransaction.Active then ATransaction.Rollback;
      ATransaction.StartTransaction;
      raise Exception.Create('ÐžÑˆÐ¸Ð±ÐºÐ° Ð¸Ð·Ð¼ÐµÐ½ÐµÐ½Ð¸Ñ: ' + E.Message);
    end;
  end;
end;

procedure DeleteLyt(AQuery: TSQLQuery; ATransaction: TSQLTransaction; AGrid: TStringGrid;
  AEditId, AEditName: TEdit);
begin
  if Trim(AEditId.Text) = '' then raise Exception.Create('Ð’Ð²ÐµÐ´Ð¸Ñ‚Ðµ ID Ð·Ð°Ð¿Ð¸ÑÐ¸ Ð´Ð»Ñ ÑƒÐ´Ð°Ð»ÐµÐ½Ð¸Ñ');

  try
    AQuery.Close;
    AQuery.SQL.Text :=
      'DELETE FROM sc_accac."tb_LYT" WHERE "ni_id" = :p_id';
    AQuery.Params.ParamByName('p_id').AsInteger := StrToInt(AEditId.Text);
    AQuery.ExecSQL;

    ATransaction.Commit;
    ATransaction.StartTransaction;
    LoadLytData(AQuery, AGrid);

    AEditId.Clear;
    AEditName.Clear;
  except
    on E: Exception do
    begin
      if ATransaction.Active then ATransaction.Rollback;
      ATransaction.StartTransaction;
      raise Exception.Create('ÐžÑˆÐ¸Ð±ÐºÐ° ÑƒÐ´Ð°Ð»ÐµÐ½Ð¸Ñ: ' + E.Message);
    end;
  end;
end;

end.
