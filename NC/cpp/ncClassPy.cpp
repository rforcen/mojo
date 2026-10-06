/*
  numc python numerical linalg object, numpy subset but supporting f16 & f80

  g++ -O3 -shared -std=c++2a -fPIC  $(python3.11 -m pybind11 --includes)
  ncClassPy.cpp -o numc$(python3.11-config --extension-suffix)

  usage:

    import numc # help(numc)

    a = numc.numc(3,4) # create a zero 3 x 4 array
    b = numc.numc.rand(4,5) # create 4 x 5 rand array
    c = a+b # * - /
    e = a == b #
    e = a != b #

    b = numc.numc.rand(5,5)
    d = b.det()
    i = b.inv()
    dt = b.dot(i)

 */

#include "nc.h"

#include <pybind11/eval.h>
#include <pybind11/numpy.h>
#include <pybind11/operators.h>
#include <pybind11/pybind11.h>

namespace py = pybind11;

class ncPy : public nc::NC {
public:
  ncPy() : nc::NC() {}
  ncPy(nc::NC::DataType _dtype, nc::VDim dims) : nc::NC(_dtype, dims) {}
  ncPy(nc::NC::DataType _dtype, const py::args shape)
      : nc::NC(_dtype, createDim(shape)) {}
  ncPy(const nc::NC _nc) : nc::NC(_nc) {}

  static ncPy arange(nc::NC::DataType _dtype = f64,
                     const py::args shape = py::args()) {
    if (shape.size() == 0)
      return nc::NC::arange(nc::NC::f64, {10}); // no args ->arange(f64, 10)
    else
      return nc::NC::arange(_dtype, ncPy::createDim(shape));
  }

  static ncPy fromNumpy(const py::object array_obj) {
    if (!py::isinstance<py::array>(array_obj))
      throw py::type_error("Input must be a NumPy array.");
    py::array array = py::cast<py::array>(array_obj);

    py::buffer_info info = array.request();
    string dtype_str = info.format; // Format string 'bhilfd'
    std::map<string, nc::NC::DataType> typeMap = {
        {"b", nc::NC::i8},  {"h", nc::NC::i16}, {"i", nc::NC::i32},
        {"l", nc::NC::i64}, {"f", nc::NC::f32}, {"d", nc::NC::f64}};

    ncPy res(typeMap[dtype_str], createDim(info.shape));

    res.fromBuffer(info.ptr);
    return res;
  }

  static ncPy fromNumpy(const nc::NC::DataType dt,
                        const py::object array_obj) { // converting to 'dt'
    if (!py::isinstance<py::array>(array_obj))
      throw py::type_error("Input must be a NumPy array.");
    py::array array = py::cast<py::array>(array_obj);

    py::buffer_info info = array.request();
    string dtype_str = info.format; // Format string 'bhilfd'
    std::map<string, nc::NC::DataType> typeMap = {
        {"b", nc::NC::i8},  {"h", nc::NC::i16}, {"i", nc::NC::i32},
        {"l", nc::NC::i64}, {"f", nc::NC::f32}, {"d", nc::NC::f64}};

    ncPy res(dt, createDim(info.shape));

    switch (dtype_str[0]) {
#define ct(t)                                                                  \
  case nc::NC::t:                                                              \
    for (size_t i = 0; i < info.size; i++)                                     \
      res._at<nc::_##t>(i) = p[i];                                             \
    break;
#define allTypes(t)                                                            \
  {                                                                            \
    nc::_##t *p = (nc::_##t *)info.ptr;                                        \
    switch (dt) {                                                              \
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)  \
          ct(f128)                                                             \
    }                                                                          \
  }                                                                            \
  break;

    case 'b':
    allTypes(i8) case 'h':
    allTypes(i16) case 'i':
    allTypes(i32) case 'l':
    allTypes(i64) case 'f':
    allTypes(f32) case 'd':
      allTypes(f64)

#undef ct
#undef allTypes
    }

