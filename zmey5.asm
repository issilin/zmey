model tiny
.code
org 100h
.386
locals


main:
	jmp start
Int_09h:
    push   ax
    push   di
    push   es
    in     al,60h    ;скан. код клавиши из РА	
	mov [si],word ptr al
	inc 	si
	cmp 	si,offset er
	jne con
	lea si,buffer
con:	 
	pop       es
    pop       di
    in        al,61h    ;ввод порта РВ
    mov       ah,al
    or        al,80h    ;установить бит "подтверждения ввода"
    out       61h,al
    xchg      ah,al     ;вывести старое значение РВ
    out       61h,al
    mov       al,20h    ;послать сигнал EOI
    out       20h,al    ;контроллеру прерываний
    pop       ax
    iret
	old09h dd 0
	
Int_08h:
	inc time
	db 0eah
	old08h dd 0
	
start:
	mov ax,3508h
	int 21h
	mov word ptr [old08h],bx
	mov word ptr [old08h+2],es
	mov ah,25h
	lea dx, Int_08h
	int 21h
	
	mov ax, 3509h
	int 21h
	mov word ptr [old09h], bx
	mov word ptr [old09h+2], es
	mov ah, 25h
	lea dx, Int_09h
	int 21h
	
	push offset coordinates
	pop es
	xor di,di
	xor ax,ax
	mov cx,2000
c1:									;обнуление массива координат
	stosw
	loop c1
	
	lea si, coordinates
	mov ax,2000
	mov [si],ax
	mov ax,1998
	mov [si+2],ax
	
	push offset map
	pop es
	xor di,di
	xor ax,ax
	mov cx,2000
c2:									;обнуляем массив дисплея
	stosw
	loop c2

	mov ax,3
	int 10h
	mov ax,0B800h
	push ax
	pop es
	
													;начальное положение змея
	xor bx,bx
	lea si,coordinates
	mov bx,[si]
	mov es:[bx],byte ptr 10
	mov bx,[si+2]
	mov es:[bx],byte ptr 10
	
	 
	mov bx,si
	add bx,2
	mov tail,bx
	lea bx,coordinates
	mov head,bx

	lea si,map									;стены
	mov cx,13
	xor bx,bx
	mov bx,158
	add si,158
wall7:
	mov [si],word ptr 1
	mov es:[bx],byte ptr 01h
	add bx,160
	add si,160
	loop wall7
	
	lea si,map
	add si,3920
	xor bx,bx
	mov bx,3920
	mov cx,40
wall4:
	mov [si],word ptr 1
	mov es:[bx],byte ptr 01h
	add bx,2
	add si,2
	loop wall4
	
	lea si,buffer	;si голова буффера
	lea di,buffer	;di хвост буфферка
	
	
cycle:						;основной цикл
	mov ax,time
	cmp ax,speed
	jge null
	jne key
null:
	mov time,0
	cmp p,word ptr 0
	je key
	call go
key:
	cmp si,di
	jne case
	jmp cycle
case:
	xor bx,bx
	mov bl,byte ptr[di]
	cmp bl,01
	je exit
	cmp bl,4Eh
	je speedplus
	cmp bl,4Ah
	je speedminus
	cmp bl,9Eh
	je left				
	cmp bl,0A0h
	je right
	cmp bl,091h
	je up
	cmp bl,09Fh
	je down
	cmp bl,048h
	je stretch
	cmp bl,050h
	je shorter
	cmp bl,0B9h
	je paus
	jmp incrementDi

paus:
	cmp p,word ptr 1
	je pausstop
	mov p,word ptr 1
	jmp incrementDi
pausstop:
	mov p,word ptr 0
	jmp incrementDi
stretch:					;удлиняем змейку
	push si di
	mov si,tail
	cmp head,si
	jg stretchplus
	mov ax,tail
	mov bx,head
	sub ax,bx
	cmp ax,2000
	jge stretch_exit
	std
	push ds
	pop es
	mov di,si
	add di,2
	mov tail,di	
c6:							;подвинем тело чтобы увеличить голову
	movsw
	cmp di,head
	je stretch_end
	jmp c6
stretchplus:				;голова в жопе можно удлинять
	mov ax,head
	mov bx,tail
	sub ax,bx
	cmp ax,1998
	jge stretch_exit
	mov si,head
	add head,2
	mov bx,[si]
	mov si,head
	mov [si],bx
stretch_end:
	call step
stretch_exit:
	pop di si
	jmp incrementDi
	
shorter:
	push si di
	mov bx,tail
	mov ax,head
	cmp ax,bx
	jg big_head
	sub bx,ax
	cmp bx,2
	jle shorter_end
	jmp big_zmey
big_head:
	sub ax,bx
	cmp ax,2
	jle shorter_end
big_zmey:
	call draw_tail
	mov si,tail
	cmp head,si
	jle longminus				;голова в жопе 
	cld 
	push ds
	pop es
	mov di,si
	add si,2
c7:
	movsw
	cmp di,head
	je new_head
	jmp c7
new_head:
	mov [di],word ptr 00h
	sub di,2
	mov head,di
	jmp shorter_end
longminus:						; жопа в жопе можно укорачивать
	mov  si,tail
	mov [si], word ptr 00h
	sub si,2
	mov tail,si
shorter_end:
	
	pop di si
	jmp incrementDi
	
speedplus:					;увеличиваем скорость
	cmp speed,word ptr 8
	je incrementDi
	dec speed
	jmp incrementDi
speedminus:						;уменьшаем скорость
	cmp speed,word ptr 20
	je incrementDi
	inc speed
	jmp incrementDi
left:						; едем влево
	mov ax,direct
	cmp ax, 2
	je incrementDi
	cmp ax,1
	jne toleft
	call xchdirect
