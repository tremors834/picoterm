* PicoTerm - a terminal for the Pocket Pico (HK-21 emulator) on the CoCo 3
*
* Bit-banger serial port (4-pin DIN), 1200 baud, 8N1, 80 columns.
* Load with RUN"PICOTERM" (the BASIC launcher does LOADM and EXEC).
*
* Serial I/O runs from the GIME timer FIRQ at 4800 Hz (4 ticks per
* bit), so text keeps arriving while the screen scrolls or a key is
* being sent.  The screen is a 16K buffer (physical $60000-$63FFF)
* scrolled by moving the GIME video start address.

RING    equ     $4E00           256-byte receive buffer
RINGB   equ     RING+128        index base (b,x offsets are signed)
VARS    equ     $4F00           direct page
SCRN    equ     $A000           screen buffer, mapped at $A000-$DFFF
NROWS   equ     102             rows in the buffer
ROWLEN  equ     160             80 characters + 80 attributes
ATTR    equ     $38             white (palette 15) on black (palette 0)
LATTR   equ     $30             our own messages: yellow (palette 14)
CURBITS equ     $C0             blink + underline
MARK    equ     $02             RS-232 out idle (bit 1 of $FF20)
SPACE   equ     $00
TCOUNT  equ     745             3.579545 MHz / 745 = 4800 Hz

NL_CR   equ     1               last newline came from CR
NL_LF   equ     2               ... from LF
NL_WRAP equ     3               ... from wrapping at column 80

K_CLEAR equ     $F0             special keys
K_F1    equ     $F1
K_F2    equ     $F2
K_CAPS  equ     $F3
K_WAKE  equ     $F4

        org     VARS
rxhead  rmb     1
rxtail  rmb     1
rxtick  rmb     1
rxbits  rmb     1
rxbyte  rmb     1
txbits  rmb     1
txtick  rmb     1
txshift rmb     1
ticks   rmb     2               counts up at 4800 Hz
rxcnt   rmb     2               bytes received (for testing)
ferr    rmb     1               framing errors
ovf     rmb     1               receive buffer overflows
top     rmb     1               buffer row shown at the top
topptr  rmb     2
rowptr  rmb     2               start of the cursor's row
curptr  rmb     2               cursor cell
voff    rmb     2               GIME vertical offset for top
currow  rmb     1
curcol  rmb     1
cattr   rmb     1
lastnl  rmb     1
caps    rmb     1
quiet   rmb     1               1 = don't show received text
gotcmd  rmb     1               set when "cmd:" arrives
mpos    rmb     1
tries   rmb     1
wend    rmb     2
kbtime  rmb     2
jmask   rmb     1
kbnow   rmb     8
klast   rmb     1
krep    rmb     1
krow    rmb     1
isrep   rmb     1
qask    rmb     1
quitnow rmb     1
sv_vec  rmb     3
sv_cra  rmb     1
sv_crb  rmb     1

        org     $5000
start   pshs    cc,a,b,dp,x,y,u
        orcc    #$50            no interrupts while setting up
        lda     #VARS/256
        tfr     a,dp
        setdp   VARS/256
        ldx     #VARS
clrv    clr     ,x+
        cmpx    #VARS+256
        bne     clrv
* save what we change, to put back on the way out
        ldx     #$FEF4
        lda     ,x
        sta     <sv_vec
        ldd     1,x
        std     <sv_vec+1
        lda     $FF21
        sta     <sv_cra
        anda    #$FE            PIA1 CD interrupt off
        sta     $FF21
        lda     $FF23
        sta     <sv_crb
        anda    #$FE            cartridge interrupt off
        sta     $FF23
        sta     $FFD9           fast CPU (1.79 MHz)
        sta     $FFDF           all-RAM mode
        lda     #$30            screen buffer at $A000-$DFFF
        sta     $FFA5
        inca
        sta     $FFA6
        lda     #$5C            CoCo 3 mode, MMU, FIRQ, $FExx fixed, SCS
        sta     $FF90
        lda     #$20            timer clock 3.58 MHz, MMU task 0
        sta     $FF91
        clr     $FF92
        lda     #$03            text mode, 8 lines per row
        sta     $FF98
        lda     #$15            80 columns with attributes, 192 lines
        sta     $FF99
        clr     $FF9A           black border
        clr     $FF9C
        clr     $FF9F
        clr     $FFB0           background black
        lda     #$36
        sta     $FFBE           yellow
        lda     #$3F
        sta     $FFBF           white
        lda     #ATTR
        sta     <cattr
        jsr     clrall
