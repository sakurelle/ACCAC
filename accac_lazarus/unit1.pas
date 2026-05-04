unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB, SQLDB, PQConnection, Forms, Controls,
  Graphics, Dialogs, StdCtrls, Types, ExtCtrls;

type
  { TFormMain }

  TFormMain = class(TForm)
    PQConnection1: TPQConnection;
    SQLQuery1: TSQLQuery;
    SQLTransaction1: TSQLTransaction;
    procedure FormCreate(Sender: TObject);
    procedure FormPaint(Sender: TObject);
  private
    FCurrentLayoutId: Integer;
    FScrollBox: TScrollBox;
    FPaintBox: TPaintBox;

    procedure CreateScrollArea;
    procedure RefreshMap;
    procedure UpdatePaintBoxSize;
    procedure PaintBoxPaint(Sender: TObject);

    procedure DrawDefaultAntenna(ACanvas: TCanvas; AX, AY, AW, AH: Integer);
    procedure DrawAntennaFromBlob(ACanvas: TCanvas; ABlobField: TField; AX, AY, AW, AH: Integer);
  public
    procedure SetCurrentLayout(ALayoutId: Integer);
  end;

var
  FormMain: TFormMain;

implementation

uses
  UnitDb, UnitMenu;

{$R *.lfm}

const
  MIN_MAP_WIDTH = 1000;
  MIN_MAP_HEIGHT = 715;
  MAP_MARGIN = 40;

procedure TFormMain.CreateScrollArea;
begin
  if Assigned(FScrollBox) then
    Exit;

  FScrollBox := TScrollBox.Create(Self);
  FScrollBox.Parent := Self;
  FScrollBox.Align := alClient;
  FScrollBox.HorzScrollBar.Visible := True;
  FScrollBox.VertScrollBar.Visible := True;
  FScrollBox.HorzScrollBar.Tracking := True;
  FScrollBox.VertScrollBar.Tracking := True;

  FPaintBox := TPaintBox.Create(Self);
  FPaintBox.Parent := FScrollBox;
  FPaintBox.Left := 0;
  FPaintBox.Top := 0;
  FPaintBox.Width := MIN_MAP_WIDTH;
  FPaintBox.Height := MIN_MAP_HEIGHT;
  FPaintBox.OnPaint := @PaintBoxPaint;
end;

procedure TFormMain.UpdatePaintBoxSize;
var
  NewWidth, NewHeight: Integer;
  DbWidth, DbHeight: Integer;
begin
  if not Assigned(FPaintBox) then
    Exit;

  NewWidth := MIN_MAP_WIDTH;
  NewHeight := MIN_MAP_HEIGHT;

  if Assigned(FScrollBox) then
  begin
    if FScrollBox.ClientWidth > NewWidth then
      NewWidth := FScrollBox.ClientWidth;

    if FScrollBox.ClientHeight > NewHeight then
      NewHeight := FScrollBox.ClientHeight;
  end;

  if PQConnection1.Connected then
  begin
    SQLQuery1.Close;
    SQLQuery1.SQL.Text :=
      'SELECT COALESCE(MAX("ni_x" + "ni_width"), 0) AS "map_width", ' +
      '       COALESCE(MAX("ni_y" + "ni_height"), 0) AS "map_height" ' +
      'FROM sc_accac."tb_CMP" ' +
      'WHERE "bl_visible" = TRUE ' +
      '  AND "ni_LYT_id" = :p_lyt';

    SQLQuery1.Params.ParamByName('p_lyt').AsInteger := FCurrentLayoutId;

    try
      SQLQuery1.Open;

      DbWidth := SQLQuery1.FieldByName('map_width').AsInteger + MAP_MARGIN;
      DbHeight := SQLQuery1.FieldByName('map_height').AsInteger + MAP_MARGIN;

      if DbWidth > NewWidth then
        NewWidth := DbWidth;

      if DbHeight > NewHeight then
        NewHeight := DbHeight;
    finally
      SQLQuery1.Close;
    end;
  end;

  if FPaintBox.Width <> NewWidth then
    FPaintBox.Width := NewWidth;

  if FPaintBox.Height <> NewHeight then
    FPaintBox.Height := NewHeight;
end;

procedure TFormMain.RefreshMap;
begin
  try
    UpdatePaintBoxSize;

    if Assigned(FPaintBox) then
      FPaintBox.Invalidate;
  except
    on E: Exception do
      ShowMessage('Ошибка обновления окна: ' + E.Message);
  end;
end;

procedure TFormMain.DrawDefaultAntenna(ACanvas: TCanvas; AX, AY, AW, AH: Integer);
begin
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := clSilver;
  ACanvas.Pen.Color := clWhite;
  ACanvas.Rectangle(AX, AY, AX + AW, AY + AH);
end;

procedure TFormMain.DrawAntennaFromBlob(ACanvas: TCanvas; ABlobField: TField; AX, AY, AW, AH: Integer);
var
  BlobStream: TStream;
  MemStream: TMemoryStream;
  Png: TPortableNetworkGraphic;
begin
  if (ABlobField = nil) or ABlobField.IsNull or (AW <= 0) or (AH <= 0) then
  begin
    DrawDefaultAntenna(ACanvas, AX, AY, AW, AH);
    Exit;
  end;

  MemStream := TMemoryStream.Create;
  BlobStream := nil;
  Png := nil;

  try
    try
      BlobStream := SQLQuery1.CreateBlobStream(ABlobField, bmRead);
      MemStream.CopyFrom(BlobStream, 0);
      MemStream.Position := 0;

      if MemStream.Size = 0 then
      begin
        DrawDefaultAntenna(ACanvas, AX, AY, AW, AH);
        Exit;
      end;

      Png := TPortableNetworkGraphic.Create;
      Png.LoadFromStream(MemStream);

      ACanvas.StretchDraw(Rect(AX, AY, AX + AW, AY + AH), Png);
      ACanvas.Brush.Style := bsClear;
      ACanvas.Pen.Color := clWhite;
      ACanvas.Rectangle(AX, AY, AX + AW, AY + AH);
    except
      DrawDefaultAntenna(ACanvas, AX, AY, AW, AH);
    end;
  finally
    Png.Free;
    BlobStream.Free;
    MemStream.Free;
  end;
