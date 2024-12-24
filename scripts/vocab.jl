using CitableBase, CitableText, CitableCorpus

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