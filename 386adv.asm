;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; -38.6 C Adventure
; tdwsl 2022
;
; An ice-cold text adventure written in 386 assembly
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; compile for linux with:
;   nasm -f elf 386adv.asm
;   ld -m elf_i386 386adv.o

section .text
global _start

; entry point
_start:
	cld
	mov esi,welcomeMsg
	call printStr

	call printLocTitle
	call mainLoop

	; exit
	mov eax,1
	int 80h

; main loop - read line, handle verbs, etc
mainLoop:
	call readLine

	mov edi,verb
	call getNext
	mov esi,verb

	mov al,[esi]
	or al,al
	jz mainLoop

	mov edi,vQuit
	call streq
	jz mainLoop_quit
	mov edi,vLook
	call streq
	jz mainLoop_look
	mov edi,vExamine
	call streq
	jz mainLoop_examine
	mov edi,vGo
	call streq
	jz mainLoop_go
	mov edi,vMove
	call streq
	jz mainLoop_go
	mov edi,vExit
	call streq
	jz mainLoop_go

	; "You don't know how to [verb]."
	mov esi,dontKnowMsg
	call printStr
	mov esi,verb
	call printStr
	mov al,'.'
	call printChar
	mov al,10
	call printChar

	jmp mainLoop

mainLoop_quit:
	mov esi,quitMsg
	call printStr
	ret

mainLoop_nothing: ; "You can't [verb] nothing!"
	mov esi,nothingMsgP1
	call printStr
	mov esi,verb
	call printStr
	mov esi,nothingMsgP2
	call printStr
	jmp mainLoop

mainLoop_noSuchThing: ; "You know of no such thing."
	mov esi,noSuchThingMsg
	call printStr
	jmp mainLoop

mainLoop_cantSeeThat: ; "You can't see that here."
	mov esi,cantSeeThatMsg
	call printStr
	jmp mainLoop

mainLoop_dontHaveThat: ; "You don't have that."
	mov esi,dontHaveThatMsg
	call printStr
	jmp mainLoop

mainLoop_examine:
	mov edi,noun
	call getNext
	mov al,[noun]
	or al,al
	jz mainLoop_nothing

	mov esi,noun
	call findItem
	or eax,eax
	jz mainLoop_noSuchThing

	call itemIsHere
	jnz mainLoop_cantSeeThat

	mov edx,eax
	add edx,9
	call [edx]

	jmp mainLoop

mainLoop_look:
	; look at
	mov edi,noun
	call getNext
	mov esi,noun
	mov edi,wAt
	call streq
	jz mainLoop_examine

	; print desc
	mov eax,[currentLocation]
	mov ebx,eax
	add ebx,4
	mov esi,[ebx]
	call printStr
	mov al,10
	call printChar

	; count directions
	mov ecx,10
	mov edx,0
	mov esi,[currentLocation]
	add esi,9
mainLoop_look_l0:
	lodsd
	or eax,eax
	jz mainLoop_look_l0z
	inc edx
mainLoop_look_l0z:
	loop mainLoop_look_l0

	or dl,dl
	jz mainLoop_look_noexit

	; print directions

	pusha
	mov esi,youCanGoMsg
	call printStr
	popa

	mov ecx,10
	mov esi,[currentLocation]
	add esi,9
mainLoop_look_l1:
	lodsd
	or eax,eax
	jz mainLoop_look_l1n

	pusha
	mov eax,10
	sub eax,ecx
	shl eax,2
	add eax,directions
	mov esi,[eax]
	call printStr
	popa

	dec edx
	jz mainLoop_look_l1n
	cmp edx,1
	jz mainLoop_look_l1and

	pusha
	mov al,','
	call printChar
	mov al,' '
	call printChar
	popa

	jmp mainLoop_look_l1n

mainLoop_look_l1and:
	pusha
	mov esi,orMsg
	call printStr
	popa

