#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef unsigned char U8;
typedef unsigned short U16;
typedef unsigned long U32;

typedef struct {
    char tag[4];
    U8 *data;
    U32 length;
    U32 checksum;
    U32 offset;
} Table;

typedef struct {
    U32 codepoint;
    U16 glyph;
} Mapping;

static U16 get16(const U8 *p) {
    return (U16)(((U16)p[0] << 8) | p[1]);
}

static U32 get32(const U8 *p) {
    return ((U32)p[0] << 24) | ((U32)p[1] << 16) |
           ((U32)p[2] << 8) | p[3];
}

static void put16(U8 *p, U16 v) {
    p[0] = (U8)(v >> 8);
    p[1] = (U8)v;
}

static void put32(U8 *p, U32 v) {
    p[0] = (U8)(v >> 24);
    p[1] = (U8)(v >> 16);
    p[2] = (U8)(v >> 8);
    p[3] = (U8)v;
}

static int inside(size_t size, U32 offset, U32 length) {
    return offset <= size && length <= size - offset;
}

static U8 *read_file(const char *path, size_t *size_out) {
    FILE *f = fopen(path, "rb");
    U8 *data;
    long length;
    if (!f) return NULL;
    if (fseek(f, 0, SEEK_END) || (length = ftell(f)) < 0 ||
        fseek(f, 0, SEEK_SET)) {
        fclose(f);
        return NULL;
    }
    data = (U8 *)malloc((size_t)length);
    if (!data || fread(data, 1, (size_t)length, f) != (size_t)length) {
        free(data);
        fclose(f);
        return NULL;
    }
    fclose(f);
    *size_out = (size_t)length;
    return data;
}

static U32 first_face(const U8 *font, size_t size) {
    if (inside(size, 0, 16) && get32(font) == 0x74746366UL)
        return get32(font + 12);
    return 0;
}

static int find_table(const U8 *font, size_t size, U32 face,
                      const char tag[4], U32 *offset, U32 *length) {
    U16 count;
    U32 i;
    if (!inside(size, face, 12)) return 0;
    count = get16(font + face + 4);
    if (!inside(size, face + 12, (U32)count * 16)) return 0;
    for (i = 0; i < count; i++) {
        const U8 *record = font + face + 12 + i * 16;
        if (!memcmp(record, tag, 4)) {
            *offset = get32(record + 8);
            *length = get32(record + 12);
            return inside(size, *offset, *length);
        }
    }
    return 0;
}

static U16 glyph12(const U8 *sub, size_t available, U32 cp) {
    U32 groups, low = 0, high;
    if (available < 16 || get16(sub) != 12) return 0;
    groups = get32(sub + 12);
    if (groups > (available - 16) / 12) return 0;
    high = groups;
    while (low < high) {
        U32 mid = low + (high - low) / 2;
        const U8 *group = sub + 16 + mid * 12;
        U32 start = get32(group);
        U32 end = get32(group + 4);
        if (cp < start) high = mid;
        else if (cp > end) low = mid + 1;
        else return (U16)(get32(group + 8) + cp - start);
    }
    return 0;
}

static U16 glyph4(const U8 *sub, size_t available, U32 cp) {
    U16 length, segments, i;
    U32 ends, starts, deltas, ranges;
    if (cp > 0xffffUL || available < 16 || get16(sub) != 4) return 0;
    length = get16(sub + 2);
    if (length > available) return 0;
    segments = get16(sub + 6) / 2;
    ends = 14;
    starts = ends + (U32)segments * 2 + 2;
    deltas = starts + (U32)segments * 2;
    ranges = deltas + (U32)segments * 2;
    if (ranges + (U32)segments * 2 > length) return 0;
    for (i = 0; i < segments; i++) {
        U16 start = get16(sub + starts + i * 2);
        U16 end = get16(sub + ends + i * 2);
        U16 delta, range, glyph;
        U32 glyph_offset;
        if (cp < start || cp > end) continue;
        delta = get16(sub + deltas + i * 2);
        range = get16(sub + ranges + i * 2);
        if (!range) return (U16)((cp + delta) & 0xffffUL);
        glyph_offset = ranges + i * 2 + range + (cp - start) * 2;
        if (glyph_offset + 2 > length) return 0;
        glyph = get16(sub + glyph_offset);
        return glyph ? (U16)((glyph + delta) & 0xffffUL) : 0;
    }
    return 0;
}

