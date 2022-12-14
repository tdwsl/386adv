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

FLAG_DARK equ 1
FLAG_BEENCOMFORTABLE equ 2
FLAG_SPECIAL equ 128
STATUS_LIGHT equ 1

; entry point
_start:
	cld
	mov dword [currentLocation],startCabin
	mov byte [coldResistance],0
	mov byte [temperatureScore],127
	mov word [score],0
	mov byte [status],0
	mov byte [torchBattery],20
	mov byte [cookerGas],8

	mov edi,initialBackupData
	call backup

	mov esi,.welcomeMsg
	call printStr

	mov esi,[currentLocation]
	mov esi,[esi]
	call printStr
	call look.around
	call mainLoop

	mov esi,.quitMsg
	call printStr

	; exit
	mov eax,1
	int 80h

.welcomeMsg:
	db "-38.6 C Adventure",10
	db "An ice-cold text adventure for x86 Linux",10
	db "--",10,0
.quitMsg:
	db "Stay frosty!",10,0

; main loop - read line, handle verbs, etc
mainLoop:
	call readLine

	mov edi,verb
	call getNext
	mov esi,verb

	mov al,[esi]
	or al,al
	jz mainLoop

	push mainLoop
	push update

	; verbs
	mov edi,.quit
	call streq
	jz quit
	mov edi,.q
	call streq
	jz quit
	mov edi,.restart
	call streq
	jz restart
	mov edi,.r
	call streq
	jz restart
	mov edi,.look
	call streq
	jz look
	mov edi,.l
	call streq
	jz look
	mov edi,.examine
	call streq
	jz examine
	mov edi,.read
	call streq
	jz examine
	mov edi,.search
	call streq
	jz examine
	mov edi,.check
	call streq
	jz examine
	mov edi,.go
	call streq
	jz go
	mov edi,.move
	call streq
	jz go
	mov edi,.exit
	call streq
	jz go
	mov edi,.take
	call streq
	jz take
	mov edi,.pick
	call streq
	jz pick
	mov edi,.turn
	call streq
	jz turn
	mov edi,.switch
	call streq
	jz turn
	mov edi,.drop
	call streq
	jz drop
	mov edi,.wait
	call streq
	jz passTime
	mov edi,.open
	call streq
	jz open
	mov edi,.close
	call streq
	jz close
	mov edi,.put
	call streq
	jz put
	mov edi,.inventory
	call streq
	jz takeInventory
	mov edi,.i
	call streq
	jz takeInventory
	mov edi,.score
	call streq
	jz currentScore

	; directions
	call findDirection
	jz .notDir
	jmp go.validDirection
.notDir:

	add esp,8

	call dontKnow
	jmp mainLoop

.quit:
	db "quit",0
.q:
	db "q",0
.restart:
	db "restart",0
.r:
	db "r",0
.look:
	db "look",0
.l:
	db "l",0
.examine:
	db "examine",0
.read:
	db "read",0
.search:
	db "search",0
.check:
	db "check",0
.go:
	db "go",0
.move:
	db "move",0
.exit:
	db "exit",0
.take:
	db "take",0
.pick:
	db "pick",0
.drop:
	db "drop",0
.turn:
	db "turn",0
.switch:
	db "switch",0
.wait:
	db "wait",0
.open:
	db "open",0
.close:
	db "close",0
.put:
	db "put",0
.inventory:
	db "inventory",0
.i:
	db "i",0
.score:
	db "score",0

dontKnow: ; "You don't know how to [verb]."
	mov esi,.msg
	call printStr
	mov esi,verb
	call printStr
	mov al,'.'
	call printChar
	mov al,10
	call printChar

	ret
.msg:
	db "You don't know how to ",0

finalScore:
	mov esi,.msg1
	call printStr
	mov ax,[score]
	cwde
	call printNum
	mov esi,.msg2
	call printStr
	ret
.msg1:
	db "Your final score is ",0
.msg2:
	db " points.",10,0

quit:
	add esp,8
	jmp finalScore

victory:
	mov esi,.msg
	call printStr
	add esp,8
	jmp finalScore
.msg:
	db "You win!!!",10,0

restart:
	mov esi,.msg
	call printStr
	mov esi,initialBackupData
	call restore

	mov esi,[currentLocation]
	mov esi,[esi]
	call printStr
	call look.around

	ret
.msg:
	db "Restarting...",10,0

noNoun: ; "You can't [verb] nothing!"
	mov esi,.msgP1
	call printStr
	mov esi,verb
	call printStr

	mov al,[noun]
	or al,al
	jz .0

	mov al,' '
	call printChar
	mov esi,noun
	call printStr
.0:
	mov esi,.msgP2
	call printStr
	ret
