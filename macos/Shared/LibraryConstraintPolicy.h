#pragma once
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#import <errno.h>

static uint32_t FCRead32(const uint8_t *p, BOOL big) {
    return big ? ((uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 | (uint32_t)p[2] << 8 | p[3]) :
        ((uint32_t)p[3] << 24 | (uint32_t)p[2] << 16 | (uint32_t)p[1] << 8 | p[0]);
}

static NSData *FCPolicyDigest(NSData *data, NSUInteger length) {
    uint8_t hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, hash);
    return [NSData dataWithBytes:hash length:length];
}

static NSDictionary *FCReadSignatureSlots(uint64_t fileSize, NSData *(^readRange)(uint64_t, NSUInteger)) {
    if (fileSize < 32 || fileSize > UINT32_MAX) return nil;
    NSData *header = readRange(0, 32);
    if (header.length != 32) return nil;
    const uint8_t *p = header.bytes;
    uint64_t base = 0, size = fileSize;
    if (FCRead32(p, YES) == 0xcafebabe) {
        uint32_t offset = FCRead32(p + 16, YES), length = FCRead32(p + 20, YES), alignment = FCRead32(p + 24, YES);
        if (FCRead32(p + 4, YES) != 1 || FCRead32(p + 8, YES) != 0x100000c || FCRead32(p + 12, YES) ||
            alignment > 31 || offset < 28 || offset % (1ULL << alignment) || length < 32 ||
            (uint64_t)offset + length != size) return nil;
        base = offset; size = length;
        header = readRange(base, 32);
        if (header.length != 32) return nil;
        p = header.bytes;
    }
    if (FCRead32(p, NO) != 0xfeedfacf || FCRead32(p + 4, NO) != 0x100000c || FCRead32(p + 8, NO)) return nil;
    uint32_t count = FCRead32(p + 16, NO), commands = FCRead32(p + 20, NO);
    if (!count || count > 4096 || (uint64_t)count * 8 > commands || commands > 1024 * 1024 ||
        32ULL + commands > size) return nil;
    NSData *table = readRange(base + 32, commands);
    if (table.length != commands) return nil;
    p = table.bytes;
    uint64_t offset = 0, start = 0, signatureSize = 0;
    for (uint32_t i = 0; i < count; i++) {
        if (offset + 8 > commands) return nil;
        uint32_t command = FCRead32(p + offset, NO), length = FCRead32(p + offset + 4, NO);
        if (length < 8 || length % 8 || offset + length > commands) return nil;
        if (command == 0x1d) {
            if (length != 16 || signatureSize) return nil;
            start = FCRead32(p + offset + 8, NO); signatureSize = FCRead32(p + offset + 12, NO);
            if (start < 32ULL + commands || signatureSize < 12 || signatureSize > 4 * 1024 * 1024 ||
                start + signatureSize > size) return nil;
        }
        offset += length;
    }
    if (offset != commands || !signatureSize) return nil;
    NSData *signature = readRange(base + start, (NSUInteger)signatureSize);
    if (signature.length != signatureSize) return nil;
    p = signature.bytes;
    uint32_t length = FCRead32(p + 4, YES), blobs = FCRead32(p + 8, YES);
    if (FCRead32(p, YES) != 0xfade0cc0 || length < 12 || length > signatureSize || !blobs || blobs > 64 ||
        12ULL + blobs * 8 > length) return nil;
    NSMutableDictionary *slots = [NSMutableDictionary dictionary];
    NSMutableArray<NSValue *> *ranges = [NSMutableArray array];
    for (uint32_t i = 0; i < blobs; i++) {
        uint32_t slot = FCRead32(p + 12 + i * 8, YES), position = FCRead32(p + 16 + i * 8, YES);
        if (slots[@(slot)] || position < 12ULL + blobs * 8 || (uint64_t)position + 8 > length) return nil;
        uint32_t span = FCRead32(p + position + 4, YES);
        if (span < 8 || (uint64_t)position + span > length) return nil;
        NSRange range = NSMakeRange(position, span);
        for (NSValue *other in ranges) if (NSIntersectionRange(range, other.rangeValue).length) return nil;
        [ranges addObject:[NSValue valueWithRange:range]];
        slots[@(slot)] = [NSData dataWithBytes:p + position length:span];
    }
    return slots;
}

