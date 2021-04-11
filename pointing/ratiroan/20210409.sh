make clean
ABSOLUTE=0 make
sh relative.sh ratiroan/20210409C1.txt ratiroan/20210409ne.txt | ./fitmodel | tee ratiroan/20210409C1ne.log
sh relative.sh ratiroan/20210409C1.txt ratiroan/20210409se.txt | ./fitmodel | tee ratiroan/20210409C1se.log
make clean
ABSOLUTE=1 make
sh select.sh 0 ratiroan/20210409C1.txt | ./fitmodel | tee ratiroan/20210409C1.log
