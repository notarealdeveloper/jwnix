#ifndef _TYPES_H
#define _TYPES_H


#include    <stdbool.h>

typedef     unsigned char       u8;
typedef     unsigned short      u16;
typedef     unsigned int        u32;
typedef     unsigned long       u64;

#if defined(__i386__)
typedef     unsigned int        size_t;
typedef     int                 ssize_t;
#elif defined(__x86_64__)
typedef     unsigned int        size_t;
typedef     int                 ssize_t;
#endif


#endif  /* _TYPES_H */
