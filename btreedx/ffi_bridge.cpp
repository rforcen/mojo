
#include "ffi_bridge.h"
#include "btreedx.h"

// Macro auxiliar para evitar repetir el casteo repetidamente
#define AS_CLASS(tree) static_cast<BtreeDX *>(tree)

extern "C" {

BtreeDX_t btreedx_create(void) { return static_cast<BtreeDX_t>(new BtreeDX()); }

void btreedx_destroy(BtreeDX_t tree) {
  // printf("deleting class %p\n", tree);
  delete AS_CLASS(tree);
}

int btreedx_open(BtreeDX_t tree, char *filename) {
  // printf("btreedx_open: %s\n", filename);
  return AS_CLASS(tree)->open(filename) ? 1 : 0;
}

int btreedx_close(BtreeDX_t tree) {
  // printf("closing %p\n", tree);
  return AS_CLASS(tree)->close() ? 1 : 0;
}

int btreedx_create_index(BtreeDX_t tree, char *filename, int keylen,
                         short unique, short overlay) {
  return AS_CLASS(tree)->create(filename, keylen, unique, overlay) ? 1 : 0;
}

int btreedx_add(BtreeDX_t tree, const char *key, int recNo) {
  return AS_CLASS(tree)->add(key, recNo) ? 1 : 0;
}

int btreedx_find_eq(BtreeDX_t tree, const char *key, int *recNo) {
  return AS_CLASS(tree)->findEQ(key, *recNo) ? 1 : 0;
}

int btreedx_find(BtreeDX_t tree, const char *key, int *recNo) {
  return AS_CLASS(tree)->find(key, *recNo) ? 1 : 0;
}

int btreedx_next(BtreeDX_t tree, char *key, int *recNo) {
  return AS_CLASS(tree)->next(key, *recNo) ? 1 : 0;
}

int btreedx_erase_eq(BtreeDX_t tree, const char *key) {
  return AS_CLASS(tree)->eraseEQ(key) ? 1 : 0;
}

int btreedx_erase_match(BtreeDX_t tree, const char *key) {
  return AS_CLASS(tree)->eraseMatch(key);
}

short btreedx_find_advanced(BtreeDX_t tree, const char *tkey, char *keyFound,
                            int *recNo) {
  return AS_CLASS(tree)->find(tkey, keyFound, *recNo);
}

const char *btreedx_get_filename(BtreeDX_t tree) {
  return AS_CLASS(tree)->getFileName();
}

char *btreedx_get_key(BtreeDX_t tree) { return AS_CLASS(tree)->getKey(); }

int btreedx_get_rec_no(BtreeDX_t tree) { return AS_CLASS(tree)->getRecNo(); }

int btreedx_get_nnodes(BtreeDX_t tree) { return AS_CLASS(tree)->getNnodes(); }

int btreedx_match(BtreeDX_t tree, const char *key) {
  return AS_CLASS(tree)->match(key) ? 1 : 0;
}

void *btreedx_calloc(size_t sz) { return calloc(1, sz); }
void btreedx_free(void *ptr) { free(ptr); }
}