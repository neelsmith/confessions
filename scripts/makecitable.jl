f = joinpath(pwd(), "src", "alternatingreff.txt")
urnbase = "urn:cts:latinLit:stoa0040.stoa001.omar:"

citable = ["#!ctsdata"]
ref = ""
for ln in readlines(f)
    if startswith(ln, r"^[0-9]")
        ref = ln
    elseif ! isempty(ln)
        push!(citable, string(urnbase, ref, "|", ln))
    end
end

outfile = joinpath(pwd(), "src", "confessions.cex")
open(outfile,"w") do io
    write(io, join(citable,"\n") * "\n")
end