.msgP1:
	db "You can't ",0
.msgP2:
	db " nothing!",10,0

noSuchThing: ; "[noun]? What's that?"
	cmp byte [noun],'a'
	jb .0
	cmp byte [noun],'z'
	ja .0
	sub byte [noun],20h
.0:
	mov esi,noun
	call printStr
	mov esi,.msg
	call printStr
	ret
.msg:
	db "? What's that?",10,0

cantSeeThat: ; "You can't see that here."
	mov esi,.msg
	call printStr
	ret
.msg:
	db "You can't see that here.",10,0

dontHaveThat: ; "You don't have that."
	mov esi,.msg
	call printStr
	ret
.msg:
	db "You don't have that.",10,0

alreadyHaveThat: ; "You already have that."
	mov esi,.msg
	call printStr
	ret
.msg:
	db "You already have that.",10,0

; called after every turn
update:
	; torch

	mov al,[status]
	and al,STATUS_LIGHT
	jz .torchOff
	dec byte [torchBattery]
	jnz .torchOff
	mov esi,.torchMsg
	call printStr
	xor byte [status],STATUS_LIGHT
.torchOff:

	; cold

	mov eax,[currentLocation]
	add eax,10
	mov al,[eax]
	add al,[coldResistance]
	cmp al,128
	jb .restore

	add byte [temperatureScore],al
	cmp byte [temperatureScore],128
	jb .alive

	mov esi,.freezeMsg
	call printStr
	jmp gameOver

.alive:
	cmp byte [temperatureScore],40
	ja .notTooBad
	mov esi,.veryColdMsg
	call printStr
	jmp .noRestore

.notTooBad:
	cmp byte [temperatureScore],80
	ja .noRestore
	mov esi,.drowsyMsg
	call printStr
	jmp .noRestore

.restore:
	mov byte [temperatureScore],127

	mov edx,[currentLocation]
	add edx,9
	mov al,FLAG_BEENCOMFORTABLE
	and al,[edx]
	jnz .noRestore

	or byte [edx],FLAG_BEENCOMFORTABLE
	add word [score],7
.noRestore:

	; cooker

	mov al,[kitchen+9]
	and al,FLAG_SPECIAL
	jz .noCooker

	dec byte [cookerGas]
	jnz .noCooker

	call cookerTurnOff.0
	mov eax,[currentLocation]
	mov al,[eax+8]
	cmp al,[cooker+8]
	jnz .noCooker

	mov esi,.cookerMsg
	call printStr

.noCooker:

	ret

.torchMsg:
	db "The torch dies.",10,0
.drowsyMsg:
	db "You feel tired.",10,0
.veryColdMsg:
	db "It's so cold...",10,0
.freezeMsg:
	db "You collapse. You feel so tired.",10
	db "The cold sets in, and you slowly drift away...",10,0
.cookerMsg:
	db "The cooker runs out of gas.",10,0

; end the game
gameOver:
	mov esi,.msg1
	call printStr

	call finalScore

.l0:
	mov esi,.msg2
	call printStr

	call readLine
	mov edi,noun
	call getNext
	mov esi,noun

	mov edi,mainLoop.quit
	call streq
	jz .quit
	mov edi,mainLoop.q
	call streq
	jz .quit
	mov edi,mainLoop.restart
	call streq
	jz restart
	mov edi,mainLoop.r
	call streq
	jz restart

	jmp .l0

.quit:
	add esp,4
	ret

.msg1:
	db "Game Over",10,0
.msg2:
	db "You could RESTART, or QUIT.",10,0

currentScore:
	mov esi,.msg1
	call printStr
	mov ax,[score]
	cwde
	call printNum
	mov esi,.msg2
	call printStr
	ret
.msg1:
	db "Your current score is ",0
.msg2:
	db " points.",10,0

; get the next noun and verify it
getItem:
	push .e

	mov edi,noun
	call getNext
	mov al,[noun]
	or al,al
	jz noNoun

	mov esi,noun
	call findItem
	or eax,eax
	jz noSuchThing

	call itemIsHere
	jnz cantSeeThat

.e:
	add esp,4
	ret

takeInventory:
	mov dl,1
	call countItems
	or ecx,ecx
	jz .z

	push ecx
	mov esi,.msg1
	call printStr
	pop ecx
	mov dl,1

	call listItems

	mov esi,.msg2
	jmp printStr

.z:
	mov esi,.msgZ
	jmp printStr

.msg1:
	db "You have ",0
.msg2:
	db ".",10,0
.msgZ:
	db "You don't have anything.",10,0

; put x in y
put:
	mov edi,noun
	call getNext
	mov al,[noun]
	or al,al
	jnz .0

	mov esi,.nothingNothingMsg
	jmp printStr

