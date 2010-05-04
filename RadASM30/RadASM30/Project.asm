
;NewProject.dlg
IDD_DLGNEWPROJECT				equ 3000
IDC_CBOASSEMBLER				equ 1002
IDC_EDTPROJECTNAME				equ 1004
IDC_EDTPROJECTDESC				equ 1005
IDC_EDTPROJECTPATH				equ 1007
IDC_BTNPROJECTPATH				equ 1009
IDC_CHKPROJECTSUB				equ 1011
IDC_CHKPROJECTBAK				equ 1012
IDC_CHKPROJECTRES				equ 1013
IDC_CHKPROJECTINC				equ 1014
IDC_CHKPROJECTMOD				equ 1015
IDC_TABNEWPROJECT				equ 1016


;NewProjectTab1.dlg
IDD_DLGNEWPROJECTTAB1			equ 3010
IDC_CHKHEADER					equ 1004
IDC_CHKCODE						equ 1005
IDC_CHKRESOURCE					equ 1006
IDC_CHKTEXT						equ 1007

;NewProjectTab2.dlg
IDD_DLGNEWPROJECTTAB2			equ 3020
IDC_LSTPROJECTBUILD				equ 1001

;NewProjectTab3.dlg
IDD_DLGNEWPROJECTTAB3			equ 3030
IDC_LSTPROJECTTEMPLATE			equ 1002
IDC_STCPROJECTTEMPLATE			equ 1001

.const

szTabFiles						db 'Files',0
szTabBuild						db 'Build',0
szTabTemplate					db 'Template',0
szTemplateNone					db '(None)',0
szBrowseProjectPath				db 'Browse For Project Path',0
szDefGroup1						db '2,-1,0,1,',0
szDefGroup2						db ',-2,-1,1,Assembly,-3,-1,1,Include,-4,-1,1,Misc,-5,-1,1,Resource',0
szBSAllDotTpl					db '\*.tpl',0
szBSTemplates					db '\Templates',0
szPROJECTNAME					db '[*PROJECTNAME*]',0
szBEGINTXT						db '[*BEGINTXT*]',0
szENDTXT						db '[*ENDTXT*]',0
szBEGINBIN						db '[*BEGINBIN*]',0
szENDBIN						db '[*ENDBIN*]',0

.data?

hTabNewProject					HWND 4 dup(?)
projectfile						BYTE MAX_PATH dup(?)
templatepath					BYTE MAX_PATH dup(?)

.code

FolderCreate proc hWin:HWND,lpPath:DWORD,lpFolder:DWORD
	LOCAL	buffer[MAX_PATH]:BYTE

	invoke strcpy,addr buffer,lpPath
	invoke strcat,addr buffer,offset szBS
	invoke strcat,addr buffer,lpFolder
	invoke CreateDirectory,addr buffer,NULL
	.if !eax
		invoke strcpy,offset tmpbuff,offset szErrDir
		invoke strcat,offset tmpbuff,addr buffer
		invoke MessageBox,hWin,offset tmpbuff,offset DisplayName,MB_OK or MB_ICONERROR
		xor		eax,eax
	.else
		invoke strcpy,offset tmpbuff,addr buffer
		mov		eax,offset tmpbuff
	.endif
	ret

FolderCreate endp

FileFolderCreate proc uses ebx esi,lpFile:DWORD
	LOCAL	buffer[MAX_PATH]:BYTE

	invoke lstrcpy,addr buffer,lpFile
	lea		esi,buffer
	xor		ebx,ebx
	xor		ecx,ecx
	.while byte ptr [esi+ecx]
		.if byte ptr [esi+ecx]=='\'
			mov		byte ptr [esi+ecx],0
			inc		ebx
		.endif
		inc		ecx
	.endw
	.while ebx
		invoke CreateDirectory,esi,NULL
		xor		ecx,ecx
		.while byte ptr [esi+ecx]
			inc		ecx
		.endw
		mov		byte ptr [esi+ecx],'\'
		dec		ebx
	.endw
	ret

FileFolderCreate endp

FileCreate proc hWin:HWND,lpPath:DWORD,lpFile:DWORD,lpExt:DWORD,lpFileData:DWORD,nFileSize:DWORD
	LOCAL	buffer[MAX_PATH]:BYTE
	LOCAL	hFile:HANDLE
	LOCAL	bytes:DWORD

	invoke strcpy,addr buffer,lpPath
	invoke strcat,addr buffer,offset szBS
	invoke strcat,addr buffer,lpFile
	invoke strcat,addr buffer,lpExt
	; Check if file exists
	invoke GetFileAttributes,addr buffer
	.if eax!=-1
		; File exists
		invoke lstrcpy,offset tmpbuff,offset szErrOverwrite
		invoke lstrcat,offset tmpbuff,addr buffer
		invoke MessageBox,hWin,offset tmpbuff,offset DisplayName,MB_YESNO or MB_ICONERROR
		.if eax==IDNO
			jmp		ExExist
		.endif
	.endif
	invoke FileFolderCreate,addr buffer
	invoke CreateFile,addr buffer,GENERIC_READ or GENERIC_WRITE,FILE_SHARE_READ,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL
	.if eax==INVALID_HANDLE_VALUE
		; File could not be created
		invoke lstrcpy,offset tmpbuff,offset szErrCreate
		invoke lstrcat,offset tmpbuff,addr buffer
		invoke MessageBox,hWin,offset tmpbuff,offset DisplayName,MB_YESNO or MB_ICONERROR
		xor		eax,eax
		jmp		Ex
	.endif
	mov		hFile,eax
	.if lpFileData
		; Write file data
		invoke WriteFile,hFile,lpFileData,nFileSize,addr bytes,NULL
	.endif
	invoke CloseHandle,hFile
  ExExist:
	invoke strcpy,addr tmpbuff,lpFile
	invoke strcat,addr tmpbuff,lpExt
	mov		eax,offset tmpbuff
  Ex:
	ret

FileCreate endp

IsLine proc uses ebx esi edi,lpLine:DWORD,lpWord:DWORD,fIgnore:DWORD

	mov		esi,lpWord
	mov		edi,lpLine
	mov		ebx,TRUE
	.while byte ptr [esi]
		mov		al,[esi]
		mov		ah,[edi]
		.if fIgnore
			.if al>='a' && al<='z'
				and		al,5Fh
			.endif
			.if ah>='a' && ah<='z'
				and		ah,5Fh
			.endif
		.endif
		.if al!=ah
			xor		eax,eax
			jmp		Ex
		.endif
		inc		esi
		inc		edi
	.endw
	mov		eax,edi
	sub		eax,lpLine
  Ex:
	ret

IsLine endp

TemplateCreate proc uses ebx esi edi,hWin:HWND,nTemplate:DWORD,lpPath:DWORD,lpFile:DWORD
	LOCAL	buffer[MAX_PATH]:BYTE
	LOCAL	hFile:HANDLE
	LOCAL	bytes:DWORD
	LOCAL	hTemplateMem:HGLOBAL
	LOCAL	hOutMem:HGLOBAL
	LOCAL	nFun:DWORD
	LOCAL	nBuild:DWORD
	LOCAL	filename[MAX_PATH]:BYTE
	LOCAL	fileext[MAX_PATH]:BYTE
	LOCAL	nFiles:DWORD

	invoke SendDlgItemMessage,hTabNewProject[12],IDC_LSTPROJECTTEMPLATE,LB_GETTEXT,nTemplate,addr buffer
	invoke lstrcpy,offset tmpbuff,addr templatepath
	invoke lstrcat,offset tmpbuff,offset szBS
	invoke lstrcat,offset tmpbuff,addr buffer
	invoke lstrcpy,addr buffer,offset tmpbuff
	invoke GetFileAttributes,addr buffer
	.if eax!=INVALID_HANDLE_VALUE
		invoke CreateFile,addr buffer,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL
		.if eax!=INVALID_HANDLE_VALUE
			mov		hFile,eax
			invoke GetFileSize,hFile,NULL
			mov		ebx,eax
			invoke GlobalAlloc,GMEM_FIXED or GMEM_ZEROINIT,addr [ebx+1]
			mov		hTemplateMem,eax
			invoke ReadFile,hFile,hTemplateMem,ebx,addr bytes,NULL
			invoke CloseHandle,hFile
			invoke GlobalAlloc,GMEM_FIXED or GMEM_ZEROINIT,1024*1024
			mov		hOutMem,eax
			mov		esi,hTemplateMem
			call	Template
			invoke GlobalFree,hTemplateMem
			mov		eax,TRUE
		.else
			xor		eax,eax
		.endif
	.else
		xor		eax,eax
	.endif
	ret

