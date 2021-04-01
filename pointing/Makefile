CC	=	clang -std=c99
CCOPTS	=	-O -Wall

fitmodel	: fitmodel.c nrutil.o amoeba.o amotry.o
	$(CC) $(CCGFLAGS) -O -o fitmodel fitmodel.c nrutil.o amoeba.o amotry.o -lm

nrutil.o	:	nrutil.c
	$(CC) -c nrutil.c
amoeba.o	:	amoeba.c
	$(CC) -c amoeba.c
amotry.o	:	amotry.c
	$(CC) -c amotry.c
