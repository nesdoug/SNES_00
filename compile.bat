@echo off

set name="SNES_00"

set path=%path%;..\bin\

set CC65_HOME=..\

ca65 mainB.asm -g

ld65 -C lorom256k.cfg -o %name%.sfc mainB.o -Ln labels.txt

pause

del *.o

