
.data?

pixcnt				DWORD ?
pixdir				DWORD ?
pixmov				DWORD ?
pixdpt				DWORD ?
rseed				DWORD ?

.code

Random proc uses ecx edx,range:DWORD

	mov		eax,rseed
	mov		ecx,23
	mul		ecx
	add		eax,7
	and		eax,0FFFFFFFFh
	ror		eax,1
	xor		eax,rseed
	mov		rseed,eax
	mov		ecx,range
	xor		edx,edx
	div		ecx
	mov		eax,edx
	ret

Random endp

;Description
;===========
;A short ping at 200KHz is transmitted at intervalls depending on range.
;From the time it takes for the echo to return we can calculate the depth.
;The adc measures the strenght of the echo at intervalls depending on range
;and stores it in a 512 byte array.
;
;Speed of sound in water
;=======================
;Temp (C)    Speed (m/s)
;  0             1403
;  5             1427
; 10             1447
; 20             1481
; 30             1507
; 40             1526
;
;1450m/s is probably a good estimate.
;
;The timer is clocked at 48MHz so it increments every 0,0208333 us.
;For each tick the sound travels 1450 * 0,0208333 = 30,208285 um or 30,208285e-6 meters.

;Timer value calculation
;=======================
;Example 2m range
;Timer period Tp=1/48MHz
;Each pixel is Px=2m/512.
;Time for each pixel is t=Px/1450/2
;Timer ticks Tt=t/Tp

;Formula T=((Range/512)/(1450/2))*48000000

;RangeToTimer proc RangeInx:DWORD
;	LOCAL	tmp:DWORD
;
;	mov		eax,RangeInx
;	lea		eax,[eax+eax*2]
;	mov		eax,sonarrange.range[eax*4]
;	mov		tmp,eax
;	fild	tmp
;	mov		tmp,MAXYECHO
;	fild	tmp
;	fdivp	st(1),st
;	mov		tmp,1450/2			;Divide by 2 since it is the echo
;	fild	tmp
;	fdivp	st(1),st
;	mov		tmp,48000000
;	fild	tmp
;	fmulp	st(1),st
;	fistp	tmp
;	mov		eax,tmp
;	dec		eax
;	ret
;
;RangeToTimer endp

GetRangePtr proc uses edx,RangeInx:DWORD

	mov		eax,RangeInx
	mov		edx,sizeof RANGE
	mul		edx
	ret

GetRangePtr endp

SetRange proc uses ebx esi edi,RangeInx:DWORD

	mov		eax,RangeInx
	mov		sonardata.RangeInx,al
	invoke GetRangePtr,eax
	mov		ebx,eax
	mov		eax,sonarrange.nsample[ebx]
	mov		sonardata.nSample,al
	mov		eax,sonarrange.range[ebx]
	mov		sonardata.RangeVal,eax
	invoke wsprintf,addr sonardata.options.text,addr szFmtDec,eax
	.if sonardata.AutoGain
		mov		eax,sonarrange.gain[ebx]
		mov		sonardata.Gain,al
		invoke SendDlgItemMessage,hWnd,IDC_TRBGAIN,TBM_SETPOS,TRUE,eax
	.endif
	.if sonardata.AutoPing
		mov		eax,sonarrange.pingpulses[ebx]
		mov		sonardata.PingPulses,al
		invoke SendDlgItemMessage,hWnd,IDC_TRBPULSES,TBM_SETPOS,TRUE,eax
	.endif
	mov		sonardata.Timer,STM32_Timer
	ret

SetRange endp

UpdateBitmapTile proc uses ebx esi edi,x:DWORD,wt:DWORD,NewRange:DWORD
	LOCAL	hDC:HDC
	LOCAL	mDC:HDC
	LOCAL	rect:RECT

	invoke GetDC,hSonar
	mov		hDC,eax
	invoke CreateCompatibleDC,hDC
	mov		mDC,eax
	invoke CreateCompatibleBitmap,hDC,wt,MAXYECHO
	invoke SelectObject,mDC,eax
	push	eax
	invoke ReleaseDC,hSonar,hDC
	mov		rect.left,0
	mov		rect.top,0
	mov		eax,wt
	mov		rect.right,eax
	mov		rect.bottom,MAXYECHO
	invoke CreateSolidBrush,SONARBACKCOLOR
	push	eax
	invoke FillRect,mDC,addr rect,eax
	pop		eax
	invoke DeleteObject,eax
	xor		esi,esi
	.while esi<wt
		xor		edi,edi
		.while edi<MAXYECHO
			mov		eax,MAXYECHO
			mov		edx,esi
			add		edx,x
			mul		edx
			movzx	eax,sonardata.sonar[eax+edi]
			.if eax
				.if eax<20h
					mov		eax,20h
				.endif
				xor		eax,0FFh
				mov		ah,al
				shl		eax,8
				mov		al,ah
				invoke SetPixel,mDC,esi,edi,eax
			.endif
			inc		edi
		.endw
		inc		esi
	.endw
	mov		eax,x
	mov		edx,MAXYECHO
	mul		edx
	movzx	eax,sonardata.sonar[eax]
	invoke GetRangePtr,eax
	mov		ecx,sonarrange.range[eax]
	mov		eax,MAXYECHO
	mul		ecx
	mov		ecx,NewRange
	div		ecx
	invoke StretchBlt,sonardata.mDC,x,0,wt,eax,mDC,0,0,wt,MAXYECHO,SRCCOPY
	pop		eax
	invoke SelectObject,mDC,eax
	invoke DeleteObject,eax
	invoke DeleteDC,mDC
	ret

