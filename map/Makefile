exes	=	map
objs	=	*.8

all	:	$(exes)

clean	:
	rm -f $(exes) $(objs)

map	:	map.go
	8g map.go
	8l -o map map.8