mainLoop_look_l1n:
	loop mainLoop_look_l1

	mov al,'.'
	call printChar
	mov al,10
	call printChar

mainLoop_look_noexit:
	jmp mainLoop

mainLoop_go:
	mov edi,noun
	call getNext
	mov al,[noun]
	or al,al
	jnz mainLoop_go_hasDirection

	mov esi,noDirectionMsg
	call printStr
	jmp mainLoop

mainLoop_go_hasDirection:
	mov esi,noun
	call isDirection
	jnz mainLoop_go_validDirection

	mov esi,invalidDirectionMsg
	call printStr
	jmp mainLoop

mainLoop_go_validDirection:
	mov esi,cantGoThatWayMsg
	call printStr
	jmp mainLoop

; check if is direction, load direction into eax
isDirection:
	mov edi,esi
	mov esi,directions
	mov ecx,10
isDirection_l0:
	lodsb
	push esi
	push edi
	mov esi,[eax]
	call streq
	pop edi
	pop esi
	jz isDirection_e
	loop isDirection_l0

isDirection_e:
	pushf
	mov eax,10
	sub eax,ecx
	popf
	ret

; check if item at eax is in inventory
hasItem:
	mov edx,eax
	add edx,8
	mov bl,[edx]
	cmp bl,1 ; id for inventory
	ret

; check if item at eax is in current room or inventory
itemIsHere:
	call hasItem
	jnz itemIsHere_0
	ret
itemIsHere_0:
	mov edx,[currentLocation]
	add edx,8
	mov bh,[edx]
	cmp bh,bl
	ret

; load ptr to item where name=esi into eax
findItem:
	mov edi,esi
	mov esi,items
findItem_l0:
	lodsd
	or eax,eax
	jz findItem_e

	push edi
	push esi
	push eax
	mov esi,[eax]
	call streq
	pop eax
	pop esi
	pop edi
	jnz findItem_l0
findItem_e:
	ret

; default examine
defExamine:
	mov esi,nothingSpecialMsg
	call printStr
	ret

; default take
defTake:
	ret

defDrop:
	ret

; called after moving
printLocTitle:
	mov al,'['
	call printChar
	mov eax,[currentLocation]
	mov esi,[eax]
	call printStr
	mov al,']'
	call printChar
	mov al,10
	call printChar
	ret

; compare esi with edi, set zf
streq:
	push esi
	mov ecx,-1
streq_l0:
	cmpsb
	jnz streq_l0e
	mov eax,esi
	dec eax
	cmp byte [eax],0
	jnz streq_l0
streq_l0e:
	pop esi
	ret

; read line
readLine:
	mov al,'>'
	call printChar

	mov ecx,lineBuf
readLine_l0:
	mov eax,3
	mov ebx,2
	mov edx,1
	int 80h

	cmp ecx,lineBuf+99
	jz readLine_l0e
	mov al,[ecx]
	cmp al,9
	jz readLine_l0n
	cmp al,31
	jb readLine_l0e
readLine_l0n:
	inc ecx
	jmp readLine_l0
readLine_l0e:

	mov esi,lineBuf
	mov edi,lineBuf
readLine_l1:
	lodsb
	or al,al
	jz readLine_l1e
	cmp al,'A'
	jb readLine_l1n
	cmp al,'Z'
	ja readLine_l1n
	add al,20h
readLine_l1n:
	stosb
	jmp readLine_l1
readLine_l1e:

	mov byte [ecx],0
	mov dword [nextWord],lineBuf
	ret

; read next word into edi
getNext:
	push edi
	mov edi,[nextWord]
	mov al,33
getNext_l0:
	scasb
	jb getNext_l0

	mov ecx,edi
	pop edi
	sub ecx,[nextWord]
	dec ecx
	jnz getNext_NZ

	mov al,0
	stosb
	ret

getNext_NZ:
	mov esi,[nextWord]
	rep movsb
	mov al,0
	stosb

	lodsb
	or al,al
	jnz getNext_neol
	dec esi
