	processor 16f648a
        include "p16f648a.inc"
        __CONFIG _HS_OSC

        org 0
        goto main

main:
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
