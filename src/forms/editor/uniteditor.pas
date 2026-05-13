unit UnitEditor;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SQLDB, PQConnection, Forms, Controls, Graphics, Dialogs,
  ComCtrls, StdCtrls, Grids;

type

  { TFormEditor }

  TFormEditor = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    Button6: TButton;
    Button7: TButton;
    Button8: TButton;
    Button9: TButton;
    Button10: TButton;
    Button11: TButton;
    Button12: TButton;
    Button13: TButton;
    Button14: TButton;
    Button15: TButton;
    Button16: TButton;
    Button17: TButton;
    Button18: TButton;
    Button19: TButton;
    Button20: TButton;
    Button21: TButton;
    Button22: TButton;
    Button23: TButton;

    btnCtrNext: TButton;
    btnCityBack: TButton;
    btnCityNext: TButton;
    btnAntBack: TButton;
    btnAntNext: TButton;
    btnCmpBack: TButton;

    CheckBox1: TCheckBox;

    ComboBox1: TComboBox;
    ComboBox2: TComboBox;
    ComboBox3: TComboBox;
    ComboBox4: TComboBox;
    ComboBox5: TComboBox;
    ComboBox9: TComboBox;
    ComboBox10: TComboBox;

    Edit2: TEdit;
    Edit4: TEdit;
    Edit5: TEdit;
    Edit7: TEdit;
    Edit9: TEdit;
    Edit10: TEdit;
    Edit12: TEdit;
    Edit13: TEdit;
    Edit15: TEdit;
    Edit17: TEdit;
    Edit19: TEdit;
    Edit20: TEdit;
    Edit21: TEdit;
    Edit22: TEdit;
    Edit23: TEdit;
    Edit24: TEdit;

    Label2: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label7: TLabel;
    Label9: TLabel;
    Label10: TLabel;
    Label12: TLabel;
    Label13: TLabel;
    Label15: TLabel;
    Label16: TLabel;
    Label18: TLabel;
    Label19: TLabel;
    Label20: TLabel;
    Label21: TLabel;
    Label23: TLabel;
    Label27: TLabel;
    Label28: TLabel;
    Label29: TLabel;
    Label30: TLabel;
    Label31: TLabel;
    Label32: TLabel;
    Label33: TLabel;
    Label34: TLabel;

    OpenDialog1: TOpenDialog;

    PageControl1: TPageControl;
    PQConnection1: TPQConnection;
    SQLQuery1: TSQLQuery;
    SQLTransaction1: TSQLTransaction;

    StringGrid1: TStringGrid;
    StringGrid2: TStringGrid;
    StringGrid3: TStringGrid;
    StringGrid4: TStringGrid;
    StringGrid5: TStringGrid;
    StringGrid6: TStringGrid;
    StringGrid7: TStringGrid;

    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    TabSheet3: TTabSheet;
    TabSheet4: TTabSheet;
    TabSheet5: TTabSheet;
    TabSheet6: TTabSheet;
    TabSheet7: TTabSheet;

    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);

    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);

    procedure Button7Click(Sender: TObject);
    procedure Button8Click(Sender: TObject);
    procedure Button9Click(Sender: TObject);
    procedure Button23Click(Sender: TObject);

    procedure Button10Click(Sender: TObject);
    procedure Button11Click(Sender: TObject);
    procedure Button12Click(Sender: TObject);
    procedure Button22Click(Sender: TObject);

    procedure Button13Click(Sender: TObject);
    procedure Button14Click(Sender: TObject);
    procedure Button15Click(Sender: TObject);

    procedure Button16Click(Sender: TObject);
    procedure Button17Click(Sender: TObject);
    procedure Button18Click(Sender: TObject);

    procedure Button19Click(Sender: TObject);
    procedure Button20Click(Sender: TObject);
    procedure Button21Click(Sender: TObject);

    procedure btnCtrNextClick(Sender: TObject);
    procedure btnCityBackClick(Sender: TObject);
    procedure btnCityNextClick(Sender: TObject);
    procedure btnAntBackClick(Sender: TObject);
    procedure btnAntNextClick(Sender: TObject);
    procedure btnCmpBackClick(Sender: TObject);

    procedure FormCreate(Sender: TObject);

    procedure StringGrid1SelectCell(Sender: TObject; aCol, aRow: Integer; var CanSelect: Boolean);
    procedure StringGrid2SelectCell(Sender: TObject; aCol, aRow: Integer; var CanSelect: Boolean);
    procedure StringGrid3SelectCell(Sender: TObject; aCol, aRow: Integer; var CanSelect: Boolean);
    procedure StringGrid4SelectCell(Sender: TObject; aCol, aRow: Integer; var CanSelect: Boolean);
    procedure StringGrid5SelectCell(Sender: TObject; aCol, aRow: Integer; var CanSelect: Boolean);
    procedure StringGrid6SelectCell(Sender: TObject; aCol, aRow: Integer; var CanSelect: Boolean);
    procedure StringGrid7SelectCell(Sender: TObject; aCol, aRow: Integer; var CanSelect: Boolean);
  private
    FCurrentImagePath: string;
    FInitialized: Boolean;
    procedure RefreshMainForm;
    procedure LoadAllCombos;
    procedure ClearModelImageSelection;
    procedure RefreshCmpTab;
    function GetSelectedGridId(AGrid: TStringGrid): Integer;
  public
    property IsReady: Boolean read FInitialized;
  end;