static inline NSDictionary *FCSignatureSlots(NSData *file) {
    return FCReadSignatureSlots(file.length, ^NSData *(uint64_t offset, NSUInteger length) {
        if (offset > file.length || length > file.length - offset) return nil;
        return [file subdataWithRange:NSMakeRange((NSUInteger)offset, length)];
    });
}

static NSDictionary *FCPolicyFile(NSString *path) {
    int fd = open(path.fileSystemRepresentation, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK);
    if (fd < 0) return nil;
    struct stat st;
    NSDictionary *slots = nil;
    if (!fstat(fd, &st) && S_ISREG(st.st_mode) && st.st_size >= 32 && st.st_size <= UINT32_MAX) {
        slots = FCReadSignatureSlots((uint64_t)st.st_size, ^NSData *(uint64_t offset, NSUInteger length) {
            if (offset > (uint64_t)st.st_size || length > (uint64_t)st.st_size - offset || length > 4 * 1024 * 1024)
                return nil;
            NSMutableData *data = [NSMutableData dataWithLength:length];
            ssize_t count;
            do { count = pread(fd, data.mutableBytes, length, (off_t)offset); } while (count < 0 && errno == EINTR);
            return count == (ssize_t)length ? data : nil;
        });
    }
    close(fd);
    return slots;
}

static NSData *FCPolicyCodeDirectory(NSDictionary *slots) {
    for (NSUInteger slot = 0x1000; slot < 0x1006; slot++) if (slots[@(slot)]) return nil;
    NSData *cd = slots[@0];
    if (cd.length < 44) return nil;
    const uint8_t *p = cd.bytes;
    uint32_t version = FCRead32(p + 8, YES), offset = FCRead32(p + 16, YES);
    uint32_t special = FCRead32(p + 24, YES), code = FCRead32(p + 28, YES);
    NSUInteger header = version == 0x20400 ? 88 : version == 0x20500 ? 96 : version == 0x20600 ? 108 : 0;
    if (FCRead32(p, YES) != 0xfade0c02 || FCRead32(p + 4, YES) != cd.length || !header ||
        p[36] != 32 || p[37] != 2 || (uint64_t)special * 32 + header > offset ||
        (uint64_t)offset + (uint64_t)code * 32 > cd.length) return nil;
    return cd;
}

static NSArray *FCPolicyDER(const uint8_t *p, NSUInteger size, NSUInteger *used, NSUInteger depth, NSUInteger *budget) {
    if (depth >= 16 || size < 2 || !*budget) return nil;
    (*budget)--;
    NSUInteger length = p[1], offset = 2;
    if (length & 128) {
        NSUInteger count = length & 127;
        if (!count || count > 4 || size < 2 + count || !p[2]) return nil;
        length = 0;
        for (NSUInteger i = 0; i < count; i++) length = (length << 8) | p[2 + i];
        if (length < 128) return nil;
        offset += count;
    }
    if (length > size - offset) return nil;
    id value = nil;
    if (p[0] == 0x70 || p[0] == 0xb0 || p[0] == 0x30) {
        NSMutableArray *children = [NSMutableArray array];
        NSUInteger cursor = 0;
        while (cursor < length) {
            NSUInteger consumed = 0;
            NSArray *child = FCPolicyDER(p + offset + cursor, length - cursor, &consumed, depth + 1, budget);
            if (!child || !consumed) return nil;
            [children addObject:child]; cursor += consumed;
        }
        value = children;
    } else if (p[0] == 0x0c) value = [[NSString alloc] initWithBytes:p + offset length:length encoding:NSUTF8StringEncoding];
    else if (p[0] == 4) value = [NSData dataWithBytes:p + offset length:length];
    else if (p[0] == 2) {
        if (!length || length > 8 || (p[offset] & 128) || (length > 1 && !p[offset] && !(p[offset + 1] & 128))) return nil;
        uint64_t integer = 0;
        for (NSUInteger i = 0; i < length; i++) integer = (integer << 8) | p[offset + i];
        value = @(integer);
    }
    if (!value) return nil;
    *used = offset + length;
    return @[@(p[0]), value];
}

static NSDictionary *FCPolicyDictionary(NSArray *node) {
    if (![node[0] isEqual:@0xb0]) return nil;
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    for (NSArray *pair in node[1]) {
        if (![pair[0] isEqual:@0x30] || [pair[1] count] != 2) return nil;
        NSArray *key = pair[1][0], *value = pair[1][1];
        if (![key[0] isEqual:@0x0c] || dictionary[key[1]]) return nil;
        dictionary[key[1]] = value;
    }
    return dictionary;
}

