{
    --------------------------------------------
    Filename: display.lcd.ili9341.spin
    Author: Jesse Burt
    Description: Driver for ILI9341 LCD controllers
    Copyright (c) 2022
    Started Oct 14, 2021
    Updated Feb 20, 2022
    See end of file for terms of use.
    --------------------------------------------
}

' memory usage for a buffered display would vastly exceed what's available
'   on the P1, so hardcode direct-to-display directive:
#define GFX_DIRECT
#include "lib.gfx.bitmap.spin"

CON

    MAX_COLOR       = 65535
    BYTESPERPX      = 2

' Display visibility modes
    ALL_OFF         = 0
    OFF             = 0
    NORMAL          = 1
    ON              = 1
    INVERTED        = 2
    ALL_ON          = 3

' Subpixel order
    RGB             = 0
    BGR             = 1

' Display refresh direction
    NORM            = 0
    INV             = 1

' Character attributes
    DRAWBG          = 1 << 0

' Internal use
    VMH             = 0
    VML             = 1

    CLK_DIV         = 0                         ' FRMCTR1
    FRM_RT          = 1

OBJ

    time: "time"                                ' timekeeping methods
    core: "core.con.ili9341"                    ' HW-specific constants
    com : "com.parallel-8bit"                   ' 8-bit Parallel I/O engine

VAR

    byte _RESET

    ' shadow registers
    word _vcomh, _vcoml
    byte _madctl, _pwr_ctrl2, _vmctrl1[2], _vcomoffs, _colmod, _frmctr1[2]
    byte _g3ctrl

PUB Startx(DATA_BASEPIN, RES_PIN, CS_PIN, DC_PIN, WR_PIN, RD_PIN, WIDTH, HEIGHT): status
' Start driver using custom I/O settings
'   DATA_BASEPIN: first (lowest) pin of 8 data pin block (must be contiguous)
'   RES_PIN: display's hardware reset pin (optional, -1 to ignore)
'   CS_PIN: Chip Select
'   DC_PIN: Data/Command (sometimes labeled RS, or Register Select)
'   WR_PIN: Write clock
'   RD_PIN: Read clock (not currently implemented; ignored)
'   WIDTH, HEIGHT: display dimensions, in pixels
    if lookdown(DATA_BASEPIN: 0..24) and lookdown(CS_PIN: 0..31) and {
}   lookdown(DC_PIN: 0..31) and lookdown(WR_PIN: 0..31)
        if (status := com.init(DATA_BASEPIN, CS_PIN, DC_PIN, WR_PIN, RD_PIN))
            _RESET := RES_PIN
            _disp_width := WIDTH
            _disp_height := HEIGHT
            _disp_xmax := _disp_width - 1
            _disp_ymax := _disp_height - 1
            _buff_sz := (_disp_width * _disp_height)
            _bytesperln := _disp_width * BYTESPERPX
            reset{}

PUB Preset{}
' Preset settings
    reset{}
    time.msleep(5)

    displayvisibility(OFF)
    gvddvoltage(4_750)
    vghstepfactor(7)
    vglstepfactor(3)
    vcomhvoltage(5_000)
    vcomlvoltage(-0_600)
    vcomoffset(-44)

    mirrorv(false)
    mirrorh(false)
    displayrotate(false)
    vertrefreshdir(NORM)
    subpixelorder(RGB)
    horizrefreshdir(NORM)

    colordepth(16)

    clkdiv(1)
    framerate(70)

    gamma3chctrl(false)
    gammafixedcurve(2_2)                        ' param ignored; for symbolic purpose only
    gammatablen(@_gammatbl_neg)
    gammatablep(@_gammatbl_pos)

    displaybounds(0, 0, 239, 319)