UpdateBitmapTile endp

UpdateBitmap proc uses ebx esi edi,NewRange:DWORD
	LOCAL	rect:RECT

	mov		rect.left,0
	mov		rect.top,0
	mov		rect.right,MAXXECHO
	mov		rect.bottom,MAXYECHO
	invoke CreateSolidBrush,SONARBACKCOLOR
	push	eax
	invoke FillRect,sonardata.mDC,addr rect,eax
	pop		eax
	invoke DeleteObject,eax
	xor		esi,esi
	.while esi<MAXXECHO
		mov		eax,MAXYECHO
		mul		esi
		movzx	ebx,sonardata.sonar[eax]
		mov		ecx,esi
		.while ecx<MAXXECHO
			inc		ecx
			mov		eax,MAXYECHO
			mul		ecx
			movzx	eax,sonardata.sonar[eax]
			.break .if eax!=ebx
		.endw
		push	ecx
		sub		ecx,esi
		invoke UpdateBitmapTile,esi,ecx,NewRange
		pop		esi
	.endw
	ret

UpdateBitmap endp

STM32Thread proc uses ebx esi edi,lParam:DWORD
	LOCAL	status:DWORD
	LOCAL	STM32Echo[MAXYECHO*3]:BYTE
	LOCAL	dwread:DWORD
	LOCAL	dwwrite:DWORD
	LOCAL	buffer[16]:BYTE
	LOCAL	fFishSound:DWORD

  Again:
	.if sonardata.hReply
		lea		edi,STM32Echo
		lea		esi,STM32Echo[MAXYECHO]
		mov		ecx,MAXYECHO*2/4
		rep movsd
		invoke ReadFile,sonardata.hReply,addr STM32Echo[MAXYECHO*2],MAXYECHO,addr dwread,NULL
		.if dwread!=MAXYECHO
			invoke CloseHandle,sonardata.hReply
			mov		sonardata.hReply,0
			jmp		Again
		.endif
	.elseif fSTLink && fSTLink!=IDIGNORE
		;Download Start status (first byte)
		invoke STLinkRead,hWnd,STM32_Sonar,addr status,4
		.if !eax
			jmp		STLinkErr
		.endif
		.if !(status & 255)
			;Download ADCBattery, ADCWaterTemp and ADCAirTemp
			invoke STLinkRead,hWnd,STM32_Sonar+8,addr sonardata.dmy1,8
			.if !eax
				jmp		STLinkErr
			.endif
			lea		edi,STM32Echo
			lea		esi,STM32Echo[MAXYECHO]
			mov		ecx,MAXYECHO*2/4
			rep movsd
			;Download sonar echo array
			invoke STLinkRead,hWnd,STM32_Sonar+16,addr STM32Echo[MAXYECHO*2],MAXYECHO
			.if !eax
				jmp		STLinkErr
			.endif
		 	;Upload Start, PingPulses, Noise, Gain, RangeInx, nSample and Timer to init the next reading
		 	mov		sonardata.Start,0
			invoke STLinkWrite,hWnd,STM32_Sonar,addr sonardata.Start,8
			.if !eax
				jmp		STLinkErr
			.endif
		 	mov		sonardata.Start,1
			invoke STLinkWrite,hWnd,STM32_Sonar,addr sonardata.Start,8
			.if !eax
				jmp		STLinkErr
			.endif
		.else
			;Data not ready yet
			invoke Sleep,10
			jmp		Again
		.endif
	.elseif fSTLink==IDIGNORE
		lea		edi,STM32Echo
		lea		esi,STM32Echo[MAXYECHO]
		mov		ecx,MAXYECHO*2/4
		rep movsd
		invoke RtlZeroMemory,addr STM32Echo[MAXYECHO*2],MAXYECHO
		mov		al,sonardata.RangeInx
		mov		STM32Echo[MAXYECHO*2],al
		xor		edx,edx
		.while eax<20
			inc		edx
			mov		STM32Echo[edx+MAXYECHO*2],250
			inc		eax
		.endw
		.if !(pixcnt & 63)
			;Random direction
			invoke Random,8
			mov		pixdir,eax
		.endif
		.if !(pixcnt & 31)
			;Random move
			invoke Random,7
			mov		pixmov,eax
		.endif
		mov		ebx,pixdpt
		mov		eax,pixdir
		.if eax<=3 && ebx>100
			;Up
			sub		ebx,pixmov
		.elseif eax>=5 && ebx<15000
			;Down
			add		ebx,pixmov
		.endif
		mov		pixdpt,ebx
		inc		pixcnt
		mov		eax,ebx
		mov		ecx,1024
		mul		ecx
		push	eax
		;Get current range index
		movzx	eax,STM32Echo[MAXYECHO*2]
		invoke GetRangePtr,eax
		mov		ecx,sonarrange.range[eax]
		pop		eax
		push	ecx
		xor		edx,edx
		div		ecx
		mov		ecx,100
		xor		edx,edx
		div		ecx
		mov		ebx,eax
		mov		edx,256
		pop		ecx
		sub		edx,ecx
		shr		edx,2
		xor		ecx,ecx
		.while ecx<edx
			;Random echo
			invoke Random,200
			.if ebx<MAXYECHO
				add		eax,55
				mov		STM32Echo[ebx+MAXYECHO*2],al
			.endif
			inc		ebx
			inc		ecx
		.endw
		invoke Random,ebx
		.if eax>100 && eax<MAXYECHO
			mov		edx,eax
			invoke Random,255
			.if eax>150 && eax<160
				;Random fish
				mov		STM32Echo[edx+MAXYECHO*2],al
			.endif
		.endif
		mov		sonardata.ADCBattery,0810h
		mov		sonardata.ADCWaterTemp,0980h
	.endif
	.if sonardata.hLog
		;Write to log file
		invoke WriteFile,sonardata.hLog,addr STM32Echo[MAXYECHO*2],MAXYECHO,addr dwwrite,NULL
	.endif
	;Get current range index
	mov		al,STM32Echo[MAXYECHO*2]
	.if al!=STM32Echo[MAXYECHO*1]
		invoke RtlMoveMemory,addr STM32Echo,addr STM32Echo[MAXYECHO*2],MAXYECHO
		invoke RtlMoveMemory,addr STM32Echo[MAXYECHO],addr STM32Echo[MAXYECHO*2],MAXYECHO
  	.endif
	;Store the average of the 3 last readings
	xor		ebx,ebx
	mov		ecx,3
	.while ebx<MAXYECHO
		movzx	eax,STM32Echo[ebx]
		movzx	edx,STM32Echo[ebx+MAXYECHO]
		add		eax,edx
		movzx	edx,STM32Echo[ebx+MAXYECHO*2]
		add		eax,edx
		xor		edx,edx
		div		ecx
		mov		sonardata.STM32Echo[ebx],al
		inc		ebx
	.endw
	call	FindDepth
	call	FindFish
	call	TestRangeChange
	;Get current range index
	movzx	eax,STM32Echo[MAXYECHO*2]
	invoke GetRangePtr,eax
	mov		eax,sonarrange.interval[eax]
	invoke Sleep,eax
	jmp		Again

