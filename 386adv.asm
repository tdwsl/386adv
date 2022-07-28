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
	call mainLoop_look

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

	; invalid verb
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

mainLoop_look:
	mov eax,[currentLocation]
	mov ebx,eax
	add ebx,4
	mov esi,[ebx]
	call printStr
	mov al,10
	call printChar
	jmp mainLoop

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
streq_L0:
	cmpsb
	jnz streq_L0e
	mov eax,esi
	dec eax
	cmp byte [eax],0
	jnz streq_L0
streq_L0e:
	pop esi
	ret

; read line
readLine:
	mov al,'>'
	call printChar

	mov ecx,lineBuf
readLine_L0:
	mov eax,3
	mov ebx,2
	mov edx,1
	int 80h

	cmp ecx,lineBuf+99
	jz readLine_L0e
	mov al,[ecx]
	cmp al,9
	jz readLine_L0n
	cmp al,31
	jb readLine_L0e
readLine_L0n:
	inc ecx
	jmp readLine_L0
readLine_L0e:

	mov byte [ecx],0
	mov dword [nextWord],lineBuf
	ret

; read next word into edi
getNext:
	push edi
	mov edi,[nextWord]
	mov al,33
getNext_L0:
	scasb
	jb getNext_L0

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

vQuit:
	db "quit",0
vLook:
	db "look",0

currentLocation:
	dd startCabin

startCabin_name:
	db "Your Cabin",0
startCabin_desc:
	db "You are in your cabin. The power is out, and it is absolutely "
	db "freezing.",0
startCabin:
	dd startCabin_name
	dd startCabin_desc
	dd 0,0,0,0,0,0,0,0,0,0

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
