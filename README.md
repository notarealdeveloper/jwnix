# The worst kernel ever :)

jwnix. (Pronounced "jason double unix").

This is a project I wrote back in 2014 to procrastinate from grad school.

It's intended more as an educational project than an actual OS kernel.

The basic idea is that if you start programming (like I did) by first getting interested in Linux, then learning all about how to use the shell, then learning some high level languages like Python, and eventually some lower level languages like C, then learning Assembly to try to understand how C does all these supposedly simple things like "printing a single character to the screen," soon realizing that about 90% of the magic seems to be hidden behind this whole `int 0x80` thing, finding yourself being led into the Linux kernel (where you soon develop a bad habit of typing `printk` even in userland code forever and ever after), and seeing as the kernel is a pretty damn sizable project these days, if in an attempt to understand it from first principles you end up studying earlier and earlier kernels until you get back to the wonderful hackerish badassery of linux-0.01 (praise be upon its inline assembly amen), you might find yourself writing something like the code in this repo.

The basic idea (wait, that's how the last paragraph started... oh well, whatever) is to approach your computer like the great mythical hackers of old used to, as a dead piece of metal with no operating system or software at all, and then learn enough that you can start writing code that'll turn it into an actual computer type thing, starting from nothing but the aforementioned dead piece of metal and its (unfortunately-not-always-possible-to-replace) firmware.

In other words: you've got an x86 processor, it starts up in 16 bit real mode, the BIOS loads your code at 0x7c00... go.

# Bugs

1. Cursor bug occurs when we backspace across the leftmost boundary to go up a line, proceed any number of slots backwards, and *then* hit enter to go to the next line. The cursor code must not have a representation of what line it's on. EDIT: Scratch that. I'm pretty sure the problem is that it only increments its representation of what line we're on when we hit enter, but it doesn't decrement that representation when we backspace up one line. Should be trivial to fix this, but for now I need to quit programming and get back to work.

2. I wrote this on arch linux with whatever versions of gcc and nasm they had back in 2014. I'm currently on gentoo and the same code that worked back then (both in qemu and on real hardware) is now no longer able to get past the point where we load the interrupt descriptor table and switch into protected mode. The code hasn't changed, so this is definitely a compiler flags issue, likely something to do with gentoo hardened. Current guess is that it's a problem with the compiler defaulting to generating position independent code. Figure this out, ya idiot. (Talking to myself, not you. You're not an idiot. You're smart. I like you. You look nice today, by the way. How's about a date?)
