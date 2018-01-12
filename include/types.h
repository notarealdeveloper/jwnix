#ifndef _TYPES_H
#define _TYPES_H


#include    <stdbool.h>

/* Some useful typedefs */
typedef     unsigned char       u8;
typedef     unsigned short      u16;
typedef     unsigned int        u32;
typedef     unsigned long       u64;

/* The redundant "signed" keyword is just for documentation */
typedef     signed   char       s8;
typedef     signed   short      s16;
typedef     signed   int        s32;
typedef     signed   long       s64;

#if defined(__i386__)
typedef     unsigned int        size_t;
typedef     signed   int        ssize_t;
#elif defined(__x86_64__)
typedef     unsigned long       size_t;
typedef     signed   long       ssize_t;
#endif


#endif  /* _TYPES_H */