static U16 donor_glyph(const U8 *font, size_t size, U32 face, U32 cp) {
    U32 cmap_offset, cmap_length, i;
    U16 records, fallback = 0;
    if (!find_table(font, size, face, "cmap", &cmap_offset, &cmap_length) ||
        cmap_length < 4) return 0;
    records = get16(font + cmap_offset + 2);
    if ((U32)records * 8 + 4 > cmap_length) return 0;
    for (i = 0; i < records; i++) {
        const U8 *record = font + cmap_offset + 4 + i * 8;
        U16 platform = get16(record);
        U16 encoding = get16(record + 2);
        U32 relative = get32(record + 4);
        const U8 *sub;
        size_t available;
        U16 format, glyph = 0;
        if (!(platform == 0 ||
              (platform == 3 && (encoding == 1 || encoding == 10)))) continue;
        if (relative >= cmap_length) continue;
        sub = font + cmap_offset + relative;
        available = (size_t)(cmap_length - relative);
        if (available < 2) continue;
        format = get16(sub);
        if (format == 12) glyph = glyph12(sub, available, cp);
        else if (format == 4) glyph = glyph4(sub, available, cp);
        if (glyph && format == 12) return glyph;
        if (glyph) fallback = glyph;
    }
    return fallback;
}

static int safe_codepoint(U32 cp) {
    if (cp < 0x2000UL) return 0;
    if (cp == 0x200dUL || cp == 0x20e3UL) return 0;
    if (cp == 0xfe0eUL || cp == 0xfe0fUL) return 0;
    if (cp >= 0x1f1e6UL && cp <= 0x1f1ffUL) return 0;
    if (cp >= 0x1f3fbUL && cp <= 0x1f3ffUL) return 0;
    if (cp >= 0xe0000UL && cp <= 0xe007fUL) return 0;
    return cp < 0x110000UL;
}

static int compare_mapping(const void *a, const void *b) {
    const Mapping *left = (const Mapping *)a;
    const Mapping *right = (const Mapping *)b;
    if (left->codepoint < right->codepoint) return -1;
    if (left->codepoint > right->codepoint) return 1;
    return 0;
}

static Mapping *load_mappings(const char *path, const U8 *font, size_t size,
                              U32 face, U32 *count_out) {
    FILE *f = fopen(path, "r");
    Mapping *items = NULL;
    U32 count = 0, capacity = 0;
    char line[128];
    if (!f) return NULL;
    while (fgets(line, sizeof(line), f)) {
        unsigned long parsed;
        U16 glyph;
        Mapping *grown;
        if (sscanf(line, "U+%lx", &parsed) != 1 ||
            !safe_codepoint((U32)parsed)) continue;
        glyph = donor_glyph(font, size, face, (U32)parsed);
        if (!glyph) continue;
        if (count == capacity) {
            capacity = capacity ? capacity * 2 : 256;
            grown = (Mapping *)realloc(items, capacity * sizeof(Mapping));
            if (!grown) {
                free(items);
                fclose(f);
                return NULL;
            }
            items = grown;
        }
        items[count].codepoint = (U32)parsed;
        items[count].glyph = glyph;
        count++;
    }
    fclose(f);
    qsort(items, count, sizeof(Mapping), compare_mapping);
    *count_out = count;
    return items;
}

static U8 *build_cmap(const Mapping *items, U32 count, U32 *length_out) {
    U32 groups = 1, i, group_index = 0, sub_length, length;
    U8 *table;
    for (i = 1; i < count; i++) {
        if (items[i].codepoint != items[i - 1].codepoint + 1 ||
            items[i].glyph != (U16)(items[i - 1].glyph + 1)) groups++;
    }
    sub_length = 16 + groups * 12;
    length = 20 + sub_length;
    table = (U8 *)calloc(length, 1);
    if (!table) return NULL;
    put16(table + 2, 2);
    put16(table + 6, 4);
    put32(table + 8, 20);
    put16(table + 12, 3);
    put16(table + 14, 10);
    put32(table + 16, 20);
    put16(table + 20, 12);
    put32(table + 24, sub_length);
    put32(table + 32, groups);
    i = 0;
    while (i < count) {
        U32 start = i, end = i;
        U8 *group;
        while (end + 1 < count &&
               items[end + 1].codepoint == items[end].codepoint + 1 &&
               items[end + 1].glyph == (U16)(items[end].glyph + 1)) end++;
        group = table + 36 + group_index * 12;
        put32(group, items[start].codepoint);
        put32(group + 4, items[end].codepoint);
        put32(group + 8, items[start].glyph);
        group_index++;
        i = end + 1;
    }
    *length_out = length;
    return table;
}