.0:
	mov esi,noun
	call findItem
	or eax,eax
	jz noSuchThing

	call itemIsHere
	jnz cantSeeThat

	mov [noun2],eax ; temp storage

	mov edi,noun
	call getNext
	mov esi,noun
	mov edi,look.inStr
	call streq
	jz .1

	mov esi,.noInMsg
	jmp printStr

.1:
	mov edi,noun
	call getNext
	mov al,[noun]
	or al,al
	jnz .2

	mov esi,.whatMsg
	jmp printStr

.2:
	mov esi,noun
	call findItem
	or eax,eax
	jz noSuchThing

	call itemIsHere
	jnz cantSeeThat

	; call

	mov ebx,[noun2]
	mov edx,eax
	add edx,9+4*7
	jmp [edx]

.nothingNothingMsg:
	db "You can't put nothing in nothing!",10,0
.noInMsg:
	db "You could try putting something IN something...",0
.whatMsg:
	db "You can't put it in nothing!",10,0

open:
	call getItem
	add eax,9+4*5
	jmp [eax]

close:
	call getItem
	add eax,9+4*6
	jmp [eax]

passTime:
	mov esi,.msg
	call printStr
	ret
.msg:
	db "You wait.",10,0

drop:
	call getItem
	mov ebx,eax
	add ebx,9+4*2
	jmp [ebx]

turn:
	mov edi,noun
	call getNext
	mov esi,noun
	mov edi,.offStr
	call streq
	jz .0
	mov edi,.onStr
	call streq
	jz .0

	mov esi,.msg1
	jmp printStr

.0:
	mov esi,noun
	mov edi,.offStr
	call streq

	pushfd
	mov edi,noun2
	call getNext
	mov al,[noun2]
	or al,al
	pop ebx
	jz noNoun

	push ebx
	mov esi,noun2
	mov edi,noun
	call strcpy
	pop ebx
	mov [noun2],ebx

	mov esi,noun
	call findItem
	or eax,eax
	jz noSuchThing

	call itemIsHere
	jnz cantSeeThat

	mov ebx,eax
	add ebx,9+4*3
	push dword [noun2]
	popfd
	jnz .on
	add ebx,4
.on:
	jmp [ebx]

.msg1:
	db "You could try turning something ON or OFF...",10,0
.offStr:
	db "off",0
.onStr:
	db "on",0

examine:
	mov edi,noun
	call getNext
	mov al,[noun]
	or al,al
	jz noNoun
.0:

	mov esi,noun
	call findItem
	or eax,eax
	jz noSuchThing

	call itemIsHere
	jnz cantSeeThat

	mov edx,eax
	add edx,9
	call [edx]

	ret

look:
	; look at
	mov edi,noun2
	call getNext
	mov esi,noun2
	mov edi,.atStr
	call streq
	jz .at
	mov edi,.inStr
	call streq
	jz .at
	mov edi,.insideStr
	call streq
	jz .at

	jmp .around

.at:
	mov edi,noun
	call getNext
	mov al,[noun]
	or al,al
	jnz examine.0

	mov edi,noun
	mov esi,noun2
	call strcpy
	jmp noNoun

.around:
	mov eax,[currentLocation]
	mov ebx,eax
	add ebx,9
	mov bl,[ebx]
	and bl,FLAG_DARK
	jz .notDark
	mov bl,[status]
	and bl,STATUS_LIGHT
	jnz .notDark

	mov esi,.darkMsg
	call printStr
	jmp .noItems

.notDark:

	; print desc
	mov ebx,eax
	add ebx,4
	mov esi,[ebx]
	call printStr

	; list items
	mov eax,[currentLocation]
	add eax,8
	mov dl,[eax]
	call countItems
	or ecx,ecx
	jz .noItems

	pusha
	mov esi,.itemMsgP1
	call printStr
	popa
	call listItems
	mov esi,.itemMsgP2
	call printStr

.noItems:

	; count directions
	mov ecx,10
	mov edx,0
	mov esi,[currentLocation]
	add esi,11
.l0:
	lodsd
	or eax,eax
	jz .l0z
	inc edx
.l0z:
	loop .l0

	or dl,dl
	jz .noexit

	; print directions

	pusha
	mov esi,.goMsg
	call printStr
	popa

	mov ecx,10
	mov esi,[currentLocation]
	add esi,11
.l1:
	lodsd
	or eax,eax
	jz .l1n

	pusha
	mov eax,10
	sub eax,ecx
	shl eax,2
	add eax,findDirection.directions
	mov esi,[eax]
	call printStr
	popa

	dec edx
	jz .l1n
	cmp edx,1
	jz .l1and

	pusha
	mov al,','
	call printChar
	mov al,' '
	call printChar
	popa

	jmp .l1n