STLinkErr:
	xor		eax,eax
	ret

FindDepth:
	mov		sonardata.dptinx,0
	and		sonardata.ShowDepth,1
	mov		ebx,1
	xor		edx,edx
	.while ebx<MAXYECHO-8
		movzx	eax,sonardata.STM32Echo[ebx]
		.if !eax
			inc		edx
			.break .if edx==3
		.else
			xor		edx,edx
		.endif
		inc		ebx
	.endw
	mov		sonardata.minyecho,ebx
	.while ebx<MAXYECHO-8
		inc		ebx
		movzx	eax,sonardata.STM32Echo[ebx]
		.if eax
			call	TestDepth
			.break .if eax
		.endif
	.endw
	retn

TestDepth:
	xor		ecx,ecx
	xor		edx,edx
	mov		sonardata.dptinx,ecx
	.while ecx<8
		movzx	eax,sonardata.STM32Echo[ebx+ecx]
		.if eax
			inc		edx
		.endif
		inc		ecx
	.endw
	.if edx>4
		mov		sonardata.dptinx,ebx
		call	CalculateDepth
		or		sonardata.ShowDepth,2
	.endif
	retn

CalculateDepth:
	movzx	eax,sonardata.STM32Echo
	invoke GetRangePtr,eax
	mov		eax,sonarrange.range[eax]
	mov		ecx,10
	mul		ecx
	mul		ebx
	mov		ecx,MAXYECHO
	div		ecx
	invoke wsprintf,addr buffer,addr szFmtDepth,eax
	invoke strlen,addr buffer
	movzx	ecx,word ptr buffer[eax-1]
	shl		ecx,8
	mov		cl,'.'
	mov		dword ptr buffer[eax-1],ecx
	invoke strcpy,addr sonardata.options.text[1*sizeof OPTIONS],addr buffer
	retn