GetLine:
	push	edi
	mov		edi,offset tmpbuff
	.while byte ptr [esi] && byte ptr [esi]!=VK_RETURN
		mov		al,[esi]
		mov		[edi],al
		inc		esi
		inc		edi
	.endw
	mov		byte ptr [edi],0
	.if byte ptr [esi]==VK_RETURN
		inc		esi
	.endif
	.if byte ptr [esi]==0Ah
		inc		esi
	.endif
	pop		edi
	retn

PutLine:
	push	esi
	mov		esi,offset tmpbuff
	.while byte ptr [esi]
		invoke IsLine,esi,offset szPROJECTNAME,FALSE
		.if eax
			lea		esi,[esi+eax]
			invoke lstrcpy,edi,lpFile
			invoke lstrlen,edi
			lea		edi,[edi+eax]
		.else
			mov		al,[esi]
			mov		[edi],al
			inc		esi
			inc		edi
		.endif
	.endw
	mov		dword ptr [edi],0A0Dh
	add		edi,2
	pop		esi
	retn

PutLineHex:
	push	esi
	mov		esi,offset tmpbuff
	.while byte ptr [esi]
		mov		ax,[esi]
		.if al<'A'
			and		al,0Fh
		.else
			sub		al,'A'-10
		.endif
		.if ah<'A'
			and		ah,0Fh
		.else
			sub		ah,'A'-10
		.endif
		add		esi,2
		shl		al,4
		or		al,ah
		mov		[edi],al
		inc		edi
	.endw
	pop		esi
	retn

GetFileName:
	call	GetLine
	push	esi
	mov		esi,offset tmpbuff
	mov		filename,0
	mov		fileext,0
	lea		edi,filename
	.while byte ptr [esi]
		invoke IsLine,esi,offset szPROJECTNAME,FALSE
		.if eax
			lea		esi,[esi+eax]
			invoke lstrcpy,edi,lpFile
			invoke lstrlen,edi
			lea		edi,[edi+eax]
		.elseif byte ptr [esi]=='.'
			lea		edi,fileext
			movzx	eax,byte ptr [esi]
			mov		[edi],ax
			inc		esi
			inc		edi
		.else
			movzx	eax,byte ptr [esi]
			mov		[edi],ax
			inc		esi
			inc		edi
		.endif
	.endw
	pop		esi
	retn

Template:
	mov		nFun,0
	mov		nBuild,0
	mov		nFiles,0
	.while byte ptr [esi]
		call	GetLine
		.if nFun==0
			mov		nFun,1
		.elseif nFun==1
			invoke IsLine,offset tmpbuff,offset szBEGINTXT,FALSE
			.if eax
				call	GetFileName
				mov		edi,hOutMem
				mov		nFun,2
			.else
				invoke IsLine,offset tmpbuff,offset szBEGINBIN,FALSE
				.if eax
					call	GetFileName
					mov		edi,hOutMem
					mov		nFun,3
				.endif
			.endif
		.elseif nFun==2
			invoke IsLine,offset tmpbuff,offset szENDTXT,FALSE
			.if eax
				sub		edi,hOutMem
				invoke FileCreate,hWin,lpPath,addr filename,addr fileext,hOutMem,edi
				mov		nFun,1
				inc		nFiles
			.else
				call	PutLine
			.endif
		.elseif nFun==3
			invoke IsLine,offset tmpbuff,offset szENDBIN,FALSE
			.if eax
				sub		edi,hOutMem
				invoke FileCreate,hWin,lpPath,addr filename,addr fileext,hOutMem,edi
				mov		nFun,1
				inc		nFiles
			.else
				call	PutLineHex
			.endif
		.endif
	.endw
	retn

TemplateCreate endp

