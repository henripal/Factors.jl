#
# Dimensions
#
# Main file for Dimension datatype

# abstract Dimension{T} <: AbstractVector{T}
"""
A `Dimension` ... does what?

Should implements
    `values`
    `name`
Values should be some implementation of AbstractArray:
    `getindex`
    'start', `next`, `done`
    `first`
    `last`
    `eltype`
"""
abstract Dimension{T}

# stored as a range
abstract RangeDimension{T} <: Dimension{T}

"""
    ListDimension(name::Symbol, states::AbstractArray)
    ListDimension(name::Symbol, states::NTuple{N, T})

A dimension whose states emnumerated in an array.
"""
immutable ListDimension{T} <: Dimension{T}
    name::Symbol
    states::Tuple{Vararg{T}}

    function ListDimension(name::Symbol, states::Tuple)
        allunique(states) || non_unique_states_error()
        length(states) > 1 || singleton_dimension_error(length(states))

        new_states = promote(states...)
        new(name, new_states)
    end
end

ListDimension{T}(name::Symbol, states::Tuple{Vararg{T}}) =
    ListDimension{T}(name, states)

ListDimension{T}(name::Symbol, states::AbstractVector{T}) =
    ListDimension{T}(name, (states...))

"""
    StepDimension(name::Symbol, states::StepRange{T, S})
    StepDimension(name::Symbol, start::T, [step::S=1,] stop::T)

Similar to a StepRange, enumerates values over start:step:stop
"""
immutable StepDimension{T, S} <: RangeDimension{T}
    name::Symbol
    states::StepRange{T, S}

    function StepDimension(name::Symbol, states::StepRange{T, S})
        length(states) > 1 || singleton_dimension_error(length(states))

        new(name, states)
    end
end

StepDimension{T,S}(name::Symbol, states::StepRange{T, S}) =
    StepDimension{T,S}(name, states)

StepDimension{T,S}(name::Symbol, start::T, step::S, stop::T) =
    StepDimension{T,S}(name, start:step:stop)

StepDimension{T}(name::Symbol, start::T, stop::T) =
    StepDimension{T,Int}(name, start:1:stop)

"""
    UnitDimension(name::Symbol, states:UnitRange{T})
    UnitDimension(name::Symbol, start::T, stop::T)

Similar to a UnitRange, enumerates values over start:stop
"""
immutable UnitDimension{T<:Real} <: RangeDimension{T}
    name::Symbol
    states::UnitRange{T}

    function UnitDimension(name::Symbol, states::UnitRange{T})
        length(states) > 1 || singleton_dimension_error(length(states))

        new(name, states)
    end
end

UnitDimension{T<:Real}(name::Symbol, states::UnitRange{T}) =
    UnitDimension{T}(name, states)

UnitDimension{T<:Real}(name::Symbol, start::T, stop::T) =
    UnitDimension{T}(name, start:stop)

"""
    CartesianDimension(name::Symbol, states::Base.OneTo)
    CartesianDimension(name::Symbol, length)

An integer dimension that starts at 1.
"""
immutable CartesianDimension{T<:Integer} <: RangeDimension{T}
    name::Symbol
    states::OneTo{T}

    function CartesianDimension(name::Symbol, states::OneTo{T})
        length(states) > 1 || singleton_dimension_error(length(states))

        new(name, states)
    end
end

CartesianDimension{T<:Integer}(name::Symbol, states::OneTo{T}) =
    CartesianDimension{T}(name, states)

CartesianDimension{T<:Integer}(name::Symbol, length::T) =
    CartesianDimension{T}(name, OneTo(length))

###############################################################################
#                   Functions

# genaric name and value
"""
    name(d::Dimension)

Return the name of the dimension, as a symbol
"""
name(d::Dimension) = d.name

"""
    values(d::Dimension)

Return the possible values a dimension can take
"""
Base.values(d::Dimension) = d.states

Base.length(d::Dimension) = length(values(d))

Base.size(d::Dimension) = size(values(d))

Base.step(d::RangeDimension) = step(values(d))

Base.first(d::Dimension) = first(values(d))

