# Register numbering, bit mask is 1 << x for x the enum value
perf_regs_numbering = Dict{UInt32, Symbol}(
   0 => :rax,  1 => :rbx,  2 => :rcx,  3 => :rdx,  4 => :rsi,
   5 => :rdi,  6 => :rbp,  7 => :rsp,  8 => :rip,  9 => :rflags,
  10 =>  :cs, 11 =>  :ss, 12 =>  :ds, 13 =>  :es, 14 =>  :fs,
  15 =>  :gs, 16 =>  :r8, 17 =>  :r9, 18 => :r10, 19 => :r11,
  20 => :r12, 21 => :r13, 22 => :r14, 23 => :r15
)
