unit UfrmMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms,
  LYTray, Menus, StdCtrls, Buttons, ADODB,
  ActnList, AppEvnts, ComCtrls, ToolWin, ExtCtrls,
  registry,inifiles,Dialogs,
  StrUtils, DB, ComObj,Variants,CPort,ShellAPI;

type
  TfrmMain = class(TForm)
    LYTray1: TLYTray;
    PopupMenu1: TPopupMenu;
    N1: TMenuItem;
    N2: TMenuItem;
    N3: TMenuItem;
    ADOConnection1: TADOConnection;
    ApplicationEvents1: TApplicationEvents;
    CoolBar1: TCoolBar;
    ToolBar1: TToolBar;
    ToolButton3: TToolButton;
    ToolButton4: TToolButton;
    ToolButton8: TToolButton;
    ActionList1: TActionList;
    editpass: TAction;
    about: TAction;
    stop: TAction;
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
    procedure N3Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure N1Click(Sender: TObject);
    procedure ApplicationEvents1Activate(Sender: TObject);
    procedure ToolButton2Click(Sender: TObject);
    procedure BitBtn2Click(Sender: TObject);
    procedure BitBtn1Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure ToolButton5Click(Sender: TObject);
    procedure ToolButton7Click(Sender: TObject);
    procedure ComPort1RxChar(Sender: TObject; Count: Integer);
  private
    { Private declarations }
    procedure WMSyscommand(var message:TWMMouse);message WM_SYSCOMMAND;
    procedure UpdateConfig;{配置文件生效}
    function LoadInputPassDll:boolean;
    function MakeDBConn:boolean;
    function GetSpecNo(const Value:string):string; //取得联机号
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
  sCryptSeed='lc';//加解密种子
  //SEPARATOR=#$1C;
  sCONNECTDEVELOP='错误!请与开发商联系!' ;
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
  OnLineIDPrefix:string;//联机标识前缀
  ifRecLog:boolean;//是否记录调试日志

  RFM:STRING;       //返回数据
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

  if not result then messagedlg('对不起,您没有注册或注册码错误,请注册!',mtinformation,[mbok],0);
end;

function GetConnectString:string;
var
  Ini:tinifile;
  userid, password, datasource, initialcatalog: string;
  ifIntegrated:boolean;//是否集成登录模式

  pInStr,pDeStr:Pchar;
  i:integer;
begin
  result:='';
  
  Ini := tinifile.Create(ChangeFileExt(Application.ExeName,'.INI'));
  datasource := Ini.ReadString('连接数据库', '服务器', '');
  initialcatalog := Ini.ReadString('连接数据库', '数据库', '');
  ifIntegrated:=ini.ReadBool('连接数据库','集成登录模式',false);
  userid := Ini.ReadString('连接数据库', '用户', '');
  password := Ini.ReadString('连接数据库', '口令', '107DFC967CDCFAAF');
  Ini.Free;
  //======解密password
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
  if ifIntegrated then
    result := result + 'Integrated Security=SSPI;';
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var
  ctext        :string;
  reg          :tregistry;
begin
  rfm:='';
  
  ConnectString:=GetConnectString;
  UpdateConfig;
  if ifRegister then bRegister:=true else bRegister:=false;  

  Caption:='数据接收服务'+ExtractFileName(Application.ExeName);
  lytray1.Hint:='数据接收服务'+ExtractFileName(Application.ExeName);

//=============================初始化密码=====================================//
    reg:=tregistry.Create;
    reg.RootKey:=HKEY_CURRENT_USER;
    reg.OpenKey('\sunyear',true);
    ctext:=reg.ReadString('pass');
    if ctext='' then
    begin
        reg:=tregistry.Create;
        reg.RootKey:=HKEY_CURRENT_USER;
        reg.OpenKey('\sunyear',true);
        reg.WriteString('pass','JIHONM{');
        //MessageBox(application.Handle,pchar('感谢您使用智能监控系统，'+chr(13)+'请记住初始化密码：'+'lc'),
        //            '系统提示',MB_OK+MB_ICONinformation);     //WARNING
    end;
    reg.CloseKey;
    reg.Free;
//============================================================================//
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
    if LoadInputPassDll then action:=cafree else action:=caNone;
end;

procedure TfrmMain.N3Click(Sender: TObject);
begin
    if not LoadInputPassDll then exit;
    application.Terminate;
end;

procedure TfrmMain.N1Click(Sender: TObject);
begin
  show;
end;

procedure TfrmMain.ApplicationEvents1Activate(Sender: TObject);
begin
  hide;
end;

