.386
.model flat, stdcall
.stack 10448576
option casemap:none

; ========== LIBRERIAS =============
include masm32\include\windows.inc 
include masm32\include\kernel32.inc
include masm32\include\user32.inc
includelib masm32\lib\kernel32.lib
includelib masm32\lib\user32.lib
include masm32\include\gdi32.inc
includelib masm32\lib\Gdi32.lib
include masm32\include\msimg32.inc
includelib masm32\lib\msimg32.lib
include masm32\include\winmm.inc
includelib masm32\lib\winmm.lib

; ================================== PROTOTIPOS ======================================
main			proto
credits			proto	:DWORD
playMusic		proto
joystickError	proto
setup			proto
algorythm		proto
LocateFruit		proto
NewFruit		proto
PseudoRandom    proto
SeparateScore	proto	:DWORD
PrintScore		proto	:DWORD, :DWORD
PrintNumber		proto	:DWORD, :DWORD
GameoverProc	proto
WinMain			proto	:DWORD, :DWORD, :DWORD, :DWORD

; =========================================== DECLARACION DE VARIABLES =====================================================
.data
; =============================== VARIABLES QUE NORMALMENTE NO VAN A TENER QUE CAMBIAR =====================================
className				db			"ProyectoEnsamblador",0		; Se usa para declarar el nombre del "estilo" de la ventana.
windowHandler			dword		?							; Un HWND auxiliar
windowClass				WNDCLASSEX	<>							; Aqui es en donde registramos la "clase" de la ventana.
windowMessage			MSG			<>							; Sirve pare el ciclo de mensajes (los del WHILE infinito)
clientRect				RECT		<>							; Un RECT auxilar, representa el área usable de la ventana
windowContext			HDC			?							; El contexto de la ventana
layer					HBITMAP		?							; El lienzo, donde dibujaremos cosas
layerContext			HDC			?							; El contexto del lienzo
auxiliarLayer			HBITMAP		?							; Un lienzo auxiliar
auxiliarLayerContext	HBITMAP		?							; El contexto del lienzo auxiliar
clearColor				HBRUSH		?							; El color de limpiado de pantalla
windowPaintstruct		PAINTSTRUCT	<>							; El paintstruct de la ventana.
joystickInfo			JOYINFO		<>							; Información sobre el joystick.
; //// Mensajes de error: \\\\
errorTitle				byte		'Error', 0
joystickErrorText		byte		'No se pudo inicializar el joystick', 0

; ========================================== VARIABLES QUE PROBABLEMENTE QUIERAN CAMBIAR ===================================
windowTitle				db			"SNAKEx86",0							; El título de la ventana
windowWidth				DWORD		368										; El ancho de la venata CON TODO Y LA BARRA DE TITULO Y LOS MARGENES
windowHeight			DWORD		426										; El alto de la ventana CON TODO Y LA BARRA DE TITULO Y LOS MARGENES
messageBoxTitle			byte		'Plantilla ensamblador: Créditos',0		; Un string, se usa como título del messagebox NOTESE QUE TRAS ESCRIBIR EL STRING, SE LE CONCATENA UN 0
messageBoxText			byte		'Programación: Edgar Abraham Santos Cervantes',10,'Arte: Estúdio Vaca Roxa',10,'https://bakudas.itch.io/generic-rpg-pack',0
musicFilename			byte		'snake_theme.wav',0						; El nombre de la música a reproducir.
image					HBITMAP		?										; El manejador de la imagen a manuplar, pueden agregar tantos como necesiten.
imageFilename			byte		'snake_spritesheet.bmp',0				; El manejador de la imagen a manuplar, pueden agregar tantos como necesiten.

;==============================================
;=============== MIS VARIABLES ================
;==============================================
timer_counter byte 0
controller byte 0
mode dword 0
gamestate byte 0								; gamestate 0 = mainmenu / gamestate 1 = running_game / gamestate 2 = pause / gamestate 3 = gameover / gamestate 4 = reach_perfect
speed byte 0
maxspeed byte 0
speedchange byte 0
fruitcount byte 0
seed dword 0
randnum dword 0
score dword 0
scorearray dword 5 dup (0)
savescore dword 6 dup (0)

dir dword 0
facing dword 0
personajeX dword 0
personajeY dword 0
tailX dword 400 dup(0)
tailY dword 400 dup(0)
prevX dword 0
prevY dword 0
prev2X dword 0
prev2Y dword 0
nTail dword 0