.l1and:
	pusha
	mov esi,.orMsg
	call printStr
	popa

.l1n:
	loop .l1

	mov al,'.'
	call printChar
	mov al,10
	call printChar

.noexit:
	ret

.itemMsgP1:
	db "There is ",0
.itemMsgP2:
	db " here.",10,0
.orMsg:
	db " or ",0
.goMsg:
	db "You could go ",0
.darkMsg:
	db "It's dark in here - you can't see a thing.",10,0
.atStr:
	db "at",0
.inStr:
	db "in",0
.insideStr:
	db "inside",0

go:
	mov edi,noun
	call getNext
	mov al,[noun]
	or al,al
	jnz .hasDirection

	mov esi,.noDirMsg
	call printStr
	ret

.hasDirection:
	mov esi,noun
	call findDirection
	jnz .validDirection

	mov esi,.invalidMsg
	call printStr
	ret

.validDirection:
	shl eax,2
	add eax,[currentLocation]
	add eax,11
	mov dl,[eax]
	or dl,dl
	jnz .canGo

	mov esi,.noCanDoMsg
	call printStr
	ret

.canGo:
	mov eax,[eax]
	mov dword [currentLocation],eax
	mov esi,[currentLocation]
	mov esi,[esi]
	call printStr
	ret

.invalidMsg:
	db "That isn't a valid direction.",10,0
.noDirMsg:
	db "You must specify which way to go.",10,0
.noCanDoMsg:
	db "You can't go that way.",10,0

take:
	mov edi,noun
	call getNext
	mov al,[noun]
	or al,al
	jz noNoun

	mov esi,noun
	mov edi,mainLoop.inventory
	call streq
	jz takeInventory

.0:
	mov esi,noun
	call findItem
	or eax,eax
	jz noSuchThing

	call itemIsHere
	jnz cantSeeThat

	mov ebx,eax
	add ebx,9+4*1
	jmp [ebx]

pick:
	mov edi,noun
	call getNext
	mov esi,noun
	mov edi,findDirection.up
	call streq
	jnz .notUp

	mov edi,noun2
	call getNext
	mov al,[noun2]
	or al,al
	jz noNoun

	mov esi,noun2
	mov edi,noun
	call strcpy
	jmp take.0

.notUp:
	mov esi,.notUpMsg
	call printStr
	ret

.notUpMsg:
	db "You could pick something UP...",10,0

; load direction index into eax
findDirection:
	mov edi,esi
	mov ecx,10
	mov esi,.directions
	mov dl,0
.l0:
	lodsd
	pusha
	mov esi,eax
	call streq
	popa
	jz .l0e
	loop .l0
.l0e:
	mov eax,10
	sub eax,ecx
	cmp eax,10
	jnz .end

	or dl,dl
	jz .again
	cmp eax,10
.end:
	ret

.again:
	inc dl
	mov ecx,10
	mov esi,.shortDirs
	jmp .l0

.north: db "north",0
.east: db "east",0
.south: db "south",0
.west: db "west",0
.northeast: db "northeast",0
.southeast: db "southeast",0
.northwest: db "northwest",0
.southwest: db "southwest",0
.up: db "up",0
.down: db "down",0
.n: db "n",0
.e: db "e",0
.s: db "s",0
.w: db "w",0
.ne: db "ne",0
.se: db "se",0
.nw: db "nw",0
.sw: db "sw",0
.u: db "u",0
.d: db "d",0
.directions:
	dd .north,.east,.south,.west
	dd .northeast,.southeast,.northwest,.southwest
	dd .up,.down
.shortDirs:
	dd .n,.e,.s,.w,.ne,.se,.nw,.sw,.u,.d

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
	jnz .0
	ret
.0:
	mov edx,[currentLocation]
	add edx,9
	mov dl,[edx]
	and dl,FLAG_DARK
	jz .1
	mov dl,[status]
	and dl,STATUS_LIGHT
	jnz .1
	ret
.1:
	mov edx,[currentLocation]
	add edx,8
	mov bh,[edx]
	cmp bh,bl
	jnz .2
	ret

.2:
	mov esi,containers
	push eax
.l0:
	lodsd
	or eax,eax
	jz .l0e

	mov dx,[eax]
	cmp dh,bh
	jnz .l0
	cmp dl,bl
	jnz .l0

	pop eax
	ret
.l0e:
	pop eax
	cmp esi,0
	ret

; load ptr to item where name=esi into eax
findItem:
	mov edi,esi
	mov esi,items
.l0:
	lodsd
	or eax,eax
	jz .e

	push edi
	push esi
	push eax
	mov esi,[eax]
	call streq
	pop eax
	pop esi
	pop edi
	jnz .l0
