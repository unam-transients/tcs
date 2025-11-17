# mountopentsi

## Derotator

Current behavior as of 2025-11-17.

We get the derotator position from `POSITION.INSTRUMENTAL.DEROTATOR[3].REALPOS` where the index is 2 for OGSE and 3 for DDRAGO. `REALPOS` is the true position of the mechanism.

We park by setting `POSITION.INSTRUMENTAL.DEROTATOR[3].TARGETPOS`. The value is -50 for DDRAGO. This then gives a `REALPOS` of -34.15 (which is -50 + 15.85).

We align the instrument on the sky by setting `POSITION.INSTRUMENTAL.DEROTATOR[3].OFFSET`. The value is 15.85 for DDRAGO.

Current derotator positions for DDRAGO are:

|alpha|delta|rotation|
|---|---|---|
|parked|parked|+20.43d|
|unparked|unparked|-2.00d|
|+6h|+60d|+39.70d|
|+0h|+60d|+0.93d|
|-6h|+60d|-16.72d|
|-4h|+0d|+0.24d|
|+0h|+0d|-0.95d|
|+4h|+0d|+20.53d|
|+0h|-30d|-30.95d|