fruitX dword 0
fruitY dword 0

; =============== MACROS ===================
RGB MACRO red, green, blue
	exitm % blue shl 16 + green shl 8 + red
endm

;================= PROGRAMA ==================
.code

main proc
	mov seed, eax
	invoke	CreateThread, 0, 0, playMusic, 0, 0, 0				;Reproduce música
	invoke	GetModuleHandleA, NULL								;Obtenemos la INSTANCIA de la Aplicación y se guarda en EAX por defecto.
	invoke	WinMain, eax, NULL, NULL, SW_SHOWDEFAULT			;Ejecutamos WinMain con la INSTANCIA guardada en EAX.
	invoke ExitProcess, 0
main endp

WinMain proc hInstance:dword, hPrevInst:dword, cmdLine:dword, cmdShow:DWORD
	
	; //// INICIALIZACION DE LA CLASE \\\\
	mov		windowClass.lpfnWndProc, OFFSET WindowCallback			; Establecemos nuestro callback procedure, que en este caso se llama WindowCallback
	mov		windowClass.cbSize, SIZEOF WNDCLASSEX					; Tenemos que decir el tamaño de nuestra estructura, si no se lo dicen no se podrá crear la ventana.
	mov		eax, hInstance											; Le asignamos nuestro HINSTANCE
	mov		windowClass.hInstance, eax
	mov		windowClass.lpszClassName, OFFSET className				; Asignamos el nombre de nuestra "clase"
	invoke RegisterClassExA, addr windowClass                       ; Registramos la clase

	; //// CREACIÓN DE LA VENATANA \\\\
	xor		ebx, ebx												; Creamos la ventana.
	mov		ebx, WS_OVERLAPPED										; Le asignamos los estilos para que se pueda crear pero que NO se pueda alterar su tamaño, maximizar ni minimizar
	or		ebx, WS_CAPTION
	or		ebx, WS_SYSMENU
	invoke CreateWindowExA, NULL, ADDR className, ADDR windowTitle, ebx, CW_USEDEFAULT, CW_USEDEFAULT, windowWidth, windowHeight, NULL, NULL, hInstance, NULL
	mov		windowHandler, eax										; Guardamos el resultado en una variable auxilar y mostramos la ventana.
    invoke ShowWindow, windowHandler, cmdShow
    invoke UpdateWindow, windowHandler

	; //// EL CICLO DE MENSAJES \\\\
    invoke	GetMessageA, ADDR windowMessage, NULL, 0, 0
	.WHILE eax != 0
        invoke	TranslateMessage, ADDR windowMessage
        invoke	DispatchMessageA, ADDR windowMessage
		invoke	GetMessageA, ADDR windowMessage, NULL, 0, 0
   .ENDW
    mov eax, windowMessage.wParam
	ret
WinMain endp

WindowCallback proc handler:dword, message:dword, wParam:dword, lParam:dword

;	//// WM_CREATE \\\\
	.IF message == WM_CREATE
		invoke	GetClientRect, handler, addr clientRect											; Obtiene las dimenciones del área de trabajo de la ventana.
		invoke	GetDC, handler																	; Obtenemos el contexto de la ventana.
		mov		windowContext, eax
		invoke	CreateCompatibleBitmap, windowContext, clientRect.right, clientRect.bottom		; Creamos un bitmap del tamaño del área de trabajo de nuestra ventana.
		mov		layer, eax
		invoke	CreateCompatibleDC, windowContext												; Y le creamos un contexto
		mov		layerContext, eax
		invoke	ReleaseDC, handler, windowContext												; Liberamos windowContext para poder trabajar con lo demás
		invoke	SelectObject, layerContext, layer												; Le decimos que el contexto layerContext le pertenece a layer
		invoke	DeleteObject, layer
		invoke	CreateSolidBrush, RGB(0,0,0)													; Asignamos un color de limpiado de pantalla
		mov		clearColor, eax
		invoke	LoadImage, NULL, addr imageFilename, IMAGE_BITMAP, 0, 0, LR_LOADFROMFILE		;Cargamos la imagen
		mov		image, eax
		invoke	joyGetNumDevs																	; Habilitamos el joystick
		invoke	joyGetPos, JOYSTICKID1, addr joystickInfo
		invoke	joySetCapture, handler, JOYSTICKID1, NULL, FALSE
		invoke	SetTimer, handler, 33, 10, NULL

