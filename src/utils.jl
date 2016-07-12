function dump_perf_buf(buf::IOBuffer)
    seekstart(buf)
    while !eof(buf)
        header = unpack(buf, perf_event_header)
        @show header.event_type
        @show header.misc
        println(PERF_EVENT_TYPE[header.event_type])
        pos = position(buf)
        if header.event_type == PERF_RECORD_ITRACE_START
            println(unpack(buf, itrace_start))
        elseif header.event_type == PERF_RECORD_AUX
            println(unpack(buf, aux_record))
        elseif header.event_type == PERF_RECORD_COMM
            println(unpack(buf, itrace_start))
            println(bytestring(read(buf, UInt8, header.size - sizeof(perf_event_header) - sizeof(itrace_start))))
        end
        seek(buf, pos + header.size - sizeof(perf_event_header))
    end
end
