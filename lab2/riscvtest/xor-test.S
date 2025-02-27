######################
#     xor TEST       #
######################

.globl __start

.text

__start:

    # Generate pseudo-random values using arithmetic operations
    addi t0, zero, -1    # t0 = 0xFFFFFFFF (-1 in signed representation)
    addi t1, zero, 3     # t1 = 3 (small nonzero value)
    add t0, t0, t1       # t0 = 0xFFFFFFFF + 3 = 0x00000002 
    sll a1, t0, t1       # a1 = t0 << 3 = 0x0000_0010
    xor t1, a1, t0       # t1 = a1 ^ t0 = 0x0000_0010 ^ 0x0000_0002 = 0x0000_0012
    addi t2, t1, 10      # t2 = t1 + 10 = 0x0000_0012 + 0x0000_000A = 0x0000_001C
    srl a5, t2, a1       # a5 = t2 >> a1 = 0x0000_001C >> 0x0000_0010 = 0x0000_0000
    addi a0, t0, 0x7F8   # a0 = t0 + 0x7F8 = 0x0000_0002 + 0x7F8  = 0x7FA
    sra t3, a0, t0       # t3 = 0x7FA >>> 0x0000_0002 = 0x0000_01FE


    # Perform XOR test
   # xor t2, t0, t1       # t2 = t0 \oplus t1

    # Validate XOR property: A \oplus A = 0
    #xor t3, t2, t2       # t3 = t2 \oplus t2 (should be zero)
    #add a0, zero, t3     # If t3 = 0, a0 remains 0, ow test fails (a0 \neq 0)