procedure TfrmMain.WMSyscommand(var message: TWMMouse);
begin
  inherited;
  if message.Keys=SC_MINIMIZE then hide;
  message.Result:=-1;
end;

procedure TfrmMain.UpdateConfig;
var
  INI:tinifile;
  CommName,BaudRate,DataBit,StopBit,ParityBit:string;
  autorun:boolean;
begin
  ini:=TINIFILE.Create(ChangeFileExt(Application.ExeName,'.ini'));

  CommName:=ini.ReadString(IniSection,'串口选择','COM1');
  BaudRate:=ini.ReadString(IniSection,'波特率','9600');
  DataBit:=ini.ReadString(IniSection,'数据位','8');
  StopBit:=ini.ReadString(IniSection,'停止位','1');
  ParityBit:=ini.ReadString(IniSection,'校验位','None');
  autorun:=ini.readBool(IniSection,'开机自动运行',false);
  ifRecLog:=ini.readBool(IniSection,'调试日志',false);

  GroupName:=trim(ini.ReadString(IniSection,'工作组',''));
  EquipChar:=trim(uppercase(ini.ReadString(IniSection,'仪器字母','')));//读出来是大写就万无一失了
  OnLineIDPrefix:=trim(ini.ReadString(IniSection,'联机标识前缀',''));
  SpecType:=ini.ReadString(IniSection,'默认样本类型','');
  SpecStatus:=ini.ReadString(IniSection,'默认样本状态','');
  CombinID:=ini.ReadString(IniSection,'组合项目代码','');

  LisFormCaption:=ini.ReadString(IniSection,'检验系统窗体标题','');

  QuaContSpecNoG:=ini.ReadString(IniSection,'高值质控联机号','9999');
  QuaContSpecNo:=ini.ReadString(IniSection,'常值质控联机号','9998');
  QuaContSpecNoD:=ini.ReadString(IniSection,'低值质控联机号','9997');

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
  try
    ComPort1.Open;
  except
    showmessage('串口'+ComPort1.Port+'打开失败!');
  end;
end;

function TfrmMain.LoadInputPassDll: boolean;
TYPE
    TDLLFUNC=FUNCTION:boolean;
VAR
    HLIB:THANDLE;
    DLLFUNC:TDLLFUNC;
    PassFlag:boolean;
begin
    result:=false;
    HLIB:=LOADLIBRARY('OnOffLogin.dll');
    IF HLIB=0 THEN BEGIN SHOWMESSAGE(sCONNECTDEVELOP);EXIT; END;
    DLLFUNC:=TDLLFUNC(GETPROCADDRESS(HLIB,'showfrmonofflogin'));
    IF @DLLFUNC=NIL THEN BEGIN SHOWMESSAGE(sCONNECTDEVELOP);EXIT; END;
    PassFlag:=DLLFUNC;
    FREELIBRARY(HLIB);
    result:=passflag;
end;

function TfrmMain.GetSpecNo(const Value:string):string; //取得联机号
var
  ls3,ls4:tstrings;
begin
  ls3:=StrToList(Value,'|');
  IF ls3.Count<3 then
  begin
    ls3.Free;
    result:=formatdatetime('nnss',now);
    exit;
  end;
  result:=ls3[2];
  ls3.Free;

  //迪瑞CS-600B Start
  ls4:=StrToList(result,'^');
  IF ls4.Count>1 then result:=ls4[1];
  ls4.Free;
  //迪瑞CS-600B Stop

  result:='0000'+trim(result);
  result:=rightstr(result,4);
end;

function StrToList(const SourStr:string;const Separator:string):TStrings;
//根据指定的分隔字符串(Separator)将字符串(SourStr)导入到字符串列表中
var
  vSourStr,s:string;
  ll,lll:integer;
begin
  vSourStr:=SourStr;
  Result := TStringList.Create;
  lll:=length(Separator);

  while pos(Separator,vSourStr)<>0 do
  begin
    ll:=pos(Separator,vSourStr);
    Result.Add(copy(vSourStr,1,ll-1));
    delete(vSourStr,1,ll+lll-1);
  end;
  Result.Add(vSourStr);
  s:=vSourStr;
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
    ss:='服务器'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
        '数据库'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
        '集成登录模式'+#2+'CheckListBox'+#2+#2+'0'+#2+#2+#3+
        '用户'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
        '口令'+#2+'Edit'+#2+#2+'0'+#2+#2+'1';
    if ShowOptionForm('连接数据库','连接数据库',Pchar(ss),Pchar(ChangeFileExt(Application.ExeName,'.ini'))) then
      goto labReadIni else application.Terminate;
  end;
end;

