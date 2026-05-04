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
    procedure FormCreate(Sender: TObject);
  private

  public

  end;

var
  FormMenu: TFormMenu;

implementation

{$R *.lfm}

procedure TFormMenu.FormCreate(Sender: TObject);
begin
  FormStyle := fsStayOnTop;
  Position := poMainFormCenter;
end;

end.