end;

procedure TFormMain.SetCurrentLayout(ALayoutId: Integer);
begin
  FCurrentLayoutId := ALayoutId;
  RefreshMap;
end;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  CreateScrollArea;

  try
    ConnectToDatabase(PQConnection1, SQLTransaction1, SQLQuery1);

    { макет по умолчанию }
    FCurrentLayoutId := 1;
    RefreshMap;

    { автоматически создаем и показываем форму меню }
    if not Assigned(FormMenu) then
      Application.CreateForm(TFormMenu, FormMenu);

    FormMenu.Show;
  except
    on E: Exception do
      ShowMessage('Ошибка подключения: ' + E.Message);
  end;
end;

procedure TFormMain.FormPaint(Sender: TObject);
begin
  RefreshMap;
end;

procedure TFormMain.PaintBoxPaint(Sender: TObject);
var
  C: TCanvas;
  vType, vText: string;
  x, y, w, h: Integer;
  vColorCode: Integer;
  ImgField: TField;
begin
  if not Assigned(FPaintBox) then
    Exit;

  C := FPaintBox.Canvas;

  C.Brush.Style := bsSolid;
  C.Brush.Color := clWhite;
  C.FillRect(Rect(0, 0, FPaintBox.Width, FPaintBox.Height));

  try
    if not PQConnection1.Connected then
      Exit;

    SQLQuery1.Close;
    SQLQuery1.SQL.Text :=
      'SELECT c."cv_type", c."ni_x", c."ni_y", c."ni_width", c."ni_height", c."cv_text", ' +
      ' mdl."bh_img", ' +
      ' COALESCE(st."cv_color", 4) AS "stat_color" ' +
      'FROM sc_accac."tb_CMP" c ' +
      'LEFT JOIN sc_accac."tb_ANT" ant ON ant."ni_id" = c."ni_ANT_id" ' +
      'LEFT JOIN sc_accac."tb_MDL" mdl ON mdl."ni_id" = ant."ni_MDL_id" ' +
      'LEFT JOIN sc_accac."tb_STAT" st ON st."ni_id" = ant."ni_STAT_id" ' +
      'WHERE c."bl_visible" = TRUE ' +
      ' AND c."ni_LYT_id" = :p_lyt ' +
      'ORDER BY c."ni_id"';

    SQLQuery1.Params.ParamByName('p_lyt').AsInteger := FCurrentLayoutId;
    SQLQuery1.Open;

    while not SQLQuery1.EOF do
    begin
      vType := SQLQuery1.FieldByName('cv_type').AsString;
      x := SQLQuery1.FieldByName('ni_x').AsInteger;
      y := SQLQuery1.FieldByName('ni_y').AsInteger;
      w := SQLQuery1.FieldByName('ni_width').AsInteger;
      h := SQLQuery1.FieldByName('ni_height').AsInteger;
      vText := SQLQuery1.FieldByName('cv_text').AsString;
      vColorCode := SQLQuery1.FieldByName('stat_color').AsInteger;
      ImgField := SQLQuery1.FieldByName('bh_img');

      if vType = 'title' then
      begin
        C.Brush.Style := bsClear;
        C.Font.Color := clBlack;
        C.Font.Size := 17;
        C.Font.Style := [fsBold];
        C.Font.Orientation := 0;
        C.TextOut(x, y, vText);
      end
      else if vType = 'rectangle_header' then
      begin
        C.Brush.Style := bsSolid;
        C.Brush.Color := $8F4A2E;
        C.Pen.Color := $8F4A2E;
        C.Rectangle(x, y, x + w, y + h);
      end
      else if vType = 'header' then
      begin
        C.Brush.Style := bsClear;
        C.Font.Color := clBlack;
        C.Font.Size := 16;
        C.Font.Style := [];
        C.Font.Orientation := 0;
        C.TextOut(x, y, vText);
      end
      else if vType = 'rectangle_city' then
      begin
        C.Brush.Style := bsClear;
        C.Pen.Color := clWhite;
        C.Rectangle(x, y, x + w, y + h);
      end
      else if vType = 'city' then
      begin
        C.Brush.Style := bsClear;
        C.Font.Color := clWhite;
        C.Font.Size := 10;
        C.Font.Style := [];
        C.Font.Orientation := 900;
        C.TextOut(x, y, vText);
        C.Font.Orientation := 0;
      end
      else if vType = 'rectangle_antenna' then
      begin
        DrawAntennaFromBlob(C, ImgField, x, y, w, h);
      end
      else if vType = 'antenna_text' then
      begin
        C.Brush.Style := bsClear;

        case vColorCode of
          1: C.Font.Color := clLime;
          2: C.Font.Color := clRed;
          3: C.Font.Color := clYellow;
          4: C.Font.Color := clSilver;
        else
          C.Font.Color := clWhite;
        end;

        C.Font.Size := 7;
        C.Font.Style := [];
        C.Font.Orientation := 0;
        C.TextOut(x, y, vText);
      end;

      SQLQuery1.Next;
    end;

    SQLQuery1.Close;
  except
    on E: Exception do
      ShowMessage('Ошибка отрисовки: ' + E.Message);
  end;
end;

end.