;	//// WM_PAINT \\\\
	.ELSEIF message == WM_PAINT
		invoke	BeginPaint, handler, addr windowPaintstruct										; Iniciamos nuestro windowContext
		mov		windowContext, eax
		invoke	CreateCompatibleBitmap, layerContext, clientRect.right, clientRect.bottom		; Creamos un bitmap auxilar. Esto es, para evitar el efecto de parpadeo
		mov		auxiliarLayer, eax
		invoke	CreateCompatibleDC, layerContext												; Le creamos su contetxo
		mov		auxiliarLayerContext, eax
		invoke	SelectObject, auxiliarLayerContext, auxiliarLayer								; Lo asociamos
		invoke	DeleteObject, auxiliarLayer
		invoke	FillRect, auxiliarLayerContext, addr clientRect, clearColor						; Llenamos nuestro auxiliar con nuestro color de borrado, sirve para limpiar la pantalla
		invoke	SelectObject, layerContext, image												; Elegimos la imagen

		; //// PROCESOS DE DIBUJADO \\\\

		invoke	TransparentBlt, auxiliarLayerContext, 0, 0, 352, 352, layerContext, 0, 17, 352, 352, 00000FF00h			; Mundo de Snake

		.IF gamestate != 0
			mov ecx, nTail																									; Cola de snake
			mov ebx, offset tailX
			mov esi, offset tailY
			tail_draw:
				push ecx
				mov eax, dword ptr [ebx]
				mov edx, dword ptr [esi]
				invoke	TransparentBlt, auxiliarLayerContext, eax, edx, 16, 16, layerContext, 64, 0, 16, 16, 00000FF00h
				add ebx, 4
				add esi, 4
				pop ecx
			loop tail_draw

			mov eax, personajeX																								; Cabeza de Snake
			mov ebx, personajeY
			.IF facing == 0
				invoke	TransparentBlt, auxiliarLayerContext, personajeX, personajeY, 16, 16, layerContext, 0, 0, 16, 16, 0000FF00h
			.ELSEIF facing == 1
				invoke	TransparentBlt, auxiliarLayerContext, personajeX, personajeY, 16, 16, layerContext, 16, 0, 16, 16, 0000FF00h
			.ELSEIF facing == 2
				invoke	TransparentBlt, auxiliarLayerContext, personajeX, personajeY, 16, 16, layerContext, 32, 0, 16, 16, 0000FF00h
			.ELSEIF facing == 3
				invoke	TransparentBlt, auxiliarLayerContext, personajeX, personajeY, 16, 16, layerContext, 48, 0, 16, 16, 0000FF00h
			.ENDIF

			.IF gamestate != 4																								; Fruta
				mov eax, fruitX
				mov ebx, fruitY
				invoke	TransparentBlt, auxiliarLayerContext, eax, ebx, 16, 16, layerContext, 80, 0, 16, 16, 00000FF00h
			.ENDIF

			invoke SeparateScore, score
			invoke PrintScore, 100, 354

			.IF gamestate == 2
				invoke TransparentBlt, auxiliarLayerContext, 122, 154, 107, 43, layerContext, 352, 148, 107, 43, 00000FF00h
			.ELSEIF gamestate == 3
				invoke TransparentBlt, auxiliarLayerContext, 85, 35, 182, 110, layerContext, 352, 0, 182, 110, 00000FF00h
				mov esi, offset savescore
				mov ebx, 160
				mov ecx, 6
				print_scores:
					push ecx
					mov eax, dword ptr [esi]
					push ebx
					invoke SeparateScore, eax
					pop ebx
					push esi
					invoke PrintScore, 135, ebx
					pop esi
					add ebx, 28
					add esi, 4
					pop ecx
				loop print_scores
			.ELSEIF gamestate == 4
				invoke TransparentBlt, auxiliarLayerContext, 85, 121, 206, 110, layerContext, 352, 191, 206, 110, 00000FF00h
			.ENDIF
		.ELSEIF
			invoke TransparentBlt, auxiliarLayerContext, 43, 30, 266, 230, layerContext, 568, 0, 266, 230, 00000FF00h
		.ENDIF

		; //// MOSTRAR EN PANTALLA \\\\
		invoke	BitBlt, windowContext, 0, 0, clientRect.right, clientRect.bottom, auxiliarLayerContext, 0, 0, SRCCOPY	
		invoke  EndPaint, handler, addr windowPaintstruct										; Es MUY importante liberar los recursos al terminar de usuarlos, si no se liberan la aplicación se quedará trabada con el tiempo
		invoke	DeleteDC, windowContext
		invoke	DeleteDC, auxiliarLayerContext

