#!/bin/sh

cd /usr/local/var/coatli/

exec >direct.html.new

cat <<"EOF"
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
<link rel="stylesheet" href="../style.css" type="text/css"/>
<meta name=viewport content="width=device-width, initial-scale=1">
<title>
COATLI: Pipeline Analysis
</title>
</head>
<body>
<div id="header">
<p><a href="http://transients.astrossp.unam.mx/">Home</a>
<hr/>
<h1>COATLI: Pipeline Analysis</h1>
<hr/>
</div>
<div id="main">
EOF

for date in $(ls | grep '^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$' | sort -nr | head -30)
do
  echo $date
  rsync --ignore-missing-args /nas/archive-coatli/raw/$date/log/error.txt   $date/log/
  rsync --ignore-missing-args /nas/archive-coatli/raw/$date/log/warning.txt $date/log/
  rsync --ignore-missing-args /nas/archive-coatli/raw/$date/log/summary.txt $date/log/
  rsync --ignore-missing-args /nas/archive-coatli/raw/$date/log/info.txt    $date/log/
  find -L $date -maxdepth 4 -name "*.html" |
  awk -F/ '{ print $0, $5 }' |
  sed '
    s:/: :g
    s:stack[^ ]*_::
    s:.html::
  ' | 
  sort -k1,4 -k5g -s
done |
awk '

function printfilter(filter)
{
  if (url[filter] != "")
    printf(" <a href=\"%s\">%s</a>", url[filter], filter);
}

function printvisit()
{
  if (visit != "") {
    printf("<li><a href=\"%s\">%s</a>:", visiturl, visit);
    printfilter("BB");
    printfilter("BV");
    printfilter("BR");
    printfilter("BI");
    printfilter("w");
    printf("</li>\n");
  }
  url["BB"] = "";
  url["BV"] = "";
  url["BR"] = "";
  url["BI"] = "";
  url["w"] = "";
}

BEGIN {
  printf("<ul>\n");
  firstdate = 1;
}
NF == 1 {
  if (!firstdate) {
    printvisit();
    printf("</li>\n");
    printf("  </ul>\n")
  }
  visit = "";
  firstdate = 0;
  printf("  <li>%s:", $1);
  printf("  <ul>\n");
  printf("    <li>Log:")
  printf(" <a href=\"%s\">Info</a>", $1 "/log/info.txt");
  printf(" <a href=\"%s\">Summary</a>", $1 "/log/summary.txt");
  printf(" <a href=\"%s\">Warning</a>", $1 "/log/warning.txt");
  printf(" <a href=\"%s\">Error</a>", $1 "/log/error.txt");
}
NF > 1 && /_w_/  { filter = "w" ; }
NF > 1 && /_BB_/ { filter = "BB"; }
NF > 1 && /_BV_/ { filter = "BV"; }
NF > 1 && /_BR_/ { filter = "BR"; }
NF > 1 && /_BI_/ { filter = "BI"; }
NF > 1 && $5 != "current" {
  newvisit = $2 "/" $3 "/" $4;
  if (newvisit != visit)
    printvisit();
  visit = newvisit;
  visiturl = $1 "/" $2 "/" $3 "/" $4 "/";
  url[filter] = $1 "/" $2 "/" $3 "/" $4 "/" $6;
}
END {
  printvisit();
  printf("</li>\n");
  printf("  </ul>\n");
  printf("  <li><a href=\"./\">All</a></li>\n");
  printf("</ul>\n");
}
'

cat <<"EOF"
</div>
<div id="footer">
<hr/>
<p><a href="http://transients.astrossp.unam.mx/">Home</a>

<p>Copyright © 2018 <a href="mailto:alan@astro.unam.mx">Alan M. Watson</a>.</p>
</div>
</body>
</html>
EOF

mv direct.html.new direct.html
