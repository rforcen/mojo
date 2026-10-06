/*
 NC: numpy inspired multi dimensional matrix
 * requires c++20

 usage:

     NC a(f64, 3,4,4);
*/
#pragma once

#include <assert.h>
#include <charconv>
#include <cmath>
#include <cstdarg>
#include <fstream>
#include <iostream>
#include <limits>
#include <numeric>
#include <regex>
#include <sstream>
#include <stdexcept>
#include <string>
#include <system_error>
#include <tuple>
#include <type_traits>
#include <vector>

#include <omp.h>
#include <quadmath.h>

#include "compiler.h"
#include "half.h"
#include "mpreal.h"

using namespace std;
using namespace half_float; // f16 support
using namespace mpfr;

// helpers
ostream &operator<<(ostream &os, __float128 value) {
  char buffer[128];
  quadmath_snprintf(buffer, sizeof(buffer), "%.30Qg", value);

  os << buffer;

  return os;
}

namespace nc {

/////////////////// supported data types

using _u8 = uint8_t;
using byte = uint8_t;
using _i8 = int8_t;
using _i16 = int16_t;
using _i32 = int32_t;
using _i64 = int64_t;
using _i128 = __int128_t;

using _f16 = half;
using _f32 = float;
using _f64 = double;
using _f80 = long double;
using _f128 = __float128;
using _fmp = mpreal;

typedef vector<size_t> VDim;
typedef vector<vector<size_t>> VVInt;
using VInt = VDim;

const vector<int> sizeTypes = {1, 2, 4, 8, 16, 2, 4, 8, 16, 16, sizeof(mpreal)};
const vector<string> nameTypes = {"i8",  "i16", "i32", "i64",  "i128", "f16",
                                  "f32", "f64", "f80", "f128", "fmp"};
enum DataType { i8, i16, i32, i64, i128, f16, f32, f64, f80, f128, fmp };

// precision converter
class Converters {
public:
#define ct(t)                                                                  \
  static mpreal to_mp(_##t value) { return mpreal((long double)value); }
  ct(f128) ct(i128) ct(f32) ct(f64) ct(f16) ct(f80) ct(i8) ct(i32) ct(i64)
#undef ct
#define ct(t)                                                                  \
  static _##t from_mp_##t(mpreal value) { return (_##t)((long double)value); }
      ct(f128) ct(i128) ct(f32) ct(f64) ct(f16) ct(f80) ct(i8) ct(i32) ct(i64)
#undef ct
};

// NC main class
class NC {
public:
  enum DataType { i8, i16, i32, i64, i128, f16, f32, f64, f80, f128, fmp };

private:
  vector<byte> _data;
  byte *pdata = nullptr, *edata = nullptr;
  size_t size = 0, sizeBytes = 0, dim0 = 0;
  VDim dims, mlt;
  int ndims = 0, szType = 0;
  DataType _dtype = f64;
  char charType = 'f';

public:
  NC() {}

  template <typename... Args>
  NC(DataType _dtype, Args... args)
      : _dtype(_dtype) { // supports int & size_t args
    dims = createVector(args...);
    _recalc();
  }
  /*template <typename... Args>  // default f64
  NC(Args... args) : _dtype(f64) {
    dims = createVector(args...);
    _recalc();
  }*/
  NC(DataType _dtype, VDim dims) : _dtype(_dtype), dims(dims) { _recalc(); }

  NC(const NC &o) {
    _data = o._data;

    pdata = _data.data();
    edata = _data.data() + o.sizeBytes;

    size = o.size;
    sizeBytes = o.sizeBytes;
    dim0 = o.dim0;

    dims = o.dims;
    mlt = o.mlt;

    ndims = o.ndims;
    szType = o.szType;

    _dtype = o._dtype;
    charType = o.charType;
  }

  NC dtype(DataType _dtype) { // define a new type
    this->_dtype = _dtype;

    _resizeData();
    return *this;
  }

  static NC ones(DataType _dtype, VDim dims) {
    NC a(_dtype, dims);
#define set1(T)                                                                \
  case T:                                                                      \
    for (size_t i = 0; i < a.size; i++)                                        \
      a._at<_##T>(i) = 1;                                                      \
    break

    switch (_dtype) {
      set1(f16);
      set1(f32);
      set1(f64);
      set1(f80);
      set1(f128);
      set1(fmp);

      set1(i8);
      set1(i16);
      set1(i32);
      set1(i64);
      set1(i128);

    default:;
    }
#undef set1

    return a;
  }

  static NC identity(DataType _dtype, size_t n) {
    NC nc(_dtype, {n, n});

#define set1(T)                                                                \
  case T:                                                                      \
    for (size_t i = 0; i < n; i++)                                             \
      nc._at<_##T>(i, i) = 1;                                                  \
    break

    switch (_dtype) {
      set1(f16);
      set1(f32);
      set1(f64);
      set1(f80);
      set1(f128);
      set1(fmp);

      set1(i8);
      set1(i16);
      set1(i32);
      set1(i64);
      set1(i128);
    default:;
    }

    return nc;
  }
  static NC Rand(DataType _dtype, VDim dims) {
    NC a(_dtype, dims);
    a.rand();
    return a;
  }
  static NC FromBuffer(DataType _dtype, VDim dims, void *buffer) {
    NC a(_dtype, dims);
    a.fromBuffer(buffer);
    return a;
  }
  static NC arange(DataType _dtype, VDim dims) {
    NC a(_dtype, dims);

    if (a.ndims == 1) {
#define ct(t)                                                                  \
  case t:                                                                      \
    for (auto i = 0; i < a.dim(0); i++)                                        \
      a._at<_##t>(i) = (_##t)i;                                                \
    break;
      switch (_dtype) {
        ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
            ct(f128) ct(fmp)
      }
#undef ct
    } else {
#define ct(t)                                                                  \
  case t:                                                                      \
    for (auto i = 0; i < s.dim(0); i++)                                        \
      s._at<_##t>(i) = (_##t)i;                                                \
    break;
      VInt tdims(dims.begin(), dims.end() - 1);
      for (auto d : a.combinations(tdims)) {
        auto s = a.slice(d);

        switch (_dtype) {
          ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64)
              ct(f80) ct(f128) ct(fmp)
        }
        a.assign(s, d);
      }
#undef ct
    }

    return a;
  }
  static NC fromString(string sarr) { // converts to f64
    vector<double> d = __fromString<double>(
        sarr, R"([+-]?(?:\d+(?:[.,]\d*)?|[.,]\d+)(?:e[+-]?\d+)?)");

    NC res(f64, {d.size()});
    for (size_t i = 0; i < res.size; i++)
      res._at<_f64>(i) = d[i];

    return res;
  }
  static NC fromString(DataType _dtype, string sarr) { // converts to f64
    const string re = R"([+-]?(?:\d+(?:[.,]\d*)?|[.,]\d+)(?:e[+-]?\d+)?)";

#define ct(t)                                                                  \
  case t: {                                                                    \
    vector<_##t> d = __fromString<_##t>(sarr, re);                             \
    NC a(t, {d.size()});                                                       \
    for (size_t i = 0; i < a.size; i++)                                        \
      a._at<_##t>(i) = d[i];                                                   \
    return a;                                                                  \
  } break;

    switch (_dtype) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
          ct(f128) ct(fmp)
    }
#undef ct
    return NC();
  }
  // index ///////////////////////////

