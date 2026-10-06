#include "nc.h"
#include "mpreal.h"
#include "Timer.h"
#include <chrono>
#include <iostream>
#include <vector>


using namespace nc;
/*
void test00() {
  puts("---------- test00 ------------\n");

  NC a(2, 2, 3);  // default type is f64

  double d = 33.33;
  a.at<double>(0, 1, 0) = d;
  d = a.at<double>(0, 1, 0);
  printf("d:%f > %s\n", d, d == 33.33 ? "ok" : "fail");
  a.dump("-----------> a", true);

  size_t n = 10;
  NC c(f32, n, n);

  c.at<float>(1, 0) = 2.0f;
  float f;
  c.dump("-----------> c", true);

  printf("f:%f -> %s\n", c.at<float>(1, 0),
         c.at<float>(1, 0) == 2.0f ? "ok" : "fail");
}

void test01() {
  puts("---------- test01 ------------\n");

  NC a(3, 2, 2);
  a.rand();

  double d = 1;

  for (int i = 0; i < 3; i++) {
    d = (i + 1) * 100;
    a.at<double>(i, 0, 0) = d;
    a.at<double>(i, 0, 1) = d;
  }

  a.dump("a------->", true);

  puts("b--------->");
  NC b(3, 4);
  b.rand();  // fast unckecked index _at(r,c);
  for (size_t r = 0; r < 3; r++) {
    for (size_t c = 0; c < 4; c++) cout << b._at<double>(r, c) << ", ";
    cout << endl;
  }

  cout << endl;
  size_t n = 0;
  b.at<double>(n, n) = 999;
  cout << b.at<double>(0, 0) << endl;

  b.at<double>(n, n + 1) = 777;
  cout << b.at<double>(0, 1) << endl;

  b.dump("b---->", true);

  NC c(i16, 3, 3);
  c.rand();
  c.dump("c-------->", true);

  NC c0(i32, 3, 3);
  c0.rand();
  c0.dump("c0-------->", true);

  NC sm = c + c;
  sm.dump("sum:", true);
}

void test02() {
  puts("---------- test02 ------------\n");

  NC a(2, 3, 4);
  a.rand();
  double d = a.at<double>(1, 2, 3);
  a.at<double>(1, 2, 3) = d + 1;
  printf("d:%f, %d\n", d, a.at<double>(1, 2, 3) == d + 1);

  d = a.at<double>(0, 0, 0);
  a.at<double>(0, 0, 0) = d + 1;
  printf("d:%f, %d\n", d, a.at<double>(0, 0, 0) == d + 1);

  a.dump("", true);

  d = a.at<double>(0);
  printf("d:%f, %d\n", d, a.at<double>(0) == d);

  d = a.at<double>(0, 0);
  printf("d:%f, %d\n", d, a.at<double>(0, 0) == d);

  size_t n = 100000;
  auto l0 = Timer().chrono([&] {
    for (auto i = 0; i < n; i++) {
      double d = a.at<double>(1, 2, 3);
      a.at<double>(1, 2, 3) = d;
    }
  });
  auto l1 = Timer().chrono([&] {
    for (auto i = 0; i < n; i++) {
      double d = a.at<double>(1, 2, 3);
      a.at<double>(1, 2, 3) = d;
    }
  });
  printf("lap  index:%ldms\nlap _index:%ldms\n", l0, l1);
}

void test03() {
  puts("---------- test03 ------------\n");

  NC a(2, 3, 4), b(a), s;

  b.rand();
  a.rand();

  s = a + b;
  s -= b;

  printf("eq:%d\n", a == s);

  s += 1.0;
  s -= 1.0;
  printf("eq:%d\n", a == s);

  s += 1.0;
  s -= 4.0;
  printf("ne:%d\n", a != s);

  a = s;
  s *= 2.0;
  s /= 2.0;
  printf("eq:%d\n", a == s);
}

void test04() {
  puts("---------- test04 ------------\n");

  string fName = "test.npy";

  NC ma(f32, 2, 3, 4);
  ma.rand();
  ma.save(fName);
  // a.dump("a:", true);

  NC b = NC::load(fName);
  // b.dump("b:", true);

  printf("test %s\n\n", ma == b ? "ok" : "fail");
}

void test05() {
  puts("---------- test05 ------------\n");

  NC a(f32, 2, 3, 4);
  a.rand();
  a.dump("a:", true);

  NC sl = a.slice({1, 0});
  sl.dump("slice{1,0}:", true);

  sl = a.slice({1, 2});
  sl.dump("slice:{1,2}", true);
}

void test06() {
  puts("---------- test06 ------------\n");

  NC a(f64, 20, 30, 4, 4);
  a.rand();

  // a.dump("a:", true);
  auto d = a.detST();
  // d.dump("d:", true);
  a.save("a.npy");
  d.save("d.npy");

  auto b = a.convert(f32);
  b.save("b32.npy");

  b = a.convert(f64);
  b.save("b64.npy");
}

void test070() {
  puts("---------- test070 ------------\n");

  NC a(f64, 4, 4);
  a.rand();

  NC i = a.inv_nxn<_f64>();

  a.save("a.npy");
  i.save("i.npy");
}

void test07() {
  puts("---------- test07 ------------\n");

  NC a(f64, 20, 30, 90, 90);
  // srand(time(nullptr));
  a.rand();

  NC i = a.inv();
  a.save("a.npy");
  i.save("i.npy");
  puts(
      "a=np.load('a.npy'); i=np.load('i.npy'); ai=np.linalg.inv(a); "
      "np.max(abs(i-ai))");
}
void test08() {
  puts("---------- test08 ------------\n");

  NC a(f64, 12, 13, 90, 90);
  // srand(time(nullptr));
  a.rand();

  NC i = a.inv();
  a.save("a.npy");
  NC d = a.dot(i);
  d.save("d.npy");

  puts(
      "a=np.load('a.npy'); d=np.load('d.npy'); dn=np.dot(a,np.linalg.inv(a)); "
      "print('dot error:',np.max(abs(d-dn)))");
}

void test09() {
  puts("---------- test09 ------------\n");

  NC a(f64, 90, 90);
  a.rand();
  a.save("a.npy");

  printf("detnxn_MT:%g\ndetnxn_ST:%g\ndetBareis:%g\n", a.detnxn_MT<double>(),
         a.detnxn_ST<double>(), a.detBareiss<double>());

  NC d = a.det();
  d.dump("det:", true);

  puts("a=np.load('a.npy'); print('det a:', np.linalg.det(a))");
}
*/
void test10() {
  puts("---------- test10 ------------\n");

  NC a(nc::NC::f64, {8, 8});
  a.rand();

  NC i = a.dot(a.inv()).round();
  i.dump("i:", true);
}

