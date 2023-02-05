sh map.sh   0 coatli/20211103a.txt | tee coatli/20211103a-0.txt | sed -n '/RMS/p;/^Fit:/,$p'
sh map.sh 180 coatli/20211103a.txt | tee coatli/20211103a-180.txt | sed -n '/RMS/p;/^Fit:/,$p'
