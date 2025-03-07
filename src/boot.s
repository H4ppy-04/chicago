/* multi boot header constants */
.set ALIGN,     1<<0             /* align loaded modules on page boundaries                   */
.set MEMINFO,   1<<1             /* memory map                                                */
.set FLAGS,     ALIGN | MEMINFO  /* multi boot 'flag' value                                   */
.set MAGIC,     0x1BADB002       /* allows bootloader to find the header                      */
.set CHECKSUM,  -(MAGIC + FLAGS) /* checksum of above values, proving multi boot authenticity */

/*
Declare a multi boot header that marks the program as a kernel. These are magic
values that are documented in the multi boot standard. (need reference link).
The bootloader will search for this signature in the first 8 KiB of the Kernel
file, aligned at a 32-bit boundary. The signature is in its own section so the
header can be forced to be within the first 8 KiB of the kernel file.
*/
.section .multiboot
.align 4
.long MAGIC
.long FLAGS
.long CHECKSUM

/*
   The multi boot standard (reference needed) does not define the value of the
   stack pointer register (ESP) and it is up to the kernel to provide a stack.
   This allocates room for a small stack by creating a symbol at the bottom of
   it, then allocating 16384 bytes (16 KiB)for it, and finally creating a
   symbol at the top. The stack grows downwards on x86. The stack is in its own
   section so it can be marked NOBITS, which means the kernel file is smaller
   because it does not contain an uninitialized stack. The stack on x86 must be
   16-byte aligned according to the System V ABI standard and de-factor
   extensions. The compiler will assume the stack is properly aligned and
   failure to align the stack will result in undefined behavior (UB).
 */
.section .bss
.align 16
stack_bottom:
.skip 16384
stack_top:

/*
   The linker script specifies the _start label as the entry point to the
   kernel and the bootloader will jump to this position once the kernel has
   been loaded.  It doesn't make sense to return from this function. This is
   because the bootloader is gone at this point.
*/
.section .text
.global _start
.type _start, @function
_start:
	/*
	   The bootloader has loaded us into 32-bit PROTECTED MODE on an x86
	   machine. Interrupts are disabled, Paging is also disabled. The
	   processor state is as defined in the multi boot standard. The kernel
	   has full control of the CPU. The kernel can only make use of
	   hardware features and any code it provides as part of itself.
	   There's no `printf` function, unless the kernel provides its own
	   <stdio.h> header and a printf implementation. There are no security
	   restrictions, no safeguards, no debugging mechanisms, only what the
	   kernel provides itself. It has absolute and complete power over the
	   machine.
	*/

	/*
	   To set up a stack, we set the esp register to point o the top of the
	   stack (as it grows downwards on x86 systems). This is necessarily
	   done in assembly as languages such as C cannot function without a
	   stack.
	*/
	mov $stack_top, %esp

	/*
	   This is a good place to initialize crucial processor state before
	   the high-level kernel is entered. It's best to minimize the early
	   environment where crucial features are offline. Note that the
	   processor is not fully initialized yet: Features such as floating
	   point instructions and instruction set extensions are not
	   initialized yet.  The GDT should be loaded here. Paging should be
	   enabled here. C++ features such as global constructors and
	   exceptions will require runtime support to work as well.
	*/

	/*
	   Enter the high-level kernel. The ABI requires the stack is 16-byte
	   aligned at the time of the call instruction (which afterwards pushes
	   the return pointer of size 4 bytes). The stack was originally
	   16-byte aligned above and we've pushed a multiple of 16 bytes to the
	   stack since (pushed 0 bytes so far), so the alignment has thus been
	   preserved and the call is well defined.
	*/
	call kernel_main

	/*
	   If the system has nothing more to do, put the computer into an
	   infinite loop. Here's how that's done.

	   1) Disable interrupts with CLI (clear interrupt enable in e-flags).
	   They are already disabled by the bootloader, so this is not needed.
	   Mind that you might later enable interrupts and return from
	   kernel_main (which is sort of nonsensical to do).

	   2) Wait for the next interrupt to arrive with the HLT (halt signal).
	   Since they are disabled, this will 'lock up' the computer.

	   3) JMP to the HLT instruction if it ever wakes up due to a interrupt
	   that isn't able to be masked occurring or due to system management
	   mode.
	*/
	cli
1:      hlt
	jmp 1b

/*
   Set the size of the _start label to the current location '.' minus its
   start. This is useful when debugging or when finally implementing call
   tracing.
*/
.size _start, . - _start
