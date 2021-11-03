sh map.sh   0 coatlioan/20211103a.txt | tee coatlioan/20211103a-0.txt | sed -n '/RMS/p;/^Fit:/,$p'
sh map.sh 180 coatlioan/20211103a.txt | tee coatlioan/20211103a-180.txt | sed -n '/RMS/p;/^Fit:/,$p'
