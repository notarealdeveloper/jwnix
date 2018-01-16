# The worst kernel ever :)

jwnix. (Pronounced "jason double unix").

This is a project I wrote back in 2014 to procrastinate from grad school.

It's intended more as an educational project than an actual OS kernel.

The basic idea is that if you start programming, like I did, by first getting interested in Linux, then learning about how to use the shell, then learning some high level languages like Python, and eventually some lower level languages like C, then learning Assembly to try to understand how C does all those supposedly simple things like "printing a single character to the screen," then realizing that about 90% of the magic seems to be hidden behind this whole `int 0x80` thing, soon finding yourself learning about the Linux kernel (where you develop a bad habit of typing `printk` even in userland code forever and ever after), and -- seeing as the kernel is a pretty damn sizable project these days -- if, in an attempt to understand it from first principles you end up studying earlier and earlier kernels until you get back to the wonderful hackerish badassery of linux-0.01 (praise be upon its inline assembly, amen) you might find yourself writing something like the code in this repo.

The basic idea (wait, that's how the last paragraph started... oh well, whatever) is to approach your computer like the great mythical hackers of old used to, as a dead piece of metal with no operating system or software, and then learn enough that you can start writing code that'll turn it into an actual computer type thing starting from nothing but the aforementioned dead piece of metal and its (unfortunately-not-always-possible-to-replace) firmware.

In other words: you've got an x86 processor, it starts up in 16 bit real mode, the BIOS loads your code at 0x7c00, ready set go! :D

Along the way, you'll learn important lifelong lessons like:

1. How to print a single character to the screen
2. Goto considered harmful, and
3. Protected mode is a bitch


# Bugs

1. Cursor bug occurs when we backspace across the leftmost boundary to go up a line, proceed any number of slots backwards, and *then* hit enter to go to the next line. The cursor code must not have a representation of what line it's on. EDIT: Scratch that. I'm pretty sure the problem is that it only increments its representation of what line we're on when we hit enter, but it doesn't decrement that representation when we backspace up one line. Should be trivial to fix this, but for now I need to quit programming and get back to work.
