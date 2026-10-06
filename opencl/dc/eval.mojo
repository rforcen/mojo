from std.complex import ComplexFloat32
from std.math import pi, floor
from cmath import I, c_exp, c_sin, c_cos, c_tan, c_log, c_log10, c_sqrt, c_asin, c_acos, c_atan, c_pow, c_abs

from zcompiler import Token

comptime UInt32Ptr = Pointer[UInt32, MutUnsafeAnyOrigin]
comptime Float32Ptr = Pointer[Float32, MutUnsafeAnyOrigin]
comptime c32 = ComplexFloat32

@always_inline
def evaluate(code_ptr: UInt32Ptr, consts: Float32Ptr, z : c32) raises -> c32:

    @always_inline
    def get_const(idx: Token) {imm consts} -> Float32:  return consts.unsafe_offset(idx.value())[]
    @always_inline
    def get_code(idx: Int32) {imm code_ptr} -> Token:  return Token(code_ptr.unsafe_offset(idx)[])
    
    var stack = Array[c32, 64](uninitialized=True)
    var sp : Int32 = 0
    var pc : Int32 = 0

    while get_code(pc) != Token.tk_end:
        var code = get_code(pc)

        if code == Token.tk_pushc:
            stack[sp] = c32(get_const(get_code(pc + 1)), 0.0)
            sp += 1
            pc += 2
        elif code == Token.tk_pushz:
            stack[sp] = z
            sp += 1
            pc += 1
        elif code == Token.tk_pushi:
            stack[sp] = c32(0.0, 1.0)
            sp += 1
            pc += 1
        elif code == Token.tk_neg:
            stack[sp - 1] = -stack[sp - 1]
            pc += 1
        elif code == Token.tk_plus:
            stack[sp - 2] = stack[sp - 2] + stack[sp - 1]
            sp -= 1
            pc += 1
        elif code == Token.tk_minus:
            stack[sp - 2] = stack[sp - 2] - stack[sp - 1]
            sp -= 1
            pc += 1
        elif code == Token.tk_mult:
            stack[sp - 2] = stack[sp - 2] * stack[sp - 1]
            sp -= 1
            pc += 1            
        elif code == Token.tk_div:
            stack[sp - 2] = stack[sp - 2] / stack[sp - 1]
            sp -= 1
            pc += 1
        elif code == Token.tk_power:
            stack[sp - 2] = c_pow(stack[sp - 2], stack[sp - 1])
            sp -= 1
            pc += 1
        elif code == Token.tk_fexp:
            stack[sp - 1] = c_exp(stack[sp - 1])
            pc += 1
        elif code == Token.tk_fsin:
            stack[sp - 1] = c_sin(stack[sp - 1])
            pc += 1
        elif code == Token.tk_fcos:
            stack[sp - 1] = c_cos(stack[sp - 1])
            pc += 1
        elif code == Token.tk_ftan:
            stack[sp - 1] = c_tan(stack[sp - 1])
            pc += 1
        elif code == Token.tk_flog:
            stack[sp - 1] = c_log(stack[sp - 1])
            pc += 1
        elif code == Token.tk_flog10:
            stack[sp - 1] = c_log10(stack[sp - 1])
            pc += 1
        elif code == Token.tk_fsqrt:
            stack[sp - 1] = c_sqrt(stack[sp - 1])
            pc += 1
        elif code == Token.tk_fasin:
            stack[sp - 1] = c_asin(stack[sp - 1])
            pc += 1
        elif code == Token.tk_facos:
            stack[sp - 1] = c_acos(stack[sp - 1])
            pc += 1
        elif code == Token.tk_fatan:
            stack[sp - 1] = c_atan(stack[sp - 1])
            pc += 1
        elif code == Token.tk_fabs:
            stack[sp - 1] = c32(c_abs(stack[sp - 1]), 0.0)
            pc += 1
        elif code == Token.tk_fint:
            stack[sp - 1] = c32(floor(stack[sp - 1].re), floor(stack[sp - 1].im))
            pc += 1
        elif code == Token.tk_c:
            sp -= 1
            stack[sp - 1] = c32(stack[sp - 1].re, stack[sp].im)
            pc += 1
        else:
            raise Error("evaluate: unknown token")
            
    if sp != 1: raise Error("evaluate: stack underflow")

    return stack[0]