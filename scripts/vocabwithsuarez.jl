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

tabulaeurl = "http://shot.holycross.edu/tabulae/complut-lat25-current.cex"
parser = stringParser(tabulaeurl, UrlReader)


vocab = keys(counts) |> collect

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


using SuarezAI
key = "SET VALUE FOR YOUR BEARER KEY"

prompt = "I'm studying Latin. Can you help me find the dictionary form I would use to look up audetis? Please answer with a single line of delimited text; the word should be in the first column, the dictionary form in the second column, and the part of speech in the third."

suarezanswer = split(asksuarez(prompt, key), "\n")[1]

(form, lemma, pos) = strip.(split(suarezanswer, "|"))

form
lemma


function getls()
    url = "http://shot.holycross.edu/lexica/ls-articles.cex"
    f = Downloads.download(url)
	lslines = split(read(f, String), "\n")
	rm(f)

    data = filter(ln -> ! isempty(ln), lslines)
    map(data[2:end]) do ln
        (seq, urn, key, entry) = split(ln,"|")
        (seq = seq, urn = urn, key = key, entry = entry)
    end
end


ls = getls()

function articlesforlemma(lemma, lexicon)
	matchingarticles = filter(tupl -> startswith(tupl.key, lemma), lexicon)
    if length(matchingarticles) == 1
		matchingarticles[1]
	else
        @warn("Did not match unique article for $(id).")
		nothing
	end
end


preface = """I'm trying to find information in this Latin dictionary entry. Could you extract a brief English definition from it?  Just a few words or phrases, in a single line of text.
"""
fullarticle = articlesforlemma(lemma, ls)

fullarticle.entry |> Markdown.parse

#summaryquery = string(preface, fullarticle.entry)
#asksuarez(summaryquery, key) |> println