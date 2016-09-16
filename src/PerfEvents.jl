module PerfEvents
  
  using StructIO
  import Base: start, next, done, getindex, endof, length, show
  
  export EventIterator
  
  @struct immutable perf_file_section
    offset::UInt64
    size::UInt64
  end
  perf_file_section() = perf_file_section(0,0)
  
  @struct immutable perf_file_header
    magic::UInt64
    size::UInt64
    attr_size::UInt64
    attrs::perf_file_section
    data::perf_file_section
    event_types::perf_file_section
    features::NTuple{32, UInt8}
  end
  
  @struct immutable perf_trace_event_type
    event_id::UInt64
    name::NTuple{64,UInt8}
  end
  
  immutable PerfFileHandle{T}
    io::T
    header::perf_file_header
  end
  
  function readmeta(io::IO)
    PerfFileHandle(io, unpack(io,perf_file_header))
  end
  readmeta(path::String) = readmeta(open(path))
  
  # Record structures
  @struct immutable perf_event_header
    event_type::UInt32
    misc::UInt16
    size::UInt16
  end

  @struct immutable tid_record
    pid::UInt32
    tid::UInt32
  end
  const itrace_start = tid_record

  @struct immutable aux_record
    aux_offset::UInt64
    aux_size::UInt64
    flags::UInt64
  end
  
  @struct immutable mmap_record
    start::UInt64
    len::UInt64
    pgoff::UInt64
  end
  
  @struct immutable mmap2_extra_record
    maj::UInt32
    min::UInt32
    ino::UInt64
    ino_generation::UInt64
    prot::UInt32
    flags::UInt32
  end
  
  @struct immutable time_conv_record
    time_shift::UInt64
    time_mult::UInt64
    time_zero::UInt64
  end

  # Iterator for `attrs`
  @struct immutable perf_event_attr
    ev_type::UInt32
    size::UInt32
    config::UInt64
    sample_period_freq::UInt64
    sample_type::UInt64
    read_type::UInt64
    flags::UInt64
    wakeup::UInt32
    bp_type::UInt32
    config1::UInt64
    config2::UInt64
    branch_sample_type::UInt64
    sample_regs_user::UInt64
    sample_stack_user::UInt32
    clockid::Int32
    sample_regs_intr::UInt64
    aux_watermark::UInt32
    reserved_2::UInt32
  end
  
  function show(io::IO, attr::perf_event_attr)
      if attr.ev_type == PERF_TYPE_HARDWARE
          print(io, PERF_HW[attr.config])
      else
          println(io, "Unkown event type"); return
      end
      print(io, ", sample_freq=", attr.sample_period_freq)
      print(io, ", size: ", attr.size)
      print(io, ", sample_type: ",
        join(map(x->PERF_SAMPLE_TYPE[x],
          sort(collect(filter(kind->(kind & attr.sample_type) != 0,
            keys(PERF_SAMPLE_TYPE))))),'|'))
  end
  
  immutable AttrIterator
    handle::PerfFileHandle
  end
  
  endof(it::AttrIterator) =
    div(it.handle.header.attrs.size, it.handle.header.attr_size)
  length(it::AttrIterator) = endof(it)
      
  function getindex(it::AttrIterator, n)
    @assert 1 <= n <= endof(it)
    @assert sizeof(perf_event_attr) <= it.handle.header.attr_size
    seek(it.handle.io,
      it.handle.header.attrs.offset +
      (n-1)*it.handle.header.attr_size)
    unpack(it.handle.io, perf_event_attr)
  end
  
  start(it::AttrIterator) = 1
  next(it::AttrIterator, s) = (it[s], s+1)
  done(it::AttrIterator, s) = s > endof(it)

  # Iterator for `event_types`
  immutable EventIterator
    handle::PerfFileHandle
  end
  
  endof(it::EventIterator) =
    div(it.handle.header.event_types.size,
      sizeof(perf_trace_event_type))
  length(it::EventIterator) = endof(it)
      
  function getindex(it::EventIterator, n)
    seek(it.handle.io,
      it.handle.header.event_types.offset +
      (n-1)*sizeof(perf_trace_event_type))
    unpack(it.handle.io, perf_trace_event_type)
  end
  
  start(it::EventIterator) = 1
  next(it::EventIterator, s) = (it[s], s+1)
  done(it::EventIterator, s) = s > endof(it)
  
  # Iterator for `data`
  immutable RecordIterator
    handle::PerfFileHandle
  end
  Base.iteratorsize(::Type{RecordIterator}) = Base.SizeUnknown()
  
  immutable Record
    event_type::UInt32
    misc::UInt16
    record::Any
  end
  Base.show(io::IO, rec::Record) =
    println(io, PERF_EVENT_TYPE[rec.event_type], ": ", rec.record)
  
  start(it::RecordIterator) = 0
  done(it::RecordIterator, s) = s >= it.handle.header.data.size
  function next(it::RecordIterator, s)
    seek(it.handle.io, it.handle.header.data.offset + s)
    header = unpack(it.handle.io, perf_event_header)
    pos = position(it.handle.io)
    function read_remaining_array()
      remaining_length = header.size -
       sizeof(perf_event_header) -
        (position(it.handle.io) - pos)
      read(it.handle.io, UInt8, remaining_length)
    end
    read_remaining_string() = String(read_remaining_array())
    @show header
    rec = Record(header.event_type, header.misc,
      if header.event_type == PERF_RECORD_ITRACE_START
          unpack(it.handle.io, itrace_start)
      elseif header.event_type == PERF_RECORD_AUX
          unpack(it.handle.io, aux_record)
      elseif header.event_type == PERF_RECORD_COMM
          (unpack(it.handle.io, itrace_start),
           read_remaining_string())
      elseif header.event_type == PERF_RECORD_MMAP
          x = unpack(it.handle.io, itrace_start)
          y = unpack(it.handle.io, mmap_record)
          z = read_remaining_string()
          idx = findfirst(z,'\0')
          z = idx == 0 ? z : z[1:idx-1]
          (x,y,z)
      elseif header.event_type == PERF_RECORD_MMAP2
          x = unpack(it.handle.io, itrace_start)
          y = unpack(it.handle.io, mmap_record)
          z = unpack(it.handle.io, mmap2_extra_record)
          fname = read_remaining_string()
          idx = findfirst(fname,'\0')
          fname = idx == 0 ? fname : fname[1:idx-1]
          (x,y,z,fname)
      elseif header.event_type == PERF_RECORD_SAMPLE
          read_remaining_array()
      elseif header.event_type == PERF_RECORD_FORK
          (unpack(it.handle.io, itrace_start),
           unpack(it.handle.io, itrace_start),
           read_remaining_array())
      elseif header.event_type == PERF_RECORD_THROTTLE ||
        header.event_type == PERF_RECORD_UNTHROTTLE
          nothing
      elseif header.event_type == PERF_RECORD_EXIT
          (unpack(it.handle.io, itrace_start),
           unpack(it.handle.io, itrace_start),
           read(it.handle.io, UInt64),
           read_remaining_array())
      elseif header.event_type == PERF_RECORD_TIME_CONV
          unpack(it.handle.io, time_conv_record)
      elseif header.event_type == PERF_RECORD_FINISHED_ROUND
      else
          error(string("Unknown record type ",
            try PERF_EVENT_TYPE[header.event_type];
            catch; string("0x",hex(header.event_type)); end))
      end)
    return (rec, s + header.size)
  end
  
  include("constants.jl")
  include("utils.jl")
  include("samples.jl")
  include("x86.jl")
  
end # module