void test11() {
  NC a(nc::NC::f64, {40, 140, 140});
  a.rand();
  auto t0 = Timer();
  auto d = a.detST();
  printf("lap:%ld ms\n", t0.lap());
}
void test12() {
  NC a(nc::NC::fmp, {40, 140, 140});
  a.rand();
  auto t0 = Timer();
  auto d = a.det();
  printf("lap:%ld ms\n", t0.lap());
}
void test_mpreal() {
  mpfr_set_default_prec(2048);

  int n = 400;
  vector<nc::byte> vals(n * sizeof(mpreal));
  // return *(T *)(&_data[index * szType]);
  for (int i = 0; i < n; i++)
    *(mpreal *)(&vals[i * sizeof(mpreal)]) = mpreal((i + 1) * 10000.0);
  for (int i = 0; i < n; i++)
    cout << *(mpreal *)(&vals[i * sizeof(mpreal)]) << ", ";
  cout << endl;

  mpreal p = 10;
  for (int i = 0; i < n; i++) {
    mpreal v = *(mpreal *)(&vals[i * sizeof(mpreal)]);
    cout << "(" << p << ", " << v << "), ";
    p = p * v;
    
  }
  cout << endl;
}

int test_det() {
  size_t n=392;
  NC a(nc::NC::f80, {n, n});
  a.rand();
  auto t0 = std::chrono::high_resolution_clock::now();
  auto d = a.det();
  auto t1 = std::chrono::high_resolution_clock::now();
  auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(t1 - t0);
  printf("det %ldx%ld lap:%ld ms\n", n, n, duration.count());
  return 0;
}

int main(int argc, const char *argv[]) {
  // test_mpreal();
  test_det();

  return 0;
}