;	//// WM_KEYDOWN \\\\
	.ELSEIF message == WM_KEYDOWN
		mov	eax, wParam
		.IF controller == 1
			.IF gamestate == 1
				.IF al == 65
					.IF dir == 3
						jmp jump65
					.ENDIF
					mov dir, 1
					jump65:
				.ELSEIF al == 87
					.IF dir == 4
						jmp jump87
					.ENDIF
					mov dir, 2
					jump87:
				.ELSEIF al == 68
					.IF dir == 1
						jmp jump68
					.ENDIF
					.IF dir == 0
						jmp jump68
					.ENDIF
					mov dir, 3
					jump68:
				.ELSEIF al == 83
					.IF dir == 2
						jmp jump83
					.ENDIF
					mov dir, 4
					jump83:
				.ENDIF
			.ENDIF
			mov controller, 0
		.ENDIF
		.IF al == 20
			invoke	credits, handler
		.ENDIF
		.IF al == 82
			mov gamestate, 0
		.ENDIF
		.IF al == 13
			.IF gamestate != 3
				.IF gamestate == 1
					mov gamestate, 2
				.ELSEIF gamestate == 2
					mov gamestate, 1
				.ENDIF
			.ENDIF
		.ENDIF
		.IF gamestate == 0
			.IF al == 65
				mov mode, 0
				invoke setup
			.ELSEIF al == 83
				mov mode, 1
				invoke setup
			.ELSEIF al == 68
				mov mode, 2
				invoke setup
			.ENDIF
		.ENDIF

;	//// MM_JOY1MOVE \\\\
	.ELSEIF message == MM_JOY1MOVE
		; Lo que pasa cuando mueves la palanca del joystick
		xor	ebx, ebx
		xor edx, edx
		mov	edx, lParam
		mov bx, dx
		and	dx, 0
		ror edx, 16
		.IF controller == 1
			.IF gamestate == 1
				.IF bx < 062B3h
					.IF dir == 3
						jmp jump65_j
					.ENDIF
					mov dir, 1
					jump65_j:
				.ELSEIF dx < 062B3h
					.IF dir == 4
						jmp jump87_j
					.ENDIF
					mov dir, 2
					jump87_j:
				.ELSEIF bx > 09D4Bh
					.IF dir == 1
						jmp jump68_j
					.ENDIF
					.IF dir == 0
						jmp jump68_j
					.ENDIF
					mov dir, 3
					jump68_j:
				.ELSEIF dx > 09D4Bh
					.IF dir == 2
						jmp jump83_j
					.ENDIF
					mov dir, 4
					jump83_j:
				.ENDIF
			.ENDIF
			mov controller, 0
		.ENDIF

;	//// MM_JOY1BUTTONDOWN \\\\
	.ELSEIF message == MM_JOY1BUTTONDOWN
		; Lo que hace cuando presionas un botón del joystick
		; Pueden comparar que botón se presionó haciendo un AND
		xor	ebx, ebx
		mov	ebx, wParam 
		and ebx, JOY_BUTTON4
		.IF ebx != 0
			mov gamestate, 0
		.ENDIF
		xor	ebx, ebx
		mov	ebx, wParam 
		and ebx, JOY_BUTTON2
		.IF ebx != 0
			.IF gamestate != 3
				.IF gamestate == 1
					mov gamestate, 2
				.ELSEIF gamestate == 2
					mov gamestate, 1
				.ENDIF
			.ENDIF
		.ENDIF
		.IF gamestate == 0
			xor	ebx, ebx
			mov	ebx, wParam 
			and ebx, JOY_BUTTON3
			.IF ebx != 0
				mov mode, 0
				invoke setup
			.ENDIF
			xor	ebx, ebx
			mov	ebx, wParam 
			and ebx, JOY_BUTTON1
			.IF ebx != 0
				mov mode, 1
				invoke setup
			.ENDIF
			xor	ebx, ebx
			mov	ebx, wParam 
			and ebx, JOY_BUTTON2
			.IF ebx != 0
				mov mode, 2
				invoke setup
			.ENDIF
		.ENDIF