static U8 *build_name(U32 *length_out) {
    const char *values[4] = {
        "Emoji26 Additions", "Regular",
        "Emoji26 Additions", "Emoji26Additions-Regular"
    };
    const U16 ids[4] = {1, 2, 4, 6};
    U32 string_bytes = 0, cursor = 0, i, j, length;
    U8 *table;
    for (i = 0; i < 4; i++)
        string_bytes += (U32)strlen(values[i]) * 3;
    length = 6 + 8 * 12 + string_bytes;
    table = (U8 *)calloc(length, 1);
    if (!table) return NULL;
    put16(table + 2, 8);
    put16(table + 4, 6 + 8 * 12);
    for (i = 0; i < 4; i++) {
        U8 *record = table + 6 + i * 12;
        U32 n = (U32)strlen(values[i]);
        put16(record, 1);
        put16(record + 6, ids[i]);
        put16(record + 8, (U16)n);
        put16(record + 10, (U16)cursor);
        memcpy(table + 6 + 8 * 12 + cursor, values[i], n);
        cursor += n;
    }
    for (i = 0; i < 4; i++) {
        U8 *record = table + 6 + (4 + i) * 12;
        U32 n = (U32)strlen(values[i]);
        put16(record, 3);
        put16(record + 2, 1);
        put16(record + 4, 0x0409);
        put16(record + 6, ids[i]);
        put16(record + 8, (U16)(n * 2));
        put16(record + 10, (U16)cursor);
        for (j = 0; j < n; j++) {
            table[6 + 8 * 12 + cursor++] = 0;
            table[6 + 8 * 12 + cursor++] = (U8)values[i][j];
        }
    }
    *length_out = length;
    return table;
}

static U32 table_checksum(const U8 *data, U32 length) {
    U32 sum = 0, i;
    for (i = 0; i < (length + 3) / 4; i++) {
        U8 word[4] = {0, 0, 0, 0};
        U32 remaining = length - i * 4;
        U32 amount = remaining > 4 ? 4 : remaining;
        memcpy(word, data + i * 4, amount);
        sum += get32(word);
    }
    return sum;
}

static int compare_table(const void *a, const void *b) {
    return memcmp(((const Table *)a)->tag, ((const Table *)b)->tag, 4);
}

static void free_source_tables(Table *tables, U16 count,
                               U8 *new_cmap, U8 *new_name) {
    U16 i;
    for (i = 0; i < count; i++) {
        if (tables[i].data != new_cmap && tables[i].data != new_name)
            free(tables[i].data);
    }
    free(tables);
}