var
  FormEditor: TFormEditor;

implementation

uses
  Unit1, UnitDb, UnitCtr, UnitStat, UnitLyt, UnitMdl, UnitCity, UnitAnt, UnitCmp;

{$R *.lfm}

{ TFormEditor }

procedure TFormEditor.RefreshMainForm;
begin
  if Assigned(FormMain) then
    FormMain.Invalidate;
end;

procedure TFormEditor.ClearModelImageSelection;
begin
  FCurrentImagePath := '';
  Edit24.Clear;
end;

function TFormEditor.GetSelectedGridId(AGrid: TStringGrid): Integer;
begin
  if (AGrid = nil) or (AGrid.Row <= 0) then
    raise Exception.Create('Выберите запись в таблице');

  if Trim(AGrid.Cells[0, AGrid.Row]) = '' then
    raise Exception.Create('Не удалось определить ID выбранной записи');

  Result := StrToInt(AGrid.Cells[0, AGrid.Row]);
end;

procedure TFormEditor.LoadAllCombos;
begin
  LoadCtrToCombo(SQLQuery1, ComboBox1);

  LoadMdlToCombo(SQLQuery1, ComboBox2);
  LoadCityToCombo(SQLQuery1, ComboBox3);
  LoadStatToCombo(SQLQuery1, ComboBox4);

  LoadAntToCombo(SQLQuery1, ComboBox5);
  LoadLytToCombo(SQLQuery1, ComboBox9);
  LoadCmpTypeToCombo(ComboBox10);
end;

procedure TFormEditor.RefreshCmpTab;
begin
  LoadCmpData(SQLQuery1, StringGrid7);
  LoadAntToCombo(SQLQuery1, ComboBox5);
  LoadLytToCombo(SQLQuery1, ComboBox9);
  LoadCmpTypeToCombo(ComboBox10);
end;

procedure TFormEditor.FormCreate(Sender: TObject);
begin
  FInitialized := False;

  try
    ConnectToDatabase(PQConnection1, SQLTransaction1, SQLQuery1);

    SetupCtrGrid(StringGrid1);
    LoadCtrData(SQLQuery1, StringGrid1);

    SetupStatGrid(StringGrid2);
    LoadStatData(SQLQuery1, StringGrid2);

    SetupLytGrid(StringGrid3);
    LoadLytData(SQLQuery1, StringGrid3);

    SetupMdlGrid(StringGrid4);
    LoadMdlData(SQLQuery1, StringGrid4);

    SetupCityGrid(StringGrid5);
    LoadCityData(SQLQuery1, StringGrid5);

    SetupAntGrid(StringGrid6);
    LoadAntData(SQLQuery1, StringGrid6);

    SetupCmpGrid(StringGrid7);
    LoadCmpData(SQLQuery1, StringGrid7);

    LoadAllCombos;
    ClearModelImageSelection;
    FInitialized := True;
  except
    on E: Exception do
    begin
      ShowMessage('Не удалось открыть редактор ACCAC.' + LineEnding +
        LineEnding + BuildStartupErrorMessage(E.Message));
      Visible := False;
    end;
  end;
end;

{ ===== Центры ===== }

procedure TFormEditor.StringGrid1SelectCell(Sender: TObject; aCol, aRow: Integer; var CanSelect: Boolean);
begin
  SelectCtrRow(StringGrid1, aRow, Edit2);
end;

procedure TFormEditor.Button1Click(Sender: TObject);
begin
  try
    AddCtr(SQLQuery1, SQLTransaction1, StringGrid1, Edit2);
    LoadCtrToCombo(SQLQuery1, ComboBox1);
    LoadCityData(SQLQuery1, StringGrid5);
    RefreshCmpTab;
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

procedure TFormEditor.Button2Click(Sender: TObject);
begin
  try
    EditCtr(SQLQuery1, SQLTransaction1, StringGrid1, Edit2);
    LoadCtrToCombo(SQLQuery1, ComboBox1);
    LoadCityData(SQLQuery1, StringGrid5);
    RefreshCmpTab;
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