FindFish:
	mov		ebx,sonardata.minyecho
	add		ebx,5
	mov		edi,sonardata.dptinx
	.if !edi
		mov		edi,MAXYECHO
	.endif
	.if edi>4
		sub		edi,4
	.endif
	.while ebx<edi
		movzx	eax,STM32Echo[ebx]
		.if eax
			mov		eax,edi
			.if sdword ptr eax>ebx
				;Large fish
				mov		sonardata.STM32Echo[ebx],255
				mov		STM32Echo[ebx],0
				mov		STM32Echo[ebx+MAXYECHO],0
				mov		STM32Echo[ebx+MAXYECHO*2],0
				.if sonardata.FishAlarm && !fFishSound
					mov		eax,sonardata.ChartSpeed
					add		eax,4
					mov		fFishSound,eax
					invoke strcpy,addr buffer,addr szAppPath
					invoke strcat,addr buffer,addr szFishWav
					invoke PlaySound,addr buffer,hInstance,SND_ASYNC
				.endif
			.endif
		.endif
		inc		ebx
	.endw
	.if fFishSound
		dec		fFishSound
	.endif
	retn

TestRangeChange:
	.if sonardata.AutoRange
		movzx	eax,sonardata.RangeInx
		mov		ebx,sonardata.dptinx
		.if !ebx
			;Bottom not found
			.if eax<(MAXRANGE-1)
				;Range increment
				inc		eax
				invoke SendDlgItemMessage,hWnd,IDC_TRBRANGE,TBM_SETPOS,TRUE,eax
			.endif
		.else
			.if eax && ebx<MAXYECHO/3
				;Range decrement
				dec		eax
				invoke SendDlgItemMessage,hWnd,IDC_TRBRANGE,TBM_SETPOS,TRUE,eax
			.elseif eax<(MAXRANGE-1) && ebx>(MAXYECHO-MAXYECHO/5)
				;Range increment
				inc		eax
				invoke SendDlgItemMessage,hWnd,IDC_TRBRANGE,TBM_SETPOS,TRUE,eax
			.endif
		.endif
	.endif
	invoke SendDlgItemMessage,hWnd,IDC_TRBRANGE,TBM_GETPOS,0,0
	.if al!=sonardata.RangeInx
		invoke SetRange,eax
	.endif
	retn

STM32Thread endp

SonarThreadProc proc uses ebx esi edi,lParam:DWORD
	LOCAL	rect:RECT
	LOCAL	buffer[256]:BYTE
	LOCAL	tmp:DWORD

	.if sonardata.hReply
		call	Update
		;Update range
		movzx	eax,sonardata.STM32Echo
		invoke SendDlgItemMessage,hWnd,IDC_TRBRANGE,TBM_SETPOS,TRUE,eax
		call	Setup
	.elseif fSTLink
		call	Update
		call	Setup
	.endif
	mov		fThread,FALSE
	xor		eax,eax
	ret

SetBattery:
	.if eax!=sonardata.Battery
		mov		sonardata.Battery,eax
		mov		ecx,100
		mul		ecx
		mov		ecx,1640
		div		ecx
		invoke wsprintf,addr buffer,addr szFmtVolts,eax
		invoke strlen,addr buffer
		movzx	ecx,word ptr buffer[eax-1]
		shl		ecx,8
		mov		cl,'.'
		mov		dword ptr buffer[eax-1],ecx
		invoke strcat,addr buffer,addr szVolts
		invoke strcpy,addr map.options.text[sizeof OPTIONS],addr buffer
		invoke InvalidateRect,hMap,NULL,TRUE
	.endif
	retn

SetWTemp:
	.if eax!=sonardata.WTemp
		mov		sonardata.WTemp,eax
		sub		eax,0BC8h
		neg		eax
		mov		tmp,eax
		fild	tmp
		fld		watertempconv
		fdivp	st(1),st
		fistp	tmp
		invoke wsprintf,addr buffer,addr szFmtDec,tmp
		invoke strlen,addr buffer
		movzx	ecx,word ptr buffer[eax-1]
		shl		ecx,8
		mov		cl,'.'
		mov		dword ptr buffer[eax-1],ecx
		invoke strcat,addr buffer,addr szCelcius
		invoke strcpy,addr sonardata.options.text[sizeof OPTIONS*2],addr buffer
	.endif
	retn

ScrollEchoArray:
	mov		esi,offset sonardata.sonar+MAXYECHO
	mov		edi,offset sonardata.sonar
	mov		ecx,(MAXXECHO*MAXYECHO-MAXYECHO)/4
	rep movsd
	retn