.e:
	ret

;;;; START ITEM VERBS ;;;;

defExamine:
	mov esi,.msg
	call printStr
	ret
.msg:
	db "You see nothing special about it.",10,0

defTake:
	call hasItem
	jz alreadyHaveThat

	add eax,8
	mov byte [eax],1
	mov esi,.msg
	call printStr
	ret
.msg:
	db "Taken.",10,0

defDrop:
	call hasItem
	jnz dontHaveThat

	mov ebx,[currentLocation]
	add ebx,8
	mov bl,[ebx]
	add eax,8
	mov [eax],bl

	mov esi,.msg
	call printStr
	ret
.msg:
	db "Done.",10,0

cantTake:
	mov esi,.msg
	call printStr
	ret
.msg:
	db "You can't take that!",10,0

cantOpen:
	mov esi,.msg
	call printStr
	ret
.msg:
	db "You can't open that!",10,0

cantClose:
	mov esi,.msg
	call printStr
	ret
.msg:
	db "You can't close that!",10,0

cantTurnOn:
	mov esi,.msg
	call printStr
	ret
.msg:
	db "You can't turn that on!",10,0

cantTurnOff:
	mov esi,.msg
	call printStr
	ret
.msg:
	db "You can't turn that off!",10,0

cantPut:
	mov esi,.msg
	call printStr
	ret
.msg:
	db "You can't put something in that!",10,0

takeClothing:
	push esi
	call hasItem
	pop esi
	jz alreadyHaveThat

	pusha
	call printStr
	popa

	add byte [coldResistance],dl
	jmp defTake

dropClothing:
	push esi
	call hasItem
	pop esi
	jnz dontHaveThat

	pusha
	call printStr
	popa

	sub byte [coldResistance],dl
	jmp defDrop

coatTake:
	mov dl,21
	mov esi,.msg
	jmp takeClothing
.msg:
	db "You put the coat on. You feel warmer.",10,0

coatDrop:
	mov dl,21
	mov esi,.msg
	jmp dropClothing
.msg:
	db "It feels colder without the coat.",10,0

hatTake:
	mov dl,12
	mov esi,.msg
	jmp takeClothing
.msg:
	db "Now your head is nice and warm.",10,0

hatDrop:
	mov dl,12
	mov esi,.msg
	jmp dropClothing
.msg:
	db "You take of the hat. Brrr.",10,0

torchTurnOn:
	call hasItem
	jnz dontHaveThat

	mov al,[torchBattery]
	or al,al
	jnz .notDead
	mov esi,.deadMsg
	call printStr
	ret

.notDead:
	mov al,[status]
	and al,STATUS_LIGHT
	jz .notOn
	mov esi,.alreadyMsg
	call printStr
	ret

.notOn:
	or byte [status],STATUS_LIGHT
	mov esi,.msg
	call printStr
	ret
.msg:
	db "You turn the torch on.",10,0
.deadMsg:
	db "It's dead.",10,0
.alreadyMsg:
	db "It's already on.",10,0

torchTurnOff:
	call hasItem
	jnz dontHaveThat

	mov al,[status]
	and al,STATUS_LIGHT
	jnz .notOff
	mov esi,.alreadyMsg
	call printStr
	ret

.notOff:
	xor byte [status],STATUS_LIGHT
	mov esi,.msg
	call printStr
	ret
.msg:
	db "You turn the torch off.",10,0
.alreadyMsg:
	db "It's already off.",10,0

torchDrop:
	call defDrop
	xor byte [status],STATUS_LIGHT
	ret

; open container at eax
openContainer:
	inc eax
	mov ebx,[currentLocation]
	add ebx,8
	mov bl,[ebx]
	cmp [eax],bl
	jz .already

	mov [eax],bl
	mov esi,.msg
	call printStr
	ret
.already:
	mov esi,.alreadyMsg
	call printStr
	ret
.msg:
	db "Open.",10,0
.alreadyMsg:
	db "It's already open.",10,0

; close container at eax
closeContainer:
	inc eax
	mov ebx,[currentLocation]
	add ebx,8
	mov bl,[ebx]
	cmp [eax],bl
	jnz .already

	mov byte [eax],0
	mov esi,.msg
	call printStr
	ret
.already:
	mov esi,.alreadyMsg
	call printStr
	ret
.msg:
	db "Closed.",10,0
.alreadyMsg:
	db "It's already closed.",10,0

; list items in a container
examineContainer:
	mov dl,[eax]
	inc eax
	mov dh,[eax]
	mov ebx,[currentLocation]
	add ebx,8
	cmp dh,[ebx]
	jnz .closed

	call countItems
	or ecx,ecx
	jz .empty

	pusha
	mov esi,.msgP1
	call printStr
	popa

	call listItems
	mov al,'.'
	call printChar
	mov al,10
	call printChar
	ret