  template <typename T> /// checked 1d
  inline T &cat(size_t index) const {
    if (index >= size)
      throw out_of_range("index out of range");
    return *(T *)(&_data[index * szType]);
  }

  template <typename T> /// fast unchecked 1d
  inline T &_at(size_t index) const {
    return *(T *)(&_data[index * szType]);
  }

  template <typename T> // 2d unchecked 2d
  inline T &_at(size_t r, size_t c) const {
    return *(T *)(&_data[(r * dim0 + c) * szType]);
  }

  template <typename T,
            typename... Args> // index checked, fastest solution found
  inline T &at(vector<size_t> args) {
    size_t ix = calcIndex(args);
    if (ix >= size)
      throw out_of_range("index out of range");

    return *reinterpret_cast<T *>(&_data[ix * szType]);
  }

  template <typename T,
            typename... Args> // index checked, fastest solution found
  inline T &at(T first, Args... args) {
    size_t ix = first * mlt[0];

    if constexpr (sizeof...(args) == 0) {        // 1 index, done
    } else if constexpr (sizeof...(args) == 1) { // 2 indexes
      ix += get<0>(make_tuple(args...)) * mlt[1];
    } else {
      if (sizeof...(args) != ndims - 1)
        throw invalid_argument("wrong number of indexes:" + to_string(ndims));

      size_t i = 1;
      apply([this, &i, &ix](auto &&...args) { ((ix += args * mlt[i++]), ...); },
            make_tuple(args...));
    }

    if (ix >= size)
      throw out_of_range("index out of range:" + to_string(ix) +
                         " out of range 0.." + to_string(size - 1));

    return *reinterpret_cast<T *>(&_data[ix * szType]);
  }
  // r,c index
  template <typename T> inline T &operator()(size_t r, size_t c) {
    return *reinterpret_cast<T *>(&_data[(r * dim0 + c) * szType]);
  } // nc(i,j)
  template <typename T> inline T &operator()(size_t i) {
    return *reinterpret_cast<T *>(&_data[i * szType]);
  } // nc(i)
  NC slice(
      const VDim &index) const { // index is < ndim-1 size, NC a(3,4,5); auto
    // b=a.slice({2,3});
    assert(!index.empty() && "slice with empty array not allowed");

    auto widx = index; // end fill w/0
    widx.insert(widx.end(), ndims - widx.size(), 0);
    size_t istart = calcIndex(widx);

    widx = index; // end fill with dims[i]-1
    for (int i = index.size(); i < ndims; i++)
      widx.push_back(dims[i] - 1);
    auto iend = calcIndex(widx) + 1;

    auto sz = ndims - index.size();
    copy(dims.begin() + index.size(), dims.begin() + index.size() + sz,
         widx.begin()); // widx=dims[szIndex..szDims-szIndex]
    widx.resize(sz);

    NC res(_dtype, widx);

    copy(_data.begin() + istart * szType, _data.begin() + iend * szType,
         res._data.begin());

    return res;
  }
  ////////////////////////
  void fromBuffer(const void *buff) { memcpy(_data.data(), buff, sizeBytes); }

  void toBuffer(void *buff) const { memcpy(buff, _data.data(), sizeBytes); }

  VDim getDims() const { return dims; }
  int get_ndims() const { return ndims; }

  size_t getSize() const { return size; }

  DataType getType() const { return _dtype; }

  string getTypeString() const { return nameTypes[_dtype]; }

  static string _getTypeString(DataType _dtype) { return nameTypes[_dtype]; }
  static DataType _getStringType(const string &s) {
#define dm(t) {nameTypes[t], t}
    map<string, DataType> dtMap = {dm(i8),   dm(i16),  dm(i32), dm(i64),
                                   dm(i128), dm(f16),  dm(f32), dm(f64),
                                   dm(f80),  dm(f128), dm(fmp)};
#undef dm
    if (dtMap.find(s) != dtMap.end())
      return dtMap[s];
    else
      throw invalid_argument(string("unknown type:") + s);
  }

  size_t getSizeBytes() const { return sizeBytes; }

  void *getData() const { return (void *)_data.data(); }

  double getDouble(size_t i) { // get i value as double
#define rv(t)                                                                  \
  case t:                                                                      \
    return (double)_at<_##t>(i);
    switch (_dtype) {
      rv(i8) rv(i16) rv(i32) rv(i64) rv(i128) rv(f16) rv(f32) rv(f64) rv(f80)
          rv(f128) rv(fmp)
    }
#undef rv
  }

  // arithmetic ops

#define doOper(oper, T)                                                        \
  case T:                                                                      \
    return oper<_##T>(o)

#define operate(oper)                                                          \
  switch (_dtype) {                                                            \
    doOper(oper, i8);                                                          \
    doOper(oper, i16);                                                         \
    doOper(oper, i32);                                                         \
    doOper(oper, i64);                                                         \
    doOper(oper, i128);                                                        \
    doOper(oper, f16);                                                         \
    doOper(oper, f32);                                                         \
    doOper(oper, f64);                                                         \
    doOper(oper, f80);                                                         \
    doOper(oper, f128);                                                        \
    doOper(oper, fmp);                                                         \
  }

  // +
  template <typename T> NC add(const NC &o) const {
    NC res(*this);
    for (size_t i = 0; i < size; i++)
      res._at<T>(i) += o._at<T>(i);

    return res;
  }
  template <typename T> NC add(const T o) const {
    NC res(*this);
    for (size_t i = 0; i < size; i++)
      res._at<T>(i) += o;

    return res;
  }
  NC operator+(const NC &_o) const {
    if (!eqDims(_o.dims))
      throw invalid_argument("can't sum matrix of different dimensions");
    if (_dtype != _o._dtype) {
      auto o = _o.convert(_dtype);
      operate(add);
    } // convert 'o' to _dtype
    else {
      NC o(_o);
      operate(add);
    }
  }
  NC operator+=(NC &o) {
    *this = *this + o;
    return *this;
  }

  // template <typename T>  auto operator+(const T o) const ->
  // std::enable_if_t<!std::is_same_v<T, NC>, NC>     { return add<T>(o); } //
  // can't coexist with NC operator+(const NC &o) const

