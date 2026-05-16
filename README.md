# ili9341-spin 
--------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the ILI9341 LCD controller

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.


## Salient Features

* 8-bit Parallel connection
* 16bpp color depth
* Integration with generic bitmap graphics library
* Display mirroring (vertical/horizontal) and rotation (landscape/portrait up/down)
* Buffered display support (P2 only)


## Requirements

P1/SPIN1:
* 1 extra core/cog for the parallel I/O engine
* spin-standard-library
* graphics.common.spinh (provided by spin-standard-library)


P2/SPIN2:
* 1 extra core/cog for the parallel I/O engine
* p2-spin-standard-library
* graphics.common.spin2h (provided by p2-spin-standard-library)
* 150kB of RAM for the framebuffer, if using buffered mode


## Compiler Compatibility

| Processor | Language | Compiler               | Backend      | Status                |
|-----------|----------|------------------------|--------------|-----------------------|
| P1        | SPIN1    | FlexSpin (7.6.5)       | Bytecode     | OK                    |
| P1        | SPIN1    | FlexSpin (7.6.5)       | Native/PASM  | OK                    |
| P2        | SPIN2    | FlexSpin (7.6.5)       | NuCode       | Runtime issues        |
| P2        | SPIN2    | FlexSpin (7.6.5)       | Native/PASM2 | OK                    |

(other versions or toolchains not listed are __not supported__, and _may or may not_ work)


## Hardware compatibility

Tested with:
* Adafruit 2.8" LCD (#1770)
* Adafruit 3.2" LCD (#1743)
* HiLetGo 2.4" (#2160039)


## Limitations

* Not optimized
* 18bpp color depth not supported (unplanned, for now)
* Buffered display unsupported on the P1