ProjectCreate proc uses ebx esi edi,hWin:HWND
	LOCAL	projectpath[MAX_PATH]:BYTE
	LOCAL	projectname[64]:BYTE
	LOCAL	projectdesc[64]:BYTE
	LOCAL	fileext[64]:BYTE
	LOCAL	filename[128]:BYTE
	LOCAL	buffer[8]:BYTE

	;Get project name
	invoke GetDlgItemText,hWin,IDC_EDTPROJECTNAME,addr projectname,sizeof projectname
	;Get project description
	invoke GetDlgItemText,hWin,IDC_EDTPROJECTDESC,addr projectdesc,sizeof projectdesc
	;Get the project path
	invoke GetDlgItemText,hWin,IDC_EDTPROJECTPATH,addr projectpath,sizeof projectpath
	;Create sub folders
	invoke IsDlgButtonChecked,hWin,IDC_CHKPROJECTSUB
	.if eax
		;Create project sub folder
		invoke FolderCreate,hWin,addr projectpath,addr projectname
		.if !eax
			jmp		ExErr
		.endif
		invoke strcpy,addr projectpath,eax
	.endif
	;Make project filename
	invoke strcpy,addr projectfile,addr projectpath
	invoke strcat,addr projectfile,addr szBS
	invoke strcat,addr projectfile,addr projectname
	invoke strcat,addr projectfile,addr szDotPrra
	;Create folders
	invoke IsDlgButtonChecked,hWin,IDC_CHKPROJECTBAK
	.if eax
		;Create project bak folder
		invoke GetDlgItemText,hWin,IDC_CHKPROJECTBAK,addr tmpbuff,sizeof tmpbuff
		invoke FolderCreate,hWin,addr projectpath,addr tmpbuff
	.endif
	invoke IsDlgButtonChecked,hWin,IDC_CHKPROJECTINC
	.if eax
		;Create project inc folder
		invoke GetDlgItemText,hWin,IDC_CHKPROJECTINC,addr tmpbuff,sizeof tmpbuff
		invoke FolderCreate,hWin,addr projectpath,addr tmpbuff
	.endif
	invoke IsDlgButtonChecked,hWin,IDC_CHKPROJECTMOD
	.if eax
		;Create project mod folder
		invoke GetDlgItemText,hWin,IDC_CHKPROJECTMOD,addr tmpbuff,sizeof tmpbuff
		invoke FolderCreate,hWin,addr projectpath,addr tmpbuff
	.endif
	invoke IsDlgButtonChecked,hWin,IDC_CHKPROJECTRES
	.if eax
		;Create project res folder
		invoke GetDlgItemText,hWin,IDC_CHKPROJECTRES,addr tmpbuff,sizeof tmpbuff
		invoke FolderCreate,hWin,addr projectpath,addr tmpbuff
	.endif
	invoke SendDlgItemMessage,hTabNewProject[12],IDC_LSTPROJECTTEMPLATE,LB_GETCURSEL,0,0
	.if eax
		;A template is selected
		mov		edx,eax
		invoke TemplateCreate,hWin,edx,addr projectpath,addr projectname
	.else
		;Version
		invoke BinToDec,3000,addr tmpbuff
		invoke WritePrivateProfileString,addr szIniVersion,addr szIniVersion,addr tmpbuff,addr projectfile
		;Assembler
		invoke SendDlgItemMessage,hWin,IDC_CBOASSEMBLER,CB_GETCURSEL,0,0
		mov		edx,eax
		invoke SendDlgItemMessage,hWin,IDC_CBOASSEMBLER,CB_GETLBTEXT,edx,addr tmpbuff
		invoke WritePrivateProfileString,addr szIniProject,addr szIniAssembler,addr tmpbuff,addr projectfile
		;Filebrowser path
		invoke WritePrivateProfileString,addr szIniProject,addr szIniPath,addr projectpath,addr projectfile
		;Project groups
		invoke strcpy,addr tmpbuff,addr szDefGroup1
		.if projectdesc
			invoke strcat,addr tmpbuff,addr projectdesc
		.else
			invoke strcat,addr tmpbuff,addr projectname
		.endif
		invoke strcat,addr tmpbuff,addr szDefGroup2
		invoke WritePrivateProfileString,addr szIniProject,addr szIniGroup,addr tmpbuff,addr projectfile
		;Create files
		mov		ebx,1
		invoke IsDlgButtonChecked,hTabNewProject[4],IDC_CHKCODE
		.if eax
			;Create main code (asm) file
			invoke GetPrivateProfileString,addr szIniProject,addr szIniCode,addr szNULL,addr fileext,sizeof fileext,addr da.szAssemblerIni
			invoke FileCreate,hWin,addr projectpath,addr projectname,addr fileext,NULL,0
			.if eax
				invoke strcpy,addr filename,eax
				mov		eax,-2			;Group
				mov		edi,2			;Main
				mov		esi,ID_EDITCODE	;File type
				call	AddFile
			.endif
		.endif
		invoke IsDlgButtonChecked,hTabNewProject[4],IDC_CHKHEADER
		.if eax
			;Create header (inc) file
			invoke GetPrivateProfileString,addr szIniProject,addr szIniHeader,addr szNULL,addr fileext,sizeof fileext,addr da.szAssemblerIni
			invoke FileCreate,hWin,addr projectpath,addr projectname,addr fileext,NULL,0
			.if eax
				invoke strcpy,addr filename,eax
				mov		eax,-3			;Group
				mov		edi,0			;Main
				mov		esi,ID_EDITCODE	;File type
				call	AddFile
			.endif
		.endif
		invoke IsDlgButtonChecked,hTabNewProject[4],IDC_CHKRESOURCE
		.if eax
			;Create main rc file
			mov		dword ptr fileext,'cr.'
			invoke FileCreate,hWin,addr projectpath,addr projectname,addr fileext,NULL,0
			.if eax
				invoke strcpy,addr filename,eax
				mov		eax,-5			;Group
				mov		edi,2			;Main
				mov		esi,ID_EDITRES	;File type
				call	AddFile
			.endif
		.endif
		invoke IsDlgButtonChecked,hTabNewProject[4],IDC_CHKTEXT
		.if eax
			;Create txt file
			mov		dword ptr fileext,'txt.'
			mov		byte ptr fileext[4],0
			invoke FileCreate,hWin,addr projectpath,addr projectname,addr fileext,NULL,0
			.if eax
				invoke strcpy,addr filename,eax
				mov		eax,-4			;Group
				mov		edi,0			;Main
				mov		esi,ID_EDITTEXT	;File type
				call	AddFile
			.endif
		.endif
		;Make options
		xor		ebx,ebx
		xor		edi,edi
		;Selected make option
		invoke BinToDec,ebx,addr buffer
		invoke WritePrivateProfileString,addr szIniMake,addr szIniMake,addr buffer,addr projectfile
		.while TRUE
			invoke SendDlgItemMessage,hTabNewProject[8],IDC_LSTPROJECTBUILD,LB_GETSEL,ebx,0
			.break .if eax==LB_ERR
			.if eax
				invoke BinToDec,ebx,addr buffer
				invoke GetPrivateProfileString,addr szIniMake,addr buffer,addr szNULL,addr tmpbuff,sizeof tmpbuff,addr da.szAssemblerIni
				invoke BinToDec,edi,addr buffer
				invoke WritePrivateProfileString,addr szIniMake,addr buffer,addr tmpbuff,addr projectfile
				inc		edi
			.endif
			inc		ebx
		.endw
	.endif
	mov		eax,offset projectfile
	ret
  ExErr:
	xor		eax,eax
	ret

AddFile:
	mov		tmpbuff,0
	;Group
	invoke PutItemInt,addr tmpbuff,eax
	;Main
	invoke PutItemInt,addr tmpbuff,edi
	;Type
	invoke PutItemInt,addr tmpbuff,edi
	;Left
	mov		eax,22
	mul		ebx
	invoke PutItemInt,addr tmpbuff,eax
	;Top
	mov		eax,22
	mul		ebx
	invoke PutItemInt,addr tmpbuff,eax
	;Width
	invoke PutItemInt,addr tmpbuff,600
	;Height
	invoke PutItemInt,addr tmpbuff,400
	;Line
	invoke PutItemInt,addr tmpbuff,0
	;Filename
	invoke PutItemStr,addr tmpbuff,addr filename
	mov		buffer,'F'
	invoke BinToDec,ebx,addr buffer[1]
	invoke WritePrivateProfileString,addr szIniProject,addr buffer,addr tmpbuff[1],addr projectfile
	inc		ebx
	retn

ProjectCreate endp

GetProjectTemplates proc hWin:HWND,lpPath:DWORD
	LOCAL	wfd:WIN32_FIND_DATA
	LOCAL	hwfd:HANDLE
	LOCAL	buffer[MAX_PATH]:BYTE

	invoke SendMessage,hWin,LB_RESETCONTENT,0,0
	invoke SendMessage,hWin,LB_ADDSTRING,0,offset szTemplateNone
	invoke strcpy,addr buffer,lpPath
	invoke strcat,addr buffer,offset szBSAllDotTpl
	invoke FindFirstFile,addr buffer,addr wfd
	.if eax!=INVALID_HANDLE_VALUE
		mov		hwfd,eax
		.while TRUE
			invoke SendMessage,hWin,LB_ADDSTRING,0,addr wfd.cFileName
			invoke FindNextFile,hwfd,addr wfd
			.break .if !eax
		.endw
		invoke FindClose,hwfd
	.endif
	invoke SendMessage,hWin,LB_SETCURSEL,0,0
	ret

GetProjectTemplates endp

;File creation
NewProjectTab1 proc hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
		invoke CheckDlgButton,hWin,IDC_CHKCODE,BST_CHECKED
		invoke CheckDlgButton,hWin,IDC_CHKPROJECTBAK,BST_CHECKED
	.else
		mov		eax,FALSE
		jmp		Ex
	.endif
	mov		eax,TRUE
  Ex:
	ret

NewProjectTab1 endp

;Make options
NewProjectTab2 proc hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
	.elseif eax==WM_COMMAND
		mov		edx,wParam
		movzx	eax,dx
		shr		edx,16
		.if edx==LBN_SELCHANGE
			;Check if any items are selected
			invoke SendDlgItemMessage,hWin,IDC_LSTPROJECTBUILD,LB_GETSELCOUNT,0,0
			.if !eax
				;None selected, reselect the item
				invoke SendDlgItemMessage,hWin,IDC_LSTPROJECTBUILD,LB_GETCURSEL,0,0
				invoke SendDlgItemMessage,hWin,IDC_LSTPROJECTBUILD,LB_SETSEL,TRUE,eax
			.endif
		.endif
	.else
		mov		eax,FALSE
		jmp		Ex
	.endif
	mov		eax,TRUE
  Ex:
	ret