.closed:
	mov esi,.closedMsg
	call printStr
	ret

.empty:
	mov esi,.emptyMsg
	call printStr
	ret

.msgP1:
	db "Inside is ",0
.closedMsg:
	db "It's closed.",10,0
.emptyMsg:
	db "It's empty.",10,0

; put ebx in container eax
putContainer:
	mov [noun2],eax
	mov eax,ebx
	call hasItem
	jnz dontHaveThat

	mov ebx,eax
	mov eax,[noun2]

	; check if open
	inc eax
	mov al,[eax]
	mov edx,[currentLocation]
	add edx,8
	mov dl,[edx]
	cmp al,dl
	jz .0
	cmp al,1
	jnz examineContainer.closed

.0:
	mov eax,[noun2]

	; drop
	mov eax,ebx
	add ebx,9+4*2
	push eax
	call [ebx]
	pop ebx
	mov eax,[noun2]

	; put
	add ebx,8
	mov al,[eax]
	mov [ebx],al

	ret

drawerOpen:
	mov eax,drawerContainer
	jmp openContainer

drawerClose:
	mov eax,drawerContainer
	jmp closeContainer

drawerExamine:
	mov eax,drawerContainer
	jmp examineContainer

drawerPut:
	mov eax,drawerContainer
	call putContainer

	mov al,[drawerContainer]
	mov dl,[hat+8]
	cmp al,dl
	jz victory

	ret

cookerTurnOn:
	mov al,[kitchen+9]
	and al,FLAG_SPECIAL
	jnz .already

	mov al,[cookerGas]
	or al,al
	jz .z

	add byte [kitchen+10],30

	or byte [kitchen+9],FLAG_SPECIAL
	mov esi,.msg
	jmp printStr

.z:
	mov esi,.msgZ
	jmp printStr

.already:
	mov esi,.alreadyMsg
	jmp printStr

.msg:
	db "The cooker heats up the room.",10,0
.msgZ:
	db "It's out of gas.",10,0
.alreadyMsg:
	db "It's already on.",10,0

cookerTurnOff:
	mov al,[kitchen+9]
	and al,FLAG_SPECIAL
	jz .not

	mov esi,.msg
	call printStr
.0:
	xor byte [kitchen+9],FLAG_SPECIAL
	sub byte [kitchen+10],30
	ret

.not:
	mov esi,.notMsg
	jmp printStr

.msg:
	db "You turn the cooker off.",10,0
.notMsg:
	db "It's already off.",10,0

bodyExamine:
	mov esi,.msg
	call printStr

	mov dl,[bodyContainer]
	call countItems
	or ecx,ecx
	jz .z

	pusha
	mov esi,.exMsg
	call printStr
	popa
	call listItems
	mov al,'.'
	call printChar
	mov al,10
	jmp printChar

.z:
	mov esi,.nothingMsg
	jmp printStr

.msg:
	db "You take a close look at the dead body... Ick.",10,0
.nothingMsg:
	db "They have nothing on them.",10,0
.exMsg:
	db "On their person is ",0

thermometerExamine:
	mov esi,.msg1
	call printStr
	mov eax,[currentLocation]
	add eax,10
	mov al,[eax]
	cbw
	cwde
	call printNum
	mov esi,.msg2
	jmp printStr
.msg1:
	db "It reads ",0
.msg2:
	db " degrees C.",10,0

noteExamine:
	mov esi,.msg
	jmp printStr
.msg:
	db "The note reads:",10
	db '"Sadly, this game is unfinished. To win, put the hat in the '
	db 'drawer."',10
	db "How strange.",10,0

;;;; END ITEM VERBS  ;;;;

; backup data to edi
backup:
	mov esi,dataBackupStart
	mov ecx,(dataBackupEnd-dataBackupStart)/4
	rep movsd
	mov esi,bssBackupStart
	mov ecx,bssBackupEnd-bssBackupStart
	rep movsb
	ret

; restore data from esi
restore:
	mov edi,dataBackupStart
	mov ecx,(dataBackupEnd-dataBackupStart)/4
	rep movsd
	mov edi,bssBackupStart
	mov ecx,bssBackupEnd-bssBackupStart
	rep movsb
	ret

; count items at location dl with ecx
countItems:
	mov ecx,0
	mov esi,items
.l0:
	lodsd
	or eax,eax
	jz .l0e

	add eax,8
	mov al,[eax]
	cmp al,dl
	jnz .l0
	inc ecx
	jmp .l0

.l0e:
	ret

; list n=ecx items at location dl
listItems:
	mov esi,items
	mov dh,1

