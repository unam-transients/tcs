ABSOLUTE=1 make
sh map.sh   0 coatli/20211103b.txt | tee coatli/20211103b-0.txt | sed -n '/RMS/p;/^Fit:/,$p'
sh map.sh 180 coatli/20211103b.txt | tee coatli/20211103b-180.txt | sed -n '/RMS/p;/^Fit:/,$p'