* FIRQ vector and serial timer
        lda     #MARK
        sta     $FF20
        lda     #$7E            JMP firq
        ldx     #firq
        sta     $FEF4
        stx     $FEF5
        lda     #$20            timer FIRQ on
        sta     $FF93
        lda     $FF93
        ldd     #TCOUNT
        stb     $FF95
        sta     $FF94
        andcc   #$BF            FIRQ on (IRQ stays off)
        lda     #1
        sta     <caps
        ldx     #m_hello
        jsr     lmsg
* a key still held from typing RUN"PICOTERM" is not a new key press
        lda     #$FF
        sta     <klast
        jsr     kbscan
        lda     #$FF
        sta     <krep
        jsr     wake

main    jsr     getrx
        bcc     mkey
        jsr     dorx
        bra     main
mkey    ldd     <ticks          scan the keyboard every 20 ms
        subd    <kbtime
        cmpd    #96
        blo     main
        ldd     <ticks
        std     <kbtime
        jsr     kbscan
        tsta
        beq     main
        jsr     dokey
        tst     <quitnow
        beq     main

* back to BASIC
        orcc    #$50
        clr     $FF93
        lda     $FF93
        lda     #$4C
        sta     $FF90
        clr     $FF91
        ldx     #$FEF4
        lda     <sv_vec
        sta     ,x
        ldd     <sv_vec+1
        std     1,x
        lda     <sv_cra
        sta     $FF21
        lda     <sv_crb
        sta     $FF23
        lda     #$3D
        sta     $FFA5
        inca
        sta     $FFA6
        lda     #$D8            BASIC's 80-column screen
        sta     $FF9D
        clr     $FF9E
        ldx     #defpal
        ldu     #$FFB0
pal     lda     ,x+
        sta     ,u+
        cmpu    #$FFC0
        bne     pal
        lda     #MARK
        sta     $FF20
        sta     $FFD8           normal CPU speed
        puls    cc,a,b,dp,x,y,u,pc

* ---------------------------------------------------------------
* Timer FIRQ, 4800 times a second: receive and send one bit slice
firq    pshs    a,b,x
        lda     $FF93           acknowledge the timer
        inc     <ticks+1
        bne     f0
        inc     <ticks
f0      ldb     $FF22           bit 0 = RS-232 in
        lda     <rxbits
        bne     rx1
        lsrb
        bcs     rxe             idle (mark)
        lda     #6              start bit: first data bit in 1.5 bits
        sta     <rxtick
        lda     #9              8 data bits + stop bit
        sta     <rxbits
        bra     rxe
rx1     dec     <rxtick
        bne     rxe
        lsrb                    C = the bit
        ldb     #4
        stb     <rxtick
        deca
        sta     <rxbits
        beq     rx2
        ror     <rxbyte
        bra     rxe
rx2     bcc     rx3             no stop bit
        ldb     <rxhead
        incb
        cmpb    <rxtail
        beq     rx4             buffer full
        decb
        ldx     #RINGB
        lda     <rxbyte
        sta     b,x
        incb
        stb     <rxhead
        inc     <rxcnt+1
        bne     rxe
        inc     <rxcnt
        bra     rxe
rx3     inc     <ferr
        bra     rxe
rx4     inc     <ovf
rxe     lda     <txbits         11 = start, 10-3 = data, 2 = stop, 1 = gap
        beq     txe
        dec     <txtick
        bne     txe
        ldb     #4
        stb     <txtick
        cmpa    #11
        beq     txs
        cmpa    #3
        blo     txm
        lsr     <txshift
        bcs     txm
txs     ldb     #SPACE
        bra     txo
txm     ldb     #MARK
txo     stb     $FF20
        dec     <txbits
txe     puls    a,b,x
        rti

* ---------------------------------------------------------------
* send A (waits while the previous character goes out)
sendc   tst     <txbits
        bne     sendc
        sta     <txshift
        lda     #1
        sta     <txtick
        lda     #11
        sta     <txbits
        rts

* next received character: C=1 and A=char, or C=0 if none
getrx   ldb     <rxtail
        cmpb    <rxhead
        beq     gr0
        ldx     #RINGB
        lda     b,x
        incb
        stb     <rxtail
        orcc    #1
        rts
