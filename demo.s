.segment "HEADER"
  ; .byte "NES", $1A      ; iNES header identifier
  .byte $4E, $45, $53, $1A
  .byte 2               ; 2x 16KB PRG code
  .byte 1               ; 1x  8KB CHR data
  .byte $01, $00        ; mapper 0, vertical mirroring

.segment "VECTORS"
  ;; When an NMI happens (once per frame if enabled) the label nmi:
  .addr nmi
  ;; When the processor first turns on or is reset, it will jump to the label reset:
  .addr reset
  ;; External interrupt IRQ (unused)
  .addr 0

; "nes" linker config requires a STARTUP section, even if it's empty
.segment "STARTUP"

; Main code segment for the program
.segment "CODE"

reset:
  sei		; disable IRQs
  cld		; disable decimal mode
  ldx #$40
  stx $4017	; disable APU frame IRQ
  ldx #$ff 	; Set up stack
  txs		;  .
  inx		; now X = 0
  stx $2000	; disable NMI
  stx $2001 	; disable rendering
  stx $4010 	; disable DMC IRQs

;; first wait for vblank to make sure PPU is ready
vblankwait1:
  bit $2002
  bpl vblankwait1

clear_memory:
  lda #$00
  sta $0000, x
  sta $0100, x
  sta $0200, x
  sta $0300, x
  sta $0400, x
  sta $0500, x
  sta $0600, x
  sta $0700, x
  inx
  bne clear_memory

;; second wait for vblank, PPU is ready after this
vblankwait2:
  bit $2002
  bpl vblankwait2

main:
load_palettes:
  lda $2002 ;reads from the CPU-RAM PPU address register to reset it
  lda #$3f  ;loads the higher byte of the PPU address register of the palettes in a (we want to write in $3f00 of the PPU since it is the address where the palettes of the PPU are stored)
  sta $2006 ;store what's in a (higher byte of PPU palettes address register $3f00) in the CPU-RAM memory location that transfers it into the PPU ($2006)
  lda #$00  ;loads the lower byte of the PPU address register in a
  sta $2006 ;store what's in a (lower byte of PPU palettes address register $3f00) in the CPU-RAM memory location that transfers it into the PPU ($2006)
  ldx #$00  ;AFTER THIS, THE PPU-RAM GRAPHICS POINTER WILL BE POINTING TO THE MEMORY LOCATION THAT CONTAINS THE SPRITES, NOW WE NEED TO TRANSFER SPRITES FROM THE CPU-ROM TO THE PPU-RAM
            ;THE PPU-RAM POINTER GETS INCREASED AUTOMATICALLY WHENEVER WE WRITE ON IT

; NO NEED TO MODIFY THIS LOOP SUBROUTINE, IT ALWAYS LOADS THE SAME AMOUNT OF PALETTE REGISTER. TO MODIFY PALETTES, REFER TO THE PALETTE SECTION
@loop: 
  lda palettes, x   ; as x starts at zero, it starts loading in a the first element in the palettes code section ($0f). This address mode allows us to copy elements from a tag with .data directives and the index in x
  sta $2007         ;THE PPU-RAM POINTER GETS INCREASED AUTOMATICALLY WHENEVER WE WRITE ON IT
  inx
  cpx #$20
  bne @loop

enable_rendering: ; DO NOT MODIFY THIS
  lda #%10000000	; Enable NMI
  sta $2000
  lda #%00010000	; Enable Sprites
  sta $2001

forever: ;FOREVER LOOP WAITING FOR THEN NMI INTERRUPT, WHICH OCCURS WHENEVER THE LAST PIXEL IN THE BOTTOM RIGHT CORNER IS PROJECTED
  jmp forever

nmi:  ;WHENEVER AN NMI INTERRUPT OCCURS, THE PROGRAM JUMPS HERE (60fps)
  ldx #$00 	; Set SPR-RAM address to 0
  stx $2003 ;Sets the PPU-RAM pointer to $2003 to start receiving sprite information saved under the tag "firstName"
@loop:	lda firstName, x 	; Load the firstName message into SPR-RAM one by one, the pointer is increased every time a byte is written. Sprites are referenced by using the third byte of the 4-byte arrays in "firstName"
  sta $2004
  inx
  cpx #$3c            ;ATTENTION: if you add more letters, you must increase this number by 4 per each additional letter. This is the limit for the sprite memory copy routine
  bne @loop
  rti

