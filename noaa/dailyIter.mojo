# minimal example of iterator
from targz import TarGzReader
from daily import Daily

struct DailyIter(Iterable, Iterator, ImplicitlyCopyable):
    comptime IteratorType[iterable_mut: Bool, //, iterable_origin: Origin[mut=iterable_mut]]: Iterator = Self
    comptime Element = Daily

    var targz: TarGzReader
    var daily: Daily
    var file_name : String

    def __init__(out self, targz_file : String):
        self.daily = Daily()
        self.targz = TarGzReader()
        self.file_name = targz_file # save file name for __iter__

    def __init__(out self):
        self.daily = Daily()
        self.targz = TarGzReader()
        self.file_name = ""
    
    # 1. Returns the iterator object 
    def __iter__(ref self) -> Self.IteratorType[origin_of(self)]:
        var res = Self()
        
        res.file_name = self.file_name
        res.daily = Daily()

        try:
            res.targz = TarGzReader(res.file_name)    
        except:
            print("DailyIter, can't open file:", self.file_name)
        
        return res^
            

    # 2. Controls the advance and endal of the loop
    def __next__(mut self) raises StopIteration -> Daily:        
        try:
            var result = self.targz.next_header()

            while not self.targz.get_pathname().endswith(".dly"):   # skip non daily files
                result = self.targz.next_header()
                if not result: raise StopIteration()
            
            self.daily = Daily(self.targz.read()) # read data
        except:
            raise StopIteration()
    
        return self.daily
 

def main():
    var DailyFile = "../data/ghcnd_all.tar.gz"

    print(t"dailyIter test on {DailyFile}")
        
    for nf, daily in enumerate(DailyIter(DailyFile)):
        if nf % 1000 == 0:
            try:
                print(t"{nf}: {daily.station()}, {daily.year(0)}, {daily.month(0)}, {daily.element(0)}, # recs: {len(daily)}", end='\r ')                   
            except: pass
    print()
    