gr0     andcc   #$FE
        rts

* handle one received character
dorx    pshs    a
        jsr     match
        puls    a
        tst     <quiet
        bne     dr0
        jsr     outch
dr0     rts

* watch for "cmd:" (any case)
match   anda    #$7F
        cmpa    #'A
        blo     m0
        cmpa    #'Z
        bhi     m0
        ora     #$20
m0      ldx     #mstr
        ldb     <mpos
        cmpa    b,x
        beq     m1
        clr     <mpos
        cmpa    ,x
        bne     mr
        inc     <mpos
        rts
m1      incb
        stb     <mpos
        cmpb    #4
        bne     mr
        clr     <mpos
        inc     <gotcmd
mr      rts
mstr    fcc     "cmd:"

* wait D ticks, handling received text; returns early on "cmd:"
waitt   addd    <ticks
        std     <wend
wt1     jsr     getrx
        bcc     wt2
        jsr     dorx
        tst     <gotcmd
        bne     wt3
wt2     ldd     <ticks
        subd    <wend
        bmi     wt1
wt3     rts

* get the Pico talking at 1200 baud
wake    ldx     #m_wake
        jsr     lmsg
        lda     #1
        sta     <quiet
        clr     <gotcmd
        clr     <mpos
        lda     #$03            Ctrl-C: to the cmd: prompt
        jsr     sendc
        lda     #$0D
        jsr     sendc
        ldd     #4800           1 s
        jsr     waitt
        tst     <gotcmd
        bne     wk2
        lda     #12             auto-baud: send * until it answers
        sta     <tries
wk1     lda     #'*
        jsr     sendc
        ldd     #3360           0.7 s
        jsr     waitt
        tst     <gotcmd
        bne     wk2
        dec     <tries
        bne     wk1
        clr     <quiet
        ldx     #m_noans
        jmp     lmsg
wk2     clr     <gotcmd
        ldd     #2400           let the rest of its greeting go by
        jsr     waitt
        clr     <quiet
        ldx     #m_ready
        jsr     lmsg
        lda     #$0D            fresh cmd: prompt
        jmp     sendc

* ---------------------------------------------------------------
* keys
dokey   tst     <qask
        beq     dk1
        clr     <qask
        cmpa    #'Y
        beq     dkq
        cmpa    #'y
        beq     dkq
        ldx     #m_stay
        jmp     lmsg
dkq     inc     <quitnow
        rts
dk1     cmpa    #K_CLEAR
        blo     dk2
        tst     <isrep          special keys don't repeat
        bne     dkr
        cmpa    #K_F1
        beq     dkhelp
        cmpa    #K_F2
        beq     dkask
        cmpa    #K_CLEAR
        beq     dkclr
        cmpa    #K_CAPS
        beq     dkcaps
        cmpa    #K_WAKE
        lbeq    wake
dkr     rts
dk2     jmp     sendc
dkhelp  ldx     #m_help
        jmp     lmsg
dkask   inc     <qask
        ldx     #m_quit
        jmp     lmsg
dkclr   jsr     clrall
        rts
dkcaps  lda     <caps
        eora    #1
        sta     <caps
        ldx     #m_capon
        tsta
        bne     dkc1
        ldx     #m_capof
dkc1    jmp     lmsg

* scan the keyboard; A = character or special key code, 0 = nothing new
kbscan  lda     #$FF            rows that are down with no column
        sta     $FF02           selected are joystick buttons
        lda     $FF00
        coma
        anda    #$7F
        sta     <jmask
        ldx     #kbnow
        ldb     #$FE
ks1     stb     $FF02
        lda     $FF00
        coma
        anda    #$7F
        sta     ,x
        lda     <jmask
        coma
        anda    ,x
        sta     ,x+
        orcc    #1
        rolb
        bcs     ks1
        lda     #$FF
        sta     $FF02
* first key down, not counting ALT, CTRL and SHIFT
        ldx     #kbnow
        clrb
kf1     lda     b,x
        cmpb    #3
        beq     kfm
        cmpb    #4
        beq     kfm
        cmpb    #7
        bne     kf2
kfm     anda    #$3F
kf2     tsta
        bne     kf3
        incb
        cmpb    #8
        blo     kf1
        lda     #$FF            nothing down
        bra     kf6
