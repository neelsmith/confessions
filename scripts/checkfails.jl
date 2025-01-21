using Tabulae, CitableBase
using CitableParserBuilder

url = "http://shot.holycross.edu/morphology/lewisshort-lat24-current.cex"
@time parser = tabulaeStringParser(url, UrlReader)



@time results = map(readlines("fails.cex") ) do ln
    (tkn, count) = split(ln, "|")
    #@info("parsing $(tkn)...")
    parses = parsetoken(tkn, parser)
    if isempty(parses)
        @warn("Failed on $(tkn)")
    end
    (token = tkn, count = count, parses = parses)
end

nfg = filter(pr -> isempty(pr.parses), results)

badlines = map(nfg) do tpl
    @info("tpl")
    string(tpl.token, "|", tpl.count)
end

open("stillnfg.cex", "w") do io
    write(io, join(badlines, "\n"))
end