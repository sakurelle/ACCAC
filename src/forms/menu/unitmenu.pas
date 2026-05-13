unit UnitMenu;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls;

type

  { TFormMenu }

  TFormMenu = class(TForm)
    btnStates: TButton;
    btnLayouts: TButton;
    btnAddCenterCityAntenna: TButton;
    procedure btnStatesClick(Sender: TObject);
    procedure btnLayoutsClick(Sender: TObject);
    procedure btnAddCenterCityAntennaClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    procedure OpenEditorPage(APageIndex: Integer);
  public

  end;

var
  FormMenu: TFormMenu;

implementation

uses
  UnitEditor;

{$R *.lfm}

procedure TFormMenu.OpenEditorPage(APageIndex: Integer);
begin
  if Assigned(FormEditor) and not FormEditor.IsReady then
    FreeAndNil(FormEditor);

  if not Assigned(FormEditor) then
    Application.CreateForm(TFormEditor, FormEditor);

  if not Assigned(FormEditor) or not FormEditor.IsReady then
    Exit;

  if (APageIndex >= 0) and (APageIndex < FormEditor.PageControl1.PageCount) then
    FormEditor.PageControl1.ActivePageIndex := APageIndex;

  FormEditor.Show;
  FormEditor.BringToFront;
end;

procedure TFormMenu.FormCreate(Sender: TObject);
begin
  FormStyle := fsStayOnTop;
  Position := poMainFormCenter;
end;

procedure TFormMenu.btnStatesClick(Sender: TObject);
begin
  OpenEditorPage(1);
end;

procedure TFormMenu.btnLayoutsClick(Sender: TObject);
begin
  OpenEditorPage(2);
end;

procedure TFormMenu.btnAddCenterCityAntennaClick(Sender: TObject);
begin
  OpenEditorPage(0);
end;

end.