static int write_subset(const char *path, const U8 *source, size_t source_size,
                        U32 face, U8 *new_cmap, U32 cmap_length,
                        U8 *new_name, U32 name_length) {
    U16 source_count = get16(source + face + 4);
    U16 count = 0, i, power = 1, selector = 0;
    Table *tables = (Table *)calloc((size_t)source_count + 2, sizeof(Table));
    U32 offset, file_length, head_offset = 0, sum;
    U8 *output;
    FILE *f;
    if (!tables) return 0;
    for (i = 0; i < source_count; i++) {
        const U8 *record = source + face + 12 + (U32)i * 16;
        U32 source_offset = get32(record + 8);
        U32 source_length = get32(record + 12);
        if (!memcmp(record, "cmap", 4) || !memcmp(record, "name", 4) ||
            !memcmp(record, "DSIG", 4)) continue;
        if (!inside(source_size, source_offset, source_length)) {
            free_source_tables(tables, count, new_cmap, new_name);
            return 0;
        }
        memcpy(tables[count].tag, record, 4);
        tables[count].length = source_length;
        tables[count].data = (U8 *)malloc(source_length);
        if (!tables[count].data) {
            free_source_tables(tables, count, new_cmap, new_name);
            return 0;
        }
        memcpy(tables[count].data, source + source_offset, source_length);
        if (!memcmp(record, "head", 4) && source_length >= 12)
            memset(tables[count].data + 8, 0, 4);
        count++;
    }
    memcpy(tables[count].tag, "cmap", 4);
    tables[count].data = new_cmap;
    tables[count].length = cmap_length;
    count++;
    memcpy(tables[count].tag, "name", 4);
    tables[count].data = new_name;
    tables[count].length = name_length;
    count++;
    qsort(tables, count, sizeof(Table), compare_table);
    offset = 12 + (U32)count * 16;
    for (i = 0; i < count; i++) {
        offset = (offset + 3) & ~3UL;
        tables[i].offset = offset;
        tables[i].checksum = table_checksum(tables[i].data, tables[i].length);
        offset += tables[i].length;
    }
    file_length = (offset + 3) & ~3UL;
    output = (U8 *)calloc(file_length, 1);
    if (!output) {
        free_source_tables(tables, count, new_cmap, new_name);
        return 0;
    }
    memcpy(output, source + face, 4);
    put16(output + 4, count);
    while ((U16)(power * 2) <= count) {
        power = (U16)(power * 2);
        selector++;
    }
    put16(output + 6, (U16)(power * 16));
    put16(output + 8, selector);
    put16(output + 10, (U16)(count * 16 - power * 16));
    for (i = 0; i < count; i++) {
        U8 *record = output + 12 + (U32)i * 16;
        memcpy(record, tables[i].tag, 4);
        put32(record + 4, tables[i].checksum);
        put32(record + 8, tables[i].offset);
        put32(record + 12, tables[i].length);
        memcpy(output + tables[i].offset, tables[i].data, tables[i].length);
        if (!memcmp(tables[i].tag, "head", 4))
            head_offset = tables[i].offset;
    }
    if (!head_offset) {
        free(output);
        free_source_tables(tables, count, new_cmap, new_name);
        return 0;
    }
    sum = table_checksum(output, file_length);
    put32(output + head_offset + 8, 0xb1b0afbaUL - sum);
    f = fopen(path, "wb");
    if (!f || fwrite(output, 1, file_length, f) != file_length) {
        if (f) fclose(f);
        free(output);
        free_source_tables(tables, count, new_cmap, new_name);
        return 0;
    }
    fclose(f);
    free(output);
    free_source_tables(tables, count, new_cmap, new_name);
    return 1;
}

int main(int argc, char **argv) {
    U8 *font, *cmap, *name;
    size_t size;
    U32 face, mapping_count, cmap_length, name_length;
    Mapping *mappings;
    FILE *mapped_file;
    U32 i;
    if (argc != 5) {
        fprintf(stderr, "usage: font-additions-builder DONOR ADDITIONS OUTPUT MAPPED_LIST\n");
        return 64;
    }
    font = read_file(argv[1], &size);
    if (!font) {
        fprintf(stderr, "cannot read donor font\n");
        return 66;
    }
    face = first_face(font, size);
    if (!inside(size, face, 12)) {
        fprintf(stderr, "invalid donor face\n");
        free(font);
        return 65;
    }
    mappings = load_mappings(argv[2], font, size, face, &mapping_count);
    if (!mappings || !mapping_count) {
        fprintf(stderr, "no safe mapped additions\n");
        free(font);
        return 65;
    }
    mapped_file = fopen(argv[4], "w");
    if (!mapped_file) {
        fprintf(stderr, "cannot write mapped-additions list\n");
        free(mappings);
        free(font);
        return 73;
    }
    for (i = 0; i < mapping_count; i++)
        fprintf(mapped_file, "U+%04lX\n", mappings[i].codepoint);
    fclose(mapped_file);
    cmap = build_cmap(mappings, mapping_count, &cmap_length);
    name = build_name(&name_length);
    if (!cmap || !name ||
        !write_subset(argv[3], font, size, face, cmap, cmap_length,
                      name, name_length)) {
        fprintf(stderr, "font build failed\n");
        free(name);
        free(cmap);
        free(mappings);
        free(font);
        return 74;
    }
    printf("built=%s additions=%lu family=Emoji26 Additions\n",
           argv[3], mapping_count);
    free(name);
    free(cmap);
    free(mappings);
    free(font);
    return 0;
}