.l0:
	lodsd
	or eax,eax
	jz .l0e
	mov ebx,eax
	add ebx,8
	mov bl,[ebx]
	cmp bl,dl
	jnz .l0

	add eax,4
	pusha
	mov esi,[eax]
	call printStr
	popa

	cmp ecx,2
	jz .l0and
	jb .l0next

	pusha
	mov al,','
	call printChar
	mov al,' '
	call printChar
	popa
	inc dh
	jmp .l0next

.l0and:
	pusha
	mov esi,.andSep
	call printStr
	popa
	inc dh

.l0next:
	cmp dh,4
	jnz .l0next0
	cmp ecx,1
	jz .l0next0

	mov dh,0
	pusha
	mov al,10
	call printChar
	popa
.l0next0:
	loop .l0

.l0e:
	ret

.andSep:
	db " and ",0

; copy null-terminated str in esi to edi
strcpy:
	movsb
	mov al,[esi]
	or al,al
	jnz strcpy
	stosb
	ret

; compare esi with edi
streq:
	push esi
	mov ecx,-1
.l0:
	cmpsb
	jnz .l0e
	mov eax,esi
	dec eax
	cmp byte [eax],0
	jnz .l0
.l0e:
	pop esi
	ret

; read line
readLine:
	mov al,'>'
	call printChar

	mov ecx,lineBuf
.l0:
	mov eax,3
	mov ebx,2
	mov edx,1
	int 80h

	cmp ecx,lineBuf+99
	jz .l0e
	mov al,[ecx]
	cmp al,9
	jz .l0n
	cmp al,31
	jb .l0e
.l0n:
	inc ecx
	jmp .l0
.l0e:

	mov esi,lineBuf
	mov edi,lineBuf
.l1:
	lodsb
	or al,al
	jz .l1e
	cmp al,'A'
	jb .l1n
	cmp al,'Z'
	ja .l1n
	add al,20h
.l1n:
	stosb
	jmp .l1
.l1e:

	mov byte [ecx],0
	mov esi,lineBuf
.l2:
	lodsb
	or al,al
	jz .l2e
	cmp al,33
	jb .l2
.l2e:
	dec esi

	mov [nextWord],esi
	ret

; read next word into edi
getNext:
	push edi
	mov edi,[nextWord]
	mov al,33
.l0:
	scasb
	jb .l0

	mov ecx,edi
	pop edi
	sub ecx,[nextWord]
	dec ecx
	jnz .NZ

	mov al,0
	stosb
	ret

.NZ:
	mov esi,[nextWord]
	rep movsb
	mov al,0
	stosb

	lodsb
	or al,al
	jz .eol

.l1:
	lodsb
	or al,al
	jz .l1e
	cmp al,33
	jb .l1
.l1e:
	dec esi
	jmp .neol
.eol:
	dec esi
.neol:
	mov [nextWord],esi

	ret

; print number in eax
printNum:
	push eax
	and eax,80000000h
	pop eax
	jz .pos

	neg eax
	push eax
	mov al,'-'
	call printChar
	pop eax
.pos:

	mov edi,buf
	mov ebx,10
.l0:
	mov edx,0
	div ebx

	push ax
	mov al,dl
	add al,'0'
	stosb
	pop ax

	or eax,eax
	jnz .l0

	mov ecx,edi
	sub ecx,buf
	mov esi,edi
	dec esi
	std
.l2:
	lodsb
	pusha
	call printChar
	popa
	loop .l2

	cld
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

align 4
dataBackupStart:

startCabin_title:
	db "Your Cabin",10,0
startCabin_desc:
	db "The inside of your cabin. The power is out, and it is absolutely "
	db "freezing.",10,0
startCabin:
	dd startCabin_title
	dd startCabin_desc
	db 2 ; id
	db 0 ; flags
	db -20 ; temperature
        ;  n,            e,     s,w,      ne,se,nw,sw,u,d
	dd outsideCabins,closet,0,kitchen,0, 0, 0, 0, 0,0

kitchen_title:
	db "Kitchen",10,0
kitchen_desc:
	db "The windows of the kitchen are iced over.",10,0
kitchen:
	dd kitchen_title
	dd kitchen_desc
	db 3
	db 0
	db -25
	dd 0,startCabin,0,0,0,0,0,0,0,0

closet_title:
	db "Closet",10,0
closet_desc:
	db "The closet is quite small, with wood-panel walling. You can feel "
	db "a draft.",10,0
closet:
	dd closet_title
	dd closet_desc
	db 4
	db FLAG_DARK
	db -20
	dd 0,0,0,startCabin,0,0,0,0,0,0

outsideCabins_title:
	db "Outside",10,0