NewProjectTab2 endp

;Templates
NewProjectTab3 proc hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	LOCAL	nInx:DWORD
	LOCAL	hFile:HANDLE
	LOCAL	buffer[MAX_PATH]:BYTE

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
	.elseif eax==WM_COMMAND
		mov		edx,wParam
		movzx	eax,dx
		shr		edx,16
		.if edx==LBN_SELCHANGE
			mov		buffer,0
			invoke SendDlgItemMessage,hWin,IDC_LSTPROJECTTEMPLATE,LB_GETCURSEL,0,0
			.if sdword ptr eax>0
				push	eax
				invoke strcpy,addr buffer,offset templatepath
				invoke lstrcat,addr buffer,offset szBS
				invoke lstrlen,addr buffer
				pop		edx
				invoke SendDlgItemMessage,hWin,IDC_LSTPROJECTTEMPLATE,LB_GETTEXT,edx,addr buffer[eax]
				invoke CreateFile,addr buffer,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0
				.if eax!=INVALID_HANDLE_VALUE
					mov		hFile,eax
					invoke RtlZeroMemory,addr buffer,sizeof buffer
					invoke ReadFile,hFile,addr buffer,sizeof buffer-1,addr nInx,NULL
					xor		eax,eax
					.while eax<sizeof buffer
						.if buffer[eax]==0Dh
							mov		buffer[eax],0
							.break
						.endif
						inc		eax
					.endw
					invoke CloseHandle,hFile
				.endif
			.endif
			invoke SetDlgItemText,hWin,IDC_STCPROJECTTEMPLATE,addr buffer
		.endif
	.else
		mov		eax,FALSE
		jmp		Ex
	.endif
	mov		eax,TRUE
  Ex:
	ret

NewProjectTab3 endp

NewProjectProc proc uses ebx esi edi,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	LOCAL	tci:TC_ITEM
	LOCAL	buffer[MAX_PATH]:BYTE
	LOCAL	buffer1[128]:BYTE

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
		mov		eax,hWin
		mov		hTabNewProject[0],eax
		;Create the tabs
		invoke GetDlgItem,hWin,IDC_TABNEWPROJECT
		mov		hTabNewProject,eax
		mov		tci.imask,TCIF_TEXT
		mov		tci.pszText,offset szTabFiles
		invoke SendMessage,hTabNewProject,TCM_INSERTITEM,0,addr tci
		mov		tci.pszText,offset szTabBuild
		invoke SendMessage,hTabNewProject,TCM_INSERTITEM,1,addr tci
		mov		tci.pszText,offset szTabTemplate
		invoke SendMessage,hTabNewProject,TCM_INSERTITEM,2,addr tci
		;Create the tab dialogs
		;Files dialog
		invoke CreateDialogParam,ha.hInstance,IDD_DLGNEWPROJECTTAB1,hTabNewProject,addr NewProjectTab1,0
		mov		hTabNewProject[4],eax
		;Build dialog
		invoke CreateDialogParam,ha.hInstance,IDD_DLGNEWPROJECTTAB2,hTabNewProject,addr NewProjectTab2,0
		mov		hTabNewProject[8],eax
		;Template dialog
		invoke CreateDialogParam,ha.hInstance,IDD_DLGNEWPROJECTTAB3,hTabNewProject,addr NewProjectTab3,0
		mov		hTabNewProject[12],eax
		mov		SelTab,1
		;Add assemblers
		invoke strcpy,addr tmpbuff,addr da.szAssemblers
		.while tmpbuff
			invoke GetItemStr,addr tmpbuff,addr szNULL,addr buffer,sizeof buffer
			invoke SendDlgItemMessage,hWin,IDC_CBOASSEMBLER,CB_ADDSTRING,0,addr buffer
		.endw
		invoke SendDlgItemMessage,hWin,IDC_CBOASSEMBLER,CB_SETCURSEL,0,0
		invoke CheckDlgButton,hWin,IDC_CHKPROJECTSUB,BST_CHECKED
		invoke CheckDlgButton,hWin,IDC_CHKPROJECTBAK,BST_CHECKED
		invoke SendMessage,hWin,WM_COMMAND,CBN_SELCHANGE shl 16 or IDC_CBOASSEMBLER,hWin
	.elseif eax==WM_COMMAND
		mov		edx,wParam
		movzx	eax,dx
		shr		edx,16
		.if edx==BN_CLICKED
			.if eax==IDOK
				invoke ProjectCreate,hWin
				.if eax
					invoke OpenTheFile,eax,ID_PROJECT
				.endif
				invoke SendMessage,hWin,WM_CLOSE,NULL,NULL
			.elseif eax==IDCANCEL
				invoke SendMessage,hWin,WM_CLOSE,NULL,NULL
			.elseif eax==IDC_BTNPROJECTPATH
				invoke BrowseFolder,hWin,IDC_EDTPROJECTPATH,addr szBrowseProjectPath
			.endif
		.elseif edx==EN_CHANGE
			.if eax==IDC_EDTPROJECTNAME
				invoke GetDlgItem,hWin,IDOK
				mov		ebx,eax
				invoke SendDlgItemMessage,hWin,IDC_EDTPROJECTNAME,WM_GETTEXTLENGTH,0,0
				invoke EnableWindow,ebx,eax
			.endif
		.elseif edx==CBN_SELCHANGE
			invoke SendDlgItemMessage,hWin,IDC_CBOASSEMBLER,CB_GETCURSEL,0,0
			mov		ebx,eax
			invoke SendDlgItemMessage,hTabNewProject[8],IDC_LSTPROJECTBUILD,LB_RESETCONTENT,0,0
			invoke SendDlgItemMessage,hTabNewProject[12],IDC_LSTPROJECTTEMPLATE,LB_RESETCONTENT,0,0
			;Get the assembler.ini
			invoke SendDlgItemMessage,hWin,IDC_CBOASSEMBLER,CB_GETLBTEXT,ebx,addr buffer
			invoke strcpy,addr tmpbuff,addr da.szAppPath
			invoke strcat,addr tmpbuff,addr szBS
			invoke strcat,addr tmpbuff,addr buffer
			invoke strcat,addr tmpbuff,addr szDotIni
			invoke GetFileAttributes,addr tmpbuff
			.if eax!=INVALID_HANDLE_VALUE
				invoke strcpy,addr buffer,addr tmpbuff
				;Get path to templates
				invoke strcpy,addr templatepath,addr tmpbuff
				invoke RemoveFileName,addr templatepath
				invoke strcat,addr templatepath,addr szBS
				invoke strlen,addr templatepath
				invoke SendDlgItemMessage,hWin,IDC_CBOASSEMBLER,CB_GETLBTEXT,ebx,addr templatepath[eax]
				invoke strcat,addr templatepath,addr szBSTemplates
				;Get build types
				xor		ebx,ebx
				.while ebx<32
					invoke BinToDec,ebx,addr buffer1
					invoke GetPrivateProfileString,addr szIniMake,addr buffer1,addr szNULL,addr tmpbuff,sizeof tmpbuff,addr buffer
					.if eax
						invoke GetItemStr,addr tmpbuff,addr szNULL,addr buffer1,sizeof buffer1
						invoke SendDlgItemMessage,hTabNewProject[8],IDC_LSTPROJECTBUILD,LB_ADDSTRING,0,addr buffer1
						invoke SendDlgItemMessage,hTabNewProject[8],IDC_LSTPROJECTBUILD,LB_SETITEMDATA,eax,ebx
					.endif
					inc		ebx
				.endw
				invoke SendDlgItemMessage,hTabNewProject[8],IDC_LSTPROJECTBUILD,LB_SETSEL,TRUE,0
				;Get templates
				invoke GetDlgItem,hTabNewProject[12],IDC_LSTPROJECTTEMPLATE
				invoke GetProjectTemplates,eax,addr templatepath
				;Default project path
				invoke GetPrivateProfileString,addr szIniProject,addr szIniPath,addr szNULL,addr tmpbuff,MAX_PATH,addr buffer
				invoke FixPath,addr tmpbuff,addr da.szAppPath,addr szDollarA
				invoke SetDlgItemText,hWin,IDC_EDTPROJECTPATH,addr tmpbuff
			.endif
			invoke GetDlgItem,hWin,IDOK
			mov		ebx,eax
			invoke SendDlgItemMessage,hWin,IDC_EDTPROJECTNAME,WM_GETTEXTLENGTH,0,0
			invoke EnableWindow,ebx,eax
		.endif
	.elseif eax==WM_CLOSE
		invoke EndDialog,hWin,NULL
	.elseif eax==WM_NOTIFY
		mov		eax,lParam
		mov		eax,[eax].NMHDR.code
		.if eax==TCN_SELCHANGE
			;Tab selection
			invoke SendMessage,hTabNewProject,TCM_GETCURSEL,0,0
			inc		eax
			.if eax!=SelTab
				push	eax
				mov		eax,SelTab
				invoke ShowWindow,[hTabNewProject+eax*4],SW_HIDE
				pop		eax
				mov		SelTab,eax
				invoke ShowWindow,[hTabNewProject+eax*4],SW_SHOWDEFAULT
			.endif
		.endif
	.else
		mov		eax,FALSE
		jmp		Ex
	.endif
	mov		eax,TRUE
  Ex:
	ret