  // template <typename T> NC operator+=(T o) { return *this = add(o);  }
  //  -
  template <typename T> NC sub(const NC &o) const {
    NC res(*this);
    for (size_t i = 0; i < size; i++)
      res._at<T>(i) -= o._at<T>(i);

    return res;
  }
  template <typename T> NC sub(T o) const {
    NC res(*this);
    for (size_t i = 0; i < size; i++)
      res._at<T>(i) -= o;

    return res;
  }
  NC operator-(const NC &_o) const {
    if (!eqDims(_o.dims))
      throw invalid_argument("can't operate matrix of different dimensions");
    if (_dtype != _o._dtype) {
      auto o = _o.convert(_dtype);
      operate(sub);
    } // convert 'o' to _dtype
    else {
      NC o(_o);
      operate(sub);
    }
  }
  NC operator-=(NC &o) {
    *this = *this - o;
    return *this;
  }
  // template <typename T> NC operator-(const T o) const { return sub<T>(o); }
  // template <typename T> NC operator-=(T o) { return *this = sub(o); }
  // NC operator-(const double o) const { return sub<double>(o); }
  //  *
  template <typename T> NC mul(const NC &o) const {
    NC res(*this);
    for (size_t i = 0; i < size; i++)
      res._at<T>(i) *= o._at<T>(i);

    return res;
  }
  template <typename T> NC mul(T o) const {
    NC res(*this);
    for (size_t i = 0; i < size; i++)
      res._at<T>(i) *= o;

    return res;
  }
  NC operator*(const NC &_o) const {
    if (!eqDims(_o.dims))
      throw invalid_argument("can't operate matrix of different dimensions");
    if (_dtype != _o._dtype) {
      auto o = _o.convert(_dtype);
      operate(mul);
    } // convert 'o' to _dtype
    else {
      NC o(_o);
      operate(mul);
    }
  }
  NC operator*=(NC &o) {
    *this = *this * o;
    return *this;
  }
  // template <typename T> NC operator*(const T o) const { return mul<T>(o); }
  // template <typename T> NC operator*=(T o) { return *this = mul(o); }
  // NC operator*(const double o) const { return mul<double>(o); }
  //  /
  template <typename T> NC div(const NC &o) const {
    NC res(*this);
    for (size_t i = 0; i < size; i++)
      res._at<T>(i) /= o._at<T>(i);

    return res;
  }
  template <typename T> NC div(T o) const {
    NC res(*this);
    for (size_t i = 0; i < size; i++)
      res._at<T>(i) /= o;

    return res;
  }
  NC operator/(const NC &_o) const {
    if (!eqDims(_o.dims))
      throw invalid_argument("can't div matrix of different dimensions");
    if (_dtype != _o._dtype) {
      auto o = _o.convert(_dtype);
      operate(div);
    } // convert 'o' to _dtype
    else {
      NC o(_o);
      operate(div);
    }
  }
  NC operator/=(NC &o) {
    *this = *this / o;
    return *this;
  }
  // template <typename T> NC operator/(const T o) const { return div<T>(o); }
  // template <typename T> NC operator/=(T o) { return *this = div(o); }
  // NC operator/(const double o) const { return div<double>(o); }

  template <typename T> NC __add(T o) const {
    NC res(*this);
#define ct(t)                                                                  \
  case t:                                                                      \
    for (size_t i = 0; i < size; i++)                                          \
      res._at<_##t>(i) += (_##t)o;                                             \
    break;
    switch (_dtype) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128)

          ct(f16) ct(f32) ct(f64) ct(f80) ct(f128) ct(fmp)
    }
#undef ct
    return res;
  }
  template <typename T> NC __sub(T o) const {
    NC res(*this);
#define ct(t)                                                                  \
  case t:                                                                      \
    for (size_t i = 0; i < size; i++)                                          \
      res._at<_##t>(i) -= (_##t)o;                                             \
    break;
    switch (_dtype) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128)

          ct(f16) ct(f32) ct(f64) ct(f80) ct(f128) ct(fmp)
    }

    return res;
#undef ct
  }
  template <typename T> NC __mul(T o) const {
    NC res(*this);
#define ct(t)                                                                  \
  case t:                                                                      \
    for (size_t i = 0; i < size; i++)                                          \
      res._at<_##t>(i) *= (_##t)o;                                             \
    break;
    switch (_dtype) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128)

          ct(f16) ct(f32) ct(f64) ct(f80) ct(f128) ct(fmp)
    }
    return res;
#undef ct
  }
  template <typename T> NC __div(T o) const {
    NC res(*this);
#define ct(t)                                                                  \
  case t:                                                                      \
    for (size_t i = 0; i < size; i++)                                          \
      res._at<_##t>(i) /= (_##t)o;                                             \
    break;
    switch (_dtype) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128)

          ct(f16) ct(f32) ct(f64) ct(f80) ct(f128) ct(fmp)
    }
    return res;
#undef ct
  }
#define operConst(op, func, t)                                                 \
  NC operator op(const t o) const { return func<t>(o); }
#define allTypes(op, func)                                                     \
  operConst(op, func, int)                                                     \
      operConst(op, func, double) // support int & double types

  allTypes(+, __add) allTypes(-, __sub) allTypes(*, __mul) allTypes(/, __div)
#undef operConst
#undef allTypes

      // logical ops

      // ==
      template <typename T>
      bool eq(const NC o) const {
    for (size_t i = 0; i < size; i++)
      if (_at<T>(i) != o._at<T>(i))
        return false;
    return true;
  }

  bool operator==(const NC &o) const {
    if (!eqDims(o.dims))
      throw invalid_argument("can't operate matrix of different dimensions");

    operate(eq);
  }

  bool operator==(const double d) const {
#define ct(t)                                                                  \
  case t:                                                                      \
    for (size_t i = 0; i < size; i++)                                          \
      if (_at<_##t>(i) != d)                                                   \
        return false;                                                          \
    break;

    switch (_dtype) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
          ct(f128) ct(fmp)
    }
#undef ct
    return true;
  }

  bool operator!=(const double d) const { return !(*this == d); }

  bool operator!=(const NC &o) const { return !(*this == o); }

  //////////////////////////
  string Int128ToString(__int128 value) const {
    std::stringstream ss;
    bool isNegative = value < 0;
    if (isNegative) {
      value = -value;
      ss << '-';
    }
    __uint128_t temp = value;
    std::string result;
    do {
      result += '0' + temp % 10;
      temp /= 10;
    } while (temp > 0);
    std::reverse(result.begin(), result.end());
    ss << result;
    return ss.str();
  }

  template <typename T> size_t checksum() {
    uint64_t checksum = 0;
    const byte *bytes = reinterpret_cast<const byte *>(_data.data());
    size_t num_uint64 = sizeBytes / sizeof(uint64_t);
    size_t remaining_bytes = sizeBytes % sizeof(uint64_t);

    for (size_t i = 0; i < num_uint64; ++i)
      checksum ^= *(uint64_t *)(bytes + i * sizeof(T));

    if (remaining_bytes > 0) {
      uint64_t last_chunk = 0;
      std::memcpy(&last_chunk, bytes + num_uint64 * sizeof(uint64_t),
                  remaining_bytes);
      checksum ^= last_chunk;
    }

    return checksum;
  }

  template <typename T> void push(T v) { // push back 1 item
    size++;
    dims[0]++;
    _resizeData();

#define ct(t)                                                                  \
  case t:                                                                      \
    _at<_##t>(size - 1) = _##t(v);                                             \
    break;

    switch (_dtype) {
    ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
        ct(f128)
        //
        case fmp:
      _at<_fmp>(size - 1) = Converters::to_mp(v);
      break;
    }
#undef ct
  }

  // numpy interface
