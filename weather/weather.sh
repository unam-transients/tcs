#!/bin/sh

cd $(dirname $0)

rsync -ah alan@ratir.astroscu.unam.mx:/mnt/volume/archive-ddoti/raw/weather* .

for stationid in a b
do
  rm -rf $stationid
  cd weather-$stationid
  for file in $(ls ARC-*.txt | sort -r)
  do
    echo $file
    date=$(echo $file | sed 's/ARC-//;s/-//g;s/.txt//')
    mkdir -p ../$stationid/$date/sensors/
    sed '/^-/d' $file |
    awk -v stationid=$stationid '
    
    BEGIN {
      if (stationid == "a") {
        model = "Vaisala";
      } else {
        model = "Davis"
      }
    }
    
    function sensor(file, value, unit, name, comma) {
      prettyname = name;
      gsub("-", " ", prettyname);
      printf "    {\n" >>file;
      printf "      \"name\": \"weather-station-%s-%s\",\n", stationid, name >>file;
      printf "      \"value\": \"%s\",\n", value >>file;
      printf "      \"date\": \"%s\",\n", date >>file;
      printf "      \"pretty_name\": \"weather station %s %s\",\n", stationid, prettyname >>file;
      printf "      \"model\": \"%s\",\n", model >>file;
      printf "      \"identifier\": \"%s\",\n", stationid >>file;
      printf "      \"firmware\": \"\",\n" >>file;
      printf "      \"type\": \"\",\n" >>file;
      printf "      \"unit\": \"%s\",\n", unit >>file;
      printf "      \"correction_model\": \"\",\n" >>file;
      printf "      \"raw_value\": \"%s\",\n", value >>file;
      printf "      \"error-code\": \"0\"\n" >>file;
      printf "    }\n" >>file;
      if (comma) {
        printf "    ,\n" >>file;
      }
    }
    
    {

      year   = int(substr($1, 1, 4));
      month  = int(substr($1, 5, 2));
      day    = int(substr($1, 7, 2));
      hour   = int(substr($2, 1, 2));
      minute = int(substr($2, 4, 2));
      
      if (hour == 24) {
        hour = 0;
        day += 1;
        if (month == 9 || month == 4 || month == 6 || month == 11) {
          maxday = 30;
        } else if (month != 2) {
          maxday = 31;
        } else if (year % 4 == 0) {
          maxday = 29;
        } else {
          maxday = 28;        
        }
        if (day > maxday) {
          day = 1;
          month += 1;
        }
        if (month > 12) {
          month = 1;
          year += 1;
        }
      }
      
      date = sprintf("%04d-%02d-%02dT%02d:%02d:00", year, month, day, hour, minute);

      file = sprintf("../%s/%04d%02d%02d/sensors/sensors-%04d%02d%02dT%02d%02d.json", stationid, year, month, day, year, month, day, hour, minute);

      print "{" >file;
      print "  \"frame-model\": \"1.0\"," >>file;
      print "  \"producer-name\": \"TCS\"," >>file;
      print "  \"devices\": [" >>file;
      
      sensor(file, $3, "C", "temperature", 1);
      sensor(file, $6 * 0.01, "", "relative-humidity", 1);
      sensor(file, $7, "C", "dew-point", 1);
      sensor(file, $3 - $7, "C", "dew-point-depression", 1);
      sensor(file, $8, "km/h", "wind-average-speed", 1);
      sensor(file, $9, "km/h", "wind-gust-speed", 1);
      sensor(file, $10, "deg", "wind-average-azimuth", 1);
      sensor(file, $11, "mm/?", "rain-rate", 1);
      sensor(file, $12, "mbar", "pressure", 0);
      
      print "  ]" >>file;
      print "}" >>file;

      close(file);

    }
    '
  done
  cd ..
done
