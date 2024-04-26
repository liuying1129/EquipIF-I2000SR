unit UfrmMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms,
  Menus, StdCtrls, Buttons, ADODB,
  ComCtrls, ToolWin, ExtCtrls,
  inifiles,Dialogs,
  StrUtils, DB, ComObj,Variants,CPort,ShellAPI, PerlRegEx, CoolTrayIcon;

type
  TfrmMain = class(TForm)
    PopupMenu1: TPopupMenu;
    N1: TMenuItem;
    N2: TMenuItem;
    N3: TMenuItem;
    ADOConnection1: TADOConnection;
    CoolBar1: TCoolBar;
    ToolBar1: TToolBar;
    ToolButton8: TToolButton;
    ToolButton2: TToolButton;
    Memo1: TMemo;
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    Button1: TButton;
    ToolButton5: TToolButton;
    ToolButton9: TToolButton;
    OpenDialog1: TOpenDialog;
    ComPort1: TComPort;
    ToolButton7: TToolButton;
    SaveDialog1: TSaveDialog;
    LYTray1: TCoolTrayIcon;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure N1Click(Sender: TObject);
    procedure ToolButton2Click(Sender: TObject);
    procedure BitBtn2Click(Sender: TObject);
    procedure BitBtn1Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure ToolButton5Click(Sender: TObject);
    procedure ToolButton7Click(Sender: TObject);
    procedure ComPort1RxChar(Sender: TObject; Count: Integer);
    procedure ComPort1RxFlag(Sender: TObject);
    procedure N3Click(Sender: TObject);
  private
    { Private declarations }
    procedure UpdateConfig;{�����ļ���Ч}
    function MakeDBConn:boolean;
    function GetSpecNo(const Value:string):string; //ȡ��������
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

uses ucommfunction;

const
  CR=#$D+#$A;
  STX=#$2;ETX=#$3;ACK=#$6;NAK=#$15;EOT=#$4;ETB=#$17;
  sCryptSeed='lc';//�ӽ�������
  //SEPARATOR=#$1C;
  sCONNECTDEVELOP='����!���뿪������ϵ!' ;
  IniSection='Setup';

var
  ConnectString:string;
  GroupName:string;//
  SpecType:string ;//
  SpecStatus:string ;//
  CombinID:string;//
  LisFormCaption:string;//
  QuaContSpecNoG:string;
  QuaContSpecNo:string;
  QuaContSpecNoD:string;
  EquipChar:string;
  OnLineIDPrefix:string;//������ʶǰ׺
  ifRecLog:boolean;//�Ƿ��¼������־
  EquipUnid:integer;//�豸Ψһ���
  YXJB:STRING;//���ȼ���

  SpecNo_Type:string;//������ȡֵ

  RFM:STRING;       //��������
  hnd:integer;
  bRegister:boolean;

{$R *.dfm}

function ifRegister:boolean;
var
  HDSn,RegisterNum,EnHDSn:string;
  configini:tinifile;
  pEnHDSn:Pchar;
