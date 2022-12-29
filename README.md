# ili9341-spin 
--------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the ILI9341 LCD controller

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* 8-bit Parallel connection
* Integration with generic bitmap graphics library
* Display mirroring (vertical/horizontal) and rotation (landscape/portrait up/down)

## Requirements

P1/SPIN1:
* 1 extra core/cog for the parallel I/O engine
* spin-standard-library
* graphics.common.spinh (provided by spin-standard-library)

P2/SPIN2:
* 1 extra core/cog for the parallel I/O engine
* p2-spin-standard-library
* graphics.common.spin2h (provided by p2-spin-standard-library)

## Compiler Compatibility

| Processor | Language | Compiler               | Backend     | Status                |
|-----------|----------|------------------------|-------------|-----------------------|
| P1        | SPIN1    | FlexSpin (5.9.23-beta) | Bytecode    | OK                    |
| P1        | SPIN1    | FlexSpin (5.9.23-beta) | Native code | OK                    |
| P1        | SPIN1    | OpenSpin (1.00.81)     | Bytecode    | Untested (deprecated) |
| P2        | SPIN2    | FlexSpin (5.9.23-beta) | NuCode      | Untested              |
| P2        | SPIN2    | FlexSpin (5.9.23-beta) | Native code | OK                    |
| P1        | SPIN1    | Brad's Spin Tool (any) | Bytecode    | Unsupported           |
| P1, P2    | SPIN1, 2 | Propeller Tool (any)   | Bytecode    | Unsupported           |
| P1, P2    | SPIN1, 2 | PNut (any)             | Bytecode    | Unsupported           |

## Limitations

* Very early in development - may malfunction, or outright fail to build
* Not optimized

