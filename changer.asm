	processor 16f648a
        include "p16f648a.inc"
        __CONFIG _HS_OSC

        org 0
        goto main

main:
        nop
        goto $-1
        end

        macro test_clk
        btf     PORTB, 0
        endm

        macro wait_clk_low
        test_clk
        skpz
        goto $-2
        endm

        macro wait_clk_high
        test_clk
        skpnz
        goto $-2
        endm

        macro test_data
        btf     PORTB, 1
        endm

        macro wait_data_low
        test_clk
        skpz
        goto $-2
        endm

        macro wait_data_high
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

        rolf    0x20, F
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
        ret
        ; end decode_burst
