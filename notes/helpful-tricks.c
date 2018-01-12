#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Some completely stupid shit, for fun ;)
 * =========================================
 * f=helpful-tricks && gcc -o "$f"{,.c} && ./"$f"; echo $?
 */

#define syscall() asm("syscall\n")

#define sys_write       1
#define sys_open        2
#define sys_close       3
#define sys_fork        57
#define sys_exit        60
#define sys_mkdir       83
#define sys_rmdir       84
#define sys_creat       85
#define sys_unlink      87

#define asmprint(s)                                                 \
({                                                                  \
    rdx = strlen(s);    /* library call first, else registerfuck */ \
    rsi = (long)s;      /* avoids warning */                        \
    rdi = 1;            /* write message to stdout */               \
    rax = sys_write;    /* linux x86_64 opcode for write syscall */ \
    syscall();          /* use new x86_64 syscall instruction */    \
})

#define asmexit(exit_code)  \
({                          \
    rax = sys_exit;         \
    rdi = exit_code;        \
    syscall();              \
})

char *msg = "It works for pointers to strings!\n";

void main(int argc, char *argv[])
{
    register long rax asm("rax");
    register long rbx asm("rbx");
    register long rcx asm("rcx");
    register long rdx asm("rdx");
    register long rsi asm("rsi");
    register long rdi asm("rdi");
    register long rsp asm("rsp");
    register long rbp asm("rbp");

    register long r8  asm("r8");
    register long r9  asm("r9");
    register long r10 asm("r10");
    register long r11 asm("r11");
    register long r12 asm("r12");
    register long r13 asm("r13");
    register long r14 asm("r14");
    register long r15 asm("r15");

    /* It works for pointers to strings! */
    asmprint(msg);

    /* It works for string literals! */
    asmprint("It works for string literals!\n");

    /* Just a reminder */
    printf("strlen(\"abc\") == %d\n", strlen("abc"));
    printf("sizeof(\"abc\") == %d\n", sizeof("abc"));

    /* Exit with code 69 */
    asmexit(69);
}