kf3     clr     <krow
kf4     lsra
        bcs     kf5
        inc     <krow
        bra     kf4
kf5     lda     <krow
        lsla
        lsla
        lsla
        pshs    b
        adda    ,s+             A = row*8 + column
kf6     cmpa    <klast
        beq     ksame
        sta     <klast
        cmpa    #$FF
        beq     knone
        ldb     #25             first repeat after 0.5 s
        stb     <krep
        clr     <isrep
        bra     xlate
ksame   cmpa    #$FF
        beq     knone
        dec     <krep
        bne     knone
        ldb     #4              then every 80 ms
        stb     <krep
        ldb     #1
        stb     <isrep
        bra     xlate
knone   clra
        rts

* key position A -> character
xlate   ldb     <kbnow+4        CTRL
        bitb    #$40
        beq     xl1
        ldx     #tctrl
        lda     a,x
        rts
xl1     ldx     #tnorm
        clr     <krow           krow = SHIFT down
        ldb     <kbnow+7
        bitb    #$40
        beq     xl2
        ldx     #tshift
        inc     <krow
xl2     lda     a,x
        cmpa    #'A
        blo     xl3
        cmpa    #'Z
        bhi     xl3
        ldb     <krow           lower case unless caps XOR shift
        eorb    <caps
        bne     xl3
        ora     #$20
xl3     rts

* ---------------------------------------------------------------
* screen
outch   pshs    a,b,x,y,u
        anda    #$7F
        pshs    a
        jsr     hidecur
        puls    a
        cmpa    #$0D
        beq     o_cr
        cmpa    #$0A
        beq     o_lf
        cmpa    #$08
        beq     o_bs
        cmpa    #$09
        beq     o_tab
        cmpa    #$20
        blo     o_done
        cmpa    #$7F
        beq     o_done
        bsr     o_put
        bra     o_done
o_cr    ldb     <lastnl
        cmpb    #NL_LF
        beq     o_none
        cmpb    #NL_WRAP
        beq     o_setcr
        jsr     newline
o_setcr ldb     #NL_CR
        stb     <lastnl
        bra     o_done
o_none  clr     <lastnl
        bra     o_done
o_lf    ldb     <lastnl
        cmpb    #NL_CR
        beq     o_none
        cmpb    #NL_WRAP
        beq     o_setlf
        jsr     newline
o_setlf ldb     #NL_LF
        stb     <lastnl
        bra     o_done
o_bs    clr     <lastnl
        lda     <curcol
        beq     o_done
        dec     <curcol
        ldx     <curptr
        leax    -2,x
        stx     <curptr
        lda     #$20
        ldb     <cattr
        std     ,x
        bra     o_done
o_tab   lda     #$20
        bsr     o_put
        lda     <curcol
        bita    #7
        bne     o_tab
o_done  jsr     showcur
        puls    a,b,x,y,u,pc
o_put   clr     <lastnl
        ldx     <curptr
        ldb     <cattr
        std     ,x++
        stx     <curptr
        inc     <curcol
        lda     <curcol
        cmpa    #80
        blo     op1
        jsr     newline
        lda     #NL_WRAP
        sta     <lastnl
op1     rts

hidecur ldx     <curptr
        lda     1,x
        anda    #$3F
        sta     1,x
        rts
showcur ldx     <curptr
        lda     1,x
        ora     #CURBITS
        sta     1,x
        rts

* move to the start of the next line, scrolling if needed
newline clr     <curcol
        lda     <currow
        cmpa    #23
        bhs     scroll
        inc     <currow
        ldd     <rowptr
        addd    #ROWLEN
        std     <rowptr
        std     <curptr
        rts
scroll  lda     <top
        cmpa    #NROWS-24
        blo     sc1
* end of the buffer: copy the bottom 23 rows to the start
        ldx     <topptr
        leax    ROWLEN,x
        ldu     #SCRN
        ldy     #23*ROWLEN/2
sc0     ldd     ,x++
        std     ,u++
        leay    -1,y
        bne     sc0
        clr     <top
        ldd     #SCRN
        std     <topptr
        ldd     #$C000
        std     <voff
        ldd     #SCRN+23*ROWLEN
        std     <rowptr
        bra     sc2
sc1     inc     <top
        ldd     <topptr
        addd    #ROWLEN
        std     <topptr
        ldd     <voff
        addd    #ROWLEN/8
        std     <voff
        ldd     <rowptr
        addd    #ROWLEN
        std     <rowptr