NewProjectProc endp

AddNewProjectFile proc
	LOCAL	ofn:OPENFILENAME
	LOCAL	buffer[MAX_PATH]:BYTE

	invoke SendMessage,ha.hProjectBrowser,RPBM_GETSELECTED,0,0
	.if eax
		;Zero out the ofn struct
	    invoke RtlZeroMemory,addr ofn,sizeof ofn
		;Setup the ofn struct
		mov		ofn.lStructSize,sizeof ofn
		push	ha.hWnd
		pop		ofn.hwndOwner
		push	ha.hInstance
		pop		ofn.hInstance
		mov		ofn.lpstrFilter,offset da.szALLString
		invoke strcpy,addr buffer,addr szNULL
		lea		eax,buffer
		mov		ofn.lpstrFile,eax
		mov		ofn.nMaxFile,sizeof buffer
		mov		ofn.Flags,OFN_HIDEREADONLY or OFN_PATHMUSTEXIST or OFN_OVERWRITEPROMPT
	    mov		ofn.lpstrDefExt,offset szNULL
	    mov		ofn.lpstrTitle,offset szAddNewProjectFile
	    ;Show save as dialog
		invoke GetSaveFileName,addr ofn
		.if eax
			invoke SendMessage,ha.hProjectBrowser,RPBM_FINDITEM,0,addr buffer
			.if !eax
				invoke UpdateAll,UAM_ISOPENACTIVATE,addr buffer
				.if eax==-1
					invoke CreateFile,addr buffer,GENERIC_WRITE,FILE_SHARE_READ,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,0
					.if eax!=INVALID_HANDLE_VALUE
						invoke CloseHandle,eax
						invoke SendMessage,ha.hProjectBrowser,RPBM_ADDNEWFILE,0,addr buffer
						invoke OpenTheFile,addr buffer,0
					.endif
				.endif
			.endif
		.endif
	.endif
	ret

AddNewProjectFile endp

AddProjectFiles proc uses esi edi,lpFileNames:DWORD
	LOCAL	buffer[MAX_PATH]:BYTE
	LOCAL	nOpen:DWORD

	mov		esi,lpFileNames
	mov		nOpen,0
	invoke strlen,esi
	.if byte ptr [esi+eax+1]
		;Multiselect
		mov		edi,esi
		lea		esi,[esi+eax+1]
		.while byte ptr [esi]
			invoke strcpy,addr buffer,edi
			invoke strcat,addr buffer,addr szBS
			invoke strcat,addr buffer,esi
			invoke UpdateAll,UAM_ISOPENACTIVATE,addr buffer
			.if eax==-1
				invoke SendMessage,ha.hProjectBrowser,RPBM_ADDNEWFILE,0,addr buffer
				invoke OpenTheFile,addr buffer,0
				.if eax
					.if ha.hMdi
						invoke GetWindowLong,ha.hEdt,GWL_ID
						.if eax==ID_EDITCODE
							invoke GetWindowLong,ha.hEdt,GWL_USERDATA
							invoke ParseEdit,ha.hMdi,[eax].TABMEM.pid
						.endif
					.endif
				.endif
				inc		nOpen
			.endif
			invoke strlen,esi
			lea		esi,[esi+eax+1]
		.endw
	.else
		;Single file
		invoke SendMessage,ha.hProjectBrowser,RPBM_FINDITEM,0,esi
		.if !eax
			invoke UpdateAll,UAM_ISOPENACTIVATE,esi
			.if eax==-1
				invoke SendMessage,ha.hProjectBrowser,RPBM_ADDNEWFILE,0,esi
				invoke OpenTheFile,esi,0
				.if eax
					.if ha.hMdi
						invoke GetWindowLong,ha.hEdt,GWL_ID
						.if eax==ID_EDITCODE
							invoke GetWindowLong,ha.hEdt,GWL_USERDATA
							invoke ParseEdit,ha.hMdi,[eax].TABMEM.pid
						.endif
					.endif
				.endif
				mov		nOpen,1
			.endif
		.endif
	.endif
	mov		eax,nOpen
	ret

AddProjectFiles endp

AddExistingProjectFiles proc
	LOCAL	ofn:OPENFILENAME
	LOCAL	hMem:HGLOBAL

	invoke SendMessage,ha.hProjectBrowser,RPBM_GETSELECTED,0,0
	.if eax
		invoke GlobalAlloc,GMEM_FIXED or GMEM_ZEROINIT,8192
		mov		hMem,eax
		mov		esi,eax
		;Zero out the ofn struct
		invoke RtlZeroMemory,addr ofn,sizeof ofn
		;Setup the ofn struct
		mov		ofn.lStructSize,sizeof ofn
		push	ha.hWnd
		pop		ofn.hwndOwner
		push	ha.hInstance
		pop		ofn.hInstance
		mov		ofn.lpstrFilter,offset da.szALLString
		mov		ofn.lpstrFile,esi
		mov		ofn.nMaxFile,8192
		mov		ofn.lpstrDefExt,NULL
		mov		ofn.lpstrInitialDir,offset da.szProjectPath
		mov		ofn.Flags,OFN_FILEMUSTEXIST or OFN_HIDEREADONLY or OFN_PATHMUSTEXIST or OFN_ALLOWMULTISELECT or OFN_EXPLORER
	    mov		ofn.lpstrTitle,offset szAddExistingProjectFiles
		;Show the Open dialog
		invoke GetOpenFileName,addr ofn
		.if eax
			invoke AddProjectFiles,hMem
		.endif
		push	eax
		invoke GlobalFree,hMem
		pop		eax
	.endif
	ret

AddExistingProjectFiles endp

