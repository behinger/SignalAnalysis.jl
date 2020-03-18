export isanalytic, analytic
export padded, slide
export energy, meantime, rmsduration, meanfrequency, rmsbandwidth, ifreq

# TODO: ifreq, meanfrequency and rmsbandwidth are broken, fix!

"""
$(SIGNATURES)
Generate a padded view of a signal with optional delay/advance.
"""
function padded(s::AbstractVector{T}, padding; delay=0, fill=zero(T)) where {T, N}
  if length(padding) == 1
    left = padding
    right = padding
  else
    left = padding[1]
    right = padding[2]
  end
  PaddedView(fill, s, (1-left:length(s)+right,), (1+delay:delay+length(s),))
end

"""
$(SIGNATURES)
Slide a window over a signal, process each window.
"""
function slide(f::Function, s::AbstractVector, nsamples, overlap=0, args...; showprogress=true)
  @assert overlap < nsamples "overlap must be less than nsamples"
  n = size(s,1)
  m = nsamples - overlap
  mmax = (n-nsamples)÷m
  showprogress && (p = Progress(mmax+1, 1, "Processing: "))
  for j = 0:mmax
    s1 = @view s[j*m+1:j*m+nsamples]
    f(s1, j+1, j*m+1, args...)
    showprogress && next!(p)
  end
end

"""
$(SIGNATURES)
Slide a window over a signal, process each window, and collect the results.
"""
function slide(f::Function, ::Type{T}, s::AbstractVector, nsamples, overlap=0, args...; showprogress=true) where {T}
  @assert overlap < nsamples "overlap must be less than nsamples"
  n = size(s,1)
  m = nsamples - overlap
  mmax = (n-nsamples)÷m
  out = Array{T,1}(undef, 1+mmax)
  showprogress && (p = Progress(mmax+1, 1, "Processing: "))
  for j = 0:mmax
    s1 = @view s[j*m+1:j*m+nsamples]
    out[j+1] = f(s1, j+1, j*m+1, args...)
    showprogress && next!(p)
  end
  return out
end

# TODO: add back toindex
#"Convert time to index."
#toindex(t; fs=???) = 1 + round(Int, toseconds(t)*inHz(fs))

"""
$(SIGNATURES)
Get total signal energy.
"""
energy(s::AbstractVector; fs=framerate(s)) = sum(abs2, s)/inHz(fs)
energy(s::AbstractMatrix; fs=framerate(s)) = vec(sum(abs2, s; dims=1))./inHz(fs)

"""
$(SIGNATURES)
Get mean time of the signal.
"""
meantime(s::SampleBuf) = wmean(domain(s), abs2.(s))
meantime(s; fs) = wmean((0:size(s,1)-1)/fs, abs2.(s))

"""
$(SIGNATURES)
Get RMS duration of the signal.
"""
rmsduration(s::SampleBuf) = sqrt.(wmean(domain(s).^2, abs2.(s)) .- meantime(s).^2)
rmsduration(s; fs) = sqrt.(wmean(((0:size(s,1)-1)/fs).^2, abs2.(s)) .- meantime(s; fs=fs).^2)

"""
$(SIGNATURES)
Get instantaneous frequency of the signal.
"""
function ifreq(s; fs=framerate(s))
  s1 = analytic(s)
  f1 = inHz(fs)/(2π) * diff(unwrap(angle.(s1); dims=1); dims=1)
  vcat(f1[1:1,:], (f1[1:end-1,:]+f1[2:end,:])/2, f1[end:end,:])
end

"""
$(SIGNATURES)
Get mean frequency of the signal.
"""
function meanfrequency(s; fs=framerate(s), nfft=1024, window=nothing)
  mapslices(s; dims=1) do s1
    p = welch_pgram(s1, ceil(Int, length(s1)/nfft); fs=inHz(fs), window=window)
    f = freq(p)
    wmean(f, power(p))
  end
end

"""
$(SIGNATURES)
Get RMS bandwidth of the signal.
"""
function rmsbandwidth(s; fs=framerate(s), nfft=1024, window=nothing)
  mapslices(s; dims=1) do s1
    p = welch_pgram(s1, ceil(Int, length(s1)/nfft); fs=inHz(fs), window=window)
    f = freq(p)
    f0 = wmean(f, power(p))
    sqrt.(wmean((f.-f0).^2, power(p)))
  end
end

### utility functions

wmean(x::AbstractVector, w::AbstractVector) = (x'w) / sum(w)
wmean(x, w::AbstractVector) = sum(x.*w) ./ sum(w)
