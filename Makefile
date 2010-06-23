
all: changer.hex

%.hex: %.asm
	gpasm -i $<

.PHONY: clean

clean:
	rm *.hex *.lst *.cod