private:
  // misc
  string fmt(const char *format, ...) const {
    char buffer[1024 * 4];

    memset(buffer, 0, sizeof(buffer));

    va_list args;
    va_start(args, format);

    vsnprintf(buffer, sizeof(buffer) - 1, format, args);

    va_end(args);
    return buffer;
  }
  typedef struct _HeaderNPY { // numpy file header (np.save / load)
    _HeaderNPY(uint16_t headLen) : headLen(headLen) {}
    _HeaderNPY() {}

    char id[6] = {'\x93', 'N', 'U', 'M', 'P', 'Y'};
    char minVer = 1, maxVer = 0;
    uint16_t headLen;
  } HeaderNPY;

  string dimsStr() const {
    string s;
    for (int i = 0; i < ndims; i++) {
      s += to_string(dims[i]);
      if (i < ndims - 1)
        s += ',';
    }
    return s;
  }
  static VDim descToDims(string desc) { // (#,#,#,#...)
    auto start = desc.find('('), end = desc.find(')', start);
    desc = desc.substr(start + 1, end - start - 1);

    auto _desc = desc.c_str();

    return strToDims(desc);
  }
  static VDim strToDims(string desc) { // #,#,...,#
    return __string2VInt(desc);
  }

  static VDim __string2VInt(const string &s) {
    VDim v;
    regex re(R"(\d+)");

    for (auto it = sregex_token_iterator(s.begin(), s.end(), re);
         it != sregex_token_iterator(); it++) {
      try {
        v.push_back(stol(*it));
      } catch (const invalid_argument &e) {
        cerr << *it << ":invalid number" << endl;
      }
    }

    return v;
  }

  template <typename T> static T string_to_numeric(const std::string &str) {
    T value{};

    // 1. Handle Standard Integers and Floats (C++17/20)
    if constexpr (std::is_arithmetic_v<T>) {
      auto [ptr, ec] =
          std::from_chars(str.data(), str.data() + str.size(), value);
      if (ec != std::errc{}) {
        // Fallback for floating point if your compiler's from_chars
        // doesn't support float yet (common in older GCC)
        if constexpr (std::is_floating_point_v<T>) {
          value = static_cast<T>(std::stod(str));
        }
      }
    }
    // 2. Handle __int128_t (No standard from_chars support)
    else if constexpr (std::is_same_v<T, __int128_t> ||
                       std::is_same_v<T, __uint128_t>) {
      // Simple manual conversion for 128-bit
      bool neg = (str[0] == '-');
      for (size_t i = neg ? 1 : 0; i < str.size(); ++i) {
        value = value * 10 + (str[i] - '0');
      }
      if (neg)
        value = -value;
    }
    // 3. Handle _f16 (half-precision)
    else if constexpr (std::is_same_v<T, half>) {
      // Convert to float first, then downcast to half
      value = static_cast<half>(std::stof(str));
    }

    return value;
  }

  template <typename T>
  static vector<T> __fromString(const string &s, const string regExp) {
    regex re(regExp);

    vector<T> v;
    for (auto it = sregex_token_iterator(s.begin(), s.end(), re);
         it != sregex_token_iterator(); it++) {
      try {
        v.push_back(string_to_numeric<T>(*it));
      } catch (const invalid_argument &e) {
        cerr << *it << ":invalid number" << endl;
      }
    }

    return v;
  }

