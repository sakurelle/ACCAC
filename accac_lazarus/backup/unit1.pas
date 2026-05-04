unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB, SQLDB, PQConnection, Forms, Controls,
  Graphics, Dialogs, StdCtrls, Types;

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
    procedure DrawDefaultAntenna(AX, AY, AW, AH: Integer);
    procedure DrawAntennaFromBlob(ABlobField: TField; AX, AY, AW, AH: Integer);
  public
    procedure SetCurrentLayout(ALayoutId: Integer);
  end;

var
  FormMain: TFormMain;

implementation

uses
  UnitDb, UnitMenu;

{$R *.lfm}

procedure TFormMain.DrawDefaultAntenna(AX, AY, AW, AH: Integer);
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := clSilver;
  Canvas.Pen.Color := clWhite;
  Canvas.Rectangle(AX, AY, AX + AW, AY + AH);
end;

procedure TFormMain.DrawAntennaFromBlob(ABlobField: TField; AX, AY, AW, AH: Integer);
var
  BlobStream: TStream;
  MemStream: TMemoryStream;
  Png: TPortableNetworkGraphic;
begin
  if (ABlobField = nil) or ABlobField.IsNull or (AW <= 0) or (AH <= 0) then
  begin
    DrawDefaultAntenna(AX, AY, AW, AH);
    Exit;
  end;

  MemStream := TMemoryStream.Create;
  BlobStream := nil;
  Png := nil;

  try
    BlobStream := SQLQuery1.CreateBlobStream(ABlobField, bmRead);
    MemStream.CopyFrom(BlobStream, 0);
    MemStream.Position := 0;

    if MemStream.Size = 0 then
    begin
      DrawDefaultAntenna(AX, AY, AW, AH);
      Exit;
    end;

    Png := TPortableNetworkGraphic.Create;
    Png.LoadFromStream(MemStream);

    Canvas.StretchDraw(Rect(AX, AY, AX + AW, AY + AH), Png);

    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := clWhite;
    Canvas.Rectangle(AX, AY, AX + AW, AY + AH);
  except
    DrawDefaultAntenna(AX, AY, AW, AH);
  end;

  Png.Free;
  BlobStream.Free;
  MemStream.Free;
end;

procedure TFormMain.SetCurrentLayout(ALayoutId: Integer);
begin
  FCurrentLayoutId := ALayoutId;
  Invalidate;
end;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  try
    ConnectToDatabase(PQConnection1, SQLTransaction1, SQLQuery1);

    { макет по умолчанию }
    FCurrentLayoutId := 1;

    Invalidate;

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
var
  vType, vText: string;
  x, y, w, h: Integer;
  vColorCode: Integer;
  ImgField: TField;
begin
  Canvas.Brush.Color := clWhite;
  Canvas.FillRect(ClientRect);

  try
    if not PQConnection1.Connected then
      Exit;

    SQLQuery1.Close;
    SQLQuery1.SQL.Text :=
      'SELECT c."cv_type", c."ni_x", c."ni_y", c."ni_width", c."ni_height", c."cv_text", ' +
      '       mdl."bh_img", ' +
      '       COALESCE(st."cv_color", 4) AS "stat_color" ' +
      'FROM sc_accac."tb_CMP" c ' +
      'LEFT JOIN sc_accac."tb_ANT" ant ON ant."ni_id" = c."ni_ANT_id" ' +
      'LEFT JOIN sc_accac."tb_MDL" mdl ON mdl."ni_id" = ant."ni_MDL_id" ' +
      'LEFT JOIN sc_accac."tb_STAT" st ON st."ni_id" = ant."ni_STAT_id" ' +
      'WHERE c."bl_visible" = TRUE ' +
      '  AND c."ni_LYT_id" = :p_lyt ' +
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
        Canvas.Brush.Style := bsClear;
        Canvas.Font.Color := clBlack;
        Canvas.Font.Size := 17;
        Canvas.Font.Style := [fsBold];
        Canvas.Font.Orientation := 0;
        Canvas.TextOut(x, y, vText);
      end
      else if vType = 'rectangle_header' then
      begin
        Canvas.Brush.Style := bsSolid;
        Canvas.Brush.Color := $8F4A2E;
        Canvas.Pen.Color := $8F4A2E;
        Canvas.Rectangle(x, y, x + w, y + h);
      end
      else if vType = 'header' then
      begin
        Canvas.Brush.Style := bsClear;
        Canvas.Font.Color := clBlack;
        Canvas.Font.Size := 16;
        Canvas.Font.Style := [];
        Canvas.Font.Orientation := 0;
        Canvas.TextOut(x, y, vText);
      end
      else if vType = 'rectangle_city' then
      begin
        Canvas.Brush.Style := bsClear;
        Canvas.Pen.Color := clWhite;
        Canvas.Rectangle(x, y, x + w, y + h);
      end
      else if vType = 'city' then
      begin
        Canvas.Brush.Style := bsClear;
        Canvas.Font.Color := clWhite;
        Canvas.Font.Size := 10;
        Canvas.Font.Style := [];
        Canvas.Font.Orientation := 900;
        Canvas.TextOut(x, y, vText);
        Canvas.Font.Orientation := 0;
      end
      else if vType = 'rectangle_antenna' then
      begin
        DrawAntennaFromBlob(ImgField, x, y, w, h);
      end
      else if vType = 'antenna_text' then
      begin
        Canvas.Brush.Style := bsClear;

        case vColorCode of
          1: Canvas.Font.Color := clLime;
          2: Canvas.Font.Color := clRed;
          3: Canvas.Font.Color := clYellow;
          4: Canvas.Font.Color := clSilver;
        else
          Canvas.Font.Color := clWhite;
        end;

        Canvas.Font.Size := 7;
        Canvas.Font.Style := [];
        Canvas.Font.Orientation := 0;
        Canvas.TextOut(x, y, vText);
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
