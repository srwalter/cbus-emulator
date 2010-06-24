	processor 16f648a
        include "p16f648a.inc"
        __CONFIG _HS_OSC

        CONSTANT IRQ_W=0x7f
        CONSTANT IRQ_STATUS=0x7e

        org 0
        goto main
        nop
        nop
        nop
        goto irq

main:
        bsf     STATUS, RP0
        bsf     TRISB, 1
        bsf     TRISB, 2
        bsf     TRISB, 4
        bsf     TRISB, 5
        bsf     TXSTA, TXEN
        bcf     STATUS, RP0

        movlw   0xf ; 19200 @ 20MHz
        bcf     RCSTA, SYNC
        bsf     RCSTA, SPEN

        bsf     STATUS, GIE
        bcf     STATUS, RBIF
        bsf     STATUS, RBIE

        nop
        goto $-1

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

        btfsc   STATUS, RBIF
        call    bus_activity
        ;btfsc   PIR1, TXIF
        ;call    tx_ready

        swapf   IRQ_STATUS, W
        movwf   STATUS
        swapf   IRQ_W, F
        swapf   IRQ_W, W
        retfie
        ; end of irq

bus_activity:
        bcf     STATUS, RBIF
        call    decode_burst
        movwf   TXREG
        return
        ; end of bus_activity

tx_ready:
        bsf     STATUS, RP0
        movfw   PIE1
        bcf     STATUS, RP0
        movwf   0x20
        btfss   0x20, TXIE
        return

        nop
        return
        ; end of tx_ready

        end
