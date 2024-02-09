module FQ

struct Record
    header::UInt32
    seq::UInt32
    qheader::UInt32
    qual::UInt32
    stop::UInt32
end

seq_len(x::Record) = x.qheader - x.seq - 1

mutable struct Parser{T<:IO}
    const io::T
    const buffer::Vector{UInt8}
    filled::UInt32
    pos::UInt32
end

function Parser(io::IO; bufsize::Int64 = 64 * 1024)
    mem = Vector{UInt8}(undef, bufsize)
    Parser{typeof(io)}(io, mem, readbytes!(io, mem), 1)
end

function fill_buffer!(x::Parser)
    buf = x.buffer
    i = 1
    if x.pos ≤ x.filled
        N = x.filled - x.pos + 1
        copyto!(buf, i, buf, x.pos, N)
        i += N
    end
    i += readbytes!(x.io, view(buf, i:length(buf)), length(buf) - i + 1)
    x.filled = i - 1
    x.pos = 1
    x
end

@inline function find_newline(v::Vector{UInt8}, start, to)
    width = 32
    i = start
    GC.@preserve v begin
        @inbounds while i ≤ to - width + 1
            vec = unsafe_load(Ptr{NTuple{width,UInt8}}(pointer(v, i)))
            if reduce(|, vec .== UInt8('\n'))
                for j = 1:width
                    vec[j] == UInt8('\n') && return i + j
                end
            end
            i += width
        end
    end
    @inbounds while i ≤ to
        (v[i] == UInt8('\n')) && return i
        i += 1
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

benchmark(path) = open(io -> read_all(Parser(io)), path; lock = false)

benchmark(joinpath(dirname(dirname(pathof(FQ))), "small.fq"))

end # module FQ
