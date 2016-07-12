@struct immutable cpu_sample
    cpu::UInt32
    res::UInt32
end

function dump_sample_dict(io, sample_dict)
    for (k,v) in sample_dict
        println(io, PERF_SAMPLE_TYPE[k]," = ", v)
    end
end

immutable counter_value
  value::UInt64
  id::UInt64
end

immutable time_value
  time_enabled::UInt64
  time_running::UInt64
end

function extract_read_format(buf, attr)
    values = counter_value[]
    value = id = time_enabled = time_running = 0
    nr = 1
    if (attr.read_type & PERF_FORMAT_GROUP) != 0
      nr = read(buf, UInt64)
    else
      value = read(buf, UInt64)
    end
    if (attr.read_type & PERF_FORMAT_TOTAL_TIME_ENABLED) != 0
      time_enabled = read(buf, UInt64)
    end
    if (attr.read_type & PERF_FORMAT_TOTAL_TIME_RUNNING) != 0
      time_running = read(buf, UInt64)
    end
    if (attr.read_type & PERF_FORMAT_GROUP) != 0
      for i = 1:nr
        value = read(buf, UInt64)
        if (attr.read_type & PERF_FORMAT_ID) != 0
          id = read(buf, UInt64)
        end
        push!(values, counter_value(value, id))
      end
    else
      if (attr.read_type & PERF_FORMAT_ID) != 0
        id = read(buf, UInt64)
      end
      push!(values, counter_value(value, id))
    end
    (time_value(time_enabled,time_running), values)
end

function extract_sample_kinds(data, attr)
    sample_type = attr.sample_type
    sample_data = Dict{UInt64, Any}()
    buf = IOBuffer(data)
    for (kind, T) in ((PERF_SAMPLE_IDENTIFIER, UInt64),
                      (PERF_SAMPLE_IP, UInt64),
                      (PERF_SAMPLE_TID, tid_record),
                      (PERF_SAMPLE_TIME, UInt64),
                      (PERF_SAMPLE_ADDR, UInt64),
                      (PERF_SAMPLE_ID, UInt64),
                      (PERF_SAMPLE_STREAM_ID, UInt64),
                      (PERF_SAMPLE_CPU, cpu_sample),
                      (PERF_SAMPLE_PERIOD, UInt64))
      if (sample_type & kind) != 0
          sample_data[kind] = unpack(buf, T)
      end
    end
    if (sample_type & PERF_SAMPLE_READ) != 0
      sample_data[PERF_SAMPLE_READ] = extract_read_format(buf, attr)
    end
    if (sample_type & PERF_SAMPLE_CALLCHAIN) != 0
      nr = read(buf, UInt64)
      sample_data[PERF_SAMPLE_CALLCHAIN] = read(buf, UInt64, nr)
    end
    if (sample_type & PERF_SAMPLE_RAW) != 0
      size = read(buf, UInt32)
      sample_data[PERF_SAMPLE_RAW] = read(buf, UInt8, size)
    end
    if (sample_type & PERF_SAMPLE_BRANCH_STACK) != 0
      error("Unsupported")
    end
    if (sample_type & PERF_SAMPLE_REGS_USER) != 0
      abi = read(buf, UInt64)
      @show abi
      sample_data[PERF_SAMPLE_REGS_USER] = abi == 0 ? UInt64[] :
        read(buf, UInt64, count_ones(attr.sample_regs_user))
    end
    if (sample_type & PERF_SAMPLE_STACK_USER) != 0
      size = read(buf, UInt64)
      if size == 0
        sample_data[PERF_SAMPLE_STACK_USER] = UInt8[]
      else
        data = read(buf, UInt8, size)
        dyn_size = read(buf, UInt64)
        resize!(data, dyn_size)
        sample_data[PERF_SAMPLE_STACK_USER] = data
      end
    end
    for kind in (PERF_SAMPLE_WEIGHT,
                      PERF_SAMPLE_DATA_SRC,
                      PERF_SAMPLE_TRANSACTION)
      if (sample_type & kind) != 0
          sample_data[kind] = unpack(buf, UInt64)
      end
    end
    if (sample_type & PERF_SAMPLE_REGS_INTR) != 0
      abi = read(buf, UInt64)
      sample_data[PERF_SAMPLE_REGS_INTR] = (abi, read(buf, count_ones(attr.sample_regs_intr)))
    end
    sample_data
end
