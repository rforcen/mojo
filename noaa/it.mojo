# minimal example of iterator

struct MyRange(Iterable, Iterator, ImplicitlyCopyable):
    comptime IteratorType[iterable_mut: Bool, //, iterable_origin: Origin[mut=iterable_mut]]: Iterator = Self
    comptime Element = Int

    var start: Int
    var end: Int

    def __init__(out self, start: Int, end: Int):
        self.start = start
        self.end = end
    def __init__(out self, end: Int):
        self.start = 0
        self.end = end

    # 1. Returns the iterator object (in this case, a copy of itself)
    def __iter__(ref self) -> Self.IteratorType[origin_of(self)]:
        return self.copy()

    # 2. Controls the advance and endal of the loop
    def __next__(mut self) raises StopIteration -> Int:
        var current = self.start
        self.start += 1
    
        if self.start > self.end:
            raise StopIteration()
    
        return current
 

def main():
    for valor in MyRange(1, 10): print(valor, end=', ')
    print()
    for valor in MyRange(10): print(valor, end=', ')
    print()