    return res;
  }

  py::object toNumpy() {
    switch (getType()) {
    case i8:
      return create_array<int8_t>();
    case i16:
      return create_array<int16_t>();
    case i32:
      return create_array<int32_t>();
    case i64:
      return create_array<int64_t>();
    case i128:
      return conv_array<nc::_i128, int64_t>();

    case f16:
      return conv_array<nc::_f16, float>();
    case f32:
      return create_array<float>();
    case f64:
      return create_array<double>();
    case f80:
      return conv_array<nc::_f80, double>();
    case f128:
      return conv_array<nc::_f128, double>();
    }
  }

  py::bytes toBytes() { return py::bytes((char *)getData(), getSizeBytes()); }

  static ncPy fromBytes(const py::bytes _bytes, const nc::NC::DataType _dtype,
                        const py::args shape) {

    ncPy res(_dtype, shape);
    string b(_bytes); // must convert to string

    if (b.size() == res.getSizeBytes())
      res.fromBuffer(b.data());
    else
      throw "fromBytes: incompatible sizes";

    return res;
  }

  // arith. opers w/ncPy
  ncPy operator+(const ncPy &other) const {
    return nc::NC::operator+(other);
  } // are they same _dtype?
  ncPy operator-(const ncPy &other) const { return nc::NC::operator-(other); }
  ncPy operator*(const ncPy &other) const { return nc::NC::operator*(other); }
  ncPy operator/(const ncPy &other) const { return nc::NC::operator/(other); }

  // with numpy operators
  ncPy operator+(const py::array_t<double> &_np) const {
    return *this + fromNumpy(getType(), _np);
  }
  ncPy operator-(const py::array_t<double> &_np) const {
    return *this - fromNumpy(getType(), _np);
  }
  ncPy operator*(const py::array_t<double> &_np) const {
    return *this * fromNumpy(getType(), _np);
  }
  ncPy operator/(const py::array_t<double> &_np) const {
    return *this / fromNumpy(getType(), _np);
  }

  ncPy operator+(const py::array_t<float> &_np) const {
    return *this + fromNumpy(getType(), _np);
  }
  ncPy operator-(const py::array_t<float> &_np) const {
    return *this - fromNumpy(getType(), _np);
  }
  ncPy operator*(const py::array_t<float> &_np) const {
    return *this * fromNumpy(getType(), _np);
  }
  ncPy operator/(const py::array_t<float> &_np) const {
    return *this / fromNumpy(getType(), _np);
  }

// arithmetic operators def
#define operType(t, op)                                                        \
  ncPy operator op(const t c) const { return nc::NC::operator op(c); }
#define allType(op) operType(int, op) operType(double, op)
  allType(+) allType(-) allType(*) allType(/)
