#!/bin/sh

cd /usr/local/var/ddoti/

exec >direct.html.new

cat <<"EOF"
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
<link rel="stylesheet" href="../style.css" type="text/css"/>
<meta name=viewport content="width=device-width, initial-scale=1">
<title>
DDOTI: Pipeline Analysis
</title>
</head>
<body>
<div id="header">
<p><a href="http://transients.astrossp.unam.mx/">Home</a>
<hr/>
<h1>DDOTI: Pipeline Analysis</h1>
<hr/>
</div>
<div id="main">
EOF

for date in $(ls | grep '^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$' | sort -nr | head -30)
do
  echo $date
  rsync --ignore-missing-args /nas/archive-ddoti/raw/$date/log/error.txt   $date/log/
  rsync --ignore-missing-args /nas/archive-ddoti/raw/$date/log/warning.txt $date/log/
  rsync --ignore-missing-args /nas/archive-ddoti/raw/$date/log/summary.txt $date/log/
  rsync --ignore-missing-args /nas/archive-ddoti/raw/$date/log/info.txt    $date/log/
done |
while read date
do
  echo $date
  find $date -mindepth 2 -maxdepth 2 -type d | grep -- '-1' | sed 's:/: :g' | sort
  find $date -mindepth 3 -maxdepth 3 -type d | grep -- '-2' | sed 's:/: :g' | sort
  find $date -mindepth 2 -maxdepth 2 -type d | grep -- '-3' | sed 's:/: :g' | sort
done |
awk '

BEGIN {
  printf("<ul>\n");
  firstdate = 1;
}
NF == 1 {
  if (!firstdate) {
    printf("    </ul>\n");
    printf("  </li>\n");
  }
  firstdate = 0;
  printf("  <li>%s:\n", $1);
  printf("    <ul>\n");
  printf("      <li>")
  printf("        <a href=\"%s\">Info</a>", $1 "/log/info.txt");
  printf("        <a href=\"%s\">Summary</a>", $1 "/log/summary.txt");
  printf("        <a href=\"%s\">Warning</a>", $1 "/log/warning.txt");
  printf("        <a href=\"%s\">Error</a>", $1 "/log/error.txt");
  printf("      </li>\n");
}
NF == 3 {
  printf("      <li><a href=\"%s/%s/%s\">%s/%s</a></li>", $1, $2, $3, $2, $3)
}
NF == 4 {
  printf("      <li><a href=\"%s/%s/%s/%s\">%s/%s/%s</a></li>", $1, $2, $3, $4, $2, $3, $4)
}
END {
  printf("    </ul>\n");
  printf("  </li>\n");
  printf("  <li><a href=\"./\">All</a></li>\n");
  printf("</ul>\n");
}
'

cat <<"EOF"
</div>
<div id="footer">
<hr/>
<p><a href="http://transients.astrossp.unam.mx/">Home</a>

<p>Copyright © 2020 <a href="mailto:alan@astro.unam.mx">Alan M. Watson</a>.</p>
</div>
</body>
</html>
EOF

mv direct.html.new direct.html