procedure TfrmMain.ToolButton2Click(Sender: TObject);
var
  ss:string;
begin
  if LoadInputPassDll then
  begin
    ss:='串口选择'+#2+'Combobox'+#2+'COM1'+#13+'COM2'+#13+'COM3'+#13+'COM4'+#2+'0'+#2+#2+#3+
      '波特率'+#2+'Combobox'+#2+'19200'+#13+'9600'+#13+'4800'+#13+'2400'+#13+'1200'+#2+'0'+#2+#2+#3+
      '数据位'+#2+'Combobox'+#2+'8'+#13+'7'+#13+'6'+#13+'5'+#2+'0'+#2+#2+#3+
      '停止位'+#2+'Combobox'+#2+'1'+#13+'1.5'+#13+'2'+#2+'0'+#2+#2+#3+
      '校验位'+#2+'Combobox'+#2+'None'+#13+'Even'+#13+'Odd'+#13+'Mark'+#13+'Space'+#2+'0'+#2+#2+#3+
      '工作组'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '仪器字母'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '联机标识前缀'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '检验系统窗体标题'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '默认样本类型'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '默认样本状态'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '组合项目代码'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '开机自动运行'+#2+'CheckListBox'+#2+#2+'1'+#2+#2+#3+
      '调试日志'+#2+'CheckListBox'+#2+#2+'0'+#2+'注:强烈建议在正常运行时关闭'+#2+#3+
      '高值质控联机号'+#2+'Edit'+#2+#2+'2'+#2+#2+#3+
      '常值质控联机号'+#2+'Edit'+#2+#2+'2'+#2+#2+#3+
      '低值质控联机号'+#2+'Edit'+#2+#2+'2'+#2+#2;

  if ShowOptionForm('',Pchar(IniSection),Pchar(ss),Pchar(ChangeFileExt(Application.ExeName,'.ini'))) then
	  UpdateConfig;
  end;
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
  showmessage('保存成功!');
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
  //rfm:=ls.Text;
  //ComPort1RxChar(nil,0);
  ls.Free;
end;

procedure TfrmMain.ToolButton5Click(Sender: TObject);
var
  ss:string;