;	//// WM_TIMER \\\\
	.ELSEIF message == WM_TIMER
		.IF mode == 0
			mov al, speed
			.IF timer_counter == al
				mov timer_counter, 0
			.ENDIF
		.ELSEIF mode == 1
			mov al, speed
			.IF timer_counter == al
				mov timer_counter, 0
			.ENDIF
		.ELSEIF mode == 2
			mov al, speed
			.IF timer_counter == al
				mov timer_counter, 0
			.ENDIF
		.ENDIF
		.IF timer_counter == 0
			.IF gamestate == 1
				invoke algorythm
			.ENDIF
		.ENDIF
	inc timer_counter
	invoke	InvalidateRect, handler, NULL, FALSE

;	//// WM_DESTROY \\\\
	.ELSEIF message == WM_DESTROY
        invoke PostQuitMessage, NULL											; Lo que debe suceder al intentar cerrar la ventana.   
    .ENDIF
    invoke DefWindowProcA, handler, message, wParam, lParam      
    ret
WindowCallback endp

setup proc
	mov ecx, 400
	mov esi, offset tailX
	mov edi, offset tailY
	zeroTail:
		mov dword ptr [esi], 0
		mov dword ptr [edi], 0
		add esi, 4
		add edi, 4
	loop zeroTail
	mov ecx, 5
	mov esi, offset scorearray
	initScorePrint:
		mov dword ptr [esi], 0
		add esi, 4
	loop initScorePrint
	mov gamestate, 1
	mov controller, 1
	mov dir, 0
	mov facing, 0
	mov personajeX, 176
	mov personajeY, 176
	mov nTail, 3
	mov score, 0
	mov fruitcount, 0
	mov ecx, nTail
	mov esi, offset tailX
	mov edi, offset tailY
	mov eax, personajeX
	add eax, 16
	mov ebx, personajeY
	initializeTail:
		mov dword ptr [esi], eax
		mov dword ptr [edi], ebx
		add eax, 16
		add esi, 4
		add edi, 4
	loop initializeTail
	.IF mode == 0
		mov speed, 20
		mov speedchange, 12
		mov maxspeed, 12
	.ELSEIF mode == 1
		mov speed, 18
		mov speedchange, 10
		mov maxspeed, 8
	.ELSEIF mode == 2
		mov speed, 14
		mov speedchange, 8
		mov maxspeed, 6
	.ENDIF
	invoke NewFruit
	ret
setup endp

algorythm proc
	.IF dir != 0
		mov eax, tailX[0]
		mov prevX, eax
		mov eax, tailY[0]
		mov prevY, eax
		mov eax, personajeX
		mov tailX[0], eax
		mov eax, personajeY
		mov tailY[0], eax
		mov ecx, nTail
		mov esi, offset tailX
		mov edi, offset tailY
		add esi, 4
		add edi, 4
		move_tail:
			mov eax, dword ptr [esi]
			mov prev2X, eax
			mov eax, dword ptr [edi]
			mov prev2Y, eax
			mov eax, prevX
			mov dword ptr [esi], eax
			mov eax, prevY
			mov dword ptr [edi], eax
			mov eax, prev2X
			mov prevX, eax
			mov eax, prev2Y
			mov prevY, eax
			add esi, 4
			add edi, 4
		loop move_tail
	.ENDIF
	.IF dir == 1
		sub personajeX, 16
		mov facing, 0
	.ELSEIF dir == 2
		sub personajeY, 16
		mov facing, 1
	.ELSEIF dir == 3
		add personajeX, 16
		mov facing, 2
	.ELSEIF dir == 4
		add personajeY, 16
		mov facing, 3
	.ENDIF
	mov ecx, nTail
	mov esi, offset tailX
	mov edi, offset tailY
	colide_yourself:
		mov eax, dword ptr [esi]
		mov ebx, dword ptr [edi]
		.IF eax == personajeX
			.IF ebx == personajeY
				mov gamestate, 3
				invoke GameoverProc
				jmp ext_colide_yourself
			.ENDIF
		.ENDIF
		add esi, 4
		add edi, 4
	loop colide_yourself
	ext_colide_yourself:
	mov eax, personajeX
	mov ebx, personajeY
	.IF eax == fruitX
		.IF ebx == fruitY
			inc nTail
			add score, 100
			inc fruitcount
			mov al, speedchange
			.IF fruitcount == al
				mov bl, maxspeed
				.IF speed != bl
					sub speed, 2
				.ENDIF
				mov fruitcount, 0
			.ENDIF
			.IF nTail == 396
				mov gamestate, 4
			.ELSE
				invoke NewFruit
			.ENDIF
		.ENDIF
	.ENDIF
	mov eax, personajeX
	mov ebx, personajeY
	.IF eax == 0
		mov gamestate, 3
		invoke GameoverProc
	.ELSEIF eax == 336
		mov gamestate, 3
		invoke GameoverProc
	.ENDIF
	.IF ebx == 0
		mov gamestate, 3
		invoke GameoverProc
	.ELSEIF ebx == 336
		mov gamestate, 3
		invoke GameoverProc
	.ENDIF
	mov controller, 1
	ret