public:
  void save(const string &name) const {
    ofstream fs(name, ios::binary);

    if (fs) {
      string desc =
          fmt("{'descr':'<%c%d', 'fortran_order':False, 'shape':(%s,)}",
              charType, szType, dimsStr().c_str());

      int szHdr = sizeof(HeaderNPY) + desc.length() + 1; // header size + $0a
      desc += string(64 * ((szHdr / 64) + 1) - szHdr, ' ') + '\x0a';

      HeaderNPY hdr(desc.size());

      // write header, desc, data
      fs.write((char *)&hdr, sizeof(hdr));
      fs << desc;
      fs.write((char *)_data.data(), sizeBytes);

      fs.close();
    }
  }

  static NC load(const string &name) {
    ifstream fs(name, ios::binary);

    NC nc;

    if (fs) {
      HeaderNPY hdr;

      fs.read((char *)&hdr, sizeof(hdr));

      string desc(hdr.headLen, ' ');
      fs.read(desc.data(), desc.size());

      // get type
      string searchStr = "'descr':'<";
      auto pos = desc.find(searchStr);
      if (pos == string::npos) {
        cout << "bad format\n";
        return nc;
      }

      pos += searchStr.length();
      auto tp = desc[pos];
      int sz = stoi(desc.substr(pos + 1));

      DataType dt = f64;
      map<int, DataType> imap = {{1, i8}, {2, i16}, {4, i32}, {8, i64}};
      map<int, DataType> fmap = {
          {4, f32}, {8, f64}, {16, f80}, {16, f128}, {sizeof(mpreal), fmp}};

      switch (tp) {
      case 'i':
        dt = imap[sz];
        break;
      case 'f':
        dt = fmap[sz];
        break;
      default:
        cout << "bad format\n";
        return nc;
      }

      nc = NC(dt, descToDims(desc)); // (#,#,#)

      fs.read((char *)nc._data.data(), nc.sizeBytes); // read data & close
      fs.close();
    }
    return nc;
  }

  string _toString(size_t i) const { // convert item(i) to string
    stringstream ss;

    switch (_dtype) {
    case i8:
      ss << (int)_at<_i8>(i);
      break;
    case i16:
      ss << _at<_i16>(i);
      break;
    case i32:
      ss << _at<_i32>(i);
      break;
    case i64:
      ss << _at<_i64>(i);
      break;
    case i128:
      ss << Int128ToString(_at<_i128>(i));
      break;
    case f16:
      ss << _at<_f16>(i);
      break;
    case f32:
      ss << _at<_f32>(i);
      break;
    case f64:
      ss << _at<_f64>(i);
      break;
    case f80:
      ss << _at<_f80>(i);
      break;
    case f128:
      ss << _at<_f128>(i);
      break;
    case fmp:
      ss << _at<_fmp>(i);
      break;
    }
    return ss.str();
  }

  string toString() {
    if (size == 1)
      return _toString(0);

    string ret;
    for (size_t i = 0; i < size; i++) {
      ret += _toString(i);

      if (ndims > 1 && (i > 0 && ((i + 1) % dim0) == 0))
        ret += '\n';
      else
        ret += ", ";
    }
    return ret;
  }

  string toCSV() const {
    string ret;
    for (size_t i = 0; i < size; i++) {
      ret += _toString(i) + ((i < size - 1) ? ", " : "");
    }
    return ret;
  }

  void dump(string msg = "", bool withData = false) const {
    puts(msg.c_str());
    printf("type:%s, size type:%d\n", nameTypes[_dtype].c_str(), _size(_dtype));
    printf("items:%ld\nbytes:%ld\n", size, sizeBytes);
    printf("shape:");
    for (auto &d : dims)
      printf("%ld,", d);
    printf("dim0:%ld\n", dim0);

    if (withData) {
      cout << "data:\n";
      for (size_t i = 0; i < size; i++) {
        cout << _toString(i);

        if (i > 0 && ((i + 1) % dim0) == 0)
          cout << endl;
        else
          cout << ", ";
      }

      cout << endl;
    }
  }

  template <typename T> void setRandf() {
    for (auto d = (T *)pdata; d < (T *)(edata); d++)
      *d = (T)(std::rand()) / (_f32)RAND_MAX;
  }
  void setRandf16() {
    for (auto d = (_f16 *)pdata; d < (_f16 *)(edata); d++)
      *d = (_f16)(1.0 * std::rand() / RAND_MAX);
  }
  void setRandfmp() {
    for (auto d = (_fmp *)pdata; d < (_fmp *)(edata); d++)
      *d = _fmp(std::rand() / _fmp(RAND_MAX));
  }
  template <typename T> void setRandi() {
    for (auto d = (T *)pdata; d < (T *)(edata); d++)
      *d = (T)std::rand();
  }

  void rand() {
    switch (_dtype) {
    case i8:
      setRandi<_i8>();
      break;
    case i16:
      setRandi<_i16>();
      break;
    case i32:
      setRandi<_i32>();
      break;
    case i64:
      setRandi<_i64>();
      break;
    case i128:
      setRandi<_i128>();
      break;
    case f16:
      setRandf16();
      break;
    case f32:
      setRandf<_f32>();
      break;
    case f64:
      setRandf<_f64>();
      break;
    case f80:
      setRandf<_f80>();
      break;
    case f128:
      setRandf<_f128>();
      break;
    case fmp:
      setRandfmp();
      break;
    }
  }

  NC convert(DataType _newType) const { // convert from _dtype to _newtype
    if (_dtype == _newType)
      return *this;

    NC res(_newType, dims);

#define copyConv(TR, TT)                                                       \
  for (size_t i = 0; i < size; i++)                                            \
    res._at<TR>(i) = (TR)_at<TT>(i);                                           \
  break;

#define copyType(TR)                                                           \
  switch (_dtype) {                                                            \
  case i8:                                                                     \
    copyConv(TR, _i8);                                                         \
  case i16:                                                                    \
    copyConv(TR, _i16);                                                        \
  case i32:                                                                    \
    copyConv(TR, _i32);                                                        \
  case i64:                                                                    \
    copyConv(TR, _i64);                                                        \
  case i128:                                                                   \
    copyConv(TR, _i128);                                                       \
                                                                               \
  case f16:                                                                    \
    copyConv(TR, _f16);                                                        \
  case f32:                                                                    \
    copyConv(TR, _f32);                                                        \
  case f64:                                                                    \
    copyConv(TR, _f64);                                                        \
  case f80:                                                                    \
    copyConv(TR, _f80);                                                        \
  case f128:                                                                   \
    copyConv(TR, _f128);                                                       \
  case fmp:                                                                    \
    break;                                                                     \
  }                                                                            \
  break;

    switch (_newType) {
    case i8:
      copyType(_i8);
    case i16:
      copyType(_i16);
    case i32:
      copyType(_i32);
    case i64:
      copyType(_i64);
    case i128:
      copyType(_i128);

    case f16:
      copyType(_f16);
    case f32:
      copyType(_f32);
    case f64:
      copyType(_f64);
    case f80:
      copyType(_f80);
    case f128:
      copyType(_f128);
    case fmp:
      break;
      //     copyType(_fmp);
    }

    return res;
  }

  // linalg

  NC detST() const { // ST version
    NC res;

    assertQuadratic();

    if (ndims == 2) {
      res = NC(_dtype, {1});

#define DETERMINANT detBareiss

#define detAssign(T)                                                           \
  case T:                                                                      \
    res._at<_##T>(0) = DETERMINANT<_##T>();                                    \
    break;

      switch (_dtype) {
        detAssign(f16);
        detAssign(f32);
        detAssign(f64);
        detAssign(f80);
        detAssign(f128);
        detAssign(fmp);

        detAssign(i8);
        detAssign(i16);
        detAssign(i32);
        detAssign(i64);
        detAssign(i128);
      default:;
      }
    } else {
      VInt tdim(dims.begin(), dims.end() - 2); // dims[0..-2]
      res = NC(_dtype, tdim);

#define detSlice(T, D)                                                         \
  case T:                                                                      \
    res.at<_##T>(D) = slice(D).DETERMINANT<_##T>();                            \
    break;

      for (auto &c : combinations(tdim))
        switch (_dtype) {
          detSlice(f16, c);
          detSlice(f32, c);
          detSlice(f64, c);
          detSlice(f80, c);
          detSlice(f128, c);
          detSlice(fmp, c);

          detSlice(i8, c);
          detSlice(i16, c);
          detSlice(i32, c);
          detSlice(i64, c);
          detSlice(i128, c);
        default:;
        }
    }
    return res;
  }

  NC det() const { // N x N, MT version
    NC res;

    assertQuadratic();

    if (ndims == 2) {
      res = NC(_dtype, {1});
      // res._at<T>(0) = detnxn_MT<T>();
      switch (_dtype) {
        detAssign(f16);
        detAssign(f32);
        detAssign(f64);
        detAssign(f80);
        detAssign(f128);
        detAssign(fmp);

        detAssign(i8);
        detAssign(i16);
        detAssign(i32);
        detAssign(i64);
        detAssign(i128);
      default:;
      }
    } else {
      VInt tdim(dims.begin(), dims.end() - 2); // dims[0..-2]
      VVInt tdims = combinations(tdim);
      res = NC(_dtype, tdim);

#pragma omp parallel for
      for (size_t ix = 0; ix < tdims.size(); ix++) {
        // res.at<T>(tdims[ix]) = slice(tdims[ix]).detnxn_ST<T>();
        switch (_dtype) {
          detSlice(f16, tdims[ix]);
          detSlice(f32, tdims[ix]);
          detSlice(f64, tdims[ix]);
          detSlice(f80, tdims[ix]);
          detSlice(f128, tdims[ix]);
          detSlice(fmp, tdims[ix]);

          detSlice(i8, tdims[ix]);
          detSlice(i16, tdims[ix]);
          detSlice(i32, tdims[ix]);
          detSlice(i64, tdims[ix]);
          detSlice(i128, tdims[ix]);
        default:;
        }
      }
    }
    return res;
  }

  template <typename T> T detBareiss() const {
    T res = (T)(1);
    NC a(*this);

    assertQuadratic();

    size_t n = dim0;

    for (size_t i = 0; i < n; i++) {
      for (size_t j = i + 1; j < n; j++) {
        if (a.at(i, i) != static_cast<T>(0)) {
          T factor = a._at<T>(j, i) / a._at<T>(i, i);
          for (size_t k = i; k < n; k++)
            a._at<T>(j, k) -= factor * a._at<T>(i, k);
        }
      }
      res *= a._at<T>(i, i);
    }
    return res;
  }

  template <typename T> T detnxn_MT() { // LU fastest method

    assert_nxn();

    NC a(*this); // work copy

#pragma omp parallel
    for (size_t k = 0; k < dim0; ++k) {
#pragma omp for
      for (size_t i = 0; i < dim0; ++i)
        if (i > k) {
          a._at<T>(i, k) /= a._at<T>(k, k);
          for (size_t j = k + 1; j < dim0; ++j)
            a._at<T>(i, j) -= a._at<T>(i, k) * a._at<T>(k, j);
        }
    }

    return a.diagProd<T>();
  }

  template <typename T> T detnxn_ST() {
    NC a(*this); // work copy
    size_t n = dim0;

    for (size_t k = 0; k < n; ++k) {
      for (size_t i = k + 1; i < n; ++i) {
        a._at<T>(i, k) /= a._at<T>(k, k);
        for (size_t j = k + 1; j < n; ++j)
          a._at<T>(i, j) -= a._at<T>(i, k) * a._at<T>(k, j);
      }
    }

    return a.diagProd<T>();
  }

private:
  void rangeSlice(const VInt &index, size_t &aStart, size_t &aEnd) {
    if (index.empty()) {
      aStart = aEnd = 0;
    } else {
      auto widx = index; // start
      widx.insert(widx.end(), ndims - widx.size(), 0);
      aStart = calcIndex(widx);

      widx = index; // end
      for (int i = index.size(); i < ndims; i++)
        widx.push_back(dims[i] - 1);
      aEnd = calcIndex(widx) - 1;
    }
  }

  void assign(NC a, const VInt &_dims) {
    size_t aStart, aEnd;
    rangeSlice(_dims, aStart, aEnd);

    for (size_t i = 0; i < a.sizeBytes; i++)
      _data[i + aStart * szType] = a._data[i];
  }

  template <typename T> void swap(size_t i, size_t j, size_t k, size_t l) {
    auto tmp = _at<T>(i, j);
    _at<T>(i, j) = _at<T>(k, l);
    _at<T>(k, l) = tmp;
  }