AddOpenProjectFile proc uses ebx

	invoke GetWindowLong,ha.hEdt,GWL_USERDATA
	mov		ebx,eax
	invoke SendMessage,ha.hProjectBrowser,RPBM_FINDITEM,0,addr [ebx].TABMEM.filename
	.if !eax
		invoke SendMessage,ha.hProjectBrowser,RPBM_ADDNEWFILE,0,addr [ebx].TABMEM.filename
		mov		eax,[eax].PBITEM.id
		mov		[ebx].TABMEM.pid,eax
		invoke GetWindowLong,[ebx].TABMEM.hedt,GWL_ID
		.if eax==ID_EDITCODE
			invoke ParseEdit,[ebx].TABMEM.hwnd,[ebx].TABMEM.pid
		.endif
	.endif
	ret

AddOpenProjectFile endp

AddAllOpenProjectFiles proc uses ebx edi
	LOCAL	tci:TC_ITEM

	xor		edi,edi
	mov		tci.imask,TCIF_PARAM
	.while TRUE
		invoke SendMessage,ha.hTab,TCM_GETITEM,edi,addr tci
		.break .if !eax
		mov		ebx,tci.lParam
		invoke SendMessage,ha.hProjectBrowser,RPBM_FINDITEM,0,addr [ebx].TABMEM.filename
		.if !eax
			invoke SendMessage,ha.hProjectBrowser,RPBM_ADDNEWFILE,0,addr [ebx].TABMEM.filename
			mov		eax,[eax].PBITEM.id
			mov		[ebx].TABMEM.pid,eax
			invoke GetWindowLong,[ebx].TABMEM.hedt,GWL_ID
			.if eax==ID_EDITCODE
				invoke ParseEdit,[ebx].TABMEM.hwnd,[ebx].TABMEM.pid
			.endif
		.endif
		inc		edi
	.endw
	ret

AddAllOpenProjectFiles endp

OpenProjectItemFile proc uses ebx

	invoke SendMessage,ha.hProjectBrowser,RPBM_GETSELECTED,0,0
	.if eax
		mov		ebx,eax
		invoke UpdateAll,UAM_ISOPENACTIVATE,addr [ebx].PBITEM.szitem
		.if eax==-1
			invoke OpenTheFile,addr [ebx].PBITEM.szitem,0
		.endif
	.endif
	ret

OpenProjectItemFile endp

OpenProjectItemGroup proc uses ebx esi edi

	invoke SendMessage,ha.hProjectBrowser,RPBM_GETSELECTED,0,0
	.if eax
		mov		edi,[eax].PBITEM.id
		xor		esi,esi
		.while TRUE
			invoke SendMessage,ha.hProjectBrowser,RPBM_GETITEM,esi,0
			.break .if !eax
			.if sdword ptr [eax].PBITEM.id>0 && edi==[eax].PBITEM.idparent
				mov		ebx,eax
				invoke UpdateAll,UAM_ISOPENACTIVATE,addr [ebx].PBITEM.szitem
				.if eax==-1
					invoke OpenTheFile,addr [ebx].PBITEM.szitem,0
				.endif
			.endif
			inc		esi
		.endw
	.endif
	ret

OpenProjectItemGroup endp

RemoveProjectFile proc uses ebx

	invoke SendMessage,ha.hProjectBrowser,RPBM_GETSELECTED,0,0
	.if eax
		mov		ebx,eax
		invoke UpdateAll,UAM_ISOPEN,addr [ebx].PBITEM.szitem
		.if eax!=-1
			invoke GetWindowLong,eax,GWL_USERDATA
			invoke GetWindowLong,eax,GWL_USERDATA
			mov		[eax].TABMEM.pid,0
		.endif
		invoke SendMessage,ha.hProperty,PRM_DELPROPERTY,[ebx].PBITEM.id,0
		invoke SendMessage,ha.hProperty,PRM_REFRESHLIST,0,0
		invoke SendMessage,ha.hProjectBrowser,RPBM_DELETEITEM,0,0
	.endif
	ret

RemoveProjectFile endp

GetProjectFiles proc uses ebx esi edi
	LOCAL	fi:FILEINFO
	LOCAL	pbi:PBITEM
	LOCAL	buffer[MAX_PATH]:BYTE
	LOCAL	nMiss:DWORD

	;File browser path
	invoke GetPrivateProfileString,addr szIniProject,addr szIniPath,addr da.szAppPath,addr da.szFBPath,sizeof da.szFBPath,addr da.szProjectFile
	;Check if path exist
	invoke GetFileAttributes,addr da.szFBPath
	.if eax==INVALID_HANDLE_VALUE
		invoke strcpy,addr da.szFBPath,addr da.szProjectPath
	.endif
	invoke SendMessage,ha.hFileBrowser,FBM_SETPATH,TRUE,addr da.szFBPath
	;Get groups
	invoke GetPrivateProfileString,addr szIniProject,addr szIniGroup,addr szNULL,addr tmpbuff,sizeof tmpbuff,addr da.szProjectFile
	.if eax
		invoke SendMessage,ha.hProjectBrowser,RPBM_SETGROUPING,FALSE,RPBG_GROUPS
		invoke RtlZeroMemory,addr pbi,sizeof PBITEM
		invoke GetItemInt,addr tmpbuff,0
		.if sdword ptr eax>0
			invoke SendMessage,ha.hProjectBrowser,RPBM_SETGROUPING,FALSE,eax
		.endif
		xor		ebx,ebx
		.while tmpbuff
			invoke GetItemInt,addr tmpbuff,0
			mov		pbi.id,eax
			invoke GetItemInt,addr tmpbuff,0
			mov		pbi.idparent,eax
			invoke GetItemInt,addr tmpbuff,0
			mov		pbi.expanded,eax
			invoke GetItemStr,addr tmpbuff,addr szNULL,addr pbi.szitem,sizeof pbi.szitem
			invoke SendMessage,ha.hProjectBrowser,RPBM_SETITEM,ebx,addr pbi
			inc		ebx
		.endw
		;Get files
		mov		nMiss,0
		mov		esi,START_FILES
		.while esi<MAX_FILES
			invoke GetFileInfo,esi,addr szIniProject,addr da.szProjectFile,addr fi
			.if eax
				invoke RtlZeroMemory,addr pbi,sizeof PBITEM
				mov		pbi.id,esi
				mov		eax,fi.idparent
				mov		pbi.idparent,eax
				mov		eax,fi.flag
				mov		pbi.flag,eax
				invoke strcpy,addr pbi.szitem,addr fi.filename
				mov		eax,fi.ID
				mov		pbi.lParam,eax
				invoke GetFileAttributes,addr pbi.szitem
				.if eax!=INVALID_HANDLE_VALUE
					invoke ParseFile,addr pbi.szitem,pbi.id
					invoke SendMessage,ha.hProjectBrowser,RPBM_SETITEM,ebx,addr pbi
					.if pbi.flag==FLAG_MAIN
						;Main file
						invoke RemovePath,addr pbi.szitem,addr da.szProjectPath,addr buffer
						invoke GetTheFileType,addr pbi.szitem
						.if eax==ID_EDITCODE
							invoke strcpy,addr da.szMainAsm,addr buffer
						.elseif eax==ID_EDITRES
							invoke strcpy,addr da.szMainRC,addr buffer
						.endif
					.endif
					inc		ebx
				.endif
				mov		nMiss,0
			.else
				inc		nMiss
				.break .if nMiss>MAX_MISS
			.endif
			inc		esi
		.endw
		invoke SendMessage,ha.hProjectBrowser,RPBM_SETGROUPING,TRUE,RPBG_GROUPS
		invoke SetProjectTab,1
		;Get open files
		invoke GetPrivateProfileString,addr szIniProject,addr szIniOpen,addr szNULL,addr buffer,sizeof buffer,addr da.szProjectFile
		.if eax
