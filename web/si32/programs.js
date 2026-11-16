const PROGRAMS = [
{ id: "hello", name: "Hello + Fibonacci", src:
`# Prints a greeting, then Fibonacci numbers.
# Memory-mapped I/O: a byte stored at UART prints a character,
# a word stored at UART+4 prints a decimal number.
.equ UART, 0x1F000

main:
    li   sp, 0xFF00          # stack at the top of RAM
    li   s0, UART
    la   a0, greeting
    call puts
    li   t0, 0               # a = fib(0)
    li   t1, 1               # b = fib(1)
    li   s1, 30              # how many to print
fib_loop:
    sw   t0, 4(s0)           # print a
    li   t2, ' '
    sb   t2, 0(s0)
    add  t2, t0, t1          # next = a + b
    mv   t0, t1
    mv   t1, t2
    addi s1, s1, -1
    bnez s1, fib_loop
    li   t2, '\\n'
    sb   t2, 0(s0)
    ebreak                   # stop the clock

puts:                        # print the zero-terminated string at a0
    lbu  t2, 0(a0)
    beqz t2, puts_done
    sb   t2, 0(s0)
    addi a0, a0, 1
    j    puts
puts_done:
    ret

greeting:
    .string "Hello from a CPU made of NAND gates.\\nFibonacci: "
` },
{ id: "primes", name: "Prime sieve", src:
`# Sieve of Eratosthenes: every prime below 1000.
.equ UART, 0x1F000
.equ N, 1000

main:
    li   s0, UART
    la   s1, sieve           # one byte per number, 1 = crossed out
    li   s2, N
    li   t0, 2               # i
outer:
    mul  t1, t0, t0          # start crossing out at i*i
    bge  t1, s2, report
    add  t2, s1, t0
    lbu  t3, 0(t2)
    bnez t3, next_i          # i is composite, skip it
cross:
    add  t2, s1, t1
    li   t3, 1
    sb   t3, 0(t2)
    add  t1, t1, t0          # j += i
    blt  t1, s2, cross
next_i:
    addi t0, t0, 1
    j    outer

report:
    li   t0, 2
    li   s3, 0               # number of primes found
print_loop:
    add  t2, s1, t0
    lbu  t3, 0(t2)
    bnez t3, skip
    sw   t0, 4(s0)
    li   t3, ' '
    sb   t3, 0(s0)
    addi s3, s3, 1
skip:
    addi t0, t0, 1
    blt  t0, s2, print_loop
    la   a0, summary
    call puts
    sw   s3, 4(s0)
    li   t3, '\\n'
    sb   t3, 0(s0)
    ebreak

puts:
    lbu  t2, 0(a0)
    beqz t2, puts_done
    sb   t2, 0(s0)
    addi a0, a0, 1
    j    puts
puts_done:
    ret

summary:
    .string "\\nPrimes below 1000: "
    .align 2
sieve:
    .zero 1000
` },
{ id: "fact", name: "Factorials", src:
`# n! for n = 1..12 using the hardware multiplier (MUL).
# 12! = 479001600 is the largest that fits in 32 bits.
.equ UART, 0x1F000

main:
    li   s0, UART
    li   t0, 1               # n
    li   t1, 1               # n!
    li   s1, 13
loop:
    mul  t1, t1, t0          # n! = (n-1)! * n
    sw   t0, 4(s0)           # "n"
    la   a0, middle
    call puts                # "! = "
    sw   t1, 4(s0)           # value
    li   t2, '\\n'
    sb   t2, 0(s0)
    addi t0, t0, 1
    blt  t0, s1, loop
    ebreak

puts:
    lbu  t2, 0(a0)
    beqz t2, puts_done
    sb   t2, 0(s0)
    addi a0, a0, 1
    j    puts
puts_done:
    ret

middle:
    .string "! = "
` },
{ id: "mandel", name: "Mandelbrot", src:
`# The Mandelbrot set on the 64x64 framebuffer.
# Fixed-point maths with 10 fraction bits (1.0 = 1024).
# Each pixel byte is a colour index (iteration count).
.equ FB, 0x10000
.equ MAXIT, 14

main:
    li   s0, FB              # pixel pointer
    li   s1, 0               # row
    li   s5, -1331           # cy = -1.3
    li   s6, 4096            # escape radius squared = 4.0
    li   s7, MAXIT
    li   s8, 64
row:
    li   s2, 0               # column
    li   s4, -2048           # cx = -2.0
col:
    mv   t0, s4              # x = cx
    mv   t1, s5              # y = cy
    li   t2, 0               # iteration
iter:
    mul  t3, t0, t0
    srai t3, t3, 10          # x*x
    mul  t4, t1, t1
    srai t4, t4, 10          # y*y
    add  t5, t3, t4
    bgt  t5, s6, done        # escaped?
    mul  t1, t0, t1
    srai t1, t1, 9           # 2*x*y
    add  t1, t1, s5          # y = 2xy + cy
    sub  t0, t3, t4
    add  t0, t0, s4          # x = x*x - y*y + cx
    addi t2, t2, 1
    blt  t2, s7, iter
done:
    sb   t2, 0(s0)
    addi s0, s0, 1
    addi s4, s4, 42          # step = 2.6 / 64
    addi s2, s2, 1
    blt  s2, s8, col
    addi s5, s5, 42
    addi s1, s1, 1
    blt  s1, s8, row
    ebreak
` }
];
if (typeof module !== "undefined") module.exports = { PROGRAMS };