Update:
	movzx	eax,sonardata.ADCBattery
	call	SetBattery
	;Water temprature
	movzx	eax,sonardata.ADCWaterTemp
	call	SetWTemp
	;Check if range is still the same
	movzx	eax,sonardata.STM32Echo
	.if al!=sonardata.sonar[(MAXXECHO*MAXYECHO)-MAXYECHO]
		invoke GetRangePtr,eax
		mov		eax,sonarrange.range[eax]
		invoke UpdateBitmap,eax
		mov		eax,sonardata.ChartSpeed
	.endif
	call	ScrollEchoArray
	invoke RtlMoveMemory,offset sonardata.sonar[(MAXXECHO*MAXYECHO)-MAXYECHO],offset sonardata.STM32Echo,MAXYECHO
	mov		rect.left,0
	mov		rect.top,0
	mov		rect.right,MAXXECHO
	mov		rect.bottom,MAXYECHO
	invoke ScrollDC,sonardata.mDC,-1,0,addr rect,addr rect,NULL,NULL
	mov		ebx,1
	.while ebx<MAXYECHO
		movzx	eax,sonardata.sonar[ebx+MAXXECHO*MAXYECHO-MAXYECHO]
		.if eax
			.if eax<20h
				mov		eax,20h
			.endif
			xor		eax,0FFh
			mov		ah,al
			shl		eax,8
			mov		al,ah
		.else
			mov		eax,SONARBACKCOLOR
		.endif
		invoke SetPixel,sonardata.mDC,MAXXECHO-1,ebx,eax
		inc		ebx
	.endw
	;Remove fish
	xor		ebx,ebx
	.while ebx<MAXYECHO
		.if sonardata.STM32Echo[ebx]>253
			mov		sonardata.STM32Echo[ebx],0
		.endif
		inc		ebx
	.endw
	invoke InvalidateRect,hSonar,NULL,TRUE
	invoke UpdateWindow,hSonar
	retn

Setup:
	invoke SendDlgItemMessage,hWnd,IDC_TRBGAIN,TBM_GETPOS,0,0
	mov		sonardata.Gain,al
	invoke SendDlgItemMessage,hWnd,IDC_TRBNOISE,TBM_GETPOS,0,0
	mov		sonardata.Noise,al
	invoke SendDlgItemMessage,hWnd,IDC_TRBPULSES,TBM_GETPOS,0,0
	mov		sonardata.PingPulses,al
	retn

SonarThreadProc endp

ShowRangeDepthTempScaleFish proc uses ebx esi edi,hDC:HDC
	LOCAL	rcsonar:RECT
	LOCAL	rect:RECT
	LOCAL	x:DWORD
	LOCAL	buffer[32]:BYTE

	invoke GetClientRect,hSonar,addr rcsonar
	.if sonardata.FishDetect
		call	ShowFish
	.endif
	invoke SetBkMode,hDC,TRANSPARENT
	xor		ebx,ebx
	mov		esi,offset sonardata.options
	.while ebx<MAXSONAROPTION
		.if [esi].OPTIONS.show
			.if ebx==1
				.if (sonardata.ShowDepth & 1) || (sonardata.ShowDepth>1)
					call ShowOption
				.endif
			.else
				call ShowOption
			.endif
		.endif
		lea		esi,[esi+sizeof OPTIONS]
		inc		ebx
	.endw
	call	ShowScale
	ret

ShowFish:
	movzx	ebx,sonardata.sonar[(MAXXECHO*MAXYECHO)-MAXYECHO]
	invoke GetRangePtr,ebx
	mov		ebx,sonarrange.range[eax]
	mov		esi,MAXXECHO
	sub		esi,rcsonar.right
	.while esi<MAXXECHO
		xor		edi,edi
		.while edi<MAXYECHO
			mov		eax,MAXYECHO
			mul		esi
			movzx	eax,sonardata.sonar[eax+edi]
			.if eax==255
				;Large fish
				mov		eax,MAXYECHO
				mul		esi
				movzx	eax,sonardata.sonar[eax]
				invoke GetRangePtr,eax
				mov		ecx,sonarrange.range[eax]
				mov		eax,edi
				mul		ecx
				xor		edx,edx
				div		ebx
				mov		ecx,rcsonar.bottom
				mul		ecx
				mov		ecx,MAXYECHO
				xor		edx,edx
				div		ecx
				mov		ecx,eax
				mov		edx,rcsonar.right
				sub		edx,MAXXECHO
				invoke ImageList_Draw,hIml,18,hDC,addr [esi+edx-8],addr [ecx-8],ILD_TRANSPARENT
			.endif
			inc		edi
		.endw
		inc		esi
	.endw
	retn