;			push	da.win.fcldmax
;			mov		da.win.fcldmax,FALSE
			;Selected tab
			invoke GetItemInt,addr buffer,0
			push	eax
			.while buffer
				invoke GetItemInt,addr buffer,0
				.if eax
					invoke SendMessage,ha.hProjectBrowser,RPBM_FINDITEM,eax,0
					.if eax
						invoke OpenTheFile,addr [eax].PBITEM.szitem,[eax].PBITEM.lParam
					.endif
				.endif
			.endw
			pop		eax
;			pop		da.win.fcldmax
			invoke SendMessage,ha.hTab,TCM_SETCURSEL,eax,0
			.if eax==-1
				invoke SendMessage,ha.hTab,TCM_SETCURSEL,0,0
			.endif
			.if eax!=-1
				invoke TabToolActivate
;				.if da.win.fcldmax
;					invoke SendMessage,ha.hClient,WM_MDIMAXIMIZE,ha.hMdi,0
;				.endif
			.endif
		.endif
		;Get make command lines
		xor		ebx,ebx
		mov		edi,offset da.make
		invoke RtlZeroMemory,edi,sizeof da.make
		invoke SendMessage,ha.hCboBuild,CB_RESETCONTENT,0,0
		.while ebx<32
			invoke BinToDec,ebx,addr buffer
			invoke GetPrivateProfileString,addr szIniMake,addr buffer,addr szNULL,addr tmpbuff,sizeof tmpbuff,addr da.szProjectFile
			.if eax
				invoke GetItemStr,addr tmpbuff,addr szNULL,addr [edi].MAKE.szType,sizeof MAKE.szType
				invoke GetItemQuotedStr,addr tmpbuff,addr szNULL,addr [edi].MAKE.szCompileRC,sizeof MAKE.szCompileRC
				invoke GetItemStr,addr tmpbuff,addr szNULL,addr [edi].MAKE.szOutCompileRC,sizeof MAKE.szOutCompileRC
				invoke GetItemQuotedStr,addr tmpbuff,addr szNULL,addr [edi].MAKE.szAssemble,sizeof MAKE.szAssemble
				invoke GetItemStr,addr tmpbuff,addr szNULL,addr [edi].MAKE.szOutAssemble,sizeof MAKE.szOutAssemble
				invoke GetItemQuotedStr,addr tmpbuff,addr szNULL,addr [edi].MAKE.szLink,sizeof MAKE.szLink
				invoke GetItemStr,addr tmpbuff,addr szNULL,addr [edi].MAKE.szOutLink,sizeof MAKE.szOutLink
				invoke GetItemQuotedStr,addr tmpbuff,addr szNULL,addr [edi].MAKE.szLib,sizeof MAKE.szLib
				invoke GetItemStr,addr tmpbuff,addr szNULL,addr [edi].MAKE.szOutLib,sizeof MAKE.szOutLib
				invoke SendMessage,ha.hCboBuild,CB_ADDSTRING,0,addr [edi].MAKE.szType
				lea		edi,[edi+sizeof MAKE]
			.endif
			inc		ebx
		.endw
		invoke GetPrivateProfileInt,addr szIniMake,addr szIniMake,0,addr da.szProjectFile
		invoke SendMessage,ha.hCboBuild,CB_SETCURSEL,eax,0
		.if eax==CB_ERR
			invoke SendMessage,ha.hCboBuild,CB_SETCURSEL,0,0
		.endif
		invoke GetPrivateProfileString,addr szIniMake,addr szIniRun,addr szNULL,addr tmpbuff,sizeof tmpbuff,addr da.szProjectFile
		invoke GetItemInt,addr tmpbuff,0
		mov		da.fCmdExe,eax
		invoke GetItemQuotedStr,addr tmpbuff,addr szNULL,addr da.szCmdExe,sizeof da.szCmdExe
		invoke GetItemQuotedStr,addr tmpbuff,addr szNULL,addr da.szCommandLine,sizeof da.szCommandLine
	.endif
	ret

GetProjectFiles endp

SaveProjectItem proc nInx:DWORD
	LOCAL	fi:FILEINFO
	LOCAL	buffer[8]:BYTE

	invoke SetFileInfo,nInx,addr fi
	.if eax
		mov		tmpbuff,0
		invoke PutItemInt,addr tmpbuff,fi.idparent
		invoke PutItemInt,addr tmpbuff,fi.flag
		invoke PutItemInt,addr tmpbuff,fi.ID
		invoke PutItemInt,addr tmpbuff,fi.rect.left
		invoke PutItemInt,addr tmpbuff,fi.rect.top
		invoke PutItemInt,addr tmpbuff,fi.rect.right
		invoke PutItemInt,addr tmpbuff,fi.rect.bottom
		invoke PutItemInt,addr tmpbuff,fi.nline
		invoke PutItemStr,addr tmpbuff,addr fi.filename
		mov		buffer,'F'
		invoke BinToDec,fi.pid,addr buffer[1]
		invoke WritePrivateProfileString,addr szIniProject,addr buffer,addr tmpbuff[1],addr da.szProjectFile
	.endif
	ret

SaveProjectItem endp

PutProject proc uses ebx esi edi
	LOCAL	tci:TC_ITEM
	LOCAL	buffer[8]:BYTE
	LOCAL	nMiss:DWORD

	;RadASM.ini [Session]
	mov		word ptr buffer,0
	invoke WritePrivateProfileSection,addr szIniSession,addr buffer,addr da.szRadASMIni
	invoke WritePrivateProfileString,addr szIniSession,addr szIniProject,addr da.szProjectFile,addr da.szRadASMIni
	;Project.prra [Project]
	;Assembler
	invoke WritePrivateProfileString,addr szIniProject,addr szIniAssembler,addr da.szAssembler,addr da.szProjectFile
	;File browser path
	invoke WritePrivateProfileString,addr szIniProject,addr szIniPath,addr da.szFBPath,addr da.szProjectFile
	;Project groups
	mov		tmpbuff,0
	;Refresh expanded group flags
	invoke SendMessage,ha.hProjectBrowser,RPBM_GETEXPAND,0,0
	;Get selected grouping
	invoke SendMessage,ha.hProjectBrowser,RPBM_GETGROUPING,0,0
	invoke PutItemInt,addr tmpbuff,eax
	;Get groups
	xor		ebx,ebx
	.while TRUE
		invoke SendMessage,ha.hProjectBrowser,RPBM_GETITEM,ebx,0
		.break .if !eax
		mov		esi,eax
		.break .if ![esi].PBITEM.id
		.if sdword ptr [esi].PBITEM.id<0
			invoke PutItemInt,addr tmpbuff,[esi].PBITEM.id
			invoke PutItemInt,addr tmpbuff,[esi].PBITEM.idparent
			invoke PutItemInt,addr tmpbuff,[esi].PBITEM.expanded
			invoke PutItemStr,addr tmpbuff,addr [esi].PBITEM.szitem
		.endif
		inc		ebx
	.endw
	invoke WritePrivateProfileString,addr szIniProject,addr szIniGroup,addr tmpbuff[1],addr da.szProjectFile
	;Remove files not longer in project
	mov		ebx,START_FILES
	mov		nMiss,0
	.while ebx<MAX_FILES
		mov		buffer,'F'
		invoke BinToDec,ebx,addr buffer[1]
		invoke GetPrivateProfileString,addr szIniProject,addr buffer,addr szNULL,addr tmpbuff,sizeof tmpbuff,addr da.szProjectFile
		.if eax
			invoke SendMessage,ha.hProjectBrowser,RPBM_FINDITEM,ebx,0
			.if !eax
				;Remove it from project file
				invoke WritePrivateProfileString,addr szIniProject,addr buffer,addr szNULL,addr da.szProjectFile
			.endif
			mov		nMiss,0
		.else
			inc		nMiss
			.break .if nMiss>MAX_MISS
		.endif
		inc		ebx
	.endw
	;Get open project files
	mov		dword ptr tmpbuff,0
	.if ha.hMdi
		invoke ShowWindow,ha.hClient,SW_HIDE
		mov		eax,da.win.fcldmax
		push	eax
		.if eax
			invoke SendMessage,ha.hClient,WM_MDIRESTORE,ha.hMdi,0
		.endif
		invoke SendMessage,ha.hTab,TCM_GETCURSEL,0,0
		invoke PutItemInt,addr tmpbuff,eax
		xor		ebx,ebx
		.while TRUE
			mov		tci.imask,TCIF_PARAM
			invoke SendMessage,ha.hTab,TCM_GETITEM,ebx,addr tci
			.break .if !eax
			mov		esi,tci.lParam
			mov		eax,[esi].TABMEM.pid
			.if eax
				invoke PutItemInt,addr tmpbuff,eax
			.endif
			inc		ebx
		.endw
		pop		da.win.fcldmax
		invoke ShowWindow,ha.hClient,SW_SHOWNA
	.endif