public:
  void Assign(NC a, const VInt &_dims) { // checked version of assign
    size_t aStart, aEnd;
    rangeSlice(_dims, aStart, aEnd);
    if (aStart > size || aEnd > size || aStart + a.size > size)
      throw out_of_range("index out of range");
    if (_dtype != a._dtype) {
      NC an = a.convert(_dtype);
      memcpy(_data.data() + aStart * szType, an._data.data(), an.sizeBytes);
    } else {
      // for (size_t i = 0; i < a.sizeBytes; i++) _data[i + aStart * szType] =
      // a._data[i];
      memcpy(_data.data() + aStart * szType, a._data.data(), a.sizeBytes);
    }
  }

  template <typename T> NC inv_nxn() const {
    size_t n = dim0;
    NC res = identity(_dtype, n);

    NC a(*this);

    for (size_t j = 0; j < n; j++) {
      for (size_t i = j; i < n; i++) {
        if (a._at<T>(i, j) != 0) {
          for (size_t k = 0; k < n; k++) {
            a.swap<T>(j, k, i, k);
            res.swap<T>(j, k, i, k);
          }
          auto tmp = 1 / a._at<T>(j, j);
          for (size_t k = 0; k < n; k++) {
            a._at<T>(j, k) = tmp * a._at<T>(j, k);
            res._at<T>(j, k) = tmp * res._at<T>(j, k);
          }

          for (size_t k = 0; k < n; k++) {
            if (k != j) {
              tmp = -a._at<T>(k, j);
              for (size_t c = 0; c < n; c++) {
                a._at<T>(k, c) = a._at<T>(k, c) + tmp * a._at<T>(j, c);
                res._at<T>(k, c) = res._at<T>(k, c) + tmp * res._at<T>(j, c);
              }
            }
          }
          break;
        }
      }
    }

    return res;
  }

  NC inv_nxnType() const {
#define doInv(T)                                                               \
  case T:                                                                      \
    return inv_nxn<_##T>()

    switch (_dtype) {
      doInv(i8);
      doInv(i16);
      doInv(i32);
      doInv(i64);
      doInv(i128);
      doInv(f16);
      doInv(f32);
      doInv(f64);
      doInv(f80);
      doInv(f128);
      doInv(fmp);
    }
  }

public:
  NC invST() { // matrix inversion ST
    assertQuadratic();

    NC res(*this);

    if (ndims == 2) {
      res = inv_nxnType();
    } else {
      VInt tdim(dims.begin() + 0, dims.end() - 2); // dims[0..-2]
      for (auto &t : combinations(tdim))
        res.assign(slice(t).inv_nxnType(), t);
    }
    return res;
  }

  NC inv() const { // MT version
    NC res;

    assertQuadratic();

    if (ndims == 2) {
      res = inv_nxnType();
    } else {
      VInt tdim(dims.begin(), dims.end() - 2); // dims[0..-2]
      VVInt tdims = combinations(tdim);
      res = *this;

#pragma omp parallel for
      for (size_t ix = 0; ix < tdims.size(); ix++)
        res.assign(slice(tdims[ix]).inv_nxnType(), tdims[ix]);
    }
    return res;
  }

  NC dot(const NC &a) const {
    size_t pivotPos, pivd, prs;
    NC res = __prepDot(a, pivotPos, pivd, prs);

    switch (pivotPos) {
    case 0: {
#pragma omp parallel for
      for (int ix = 0; ix < prs; ix++) {
        size_t sStart = ix * pivd;

#define dotPart(T)                                                             \
  case T: {                                                                    \
    _##T p = _##T(0.0);                                                        \
    for (size_t r = 0; r < pivd; r++)                                          \
      p += _at<_##T>(sStart + r) * a._at<_##T>(r);                             \
    res._at<_##T>(ix) = p;                                                     \
  } break;

        switch (_dtype) {
          dotPart(i8);
          dotPart(i16);
          dotPart(i32);
          dotPart(i64);
          dotPart(i128);
          dotPart(f16);
          dotPart(f32);
          dotPart(f64);
          dotPart(f80);
          dotPart(f128);
          dotPart(fmp);
        }
      }

    } break;
    case 1: {
      VInt raDim;
      if (a.ndims > 2)
        raDim.insert(raDim.begin(), a.dims.begin(), a.dims.end() - 2);

      size_t pra = prod(raDim), aStride = a.size / pra, adim0 = a.dim0,
             ahi0 = a.dim0;
      size_t ahi1 = (a.ndims > 1) ? a.dim(1) : 1;

#pragma omp parallel for
      for (int ix = 0; ix < prs; ix++) {
        for (size_t ixa = 0, aStart = 0, sStart = ix * pivd,
                    ixr = ix * (pra * adim0);
             ixa < pra; ixa++, aStart += aStride) {
          for (size_t c = 0; c < ahi0; c++) {
#undef dotPart

#define dotPart(T)                                                             \
  case T: {                                                                    \
    _##T p = _##T(0);                                                          \
    for (size_t r = 0; r < ahi1; r++)                                          \
      p += _at<_##T>(sStart + r) * a._at<_##T>(aStart + r * adim0 + c);        \
    res._at<_##T>(ixr++) = p;                                                  \
  } break;
            switch (_dtype) {
              dotPart(i8);
              dotPart(i16);
              dotPart(i32);
              dotPart(i64);
              dotPart(i128);
              dotPart(f16);
              dotPart(f32);
              dotPart(f64);
              dotPart(f80);
              dotPart(f128);
              dotPart(fmp);
            }
          }
        }
      }
    } break;
    default:
      assert("dot: internal error pivot not 0 or 1");
      break;
    }

    return res;
  }

  NC sumAll() const {
    NC res(_dtype, {1});

#define ct(t)                                                                  \
  case t: {                                                                    \
    _##t s = (_##t)0;                                                          \
    for (size_t i = 0; i < size; i++)                                          \
      s += _at<_##t>(i);                                                       \
    res._at<_##t>(0) = s;                                                      \
  } break;

    switch (_dtype) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
          ct(f128) ct(fmp)
    }
#undef ct
    return res;
  }

  NC sum() const {
    if (ndims == 1)
      return sumAll();

    VDim tdim(dims.begin(), dims.end() - 1); // dims[0..-1]
    NC res(_dtype, tdim);
    for (auto &t : combinations(tdim))
      res.assign(slice(t).sumAll(), t);

    return res;
  }

  template <typename T> T _sumDiag() const {
    size_t n_it = 0;
    if (ndims == 1)
      n_it = 1;
    if (ndims == 2)
      n_it = dim0;

    T s = (T)0;
#define ct(t)                                                                  \
  case t:                                                                      \
    for (size_t i = 0; i < n_it; i++)                                          \
      s += _at<_##t>(i, i);                                                    \
    break;
    switch (_dtype) {
    ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
        ct(f128)
        //
        case fmp:
      break;
    }
#undef ct
    return s;
  }

  NC sumDiag() const {
    if (ndims == 1 || ndims == 2) {
      auto res = NC(_dtype, {1});
#define ct(t)                                                                  \
  case t:                                                                      \
    res._at<_##t>(0) = _sumDiag<_##t>();                                       \
    break;
      switch (_dtype) {
        ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
            ct(f128)
      }
#undef ct
      return res;
    }

    VDim tdim(dims.begin(), dims.end() - 2); // dims[0..-2]
    NC res(_dtype, tdim);
#define ct(t)                                                                  \
  case t:                                                                      \
    for (auto &t : combinations(tdim))                                         \
      res._at<_##t>(res.calcIndex(t)) = slice(t)._sumDiag<_##t>();             \
    break;
    switch (_dtype) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
          ct(f128)
    }
