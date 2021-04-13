make clean
ABSOLUTE=0 make
sh relative.sh ratiroan/20210409ne.txt ratiroan/20210409C1.txt | ./fitmodel | tee ratiroan/20210409neC1.log
sh relative.sh ratiroan/20210409se.txt ratiroan/20210409C1.txt | ./fitmodel | tee ratiroan/20210409seC1.log
make clean
ABSOLUTE=1 make
sh select.sh 0 ratiroan/20210409C1.txt | ./fitmodel | tee ratiroan/20210409C1.log