;	;Get external project files
;	.while TRUE
;		invoke SendMessage,ha.hProjectBrowser,RPBM_FINDNEXTITEM,ebx,0
;		.break .if !eax
;		mov		esi,eax
;		mov		ebx,[esi].PBITEM.id
;		.if [esi].PBITEM.lParam==ID_EXTERNAL
;		.endif
;	.endw
	invoke WritePrivateProfileString,addr szIniProject,addr szIniOpen,addr tmpbuff[1],addr da.szProjectFile
	;Project.prra [Make]
	mov		word ptr buffer,0
	invoke WritePrivateProfileSection,addr szIniMake,addr buffer,addr da.szProjectFile
	;Selected make option
	invoke SendMessage,ha.hCboBuild,CB_GETCURSEL,0,0
	.if eax==CB_ERR
		xor		eax,eax
	.endif
	mov		edx,eax
	invoke BinToDec,edx,addr buffer
	invoke WritePrivateProfileString,addr szIniMake,addr szIniMake,addr buffer,addr da.szProjectFile
	;Make command line switches
	xor		ebx,ebx
	mov		esi,offset da.make
	.while ebx<32
		.if [esi].MAKE.szType
			mov		tmpbuff,0
			invoke PutItemStr,addr tmpbuff,addr [esi].MAKE.szType
			invoke PutItemQuotedStr,addr tmpbuff,addr [esi].MAKE.szCompileRC
			invoke PutItemStr,addr tmpbuff,addr [esi].MAKE.szOutCompileRC
			invoke PutItemQuotedStr,addr tmpbuff,addr [esi].MAKE.szAssemble
			invoke PutItemStr,addr tmpbuff,addr [esi].MAKE.szOutAssemble
			invoke PutItemQuotedStr,addr tmpbuff,addr [esi].MAKE.szLink
			invoke PutItemStr,addr tmpbuff,addr [esi].MAKE.szOutLink
			invoke PutItemQuotedStr,addr tmpbuff,addr [esi].MAKE.szLib
			invoke PutItemStr,addr tmpbuff,addr [esi].MAKE.szOutLib
			invoke BinToDec,ebx,addr buffer
			invoke WritePrivateProfileString,addr szIniMake,addr buffer,addr tmpbuff[1],addr da.szProjectFile
		.endif
		lea		esi,[esi+sizeof MAKE]
		inc		ebx
	.endw
	mov		tmpbuff,0
	invoke PutItemInt,addr tmpbuff,da.fCmdExe
	invoke PutItemQuotedStr,addr tmpbuff,addr da.szCmdExe
	invoke PutItemQuotedStr,addr tmpbuff,addr da.szCommandLine
	invoke WritePrivateProfileString,addr szIniMake,addr szIniRun,addr tmpbuff[1],addr da.szProjectFile
	ret

PutProject endp

CloseProject proc

	invoke UpdateAll,UAM_SAVEALL,TRUE
	.if eax
		.if da.fProject
			invoke PutProject
		.endif
		invoke UpdateAll,UAM_CLOSEALL,0
		invoke SendMessage,ha.hProperty,PRM_DELPROPERTY,0,0
		invoke SendMessage,ha.hProjectBrowser,RPBM_SETITEM,0,0
		invoke SendMessage,ha.hProjectBrowser,RPBM_SETGROUPING,TRUE,RPBG_NOCHANGE
		invoke SetProjectTab,0
		invoke SendMessage,ha.hProperty,PRM_REFRESHLIST,0,0
		mov		da.fProject,0
		mov		da.szProjectFile,0
		mov		da.szProjectPath,0
		mov		da.szMainRC,0
		mov		da.szMainAsm,0
		invoke OpenAssembler
		invoke SetMainWinCaption
		mov		eax,TRUE
	.else
		xor		eax,eax
	.endif
	ret

CloseProject endp

SetMain proc uses ebx edi,pid:DWORD,ID:DWORD

	;Remove old main
	xor		ebx,ebx
	.while TRUE
		invoke SendMessage,ha.hProjectBrowser,RPBM_FINDNEXTITEM,ebx,0
		.break .if !eax
		mov		ebx,[eax].PBITEM.id
		.if [eax].PBITEM.flag==FLAG_MAIN
			mov		edi,eax
			invoke GetTheFileType,addr [edi].PBITEM.szitem
			.if eax==ID
				;Update the item
				mov		[edi].PBITEM.flag,FLAG_NORMAL
				invoke SendMessage,ha.hProjectBrowser,RPBM_FINDITEMINDEX,ebx,0
				invoke SendMessage,ha.hProjectBrowser,RPBM_SETITEM,eax,edi
				.break
			.endif
		.endif
	.endw
	;Set new main
	invoke SendMessage,ha.hProjectBrowser,RPBM_FINDITEM,pid,0
	.if eax
		mov		edi,eax
		mov		[edi].PBITEM.flag,FLAG_MAIN
		invoke SendMessage,ha.hProjectBrowser,RPBM_FINDITEMINDEX,pid,0
		invoke SendMessage,ha.hProjectBrowser,RPBM_SETITEM,eax,edi
		invoke SendMessage,ha.hProjectBrowser,RPBM_SETGROUPING,TRUE,RPBG_NOCHANGE
		mov		eax,TRUE
	.else
		xor		eax,eax
	.endif
	ret

SetMain endp

ToggleModule proc uses edi,pid:DWORD

	invoke SendMessage,ha.hProjectBrowser,RPBM_FINDITEM,pid,0
	.if eax
		mov		edi,eax
		.if [edi].PBITEM.flag==FLAG_NORMAL
			mov		[edi].PBITEM.flag,FLAG_MODULE
		.elseif [edi].PBITEM.flag==FLAG_MAIN
			mov		[edi].PBITEM.flag,FLAG_MODULE
			mov		da.szMainAsm,0
		.else
			mov		[edi].PBITEM.flag,FLAG_NORMAL
		.endif
		invoke SendMessage,ha.hProjectBrowser,RPBM_FINDITEMINDEX,pid,0
		invoke SendMessage,ha.hProjectBrowser,RPBM_SETITEM,eax,edi
		invoke SendMessage,ha.hProjectBrowser,RPBM_SETGROUPING,TRUE,RPBG_NOCHANGE
		mov		eax,TRUE
	.else
		xor		eax,eax
	.endif
	ret

ToggleModule endp