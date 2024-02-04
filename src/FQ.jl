module FQ

struct Record
    header::UInt32
    seq::UInt32
    qheader::UInt32
    qual::UInt32
    stop::UInt32
end

seq_len(x::Record) = x.qheader - x.seq - 1

mutable struct Parser
    const io::IOStream
    const buffer::Memory{UInt8}
    filled::UInt32
    pos::UInt32
end

function Parser(io::IOStream; bufsize::Int64=64*1024)
    mem = Memory{UInt8}(undef, Int(bufsize))
    filled = readbytes!(io, mem)
    Parser(io, mem, filled, 1)
end

function fill_buffer!(x::Parser)
    buf = x.buffer
    L = length(buf)
    F = x.filled
    i = 1
    p = x.pos
    # Shift bytes in buffer if we still have unused bytes
    if p ≤ F
        N = F - p + 1
        copyto!(buf, i, buf, p, N)
        i += N
    end
    i += readbytes!(x.io, view(buf, i:L), L - i + 1)
    x.filled = i - 1
    x.pos = 1
    x
end

@inline function find_newline(v::Memory{UInt8}, start, to)
    width = 32
    i = start
    GC.@preserve v begin
        @inbounds while i ≤ to - width + 1
            vec = unsafe_load(Ptr{NTuple{width, UInt8}}(pointer(v, i)))
            if reduce(|, vec .== UInt8('\n'))
                for j in 1:width
                    vec[j] == UInt8('\n') && return i + j
                end
            end
            i += width
        end
    end
    @inbounds for j in i:to
        (v[j] == UInt8('\n')) && return j
    end
    nothing
end

function parse_read(x::Parser)
    buf = x.buffer
    start = Int(x.pos)
    stp = Int(x.filled)
    seq = @something find_newline(buf, start, stp) return nothing
    qheader = @something find_newline(buf, seq + 1, stp) return nothing
    qual = @something find_newline(buf, qheader + 1, stp) return nothing
    stop = @something find_newline(buf, qual + 1, stp) return nothing
    x.pos = (stop + 1) % UInt32
    Record(start % UInt32, seq % UInt32, qheader % UInt32, qual % UInt32, stop % UInt32)
end

function read_all(x::Parser)
    n_seq = n_reads = 0
    while true
        read = @inline parse_read(x)
        if isnothing(read)
            fill_buffer!(x)
            iszero(x.filled) && return (n_reads, n_seq, n_seq)
            continue
        end
        n_reads += 1
        n_seq += seq_len(read)
    end
end

function benchmark(path)
    open(path; lock=false) do io
        read_all(Parser(io))
    end
end

end # module FQ
