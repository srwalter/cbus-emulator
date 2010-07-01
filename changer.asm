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

        .sim "U1.txbaud = 19200"
        .sim "U1.rxbaud = 19200"

        org 0
        goto main
        nop
        nop
        nop
        goto irq

main:
        clrf    PORTA
        clrf    PORTB
        movlw   0x07
        movwf   CMCON

        bcf     RCSTA, SYNC
        bsf     RCSTA, SPEN

        bsf     STATUS, RP0
        bcf     OPTION_REG^0x80, T0CS
        bcf     TRISB^0x80, 0
        bsf     TRISB^0x80, 1
        bsf     TRISB^0x80, 2
        bsf     TRISB^0x80, 4
        bsf     TRISB^0x80, 5
        clrf    TRISA^0x80

        movlw   15 ; 19200 @ 20MHz
        movwf   SPBRG^0x80
        bsf     TXSTA^0x80, TXEN
        bcf     STATUS, RP0

        bsf     INTCON, GIE
        bsf     INTCON, PEIE

wait_clk_low macro
        btfsc   PORTB, 4
        goto    $-1
        endm

wait_clk_high macro
        btfss   PORTB, 4
        goto    $-1
        endm

wait_data_low macro
        btfsc   PORTB, 5
        goto    $-1
        endm

wait_data_high macro
        btfss   PORTB, 5
        goto    $-1
        endm

        wait_clk_high
        wait_data_high

decode_burst:
        clrf    PORTA
        clrf    0x20
        clrf    0x21
        movlw   0x30
        movwf   FSR

        ; Bit 0 (MSB)
        wait_clk_low
        bsf     PORTB, 0
        movlw   1
        movwf   PORTA
        wait_clk_high
        movfw   PORTB
        movwf   INDF
        incf    FSR, F

        ; Bit 1
        wait_clk_low
        movlw   2
        movwf   PORTA
        wait_clk_high
        movfw   PORTB
        movwf   INDF
        incf    FSR, F

        ; Bit 2
        wait_clk_low
        movlw   3
        movwf   PORTA
        wait_clk_high
        movfw   PORTB
        movwf   INDF
        incf    FSR, F

        ; Bit 3
        wait_clk_low
        movlw   4
        movwf   PORTA
        wait_clk_high
        movfw   PORTB
        movwf   INDF
        incf    FSR, F

        ; Bit 4
        wait_clk_low
        movlw   5
        movwf   PORTA
        wait_clk_high
        movfw   PORTB
        movwf   INDF
        incf    FSR, F

        ; Bit 5
        wait_clk_low
        movlw   6
        movwf   PORTA
        wait_clk_high
        movfw   PORTB
        movwf   INDF
        incf    FSR, F

        ; Bit 6
        wait_clk_low
        movlw   7
        movwf   PORTA
        wait_clk_high
        movfw   PORTB
        movwf   INDF
        incf    FSR, F

        ; Bit 7 (LSB)
        wait_clk_low
        movlw   8
        movwf   PORTA
        wait_clk_high
        movfw   PORTB
        movwf   INDF
        incf    FSR, F

        ; wait for delay to start
        wait_data_high
        movlw   9
        movwf   PORTA

        ; compress 8 bytes to one
        movlw   0x30
        movwf   FSR
        clrf    0x20
        bcf     STATUS, C

decode_loop:
        rlf     0x20, F
        btfsc   INDF, 5
        bsf     0x20, 0
        incf    FSR, F
        btfss   FSR, 3
        goto    decode_loop

        movlw   10
        movwf   PORTA
        ; wait for pulse to end
        wait_data_low
        movlw   11
        movwf   PORTA
        wait_data_high
        movlw   12
        movwf   PORTA
        wait_clk_high

        bcf     PORTB, 0

        movfw   0x20
        movwf   XMIT_BUF
        bsf     STATUS, RP0
        bsf     PIE1^0x80, TXIE
        bcf     STATUS, RP0
        goto    decode_burst

irq:
        movwf   IRQ_W
        swapf   STATUS, W
        movwf   IRQ_STATUS

        btfsc   PIR1, TXIF
        call    tx_ready

        swapf   IRQ_STATUS, W
        movwf   STATUS
        swapf   IRQ_W, F
        swapf   IRQ_W, W
        retfie
        ; end of irq

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
