
dim SHARED hInstance as HINSTANCE
dim SHARED hooks as ADDINHOOKS
dim SHARED lpHandles as ADDINHANDLES ptr
dim SHARED lpFunctions as ADDINFUNCTIONS ptr
dim SHARED lpData as ADDINDATA ptr
Dim Shared szName As ZString*260
Dim Shared szTemplate As ZString*260
Dim Shared szFile As ZString*260
Dim Shared szProc As ZString*260
Dim Shared lpCTLDBLCLICK As CTLDBLCLICK Ptr

Const szNULL=!"\0"
Const szCRLF=!"\13\10"
Const szDefProc="DialogProc"
Const szNone="(None)"
Const szOutput="(Output window)"
Const szDIALOGNAME="[*DIALOGNAME*]"
Const szDIALOGPROC="[*DIALOGPROC*]"
Const szCONTROLNAME="[*CONTROLNAME*]"
Const szCONTROLID="[*CONTROLID*]"

Const szBEGINDEF="[*BEGINDEF*]"
Const szENDDEF="[*ENDDEF*]"
Const szBEGINCREATE="[*BEGINCREATE*]"
Const szENDCREATE="[*ENDCREATE*]"
Const szBEGINPROC="[*BEGINPROC*]"
Const szENDPROC="[*ENDPROC*]"
Const szBEGINEVENT="[*BEGINEVENT*]"
Const szENDEVENT="[*ENDEVENT*]"
Const szBEGINBN_CLICKED="[*BEGINBN_CLICKED*]"
Const szENDBN_CLICKED="[*ENDBN_CLICKED*]"
Const szBEGINSELECTCASEID="[*BEGINSELECTCASEID*]"
Const szENDSELECTCASEID="[*ENDSELECTCASEID*]"
Const szBEGINCASEID="[*BEGINCASEID*]"
Const szENDCASEID="[*ENDCASEID*]"
