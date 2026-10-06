def t01():
    var d = Dict[Int, Int]()
    d[1] = 2
    print(d)

    try:
        ref d1 = d[1]
        print("with ref:", d1)
        d1 = 4
        print("modified dict:", d, d[1])

        ref dnf = d[100]
        print("with ref (not found):", dnf)
    except: 
        print("ref not found")

    
    if 1 in d:
        try:
            print(d[1])
            ref d1 = d[1]
            d1 = 3

            print("modified dict:", d, d[1])
        except: pass
    else:
        print("Not found")

def main():
    var my_dict = Dict[String, Int]()
    my_dict["a"] = 1
    my_dict["b"] = 2
    var value = my_dict.find("a")
    print(value)  # => 1
    var c = value.value() * 2

    var missing_value = my_dict.find("c")
    print(missing_value)  # => None

    