outsideCabins_desc:
	db "A clearing in the woods. The dirt is frozen dry.",10
	db "Around you are some cabins, but it looks like everyone has "
	db "gone.",10,0
outsideCabins:
	dd outsideCabins_title
	dd outsideCabins_desc
	db 6
	db 0
	db -39
	dd 0,smallCabin,startCabin,0,dirtPath,0,0,0,0,0

smallCabin_title:
	db "Tiny Cabin",10,0
smallCabin_desc:
	db "The cabin is small and dusty. It seems that not everyone got out."
	db 10,0
smallCabin:
	dd smallCabin_title
	dd smallCabin_desc
	db 7
	db FLAG_DARK
	db -25
	dd 0,0,0,outsideCabins,0,0,0,0,0,0

dirtPath_title:
	db "Dirt Path",10,0
dirtPath_desc:
	db "A winding dirt path.",10
	db "Abruptly, it reaches a dead end, as if whoever designed it just "
	db "gave up.",10,0
dirtPath:
	dd dirtPath_title
	dd dirtPath_desc
	db 9
	db 0
	db -38
	dd 0,0,0,0,0,0,0,outsideCabins,0,0

torch_name:
	db "torch",0
torch_title:
	db "a torch",0
torch:
	dd torch_name
	dd torch_title
	db 5
	dd defExamine
	dd defTake
	dd torchDrop
	dd torchTurnOn
	dd torchTurnOff
	dd cantOpen
	dd cantClose
	dd cantPut

coat_name:
	db "coat",0
coat_title:
	db "a coat",0
coat:
	dd coat_name
	dd coat_title
	db 4
	dd defExamine
	dd coatTake
	dd coatDrop
	dd cantTurnOn
	dd cantTurnOff
	dd cantOpen
	dd cantClose
	dd cantPut

drawerContainer:
	db 5 ; container id (overlaps with room id)
	db 0 ; current room id

drawer_name:
	db "drawer",0
drawer_title:
	db "a wooden drawer",0
drawer:
	dd drawer_name
	dd drawer_title
	db 3
	dd drawerExamine
	dd cantTake
	dd defDrop
	dd cantTurnOn
	dd cantTurnOff
	dd drawerOpen
	dd drawerClose
	dd drawerPut

cooker_name:
	db "cooker",0
cooker_title:
	db "a gas cooker",0
cooker:
	dd cooker_name
	dd cooker_title
	db 3
	dd defExamine
	dd cantTake
	dd defDrop
	dd cookerTurnOn
	dd cookerTurnOff
	dd cantOpen
	dd cantClose
	dd cantPut

bodyContainer:
	db 8
	db 7

body_name:
	db "body",0
body_title:
	db "a dead body",0
body:
	dd body_name
	dd body_title
	db 7
	dd bodyExamine
	dd cantTake
	dd defDrop
	dd cantTurnOn
	dd cantTurnOff
	dd cantOpen
	dd cantClose
	dd cantPut

thermometer_name:
	db "thermometer",0
thermometer_title:
	db "a thermometer",0
thermometer:
	dd thermometer_name
	dd thermometer_title
	db 8
	dd thermometerExamine
	dd defTake
	dd defDrop
	dd cantTurnOn
	dd cantTurnOff
	dd cantOpen
	dd cantClose
	dd cantPut

hat_name:
	db "hat",0
hat_title:
	db "a wooly hat",0
hat:
	dd hat_name
	dd hat_title
	db 8
	dd defExamine
	dd hatTake
	dd hatDrop
	dd cantTurnOn
	dd cantTurnOff
	dd cantOpen
	dd cantClose
	dd cantPut

note_name:
	db "note",0
note_title:
	db "a note",0
note:
	dd note_name
	dd note_title
	db 9
	dd noteExamine
	dd defTake
	dd defDrop
	dd cantTurnOn
	dd cantTurnOff
	dd cantOpen
	dd cantClose
	dd cantPut

align 4
dataBackupEnd:

items:
	dd torch,coat,drawer,cooker,body,thermometer,hat,note,0

containers:
	dd drawerContainer,bodyContainer,0

section .bss

bssBackupStart:

currentLocation:
	resd 1
temperatureScore:
	resb 1
coldResistance:
	resb 1
status:
	resb 1
score:
	resw 1
torchBattery:
	resb 1
cookerGas:
	resb 1

bssBackupEnd:

lineBuf:
	resb 100
cbuf:
	resb 1
buf:
	resb 100

verb:
	resb 100
noun:
	resb 100
noun2:
	resb 100

nextWord:
	resd 1

backupSize equ dataBackupEnd-dataBackupStart+bssBackupEnd-bssBackupStart
;backupData:
;	resb backupSize
initialBackupData:
	resb backupSize
