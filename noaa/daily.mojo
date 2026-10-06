# daily observations
from targz import TarGzReader
from common import read_aux_files, AuxFiles, Station

# daily
#
comptime DAILY_LINE_SIZE = 270 # including \n

struct Daily(Sized, ImplicitlyCopyable): # daily observation file
    var data: String
    var len : Int

    def __init__(out self):
        self.data = ""
        self.len = 0
    def __init__(out self, data: String):
        self.data = data
        self.len = data.byte_length() / DAILY_LINE_SIZE
    def __len__(self) -> Int: return self.len

    @always_inline
    def chunk(self, index : Int, start : Int, l : Int) -> String:
        return String(self.data[byte=index * DAILY_LINE_SIZE + start : index * DAILY_LINE_SIZE + start + l])

    @always_inline
    def id(self, index : Int) -> String: return self.chunk(index, 0, 11)
    @always_inline
    def year(self, index : Int) raises -> Int:  return Int(self.chunk(index, 11, 4))
    @always_inline
    def month(self, index : Int) raises -> Int: return Int(self.chunk(index, 15, 2))
    @always_inline
    def element(self, index : Int) raises -> String:   return self.chunk(index, 17, 4)
    @always_inline
    def value(self, index : Int, day : Int) raises -> Int:    return Int(self.chunk(index, 21 + day * 8, 5))
    @always_inline
    def mflag(self, index : Int, day : Int) -> String:    return self.chunk(index, 26 + day * 8, 1)
    @always_inline
    def qflag(self, index : Int, day : Int) -> String:    return self.chunk(index, 27 + day * 8, 1)
    @always_inline
    def sflag(self, index : Int, day : Int) -> String:    return self.chunk(index, 28 + day * 8, 1)
    @always_inline
    def station(self) -> String:    return String(self.data[byte=:11])

struct Observations:
    var data : String
    
    @always_inline
    def __init__(out self, dly: Daily, index : Int) raises:
        var start = index * DAILY_LINE_SIZE + 21
        self.data = String(dly.data[byte = start : start + 8 * 31])
        
    @always_inline
    def value(self, day : Int) raises -> Int:  return Int(self.data[byte = day * 8 : day * 8 + 5])
    @always_inline
    def mflag(self, day : Int) raises -> String:  return String(self.data[byte = day * 8 + 5 : day * 8 + 6])
    @always_inline
    def qflag(self, day : Int) raises -> String:  return String(self.data[byte = day * 8 + 6 : day * 8 + 7])
    @always_inline
    def sflag(self, day : Int) raises -> String:  return String(self.data[byte = day * 8 + 7 : day * 8 + 8])

    
    def max(self) raises -> Int:
        var max_val = -9999
        for i in range(31):
            var val = self.value(i)
            if val > max_val and self.qflag(i) == " ":
                max_val = val
        return max_val
    def min(self) raises -> Int:
        var min_val = 9999
        for i in range(31):
            var val = self.value(i)
            if val < min_val and self.qflag(i) == " ":
                min_val = val
        return min_val

comptime VoidPtr = Pointer[NoneType, MutUnsafeAnyOrigin]
comptime FILTER_DEF = def(imm aux_files : AuxFiles, daily : Daily, user_data : VoidPtr) thin -> Bool

#
def traverse_daily(imm aux_files : AuxFiles, filter : FILTER_DEF, user_data : VoidPtr, n_progress : Int = 1000, max_files : Int = -1) raises:
    var tgz = TarGzReader("../data/ghcnd_all.tar.gz")

    var n_files = 0
    var n_found = 0

    while tgz.next_header():
        if not tgz.get_pathname().endswith(".dly"):  continue # skip non daily files

        n_files += 1
        if n_files % n_progress == 0:
            print(t"Processed {n_files} files, found {n_found}", end='\r')

        if max_files > 0 and n_files >= max_files:
            break

        var file_content = tgz.read()
        var daily = Daily(file_content)

        if filter(aux_files, daily, user_data): n_found += 1
                
    tgz.close()
    print(t"Found {n_found} records out of {n_files}")

from std.time import perf_counter

def main() raises:
    var af = read_aux_files()

    var found = Dict[Int,Int]() # year, max(tmax value)
    var user_data: VoidPtr = Pointer(to=found).unsafe_bitcast[NoneType]().as_unsafe_any_origin()

    # filter function
    def filter(imm aux_files : AuxFiles, daily : Daily, user_data : VoidPtr) -> Bool:
        
        ref found = user_data.unsafe_bitcast[Dict[Int, Int]]()[] # get the ref to Dict 'found'

        try:
            ref station = aux_files.stations[daily.station()]
        
            for i in range(len(daily)):  
                try:      
                    var year = daily.year(i) 
                
                    if daily.element(i) == "TMAX" and 2000 <= year < 2015 and station.elevation > 3000:                    
                        var mtmax = Observations(daily, i).max() / 10 # quality max
                        var fg = found.get(year)

                        if fg: # update max value if required
                            if fg.value() < mtmax:
                                found[year] = mtmax
                        else:
                            found[year] = mtmax
                        return True
                except:
                    continue
        except: pass
                    
        return False

    # traverse daily observations
    print("traversing noaa daily observations...")

    var start = perf_counter()
    traverse_daily(aux_files=af, filter=filter, user_data=user_data, n_progress=1_000)
    var lap = Int(perf_counter() - start)
    

    var ly = List[Int]() # sort years
    for year in found.keys(): ly.append(year)
    sort(ly)
    print("year    tmax max ºC")
    for year in ly: print(t"{year}           {found[year]}º")

    print(t"lap: {lap} secs")    

