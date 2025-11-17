# mountopentsi

## Derotator

Current behavior as of 2025-11-17.

We get the derotator position from `POSITION.INSTRUMENTAL.DEROTATOR[3].REALPOS` where the index is 2 for OGSE and 3 for DDRAGO. `REALPOS` is the true position of the mechanism.

We park by setting `POSITION.INSTRUMENTAL.DEROTATOR[3].TARGETPOS`. The value is -50 for DDRAGO. This then gives a `REALPOS` of -34.15 (which is -50 + 15.85).

We align the instrument on the sky by setting `POSITION.INSTRUMENTAL.DEROTATOR[3].OFFSET`. The value is 15.85 for DDRAGO.

Current derotator positions for DDRAGO are:

|alpha|delta|rotation|
|---|---|---|
|parked|parked|-34.15d|
|unparked|unparked|-16.15d|
|+6h|+60d|+25.55d|
|+0h|+60d|-13.20d|
|-6h|+60d|+59.13d|
|-4h|+0d|-13.89d|
|+0h|+0d|-15.08d|
|+4h|+0d|+6.40d|
|+0h|-30d|-45.10d|
