"""Find names that collide in the compilers' hash of names.

Prints the pair used by the test hash_collision_prefix: a global name and
a longer one that starts with it, in one bucket, so that a lookup which
did not compare the lengths would take the short name for the long one.
Run it again and update the test if the hash function ever changes.

Two keys with the same name and a different kind or scope never share a
bucket: the kind and scope are mixed in by exclusive or, the final fold is
linear over exclusive or, and so the buckets differ by a constant that is
not zero for any pair of kinds or of the scope numbers in use.
"""
import itertools


def bucket(name, kind, scope):
    h = 2166136261
    for c in name.encode():
        h = ((h ^ c) * 16777619) & 0xffffffff
    h ^= (scope * 0x9E3779B1 + kind) & 0xffffffff
    h ^= h >> 15
    return h & 0xfffff


def names():
    for n in itertools.count(1):
        for t in itertools.product('abcdefghijklmnopqrstuvwxyz', repeat=n):
            yield ''.join(t)


GLOB = 1
b = bucket('q', GLOB, 0)
for s in names():
    if bucket('q' + s, GLOB, 0) == b:
        print('q', 'q' + s)
        break