ShowOption:
	mov		ecx,[esi].OPTIONS.pt.x
	mov		edx,[esi].OPTIONS.pt.y
	mov		rect.left,ecx
	mov		rect.top,edx
	mov		eax,rcsonar.right
	sub		eax,ecx
	mov		rect.right,eax
	mov		eax,rcsonar.bottom
	sub		eax,edx
	mov		rect.bottom,eax
	mov		eax,[esi].OPTIONS.font
	add		eax,7
	invoke SelectObject,hDC,map.font[eax*4]
	push	eax
	invoke strlen,addr [esi].OPTIONS.text
	mov		edi,eax
	mov		edx,[esi].OPTIONS.position
	.if !edx
		;Left, Top
		invoke SetTextColor,hDC,0FFFFFFh
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_LEFT or DT_SINGLELINE
		add		rect.top,4
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_LEFT or DT_SINGLELINE
		sub		rect.top,2
		sub		rect.left,2
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_LEFT or DT_SINGLELINE
		add		rect.left,4
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_LEFT or DT_SINGLELINE
		sub		rect.left,2
		invoke SetTextColor,hDC,0
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_LEFT or DT_SINGLELINE
	.elseif edx==1
		;Center, Top
		mov		rect.left,0
		mov		eax,[esi].OPTIONS.pt.x
		sub		rect.right,eax
		invoke SetTextColor,hDC,0
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_CENTER or DT_SINGLELINE
	.elseif edx==2
		;Rioght, Top
		invoke SetTextColor,hDC,0FFFFFFh
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_RIGHT or DT_SINGLELINE
		add		rect.top,4
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_RIGHT or DT_SINGLELINE
		sub		rect.top,2
		sub		rect.right,2
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_RIGHT or DT_SINGLELINE
		add		rect.right,4
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_RIGHT or DT_SINGLELINE
		sub		rect.right,2
		invoke SetTextColor,hDC,0
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_RIGHT or DT_SINGLELINE
	.elseif edx==3
		;Left, Bottom
		invoke SetTextColor,hDC,0FFFFFFh
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_LEFT or DT_BOTTOM or DT_SINGLELINE
		add		rect.bottom,4
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_LEFT or DT_BOTTOM or DT_SINGLELINE
		sub		rect.bottom,2
		sub		rect.left,2
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_LEFT or DT_BOTTOM or DT_SINGLELINE
		add		rect.left,4
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_LEFT or DT_BOTTOM or DT_SINGLELINE
		sub		rect.left,2
		invoke SetTextColor,hDC,0
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_LEFT or DT_BOTTOM or DT_SINGLELINE
	.elseif edx==4
		;Center, Bottom
		mov		rect.left,0
		mov		eax,[esi].OPTIONS.pt.x
		sub		rect.right,eax
		invoke SetTextColor,hDC,0
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_CENTER or DT_BOTTOM or DT_SINGLELINE
	.elseif edx==5
		;Right, Bottom
		invoke SetTextColor,hDC,0FFFFFFh
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_RIGHT or DT_BOTTOM or DT_SINGLELINE
		add		rect.bottom,4
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_RIGHT or DT_BOTTOM or DT_SINGLELINE
		sub		rect.bottom,2
		sub		rect.right,2
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_RIGHT or DT_BOTTOM or DT_SINGLELINE
		add		rect.right,4
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_RIGHT or DT_BOTTOM or DT_SINGLELINE
		sub		rect.right,2
		invoke SetTextColor,hDC,0
		invoke DrawText,hDC,addr [esi].OPTIONS.text,edi,addr rect,DT_RIGHT or DT_BOTTOM or DT_SINGLELINE
	.endif
	pop		eax
	invoke SelectObject,hDC,eax
	retn

