######################
#     pipe TEST      #
######################

.globl __start

.text

__start:
    # Generate pseudo-random values using arithmetic operations
    addi t0, zero, -1    # t0 = 0xFFFFFFFF (-1 in signed representation)
    addi t1, zero, 3     # t1 = 3 (small nonzero value)
    add t0, t0, t1       # t0 = 0xFFFFFFFF + 3 = 0x00000002 
    sll a1, t0, t1       # a1 = t0 << 3 = 0x00000010
    xor t1, a1, t0       # t1 = a1 ^ t0 = 0x00000010 ^ 0x00000002 = 0x00000012
    addi a0, t0, -0x7F8   # a0 = 0x00000002 + (-0x000007F8) = 0xFFFF_F80A
    sra t3, a0, t0       # t3 = a0 >>> t0 = 0x7FA >> 2 = 0xFFFF_FE02
stop:
    j stop