getNext_neol:
	mov [nextWord],esi

	ret

; print char in al
printChar:
	mov [cbuf],al
	mov eax,4
	mov ebx,1
	mov ecx,cbuf
	mov edx,1
	int 80h
	ret

; print string at esi
printStr:
	mov edi,esi
	mov al,0
	mov ecx,-1
	repnz scasb

	mov eax,4
	mov ebx,1
	mov ecx,esi
	mov edx,edi
	sub edx,esi
	int 80h

	ret

section .data

welcomeMsg:
	db "-38.6 C Adventure",10
	db "An ice-cold text adventure for x86 Linux",10
	db "--",10,0
quitMsg:
	db "Bye-bye!",10,0
dontKnowMsg:
	db "You don't know how to ",0
nothingMsgP1:
	db "You can't ",0
nothingMsgP2:
	db " nothing!",10,0
noSuchThingMsg:
	db "You know of no such thing.",10,0
cantSeeThatMsg:
	db "You can't see that here.",10,0
dontHaveThatMsg:
	db "You don't have that.",10,0
alreadyHaveThatMsg:
	db "You already have that.",10,0
nothingSpecialMsg:
	db "You see nothing special about it.",10,0
youCanGoMsg:
	db "You could go ",0
orMsg:
	db " or ",0
invalidDirectionMsg:
	db "That isn't a valid direction.",10,0
noDirectionMsg:
	db "You must say which way to go.",10,0
cantGoThatWayMsg:
	db "You can't go that way.",10,0

vQuit:
	db "quit",0
vLook:
	db "look",0
vExamine:
	db "examine",0
vGo:
	db "go",0
vMove:
	db "move",0
vExit:
	db "exit",0
wAt:
	db "at",0
wAnd:
	db "and",0

dNorth:
	db "north",0
dEast:
	db "east",0
dSouth:
	db "south",0
dWest:
	db "west",0
dNortheast:
	db "northeast",0
dSoutheast:
	db "southeast",0
dNorthwest:
	db "northwest",0
dSouthwest:
	db "southwest",0
dUp:
	db "up",0
dDown:
	db "down",0

directions:
	dd dNorth,dEast,dSouth,dWest
	dd dNortheast,dSoutheast,dNorthwest,dSouthwest
	dd dUp,dDown

sdN:
	db "n",0
sdE:
	db "e",0
sdS:
	db "s",0
sdW:
	db "w",0
sdNE:
	db "ne",0
sdSE:
	db "se",0
sdNW:
	db "nw",0
sdSW:
	db "sw",0
sdU:
	db "u",0
sdD:
	db "d",0

shortDirections:
	dd sdN,sdE,sdS,sdW,sdNE,sdSE,sdNW,sdSW,sdU,sdD

currentLocation:
	dd lStartCabin

lStartCabin_title:
	db "Your Cabin",0
lStartCabin_desc:
	db "The inside of your cabin. The power is out, and it is absolutely "
	db "freezing.",0
lStartCabin:
	dd lStartCabin_title
	dd lStartCabin_desc
	db 2 ; id
        ;  n,e,s,w,       ne,se,nw,sw,u,d
	dd 0,0,0,lKitchen,0, 0, 0, 0, 0,0

lKitchen_title:
	db "Kitchen",0
lKitchen_desc:
	db "The windows of the kitchen are iced over.",0
lKitchen:
	dd lKitchen_title
	dd lKitchen_desc
	db 3
	dd 0,lStartCabin,0,0,0,0,0,0,0,0

iTorch_name:
	db "torch",0
iTorch_title:
	db "a torch",0
iTorch:
	dd iTorch_name
	dd iTorch_title
	db 2
	dd defExamine
	dd defTake
	dd defDrop

items:
	dd iTorch,0

section .bss

lineBuf:
	resb 100
cbuf:
	resb 1

verb:
	resb 100
noun:
	resb 100
noun2:
	resb 100

nextWord:
	resd 1