ShowScale:
	invoke GetStockObject,WHITE_PEN
	invoke SelectObject,hDC,eax
	push	eax
	invoke SetTextColor,hDC,0FFFFFFh

	invoke MoveToEx,hDC,1,5,NULL
	invoke LineTo,hDC,9,5
	mov		word ptr buffer,'0'
	invoke TextOut,hDC,11,-1,addr buffer,1
	invoke MoveToEx,hDC,5,5,NULL
	mov		ebx,rect.bottom
	sub		ebx,13
	invoke LineTo,hDC,5,ebx
	invoke MoveToEx,hDC,1,ebx,NULL
	invoke LineTo,hDC,9,ebx
	mov		edi,sonardata.RangeVal
	invoke wsprintf,addr buffer,addr szFmtDec,edi
	invoke lstrlen,addr buffer
	invoke TextOut,hDC,11,addr [ebx-9],addr buffer,eax
	inc		ebx
	shr		ebx,1
	dec		ebx
	invoke MoveToEx,hDC,1,ebx,NULL
	invoke LineTo,hDC,9,ebx
	shr		edi,1
	invoke wsprintf,addr buffer,addr szFmtDec,edi
	invoke lstrlen,addr buffer
	invoke TextOut,hDC,11,addr [ebx-9],addr buffer,eax

	invoke MoveToEx,hDC,3,7,NULL
	invoke LineTo,hDC,11,7
	mov		word ptr buffer,'0'
	invoke TextOut,hDC,13,1,addr buffer,1
	invoke MoveToEx,hDC,7,7,NULL
	mov		ebx,rect.bottom
	sub		ebx,11
	invoke LineTo,hDC,7,ebx
	invoke MoveToEx,hDC,3,ebx,NULL
	invoke LineTo,hDC,11,ebx
	mov		edi,sonardata.RangeVal
	invoke wsprintf,addr buffer,addr szFmtDec,edi
	invoke lstrlen,addr buffer
	invoke TextOut,hDC,13,addr [ebx-11],addr buffer,eax
	dec		ebx
	shr		ebx,1
	inc		ebx
	invoke MoveToEx,hDC,3,ebx,NULL
	invoke LineTo,hDC,11,ebx
	shr		edi,1
	invoke wsprintf,addr buffer,addr szFmtDec,edi
	invoke lstrlen,addr buffer
	invoke TextOut,hDC,13,addr [ebx-11],addr buffer,eax

	pop		eax
	invoke SelectObject,hDC,eax
	invoke GetStockObject,BLACK_PEN
	invoke SelectObject,hDC,eax
	push	eax
	invoke SetTextColor,hDC,0
	invoke MoveToEx,hDC,2,6,NULL
	invoke LineTo,hDC,10,6
	mov		word ptr buffer,'0'
	invoke TextOut,hDC,12,0,addr buffer,1
	invoke MoveToEx,hDC,6,6,NULL
	mov		ebx,rect.bottom
	sub		ebx,12
	invoke LineTo,hDC,6,ebx
	invoke MoveToEx,hDC,2,ebx,NULL
	invoke LineTo,hDC,10,ebx
	mov		edi,sonardata.RangeVal
	invoke wsprintf,addr buffer,addr szFmtDec,edi
	invoke lstrlen,addr buffer
	invoke TextOut,hDC,12,addr [ebx-10],addr buffer,eax
	shr		ebx,1
	invoke MoveToEx,hDC,2,ebx,NULL
	invoke LineTo,hDC,10,ebx
	shr		edi,1
	invoke wsprintf,addr buffer,addr szFmtDec,edi
	invoke lstrlen,addr buffer
	invoke TextOut,hDC,12,addr [ebx-10],addr buffer,eax
	pop		eax
	invoke SelectObject,hDC,eax
	retn

ShowRangeDepthTempScaleFish endp

SaveSonarToIni proc
	LOCAL	buffer[256]:BYTE

	mov		buffer,0
	;Width,AutoRange,AutoGain,AutoPing,FishDetect,FishAlarm,RangeInx,Noise,PingPulses,Gain,ChartSpeed
	invoke PutItemInt,addr buffer,sonardata.wt
	invoke PutItemInt,addr buffer,sonardata.AutoRange
	invoke PutItemInt,addr buffer,sonardata.AutoGain
	invoke PutItemInt,addr buffer,sonardata.AutoPing
	invoke PutItemInt,addr buffer,sonardata.FishDetect
	invoke PutItemInt,addr buffer,sonardata.FishAlarm
	invoke PutItemInt,addr buffer,sonardata.RangeInx
	invoke PutItemInt,addr buffer,sonardata.Noise
	invoke PutItemInt,addr buffer,sonardata.PingPulses
	invoke PutItemInt,addr buffer,sonardata.Gain
	invoke PutItemInt,addr buffer,sonardata.ChartSpeed
	invoke WritePrivateProfileString,addr szIniSonar,addr szIniSonar,addr buffer[1],addr szIniFileName
	ret

SaveSonarToIni endp

LoadSonarFromIni proc
	LOCAL	buffer[256]:BYTE
	
	invoke RtlZeroMemory,addr buffer,sizeof buffer
	invoke GetPrivateProfileString,addr szIniSonar,addr szIniSonar,addr szNULL,addr buffer,sizeof buffer,addr szIniFileName
	;Width,AutoRange,AutoGain,AutoPing,FishDetect,FishAlarm,RangeInx,Noise,PingPulses,Gain,ChartSpeed
	invoke GetItemInt,addr buffer,250
	mov		sonardata.wt,eax
	invoke GetItemInt,addr buffer,1
	mov		sonardata.AutoRange,eax
	invoke GetItemInt,addr buffer,1
	mov		sonardata.AutoGain,eax
	invoke GetItemInt,addr buffer,1
	mov		sonardata.AutoPing,eax
	invoke GetItemInt,addr buffer,1
	mov		sonardata.FishDetect,eax
	invoke GetItemInt,addr buffer,1
	mov		sonardata.FishAlarm,eax
	invoke GetItemInt,addr buffer,0
	mov		sonardata.RangeInx,al
	invoke GetItemInt,addr buffer,31
	mov		sonardata.Noise,al
	invoke GetItemInt,addr buffer,7
	mov		sonardata.PingPulses,al
	invoke GetItemInt,addr buffer,63
	mov		sonardata.Gain,al
	invoke GetItemInt,addr buffer,3
	mov		sonardata.ChartSpeed,eax
	ret

