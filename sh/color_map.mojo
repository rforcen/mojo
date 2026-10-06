# color map

comptime N_COLOR_MAPS=25
from coord import Coord

@always_inline    
def ColorMap(_v: Float32, _vmin: Float32,  _vmax: Float32, type: Int) -> Coord:    
    var c = Coord()

    var v = _v
    var vmin = _vmin
    var vmax = _vmax

    if vmax < vmin:
        var t = vmin
        vmin = vmax
        vmax = t

    if vmax - vmin < 1.0e-6:
        vmin -= 1.0
        vmax += 1.0

    v = max(vmin, min(v, vmax))

    var dv : Float32 = vmax - vmin

    if type <= 1:
        if v < (vmin + 0.25 * dv):
            c = Coord(0.0, 4.0 * (v - vmin) / dv, 1.0)
        elif v < (vmin + 0.5 * dv):
            c = Coord(0.0, 1.0, 1.0 + 4.0 * (vmin + 0.25 * dv - v) / dv)
        elif v < (vmin + 0.75 * dv):
            c = Coord(4.0 * (v - vmin - 0.25 * dv) / dv, 1.0, 0)            
        else:
            c = Coord(1.0, 1 + 4.0 * (vmin + 0.75 * dv - v) / dv, 0)

    elif type == 2:
        c = Coord((v - vmin) / dv, 0.0, (vmax - v) / dv)

    elif type == 3:
        var val = (v - vmin) / dv
        c = Coord(val, val, val)

    elif type == 4:
        if v < (vmin + dv / 6.0):
            c = Coord(1.0, 6.0 * (v - vmin) / dv, 0.0)
        elif v < (vmin + 2.0 * dv / 6.0):
            c = Coord(1.0 + 6.0 * (vmin + dv / 6.0 - v) / dv, 1.0, 0.0)
        elif v < (vmin + 3.0 * dv / 6.0):
            c = Coord(0.0, 1.0, 6.0 * (v - vmin - 2.0 * dv / 6.0) / dv)
        elif v < (vmin + 4.0 * dv / 6.0):
            c = Coord(1.0, 1.0 + 4.0 * (vmin + 0.5 * dv - v) / dv, 0.0)
        elif v < (vmin + 5.0 * dv / 6.0):
            c = Coord(6.0 * (v - vmin - 4.0 * dv / 6.0) / dv, 0.0, 1.0)
        else:
            c = Coord(1.0, 0.0, 1.0 + 6.0 * (vmin + 5.0 * dv / 6.0 - v) / dv)

    elif type == 5:
        c = Coord((v - vmin) / dv, 1.0, 0.0)

    elif type == 6:
        var val = (v - vmin) / (vmax - vmin)
        c = Coord(val, (vmax - v) / (vmax - vmin), val)

    elif type == 7:
        if v < (vmin + 0.25 * dv):
            var val = 4.0 * (v - vmin) / dv
            c = Coord(0.0, val, 1.0 - val)
        elif v < (vmin + 0.5 * dv):
            var val = 4.0 * (v - vmin - 0.25 * dv) / dv
            c = Coord(val, 1.0 - val, 0.0)
        elif v < (vmin + 0.75 * dv):
            var val = 4.0 * (v - vmin - 0.5 * dv) / dv
            c = Coord(1.0 - val, val, 0.0)
        else:
            c = Coord(1.0, 4.0 * (v - vmin - 0.75 * dv) / dv, 0.0)

    elif type == 8:
        if v < (vmin + 0.5 * dv):
            var val = 2.0 * (v - vmin) / dv
            c = Coord(val, val, val)
        else:
            var val = 1.0 - 2.0 * (v - vmin - 0.5 * dv) / dv
            c = Coord(val, val, val)

    elif type == 9:
        if v < (vmin + dv / 3.0):
            var val = 3.0 * (v - vmin) / dv
            c = Coord(1.0 - val, 0.0, val)
        elif v < (vmin + 2.0 * dv / 3.0):
            c = Coord(0.0, 3.0 * (v - vmin - dv / 3.0) / dv, 1.0)
        else:
            var val = 3.0 * (v - vmin - 2.0 * dv / 3.0) / dv
            c = Coord(val, 1.0 - val, 1.0)

    elif type == 10:
        if v < (vmin + 0.2 * dv):
            c = Coord(0.0, 5.0 * (v - vmin) / dv, 1.0)
        elif v < (vmin + 0.4 * dv):
            c = Coord(0.0, 1.0, 1.0 + 5.0 * (vmin + 0.2 * dv - v) / dv)
        elif v < (vmin + 0.6 * dv):
            c = Coord(5.0 * (v - vmin - 0.4 * dv) / dv, 1.0, 0.0)
        elif v < (vmin + 0.8 * dv):
            c = Coord(1.0, 1.0 - 5.0 * (v - vmin - 0.6 * dv) / dv, 0.0)
        else:
            var val = 5.0 * (v - vmin - 0.8 * dv) / dv
            c = Coord(1.0, val, val)

    elif type == 11:
        var c1 = Coord(200.0 / 255, 60.0 / 255, 0.0 / 255)
        var c2 = Coord(250.0 / 255, 160.0 / 255, 110.0 / 255)
        var t = (v - vmin) / dv
        c = c1 * (1-t) + c2 * t 
        

    elif type == 12:
        var c1 = Coord(55.0 / 255, 55.0 / 255, 45.0 / 255)
        var c2 = Coord(235.0 / 255, 90.0 / 255, 30.0 / 255)
        var c3 = Coord(250.0 / 255, 160.0 / 255, 110.0 / 255)
        var ratio : Float32 = 0.4
        var vmid : Float32 = vmin + ratio * dv
        if v < vmid:
            var t = (v - vmin) / (ratio * dv)
            c = c1 * (1-t) + c2 * t
        else:
            var t = (v - vmid) / ((1.0 - ratio) * dv)
            c = c2 * (1-t) + c3 * t

    elif type == 13:
        var c1 = Coord(0.0 / 255, 255.0 / 255, 0.0 / 255)
        var c2 = Coord(255.0 / 255, 150.0 / 255, 0.0 / 255)
        var c3 = Coord(255.0 / 255, 250.0 / 255, 240.0 / 255)
        var ratio :Float32 = 0.3
        var vmid = vmin + ratio * dv
        if v < vmid:
            var t = (v - vmin) / (ratio * dv)
            c = c1 * (1-t) + c2 * t
        else:
            var t = (v - vmid) / ((1.0 - ratio) * dv)
            c = c2 * (1-t) + c3 * t

    elif type == 14:
        c = Coord(1.0, 1.0 - (v - vmin) / dv, 0.0)
    elif type == 15:
        if v < (vmin + 0.25 * dv):
            c = Coord(0.0, 4.0 * (v - vmin) / dv, 1.0)
        elif v < (vmin + 0.5 * dv):
            c = Coord(0.0, 1.0, 1.0 - 4.0 * (v - vmin - 0.25 * dv) / dv)
        elif v < (vmin + 0.75 * dv):
            c = Coord(4.0 * (v - vmin - 0.5 * dv) / dv, 1.0, 0.0)
        else:
            c = Coord(1.0, 1.0, 4.0 * (v - vmin - 0.75 * dv) / dv)

    elif type == 16:
        if v < (vmin + 0.5 * dv):
            c = Coord(0.0, 2.0 * (v - vmin) / dv, 1.0 - 2.0 * (v - vmin) / dv)
        else:
            c = Coord(
                2.0 * (v - vmin - 0.5 * dv) / dv,
                1.0,
                2.0 * (v - vmin - 0.5 * dv) / dv,
            )

    elif type == 17:
        if v < (vmin + 0.5 * dv):
            c = Coord(1.0, 1.0 - 2.0 * (v - vmin) / dv, 2.0 * (v - vmin) / dv)
        else:
            c = Coord(
                1.0 - 2.0 * (v - vmin - 0.5 * dv) / dv,
                2.0 * (v - vmin - 0.5 * dv) / dv,
                1.0,
            )
    elif type == 18:
        c = Coord(0.0, (v - vmin) / (vmax - vmin), 1.0)
    elif type == 19:
        c = Coord((v - vmin) / (vmax - vmin), (v - vmin) / (vmax - vmin), 1.0)
    elif type == 20:
        var c1 = Coord(0.0 / 255, 160.0 / 255, 0.0 / 255)
        var c2 = Coord(180.0 / 255, 220.0 / 255, 0.0 / 255)
        var c3 = Coord(250.0 / 255, 220.0 / 255, 170.0 / 255)
        var ratio : Float32 = 0.3
        var vmid : Float32 = vmin + ratio * dv
        if v < vmid:
            var t = (v - vmin) / (ratio * dv)
            c = c1 * (1-t) + c2 * t
        else:
            var t = (v - vmid) / ((1.0 - ratio) * dv)
            c = c2 * (1-t) + c3 * t
    elif type == 21:
        var c1 = Coord(255.0 / 255, 255.0 / 255, 200.0 / 255)
        var c2 = Coord(150.0 / 255, 150.0 / 255, 255.0 / 255)
        var t = (v - vmin) / dv
        c = c1 * (1-t) + c2 * t
    elif type == 22:
        var t = (v - vmin) / dv
        c = Coord(1.0 - t, 1.0 - t, t)
    elif type == 23:
        if v < (vmin + 0.5 * dv):
            c = Coord(1.0, 2.0 * (v - vmin) / dv, 2.0 * (v - vmin) / dv)
        else:
            c = Coord(1.0 - 2.0 * (v - vmin - 0.5 * dv) / dv, 1.0 - 2.0 * (v - vmin - 0.5 * dv) / dv, 1.0)
    elif type == 24:
        if v < (vmin + 0.5 * dv):
            c = Coord(2.0 * (v - vmin) / dv, 2.0 * (v - vmin) / dv, 1.0 - 2.0 * (v - vmin) / dv)
        else:
            c = Coord(1.0 - 2.0 * (v - vmin - 0.5 * dv) / dv, 1.0 - 2.0 * (v - vmin - 0.5 * dv) / dv, 0.0)
            
    elif type >= 25:
        if v < (vmin + dv / 3):
            c = Coord(0.0, 3.0 * (v - vmin) / dv, 1.0)
        elif v < (vmin + 2 * dv / 3):
            c = Coord(3.0 * (v - vmin - dv / 3) / dv, 1.0 - 3.0 * (v - vmin - dv / 3) / dv, 1.0)
        else:
            c = Coord(1.0, 0.0, 1.0 - 3.0 * (v - vmin - 2 * dv / 3) / dv)

    return c

def test_color_map():
    for i in range(N_COLOR_MAPS):
        var v : Float32 = 0.5
        var vmin : Float32 = 0.0
        var vmax : Float32 = 1.0
        print(t"ColorMap({v}, {vmin}, {vmax}, {i}) = {ColorMap(v, vmin, vmax, i)}")

def main(): test_color_map()