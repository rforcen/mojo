# noaa aux files

from std.collections import Dict

comptime CodeDesc = Dict[String, String]
comptime Stations = Dict[String, Station]

@fieldwise_init
struct AuxFiles(Copyable):
    var countries: CodeDesc
    var states: CodeDesc
    var elements: CodeDesc
    var stations: Stations

@fieldwise_init
struct Station(Copyable):
    var id: String
    var latitude: Float64
    var longitude: Float64
    var elevation: Float64
    var state: String
    var name: String
    var gsn_flag: String
    var hcn_crn_flag: String
    var wmo_id: String

def read_stations(fname: String) raises -> Stations:
    var stations = Stations()

    for line in _load_file(fname).split("\n"):
        if line.byte_length() < 78: continue # junk

        var id = String(line[byte=:11])

        stations[id] = Station(
            id=id,
            
            latitude=Float64(line[byte=12:20]),
            longitude=Float64(line[byte=21:30]),
            elevation=Float64(line[byte=31:37]),

            state=String(line[byte=38:40].rstrip()), # remove trailing spaces
            name=String(line[byte=41:71].rstrip()),
            gsn_flag=String(line[byte=72:75].rstrip()),
            hcn_crn_flag=String(line[byte=76:79].rstrip()),
            wmo_id=String(line[byte=80:85].rstrip())
        )
        
    return stations^

def read_aux(fname: String, code_size: Int = 2, gap: Int = 1) raises -> CodeDesc:
    var aux_map: CodeDesc = CodeDesc()
    
    for line in _load_file(fname).split("\n"):
        if line.byte_length() < code_size + gap - 1:
            continue

        var lst = line.strip()

        var code = String(lst[byte=:code_size])
        var description = String(lst[byte=code_size+gap:])
        
        aux_map[code] = description

    return aux_map^

def read_aux_files() raises -> AuxFiles:
    return AuxFiles(
        countries=read_aux("../data/ghcnd-countries.txt", 2, 1),
        states=read_aux("../data/ghcnd-states.txt", 2, 1),
        elements=read_aux("../data/ghcnd-elements.txt", 4, 0),
        stations=read_stations("../data/ghcnd-stations.txt")
    )

def _load_file(fname: String) raises -> String:
    with open(fname, "r") as f:
        return f.read()

def print_aux_files(imm aux_files: AuxFiles) raises:
    print("Countries:")
    for c in aux_files.countries: print(t"|{c}|{aux_files.countries[c]}|")
    print("States:")
    for c in aux_files.states: print(t"|{c}|{aux_files.states[c]}|")
    print("Elements:")
    for c in aux_files.elements: print(t"|{c}|{aux_files.elements[c]}|")
    print("Stations:")
    
    var count = 0
    var st = aux_files.stations.copy()
    for c in st: 
        var s = st[c].copy()
        print(t"|{c}|{s.id}|{s.latitude}|{s.longitude}|{s.elevation}|{s.state}|{s.name}|{s.gsn_flag}|{s.hcn_crn_flag}|{s.wmo_id}|")
        count += 1
        if count >= 10:
            break


#
def main() raises:
    from std.time import perf_counter
    from std.sys import align_of
    
    print("Reading auxiliary files...", end='')
    var start = perf_counter()
    var aux_files = read_aux_files()
    print(t"lap: {Int((perf_counter() - start) * 1000)} ms")
    # print_aux_files(aux_files)
    print(t"Station align: {align_of[Station]()}")