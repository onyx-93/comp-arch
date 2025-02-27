######################
#     xor TEST       #
######################

.globl __start

.text

__start:

    # Generate pseudo-random values using arithmetic operations
    # ---------------------------
    # Existing pseudo-random value generation code
    addi t0, zero, -1    # t0 = 0xFFFFFFFF (-1 in signed representation)
    addi t1, zero, 3     # t1 = 3 (small nonzero value)
    add t0, t0, t1       # t0 = 0xFFFFFFFF + 3 = 0x00000002 
    sll a1, t0, t1       # a1 = t0 << 3 = 0x00000010
    xor t1, a1, t0       # t1 = a1 ^ t0 = 0x00000010 ^ 0x00000002 = 0x00000012
    addi t2, t1, 10      # t2 = t1 + 10 = 0x00000012 + 0x0000000A = 0x0000001C
    srl a5, t2, a1       # a5 = t2 >> a1 = 0x0000001C >> 0x00000010 = 0x00000000
    addi a0, t0, 0x7F8   # a0 = t0 + 0x7F8 = 0x00000002 + 0x7F8 = 0x000007FA
    sra t3, a0, t0       # t3 = a0 >>> t0 = 0x7FA >> 2 = 0x000001FE

    # ---------------------------
    # Test for sltu (set less than unsigned)
    # Test 1: Compare 0xFFFFFFFE and 0x00000002
    #   - t4 = 0xFFFFFFFE (unsigned: 4294967294)
    #   - t5 = 0x00000002 (unsigned: 2)
    # Since 4294967294 is not less than 2, sltu should produce 0.
    addi t4, zero, -2    # t4 = 0xFFFFFFFE (-2 in signed, interpreted as 4294967294 unsigned)
    addi t5, zero, 2     # t5 = 2
    sltu a2, t4, t5      # a2 = (t4 < t5)? 1: 0, expected a2 = 0

    # Test 2: Compare 0x00000002 and 0xFFFFFFFE
    #   - t6 = 0x00000002 (unsigned: 2)
    #   - t7 = 0xFFFFFFFE (unsigned: 4294967294)
    # Since 2 is less than 4294967294, sltu should produce 1.
    addi t6, zero, 2     # t6 = 2
    addi t7, zero, -2    # t7 = 0xFFFFFFFE
    sltu a3, t6, t7      # a3 = (t6 < t7)? 1: 0, expected a3 = 1



    # Perform XOR test
   # xor t2, t0, t1       # t2 = t0 \oplus t1

    # Validate XOR property: A \oplus A = 0
    #xor t3, t2, t2       # t3 = t2 \oplus t2 (should be zero)
    #add a0, zero, t3     # If t3 = 0, a0 remains 0, ow test fails (a0 \neq 0)
