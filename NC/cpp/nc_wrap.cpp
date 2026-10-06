// c wrapper for nc.h
#include "nc.h"

#include <iostream>
#include <vector>

// mojo Int for 64 bit machines

using namespace nc;
typedef NC *NCPtr;

extern "C" {

void *nc_new(_i64 dtype, _i64 size, _i64 *shape) {
  std::vector<size_t> shape_vec(
      shape, shape + size); // create a vector from length, pointer
  return (void *)new NC((NC::DataType)dtype, shape_vec);
}
void nc_free(NCPtr nc_ptr) { delete nc_ptr; }

void nc_rand(NCPtr nc_ptr) { nc_ptr->rand(); }

void *nc_random(_i64 dtype, _i64 size, _i64 *shape) {
  std::vector<size_t> shape_vec(shape, shape + size);
  return (void *)new NC(NC::Rand((NC::DataType)dtype, shape_vec));
}
void *nc_identity(_i64 dtype, _i64 size) {
  return (void *)new NC(NC::identity((NC::DataType)dtype, (size_t)size));
}
void *nc_arange(_i64 dtype, _i64 size, _i64 *shape) {
  std::vector<size_t> shape_vec(shape, shape + size);
  return (void *)new NC(NC::arange((NC::DataType)dtype, shape_vec));
}
void *nc_fromString(_i64 dtype, char *sarr) {
  return (void *)new NC(NC::fromString((NC::DataType)dtype, sarr));
}
void nc_print(NCPtr nc_ptr) { cout << nc_ptr->print() << endl; }

const char *nc_to_string(NCPtr nc_ptr) {
  static thread_local std::string s;
  s = nc_ptr->toString();
  return s.c_str();
}

// aritmetics
NCPtr nc_add(NCPtr a, NCPtr b) { return new NC(*a + *b); }
void nc_iadd(NCPtr a, NCPtr b) { *a += *b; }
NCPtr nc_sub(NCPtr a, NCPtr b) { return new NC(*a - *b); }
void nc_isub(NCPtr a, NCPtr b) { *a -= *b; }
NCPtr nc_mul(NCPtr a, NCPtr b) { return new NC(*a * *b); }
void nc_imul(NCPtr a, NCPtr b) { *a *= *b; }
NCPtr nc_div(NCPtr a, NCPtr b) { return new NC(*a / *b); }
void nc_idiv(NCPtr a, NCPtr b) { *a /= *b; }

// logic
bool nc_eq(NCPtr a, NCPtr b) { return *a == *b; }
bool nc_ne(NCPtr a, NCPtr b) { return *a != *b; }

void nc_save(NCPtr nc_ptr, char *name) { nc_ptr->save(name); }
void *nc_load(char *name, _i64 *dtype, _i64 *ndims) {
  auto n = new NC(NC::load(name));
  *dtype = (_i64)n->getType();
  *ndims = n->get_ndims();

  return (void *)n;
}
void nc_getDims(NCPtr nc_ptr, _i64 *shape) {

  auto dims = nc_ptr->getDims();
  for (int i = 0; i < nc_ptr->get_ndims(); i++) {
    shape[i] = dims[i];
  }
}
void *nc_get_data(NCPtr nc_ptr) { return nc_ptr->getData(); }
void *nc_new_from_span(double *data, _i64 size) {
  return (void *)new NC(
      NC::FromBuffer((NC::DataType)NC::DataType::f64, {(size_t)size}, data));
}
void *nc_reshape(NCPtr nc_ptr, _i64 size, _i64 *shape) {
  std::vector<size_t> shape_vec(shape, shape + size);
  return (void *)new NC(nc_ptr->reshape(shape_vec));
}
NCPtr nc_convert(NCPtr nc_ptr, _i64 new_type) {
  return new NC(nc_ptr->convert((NC::DataType)new_type));
}
NCPtr nc_transpose(NCPtr nc_ptr) { return new NC(nc_ptr->transpose()); }
NCPtr nc_sort(NCPtr nc_ptr) { return new NC(nc_ptr->sort()); }
NCPtr nc_norm(NCPtr nc_ptr) { return new NC(nc_ptr->norm()); }
NCPtr nc_round(NCPtr nc_ptr) { return new NC(nc_ptr->round()); }
NCPtr nc_mean(NCPtr nc_ptr) { return new NC(nc_ptr->mean()); }
NCPtr nc_max(NCPtr nc_ptr) { return new NC(nc_ptr->max()); }
NCPtr nc_min(NCPtr nc_ptr) { return new NC(nc_ptr->min()); }
double nc_stddev(NCPtr nc_ptr) { return nc_ptr->stdev(); }
NCPtr nc_fill(NCPtr nc_ptr, double value) {
  return new NC(nc_ptr->fill(value));
}

NCPtr nc_eps(NCPtr nc_ptr, double eps) { return new NC(nc_ptr->eps(eps)); }

_i64 nc_get_size(NCPtr nc_ptr) { return nc_ptr->getSize(); }
_i64 nc_get_ndims(NCPtr nc_ptr) { return nc_ptr->get_ndims(); }
NCPtr nc_sum(NCPtr nc_ptr) { return new NC(nc_ptr->sum()); }
NCPtr nc_sum_all(NCPtr nc_ptr) { return new NC(nc_ptr->sumAll()); }

// linalg
NCPtr nc_det(NCPtr nc_ptr) { return new NC(nc_ptr->det()); }
NCPtr nc_inv(NCPtr nc_ptr) { return new NC(nc_ptr->inv()); }

NCPtr nc_dot(NCPtr nc_ptr1, NCPtr nc_ptr2) {
  return new NC(nc_ptr1->dot(*nc_ptr2));
}
NCPtr nc_apply(NCPtr nc_ptr, char *expression) {
  compiler::Compiler<double> bc;

  if (bc.compile(expression)) {
#define ct(t)                                                                  \
  case t:                                                                      \
    for (size_t i = 0; i < nc_ptr->getSize(); i++)                             \
      nc_ptr->_at<nc::_##t>(i) = bc.evaluate(nc_ptr->_at<nc::_##t>(i));        \
    break;

    switch (nc_ptr->getType()) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
          ct(f128)
    }
#undef ct
  } else {
    puts("apply: invalid syntax in expression");
  }
  return new NC(*nc_ptr);
}

