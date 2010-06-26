
all: changer.hex

%.o: %.asm
	gpasm -c $<

%.hex: %.o
	gplink --map -s 16f648a.lkr -o $@ $<

.PHONY: clean

clean:
	rm *.hex *.lst *.cod
