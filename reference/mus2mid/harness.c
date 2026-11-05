/* The reference MUS->MIDI converter for scripts/mus2mid-ref.sh: Chocolate
 * Doom's mus2mid.c and memio.c as they are, with the zone allocator stubbed.
 * GPLv2 or later, as they are; this port is GPLv3, see COPYING.
 *
 * Usage: mus2mid-ref IN.mus OUT.mid
 */

#include <stdio.h>
#include <stdlib.h>

#include "z_zone.h"
#include "memio.h"
#include "mus2mid.h"

void *Z_Malloc(int size, int tag, void *ptr) { (void) tag; (void) ptr; return malloc(size); }
void Z_Free(void *ptr) { free(ptr); }

int main(int argc, char *argv[])
{
    FILE *f;
    long len;
    unsigned char *buf;
    MEMFILE *src, *dst;
    void *out;
    size_t out_len;

    if (argc != 3)
    {
        fprintf(stderr, "usage: %s IN.mus OUT.mid\n", argv[0]);
        return 2;
    }
    f = fopen(argv[1], "rb");
    if (f == NULL) { perror(argv[1]); return 1; }
    fseek(f, 0, SEEK_END);
    len = ftell(f);
    fseek(f, 0, SEEK_SET);
    buf = malloc(len);
    if (fread(buf, 1, len, f) != (size_t) len) { perror(argv[1]); return 1; }
    fclose(f);

    src = mem_fopen_read(buf, len);
    dst = mem_fopen_write();
    if (mus2mid(src, dst))
    {
        fprintf(stderr, "mus2mid failed: %s\n", argv[1]);
        return 1;
    }
    mem_get_buf(dst, &out, &out_len);
    f = fopen(argv[2], "wb");
    if (f == NULL || fwrite(out, 1, out_len, f) != out_len) { perror(argv[2]); return 1; }
    fclose(f);
    return 0;
}
