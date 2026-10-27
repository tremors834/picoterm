* Minimal stand-in ROM for emulator testing only (not Tandy code).
* Sets up the machine roughly the way Super Extended BASIC leaves it,
* then waits for the test script to load PICO at $5000 and start it.
        org     $8000
start   orcc    #$50
        lds     #$4000
* PIAs the way Color BASIC sets them
        clr     $ff01
        clr     $ff00
        lda     #$34
        sta     $ff01
        clr     $ff03
        lda     #$ff
        sta     $ff02
        lda     #$34
        sta     $ff03
        clr     $ff21
        lda     #$fe
        sta     $ff20
        lda     #$34
        sta     $ff21
        clr     $ff23
        lda     #$f8
        sta     $ff22
        lda     #$34
        sta     $ff23
        lda     #$02            RS-232 out idle
        sta     $ff20
* MMU like BASIC: blocks $38-$3F
        ldx     #$ffa0
        lda     #$38
mmu     sta     ,x
        sta     8,x
        leax    1,x
        inca
        cmpa    #$40
        bne     mmu
        lda     #$4c
        sta     $ff90
        clr     $ff91
* RTI in every secondary vector slot
        ldx     #$feee
        lda     #$3b
vec     sta     ,x+
        cmpx    #$ff00
        bne     vec
* copy the wait loop to RAM and run it there
        ldx     #wait
        ldy     #$0100
cp      lda     ,x+
        sta     ,y+
        cmpx    #wend
        bne     cp
        clr     $0180
        clr     $0181
        jmp     $0100
wait    sta     $ffdf           all-RAM mode
w1      lda     $0180
        beq     w1
        jsr     $5000
        clr     $0180
        inc     $0181
        bra     w1
wend
        fill    $ff,$fff2-*
        fdb     $feee,$fef1,$fef4,$fef7,$fefa,$fefd,start