algorythm endp

NewFruit proc
	invoke LocateFruit
	mov eax, 0
	mov ebx, 0
	mov ecx, 0
	mov edx, 0
	mov esi, 0
	mov edi, 0
	mov eax, personajeX
	mov ebx, personajeY
	.IF fruitX == eax
		.IF fruitY == ebx
			invoke NewFruit
			jmp checkcolide_end
		.ENDIF
	.ENDIF
	mov ecx, nTail
	mov esi, offset tailX
	mov edi, offset tailY
	checkcolide:
		push ecx
		mov eax, dword ptr [esi]
		mov ebx, dword ptr [edi]
		.IF fruitX == eax
			.IF fruitY == ebx
				pop ecx
				mov ecx, 0
				invoke NewFruit
				jmp checkcolide_end
			.ENDIF
		.ENDIF
		add esi, 4
		add edi, 4
		pop ecx
	loop checkcolide
	checkcolide_end:
	ret
NewFruit endp

LocateFruit proc
	mov eax, 20
	invoke PseudoRandom
	mov ebx, 16
	mul ebx
	mov fruitX, eax
	add fruitX, 16
	mov eax, 20
	invoke PseudoRandom
	mov ebx, 16
	mul ebx
	mov fruitY, eax
	add fruitY, 16
LocateFruit endp

PseudoRandom proc                       ; Deliver EAX: Range (0..EAX-1)
      push  edx                         ; Preserve EDX
      imul  edx,seed,08088405H			; EDX = RandSeed * 0x08088405 (decimal 134775813)
      inc   edx
      mov   seed, edx					; New RandSeed
      mul   edx                         ; EDX:EAX = EAX * EDX
      mov   eax, edx                    ; Return the EDX from the multiplication
      pop   edx                         ; Restore EDX
      ret
PseudoRandom endp                       ; Return EAX: Random number in range

SeparateScore proc scr:dword
	mov eax, scr
	mov edx, 0
	mov ebx, 10000
	div ebx
	mov scorearray[0], eax

	mov eax, scr
	mov edx, 0
	mov ebx, 1000
	div ebx
	mov ecx, eax
	mov eax, scorearray[0]
	mov ebx, 10
	mul ebx
	sub ecx, eax
	mov scorearray[4], ecx

	mov eax, scr
	mov edx, 0
	mov ebx, 100
	div ebx
	mov ecx, eax
	mov eax, scorearray[0]
	mov ebx, 100
	mul ebx
	sub ecx, eax
	mov eax, scorearray[4]
	mov ebx, 10
	mul ebx
	sub ecx, eax
	mov scorearray[8], ecx

	mov eax, scr
	mov edx, 0
	mov ebx, 10
	div ebx
	mov ecx, eax
	mov eax, scorearray[0]
	mov ebx, 1000
	mul ebx
	sub ecx, eax
	mov eax, scorearray[4]
	mov ebx, 100
	mul ebx
	sub ecx, eax
	mov eax, scorearray[8]
	mov ebx, 10
	mul ebx
	sub ecx, eax
	mov scorearray[12], ecx

	mov eax, scr
	mov ecx, eax
	mov eax, scorearray[0]
	mov ebx, 10000
	mul ebx
	sub ecx, eax
	mov eax, scorearray[4]
	mov ebx, 1000
	mul ebx
	sub ecx, eax
	mov eax, scorearray[8]
	mov ebx, 100
	mul ebx
	sub ecx, eax
	mov eax, scorearray[12]
	mov ebx, 10
	mul ebx
	sub ecx, eax
	mov scorearray[16], ecx
	ret
