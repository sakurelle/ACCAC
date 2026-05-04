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

  public

  end;

var
  FormMenu: TFormMenu;

implementation

uses
  UnitEditor;

{$R *.lfm}

procedure TFormMenu.FormCreate(Sender: TObject);
begin
  FormStyle := fsStayOnTop;
  Position := poMainFormCenter;
end;

procedure TFormMenu.btnStatesClick(Sender: TObject);
begin
  if not Assigned(FormEditor) then
    Application.CreateForm(TFormEditor, FormEditor);

  FormEditor.PageControl1.ActivePage := FormEditor.TabSheet2;
  FormEditor.Show;
  FormEditor.BringToFront;
end;

procedure TFormMenu.btnLayoutsClick(Sender: TObject);
begin
  if not Assigned(FormEditor) then
    Application.CreateForm(TFormEditor, FormEditor);

  FormEditor.PageControl1.ActivePage := FormEditor.TabSheet3;
  FormEditor.Show;
  FormEditor.BringToFront;
end;

procedure TFormMenu.btnAddCenterCityAntennaClick(Sender: TObject);
begin
  if not Assigned(FormEditor) then
    Application.CreateForm(TFormEditor, FormEditor);

  FormEditor.PageControl1.ActivePage := FormEditor.TabSheet1;
  FormEditor.Show;
  FormEditor.BringToFront;
end;

end.
