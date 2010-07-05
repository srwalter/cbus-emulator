	processor 16f648a
        include "p16f648a.inc"
        include "coff.inc"
        __CONFIG _HS_OSC & _WDT_OFF & _CP_OFF & _LVP_OFF & _BOREN_OFF
        radix dec

        CONSTANT IRQ_W=0x7f
        CONSTANT IRQ_STATUS=0x7e
        CONSTANT UART_BUF=0x7d
        CONSTANT COMMAND=0x7c

        CONSTANT XFER_TMP_BUF=0x30
        CONSTANT RESP_BUF=0x40
        CONSTANT RESP_BUF_LEN=0x4F

        ; 0x30 - 0x38 send/receive temp space
        ; 0x40 - 0x4E command response buffer

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
        bsf     PORTA, 4

        bsf     STATUS, RP0
        bcf     OPTION_REG^0x80, T0CS
        bcf     TRISB^0x80, 0
        bsf     TRISB^0x80, 1
        bsf     TRISB^0x80, 2
        bsf     TRISB^0x80, 4
        bsf     TRISB^0x80, 5
        movlw   0x10
        movwf   TRISA^0x80

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
        btfsc   PORTA, 4
        goto    $-1
        endm

wait_data_high macro
        btfss   PORTA, 4
        goto    $-1
        endm

        wait_clk_high
        wait_data_high

decode_burst:
        clrf    0x20
        clrf    0x21
        movlw   XFER_TMP_BUF
        movwf   FSR

        ; Bit 0 (MSB)
        wait_clk_low
        bcf     INTCON, GIE
        bsf     PORTB, 0
        wait_clk_high
        movfw   PORTA
        movwf   INDF
        incf    FSR, F

        ; Bit 1
        wait_clk_low
        wait_clk_high
        movfw   PORTA
        movwf   INDF
        incf    FSR, F

        ; Bit 2
        wait_clk_low
        wait_clk_high
        movfw   PORTA
        movwf   INDF
        incf    FSR, F

        ; Bit 3
        wait_clk_low
        wait_clk_high
        movfw   PORTA
        movwf   INDF
        incf    FSR, F

        ; Bit 4
        wait_clk_low
        wait_clk_high
        movfw   PORTA
        movwf   INDF
        incf    FSR, F

        ; Bit 5
        wait_clk_low
        wait_clk_high
        movfw   PORTA
        movwf   INDF
        incf    FSR, F

        ; Bit 6
        wait_clk_low
        wait_clk_high
        movfw   PORTA
        movwf   INDF
        incf    FSR, F

        ; Bit 7 (LSB)
        wait_clk_low
        wait_clk_high
        movfw   PORTA
        movwf   INDF
        incf    FSR, F

        ; wait for HU to release data line
        wait_data_high

        ; end timing-critical
        bsf     INTCON, GIE

        ; compress 8 bytes to one
        movlw   XFER_TMP_BUF
        movwf   FSR
        clrf    0x20
        bcf     STATUS, C

decode_loop:
        rlf     0x20, F
        btfsc   INDF, 4
        bsf     0x20, 0
        incf    FSR, F
        btfss   FSR, 3
        goto    decode_loop

        bcf     PORTB, 0

        movfw   0x20
        movwf   UART_BUF
        bsf     STATUS, RP0
        bsf     PIE1^0x80, TXIE
        bcf     STATUS, RP0

        ; sets up CMD_BUF_LEN and buffer contents
        call    command_logic

        movlw   RESP_BUF
        movwf   FSR

send_next_byte:
        movfw   INDF
        call    send_byte
        incf    FSR, F
        decf    RESP_BUF_LEN, F
        skpz
        goto    send_next_byte

        call    ack_byte
        goto    decode_burst
        ; end main

        ; must preserve FSR
send_byte:
        movwf   0x20
        movfw   FSR
        movwf   0x21
        ; blow out one byte to 8
        movlw   XFER_TMP_BUF
        movwf   FSR