procedure TFormEditor.Button3Click(Sender: TObject);
begin
  try
    DeleteCtr(SQLQuery1, SQLTransaction1, StringGrid1, Edit2);
    LoadCtrToCombo(SQLQuery1, ComboBox1);
    LoadCityData(SQLQuery1, StringGrid5);
    RefreshCmpTab;
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

procedure TFormEditor.btnCtrNextClick(Sender: TObject);
begin
  PageControl1.ActivePage := TabSheet5;
end;

{ ===== Состояния ===== }

procedure TFormEditor.StringGrid2SelectCell(Sender: TObject; aCol, aRow: Integer; var CanSelect: Boolean);
begin
  SelectStatRow(StringGrid2, aRow, Edit4, Edit5);
end;

procedure TFormEditor.Button4Click(Sender: TObject);
begin
  try
    AddStat(SQLQuery1, SQLTransaction1, StringGrid2, Edit4, Edit5);
    LoadStatToCombo(SQLQuery1, ComboBox4);
    LoadAntData(SQLQuery1, StringGrid6);
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

procedure TFormEditor.Button5Click(Sender: TObject);
begin
  try
    EditStat(SQLQuery1, SQLTransaction1, StringGrid2, Edit4, Edit5);
    LoadStatToCombo(SQLQuery1, ComboBox4);
    LoadAntData(SQLQuery1, StringGrid6);
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

procedure TFormEditor.Button6Click(Sender: TObject);
begin
  try
    DeleteStat(SQLQuery1, SQLTransaction1, StringGrid2, Edit4, Edit5);
    LoadStatToCombo(SQLQuery1, ComboBox4);
    LoadAntData(SQLQuery1, StringGrid6);
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

{ ===== Макеты ===== }

procedure TFormEditor.StringGrid3SelectCell(Sender: TObject; aCol, aRow: Integer; var CanSelect: Boolean);
begin
  SelectLytRow(StringGrid3, aRow, Edit7);
end;

procedure TFormEditor.Button7Click(Sender: TObject);
begin
  try
    AddLyt(SQLQuery1, SQLTransaction1, StringGrid3, Edit7);
    LoadLytToCombo(SQLQuery1, ComboBox9);
    RefreshCmpTab;
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

procedure TFormEditor.Button8Click(Sender: TObject);
begin
  try
    EditLyt(SQLQuery1, SQLTransaction1, StringGrid3, Edit7);
    LoadLytToCombo(SQLQuery1, ComboBox9);
    RefreshCmpTab;
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

procedure TFormEditor.Button9Click(Sender: TObject);
begin
  try
    DeleteLyt(SQLQuery1, SQLTransaction1, StringGrid3, Edit7);
    LoadLytToCombo(SQLQuery1, ComboBox9);
    RefreshCmpTab;
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

procedure TFormEditor.Button23Click(Sender: TObject);
var
  LayoutId: Integer;
begin
  LayoutId := GetSelectedGridId(StringGrid3);

  if Assigned(FormMain) then
  begin
    FormMain.SetCurrentLayout(LayoutId);
    FormMain.Invalidate;
  end;
end;

{ ===== Модели ===== }

procedure TFormEditor.StringGrid4SelectCell(Sender: TObject; aCol, aRow: Integer; var CanSelect: Boolean);
begin
  SelectMdlRow(StringGrid4, aRow, Edit9, Edit10, Edit12, Edit13);
  ClearModelImageSelection;
end;

procedure TFormEditor.Button22Click(Sender: TObject);
begin
  if OpenDialog1.Execute then
  begin
    FCurrentImagePath := OpenDialog1.FileName;
    Edit24.Text := FCurrentImagePath;
  end;
end;

procedure TFormEditor.Button10Click(Sender: TObject);
begin
  try
    AddMdl(SQLQuery1, SQLTransaction1, StringGrid4,
      Edit9, Edit10, Edit12, Edit13, FCurrentImagePath);

    LoadMdlToCombo(SQLQuery1, ComboBox2);
    LoadAntData(SQLQuery1, StringGrid6);
    RefreshCmpTab;
    ClearModelImageSelection;
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

procedure TFormEditor.Button11Click(Sender: TObject);
begin
  try
    EditMdl(SQLQuery1, SQLTransaction1, StringGrid4,
      Edit9, Edit10, Edit12, Edit13, FCurrentImagePath);

    LoadMdlToCombo(SQLQuery1, ComboBox2);
    LoadAntData(SQLQuery1, StringGrid6);
    RefreshCmpTab;
    ClearModelImageSelection;
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

procedure TFormEditor.Button12Click(Sender: TObject);
begin
  try
    DeleteMdl(SQLQuery1, SQLTransaction1, StringGrid4,
      Edit9, Edit10, Edit12, Edit13);

    LoadMdlToCombo(SQLQuery1, ComboBox2);
    LoadAntData(SQLQuery1, StringGrid6);
    RefreshCmpTab;
    ClearModelImageSelection;
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