Base.last(d::Dimension) = last(values(d))

minimum(d::Dimension) = minimum(values(d))

maximum(d::Dimension) = maximum(values(d))

#                   Iterator Interface

Base.start(d::Dimension) = start(values(d))

Base.next(d::Dimension, i) = next(values(d), i)

Base.done(d::Dimension, i) = done(values(d), i)

Base.eltype{T}(::Dimension{T}) = T

###############################################################################
#                   Comparisons and Equality

==(d1::Dimension, d2::Dimension) =
    (d1.name == d2.name) &&
    (length(d1.states) == length(d2.states)) &&
    all(values(d1) .== values(d2))

# states should all be unique
.==(d::Dimension, x) = values(d) .== convert(eltype(d), x)

.!=(d::Dimension, x) = !(d .== x)

in(x, d::Dimension) = any(d .== x)

findfirst(d::Dimension, x) =
    findfirst(values(d), convert(eltype(d), x))

# can't be defined in terms of each b/c of non-trivial case of x ∉ d
@inline function .<(d::Dimension, x)
    ind = falses(length(d))
    loc = findfirst(d, x)

    # indexing works 1:-1 and 1:0 too ...
    ind[1:(loc - 1)] = true

    return ind
end

@inline function .>(d::Dimension, x)
    ind = falses(length(d))
    loc = findfirst(d, x)

    # if x ∉ d, then prevent 1:end being all true
    (loc != 0) && (ind[(loc + 1):end] = true)

    return ind
end

@inline function .<=(d::Dimension, x)
    ind = falses(length(d))
    loc = findfirst(d, x)

    ind[1:loc] = true

    return ind
end

@inline function .>=(d::Dimension, x)
    ind = falses(length(d))
    loc = findfirst(d, x)

    (loc != 0) && (ind[loc:end] = true)

    return ind
end

###############################################################################
#                   Indexing

# custom indexin for integer (and float?) ranges
# TODO profile this and see if its worthy
function indexin{T<:Integer}(xs::Vector{T}, d::RangeDimension{T})
    inds = zeros(Int, size(xs))

    (ds, rs) = divrem(xs - first(d), step(d))
    valid = (rs .== 0) & (minimum(d) .≤ xs .≤ maximum(d))
    inds[valid] = abs(ds[valid]) + 1
    inds == indexin(xs, d)

    return inds
end

indexin(x, d::Dimension) = first(indexin([x], values(d)))

indexin(xs::AbstractArray, d::Dimension) = indexin(xs, values(d))

"""
    update(dim::Dimension, I)

Return the indicies of `I` in `dim` and  an updated dimension from `I`

`I` is either an array of states found in dim or a logical index.
"""
update(dim::Dimension, I) = _update(dim, indexin(I, dim))

update(dim::Dimension, I::AbstractVector{Bool}) = _update(dim, find(I))

# given the index
function _update(dim::Dimension, inds::Vector{Int})
    vs = dim[inds]
    new_d = dimension(name(dim), vs)

    return(inds, new_d)
end

#                   AbstractArray Interfact
# the actual index in I
Base.getindex(d::Dimension, I) = getindex(values(d), I)
# override for list dims to get arrays, not tuples
Base.getindex(d::ListDimension, I::AbstractArray) = [getindex(values(d), I)...]
Base.endof(d::Dimension) = endof(values(d))


###############################################################################
#                   Infer Dimension
"""
    dimension{T<:AbstractArray}(name::Symbol, states::T)

Pick the best type of dimension type based on the type of states.
"""
dimension(name::Symbol, states::AbstractVector) =
    ListDimension(name, states)
dimension(name::Symbol, states::Tuple) =
    ListDimension(name, states)
dimension(name::Symbol, states::StepRange) =
    StepDimension(name, states)
dimension(name::Symbol, states::UnitRange) =
    first(states) == 1 ?
        CartesianDimension(name, length(states)) :
        UnitDimension(name, states)
dimension(name::Symbol, states::Base.OneTo) =
    CartesianDimension(name, states)
dimension(name::Symbol, length::Int) =
    CartesianDimension(name, length)