begin
  result:=false;
  
  HDSn:=GetHDSn('C:\')+'-'+GetHDSn('D:\')+'-'+ChangeFileExt(ExtractFileName(Application.ExeName),'');

  CONFIGINI:=TINIFILE.Create(ChangeFileExt(Application.ExeName,'.ini'));
  RegisterNum:=CONFIGINI.ReadString(IniSection,'RegisterNum','');
  CONFIGINI.Free;
  pEnHDSn:=EnCryptStr(Pchar(HDSn),sCryptSeed);
  EnHDSn:=StrPas(pEnHDSn);

  if Uppercase(EnHDSn)=Uppercase(RegisterNum) then result:=true;

  if not result then messagedlg('�Բ���,��û��ע���ע�������,��ע��!',mtinformation,[mbok],0);
end;

function GetConnectString:string;
var
  Ini:tinifile;
  userid, password, datasource, initialcatalog: string;
  ifIntegrated:boolean;//�Ƿ񼯳ɵ�¼ģʽ

  pInStr,pDeStr:Pchar;
  i:integer;
begin
  result:='';
  
  Ini := tinifile.Create(ChangeFileExt(Application.ExeName,'.INI'));
  datasource := Ini.ReadString('�������ݿ�', '������', '');
  initialcatalog := Ini.ReadString('�������ݿ�', '���ݿ�', '');
  ifIntegrated:=ini.ReadBool('�������ݿ�','���ɵ�¼ģʽ',false);
  userid := Ini.ReadString('�������ݿ�', '�û�', '');
  password := Ini.ReadString('�������ݿ�', '����', '107DFC967CDCFAAF');
  Ini.Free;
  //======����password
  pInStr:=pchar(password);
  pDeStr:=DeCryptStr(pInStr,sCryptSeed);
  setlength(password,length(pDeStr));
  for i :=1  to length(pDeStr) do password[i]:=pDeStr[i-1];
  //==========

  result := result + 'user id=' + UserID + ';';
  result := result + 'password=' + Password + ';';
  result := result + 'data source=' + datasource + ';';
  result := result + 'Initial Catalog=' + initialcatalog + ';';
  result := result + 'provider=' + 'SQLOLEDB.1' + ';';
  //Persist Security Info,��ʾADO�����ݿ����ӳɹ����Ƿ񱣴�������Ϣ
  //ADOȱʡΪTrue,ADO.netȱʡΪFalse
  //�����лᴫADOConnection��Ϣ��TADOLYQuery,������ΪTrue
  result := result + 'Persist Security Info=True;';
  if ifIntegrated then
    result := result + 'Integrated Security=SSPI;';
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  rfm:='';
  
  ConnectString:=GetConnectString;
  UpdateConfig;
  if ifRegister then bRegister:=true else bRegister:=false;  

  Caption:='���ݽ��շ���'+ExtractFileName(Application.ExeName);
  lytray1.Hint:='���ݽ��շ���'+ExtractFileName(Application.ExeName);
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  action:=caNone;
  LYTray1.HideMainForm;
end;

procedure TfrmMain.N1Click(Sender: TObject);
begin
  LYTray1.ShowMainForm;
end;

procedure TfrmMain.UpdateConfig;
var
  INI:tinifile;
  CommName,BaudRate,DataBit,StopBit,ParityBit:string;
  autorun:boolean;
begin
  ini:=TINIFILE.Create(ChangeFileExt(Application.ExeName,'.ini'));

  CommName:=ini.ReadString(IniSection,'����ѡ��','COM1');
  BaudRate:=ini.ReadString(IniSection,'������','9600');
  DataBit:=ini.ReadString(IniSection,'����λ','8');
  StopBit:=ini.ReadString(IniSection,'ֹͣλ','1');
  ParityBit:=ini.ReadString(IniSection,'У��λ','None');
  autorun:=ini.readBool(IniSection,'�����Զ�����',false);
  ifRecLog:=ini.readBool(IniSection,'������־',false);

  GroupName:=trim(ini.ReadString(IniSection,'������',''));
  EquipChar:=trim(uppercase(ini.ReadString(IniSection,'������ĸ','')));//�������Ǵ�д������һʧ��
  OnLineIDPrefix:=trim(ini.ReadString(IniSection,'������ʶǰ׺',''));
  SpecType:=ini.ReadString(IniSection,'Ĭ����������','');
  SpecStatus:=ini.ReadString(IniSection,'Ĭ������״̬','');
  CombinID:=ini.ReadString(IniSection,'�����Ŀ����','');

  SpecNo_Type:=ini.ReadString(IniSection,'������ȡֵ','');

  YXJB:=ini.ReadString(IniSection,'���ȼ���','����');//���ȼ���
  if trim(YXJB)='' then YXJB:='����';
  LisFormCaption:=ini.ReadString(IniSection,'����ϵͳ�������','');
  EquipUnid:=ini.ReadInteger(IniSection,'�豸Ψһ���',-1);

  QuaContSpecNoG:=ini.ReadString(IniSection,'��ֵ�ʿ�������','9999');
  QuaContSpecNo:=ini.ReadString(IniSection,'��ֵ�ʿ�������','9998');
  QuaContSpecNoD:=ini.ReadString(IniSection,'��ֵ�ʿ�������','9997');

  ini.Free;

  OperateLinkFile(application.ExeName,'\'+ChangeFileExt(ExtractFileName(Application.ExeName),'.lnk'),15,autorun);
  ComPort1.Close;
  ComPort1.Port:=CommName;
  if BaudRate='1200' then
    ComPort1.BaudRate:=br1200
    else if BaudRate='2400' then
      ComPort1.BaudRate:=br2400
      else if BaudRate='4800' then
        ComPort1.BaudRate:=br4800
        else if BaudRate='9600' then
          ComPort1.BaudRate:=br9600
          else if BaudRate='19200' then
            ComPort1.BaudRate:=br19200
            else ComPort1.BaudRate:=br9600;
  if DataBit='5' then
    ComPort1.DataBits:=dbFive
    else if DataBit='6' then
      ComPort1.DataBits:=dbSix
      else if DataBit='7' then
        ComPort1.DataBits:=dbSeven
        else if DataBit='8' then
          ComPort1.DataBits:=dbEight
          else ComPort1.DataBits:=dbEight;
  if StopBit='1' then
    ComPort1.StopBits:=sbOneStopBit
    else if StopBit='2' then
      ComPort1.StopBits:=sbTwoStopBits
      else if StopBit='1.5' then
        ComPort1.StopBits:=sbOne5StopBits
        else ComPort1.StopBits:=sbOneStopBit;
  if ParityBit='None' then
    ComPort1.Parity.Bits:=prNone
    else if ParityBit='Odd' then
      ComPort1.Parity.Bits:=prOdd
      else if ParityBit='Even' then
        ComPort1.Parity.Bits:=prEven
        else if ParityBit='Mark' then
          ComPort1.Parity.Bits:=prMark
          else if ParityBit='Space' then
            ComPort1.Parity.Bits:=prSpace
            else ComPort1.Parity.Bits:=prNone;
  ComPort1.EventChar:=#4;//ASTMЭ��涨,�豸��04��LIS,��ʾ�ô�ͨ�����
  try
    ComPort1.Open;
  except
    showmessage('����'+ComPort1.Port+'��ʧ��!');
  end;
end;

function TfrmMain.GetSpecNo(const Value:string):string; //ȡ��������
var
  ls3,ls4,ls5,ls6:tstrings;
  RegEx: TPerlRegEx;
  STAT008:boolean;//��ʾ����008��������
  i_result:integer;
begin
  if trim(SpecNo_Type)='����008' then
  begin
    RegEx := TPerlRegEx.Create;
    RegEx.Subject := Value;
    RegEx.RegEx   := '\|';
    ls5 := TStringList.Create;
    RegEx.Split(ls5,MaxInt);//MaxInt,��ʾ�ֶܷ��پͷֶ���
    FreeAndNil(RegEx);

    IF ls5.Count<4 then
    begin
      ls5.Free;
      result:=formatdatetime('nnss',now);
      exit;
    end;
    result:=ls5[3];

    IF(ls5.Count>=6)and(trim(ls5[5])='S') then STAT008:=true else STAT008:=false;

    ls5.Free;

    RegEx := TPerlRegEx.Create;
    RegEx.Subject := result;
    RegEx.RegEx   := '\^';
    ls6 := TStringList.Create;
    RegEx.Split(ls6,MaxInt);//MaxInt,��ʾ�ֶܷ��پͷֶ���
    FreeAndNil(RegEx);
    IF ls6.Count>0 then result:=ls6[0];
    ls6.Free;

    if STAT008 then//Խ����ҽҪ��,���������ż�5000.��1#��������,��Ҫ���5001
    begin
      if TryStrToInt(result,i_result) then result:=inttostr(5000+i_result);
    end;
  end else
  begin
    RegEx := TPerlRegEx.Create;
    RegEx.Subject := Value;
    RegEx.RegEx   := '\|';
    ls3 := TStringList.Create;
    RegEx.Split(ls3,MaxInt);//MaxInt,��ʾ�ֶܷ��پͷֶ���
    FreeAndNil(RegEx);

    IF ls3.Count<3 then
    begin
      ls3.Free;
      result:=formatdatetime('nnss',now);
      exit;
    end;
    result:=ls3[2];
    ls3.Free;

    //����CS-600B Start
    //ls4:=StrToList(result,'^');
    RegEx := TPerlRegEx.Create;
    RegEx.Subject := result;
    RegEx.RegEx   := '\^';
    ls4 := TStringList.Create;
    RegEx.Split(ls4,MaxInt);//MaxInt,��ʾ�ֶܷ��پͷֶ���
    FreeAndNil(RegEx);
    IF ls4.Count>1 then result:=ls4[1];
    ls4.Free;
    //����CS-600B Stop
  end;

  result:='0000'+trim(result);
  result:=rightstr(result,4);
end;

function TListToVariant(AList:TList):OleVariant;
var
  P:Pointer;
begin
  Result:=VarArrayCreate([0,Sizeof(TList)],varByte);
  P:=VarArrayLock(Result);
  Move(AList,P^,Sizeof(TList));
  VarArrayUnLock(Result);
end;

function TfrmMain.MakeDBConn:boolean;
var
  newconnstr,ss: string;
  Label labReadIni;
begin
  result:=false;

  labReadIni:
  newconnstr := GetConnectString;
  try
    ADOConnection1.Connected := false;
    ADOConnection1.ConnectionString := newconnstr;
    ADOConnection1.Connected := true;
    result:=true;
  except
  end;
  if not result then
  begin
    ss:='������'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
        '���ݿ�'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
        '���ɵ�¼ģʽ'+#2+'CheckListBox'+#2+#2+'0'+#2+#2+#3+
        '�û�'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
        '����'+#2+'Edit'+#2+#2+'0'+#2+#2+'1';
    if ShowOptionForm('�������ݿ�','�������ݿ�',Pchar(ss),Pchar(ChangeFileExt(Application.ExeName,'.ini'))) then
      goto labReadIni else application.Terminate;
  end;
end;

procedure TfrmMain.ToolButton2Click(Sender: TObject);
var
  ss:string;
begin
    ss:='����ѡ��'+#2+'Combobox'+#2+'COM1'+#13+'COM2'+#13+'COM3'+#13+'COM4'+#2+'0'+#2+#2+#3+
      '������'+#2+'Combobox'+#2+'19200'+#13+'9600'+#13+'4800'+#13+'2400'+#13+'1200'+#2+'0'+#2+#2+#3+
      '����λ'+#2+'Combobox'+#2+'8'+#13+'7'+#13+'6'+#13+'5'+#2+'0'+#2+#2+#3+
      'ֹͣλ'+#2+'Combobox'+#2+'1'+#13+'1.5'+#13+'2'+#2+'0'+#2+#2+#3+
      'У��λ'+#2+'Combobox'+#2+'None'+#13+'Even'+#13+'Odd'+#13+'Mark'+#13+'Space'+#2+'0'+#2+#2+#3+
      '������'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '������ĸ'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '������ʶǰ׺'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '������ȡֵ'+#2+'Combobox'+#2+'����008'+#2+'0'+#2+'��������LABOSPECT008AS,ѡ������008.��O|1|602|301^50003^1^^S1^SC|...��'+#2+#3+
      '����ϵͳ�������'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      'Ĭ����������'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      'Ĭ������״̬'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '�����Ŀ����'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '�����Զ�����'+#2+'CheckListBox'+#2+#2+'1'+#2+#2+#3+
      '������־'+#2+'CheckListBox'+#2+#2+'0'+#2+'ע:ǿ�ҽ�������������ʱ�ر�'+#2+#3+
      '���ȼ���'+#2+'Combobox'+#2+'�Զ�'+#13+'����'+#2+'0'+#2+'�Զ�:��������ȡֵ;����:ȡ����ֵ'+#2+#3+
      '�豸Ψһ���'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '��ֵ�ʿ�������'+#2+'Edit'+#2+#2+'2'+#2+#2+#3+
      '��ֵ�ʿ�������'+#2+'Edit'+#2+#2+'2'+#2+#2+#3+
      '��ֵ�ʿ�������'+#2+'Edit'+#2+#2+'2'+#2+#2;

  if ShowOptionForm('',Pchar(IniSection),Pchar(ss),Pchar(ChangeFileExt(Application.ExeName,'.ini'))) then
	  UpdateConfig;
end;

procedure TfrmMain.BitBtn2Click(Sender: TObject);
begin
  Memo1.Lines.Clear;
end;

procedure TfrmMain.BitBtn1Click(Sender: TObject);
begin
  SaveDialog1.DefaultExt := '.txt';
  SaveDialog1.Filter := 'txt (*.txt)|*.txt';
  if not SaveDialog1.Execute then exit;
  memo1.Lines.SaveToFile(SaveDialog1.FileName);
  showmessage('����ɹ�!');
end;

procedure TfrmMain.Button1Click(Sender: TObject);
var
  ls:Tstrings;
begin
  OpenDialog1.DefaultExt := '.txt';
  OpenDialog1.Filter := 'txt (*.txt)|*.txt';
  if not OpenDialog1.Execute then exit;
  ls:=Tstringlist.Create;
  ls.LoadFromFile(OpenDialog1.FileName);
  rfm:=ls.Text;
  ComPort1RxChar(nil,0);
  ls.Free;
end;

procedure TfrmMain.ToolButton5Click(Sender: TObject);
var
  ss:string;
begin
  ss:='RegisterNum'+#2+'Edit'+#2+#2+'0'+#2+'���ô���������ϵ��ַ�������������,�Ի�ȡע����'+#2;
  if bRegister then exit;
  if ShowOptionForm(Pchar('ע��:'+GetHDSn('C:\')+'-'+GetHDSn('D:\')+'-'+ChangeFileExt(ExtractFileName(Application.ExeName),'')),Pchar(IniSection),Pchar(ss),Pchar(ChangeFileExt(Application.ExeName,'.ini'))) then
    if ifRegister then bRegister:=true else bRegister:=false;
end;

procedure TfrmMain.ToolButton7Click(Sender: TObject);
begin
  if MakeDBConn then ConnectString:=GetConnectString;
end;

procedure TfrmMain.ComPort1RxChar(Sender: TObject; Count: Integer);
VAR
  Str:string;
begin
  ComPort1.ReadStr(Str,count);
  
  if length(memo1.Lines.Text)>=60000 then memo1.Lines.Clear;//memoֻ�ܽ���64K���ַ�
  memo1.Lines.Add(Str);
  memo1.Lines.Add(StrToHex(pchar(Str)));
  WriteLog(pchar(Str));
  WriteLog(StrToHex(pchar(Str)));

{
ϣ�����˳������ɱ�׼��ASTMͨ�Žӿ�
������̣�
I2000SR�ȴ���05��LIS,��ʼ�ͨ����·��Lis�ظ�06,�ͨ����·�ɹ���
I2000SR������(����Ϣmessage)��LIS,LIS�յ�һ֡�ͻظ�06.
֡�ĸ�ʽ��
<STX> FN text <ETX> C1 C2 <CR> <LF>
--ע��ʵ���ϱ�׼ASTM��,һ֡��С���Ϊ240�ֽ�,���һ����Ϣ���ȴ���240,����Ϊ��֡����,-------
--ǰ��֡�ĸ�ʽ��<STX><FN><TEXT><ETB><C1><C2><CR><LF>��---------------------------------------
--���һ֡�ĸ�ʽ����<STX> FN text <ETX> C1 C2 <CR> <LF>���������ѽ���������֡��С��Ϊ64000,--
--����ǰ��֡��ʽ�����ϲ����ܳ���-------------------------------------------------------------
Lisÿ�յ�һ֡�ظ�06
I2000SR��04��LIS,��ʾ�ô�ͨ�����
}

  if Str=#$5 then//һ��ͨ����·�Ŀ�ʼ
  begin
    rfm:='';
    rfm:=rfm+Str;
    ComPort1.WriteStr(ACK);//����ȷ��ָ��
    memo1.Lines.Add('Response 06');
    WriteLog('Response 06');
  end ELSE
  begin
    rfm:=rfm+Str;
    if rightstr(rfm,2)=#$D#$A then//����һ֡�ظ�06(LIS��ÿ��ComPort1RxChar�¼����յ������ݲ���������һ֡����������һ��������)
    begin
      ComPort1.WriteStr(ACK);//����ȷ��ָ��//������ע��
      memo1.Lines.Add('Response 06');
      WriteLog('Response 06');
    end;
  end;
end;

procedure TfrmMain.ComPort1RxFlag(Sender: TObject);
//�¼��ַ�(EventChar)����OnRxChar��OnRxFlag.�ݹ۲�,��OnRxChar��OnRxFlag
//���¼��ַ�����OnRxChar
//���EventChar=#4,�豸�˷��͵��ַ���Ϊ#65#66#67#4#65#66#67#4(һ���Է���,���ж��#4),��onRxFlag����ʱrfm=#65#66#67#4#65#66#67#4
VAR
  SpecNo:string;
  i,j:integer;
  dlttype:string;
  sValue:string;
  FInts:OleVariant;
  ReceiveItemInfo:OleVariant;
  ls,ls2,ls4,ls5,ls55:tstrings;
  CheckDate:string;
  msgRFM:STRING;//һ����������Ϣ
  RegEx: TPerlRegEx;
  ifHaveNotFinishedPack:boolean;
begin
  while pos(#$2,rfm)>0 do
  begin
    delete(rfm,pos(#$2,rfm),2);//ɾ��ÿ֡�ĵ�һ���ַ�(#$02),�ڶ����ַ�(֡���)
  end;
  while pos(#$17,rfm)>0 do
  begin
    delete(rfm,pos(#$17,rfm),5);//ɾ��ǰ��֡�����5���ַ�<ETB><C1><C2><CR><LF>,��ʱֻ����GEM3000����������LABOSPECT008AS��ETB
  end;

  ifHaveNotFinishedPack:=rightstr(rfm,1)<>#4;//���һ���ַ���Ϊ#4,��ʾ����δ�����İ�

  RegEx := TPerlRegEx.Create;
  RegEx.Subject := rfm;
  RegEx.RegEx   := #4;//��04���
  ls5:=TStringList.Create;
  RegEx.Split(ls5,MaxInt);//MaxInt,��ʾ�ֶܷ��پͷֶ���
  FreeAndNil(RegEx);
  
  if ifHaveNotFinishedPack then rfm:=ls5[ls5.Count-1] else rfm:='';
  for i :=0  to ls5.Count-1 do
  begin
    if ifHaveNotFinishedPack and(i=ls5.Count-1) then continue;//��ʾ���һ��δ�����İ�

    msgRFM:=ls5[i];//msgRFM��ʾһ��������ͨ����·

    if pos('O|',uppercase(msgRFM))<=0 then continue;//��������
    if pos('R|',uppercase(msgRFM))<=0 then continue;//�����

    SpecNo:='';CheckDate:='';

    ls:=TStringList.Create;
    ExtractStrings([#$D,#$A],[],Pchar(msgRFM),ls);//����Ϣ��ÿ�е��뵽�ַ����б���
    for j :=0  to ls.Count-1 do//һ����Ϣ�е�ÿһ��
    begin
      if uppercase(leftstr(trim(ls[j]),2))='O|' then SpecNo:=GetSpecNo(ls[j]);
      
      if(uppercase(leftstr(trim(ls[j]),2))='O|')and(trim(YXJB)='�Զ�') then//����008��ѡ���Զ�,���������Ƿ�ʹ�ø��ֶα�ʾ���ȼ���,����֤
      //O|1||1^40001^1^^S1^SC|^^^28330^\^^^28365^|S||||||N||||1|||||||
      //�����ַ�����|S|��S��ʾ����,����Ϊ|R|.S=STAT;R=Routine
      begin
        RegEx := TPerlRegEx.Create;
        RegEx.Subject := ls[j];
        RegEx.RegEx   := '\|';
        ls55 := TStringList.Create;
        RegEx.Split(ls55,MaxInt);//MaxInt,��ʾ�ֶܷ��پͷֶ���
        FreeAndNil(RegEx);

        IF(ls55.Count>=6)and(trim(ls55[5])='S') then YXJB:='����' else YXJB:='����';
        ls55.Free;
      end;

      if uppercase(leftstr(trim(ls[j]),2))='R|' then
      begin
        dlttype:='';sValue:='';
        RegEx := TPerlRegEx.Create;
        RegEx.Subject := ls[j];
        RegEx.RegEx   := '\|';
        ls2 := TStringList.Create;
        RegEx.Split(ls2,MaxInt);//MaxInt,��ʾ�ֶܷ��پͷֶ���
        FreeAndNil(RegEx);
        if ls2.Count>3 then
        begin
          dlttype:=OnLineIDPrefix+ls2[2];
          
          RegEx := TPerlRegEx.Create;
          RegEx.Subject := ls2[2];
          RegEx.RegEx   := '\^';
          ls4 := TStringList.Create;
          RegEx.Split(ls4,MaxInt);//MaxInt,��ʾ�ֶܷ��پͷֶ���
          FreeAndNil(RegEx);
          if ls4.Count>4 then
          begin
            if rightstr(ls2[2],2)='^F' then dlttype:=OnLineIDPrefix+ls4[4];//���ֵ�п����м���(ʵ�ʽ�������ʵ�)��^Fò����ʵ�ʽ��
            if ls4[3]='BC' then dlttype:=OnLineIDPrefix+ls4[4];//BacT3D,���ֵ�п����м���(������ʱ����)��BC��������TTD��ʱ��
          end;
          ls4.Free;

          sValue:=ls2[3];
        end;
        if ls2.Count>12 then CheckDate:=copy(ls2[12],1,4)+'-'+copy(ls2[12],5,2)+'-'+copy(ls2[12],7,2)+' '+copy(ls2[12],9,2)+':'+copy(ls2[12],11,2);
        ls2.Free;
        if SpecNo='' then SpecNo:=formatdatetime('nnss',now);
        ReceiveItemInfo:=VarArrayCreate([0,1-1],varVariant);
        ReceiveItemInfo[0]:=VarArrayof([dlttype,sValue,'','']);
        if bRegister and(dlttype<>'') then
        begin
          FInts :=CreateOleObject('Data2LisSvr.Data2Lis');
          FInts.fData2Lis(ReceiveItemInfo,(SpecNo),CheckDate,
            (GroupName),(SpecType),(SpecStatus),(EquipChar),
            (CombinID),'',(LisFormCaption),(ConnectString),
            (QuaContSpecNoG),(QuaContSpecNo),(QuaContSpecNoD),'',
            ifRecLog,true,YXJB,
            '',
            EquipUnid,
            '','','','',
            -1,-1,-1,-1,
            -1,-1,-1,-1,
            false,false,false,false);
          if not VarIsEmpty(FInts) then FInts:= unAssigned;
        end;
      end;
    end;
    ls.Free;
  end;
  ls5.Free;
end;

procedure TfrmMain.N3Click(Sender: TObject);
begin
  if (MessageDlg('�˳��󽫲��ٽ����豸����,ȷ���˳���', mtWarning, [mbYes, mbNo], 0) <> mrYes) then exit;
  application.Terminate;
end;

initialization
    hnd := CreateMutex(nil, True, Pchar(ExtractFileName(Application.ExeName)));
    if GetLastError = ERROR_ALREADY_EXISTS then
    begin
        MessageBox(application.Handle,pchar('�ó������������У�'),
                    'ϵͳ��ʾ',MB_OK+MB_ICONinformation);   
        Halt;
    end;

finalization
    if hnd <> 0 then CloseHandle(hnd);

end.




        