sc2     ldx     <rowptr         clear the new bottom row, then show it
        stx     <curptr
        ldd     #$2000+ATTR
        ldy     #80
sc3     std     ,x++
        leay    -1,y
        bne     sc3
        jmp     setoff

* clear the whole buffer and home the cursor
clrall  ldx     #SCRN
        ldd     #$2000+ATTR
ca1     std     ,x++
        cmpx    #SCRN+NROWS*ROWLEN
        blo     ca1
        clr     <top
        clr     <currow
        clr     <curcol
        clr     <lastnl
        ldd     #SCRN
        std     <topptr
        std     <rowptr
        std     <curptr
        ldd     #$C000          physical $60000 / 8
        std     <voff
        jsr     setoff
        jmp     showcur

setoff  ldd     <voff
        sta     $FF9D
        stb     $FF9E
        rts

* print one of our own messages (X = text, 0 at the end) on its own line
lmsg    pshs    a,x
        lda     <cattr
        pshs    a
        lda     #LATTR
        sta     <cattr
        lda     <curcol
        beq     lm1
        lda     #$0D
        jsr     outch
lm1     lda     ,x+
        beq     lm2
        jsr     outch
        bra     lm1
lm2     lda     #$0D
        jsr     outch
        clr     <lastnl
        puls    a
        sta     <cattr
        puls    a,x,pc

* ---------------------------------------------------------------
* key tables: row 0-6, column 0-7
tnorm   fcc     "@ABCDEFG"
        fcc     "HIJKLMNO"
        fcc     "PQRSTUVW"
        fcc     "XYZ"
        fcb     0,0,$08,0,$20           up down left right space
        fcc     "01234567"
        fcc     "89:;,-./"
        fcb     $0D,K_CLEAR,$03,0,0,K_F1,K_F2,0
tshift  fcc     "@ABCDEFG"
        fcc     "HIJKLMNO"
        fcc     "PQRSTUVW"
        fcc     "XYZ"
        fcb     0,0,$08,0,$20
        fcb     K_CAPS
        fcc     "!"
        fcb     $22
        fcc     "#$%&"
        fcb     $27
        fcc     "()*+<=>?"
        fcb     $0D,K_CLEAR,$03,0,0,K_WAKE,K_F2,0
tctrl   fcb     0,1,2,3,4,5,6,7
        fcb     8,9,10,11,12,13,14,15
        fcb     16,17,18,19,20,21,22,23
        fcb     24,25,26,0,0,$08,0,$20
        fcb     0
        fcc     "|"
        fcb     0
        fcc     "~"
        fcb     0,0,0
        fcc     "^"
        fcc     "[]"
        fcb     0,0
        fcc     "{_}"
        fcb     $5C
        fcb     $0D,K_CLEAR,$03,0,0,K_F1,K_F2,0

* BASIC's power-up palette (RGB)
defpal  fcb     18,36,11,7,63,31,9,38,0,18,0,63,0,18,0,38

m_hello fcc     "PicoTerm 0.1 for the Pocket Pico          F1 = help     F2 = quit"
        fcb     0
m_wake  fcc     "Waking up the Pocket Pico..."
        fcb     0
m_ready fcc     "The Pocket Pico is answering. Ready."
        fcb     0
m_noans fcc     "No answer from the Pocket Pico. Check the cable and its power,"
        fcb     $0D
        fcc     "then press SHIFT+F1 to try again."
        fcb     0
m_help  fcc     "BREAK = Ctrl-C (back to the cmd: prompt)     CLEAR = clear the screen"
        fcb     $0D
        fcc     "CTRL+letter = control key (CTRL+Z = Ctrl-Z)  SHIFT+0 = caps lock on/off"
        fcb     $0D
        fcc     "SHIFT+F1 = wake up the Pocket Pico again     F2 = quit to BASIC"
        fcb     $0D
        fcc     "CTRL with 1 3 7 8 9 , - . / types  | ~ ^ [ ] { _ } "
        fcb     $5C,0
m_quit  fcc     "Quit to BASIC? Press Y for yes, any other key to stay."
        fcb     0
m_stay  fcc     "Staying in the terminal."
        fcb     0
m_capon fcc     "Caps lock on."
        fcb     0
m_capof fcc     "Caps lock off."
        fcb     0

        end     start