encode_loop:
        movlw   0
        rlf     0x20, F
        btfsc   STATUS, C
        iorlw    0x10
        movwf   INDF
        incf    FSR, F
        btfss   FSR, 3
        goto    encode_loop

        call    ack_byte

        ; switch data line to output
        bsf     PORTA, 4
        bsf     STATUS, RP0
        bcf     TRISA^0x80, 4
        bcf     STATUS, RP0
        movlw   XFER_TMP_BUF
        movwf   FSR
        movfw   INDF

        ; Bit 0 (MSB)
        wait_clk_low
        movwf   PORTA
        bcf     INTCON, GIE
        wait_clk_high
        incf    FSR, F
        movfw   INDF

        ; Bit 1
        wait_clk_low
        movwf   PORTA
        wait_clk_high
        incf    FSR, F
        movfw   INDF

        ; Bit 2
        wait_clk_low
        movwf   PORTA
        wait_clk_high
        incf    FSR, F
        movfw   INDF

        ; Bit 3
        wait_clk_low
        movwf   PORTA
        wait_clk_high
        incf    FSR, F
        movfw   INDF

        ; Bit 4
        wait_clk_low
        movwf   PORTA
        wait_clk_high
        incf    FSR, F
        movfw   INDF

        ; Bit 5
        wait_clk_low
        movwf   PORTA
        wait_clk_high
        incf    FSR, F
        movfw   INDF

        ; Bit 6
        wait_clk_low
        movwf   PORTA
        wait_clk_high
        incf    FSR, F
        movfw   INDF

        ; Bit 7 (LSB)
        wait_clk_low
        movwf   PORTA
        wait_clk_high
        incf    FSR, F
        movfw   INDF

        ; release data line
        wait_clk_low
        bsf     PORTA, 4
        bsf     STATUS, RP0
        bsf     TRISA^0x80, 4
        bcf     STATUS, RP0

        ; end time critical
        bsf     INTCON, GIE

        ; restore FSR
        movfw   0x21
        movwf   FSR
        return
        ; end send_byte

ack_byte:
        ; switch data line to output
        bsf     PORTA, 4
        bsf     STATUS, RP0
        bcf     TRISA^0x80, 4
        bcf     STATUS, RP0

        clrf    TMR0
        bcf     INTCON, T0IF
        btfss   INTCON, T0IF
        goto    $-1

        clrf    TMR0
        bcf     INTCON, T0IF
        btfss   INTCON, T0IF
        goto    $-1

        clrf    TMR0
        bcf     INTCON, T0IF
        btfss   INTCON, T0IF
        goto    $-1

        clrf    TMR0
        bcf     INTCON, T0IF
        btfss   INTCON, T0IF
        goto    $-1

        wait_clk_high
        wait_clk_low
        bcf     PORTA, 4

        clrf    TMR0
        bcf     INTCON, T0IF
        btfss   INTCON, T0IF
        goto    $-1

        clrf    TMR0
        bcf     INTCON, T0IF
        btfss   INTCON, T0IF
        goto    $-1

        wait_clk_high
        wait_clk_low
        bsf     PORTA, 4
        bsf     STATUS, RP0
        bsf     TRISA^0x80, 4
        bcf     STATUS, RP0
        wait_clk_high
        return

command_logic:
        clrf    RESP_BUF_LEN
        movwf   COMMAND
        movwf   RESP_BUF
        movlw   RESP_BUF
        movwf   FSR
        incf    FSR, F
        incf    RESP_BUF_LEN, F

        movlw   0x09
        subwf   COMMAND, W
        skpnz
        goto    cmd_09

        movlw   0x4c
        subwf   COMMAND, W
        skpnz
        goto    cmd_4c

        movlw   0x45
        subwf   COMMAND, W
        skpnz
        goto    cmd_45

        movlw   0x4b
        subwf   COMMAND, W
        skpnz
        goto    cmd_4b

        movlw   0x41
        subwf   COMMAND, W
        skpnz
        goto    cmd_41

        movlw   0x50
        subwf   COMMAND, W
        skpnz
        goto    cmd_50

        movlw   0x51
        subwf   COMMAND, W
        skpnz
        goto    cmd_51

        movlw   0xe2
        subwf   COMMAND, W
        skpnz
        goto    cmd_e2

        movlw   0x61
        subwf   COMMAND, W
        skpnz
        goto    empty_cmd

        movlw   0x70
        subwf   COMMAND, W
        skpnz
        goto    empty_cmd

        movlw   0x81
        subwf   COMMAND, W
        skpnz
        goto    empty_cmd

        movlw   0x5c
        subwf   COMMAND, W
        skpnz
        goto    cmd_5c

        movlw   0xe1
        subwf   COMMAND, W
        skpnz
        goto    cmd_e1

        movlw   0x00
        subwf   COMMAND, W
        skpnz
        goto    cmd_00

        movlw   0xf7
        subwf   COMMAND, W
        skpnz
        goto    cmd_f7

        movlw   0x11
        subwf   COMMAND, W
        skpnz
        goto    cmd_11
        return