_i64 nc_count(NCPtr nc_ptr, char *expr) {
  compiler::Compiler<double> bc;
  _i64 cnt = 0;

  if (bc.compile(expr)) {

#define ct(t)                                                                  \
  case t:                                                                      \
    for (size_t i = 0; i < nc_ptr->getSize(); i++)                             \
      if (bc.evaluate(nc_ptr->_at<nc::_##t>(i)))                               \
        cnt++;                                                                 \
    break;

    switch (nc_ptr->getType()) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
          ct(f128)
    }
#undef ct

  } else {
    puts("count: invalid syntax in expression");
  }

  return cnt;
}

NCPtr nc_filter(NCPtr nc_ptr, char *expr) {
  compiler::Compiler<double> bc;
  vector<size_t> indices;

  if (bc.compile(expr)) {

#define ct(t)                                                                  \
  case t:                                                                      \
    for (size_t i = 0; i < nc_ptr->getSize(); i++)                             \
      if (bc.evaluate(nc_ptr->_at<nc::_##t>(i)))                               \
        indices.push_back(i);                                                  \
    break;

    switch (nc_ptr->getType()) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
          ct(f128)
    }
#undef ct

  } else {
    puts("filter: invalid syntax in expression");
  }

  if (indices.size() != 0) {
    NCPtr res = new NC(nc_ptr->getType(), {indices.size()});
    size_t ix = 0;

#define ct(t)                                                                  \
  case t:                                                                      \
    for (auto i : indices)                                                     \
      res->_at<nc::_##t>(ix++) = nc_ptr->_at<nc::_##t>(i);                     \
    break;

    switch (nc_ptr->getType()) {
      ct(i8) ct(i16) ct(i32) ct(i64) ct(i128) ct(f16) ct(f32) ct(f64) ct(f80)
          ct(f128)
    }
#undef ct

    return res;
  } else
    return new NC(nc_ptr->getType(), {0});
}

//
}
