#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define UNICODE_LIMIT 0x110000UL

static unsigned short be16(const unsigned char *p) {
    return (unsigned short)(((unsigned short)p[0] << 8) | p[1]);
}

static unsigned long be32(const unsigned char *p) {
    return ((unsigned long)p[0] << 24) | ((unsigned long)p[1] << 16) |
           ((unsigned long)p[2] << 8) | p[3];
}

static unsigned char *read_file(const char *path, size_t *size_out) {
    FILE *f;
    long size;
    unsigned char *data;
    f = fopen(path, "rb");
    if (!f) return NULL;
    if (fseek(f, 0, SEEK_END) != 0 || (size = ftell(f)) < 0 ||
        fseek(f, 0, SEEK_SET) != 0) {
        fclose(f);
        return NULL;
    }
    data = (unsigned char *)malloc((size_t)size);
    if (!data || fread(data, 1, (size_t)size, f) != (size_t)size) {
        free(data);
        fclose(f);
        return NULL;
    }
    fclose(f);
    *size_out = (size_t)size;
    return data;
}

static int in_bounds(size_t size, unsigned long off, unsigned long length) {
    return off <= size && length <= size - off;
}

static unsigned long first_face(const unsigned char *data, size_t size) {
    if (in_bounds(size, 0, 16) && be32(data) == 0x74746366UL) {
        return be32(data + 12);
    }
    return 0;
}

static int find_table(const unsigned char *data, size_t size, unsigned long face,
                      const char tag[4], unsigned long *off, unsigned long *len) {
    unsigned short count;
    unsigned long i;
    if (!in_bounds(size, face, 12)) return 0;
    count = be16(data + face + 4);
    if (!in_bounds(size, face + 12, (unsigned long)count * 16)) return 0;
    for (i = 0; i < count; i++) {
        const unsigned char *record = data + face + 12 + i * 16;
        if (memcmp(record, tag, 4) == 0) {
            *off = be32(record + 8);
            *len = be32(record + 12);
            return in_bounds(size, *off, *len);
        }
    }
    return 0;
}

static void parse_format12(const unsigned char *sub, size_t available,
                           unsigned char *coverage) {
    unsigned long groups, i;
    if (available < 16 || be16(sub) != 12) return;
    groups = be32(sub + 12);
    if (groups > (available - 16) / 12) return;
    for (i = 0; i < groups; i++) {
        const unsigned char *g = sub + 16 + i * 12;
        unsigned long start = be32(g);
        unsigned long end = be32(g + 4);
        unsigned long cp;
        if (start >= UNICODE_LIMIT) continue;
        if (end >= UNICODE_LIMIT) end = UNICODE_LIMIT - 1;
        for (cp = start; cp <= end; cp++) coverage[cp] = 1;
    }
}

static void parse_format4(const unsigned char *sub, size_t available,
                          unsigned char *coverage) {
    unsigned short length, seg_count, i;
    unsigned long end_off, start_off, delta_off, range_off;
    if (available < 16 || be16(sub) != 4) return;
    length = be16(sub + 2);
    if (length > available) return;
    seg_count = be16(sub + 6) / 2;
    end_off = 14;
    start_off = end_off + (unsigned long)seg_count * 2 + 2;
    delta_off = start_off + (unsigned long)seg_count * 2;
    range_off = delta_off + (unsigned long)seg_count * 2;
    if (range_off + (unsigned long)seg_count * 2 > length) return;
    for (i = 0; i < seg_count; i++) {
        unsigned short start = be16(sub + start_off + i * 2);
        unsigned short end = be16(sub + end_off + i * 2);
        unsigned short delta = be16(sub + delta_off + i * 2);
        unsigned short range = be16(sub + range_off + i * 2);
        unsigned long cp;
        if (start > end) continue;
        for (cp = start; cp <= end && cp != 0xffffUL; cp++) {
            unsigned short glyph;
            if (range == 0) {
                glyph = (unsigned short)((cp + delta) & 0xffffUL);
            } else {
                unsigned long word = range_off + i * 2;
                unsigned long glyph_off = word + range + (cp - start) * 2;
                if (glyph_off + 2 > length) continue;
                glyph = be16(sub + glyph_off);
                if (glyph) glyph = (unsigned short)((glyph + delta) & 0xffffUL);
            }
            if (glyph) coverage[cp] = 1;
        }
    }
}

static int load_coverage(const char *path, unsigned char *coverage) {
    unsigned char *data;
    size_t size;
    unsigned long face, cmap_off, cmap_len, i;
    unsigned short records;
    data = read_file(path, &size);
    if (!data) return 0;
    face = first_face(data, size);
    if (!find_table(data, size, face, "cmap", &cmap_off, &cmap_len) ||
        cmap_len < 4) {
        free(data);
        return 0;
    }
    records = be16(data + cmap_off + 2);
    if ((unsigned long)records * 8 + 4 > cmap_len) {
        free(data);
        return 0;
    }
    for (i = 0; i < records; i++) {
        const unsigned char *record = data + cmap_off + 4 + i * 8;
        unsigned short platform = be16(record);
        unsigned short encoding = be16(record + 2);
        unsigned long rel = be32(record + 4);
        const unsigned char *sub;
        size_t available;
        unsigned short format;
        if (!(platform == 0 || (platform == 3 && (encoding == 1 || encoding == 10))))
            continue;
        if (rel >= cmap_len) continue;
        sub = data + cmap_off + rel;
        available = (size_t)(cmap_len - rel);
        if (available < 2) continue;
        format = be16(sub);
        if (format == 12) parse_format12(sub, available, coverage);
        else if (format == 4) parse_format4(sub, available, coverage);
    }
    free(data);
    return 1;
}

static unsigned long count_coverage(const unsigned char *coverage) {
    unsigned long cp, count = 0;
    for (cp = 0; cp < UNICODE_LIMIT; cp++) if (coverage[cp]) count++;
    return count;
}

int main(int argc, char **argv) {
    unsigned char *donor, *legacy;
    unsigned long cp, additions = 0;
    if (argc != 3) {
        fprintf(stderr, "usage: cmap-diff DONOR_FONT LEGACY_FONT\n");
        return 64;
    }
    donor = (unsigned char *)calloc(UNICODE_LIMIT, 1);
    legacy = (unsigned char *)calloc(UNICODE_LIMIT, 1);
    if (!donor || !legacy) return 71;
    if (!load_coverage(argv[1], donor)) {
        fprintf(stderr, "cannot read donor cmap: %s\n", argv[1]);
        return 65;
    }
    if (!load_coverage(argv[2], legacy)) {
        fprintf(stderr, "cannot read legacy cmap: %s\n", argv[2]);
        return 65;
    }
    for (cp = 0; cp < UNICODE_LIMIT; cp++) {
        if (donor[cp] && !legacy[cp]) {
            printf("U+%04lX\n", cp);
            additions++;
        }
    }
    fprintf(stderr, "donor=%lu legacy=%lu additions=%lu\n",
            count_coverage(donor), count_coverage(legacy), additions);
    free(donor);
    free(legacy);
    return 0;
}