{ ===== Города ===== }

procedure TFormEditor.StringGrid5SelectCell(Sender: TObject; aCol, aRow: Integer; var CanSelect: Boolean);
begin
  SelectCityRow(StringGrid5, aRow, Edit15, ComboBox1);
end;

procedure TFormEditor.Button13Click(Sender: TObject);
begin
  try
    AddCity(SQLQuery1, SQLTransaction1, StringGrid5, Edit15, ComboBox1);
    LoadCityToCombo(SQLQuery1, ComboBox3);
    LoadAntData(SQLQuery1, StringGrid6);
    RefreshCmpTab;
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

procedure TFormEditor.Button14Click(Sender: TObject);
begin
  try
    EditCity(SQLQuery1, SQLTransaction1, StringGrid5, Edit15, ComboBox1);
    LoadCityToCombo(SQLQuery1, ComboBox3);
    LoadAntData(SQLQuery1, StringGrid6);
    RefreshCmpTab;
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

procedure TFormEditor.Button15Click(Sender: TObject);
begin
  try
    DeleteCity(SQLQuery1, SQLTransaction1, StringGrid5, Edit15, ComboBox1);
    LoadCityToCombo(SQLQuery1, ComboBox3);
    LoadAntData(SQLQuery1, StringGrid6);
    RefreshCmpTab;
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

procedure TFormEditor.btnCityBackClick(Sender: TObject);
begin
  PageControl1.ActivePage := TabSheet1;
end;

procedure TFormEditor.btnCityNextClick(Sender: TObject);
begin
  PageControl1.ActivePage := TabSheet6;
end;

{ ===== Антенны ===== }

procedure TFormEditor.StringGrid6SelectCell(Sender: TObject; aCol, aRow: Integer; var CanSelect: Boolean);
begin
  SelectAntRow(StringGrid6, aRow, Edit17, ComboBox2, ComboBox3, ComboBox4);
end;

procedure TFormEditor.Button16Click(Sender: TObject);
begin
  try
    AddAnt(SQLQuery1, SQLTransaction1, StringGrid6, Edit17,
      ComboBox2, ComboBox3, ComboBox4);

    LoadAntData(SQLQuery1, StringGrid6);
    RefreshCmpTab;
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

procedure TFormEditor.Button17Click(Sender: TObject);
begin
  try
    EditAnt(SQLQuery1, SQLTransaction1, StringGrid6, Edit17,
      ComboBox2, ComboBox3, ComboBox4);

    LoadAntData(SQLQuery1, StringGrid6);
    RefreshCmpTab;
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

procedure TFormEditor.Button18Click(Sender: TObject);
begin
  try
    DeleteAnt(SQLQuery1, SQLTransaction1, StringGrid6, Edit17,
      ComboBox2, ComboBox3, ComboBox4);

    LoadAntData(SQLQuery1, StringGrid6);
    RefreshCmpTab;
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

procedure TFormEditor.btnAntBackClick(Sender: TObject);
begin
  PageControl1.ActivePage := TabSheet5;
end;

procedure TFormEditor.btnAntNextClick(Sender: TObject);
begin
  PageControl1.ActivePage := TabSheet7;
end;

{ ===== Компоненты ===== }

procedure TFormEditor.StringGrid7SelectCell(Sender: TObject; aCol, aRow: Integer; var CanSelect: Boolean);
begin
  SelectCmpRow(
    StringGrid7, aRow,
    Edit19, Edit20, Edit21, Edit22, Edit23,
    ComboBox5, ComboBox9, ComboBox10,
    CheckBox1
  );
end;

procedure TFormEditor.Button19Click(Sender: TObject);
begin
  try
    AddCmp(
      SQLQuery1, SQLTransaction1, StringGrid7,
      Edit19, Edit20, Edit21, Edit22, Edit23,
      ComboBox5, ComboBox9, ComboBox10,
      CheckBox1
    );

    RefreshCmpTab;
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

procedure TFormEditor.Button20Click(Sender: TObject);
begin
  try
    EditCmp(
      SQLQuery1, SQLTransaction1, StringGrid7,
      Edit19, Edit20, Edit21, Edit22, Edit23,
      ComboBox5, ComboBox9, ComboBox10,
      CheckBox1
    );

    RefreshCmpTab;
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

procedure TFormEditor.Button21Click(Sender: TObject);
begin
  try
    DeleteCmp(
      SQLQuery1, SQLTransaction1, StringGrid7,
      Edit19, Edit20, Edit21, Edit22, Edit23,
      ComboBox5, ComboBox9, ComboBox10,
      CheckBox1
    );

    RefreshCmpTab;
    RefreshMainForm;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

procedure TFormEditor.btnCmpBackClick(Sender: TObject);
begin
  PageControl1.ActivePage := TabSheet6;
end;

end.
