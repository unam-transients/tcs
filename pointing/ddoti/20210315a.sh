sh map.sh   0 ddoti/20210315a.txt | tee ddoti/20210315a-0.txt | sed -n '/RMS/p;/^Fit:/,$p'
sh map.sh 180 ddoti/20210315a.txt | tee ddoti/20210315a-180.txt | sed -n '/RMS/p;/^Fit:/,$p'