' xxx todo
    ' com.wrbyte_cmd($34) ' tearing effect off
    'com.wrbyte_cmd($35) ' tearing effect on
    'com.wrbyte_cmd($b4) ' display inversion
    'com.wrbyte_dat($00)
    com.wrbyte_cmd(core#DFUNCTR) ' display function control
    com.wrbyte_dat($0a)
    com.wrbyte_dat($82)
    com.wrbyte_dat($27)
    com.wrbyte_dat($00)
' xxx

    powered(true)
    displayvisibility(NORMAL)

PUB Stop{}
' Power off the display, and stop the engine
    powered(false)
    com.deinit{}

PUB Bitmap(ptr_bmap, sx, sy, ex, ey) | nr_words
' Draw bitmap
'   ptr_bmap: pointer to bitmap data
'   (sx, sy): upper-left corner of bitmap
'   (ex, ey): lower-right corner of bitmap
'   nr_words: number of 16-bit words to read/draw from bitmap
    displaybounds(sx, sy, ex, ey)
    nr_words := 1 #> ( (ex-sx) * (ey-sy) ) / BYTESPERPX
    com.wrbyte_cmd(core#RAMWR)
    com.wrblkword_msbf(ptr_bmap, nr_words)

PUB Box(x1, y1, x2, y2, color, filled) | xt, yt
' Draw a box from (x1, y1) to (x2, y2) in color, optionally filled
    xt := ||(x2-x1)+1
    yt := ||(y2-y1)+1
    if filled
        displaybounds(x1, y1, x2, y2)
        com.wrbyte_cmd(core#RAMWR)
        com.wrwordx_dat(color, (yt * xt))
    else
        displaybounds(x1, y1, x2, y1)           ' top
        com.wrbyte_cmd(core#RAMWR)
        com.wrwordx_dat(color, xt)

        displaybounds(x1, y2, x2, y2)           ' bottom
        com.wrbyte_cmd(core#RAMWR)
        com.wrwordx_dat(color, xt)

        displaybounds(x1, y1, x1, y2)           ' left
        com.wrbyte_cmd(core#RAMWR)
        com.wrwordx_dat(color, yt)

        displaybounds(x2, y1, x2, y2)           ' right
        com.wrbyte_cmd(core#RAMWR)
        com.wrwordx_dat(color, yt)

PUB Char(ch) | gl_c, gl_r, lastgl_c, lastgl_r
' Draw character from currently loaded font
    lastgl_c := _font_width-1
    lastgl_r := _font_height-1
    case ch
        CR:
            _charpx_x := 0
        LF:
            _charpx_y += _charcell_h
            if _charpx_y > _charpx_xmax
                _charpx_y := 0
        0..127:                                 ' validate ASCII code
            ' walk through font glyph data
            repeat gl_c from 0 to lastgl_c      ' column
                repeat gl_r from 0 to lastgl_r  ' row
                    ' if the current offset in the glyph is a set bit, draw it
                    if byte[_font_addr][(ch << 3) + gl_c] & (|< gl_r)
                        plot((_charpx_x + gl_c), (_charpx_y + gl_r), _fgcolor)
                    else
                    ' otherwise, draw the background color, if enabled
                        if _char_attrs & DRAWBG
                            plot((_charpx_x + gl_c), (_charpx_y + gl_r), _bgcolor)
            ' move the cursor to the next column, wrapping around to the left,
            ' and wrap around to the top of the display if the bottom is reached
            _charpx_x += _charcell_w
            if _charpx_x > _charpx_xmax
                _charpx_x := 0
                _charpx_y += _charcell_h
            if _charpx_y > _charpx_ymax
                _charpx_y := 0
        other:
            return

PUB Clear{}
' Clear display
    displaybounds(0, 0, _disp_xmax, _disp_ymax)
    com.wrbyte_cmd(core#RAMWR)
    com.wrwordx_dat(_bgcolor, _buff_sz)

PUB ClkDiv(cdiv): curr_cdiv
' Set LCD clock divisor
'   Valid values: 1, 2, 4, 8
'   Any other value returns the current (cached) setting
    case cdiv
        1, 2, 4, 8:
            _frmctr1[CLK_DIV] := lookdownz(cdiv: 1, 2, 4, 8)
            com.wrbyte_cmd(core#FRMCTR1)
            com.wrbyte_dat(_frmctr1[CLK_DIV])
            com.wrbyte_dat(_frmctr1[FRM_RT])
        other:
            return lookupz(_frmctr1[CLK_DIV]: 1, 2, 4, 8)

PUB ColorDepth(cbpp): curr_cbpp
' Set display color depth, in bits per pixel
'   Valid values: 16, 18
'   Any other value returns the current (cached) setting
    case cbpp
        16:
            _colmod := $55
        18:
            _colmod := $66
        other:
            if (_colmod == $55)
                return 16
            elseif (_colmod == $66)
                return 18

    com.wrbyte_cmd(core#COLMOD)
    com.wrbyte_dat(_colmod)

PUB Contrast(c)

PUB DisplayBounds(x1, y1, x2, y2) | x, y, cmd_pkt[2]
' Set drawing area for subsequent drawing command(s)
    if x2 < x1                                  ' x2 must be greater than x1
        x := x2                                 ' if it isn't, swap them
        x2 := x1
        x1 := x
    if y2 < y1                                  ' same as above, for y2, y1
        y := y2
        y2 := y1
        y1 := y

    cmd_pkt.byte[0] := x1.byte[1]
    cmd_pkt.byte[1] := x1.byte[0]
    cmd_pkt.byte[2] := x2.byte[1]
    cmd_pkt.byte[3] := x2.byte[0]
    cmd_pkt.byte[4] := y1.byte[1]
    cmd_pkt.byte[5] := y1.byte[0]
    cmd_pkt.byte[6] := y2.byte[1]
    cmd_pkt.byte[7] := y2.byte[0]

    com.wrbyte_cmd(core#CASET)
    com.wrblock_dat(@cmd_pkt.byte[0], 4)

    com.wrbyte_cmd(core#PASET)
    com.wrblock_dat(@cmd_pkt.byte[4], 4)

PUB DisplayInverted(state)
' Invert display colors
'   Valid values:
'       TRUE (-1 or 1), FALSE (0)
'   Any other value is ignored
    case ||(state)
        0, 1:
            com.wrbyte_cmd(core#INVOFF + ||(state))

PUB DisplayRotate(state): curr_state
' Rotate display
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value returns the current setting
    curr_state := _madctl
    case ||(state)
        0, 1:
            state := ||(state) << core#MV
        other:
            return (((curr_state >> core#MV) & 1) == 1)

    _madctl := ((curr_state & core#MV_MASK) | state)
    com.wrbyte_cmd(core#MADCTL)
    com.wrbyte_dat(_madctl)

PUB DisplayVisibility(state): curr_state
' Set display visibility
'   Valid values:
'       ALL_OFF/OFF (0), NORMAL/ON (1), ALL_ON (3)
'   Any other value is ignored
'   NOTE: Does not affect the display RAM contents
    case state
        OFF:
            com.wrbyte_cmd(core#DISPOFF)
        ON:
            com.wrbyte_cmd(core#ETMOD)
            com.wrbyte_dat(core#GDR_NORM)
            com.wrbyte_cmd(core#DISPON)
        ALL_ON:
            com.wrbyte_cmd(core#ETMOD)
            com.wrbyte_dat(core#GDR_VGH)
        other:

PUB FrameRate(frate): curr_frate
' Set LCD maximum frame rate, in Hz
'   Valid values: 61, 63, 65, 68, 70, 73, 76, 79, 83, 86, 90, 95, 100, 106,
'                   112, 119
'   Any other value returns the current (cached) setting
'   NOTE: This setting only affects the display when operating in NORMAL mode
    case frate
        61, 63, 65, 68, 70, 73, 76, 79, 83, 86, 90, 95, 100, 106, 112, 119:
            _frmctr1[FRM_RT] := lookdownz(frate: 119, 112, 106, 100, 95, 90, {
}           86, 83, 79, 76, 73, 70, 68, 65, 63, 61)
            com.wrbyte_cmd(core#FRMCTR1)
            com.wrbyte_dat(_frmctr1[CLK_DIV])
            com.wrbyte_dat(_frmctr1[FRM_RT])
        other:
            return lookupz(_frmctr1[FRM_RT]: 119, 112, 106, 100, 95, 90, 86, {
}           83, 79, 76, 73, 70, 68, 65, 63, 61)

PUB Gamma3ChCtrl(state): curr_state
' Enable 3-gamma control
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value returns the current (cached) setting
    case ||(state)
        0, 1:
            _g3ctrl := %10 | ||(state)
            com.wrbyte_cmd(core#GM3CTRL)
            com.wrbyte_dat(_g3ctrl)
        other:
            return ((_g3ctrl & 1) == 1)

PUB GammaFixedCurve(prest): curr_prest
' Set gamma curve preset
'   NOTE: Parameter is ignored; for API compatibility with other drivers
    com.wrbyte_cmd(core#GAMMASET)
    com.wrbyte_dat($01)

PUB GammaTableN(ptr_buff)
' Modify gamma table (negative polarity)
    com.wrbyte_cmd(core#GMCTRN1)
    com.wrblock_dat(ptr_buff, 15)

PUB GammaTableP(ptr_buff)
' Modify gamma table (positive polarity)
    com.wrbyte_cmd(core#GMCTRP1)
    com.wrblock_dat(ptr_buff, 15)

PUB GVDDVoltage(v): curr_v
' Set GVDD level, in millivolts
'   (reference level for VCOM and grayscale voltage level)
'   Valid values: 3_000..6_000 (rounded to nearest 50mV)
    case v
        3_000..6_000:
            v := (v / 50) - 57
            com.wrbyte_cmd(core#PWCTR1)
            com.wrbyte_cmd(v)

PUB HorizRefreshDir(mode): curr_mode
' Set panel horizontal refresh direction
'   (refresh direction relative to panel's top-left (0, 0) location)
'   NORM (0): normal
'   INV (1): inverted
'   Any other value returns the current (cached) setting
    curr_mode := _madctl
    case mode
        NORM, INV:
            mode <<= core#MH
        other:
            return ((curr_mode >> core#MH) & 1)

    _madctl := ((curr_mode & core#MH_MASK) | mode)
    com.wrbyte_cmd(core#MADCTL)
    com.wrbyte_dat(_madctl)

PUB Line(x1, y1, x2, y2, color) | sx, sy, ddx, ddy, err, e2
' Draw line from (x1, y1) to (x2, y2), in color
    if (x1 == x2)
        displaybounds(x1, y1, x1, y2)           ' vertical
        com.wrbyte_cmd(core#RAMWR)
        com.wrwordx_dat(color, (||(y2-y1))+1)
        return
    if (y1 == y2)
        displaybounds(x1, y1, x2, y1)           ' horizontal
        com.wrbyte_cmd(core#RAMWR)
        com.wrwordx_dat(color, (||(x2-x1))+1)
        return

    ddx := ||(x2-x1)
    ddy := ||(y2-y1)
    err := ddx-ddy

    sx := -1
    if (x1 < x2)
        sx := 1

    sy := -1
    if (y1 < y2)
        sy := 1

    repeat until ((x1 == x2) and (y1 == y2))
        plot(x1, y1, color)
        e2 := err << 1

        if e2 > -ddy
            err -= ddy
            x1 += sx

        if e2 < ddx
            err += ddx
            y1 += sy

PUB MirrorH(state): curr_state
' Mirror display, horizontally
'   Valid values:
'       TRUE (-1 or 1), FALSE (0)
'   Any other value returns the current (cached) setting
    curr_state := _madctl
    case ||(state)
        0, 1:
            state := (||(state) ^ 1) << core#MX
        other:
            return ((((curr_state >> core#MX) & 1) == 1) ^ 1)

    _madctl := ((curr_state & core#MX_MASK) | state)
    com.wrbyte_cmd(core#MADCTL)
    com.wrbyte_dat(_madctl)

PUB MirrorV(state): curr_state
' Mirror display, vertically
'   Valid values:
'       TRUE (-1 or 1), FALSE (0)
'   Any other value returns the current (cached) setting
    curr_state := _madctl
    case ||(state)
        0, 1:
            state := ||(state) << core#MY
        other:
            return (((curr_state >> core#MY) & 1) == 1)

    _madctl := ((curr_state & core#MY_MASK) | state)
    com.wrbyte_cmd(core#MADCTL)
    com.wrbyte_dat(_madctl)

PUB Plot(x, y, color) | cmd_pkt
' Plot pixel at (x, y) in color (direct to display)
    if (x < 0 or x > _disp_xmax) or (y < 0 or y > _disp_ymax)
        return                                  ' coords out of bounds, ignore
    cmd_pkt.byte[0] := color.byte[1]
    cmd_pkt.byte[1] := color.byte[0]

    com.wrbyte_cmd(core#CASET)
    com.wrwordx_dat(x, 2)
    com.wrbyte_cmd(core#PASET)
    com.wrwordx_dat(y, 2)

    com.wrbyte_cmd(core#RAMWR)
    com.wrblock_dat(@cmd_pkt, 2)

PUB Powered(state)
' Enable display power
'   Valid values:
'       TRUE (-1 or 1), FALSE (0)
    case ||(state)
        0:
            com.wrbyte_cmd(core#DISPOFF)
            com.wrbyte_cmd(core#SLPIN)
        1:
            com.wrbyte_cmd(core#SLPOUT)
            time.msleep(60)
            com.wrbyte_cmd(core#DISPON)

PUB Reset{}
' Reset the display controller
    if lookdown(_RESET: 0..31)                  ' perform hard reset, if
        dira[_RESET] := 1                       '   I/O pin is defined
        outa[_RESET] := 1
        time.msleep(1)
        outa[_RESET] := 0
        time.msleep(10)
        outa[_RESET] := 1
        time.msleep(120)
    else                                        ' if not, just soft-reset
        com.wrbyte_cmd(core#SWRESET)
        time.msleep(5)

PUB SubpixelOrder(order): curr_ord
' Set subpixel color order
'   Valid values:
'       RGB (0): Red-Green-Blue order
'       BGR (1): Blue-Green-Red order
'   Any other value returns the current (cached) setting
    curr_ord := _madctl
    case order
        RGB, BGR:
            order <<= core#BGR
        other:
            return ((curr_ord >> core#BGR) & 1)

    _madctl := ((curr_ord & core#BGR_MASK) | order)
    com.wrbyte_cmd(core#MADCTL)
    com.wrbyte_dat(_madctl)

PUB Update
' Dummy method

PUB VCOMHVoltage(v): curr_v
' Set VCOMH voltage, in millivolts
'   Valid values: 2_700..5875 (rounded to nearest 25mV; default: 3_925)
'   Any other value returns the current (cached) setting
    case v
        2_700..5_875:
            _vmctrl1[VMH] := v := (v - 2700) / 25
            com.wrbyte_cmd(core#VMCTR1)
            com.wrbyte_dat(_vmctrl1[VMH])
            com.wrbyte_dat(_vmctrl1[VML])
        other:
            return (_vmctrl1[VMH] * 25) + 2_700

PUB VCOMLVoltage(v): curr_v
' Set VCOML voltage, in millivolts
'   Valid values: -2_500..0 (rounded to nearest 25mV; default: -1_000)
'   Any other value returns the current (cached) setting
    case v
        -2_500..0_000:
            _vmctrl1[VML] := v := (v + 2_500) / 25
            com.wrbyte_cmd(core#VMCTR1)
            com.wrbyte_dat(_vmctrl1[VMH])
            com.wrbyte_dat(_vmctrl1[VML])
        other:
            return (_vmctrl1[VML] * 25) - 2_500

PUB VCOMOffset(v): curr_v
' Set VCOMH/VCOML offset, in millivolts
'   Valid values: -63..63 (default: 0)
    curr_v := _vcomoffs
    case v
        -63..63:
            v += 64
            _vcomoffs := v
            v |= core#SETNVM                    ' must be set to adjust
            com.wrbyte_cmd(core#VMCTR2)
            com.wrbyte_dat(v)
        other:
            return (_vcomoffs-64)

PUB VertRefreshDir(mode): curr_mode
' Set panel vertical refresh direction
'   (refresh direction relative to panel's top-left (0, 0) location)
'   NORM (0): normal
'   INV (1): inverted
'   Any other value returns the current (cached) setting
    curr_mode := _madctl
    case mode
        NORM, INV:
            mode <<= core#ML
        other:
            return ((curr_mode >> core#ML) & 1)

    _madctl := ((curr_mode & core#ML_MASK) | mode)
    com.wrbyte_cmd(core#MADCTL)
    com.wrbyte_dat(_madctl)

PUB VGHStepFactor(fact): curr_fact
' Set step-up factor for VGH operating voltage (VCI * n)
'   Valid values: 6, 7
'   Any other value returns the current (cached) setting
    curr_fact := _pwr_ctrl2
    case fact
        6, 7:
            fact := lookdownz(fact: 7, 6) << 1
        other:
            return ((curr_fact >> 1) & %11)

    fact := ((curr_fact & core#VGH_MASK) | fact)
    _madctl |= (1 << 4)
    com.wrbyte_cmd(core#PWCTR2)
    com.wrbyte_dat(fact)

PUB VGLStepFactor(fact): curr_fact
' Set step-up factor for VGL operating voltage (VCI * n)
'   Valid values: 3, 4
'   Any other value returns the current (cached) setting
    curr_fact := _pwr_ctrl2
    case fact
        3, 4:
            fact := lookdownz(fact: 4, 3)
        other:
            return (curr_fact & 1)

    fact := ((curr_fact & core#VGH_MASK) | fact)
    com.wrbyte_cmd(core#PWCTR2)
    com.wrbyte_dat(fact)

DAT

    _gammatbl_neg   byte    $00, $25, $27, $05
                    byte    $10, $09, $3a, $78
                    byte    $4d, $05, $18, $0d
                    byte    $38, $3a, $1f

    _gammatbl_pos   byte    $1f, $1a, $18, $0a
                    byte    $0f, $06, $45, $87
                    byte    $32, $0a, $07, $02
                    byte    $07, $05, $00

DAT
{
    --------------------------------------------------------------------------------------------------------
    TERMS OF USE: MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    --------------------------------------------------------------------------------------------------------
}
