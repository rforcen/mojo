#pragma once
#ifdef __cplusplus
extern "C" {
#endif

typedef void* BtreeDX_t;

// Ciclo de vida
BtreeDX_t btreedx_create(void);
void btreedx_destroy(BtreeDX_t tree);

// Métodos de gestión del índice
int btreedx_open(BtreeDX_t tree,  char* filename);
int btreedx_close(BtreeDX_t tree);
int btreedx_create_index(BtreeDX_t tree,  char* filename, int keylen, short unique, short overlay);

// Mutación y búsqueda básica
int btreedx_add(BtreeDX_t tree, const char* key, int recNo);
int btreedx_find_eq(BtreeDX_t tree, const char* key, int* recNo);
int btreedx_find(BtreeDX_t tree, const char* key, int* recNo);
int btreedx_next(BtreeDX_t tree, char* key, int* recNo);

// Borrado
int btreedx_erase_eq(BtreeDX_t tree, const char* key);
int btreedx_erase_match(BtreeDX_t tree, const char* key);

// Búsquedas avanzadas y getters
short btreedx_find_advanced(BtreeDX_t tree, const char* tkey, char* keyFound, int* recNo);
const char* btreedx_get_filename(BtreeDX_t tree);
char* btreedx_get_key(BtreeDX_t tree);
int btreedx_get_rec_no(BtreeDX_t tree);
int btreedx_get_nnodes(BtreeDX_t tree);
int btreedx_match(BtreeDX_t tree, const char* key);

#ifdef __cplusplus
}
#endif