SeparateScore endp

PrintScore proc posx:dword, posy:dword
	mov ecx, 5
	mov esi, offset scorearray
	scoreP:
		push ecx
		mov eax, dword ptr [esi]
		invoke PrintNumber, posx, posy
		add posx, 18
		add esi, 4
		pop ecx
	loop scoreP
	ret
PrintScore endp

PrintNumber proc posx:dword, posy:dword
	.IF eax == 0
		invoke	TransparentBlt, auxiliarLayerContext, posx, posy, 21, 27, layerContext, 541, 120, 21, 27, 00000FF00h
	.ELSEIF eax == 1
		invoke	TransparentBlt, auxiliarLayerContext, posx, posy, 21, 27, layerContext, 352, 120, 21, 27, 00000FF00h
	.ELSEIF eax == 2
		invoke	TransparentBlt, auxiliarLayerContext, posx, posy, 21, 27, layerContext, 373, 120, 21, 27, 00000FF00h
	.ELSEIF eax == 3
		invoke	TransparentBlt, auxiliarLayerContext, posx, posy, 21, 27, layerContext, 394, 120, 21, 27, 00000FF00h
	.ELSEIF eax == 4
		invoke	TransparentBlt, auxiliarLayerContext, posx, posy, 21, 27, layerContext, 415, 120, 21, 27, 00000FF00h
	.ELSEIF eax == 5
		invoke	TransparentBlt, auxiliarLayerContext, posx, posy, 21, 27, layerContext, 436, 120, 21, 27, 00000FF00h
	.ELSEIF eax == 6
		invoke	TransparentBlt, auxiliarLayerContext, posx, posy, 21, 27, layerContext, 457, 120, 21, 27, 00000FF00h
	.ELSEIF eax == 7
		invoke	TransparentBlt, auxiliarLayerContext, posx, posy, 21, 27, layerContext, 478, 120, 21, 27, 00000FF00h
	.ELSEIF eax == 8
		invoke	TransparentBlt, auxiliarLayerContext, posx, posy, 21, 27, layerContext, 499, 120, 21, 27, 00000FF00h
	.ELSEIF eax == 9
		invoke	TransparentBlt, auxiliarLayerContext, posx, posy, 21, 27, layerContext, 520, 120, 21, 27, 00000FF00h
	.ENDIF
	ret
PrintNumber endp

GameoverProc proc
	mov ecx, 5
	mov esi, offset savescore
	mov edi, offset scorearray
	scoreset:
		mov eax, dword ptr [esi]
		mov dword ptr [edi], eax
		add esi, 4
		add edi, 4
	loop scoreset
	mov ecx, 5
	mov esi, offset savescore
	mov edi, offset scorearray
	add esi, 4
	scoredown:
		mov eax, dword ptr [edi]
		mov dword ptr [esi], eax
		add esi, 4
		add edi, 4
	loop scoredown
	mov eax, score
	mov savescore[0], eax
	ret
GameoverProc endp

playMusic proc
	xor		ebx, ebx
	mov		ebx, SND_FILENAME
	or		ebx, SND_LOOP
	or		ebx, SND_ASYNC
	invoke	PlaySound, addr musicFilename, NULL, ebx
	ret
playMusic endp

joystickError proc
	xor		ebx, ebx
	mov		ebx, MB_OK
	or		ebx, MB_ICONERROR
	invoke	MessageBoxA, NULL, addr joystickErrorText, addr errorTitle, ebx
	ret
joystickError endp

credits	proc handler:DWORD
	; Estoy matando al timer para que no haya problemas al mostrar el Messagebox.
	; Veanlo como un sistema de pausa
	invoke KillTimer, handler, 100
	xor ebx, ebx
	mov ebx, MB_OK
	or	ebx, MB_ICONINFORMATION
	invoke	MessageBoxA, handler, addr messageBoxText, addr messageBoxTitle, ebx
	; Volvemos a habilitar el timer
	invoke SetTimer, handler, 33, 10, NULL
	ret
credits endp

end main