firstName:
  .byte $00, $00, $00, $00 	; DO NOT MODIFY THESE
  .byte $00, $00, $00, $00  ; DO NOT MODIFY THESE

  ; Fist Line: "Jose"
  .byte $6c, $00, $00, $6c  ; Y=$6c(108), Sprite=00(J), Palette=00, X=%6c(108)
  .byte $6c, $01, $00, $76  ; Y=$6c(108), Sprite=01(O), Palette=00, X=%76(118)
  .byte $6c, $02, $00, $80  ; Y=$6c(108), Sprite=02(S), Palette=00, X=%80(128)
  .byte $6c, $03, $00, $8A  ; Y=$6c(108), Sprite=02(E), Palette=00, X=%8A(138)
  ; YOU CAN ADD MORE LETTERS IN THIS SPACE BUT REMEMBER TO INCREASE THE "cpx" ARGUMENT THAT DEFINES WHERE TO STOP LOADING SPRITES

  ; Second line: "Irizarry"
  .byte $7C, $04, $01, $6C  ; Y=$7C, Sprite=04 (I), X=$6C
  .byte $7C, $05, $01, $76  ; Y=$7C, Sprite=05 (R), X=$76
  .byte $7C, $04, $01, $80  ; Y=$7C, Sprite=04 (I), X=$80
  .byte $7C, $06, $01, $8A  ; Y=$7C, Sprite=06 (Z), X=$8A
  .byte $7C, $07, $01, $94  ; Y=$7C, Sprite=07 (A), X=$94
  .byte $7C, $05, $01, $9E  ; Y=$7C, Sprite=08 (R), X=$9E
  .byte $7C, $05, $01, $A8  ; Y=$7C, Sprite=08 (R), X=$A8
  .byte $7C, $08, $01, $B2  ; Y=$7C, Sprite=09 (Y), X=$B2

palettes: ;The first color should always be the same accross all the palettes. MOdify this section to determine which colors you'd like to use
  ; BACKGROUND Palette % all black and gray
  .byte $0f, $20, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00

  ; SPRITE Palette  %notice that the first palette contains the white color in the second element
  .byte $0f, $3A, $34, $37
  .byte $0f, $31, $3B, $39
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00

; Character memory
.segment "CHARS"
  .byte %01111110 ; J (00), first colorPal 1
  .byte %11111111
  .byte %00011000
  .byte %00011000
  .byte %00011000
  .byte %00011000
  .byte %11011000
  .byte %11110000
  .byte $00, $00, $00, $00, $00, $00, $00, $00 

  .byte %00000000	; O (01), ; second color Pal 1
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000

  .byte %01111110  
  .byte %11100111
  .byte %11000011
  .byte %11000011
  .byte %11000011
  .byte %11000011
  .byte %11100111
  .byte %01111110




  .byte %01111110 ; S (02), third color pal 1
  .byte %11111111
  .byte %11100000
  .byte %01111100
  .byte %00111111
  .byte %11000011
  .byte %01111110
  .byte %01111100

  .byte %01111110 
  .byte %11111111
  .byte %11100000
  .byte %01111100
  .byte %00111111
  .byte %11000011
  .byte %01111110
  .byte %01111100

  .byte %01111110	; E (03), first colorPal 1
  .byte %11111110
  .byte %11000000
  .byte %11111110
  .byte %11111110
  .byte %11000000
  .byte %11111110
  .byte %01111110
  .byte $00, $00, $00, $00, $00, $00, $00, $00

  .byte %01111110   ; I (04), first color 2nd Pal
  .byte %11111111
  .byte %00011000
  .byte %00011000
  .byte %00011000
  .byte %00011000
  .byte %11111111
  .byte %01111110  
  .byte $00, $00, $00, $00, $00, $00, $00, $00


  .byte %00000000	; R (05), second color 2nd Pal
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000

  .byte %11111100   
  .byte %11111110
  .byte %11000110
  .byte %11111100
  .byte %11011000
  .byte %11001100
  .byte %11000110
  .byte %11000111


  .byte %01111111   ; Z (07), first color 2nd Pal
  .byte %11111111
  .byte %00001110
  .byte %00011100
  .byte %00111000
  .byte %01110000
  .byte %11111111
  .byte %11111110
  .byte $00, $00, $00, $00, $00, $00, $00, $00

  .byte %00111100 ; A (07), first color 2nd Pal
  .byte %01100110
  .byte %11000011
  .byte %11000011
  .byte %11111111
  .byte %11111111
  .byte %11000011
  .byte %11000011
  .byte $00, $00, $00, $00, $00, $00, $00, $00

  .byte %01100110	; Y (09), third color 2nd Pal 
  .byte %11100111
  .byte %11100111
  .byte %01111110
  .byte %00111100
  .byte %00011000
  .byte %00011000
  .byte %00011000
  
  .byte %01100110	
  .byte %11100111
  .byte %11100111
  .byte %01111110
  .byte %00111100
  .byte %00011000
  .byte %00011000
  .byte %00011000