toleft:	
	mov direct,2
	jmp incrementDi
	
right:						;вправо
	mov ax,direct
	cmp ax, 1
	je incrementDi
	cmp ax,2
	jne toright
	call xchdirect
toright:
	mov direct,1
	jmp incrementDi
	
up:							;катим вверх
	mov ax,direct
	cmp ax, 3
	je incrementDi
	cmp ax,4
	jne toup
	call xchdirect
toup:							;повернуть вверх
	mov direct,3
	jmp incrementDi
	
down:							;катим вверх
	mov ax,direct
	cmp ax, 4
	je incrementDi
	cmp ax,3
	jne todown
	call xchdirect
todown:							;повернуть вверх
	mov direct,4
	jmp incrementDi
	
	
	
	
xchdirect:						;меняем голову с хвостом
	mov ax,head
	mov bx,tail
	mov head,bx
	mov tail,ax
	mov bx,head
	mov bx,tail
	ret
	
incrementDi:
	mov [di],word ptr 0
	inc di
	cmp di,offset er
	jne jump
	lea di,buffer

jump:
	jmp cycle
	
exit:
	xor bx,bx
	mov ds,bx
	mov ax,word ptr cs:[old09h]
	mov ds:09h*4,ax
	mov ax,word ptr cs:[old09h+2]
	mov ds:09h*4+2,ax
	
	mov ax,word ptr cs:[old08h]
	mov ds:08h*4,ax
	mov ax,word ptr cs:[old08h+2]
	mov ds:08h*4+2,ax
	
	mov ax, 4c00h
    int 21h
	ret

draw_tail:				 ;отрисовываем хвост змейки
	push si di
	mov si,tail	
	cmp head,si
	jl directhead
	mov ax,head
	sub ax,tail
	jmp directtail
directhead:				
	mov ax,tail
	sub ax,head
	
directtail:
	mov bx,2
	xor dx,dx
	div bx
	sub bx,1
	mov cx,ax
	call golovojop
	mov si,tail
	mov bx,[si]
	lodsw
c5:
	lodsw
	cmp ax,bx
	je draw_tail_end
	loop c5
	
	mov ax,0B800h
	push ax
	pop es
	
	mov si,tail
	mov bx,[si]
	xor ax,ax
	mov [si],ax
	mov es:[bx],byte ptr ' '
draw_tail_end:
	pop di si
	ret
	
golovojop:							;определение направления обхода
	push si di
	mov si,tail
	cld
	cmp head,si					;если у змея голова в жопе
	jg golovojop_end
	std
golovojop_end:
	pop di si
	ret
	
go:							;перемещение змея
	push si di
	call draw_tail
	xor ax,ax
	push ds
	pop es
	
	call golovojop
	mov si,tail
	mov di,si
	xor bx,bx
	xor ax,ax
	xor dx,dx
	lodsw				
c4:	
						;перемещение тела
	movsw
	cmp di,head
	je go_end
	jmp c4
go_end:
	call step
	pop di si
	ret
step:						;перемещение головы
	push si di
	xor bx,bx
	mov si,head
	mov bx,[si]
	cmp direct,1
	je directright
	cmp direct,2
	je directleft
	cmp direct,3
	je directup
	cmp direct,4
	je directdown
directright:				;шаг вправо
	lea di,map				;врезаемся в стену
	add di,bx
	mov ax,[di+2]
	cmp ax,1
	je stepend
	add bx,2
	mov ax,bx
	push bx
	xor dx,dx
	mov bx,160
	div bx
	pop bx
	cmp dx,0
	jne stepend
	sub bx,160
	jmp stepend
	
directleft:					;шаг влево
	lea di,map				;прожираем стену
	add di,bx
	sub di,2
	mov ax,[di]
	cmp ax,1
	jne goleft
	mov [di],word ptr 0
goleft:
	push bx
	mov ax,bx
	cmp ax,bx
	mov bx,160
	xor dx,dx
	div bx
	pop bx
	cmp dx,0
	jne glft
	add bx,160
glft:
	sub bx,2
	jmp stepend
directup:					;шаг вверх
	lea di,map
	add di,bx
	sub di,160
	mov ax,[di]
							;не удалять четвертую стену при движении вверх	
	cmp ax,1
	jne goup
	cmp bx,3000
	jmp stepend
	mov [di],word ptr 0
goup:
	sub bx,160
	cmp bx,0
	jle uletetlivverh
	jmp stepend
uletetlivverh:
	add bx,4000
	jmp stepend
	
directdown:					;шаг вниз
	lea di,map
	add di,bx
	add di,160
	mov ax,[di]
	cmp ax,1
	je stepend
	add bx,160
	cmp bx,4000
	jge uletetlivniz
	jmp stepend
uletetlivniz:
	sub bx,4000
	jmp stepend
stepend:					;отрисовка шага
	mov ax,0B800h
	push ax
	pop es
	mov [si],bx
	mov di,bx
	xor ax,ax
	mov al,0Ah
	mov es:[di],al
	pop di si
	ret

print:    ; выводит bx
	push si di ax
	mov cl, 4
cicl: 
	dec cx
	rol bx, 4
	mov dx, bx
	and dl, 0fh
    add dl,'0'
    cmp dl,'9'
    jle the_end
    add dl,7
the_end:
	mov ah,02h
	int 21h
	cmp cl, 0
	jne  cicl
	mov dl,13
	int 21h
	mov dl,10
	int 21h
	pop ax di si
	ret

p dw 1
direct dw 1	
time dw 0
tail dw 0
head dw 0
lzmey db 0		;длина змея	
two dw 2

speed dw 10


buffer dw 20 dup (?)
er db 0
coordinates dw 1000 dup (?)

map dw 2000 dup (?)
end main