#undef ct

    return res;
  }

  NC min() const {
#define ct(t)                                                                  \
  case t: {                                                                    \
    _##t res = _at<_##t>(0);                                                   \
    for (size_t i = 0; i < size; i++)                                          \
      if (_at<_##t>(i) < res)                                                  \
        res = _at<_##t>(i);                                                    \
    NC c(t, {1});                                                              \
    c._at<_##t>(0) = res;                                                      \
    return c;                                                                  \
  }

    switch (_dtype) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
          ct(f128)
    }
#undef ct
  }
  NC max() const {
#define ct(t)                                                                  \
  case t: {                                                                    \
    _##t res = _at<_##t>(0);                                                   \
    for (size_t i = 0; i < size; i++)                                          \
      if (_at<_##t>(i) > res)                                                  \
        res = _at<_##t>(i);                                                    \
    NC c(t, {1});                                                              \
    c._at<_##t>(0) = res;                                                      \
    return c;                                                                  \
  } break;

    switch (_dtype) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
          ct(f128)
    }
#undef ct
  }
  NC min_max() const {
#define ct(t)                                                                  \
  case t: {                                                                    \
    _##t _min = _at<_##t>(0), _max = _min;                                     \
    for (size_t i = 0; i < size; i++) {                                        \
      if (_at<_##t>(i) > _max)                                                 \
        _max = _at<_##t>(i);                                                   \
      if (_at<_##t>(i) < _min)                                                 \
        _min = _at<_##t>(i);                                                   \
    }                                                                          \
    NC c(t, {2});                                                              \
    c._at<_##t>(0) = _min;                                                     \
    c._at<_##t>(1) = _max;                                                     \
    return c;                                                                  \
  } break;

    switch (_dtype) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
          ct(f128)
    }
#undef ct
  }
  NC norm() { // inplace norm. 0..1 range
    NC mm = min_max();

#define ct(t)                                                                  \
  case t: {                                                                    \
    _##t _min = mm._at<_##t>(0), _max = mm._at<_##t>(1),                       \
         _diff = (_max - _min);                                                \
    if (_diff == 0)                                                            \
      return *this;                                                            \
    if (_diff < 0)                                                             \
      _diff = -_diff; /* abs */                                                \
    for (size_t i = 0; i < size; i++)                                          \
      _at<_##t>(i) = (_at<_##t>(i) - _min) / _diff;                            \
  } break;

    switch (_dtype) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
          ct(f128)
    }
#undef ct

    return *this;
  }

  NC abs() { // abs
#define ct(t)                                                                  \
  case t:                                                                      \
    for (size_t i = 0; i < size; i++)                                          \
      if (_at<_##t>(i) < 0)                                                    \
        _at<_##t>(i) = -_at<_##t>(i);                                          \
    break;

    switch (_dtype) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
          ct(f128)
    }
#undef ct
    return *this;
  }

private:
  template <typename T> T round_to_zero_precheck(const T value) const {
    if (std::fabs(value) / (T)100.0 <= std::numeric_limits<T>::epsilon())
      return (T)0;
    return (T)std::round(value);
  }

public:
  NC round() const { // round
#define ct(t)                                                                  \
  case t: {                                                                    \
    NC res(*this);                                                             \
    for (size_t i = 0; i < size; i++)                                          \
      res._at<_##t>(i) = round_to_zero_precheck<_##t>(_at<_##t>(i));           \
    return res;                                                                \
  } break;

    switch (_dtype) { ct(f16) ct(f32) ct(f64) ct(f80) default : return *this; }
#undef ct
  }

  NC mean() const {
#define ct(t)                                                                  \
  case t: {                                                                    \
    _##t res = (_##t)0;                                                        \
    for (size_t i = 0; i < size; i++)                                          \
      res += _at<_##t>(i);                                                     \
    NC c(t, {1});                                                              \
    c._at<_##t>(0) = res / size;                                               \
    return c;                                                                  \
  } break;

    switch (_dtype) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
          ct(f128)
    }