begin
  ss:='RegisterNum'+#2+'Edit'+#2+#2+'0'+#2+'将该窗体标题栏上的字符串发给开发者,以获取注册码'+#2;
  if bRegister then exit;
  if ShowOptionForm(Pchar('注册:'+GetHDSn('C:\')+'-'+GetHDSn('D:\')+'-'+ChangeFileExt(ExtractFileName(Application.ExeName),'')),Pchar(IniSection),Pchar(ss),Pchar(ChangeFileExt(Application.ExeName,'.ini'))) then
    if ifRegister then bRegister:=true else bRegister:=false;
end;

procedure TfrmMain.ToolButton7Click(Sender: TObject);
begin
  if MakeDBConn then ConnectString:=GetConnectString;
end;

procedure TfrmMain.ComPort1RxChar(Sender: TObject; Count: Integer);
VAR
  SpecNo:string;
  i,j:integer;
  dlttype:string;
  sValue:string;
  FInts:OleVariant;
  ReceiveItemInfo:OleVariant;
  ls3,ls,ls2,ls4:tstrings;
  Str:string;
  CheckDate:string;
  msgRFM:STRING;//一个完整的消息
begin
  ComPort1.ReadStr(Str,count);
  
  if length(memo1.Lines.Text)>=60000 then memo1.Lines.Clear;//memo只能接受64K个字符
  memo1.Lines.Add(Str);
  WriteLog(pchar(Str));

{
希望将此程序做成标准的ASTM通信接口
传输过程：
I2000SR先传个05给LIS,开始搭建通信链路，Lis回复06,搭建通信链路成功。
I2000SR传数据(即消息message)给LIS,LIS收到一帧就回复06.
帧的格式：
<STX> FN text <ETX> C1 C2 <CR> <LF>
--注：实际上标准ASTM中,一帧大小最多为240字节,如果一个消息长度大于240,则会分为多帧传输,-------
--前面帧的格式是<STX><FN><TEXT><ETB><C1><C2><CR><LF>，---------------------------------------
--最后一帧的格式才是<STX> FN text <ETX> C1 C2 <CR> <LF>，但由于已将该仪器的帧大小设为64000,--
--所有前面帧格式理论上不可能出现-------------------------------------------------------------
Lis每收到一帧回复06
I2000SR传04给LIS,表示该次通信完成
}

  if Str=#$5 then//一次通信链路的开始
  begin
    rfm:='';
    rfm:=rfm+Str;
    ComPort1.WriteStr(ACK);//发送确认指令
    memo1.Lines.Add('发送06');
    WriteLog('发送06');
  end ELSE
  begin
    rfm:=rfm+Str;
    if rightstr(rfm,2)=#$D#$A then//收完一帧回复06(LIS的每个ComPort1RxChar事件接收到的数据并非完整的一帧，而是其中一部分数据)
    begin
      ComPort1.WriteStr(ACK);//发送确认指令//测试则注释
      memo1.Lines.Add('发送06');
      WriteLog('发送06');
    end;
  end;

  //Str:=#$4;//测试
  if pos(#$4,Str)>0 then//一次通信链路的结束
  begin
    while pos(#$2,rfm)>0 do
    begin
      delete(rfm,pos(#$2,rfm),2);//删除每帧的第一个字符(#$02),第二个字符(帧序号)
    end;
    while pos(#$17,rfm)>0 do
    begin
      delete(rfm,pos(#$17,rfm),5);//删除前面帧的最后5个字符<ETB><C1><C2><CR><LF>,暂时只发现GEM3000有ETB
    end;

    ls3:=TStringList.Create;
    ExtractStrings([#$D,#$A],[],Pchar(rfm),ls3);//将每行导入到字符串列表中
    for i :=0  to ls3.Count-1 do//该次通信的每一行
    begin
      if uppercase(leftstr(trim(ls3[i]),2))<>'L|' THEN continue;//消息尾//I2000SR在一个消息(message)中仅传输一个样本
    
      msgRFM:=copy(rfm,1,pos(ls3[i],rfm));//msgRFM表示一个完整的消息
      rfm:=copy(rfm,pos(ls3[i],rfm)+length(ls3[i]),MaxInt);

      if pos('O|',uppercase(msgRFM))<=0 then continue;//样本号行
      if pos('R|',uppercase(msgRFM))<=0 then continue;//结果行

      SpecNo:='';CheckDate:='';

      ls:=TStringList.Create;
      ExtractStrings([#$D,#$A],[],Pchar(msgRFM),ls);//将消息的每行导入到字符串列表中
      ReceiveItemInfo:=VarArrayCreate([0,ls.Count-1],varVariant);
      for j :=0  to ls.Count-1 do//一个消息中的每一行
      begin
        dlttype:='';sValue:='';
        ls2:=StrToList(ls[j],'|');
        if ls2.Count>3 then
        begin
          ls4:=StrToList(ls2[2],'^');//ls2[2]中有可能包含试剂批号信息，故联机标识需再取细点
          if ls4.Count>4 then
          begin
            if rightstr(ls2[2],2)='^F' then dlttype:=OnLineIDPrefix+ls4[4];//结果值有可能有几种(实际结果、比率等)，^F貌似是实际结果
          end else dlttype:=OnLineIDPrefix+ls2[2];
          ls4.Free;
          
          sValue:=ls2[3];
        end;
        if (uppercase(leftstr(trim(ls[j]),2))='R|')AND(ls2.Count>12) then CheckDate:=copy(ls2[12],1,4)+'-'+copy(ls2[12],5,2)+'-'+copy(ls2[12],7,2)+' '+copy(ls2[12],9,2)+':'+copy(ls2[12],11,2);
        ls2.Free;
        if uppercase(leftstr(trim(ls[j]),2))='O|' then SpecNo:=GetSpecNo(ls[j]);
        ReceiveItemInfo[j]:=VarArrayof([dlttype,sValue,'','']);
      end;
      ls.Free;

      if SpecNo='' then SpecNo:=formatdatetime('nnss',now);

      if bRegister then
      begin
        FInts :=CreateOleObject('Data2LisSvr.Data2Lis');
        FInts.fData2Lis(ReceiveItemInfo,(SpecNo),CheckDate,
          (GroupName),(SpecType),(SpecStatus),(EquipChar),
          (CombinID),'',(LisFormCaption),(ConnectString),
          (QuaContSpecNoG),(QuaContSpecNo),(QuaContSpecNoD),'',
          ifRecLog,true,'常规');
        if not VarIsEmpty(FInts) then FInts:= unAssigned;
      end;
    
    end;
    ls3.Free;
  end;
end;

initialization
    hnd := CreateMutex(nil, True, Pchar(ExtractFileName(Application.ExeName)));
    if GetLastError = ERROR_ALREADY_EXISTS then
    begin
        MessageBox(application.Handle,pchar('该程序已在运行中！'),
                    '系统提示',MB_OK+MB_ICONinformation);   
        Halt;
    end;

finalization
    if hnd <> 0 then CloseHandle(hnd);

end.




        

