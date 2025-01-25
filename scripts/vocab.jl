using CitableBase, CitableText, CitableCorpus
using Downloads, Markdown

srcfile = joinpath(pwd(), "src", "confessions.cex")

corpus = fromcex(srcfile, CitableTextCorpus, FileReader)


using Orthography, LatinOrthography

tkns = tokenize(corpus, latin24())

lex = filter(t -> t.tokentype isa LexicalToken, tkns)
totallex = length(lex)

using StatsBase, OrderedCollections

countsraw = map(tkn -> tkn.passage.text, lex) |> countmap |> OrderedDict

counts = sort(countsraw, byvalue = true, rev = true)
distincttokens = length(counts)


@info("Total number of lexical tokens: $(totallex)")
@info("Distinct tokens: $(distincttokens)")


using CitableParserBuilder, Tabulae

tabulaeurl = "http://shot.holycross.edu/morphology/lewisshort-lat24-current.cex"
parser = stringParser(tabulaeurl, UrlReader)




nonsingletons = filter(counts) do (k,v)
    v > 1
end
repeatvocab = keys(nonsingletons) |> collect
@info("Number of repeated tokens: $(length(repeatvocab))")


# This takes < 5 secc on my laptop at home
@time parses = map(repeatvocab) do wrd
    (token = wrd, parselist = parsetoken(wrd, parser))
end

fails = filter(parses) do tpl
    isempty(tpl.parselist)
end


failsmsg = map(fails) do tpl
    string(tpl.token, "|", counts[tpl.token])
    
end

open("fails.cex", "w") do io

    write(io, join(failsmsg, "\n"))
end

pwd()


#=
parsing = true
results = []


for (i,tkn) in enumerate(vocab)
    if parsing
        parsed = parsetoken(tkn, parser)
        if isempty(parsed)
            parsing = false
            @info("Stopped at index $(i), token $(tkn)")
        else
            push!(results, parsed)
        end
    end
end

parsetoken("et", parser)

=#