LoadSonarFromIni endp

SonarProc proc uses ebx esi edi,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	LOCAL	ps:PAINTSTRUCT
	LOCAL	rect:RECT
	LOCAL	hDC:HDC
	LOCAL	mDC:HDC
	LOCAL	hBmp:HBITMAP

	mov		eax,uMsg
	.if eax==WM_CREATE
		mov		eax,hWin
		mov		hSonar,eax
		invoke GetDC,hWin
		mov		hDC,eax
		invoke CreateCompatibleDC,hDC
		mov		sonardata.mDC,eax
		invoke CreateCompatibleBitmap,hDC,MAXXECHO,MAXYECHO
		mov		sonardata.hBmp,eax
		invoke SelectObject,sonardata.mDC,eax
		mov		sonardata.hBmpOld,eax
		mov		rect.left,0
		mov		rect.top,0
		mov		rect.right,MAXXECHO
		mov		rect.bottom,MAXYECHO
		invoke CreateSolidBrush,SONARBACKCOLOR
		push	eax
		invoke FillRect,sonardata.mDC,addr rect,eax
		pop		eax
		invoke DeleteObject,eax
		invoke ReleaseDC,hWin,hDC
		mov		pixdpt,250
		invoke SetTimer,hWin,1000,800,NULL
		invoke SetTimer,hWin,1001,1000,NULL
	.elseif eax==WM_TIMER
		.if wParam==1000
			.if !fSTLink
				mov		fSTLink,IDIGNORE
				invoke STLinkConnect,hWnd
				.if eax==IDABORT
					invoke SendMessage,hWnd,WM_CLOSE,0,0
				.else
					mov		fSTLink,eax
				.endif
				.if fSTLink && fSTLink!=IDIGNORE
					invoke STLinkReset,hWnd
				.endif
				invoke CreateThread,NULL,NULL,addr STM32Thread,hWin,0,addr tid
				invoke CloseHandle,eax
			.endif
			.if fSTLink && !fThread
				invoke KillTimer,hWin,1000
				mov		fThread,TRUE
				invoke CreateThread,NULL,NULL,addr SonarThreadProc,hWin,0,addr tid
				invoke CloseHandle,eax
				mov		eax,sonardata.ChartSpeed
				.if eax==0
					mov		eax,800
				.elseif eax==1
					mov		eax,400
				.elseif eax==2
					mov		eax,200
				.elseif eax==3
					mov		eax,100
				.elseif eax==4
					mov		eax,50
				.endif
				invoke SetTimer,hWin,1000,eax,NULL
			.endif
		.elseif wParam==1001
			xor		sonardata.ShowDepth,1
			.if sonardata.ShowDepth<2
				invoke InvalidateRect,hSonar,NULL,TRUE
			.endif
		.endif
	.elseif eax==WM_DESTROY
		.if fSTLink && fSTLink!=IDIGNORE
			invoke STLinkDisconnect
		.endif
		invoke SelectObject,sonardata.mDC,sonardata.hBmpOld
		invoke DeleteObject,sonardata.hBmp
		invoke DeleteDC,sonardata.mDC
		invoke SaveSonarToIni
	.elseif eax==WM_PAINT
		invoke GetClientRect,hWin,addr rect
		invoke BeginPaint,hWin,addr ps
		invoke CreateCompatibleDC,ps.hdc
		mov		mDC,eax
		invoke CreateCompatibleBitmap,ps.hdc,rect.right,rect.bottom
		invoke SelectObject,mDC,eax
		push	eax
		invoke CreateSolidBrush,SONARBACKCOLOR
		push	eax
		invoke FillRect,mDC,addr rect,eax
		pop		eax
		invoke DeleteObject,eax
		mov		ecx,MAXXECHO
		sub		ecx,rect.right
		mov		eax,sonardata.RangeVal
		mov		edx,10
		mul		edx
		sub		rect.bottom,12
		invoke StretchBlt,mDC,0,6,rect.right,rect.bottom,sonardata.mDC,ecx,0,rect.right,MAXYECHO,SRCCOPY
		invoke ShowRangeDepthTempScaleFish,mDC
		add		rect.bottom,12
		invoke BitBlt,ps.hdc,0,0,rect.right,rect.bottom,mDC,0,0,SRCCOPY
		pop		eax
		invoke SelectObject,mDC,eax
		invoke DeleteObject,eax
		invoke DeleteDC,mDC
		invoke EndPaint,hWin,addr ps
	.else
		invoke DefWindowProc,hWin,uMsg,wParam,lParam
		ret
	.endif
	xor    eax,eax
	ret

SonarProc endp
