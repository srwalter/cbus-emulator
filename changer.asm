	processor 16f648a
        include "p16f648a.inc"
        include "coff.inc"
        __CONFIG _HS_OSC & _WDT_OFF & _CP_OFF & _LVP_OFF & _BOREN_OFF
        radix dec

        CONSTANT IRQ_W=0x7f
        CONSTANT IRQ_STATUS=0x7e
        CONSTANT XMIT_BUF=0x7d

MAIN CODE
start

        .sim ".frequency=20e6"
        .sim "module library libgpsim_modules"
        .sim "module load usart U1"

        .sim "node n0"
        .sim "node n1"

        .sim "attach n0 portb2 U1.RXPIN"
        .sim "attach n1 portb1 U1.TXPIN"

        .sim "U1.txbaud = 9600"
        .sim "U1.rxbaud = 9600"

        org 0
        goto main
        nop
        nop
        nop
        goto irq

main:
        bcf     RCSTA, SYNC
        bsf     RCSTA, SPEN

        bsf     STATUS, RP0
        bcf     TRISB^0x80, 0
        bsf     TRISB^0x80, 1
        bsf     TRISB^0x80, 2
        bsf     TRISB^0x80, 4
        bsf     TRISB^0x80, 5

        movlw   15 ; 19200 @ 20MHz
        movwf   SPBRG^0x80
        bsf     TXSTA^0x80, TXEN
        bcf     STATUS, RP0

        bsf     INTCON, GIE
        bcf     INTCON, RBIF
        bsf     INTCON, RBIE
        bsf     INTCON, PEIE

        ; test serial port

        bsf     STATUS, RP0
        movlw   A'S'
        movwf   XMIT_BUF
test:
        bcf     STATUS, RP0
        bsf     PORTB, 0
        bsf     STATUS, RP0

        bsf     PIE1^0x80, TXIE
        btfsc   PIE1^0x80, TXIE
        goto    $-1

        bcf     STATUS, RP0
        bcf     PORTB, 0
        bsf     STATUS, RP0
        goto    test

test_clk macro
        movlw     0x10
        andwf     PORTB, W
        endm

wait_clk_low macro
        test_clk
        skpz
        goto $-2
        endm

wait_clk_high macro
        test_clk
        skpnz
        goto $-2
        endm

test_data macro
        movlw   0x20
        andwf   PORTB, W
        endm

wait_data_low macro
        test_clk
        skpz
        goto $-2
        endm

wait_data_high macro
        test_clk
        skpnz
        goto $-2
        endm

decode_burst:
        clrf    0x20
        clrf    0x21

burst_loop:
        wait_clk_low
        wait_clk_high

        rlf     0x20, F
        test_data
        skpz
        bsf     0x20, 0
        incf    0x21, F
        movlw   8
        subwf   0x21, W
        skpz
        goto    burst_loop

        ; wait for pulse to end
        wait_data_high
        wait_data_low
        wait_data_high
        wait_clk_high

        movfw   0x20
        return
        ; end decode_burst

irq:
        movwf   IRQ_W
        swapf   STATUS, W
        movwf   IRQ_STATUS

        btfsc   INTCON, RBIF
        call    bus_activity
        btfsc   PIR1, TXIF
        call    tx_ready

        swapf   IRQ_STATUS, W
        movwf   STATUS
        swapf   IRQ_W, F
        swapf   IRQ_W, W
        retfie
        ; end of irq

bus_activity:
        bcf     INTCON, RBIF
        call    decode_burst
        movwf   XMIT_BUF
        return
        ; end of bus_activity

tx_ready:
        bsf     STATUS, RP0
        movfw   PIE1^0x80
        bcf     STATUS, RP0
        movwf   0x20
        btfss   0x20, TXIE
        return

        bsf     STATUS, RP0
        bcf     PIE1^0x80, TXIE
        bcf     STATUS, RP0
        movfw   XMIT_BUF
        movwf   TXREG
        return
        ; end of tx_ready

        end
