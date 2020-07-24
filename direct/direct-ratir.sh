#!/bin/sh

cd /usr/local/var/ratir

exec >direct.html.new

cat <<"EOF"
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
<link rel="stylesheet" href="../style.css" type="text/css"/>
<meta name=viewport content="width=device-width, initial-scale=1">
<title>
RATIR: Pipeline Analysis
</title>
</head>
<body>
<div id="header">
<p><a href="http://transients.astrossp.unam.mx/">Home</a>
<hr/>
<h1>RATIR: Pipeline Analysis</h1>
<hr/>
</div>
<div id="main">
EOF

for date in $(ls | grep '^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$' | sort -nr | head -30)
do
  echo $date
  find -L $date -maxdepth 4 -name index.html |
  sed '
    s:/version:/:
    s:/: :g
  ' | 
  sort -k1,3 -k4g -s
done |
awk '
BEGIN {
  printf("<ul>\n");
  firstdate = 1;
  firsttarget = 1;
}
NF == 1 {
  if (!firsttarget)
    printf("</li>\n  </ul>\n");
  if (!firstdate)
    printf("</li>\n");
  firstdate = 0;
  printf("<li>%s:", $1);
  firsttarget = 1;
}
NF > 1 && $4 == "latest_version" {
  if (firsttarget)
    printf("\n  <ul>\n");
  else
    printf("</li>\n");
  firsttarget = 0;
  url = $1 "/" $2 "/" $3 "/" $4 "/";
  printf("  <li>%s: <a href=\"%s\">latest</a>", $3, url);
}
NF > 1 && $4 != "latest_version" {
  url = $1 "/" $2 "/" $3 "/version" $4 "/";
  printf(" <a href=\"%s\">%s</a>", url, $4);
}
END {
  printf("</ul>\n");
  printf("<li><a href=\"./\">All</a></li>\n");
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
