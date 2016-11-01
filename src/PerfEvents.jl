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

  # Iterator for `attrs`. This us used both by the kernel and the file format
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

  @struct immutable perf_file_attr
    attr::perf_event_attr
    ids::perf_file_section
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
    @assert sizeof(perf_file_attr) <= it.handle.header.attr_size
    seek(it.handle.io,
      it.handle.header.attrs.offset +
      (n-1)*it.handle.header.attr_size)
    unpack(it.handle.io, perf_file_attr)
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

  immutable Record
    event_type::UInt32
    misc::UInt16
    record::Any
  end
  Base.show(io::IO, rec::Record) =
    println(io, PERF_EVENT_TYPE[rec.event_type], ": ", rec.record)

  function read_record(io)
    header = unpack(io, perf_event_header)
    pos = position(io)
    function read_remaining_array()
      remaining_length = header.size -
       sizeof(perf_event_header) -
        (position(io) - pos)
      read(io, UInt8, remaining_length)
    end
    read_remaining_string() = String(read_remaining_array())
    rec = Record(header.event_type, header.misc,
      if header.event_type == PERF_RECORD_ITRACE_START
          unpack(io, itrace_start)
      elseif header.event_type == PERF_RECORD_AUX
          unpack(io, aux_record)
      elseif header.event_type == PERF_RECORD_COMM
          (unpack(io, itrace_start),
           read_remaining_string())
      elseif header.event_type == PERF_RECORD_MMAP
          x = unpack(io, itrace_start)
          y = unpack(io, mmap_record)
          z = read_remaining_string()
          idx = findfirst(z,'\0')
          z = idx == 0 ? z : z[1:idx-1]
          (x,y,z)
      elseif header.event_type == PERF_RECORD_MMAP2
          x = unpack(io, itrace_start)
          y = unpack(io, mmap_record)
          z = unpack(io, mmap2_extra_record)
          fname = read_remaining_string()
          idx = findfirst(fname,'\0')
          fname = idx == 0 ? fname : fname[1:idx-1]
          (x,y,z,fname)
      elseif header.event_type == PERF_RECORD_SAMPLE
          read_remaining_array()
      elseif header.event_type == PERF_RECORD_FORK
          (unpack(io, itrace_start),
           unpack(io, itrace_start),
           read_remaining_array())
      elseif header.event_type == PERF_RECORD_THROTTLE ||
        header.event_type == PERF_RECORD_UNTHROTTLE
          nothing
      elseif header.event_type == PERF_RECORD_EXIT
          (unpack(io, itrace_start),
           unpack(io, itrace_start),
           read(io, UInt64),
           read_remaining_array())
      elseif header.event_type == PERF_RECORD_TIME_CONV
          unpack(io, time_conv_record)
      elseif header.event_type == PERF_RECORD_FINISHED_ROUND
      else
          error(string("Unknown record type ",
            try PERF_EVENT_TYPE[header.event_type];
            catch; string("0x",hex(header.event_type)); end))
      end)
  end

  # Iterator for `data`
  immutable RecordIterator
    handle::PerfFileHandle
  end
  Base.iteratorsize(::Type{RecordIterator}) = Base.SizeUnknown()

  start(it::RecordIterator) = 0
  done(it::RecordIterator, s) = s >= it.handle.header.data.size
  function next(it::RecordIterator, s)
    seek(io, it.handle.header.data.offset + s)
    return (read_record(it.handle.io), s + header.size)
  end

  # Iterator for use in sorted_records
  immutable RecordChunkIterator
    handle::PerfFileHandle
    chunk::Vector{Tuple{UInt64, UInt64}}
  end
  Base.iteratorsize(::Type{RecordIterator}) = Base.HasLength()
  function Base.getindex(it::RecordChunkIterator, i)
    seek(it.handle.io, it.handle.header.data.offset + it.chunk[i][2])
    read_record(it.handle.io)
  end
  Base.start(it::RecordChunkIterator) = 1
  Base.done(it::RecordChunkIterator, i) = i > length(it.chunk)
  Base.next(it::RecordChunkIterator, i) = (it[i], i+1)

  function read_ids(h, ids::perf_file_section)
    seek(h.io, ids.offset)
    read(h.io, UInt64, div(ids.size,sizeof(UInt64)))
  end

  # Computes the offset to the timestamp from the start (for PERF_RECORD_SAMPLE)
  # or end (for everything else) of the record.
  function time_offsets_for_attr(attr)
    (sizeof(UInt64)*count_ones((attr.sample_type &
      (PERF_SAMPLE_IDENTIFIER | PERF_SAMPLE_IP | PERF_SAMPLE_TID))),
     sizeof(UInt64)*(1+count_ones((attr.sample_type &
      (PERF_SAMPLE_IDENTIFIER | PERF_SAMPLE_CPU | PERF_SAMPLE_STREAM_ID | PERF_SAMPLE_ID)))))
  end

  """
    Records in a perf.data file are not sorted in chronological order.
    This is because a single perf.data file may contain records from
    several CPUs and though the contents of each individual CPU buffer
    is ordered chronologicallly, the overall file is not.

    To be able to recover chronological order, perf_events has the ability
    to include a time stamp in all sample and non-sample events (the latter
    only if sample_id_all=1).

    One slight optimization is that perf marks the spot at which it is done
    going through all the CPU buffers and since we know that timestamps are
    monotonically increasing within one CPU buffer, we can use this to
    accelerate sorting.



    This function will sort the records by timestamp
  """
  function sorted_record_chunks(callback, h)
    header = h.header
    # Pair of the attribute and a vector of all corresponding ids
    attrs = Tuple{perf_event_attr,Vector{UInt64}}[]
    for file_attr in AttrIterator(h)
      push!(attrs,(file_attr.attr,read_ids(h, file_attr.ids)))
    end
    # If there are multiple attrs in the event stream, we'll need to disambiguate
    # them by id.
    id_to_attr_map = Dict{UInt64, perf_event_attr}()
    need_to_check_ids = length(attrs) > 1
    if need_to_check_ids
      for attr in attrs
        if (attr[1].sample_type & PERF_SAMPLE_IDENTIFIER) == 0
          error("sample_type needs to include PERF_SAMPLE_IDENTIFIER for sorting")
        end
        if !attr[1].sample_id_all
          error("sample_id_all needs to be set for sorting")
        end
        for id in attr[2]
          id_to_attr_map[id] = attr[1]
        end
      end
    end
    for attr in attrs
      if (attr[1].sample_type & PERF_SAMPLE_TIME) == 0
        error("sample_type needs to include PERF_SAMPLE_TIME for sorting")
      end
    end
    # Pair of a record's timestamp and its offset in the file. We keep two of
    # these buffers. At every FINISHED_ROUND barrier, we know that that no
    # future event will have a timestamp smaller than the largest we have
    # already seen. However, we do not know that no old events are straggling
    # and will be seen in the current round. Thus we keep two lists, with
    # timestamps split by the maximum timestamp of the last round.
    last_round_records = Tuple{UInt64,UInt64}[]
    records = Tuple{UInt64,UInt64}[]
    last_round_max_timestamp = 0
    current_round_max_timestamp = 0
    data_offset = 0
    data_size = header.data.size
    attr = attrs[1][1]
    while data_offset < data_size
      seek(h.io, header.data.offset + data_offset)
      record_header = unpack(h.io, perf_event_header)
      if record_header.event_type == PERF_RECORD_FINISHED_ROUND
        # Last round records is now complete. Sort them and off we go.
        callback(RecordChunkIterator(h, sort(last_round_records, by=x->x[1])))
        last_round_records = records
        records = Tuple{UInt64,UInt64}[]
        last_round_max_timestamp = current_round_max_timestamp
        data_offset += record_header.size
        continue
      end
      if need_to_check_ids
        # We verified above that we have PERF_SAMPLE_IDENTIFIER,
        # which is at a known location (at the beginning for PERF_RECORD_SAMPLE,
        # at the end for everything else)
        if record_header.event_type != PERF_RECORD_SAMPLE
          skip(h.io, record_header.size - sizeof(perf_event_header) - sizeof(UInt64))
          # Otherwise, we're already in the right spot
        end
        attr = id_to_attr_map[read(h.io, UInt64)]
      end
      sample_off, non_sample_off = time_offsets_for_attr(attr)
      @show (sample_off, non_sample_off)
      seek(h.io, header.data.offset + data_offset +
        ((record_header.event_type == PERF_RECORD_SAMPLE) ?
          sizeof(perf_event_header) + sample_off :
          record_header.size - non_sample_off))
      timestamp = read(h.io, UInt64)
      push!(timestamp <= last_round_max_timestamp ? last_round_records : records,
        (timestamp, data_offset))
      current_round_max_timestamp = max(timestamp, current_round_max_timestamp)
      data_offset += record_header.size
    end
    # We have all records, both the last and the current round should be ready to go
    callback(RecordChunkIterator(h, sort(last_round_records, by=x->x[1])))
    callback(RecordChunkIterator(h, sort(records, by=x->x[1])))
  end

  include("constants.jl")
  include("utils.jl")
  include("samples.jl")
  include("x86.jl")

end # module
