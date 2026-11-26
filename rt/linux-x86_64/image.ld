/* The runtime as one run of bytes that may stand anywhere: the header
 * first, then code and constants. The program stands behind it, at the
 * same place in a line of the cache as without it, so the image ends at
 * a multiple of 64. A writable byte or a relocation has no place in it. */
SECTIONS
{
	. = 0;
	.image : {
		*(.head)
		*(.text .text.*)
		*(.rodata .rodata.*)
		. = ALIGN(64);
		rt_end = .;
	}
	.data : { *(.data .data.* .bss .bss.* COMMON .got .got.*) }
	ASSERT(SIZEOF(.data) == 0, "the runtime has writable data")
	/DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}