#undef operType
#undef allType

      // logical oper.
      bool operator==(const ncPy &other) const {
    return nc::NC::operator==(other);
  }
  bool operator!=(const ncPy &other) const { return nc::NC::operator!=(other); }

  bool operator==(const double d) const { return nc::NC::operator==(d); }
  bool operator!=(const double d) const { return nc::NC::operator!=(d); }

  bool operator==(const int d) const { return nc::NC::operator==((double)d); }
  bool operator!=(const int d) const { return nc::NC::operator!=((double)d); }

  // index acces
  py::object __get(size_t index) const {
#define cti(t)                                                                 \
  case t:                                                                      \
    return py::cast<int>((int)_at<nc::_##t>(index));
#define ctf(t)                                                                 \
  case t:                                                                      \
    return py::cast<double>((double)_at<nc::_##t>(index));
    switch (getType()) {
      cti(i8) cti(i16) cti(i32) cti(i64) cti(i128) ctf(f16) ctf(f32) ctf(f64)
          ctf(f80) ctf(f128) ctf(fmp)
    }
#undef ctf
#undef cti
  }

  // convert an object (argumen list) or int to an index
  size_t __index(const py::object index) const {
    if (py::isinstance<py::int_>(index))
      return py::cast<size_t>(index); // Single integer index
    else if (py::isinstance<py::tuple>(index))
      return calcIndex(
          createDim(py::cast<py::args>(index))); // tuple of indices
    else
      throw py::type_error("Index must be an integer or a list of integers");
  }

  py::object get(const py::object index) const {
    if (py::isinstance<py::int_>(index)) { // Single integer index?
      if (get_ndims() == 1)
        return __get(py::cast<size_t>(index));
      else
        return py::cast(ncPy(slice({py::cast<size_t>(index)})));
    } else if (py::isinstance<py::tuple>(index)) { // tuple of indices
      nc::VDim dim = createDim(py::cast<py::args>(index));

      if (dim.size() < get_ndims())
        return py::cast(ncPy(slice(dim)));
      if (dim.size() == get_ndims())
        return __get(calcIndex(dim));
      else
        throw "wrong index size";
    } else
      throw py::type_error("Index must be an integer or a list of integers");
  }

  py::object get0(void) const { return __get(0); } // get item 0

  void set(const py::object &index, const py::object &value) {
    size_t ix = __index(index);

#define cti(t)                                                                 \
  case t:                                                                      \
    _at<nc::_##t>(ix) = py::cast<int>(value);                                  \
    break;
#define ctf(t)                                                                 \
  case t:                                                                      \
    _at<nc::_##t>(ix) = py::cast<double>(value);                               \
    break;
    switch (getType()) {
      cti(i8) cti(i16) cti(i32) cti(i64) cti(i128) ctf(f16) ctf(f32) ctf(f64)
          ctf(f80) ctf(f128)
    }
#undef cti
#undef ctf
  }

  void __set(size_t index, const py::object &value) { // _at(index)=value
#define cti(t)                                                                 \
  case t:                                                                      \
    _at<nc::_##t>(index) = py::cast<int>(value);                               \
    break;
#define ctf(t)                                                                 \
  case t:                                                                      \
    _at<nc::_##t>(index) = py::cast<double>(value);                            \
    break;

    switch (getType()) {
      cti(i8) cti(i16) cti(i32) cti(i64) cti(i128) ctf(f16) ctf(f32) ctf(f64)
          ctf(f80) ctf(f128)
    }

#undef cti
#undef ctf
  }

  void setMultDim(const py::object &index, const py::object &value) {
    nc::VDim dim;
    if (py::isinstance<py::int_>(index))
      dim = {py::cast<size_t>(index)};
    else if (py::isinstance<py::tuple>(index)) // tuple of indices
      dim = createDim(py::cast<py::args>(index));
    else
      throw py::type_error("Index must be an integer or a list of integers");

    if (get_ndims() == dim.size())
      __set(calcIndex(dim), value);
    else
      Assign(py::cast<ncPy>(value), dim);
  }

  py::list getShape() {
    py::list l;
    for (auto i : nc::NC::getDims())
      l.append(i);
    return l;
  }

  ncPy
  _apply(const string &expression) { // inplace apply c++ from bool compiler
    compiler::Compiler<double> bc;

    if (bc.compile(expression)) {

#define ct(t)                                                                  \
  case t:                                                                      \
    for (size_t i = 0; i < getSize(); i++)                                     \
      _at<nc::_##t>(i) = bc.evaluate(_at<nc::_##t>(i));                        \
    break;
      switch (getType()) {
        ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
            ct(f128)
      }
#undef ct
      return *this;
    } else
      throw invalid_argument("syntax error in expression");
  }

  ncPy
  apply(const string &expression) { // inplace apply python function, compiled
    py::dict locals;                // dict to hold 'x'
    py::object eval_func = py::eval(
        "eval"); // Get the Python eval function, or py::globals()["eval"]

    string cx = "compile('" + expression +
                "', '<string>', 'eval')"; // compile -> compExpr
    py::object compExpr = eval_func(cx);

    try {
      for (auto i = 0; i < getSize(); i++) {
        double x; // x = get value(i)

#define ct(t)                                                                  \
  case t:                                                                      \
    x = _at<nc::_##t>(i);                                                      \
    break;
        switch (getType()) {
          ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64)
              ct(f80) ct(f128)
        }
#undef ct

        locals["x"] = x;
        py::object value = eval_func(
            compExpr, py::globals(),
            locals); // Evaluate the expression within the provided locals

// assign 'value' to vec(i)
#define cti(t)                                                                 \
  case t:                                                                      \
    _at<nc::_##t>(i) = py::cast<int>(value);                                   \
    break;
#define ctf(t)                                                                 \
  case t:                                                                      \
    _at<nc::_##t>(i) = py::cast<double>(value);                                \
    break;
        switch (getType()) {
          cti(i8) cti(i16) cti(i32) cti(i64) cti(i128) ctf(f16) ctf(f32)
              ctf(f64) ctf(f80) ctf(f128)
        }
#undef cti
#undef ctf
      }
    } catch (const py::error_already_set &e) {
      throw string("apply: Python error:") + e.what();
    } // Handle Python exceptions (e.g., NameError, TypeError)
    catch (const exception &e) {
      throw string("apply: C++ error:") + e.what();
    }

    return *this;
  }

  size_t count(
      const string &expression) { // count item satify python function, compiled

    size_t cnt = 0;

    py::dict locals; // dict to hold 'x'
    py::object eval_func = py::eval(
        "eval"); // Get the Python eval function, or py::globals()["eval"]

    string cx = "compile('" + expression +
                "', '<string>', 'eval')"; // compile -> compExpr
    py::object compExpr = eval_func(cx);

    try {
      for (auto i = 0; i < getSize(); i++) {
        double x; // x = get value(i)

#define ct(t)                                                                  \
  case t:                                                                      \
    x = _at<nc::_##t>(i);                                                      \
    break;
        switch (getType()) {
          ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64)
              ct(f80) ct(f128)
        }
#undef ct

        locals["x"] = x;
        if (py::cast<bool>(eval_func(compExpr, py::globals(), locals)))
          cnt++; // Evaluate the expression within the provided locals
      }
    } catch (const py::error_already_set &e) {
      throw string("apply: Python error:") + e.what();
    } // Handle Python exceptions (e.g., NameError, TypeError)
    catch (const exception &e) {
      throw string("apply: C++ error:") + e.what();
    }

    return cnt;
  }

  size_t
  _count(const string &expression) { // count item satify c++ function, compiled
    compiler::Compiler<double> bc;

    if (bc.compile(expression)) {
      size_t _nc = 0;
#define ct(t)                                                                  \
  case t:                                                                      \
    for (size_t i = 0; i < getSize(); i++)                                     \
      if (bc.bool_evaluate(_at<nc::_##t>(i)))                                  \
        _nc++;                                                                 \
    break;
      switch (getType()) {
        ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
            ct(f128)
      }
#undef ct
      return _nc;
    } else
      throw invalid_argument("syntax error in expression");
  }

  ncPy match(const string &expression)
      const {                 // return a 1d array of items that match test
    ncPy res(getType(), {0}); // result

    py::dict locals; // dict to hold 'x'
    py::object eval_func = py::eval(
        "eval"); // Get the Python eval function, or py::globals()["eval"]

    string cx = "compile('" + expression +
                "', '<string>', 'eval')"; // compile -> compExpr
    py::object compExpr = eval_func(cx);

    try {
      for (auto i = 0; i < getSize(); i++) {
#define ct(t)                                                                  \
  case t: {                                                                    \
    nc::_##t x = _at<nc::_##t>(i);                                             \
    locals["x"] = x;                                                           \
    if (py::cast<bool>(eval_func(compExpr, py::globals(), locals)))            \
      res.push<nc::_##t>(x);                                                   \
  } break;

        switch (getType()) {
          ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64)
              ct(f80) ct(f128) //ct(fmp)
        }
#undef ct
      }
    } catch (const py::error_already_set &e) {
      throw string("apply: Python error:") + e.what();
    } // Handle Python exceptions (e.g., NameError, TypeError)
    catch (const exception &e) {
      throw string("apply: C++ error:") + e.what();
    }

    return res;
  }
  ncPy _match(string &expr) {
    compiler::Compiler<double> bc;

    if (bc.compile(expr)) {
      ncPy res(getType(), {0});
#define ct(t)                                                                  \
  case t:                                                                      \
    for (size_t i = 0; i < getSize(); i++)                                     \
      if (bc.bool_evaluate(_at<nc::_##t>(i)))                                  \
        res.push<nc::_##t>(_at<nc::_##t>(i));                                  \
    break;
      switch (getType()) {
        ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
            ct(f128) // ct(fmp)
      }
#undef ct
      return res;
    } else
      throw invalid_argument("syntax error in _match expression");
  }

  ncPy tolerance(double _tolerance) {
#define ct(t)                                                                  \
  case t:                                                                      \
    for (auto i = 0; i < getSize(); i++) {                                     \
      nc::_##t v = _at<nc::_##t>(i), r = (nc::_##t)std::round(v);              \
      if (std::abs(v - r) < _tolerance)                                        \
        _at<nc::_##t>(i) = r;                                                  \
      else if (v > 0)                                                          \
        _at<nc::_##t>(i) = std::floor(v + 0.5);                                \
      else                                                                     \
        _at<nc::_##t>(i) = std::ceil(v + 0.5);                                 \
    }                                                                          \
    break;

    switch (getType()) { ct(f16) ct(f32) ct(f64) ct(f80)   }
#undef ct
    return *this;
  }

public:
  static nc::VDim createDim(const py::args shape) {
    nc::VDim dims;
    // create dims vect
    for (auto arg : shape)
      dims.push_back(arg.cast<int>());
    return dims;
  }

  static nc::VDim createDim(const vector<ssize_t> shape) {
    nc::VDim dims;
    // create dims vect
    for (auto arg : shape)
      dims.push_back(arg);
    return dims;
  }

  static nc::VDim createDim(const py::array_t<double> &a) {
    return createDim(a.request().shape);
  }

  py::array_t<double> createNumpy(const nc::NC a) {
    py::array_t<double> pa(a.getDims()); // result array_t
    a.toBuffer(static_cast<double *>(
        pa.request().ptr)); // copy data from vector to array
    return pa;
  }

  template <typename T>
  py::array_t<T> create_array() { // create numpy array based on _dtype
    py::array_t<T> pa(getDims());
    toBuffer(static_cast<T *>(pa.request().ptr));
    return pa;
  }

  template <typename To, typename Td>
  py::object conv_array() { // convert types loosing prec...
    py::array_t<Td> pa(getDims());
    auto p = static_cast<Td *>(pa.request().ptr);
    To *d = (To *)getData();
    for (auto i = 0; i < getSize(); i++)
      p[i] = (Td)d[i];
    return pa;
  }

  static ncPy magicCube(size_t n = 5) { // 2d magic cube
#define t i64
#define tp nc::_i64

    if (n % 2 == 0 || n <= 0)
      throw py::type_error("n must be odd and greater than 0");

    ncPy res(t, {n, n});
    size_t row = n / 2, col = n - 1;

    res._at<tp>(row, col) = 1;

    for (size_t i = 2; i <= n * n; ++i) {
      size_t nextRow = (row - 1 + n) % n, nextCol = (col + 1) % n;

      if (res._at<tp>(nextRow, nextCol) == 0) {
        row = nextRow;
        col = nextCol;
      } else
        row = (row + 1) % n;

      res._at<tp>(row, col) = i;
    }

    return res;
  }
#undef t
#undef tp
};

string to_string(const nc::NC::DataType &dtype) {
  return nc::NC::_getTypeString(dtype);
}
nc::NC::DataType from_string(const string &stype) {
  return nc::NC::_getStringType(stype);
}

PYBIND11_MODULE(numc, m) {
  m.doc() = "numc object, numpy inspired subset";
  py::enum_<ncPy::DataType>(m, "DataType")
      .value("i8", nc::NC::i8)
      .value("i16", nc::NC::i16)
      .value("i32", nc::NC::i32)
      .value("i64", nc::NC::i64)
      .value("i128", nc::NC::i128)

      .value("f16", nc::NC::f16)
      .value("f32", nc::NC::f32)
      .value("f64", nc::NC::f64)
      .value("f80", nc::NC::f80)
      .value("f128", nc::NC::f128)
      .value("fmp", nc::NC::fmp)
      .export_values();
  py::implicitly_convertible<std::string, nc::NC::DataType>();

  m.def("array", [](nc::NC::DataType _dtype, const py::args shape) {
    return ncPy(nc::NC(_dtype, ncPy::createDim(shape)));
  });
  m.def("array", [](string sarr) { return ncPy(nc::NC::fromString(sarr)); });
  m.def(
      "array",
      [](const py::list list) { // double list
        ncPy a(nc::NC(nc::NC::f64, {py::len(list)}));
        size_t i = 0;
        for (auto &l : list)
          a._at<nc::_f64>(i++) = l.cast<double>();

        return a;
      },
      "array(type, list)");
  m.def("array", [](string _dtype, const py::args shape) {
    return ncPy(nc::NC(from_string(_dtype), ncPy::createDim(shape)));
  });
  m.def("ones", [](nc::NC::DataType _dtype, const py::args shape) {
    return ncPy(nc::NC::ones(_dtype, ncPy::createDim(shape)));
  });
  m.def("randomize", []() { srand(time(nullptr)); });
  m.def("rand", [](nc::NC::DataType _dtype, const py::args shape) {
    return ncPy(nc::NC::Rand(_dtype, ncPy::createDim(shape)));
  });
  m.def("randq", [](nc::NC::DataType _dtype, const size_t d) {
    return ncPy(nc::NC::Rand(_dtype, {d, d})), "quadratic random matrix n x n";
  });
  m.def("identity", [](nc::NC::DataType _dtype, const int n) {
    return ncPy(nc::NC::identity(_dtype, n));
  });
  m.def("magic", &ncPy::magicCube, "2d magic cube");
  m.def("arange", &ncPy::arange, py::arg("_dtype") = nc::NC::f64,
        "multidimensional range");

  m.def("fromNumpy", py::overload_cast<const py::object>(&ncPy::fromNumpy),
        "load from numpy array");
  m.def("fromNumpy",
        py::overload_cast<const nc::NC::DataType, const py::object>(
            &ncPy::fromNumpy),
        "load from numpy array converting to type");

  m.def("fromBytes", &ncPy::fromBytes, "array from bytes");
  m.def(
      "fromString",
      [](nc::NC::DataType _dtype, const string s) {
        return ncPy(nc::NC::fromString(_dtype, s));
      },
      "array from string");
  m.def(
      "load", [](const string &name) { return ncPy(nc::NC::load(name)); },
      "load from .npy file");

  // the 3 letter funcs -> default f64
  m.def("arr", [](const py::args shape) { return ncPy(nc::NC::f64, shape); });
  m.def(
      "rsq",
      [](const size_t d) { return ncPy(nc::NC::Rand(nc::NC::f64, {d, d})); },
      "random sqare matrix");
  m.def("one", [](const py::args shape) {
    return ncPy(nc::NC::ones(nc::NC::f64, ncPy::createDim(shape)));
  });
  m.def(
      "rnd",
      [](const py::args shape) {
        return ncPy(nc::NC::Rand(nc::NC::f64, ncPy::createDim(shape)));
      },
      "normalized randon array");

  m.def(
      "rng",
      [](const py::args shape) { return ncPy::arange(nc::NC::f64, shape); },
      "multidimensional range");

  // mpreal precision functions
  m.def("set_precision", [](const int prec) { mpfr_set_default_prec(prec); },
        "set precision");
  m.def("get_precision", []() { return mpfr_get_default_prec(); },
        "get precision");

  py::class_<ncPy>(m, "numc")
      .def(py::init<nc::NC::DataType, py::args>(), "Constructor for numc")
      .def("__len__", &ncPy::getSize)
      .def("__getitem__", &ncPy::get, "Get an element")
      .def("__setitem__", &ncPy::setMultDim, "Set an element")

      .def_property_readonly(
          "clone", [](const ncPy &self) { return ncPy(self); },
          "Creates a deep copy of the object")
      .def_property_readonly(
          "copy", [](const ncPy &self) { return ncPy(self); },
          "Creates a deep copy of the object")
      .def(
          "reshape",
          [](const ncPy &self, const py::args shape) {
            return ncPy(self.reshape(ncPy::createDim(shape)));
          },
          "reshape array to new dim of the same size")
      .def_property_readonly(
          "flattern",
          [](const ncPy &self) { return ncPy(self.reshape({self.getSize()})); },
          "reshape to a flat array")
      .def(
          "astype",
          [](const ncPy &self, const nc::NC::DataType _dtype) {
            return ncPy(self.convert(_dtype));
          },
          "convert to new type")
      .def(
          "astype",
          [](const ncPy &self, const string _stype) {
            return ncPy(self.convert(from_string(_stype)));
          },
          "convert to new type")

      .def("toNumpy", &ncPy::toNumpy, "convert to numpy array")
      .def_property_readonly("np", &ncPy::toNumpy, "convert to numpy array")
      .def(
          "eps",
          [](const ncPy &self, const double _eps) {
            return ncPy(self.eps(_eps));
          },
          "if abs(a[i]<eps) -> 0")
      .def_property_readonly(
          "round", [](const ncPy &self) { return ncPy(self.round()); }, "round")
      .def("tolerance", &ncPy::tolerance, "inplace tolerance")

      .def_property_readonly(
          "det", [](const ncPy &self) { return ncPy(self.det()); },
          "determinant")

      .def_property_readonly(
          "inv", [](const ncPy &self) { return ncPy(self.inv()); },
          "inverse matrix")
      .def(
          "dot",
          [](const ncPy &self, const ncPy &o) { return ncPy(self.dot(o)); },
          "dot product")

      .def_property_readonly(
          "min", [](const ncPy &self) { return ncPy(self.min()); }, "min")
      .def_property_readonly(
          "max", [](const ncPy &self) { return ncPy(self.max()); }, "max")
      .def_property_readonly(
          "mean", [](const ncPy &self) { return ncPy(self.mean()); }, "mean")
      .def_property_readonly(
          "std", [](const ncPy &self) { return self.stdev(); }, "std")
      .def_property_readonly(
          "sum", [](const ncPy &self) { return ncPy(self.sum()); }, "sum")
      .def_property_readonly(
          "sumDiag", [](const ncPy &self) { return ncPy(self.sumDiag()); },
          "sum diagonals")
      .def_property_readonly(
          "ndims", [](const ncPy &self) { return self.get_ndims(); },
          "# of dimensions")
      .def_property_readonly(
          "norm", [](ncPy &self) { return ncPy(self.norm()); },
          "inplace normalize 0..1 range")
      .def_property_readonly(
          "abs", [](ncPy &self) { return ncPy(self.abs()); }, "abs")

      .def(
          "fill", [](ncPy &self, double v) { return ncPy(self.fill(v)); },
          "fill array with constant")

      .def_property_readonly(
          "sort", [](const ncPy &self) { return ncPy(self.sort()); },
          "return sorted array")
      .def_property_readonly(
          "inSort", [](ncPy self) { return ncPy(self.inSort()); },
          "in place sorted array")

      .def_property_readonly("toBytes", &ncPy::toBytes, "convert to bytes")

      .def("save", &ncPy::save, "save array to numpy compatible file")

      .def("apply", &ncPy::apply,
           "apply python function (x) to all items of array")
      .def("_apply", &ncPy::_apply,
           "apply bool compiler function (x) to all items of array")

      .def("count", &ncPy::count,
           "count items satisfy python function bool foo(x)")
      .def("_count", &ncPy::_count,
           "count items satisfy python function bool foo(x)")

      .def("match", &ncPy::match,
           "1d array with items that satisfy python function bool foo(x)")
      .def("_match", &ncPy::_match,
           "1d array with items that satisfy bool compiler function foo(x)")
      .def("filter", &ncPy::_match,
           "1d array with items that satisfy bool compiler function foo(x)")

      .def_property_readonly("toCSV", &ncPy::toCSV, "array to string as csv")

      .def(py::self + py::self)
      .def(py::self - py::self)
      .def(py::self * py::self)
      .def(py::self / py::self)

      .def(py::self + py::array_t<double>())
      .def(py::self - py::array_t<double>())
      .def(py::self * py::array_t<double>())
      .def(py::self / py::array_t<double>())

      .def(py::self + py::array_t<float>())
      .def(py::self - py::array_t<float>())
      .def(py::self * py::array_t<float>())
      .def(py::self / py::array_t<float>())

#define operConst(op, type) .def(py::self op type())
#define allTypes(op) operConst(op, int) operConst(op, double)
          allTypes(+) allTypes(-) allTypes(*) allTypes(/)
#undef operConst
#undef allTypes

      .def(py::self == py::self)
      .def(py::self != py::self)

      .def(py::self == double())
      .def(py::self != double())

      .def(py::self == int())
      .def(py::self != int())

      .def("dump", &ncPy::dump,
           py::arg("msg") = "array:", py::arg("withData") = true,
           "dump internals")
      .def("__repr__", &ncPy::print, "print support")
      //  properties
      .def_property_readonly("shape", &ncPy::getShape, "get shape")
      .def_property_readonly("type", &ncPy::getType, "get type")
      .def_property_readonly("size", &ncPy::getSize, "total # items")
      .def_property_readonly("sizeBytes", &ncPy::getSizeBytes,
                             "total # bytes in array")
      .def_property_readonly("v", &ncPy::get0, "Get item 0")
      .def_property_readonly("value", &ncPy::get0, "Get item 0")

      .def_property_readonly(
          "T", [](const ncPy &self) { return ncPy(self.transpose()); },
          "transpose");
}