#undef ct
  }

  NC eps(double _eps) const {
#define ct(t)                                                                  \
  case t: {                                                                    \
    NC res(*this);                                                             \
    for (size_t i = 0; i < size; i++)                                          \
      if (std::fabs(res._at<_##t>(i)) < _eps)                                  \
        res._at<_##t>(i) = 0;                                                  \
    return res;                                                                \
  } break;

    switch (_dtype) { ct(f16) ct(f32) ct(f64) ct(f80) default : return *this; }
#undef ct
  }

  double stdev() const {
#define sqr(x) ((x) * (x))
#define ct(t)                                                                  \
  case t: {                                                                    \
    _##t res = (_##t)0, mean, sumsqDiff = (_##t)0;                             \
    for (size_t i = 0; i < size; i++)                                          \
      res += _at<_##t>(i);                                                     \
    mean = res / size;                                                         \
    for (size_t i = 0; i < size; i++)                                          \
      sumsqDiff += sqr(_at<_##t>(i) - mean);                                   \
                                                                               \
    return std::sqrt((long double)sumsqDiff / size);                           \
  }

    switch (_dtype) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
          ct(f128)
    }
#undef ct
  }

  NC fill(double v) {
#define ct(t)                                                                  \
  case t:                                                                      \
    for (size_t i = 0; i < size; i++)                                          \
      _at<_##t>(i) = (_##t)v;                                                  \
    break;

    switch (_dtype) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
          ct(f128)
    }
#undef ct
    return *this;
  }

  // sort section
  NC flatSort() { return NC(*this).inFlatSort(); }

  NC sort() const {
    NC res(*this);
    if (ndims < 2)
      res = res.flatSort();
    else {
      VInt tdim(dims.begin(), dims.end() - 1); // dims[0..-1]
      for (auto &t : combinations(tdim))
        res.assign(slice(t).flatSort(), t);
    }

    return res;
  }

  NC inFlatSort() { // ascending
#define ct(t)                                                                  \
  case t:                                                                      \
    qsort((void *)_data.data(), size, _size(_dtype),                           \
          [](const void *a, const void *b) {                                   \
            return (*(_##t *)a < *(_##t *)b) ? -1 : 1;                         \
          });                                                                  \
    break;

    switch (_dtype) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
          ct(f128)
    }
#undef ct
    return *this;
  }
  NC inFlatSortDesc() { // descending
#define ct(t)                                                                  \
  case t:                                                                      \
    qsort((void *)_data.data(), size, _size(_dtype),                           \
          [](const void *a, const void *b) {                                   \
            return (*(_##t *)a < *(_##t *)b) ? 1 : -1;                         \
          });                                                                  \
    break;

    switch (_dtype) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
          ct(f128)
    }
#undef ct
    return *this;
  }

  NC inSort() { // in place sort
    if (ndims < 2)
      inFlatSort();
    else {
      VInt tdim(dims.begin() + 0, dims.end() - 1); // dims[0..-1]
      for (auto &t : combinations(tdim))
        assign(slice(t).flatSort(), t);
    }
    return *this;
  }
  // end sort section

  size_t transposedCoord(int index) {
    size_t res = 0;
    if (index != 0) {
      for (int i = 0; i < ndims; i++) {
        res += (index % dims[i]) * mlt[i];
        index /= dims[i];
      }
    }
    return res;
  }
  VDim revVInt(VInt a) const { // reserve array
    reverse(a.begin(), a.end());
    return a;
  }

  NC transpose() const { // MT version
    NC res(_dtype, revVInt(dims));

#pragma omp parallel for
    for (auto i = 0; i < size; i++) {

#define ct(t)                                                                  \
  case t:                                                                      \
    res._at<_##t>(res.transposedCoord(i)) = _at<_##t>(i);                      \
    break;

      switch (_dtype) {
        ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
            ct(f128)
      }
#undef ct
    }

    return res;
  }

  NC reshape(const VDim ndim) const {
    if (size != prod(ndim))
      throw invalid_argument("reshape: incompatible sizes");

    NC res(_dtype, ndim);

    // res._data = _data;
    res._data.assign(_data.begin(), _data.end());

    return res;
  }

  string print() const { return printRecursive(0, nc::VDim(get_ndims(), 0)); }

  size_t calcIndex(VDim index) const { // from index
    if (!eqDims(index))
      throw out_of_range("wrong index size:" + to_string(index.size()) + "," +
                         to_string(ndims));

    size_t res = 0;
    for (int i = 0; i < mlt.size(); i++)
      res += mlt[i] * index[i];
    return res;
  }

private:
  size_t prod(const VDim &v) const {
    size_t p = 1;
    for (auto i : v)
      p *= i;
    return p;
  }

  NC __prepDot(const NC &a, size_t &pivotPos, size_t &pivd, size_t &prs) const {
    pivotPos = std::min(1, a.ndims - 1); // position in a of pivot dim in  1|0
    pivd = a.dim(pivotPos);              // pivot dimension, a.dim(1|0) = dim(0)

    assert(dim0 == pivd && "dot: shapes not aligned");

    VInt sDim(dims.begin(), dims.end() - 1); // all but dim(0)
    auto aDim = a.dims;                      // remove 'pp' 0|1
    aDim.erase(aDim.begin() + a.ndims - 1 - pivotPos);

    VInt resDim = sDim; // resDim = sDim + aDim
    resDim.insert(resDim.end(), aDim.begin(), aDim.end());

    if (resDim.empty())
      resDim = {1};

    prs = prod(sDim);

    return NC(_dtype, resDim);
  }

  inline size_t dim(const int ix) const { // dims in reverse order
    if (ix >= ndims)
      throw out_of_range("dims index out of range");
    return dims[ndims - 1 - ix];
  }
  bool eqDims(const VDim &dims) const { return this->ndims == dims.size(); }
  bool identicalDims(const VDim &dims) const {
    if (this->ndims == dims.size()) {
      for (auto i = 0; i < ndims; i++)
        if (this->dims[i] != dims[i])
          return false;
      return true;
    } else
      return false;
  }

  /*size_t calcIndex(VDim &index) {  // from index
    if (!eqDims(index))
      throw out_of_range("wrong index size:" + to_string(index.size()) + "," +
                         to_string(ndims));

    size_t res = 0;
    for (int i = 0; i < mlt.size(); i++) res += mlt[i] * index[i];
    return res;
  }*/

  size_t checkIndex(size_t i) { // check & return _data index
    if (i >= size)
      throw out_of_range("index out of range:" + to_string(i) +
                         " out of range 0.." + to_string(size - 1));

    return i * szType;
  }
  void _resizeData() {
    sizeBytes = size * _size(_dtype);
    _data.resize(sizeBytes);
    pdata = _data.data();
    edata = pdata + sizeBytes;
    szType = sizeTypes[_dtype];
  }
  void _recalc() { // indexing support
    if (_dtype >= i8 && _dtype <= i128)
      charType = 'i';
    else
      charType = 'f';

    ndims = dims.size();
    dim0 = (ndims > 0) ? dim(0) : 0;

    size = accumulate(dims.begin(), dims.end(), 1, multiplies<size_t>());

    _resizeData();

    mlt.resize(ndims); // mlt factor to improve indexation
    for (size_t i = 0, nn = 1; i < ndims; i++) {
      mlt[ndims - 1 - i] = nn;
      nn *= dims[ndims - 1 - i];
    }

    // randimized required?
    static bool is_randomized=false;
    if (!is_randomized) {
      srand(time(NULL));
      is_randomized = true;
    }
  }

  int _size(DataType _dtype) const { return sizeTypes[_dtype]; }

  // create index vector from variable number of args of mixed type
  template <typename... Args>
  inline vector<size_t> createVector(Args... args) const {
    return {forward<size_t>(args)...};
  }

  VVInt combinations(VInt &limits) const {
    if (limits.empty())
      limits = dims;

    VVInt res;
    VInt cmb(limits.size(), 0);

    auto ncb =
        accumulate(limits.begin(), limits.end(), 1, multiplies<size_t>());
    res.resize(ncb);

    for (int i = 0;; i++) {
      res[i] = cmb;

      int idx = limits.size() - 1; // rightmost to inc.
      while (idx >= 0 && cmb[idx] == limits[idx] - 1)
        idx--;

      if (idx < 0)
        break;    // If no such element exists, we are done
      cmb[idx]++; // Increment this element

      // Reset all elements to the right of this element
      for (int i = idx + 1; i < limits.size(); i++)
        cmb[i] = 0;
    }

    return res;
  }

  VVInt combs(const VInt &nums) { // generate combinations recursively
    function<VVInt(int)> combHelper = [&nums, &combHelper](int index) -> VVInt {
      VVInt result;

      if (index == nums.size())
        result.push_back({}); // empty VVInt
      else {
        VVInt tComb = combHelper(index + 1);

        for (size_t i = 0; i < nums[index]; ++i) {
          for (const auto &c : tComb) {
            VInt newC = c;
            newC.insert(newC.begin(), i);
            result.push_back(newC);
          }
        }
      }
      return result;
    };

    return combHelper(0);
  }

  template <typename T> T diagProd() { // diag. prod. N x N matrix
    T res = (T)1;
    for (size_t i = 0; i < dim0; i++)
      res *= _at<T>(i, i);
    return res;
  }

  void assertQuadratic() const {
    assert((ndims >= 2 && dim0 == dim(1)) && "non quadratic matrix");
  }
  void assert_nxn() {
    assert((ndims == 2 && dim0 == dim(1)) && "non N x N matrix");
  }

  string printRecursive(int current_dim, nc::VDim indices) const {
    string s;
    if (current_dim == dims.size()) { // Base case: print the element
      int index = calcIndex(indices);
      s += _toString(index);
      return s;
    }

    s += "[";
    for (int i = 0; i < dims[current_dim]; ++i) {
      indices[current_dim] = i;
      s += printRecursive(current_dim + 1, indices);
      if (i < dims[current_dim] - 1)
        s += ", ";
    }
    s += "]";

    // if (current_dim == 0 && indices[0] < dims[0] -1) s+="\n";
    if (current_dim == 1)
      s += '\n';
    if (current_dim < dims.size() - 1 &&
        indices[current_dim] < dims[current_dim] - 1)
      s += ", ";

    return s;
  }
};
} // namespace nc
