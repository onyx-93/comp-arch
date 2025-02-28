######################
#     xor TEST       #
######################

.globl __start

.text

__start:

    # Generate pseudo-random values using arithmetic operations
    # Test shifts (sll, srl, sra)
    addi a0, zero, -32    # s0 = -32 (0xFFFFFFE0)
    addi a1, zero, 3
    sll a2, s0, s1        # s2 = -256 (0xFFFFFE00)
    srl a3, s0, s1        # s3 = 536870900 (0x1FFFFFFC)
    sra a4, s0, s1        # s4 = -4 (0xFFFFFFFC)

    # Test immediate shifts (slli, srli, srai)
    slli a5, s0, 2        # s5 = -128 (0xFFFFFF80)
    srli a6, s0, 2        # s6 = 1073741816 (0x3FFFFFF8)
    srai a7, s0, 2        # s7 = -8 (0xFFFFFFF8)

    # Test comparisons (sltu, sltiu)
    addi t1, zero, -1     # s8 = 0xFFFFFFFF (unsigned max)
    addi t2, zero, 1      # s9 = 1
    sltu t3, s8, s9      # s10 = 0 (4294967295 > 1)
    sltu t4, s9, s8      # s11 = 1 (1 < 4294967295)
    sltiu t5, s8, 1      # s12 = 0 (4294967295 < 1? False)
    sltiu t6, s9, 2      # s13 = 1 (1 < 2? True)

    # Exit
    addi a0, zero, 0
    ret
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    # ---------------------------
     # Generate pseudo-random values using arithmetic operations

    # Test SRA (register variant) with a negative number.
    # s0 = -32 (0xFFFFFFE0), s1 = 3, so sra s2, s0, s1 should yield -4 (0xFFFFFFFC)
    #addi s0, zero, -32      
    #addi s1, zero, 3        
    #sra s2, s0, s1      #s2 = -4 (0xFFFFFFFC).     

    # Test SRAI (immediate variant) with a negative number.
    # s3 = -16 (0xFFFFFFF0), shifting right by 2 should yield -4 (0xFFFFFFFC)
    #addi s3, zero, -16      
    #srai s4, s3, 2     #s4 = -4 (0xFFFFFFFC).          

    # End of test; return from main.
    #addi a0, zero, 0        
    #ret



   # addi t0, zero, -1    # t0 = 0xFFFFFFFF (-1 in signed representation)
    #addi t1, zero, 3     # t1 = 3 (small nonzero value)
    #add t0, t0, t1       # t0 = 0xFFFFFFFF + 3 = 0x00000002 
   # sll a1, t0, t1       # a1 = t0 << 3 = 0x00000010
 #   xor t1, a1, t0       # t1 = a1 ^ t0 = 0x00000010 ^ 0x00000002 = 0x00000012
  #  addi t2, t1, 10      # t2 = t1 + 10 = 0x00000012 + 0x0000000A = 0x0000001C
#    srl a5, t2, a1       # a5 = t2 >> a1 = 0x0000001C >> 0x00000010 = 0x00000000
 #   addi a0, t0, 0x7F8   # a0 = t0 + 0x7F8 = 0x00000002 + 0x7F8 = 0x000007FA
  #  sra t3, a0, t0       # t3 = a0 >>> t0 = 0x7FA >> 2 = 0x000001FE

    # ---------------------------
    # Test for sltu (set less than unsigned)
    # Test 1: Compare 0xFFFFFFFE and 0x00000002
  #  addi t4, zero, -2    # t4 = 0xFFFFFFFE (-2 in signed, unsigned: 4294967294)
  #  addi t5, zero, 2     # t5 = 2
  #  sltu a2, t4, t5      # a2 = (t4 < t5)? 1: 0, expected a2 = 0

    # Test 2: Compare 0x00000002 and 0xFFFFFFFE
   # addi t6, zero, 2     # t6 = 2
  #  addi s0, zero, -2    # s0 = 0xFFFFFFFE
 #   sltu a3, t6, s0      # a3 = (t6 < s0)? 1: 0, expected a3 = 1

    # ---------------------------
    # Test for slli (shift left logical immediate)
    # Set a register to 1 and shift left by 4 bits:
  #  addi s1, zero, 1     # s1 = 1
   # slli s2, s1, 4       # s2 = s1 << 4 = 1 << 4 = 16, expected s2 = 16 (0x10)

    # ---------------------------
    # Test for srli (shift right logical immediate)
    # Set a register to 16 and shift right by 2 bits:
#    addi s3, zero, 16    # s3 = 16 (0x10)
 #   srli s4, s3, 2       # s4 = s3 >> 2 = 16 >> 2 = 4, expected s4 = 4 (0x4)

    # ---------------------------
    # Test for srai (shift right arithmetic immediate)
    # Use a negative number to observe sign extension:
#    addi s5, zero, -16   # s5 = -16 (0xFFFFFFF0 in 32-bit)
 #   srai s6, s5, 2       # s6 = s5 >>> 2, expected arithmetic shift: -16 >> 2 = -4 (0xFFFFFFFC)

    # ---------------------------
    # Test for sltiu (set less than immediate unsigned)
    # Test 1: Compare a negative value and a small positive value
#    addi s7, zero, -1    # s7 = -1, which is 0xFFFFFFFF unsigned (4294967295)
 #   sltiu s8, s7, 1      # s8 = (s7 < 1)? 1: 0, expected s8 = 0
    # Test 2: Compare two small positive values
 #   addi s10, zero, 1    # s10 = 1
 #   sltiu s11, s10, 2    # s11 = (1 < 2)? 1: 0, expected s11 = 1



    # Perform XOR test
   # xor t2, t0, t1       # t2 = t0 \oplus t1

    # Validate XOR property: A \oplus A = 0
    #xor t3, t2, t2       # t3 = t2 \oplus t2 (should be zero)
    #add a0, zero, t3     # If t3 = 0, a0 remains 0, ow test fails (a0 \neq 0)
