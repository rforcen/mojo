# fortran rpoly wrapper

# SUBROUTINE RPOLY(OP, DEGREE, ZEROR, ZEROI,FAIL)
# DOUBLE PRECISION OP(101)
# INTEGER DEGREE
# DOUBLE PRECISION ZEROR(100), ZEROI(100)
# LOGICAL FAIL

# called as rpoly_(op.unsafe_ptr(), Pointer(to=degree), zeror.unsafe_ptr(), zeroi.unsafe_ptr(), Pointer(to=fail))
# all params are passed as pointers

# gfortran -c -Ofast -fdefault-real-8 -fdefault-double-8 493.f

from std.ffi import c_double, c_int, external_call
from std.complex import ComplexFloat64

def rpoly(op : List[Float64]) raises -> Tuple[Bool, List[ComplexFloat64]]:
    var degree = c_int(len(op) - 1)
    var fail = c_int(1) # bool fits here

    if degree > 100: raise Error("degree too high, max supporetd 100")        

    var zeror = List[Float64](length=len(op)-1, fill=0.0) # zeros result real part
    var zeroi = List[Float64](length=len(op)-1, fill=0.0) # zeros result imaginary part
    
    # all params are passed as pointers
    external_call["rpoly_", NoneType](op.unsafe_ptr(), Pointer(to=degree), zeror.unsafe_ptr(), zeroi.unsafe_ptr(), Pointer(to=fail))

    # combine real and imaginary parts into complex numbers
    var zeros = List[ComplexFloat64](length=len(op)-1, fill=ComplexFloat64(0.0, 0.0))
    for i in range(len(op)-1): zeros[i] = ComplexFloat64(zeror[i], zeroi[i])
    
    return (not fail, zeros^)

def eval(op : List[Float64], x : ComplexFloat64) -> ComplexFloat64:
    var result = ComplexFloat64(0.0, 0.0)
    var degree = len(op) - 1
    var p = ComplexFloat64(1.0, 0.0)
    for i in range(len(op)):
        result = p * op[degree - i] + result
        p = p * x
    return result

def eval_all_zeros(op : List[Float64], zeros : List[ComplexFloat64]) -> List[ComplexFloat64]:
    var results = List[ComplexFloat64](length=len(zeros), fill=ComplexFloat64(0.0, 0.0))
    for i in range(len(zeros)):
        results[i] = eval(op, zeros[i])
    return results^

def avg_error(op : List[Float64], zeros : List[ComplexFloat64]) -> Float64:
    var evals_zeros = eval_all_zeros(op, zeros)
    var avg = 0.0
    for i in range(len(zeros)): avg += evals_zeros[i].norm()
    avg /= Float64(len(zeros))
    return avg

def main() raises:
    var op : List[Float64] = [1.0, -55.0, 1320.0, -18150.0, 157773.0, -902055.0, 3416930.0, -8409500.0, 12753576.0, -10628640.0, 3628800.0]
    
    ref (success, zeros) = rpoly(op)

    if success:
        print("polynomial    :", op, " order:", len(op) - 1)
        print("zeros         :", zeros)
        print("eval all zeros:", eval_all_zeros(op, zeros))
        print("average error :", avg_error(op, zeros))
        
    else:
        print("failed to find roots")
