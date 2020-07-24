camera=C1
for date in "$@"
do
  ls $date/*/*/*${camera}o.fits.txt >/dev/null 2>&1 &&
  awk -vdate=$date '
  BEGIN {
    pi = 4.0 * atan2(1.0, 1.0);
  }
  function cosd(x) {
    return cos(x * pi / 180.0);
  }
  FNR == 1 {
    nemtra = "";
    nemtde = "";
    semtra = "";
    semtde = "";
  }
  $1 == "ENEMTRA" { nemtra = $3; }
  $1 == "ENEMTDE" { nemtde = $3; }
  $1 == "ESEMTRA" { semtra = $3; }
  $1 == "ESEMTDE" { semtde = $3; }
  $1 == "END" {
    if (nemtra != "" && nemtde != "" && semtra != "" && semtde != "") {
      dra = nemtra - semtra;
      de = dra * cosd(nemtde);
      dn = nemtde - semtde;
      # printf("%s %s %s %s %+.1f %+.1f\n", nemtra, semtra, nemtde, semtde, de * 3600.0, dn * 3600.0);
      s   += 1;
      se  += de;
      see += de * de;
      sn  += dn;
      snn += dn * dn;
    }
  }
  END {
    if (s > 0) {
      printf("%s-%s-%s", substr(date, 1, 4), substr(date, 5, 2), substr(date, 7, 2));
      printf(", %3d", s);
      me = se / s;
      mn = sn / s;
      ve = see / s - me * me;
      vn = snn / s - mn * mn;
      if (ve < 0.0)
        ve = 0.0;
      if (vn < 0.0)
        vn = 0.0;      
      printf(", %5.1f, %5.1f", me * 3600.0, sqrt(ve) * 3600.0);
      printf(", %5.1f, %5.1f", mn * 3600.0, sqrt(vn) * 3600.0);
      printf("\n");
    }
  }
  ' $date/*/*/*${camera}o.fits.txt
done