cmd_09:
        movlw   0x03
        call    enqueue_byte
        movlw   0x00
        call    enqueue_byte
        movlw   0x01
        call    enqueue_byte
        movlw   0x1a
        call    enqueue_byte
        return
        ; end command_logic

cmd_4c:
        movlw   0x02
        call    enqueue_byte
        movlw   0x00
        call    enqueue_byte
        movlw   0x00
        call    enqueue_byte
        return

cmd_45:
        movlw   0x03
        call    enqueue_byte
        movlw   0x00
        call    enqueue_byte
        movlw   0x01
        call    enqueue_byte
        movlw   0x1a
        call    enqueue_byte
        return

cmd_4b:
        movlw   0x02
        call    enqueue_byte
        movlw   0x12
        call    enqueue_byte
        movlw   0x01
        call    enqueue_byte
        return

cmd_41:
        movlw   0x04
        call    enqueue_byte
        movlw   0x1a
        call    enqueue_byte
        movlw   0x55
        call    enqueue_byte
        movlw   0x50
        call    enqueue_byte
        movlw   0x00
        call    enqueue_byte
        return

cmd_50:
        movlw   0x03
        call    enqueue_byte
        movlw   0x00
        call    enqueue_byte
        movlw   0x01
        call    enqueue_byte
        movlw   0x1a
        call    enqueue_byte
        return

cmd_51:
        movlw   0x03
        call    enqueue_byte
        movlw   0x00
        call    enqueue_byte
        movlw   0x01
        call    enqueue_byte
        movlw   0x1a
        call    enqueue_byte
        return

cmd_e2:
        movlw   0x03
        call    enqueue_byte
        movlw   0x42
        call    enqueue_byte
        movlw   0xff
        call    enqueue_byte
        movlw   0xff
        call    enqueue_byte
        return

empty_cmd:
        movlw   0x00
        call    enqueue_byte
        return

cmd_5c:
        movlw   0x03
        call    enqueue_byte
        movlw   0x00
        call    enqueue_byte
        movlw   0x01
        call    enqueue_byte
        movlw   0x06
        call    enqueue_byte
        return

cmd_e1:
        movlw   0x03
        call    enqueue_byte
        movlw   0x41
        call    enqueue_byte
        movlw   0xff
        call    enqueue_byte
        movlw   0xff
        call    enqueue_byte

        bcf     T1CON, TMR1ON
        clrf    TMR1L
        clrf    TMR1H
        bcf     PIR1, TMR1IF
        bsf     STATUS, RP0
        bsf     PIE1^0x80, TMR1IE
        bcf     STATUS, RP0
        bsf     T1CON, TMR1ON
        return

        ; cmd 0x00 is sent during interrupt servicing.  rather than being
        ; echo'ed, we reply with 0xf7
cmd_00:
        movlw   0xf7
        movwf   RESP_BUF
        return

        ; cmd 0xf7 causes the interrupt line to be released
cmd_f7:
        bsf     STATUS, RP0
        bsf     TRISB, 5
        bcf     STATUS, RP0
        return

cmd_11:
        movlw   0x03
        call    enqueue_byte
        movlw   0x00
        call    enqueue_byte
        movlw   0x01
        call    enqueue_byte
        movlw   0x04
        call    enqueue_byte
        return

enqueue_byte:
        movwf   INDF
        incf    FSR, F
        incf    RESP_BUF_LEN, F
        xorlw   0xff
        movwf   INDF
        incf    FSR, F
        incf    RESP_BUF_LEN, F
        return
        ; end enqueue_byte

irq:
        movwf   IRQ_W
        swapf   STATUS, W
        movwf   IRQ_STATUS

        btfsc   PIR1, TXIF
        call    tx_ready
        btfsc   PIR1, TMR1IF
        call    timer_expired

        swapf   IRQ_STATUS, W
        movwf   STATUS
        swapf   IRQ_W, F
        swapf   IRQ_W, W
        retfie
        ; end of irq

timer_expired:
        bsf     STATUS, RP0
        movfw   PIE1^0x80
        bcf     STATUS, RP0
        movwf   0x20
        btfss   0x20, TMR1IE
        return

        ; clear and disable interrupt
        bsf     STATUS, RP0
        bcf     PIE1^0x80, TMR1IE
        bcf     STATUS, RP0
        bcf     PIR1, TMR1IF

        ; assert SRQ
        bcf     PORTB, 5
        bsf     STATUS, RP0
        bcf     TRISB^0x80, 5
        bcf     STATUS, RP0
        return
        ; end of timer_expired

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
        movfw   UART_BUF
        movwf   TXREG
        return
        ; end of tx_ready

        end