static NSSet *FCPolicyConstraint(NSData *blob) {
    if (blob.length < 10 || blob.length > 4096 || FCRead32(blob.bytes, YES) != 0xfade8181) return nil;
    NSUInteger used = 0, budget = 128;
    NSArray *root = FCPolicyDER((const uint8_t *)blob.bytes + 8, blob.length - 8, &used, 0, &budget);
    if (!root || used != blob.length - 8 || ![root[0] isEqual:@0x70] || [root[1] count] != 2 ||
        ![root[1][0] isEqual:@[@2, @1]]) return nil;
    NSDictionary *envelope = FCPolicyDictionary(root[1][1]);
    if (envelope.count != 4 || ![envelope[@"ccat"] isEqual:@[@2, @0]] ||
        ![envelope[@"comp"] isEqual:@[@2, @1]] || ![envelope[@"vers"] isEqual:@[@2, @1]]) return nil;
    NSDictionary *requirements = FCPolicyDictionary(envelope[@"reqs"]);
    if (requirements.count != 1) return nil;
    NSDictionary *operators = FCPolicyDictionary(requirements[@"cdhash"]);
    NSArray *values = operators[@"$in"];
    if (operators.count != 1 || ![values[0] isEqual:@0x30] || [values[1] count] != 5) return nil;
    NSMutableSet *hashes = [NSMutableSet set];
    for (NSArray *value in values[1]) {
        if (![value[0] isEqual:@4] || [value[1] length] != 20) return nil;
        [hashes addObject:value[1]];
    }
    return hashes.count == 5 ? hashes : nil;
}

static BOOL FCVerifyLibraryConstraintSlots(NSDictionary *slots, NSSet *expected) {
    if (expected.count != 5) return NO;
    NSData *cd = FCPolicyCodeDirectory(slots), *blob = slots[@11];
    if (!cd || ![FCPolicyConstraint(blob) isEqualToSet:expected]) return NO;
    const uint8_t *p = cd.bytes;
    uint32_t offset = FCRead32(p + 16, YES), special = FCRead32(p + 24, YES);
    if (special < 11 || !(FCRead32(p + 12, YES) & 0x10000)) return NO;
    return [[cd subdataWithRange:NSMakeRange(offset - 11 * 32, 32)] isEqualToData:FCPolicyDigest(blob, 32)];
}

static inline BOOL FCVerifyLibraryConstraint(NSData *gui, NSSet *expected) {
    return FCVerifyLibraryConstraintSlots(FCSignatureSlots(gui), expected);
}

static BOOL FCGUILibraryPolicy(NSString *bundle, NSData *validatedHash) {
    if (![validatedHash isKindOfClass:NSData.class] || validatedHash.length != 20) return NO;
    NSArray *names = @[@"App", @"FlutterMacOS", @"objective_c", @"rust_api", @"sqlite3"];
    NSString *frameworks = [bundle stringByAppendingPathComponent:@"Contents/Frameworks"];
    NSMutableSet *expectedNames = [NSMutableSet set], *hashes = [NSMutableSet set];
    for (NSString *name in names) {
        [expectedNames addObject:[name stringByAppendingString:@".framework"]];
        NSString *relative = [NSString stringWithFormat:@"%@.framework/Versions/A/%@", name, name];
        NSString *path = [frameworks stringByAppendingPathComponent:relative];
        char canonical[PATH_MAX];
        if (!realpath(path.fileSystemRepresentation, canonical) || ![@(canonical) isEqualToString:path]) return NO;
        NSData *cd = FCPolicyCodeDirectory(FCPolicyFile(path));
        if (!cd) return NO;
        [hashes addObject:FCPolicyDigest(cd, 20)];
    }
    NSArray *contents = [NSFileManager.defaultManager contentsOfDirectoryAtPath:frameworks error:nil];
    if (!contents || ![[NSSet setWithArray:contents] isEqualToSet:expectedNames]) return NO;
    NSDictionary *gui = FCPolicyFile([bundle stringByAppendingPathComponent:@"Contents/MacOS/Flash"]);
    NSData *cd = FCPolicyCodeDirectory(gui);
    return cd && [FCPolicyDigest(cd, 20) isEqualToData:validatedHash] && FCVerifyLibraryConstraintSlots(gui, hashes);
}
