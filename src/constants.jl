using Base.Meta

macro constants(array, stripprefix, expr)
    ret = Expr(:block)
    # Initialize the name lookup array
    push!(ret.args,:(const $array = Dict{UInt32,String}()))
    for e in expr.args
        if !isexpr(e,:const)
            continue
        end
        eq = e.args[1]
        @assert isexpr(eq,:(=))
        name = string(eq.args[1])
        name = replace(name,stripprefix,"",1)
        push!(ret.args,e)
        push!(ret.args,:($array[UInt32($(eq.args[1]))] = $name))
    end
    return esc(ret)
end
@constants PERF_EVENT_TYPE "" begin
    # Kernel defined events
    const PERF_RECORD_MMAP              = 1
    const PERF_RECORD_LOST              = 2
    const PERF_RECORD_COMM              = 3
    const PERF_RECORD_EXIT              = 4
    const PERF_RECORD_THROTTLE          = 5
    const PERF_RECORD_UNTHROTTLE        = 6
    const PERF_RECORD_FORK              = 7
    const PERF_RECORD_READ              = 8
    const PERF_RECORD_SAMPLE            = 9
    const PERF_RECORD_MMAP2             = 10
    const PERF_RECORD_AUX               = 11
    const PERF_RECORD_ITRACE_START      = 12
    const PERF_RECORD_LOST_SAMPLES      = 13
    const PERF_RECORD_SWITCH            = 14
    const PERF_RECORD_SWITCH_CPU_WIDE   = 15
    # perf (the user space tool) defined events
    const PERF_RECORD_HEADER_ATTR          = 64
	const PERF_RECORD_HEADER_EVENT_TYPE    = 65
	const PERF_RECORD_HEADER_TRACING_DATA  = 66
	const PERF_RECORD_HEADER_BUILD_ID      = 67
	const PERF_RECORD_FINISHED_ROUND       = 68
	const PERF_RECORD_ID_INDEX             = 69
	const PERF_RECORD_AUXTRACE_INF         = 70
	const PERF_RECORD_AUXTRACE             = 71
	const PERF_RECORD_AUXTRACE_ERRO        = 72
	const PERF_RECORD_THREAD_MAP           = 73
	const PERF_RECORD_CPU_MAP              = 74
	const PERF_RECORD_STAT_CONFIG          = 75
	const PERF_RECORD_STAT                 = 76
	const PERF_RECORD_STAT_ROUND           = 77
	const PERF_RECORD_EVENT_UPDAT          = 78
	const PERF_RECORD_TIME_CONV            = 79
end
@constants PERF_TYPE "" begin
    const PERF_TYPE_HARDWARE            = 0
    const PERF_TYPE_SOFTWARE            = 1
    const PERF_TYPE_TRACEPOINT          = 2
    const PERF_TYPE_HW_CACHE            = 3
    const PERF_TYPE_RAW                 = 4
    const PERF_TYPE_BREAKPOINT          = 5
end
@constants PERF_HW "PERF_COUNT_HW_" begin
    const PERF_COUNT_HW_CPU_CYCLES              = 0
    const PERF_COUNT_HW_INSTRUCTIONS            = 1
    const PERF_COUNT_HW_CACHE_REFERENCES        = 2
    const PERF_COUNT_HW_CACHE_MISSES            = 3
    const PERF_COUNT_HW_BRANCH_INSTRUCTIONS     = 4
    const PERF_COUNT_HW_BRANCH_MISSES           = 5
    const PERF_COUNT_HW_BUS_CYCLES              = 6
    const PERF_COUNT_HW_STALLED_CYCLES_FRONTEND = 7
    const PERF_COUNT_HW_STALLED_CYCLES_BACKEND  = 8
    const PERF_COUNT_HW_REF_CPU_CYCLES          = 9
end
@constants PERF_SAMPLE_TYPE "PERF_SAMPLE_" begin
    const PERF_SAMPLE_IP                  = UInt64(1) << 0
    const PERF_SAMPLE_TID                 = UInt64(1) << 1
    const PERF_SAMPLE_TIME                = UInt64(1) << 2
    const PERF_SAMPLE_ADDR                = UInt64(1) << 3
    const PERF_SAMPLE_READ                = UInt64(1) << 4
    const PERF_SAMPLE_CALLCHAIN           = UInt64(1) << 5
    const PERF_SAMPLE_ID                  = UInt64(1) << 6
    const PERF_SAMPLE_CPU                 = UInt64(1) << 7
    const PERF_SAMPLE_PERIOD              = UInt64(1) << 8
    const PERF_SAMPLE_STREAM_ID           = UInt64(1) << 9
    const PERF_SAMPLE_RAW                 = UInt64(1) << 10
    const PERF_SAMPLE_BRANCH_STACK        = UInt64(1) << 11
    const PERF_SAMPLE_REGS_USER           = UInt64(1) << 12
    const PERF_SAMPLE_STACK_USER          = UInt64(1) << 13
    const PERF_SAMPLE_WEIGHT              = UInt64(1) << 14
    const PERF_SAMPLE_DATA_SRC            = UInt64(1) << 15
    const PERF_SAMPLE_IDENTIFIER          = UInt64(1) << 16
    const PERF_SAMPLE_TRANSACTION         = UInt64(1) << 17
    const PERF_SAMPLE_REGS_INTR           = UInt64(1) << 18
end
@constants PERF_FORMAT "" begin
    const PERF_FORMAT_TOTAL_TIME_ENABLED  = UInt64(1) << 0
    const PERF_FORMAT_TOTAL_TIME_RUNNING  = UInt64(1) << 1
    const PERF_FORMAT_ID                  = UInt64(1) << 2
    const PERF_FORMAT_GROUP               = UInt64(1) << 3
end

const PERF_CONTEXT_HV			     = -32   % UInt64
const PERF_CONTEXT_KERNEL		     = -128  % UInt64
const PERF_CONTEXT_USER              = -512  % UInt64
const PERF_CONTEXT_GUEST             = -2048 % UInt64
const PERF_CONTEXT_GUEST_KERNEL      = -2176 % UInt64
const PERF_CONTEXT_GUEST_USER        = -2560 % UInt64
