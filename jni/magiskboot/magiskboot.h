#ifndef _MAGISKBOOT_H_
#define _MAGISKBOOT_H_

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <unistd.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/sendfile.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <string.h>

#include "bootimg.h"
#include "sha1.h"

#define CHROMEOS_MAGIC      "CHROMEOS"
#define CHROMEOS_MAGIC_SIZE 8

#define KERNEL_FILE         "kernel"
#define RAMDISK_FILE        "ramdisk.cpio"
#define SECOND_FILE         "second"
#define DTB_FILE            "dtb"
#define NEW_BOOT            "new-boot.img"

typedef enum {
    UNKNOWN,
    CHROMEOS,
    AOSP,
    ELF,
    GZIP,
    LZOP,
    XZ,
    LZMA,
    BZIP2,
    LZ4,
    LZ4_LEGACY,
    MTK,
    QCDT,
} file_t;

typedef enum {
    NONE,
    RM,
    MKDIR,
    ADD,
    EXTRACT,
    TEST,
    DMVERITY,
    FORCEENCRYPT,
    BACKUP,
    RESTORE
} command_t;

#define SUP_LIST "gzip, xz, lzma, bzip2, lz4, lz4_legacy"
#define SUP_NUM 6

// Cannot declare in header, but place a copy here for convenience
// char *SUP_EXT_LIST[SUP_NUM] = { "gz", "xz", "lzma", "bz2", "lz4", "lz4" };
// file_t SUP_TYPE_LIST[SUP_NUM] = { GZIP, XZ, LZMA, BZIP2, LZ4, LZ4_LEGACY };
extern char *SUP_EXT_LIST[SUP_NUM];
extern file_t SUP_TYPE_LIST[SUP_NUM];

// Vector
typedef struct vector {
    size_t size;
    size_t cap;
    void **data;
} vector;
void vec_init(vector *v);
void vec_push_back(vector *v, void *p);
void vec_sort(vector *v, int (*compar)(const void *, const void *));
void vec_destroy(vector *v);

#define vec_size(v) (v)->size
#define vec_cap(v) (v)->cap
#define vec_entry(v) (v)->data
// vec_for_each(vector *v, void *e)
#define vec_for_each(v, e) \
    e = (v)->data[0]; \
    for (size_t _i = 0; _i < (v)->size; ++_i, e = (v)->data[_i])

// Global variables
extern unsigned char *kernel, *ramdisk, *second, *dtb, *extra;
extern boot_img_hdr hdr;
extern file_t boot_type, ramdisk_type, dtb_type;
extern int mtk_kernel, mtk_ramdisk;

// Main entries
void unpack(const char *image);
void repack(const char* orig_image, const char* out_image);
void hexpatch(const char *image, const char *from, const char *to);
void error(int rc, const char *msg, ...);
void parse_img(unsigned char *orig, size_t size);
int cpio_commands(const char *command, int argc, char *argv[]);
void cleanup();

// Compressions
void gzip(int mode, const char* filename, const unsigned char* buf, size_t size);
void lzma(int mode, const char* filename, const unsigned char* buf, size_t size);
void lz4(int mode, const char* filename, const unsigned char* buf, size_t size);
void bzip2(int mode, const char* filename, const unsigned char* buf, size_t size);
void lz4_legacy(int mode, const char* filename, const unsigned char* buf, size_t size);
int comp(file_t type, const char *to, const unsigned char *from, size_t size);
void comp_file(const char *method, const char *from, const char *to);
int decomp(file_t type, const char *to, const unsigned char *from, size_t size);
void decomp_file(char *from, const char *to);

// Utils
void mmap_ro(const char *filename, unsigned char **buf, size_t *size);
void mmap_rw(const char *filename, unsigned char **buf, size_t *size);
file_t check_type(const unsigned char *buf);
void write_zero(int fd, size_t size);
void mem_align(size_t *pos, size_t align);
void file_align(int fd, size_t align, int out);
int open_new(const char *filename);
void print_info();

#endif
