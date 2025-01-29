using CitableBase, CitableText, CitableCorpus
using Downloads, Markdown
using Orthography, LatinOrthography
using StatsBase, OrderedCollections
using Tabulae, CitableParserBuilder
using CairoMakie
using Format

url  = "https://raw.githubusercontent.com/neelsmith/confessions/refs/heads/main/src/confessions.cex"
corpus = fromcex(url, CitableTextCorpus, UrlReader)
tkns = tokenize(corpus, latin24())
lex = filter(t -> t.tokentype isa LexicalToken, tkns)
countsraw = map(tkn -> tkn.passage.text, lex) |> countmap |> OrderedDict
counts = sort(countsraw, byvalue = true, rev = true)
nonsingletons = filter(counts) do (k,v)
    v > 1
end
repeatvocab = keys(nonsingletons) |> collect

"""Load a parser."""
function getparser(localparser::Bool = false; tabulae = "")
    if localparser
        parserfile = joinpath(tabulae, "scratch", "lewisshort-lat24-current.cex")
        tabulaeStringParser(parserfile, FileReader)
    else
        tabulaeurl = "http://shot.holycross.edu/morphology/lewisshort-lat24-current.cex"
        tabulaeStringParser(tabulaeurl, UrlReader)
    end
end
parser = getparser()


parses = map(repeatvocab) do wrd
    (token = wrd, parselist = parsetoken(wrd, parser))
end

successes = filter(parses) do tpl
    ! isempty(tpl.parselist)
end

fails = filter(parses) do tpl
    isempty(tpl.parselist)
end

"""Find unique idetnifiers for lexemes in a list of analysis tuples."""
function lexids(plist) #::Vector{NamedTuple{(:token, :parselist)}})
    ustrings = plist.parselist .|> lexemeurn .|> string
    ids = [replace(s, r"[^.]+\." => "") for s in ustrings]
    unique(ids)
end

"""Find all forms of a lexeme appearing in a list of parses."""
function tokensforlemma(id::AbstractString, parses) #::Vector{NamedTuple{(:token, :parselist)}})
    #@info("Work with $(id) and a $(typeof(parses))")

    parsesforid = filter(parses) do p
        #@info("Now get lexids for a $(p)")
        allids = lexids(p)
        id in allids
    end
    map(a -> a.token, parsesforid)
end

"""Find number of occurrences of a lexeme in a list of parses using a precomputed frequency dictionary."""
function lexcount(id::AbstractString, parses, occurrences) #::Vector{NamedTuple{(:token, :parselist)}}, occurrences::OrderedDict{SubString{String}, Int64})
    #@info("Find count for $(id)")
    tknsforid = tokensforlemma(id, parses)
    [occurrences[tkn] for tkn in tknsforid] |> sum
end


lexlabels = Tabulae.lexlemma_dict_remote()
function labellemm(id::AbstractString, dict = lexlabels)
    foliobase ="http://folio2.furman.edu/lewis-short/index.html?urn=urn:cite2:hmt:ls.markdown:"
    link = foliobase * id

    keystring = string("ls.", id)
	key2 = string("lsx.", id)
    if haskey(dict, (keystring))
        #string(id, " (", dict[keystring], ")")
        string(dict[keystring], " ([",id, "](", link, "))" )
	elseif haskey(dict, key2)
		# string(id, " (", dict[key2], ")")
        string(dict[key2], " ([",id, "](", link, "))" )
    else
        keystring * " (?)"
        string(keystring * " ([",id, "](", link, "))" )
    end
end


@info(labellemm("n50664"))

function getlexcounts(idlist, parselist, freqsdict )
	lexcountsall = OrderedDict()
	map(idlist) do lsid
    	readable = labellemm(lsid)
    	numoccurrences = lexcount(lsid, parselist, freqsdict) 
    	lexcountsall[readable] = numoccurrences
	end
	sort!(lexcountsall; rev=true, byvalue = true)
end



function getrawlexcounts(idlist, parselist, freqsdict )
	lexcountsall = OrderedDict()
	map(idlist) do lsid
    	
    	numoccurrences = lexcount(lsid, parselist, freqsdict) 
    	lexcountsall[lsid] = numoccurrences
	end
	sort!(lexcountsall; rev=true, byvalue = true)
end





idvals = successes .|> lexids |> Iterators.flatten |> collect |> unique
@time lexcounts = getlexcounts(idvals, successes, counts)
@time rawlexcounts = getrawlexcounts(idvals, successes, counts)


lexcountcex = []
for k in keys(rawlexcounts) 
    msg = string(k, "|", rawlexcounts[k])
    push!(lexcountcex, msg)
end
open("lexemecounts.cex", "w") do io
    write(io, join(lexcountcex, "\n"))
end


function tablerows(dict, n; totalcount = totallex)
	intro = """#### Coverage for $(n) most frequent words\n\n(Links are to articles in on-line Lewis-Short *Dictionary*.)"""
	tblhdr = "| Rank | Lexeme | Occurrences | Running total | Running percent |\n| --- | --- | --- | --- | --- |\n"
	runningcount = 0
	rank = 0
	rows = map(collect(keys(dict))[1:n]) do k
		rank = rank + 1
		runningcount = runningcount + dict[k]
		pct = round((runningcount / totalcount) * 100; digits = 1)
		string("| ",rank, " | ",  k, " | ", dict[k] , " | " , runningcount, "  |  $(pct) ", " |")
	end
	intro * tblhdr * join(rows, "\n")
end


function runningtotals(orderedfreqs)
	runningdict = OrderedDict()
	runningtotal = 0
	for k in keys(orderedfreqs)
		runningtotal = runningtotal + orderedfreqs[k]
		runningdict[k] = runningtotal
	end
	runningdict
end


function rnngpct(runningdict; max = totallex)
	keylist = collect(keys(runningdict))
	rnngpctdict = OrderedDict()
	for k in 	keylist	
		pct = round((runningdict[k] / max) * 100, digits = 1)
		#@info("$(k): pct is $(pct)")
		#@info("from $(runningdict[k])) / $(max)")
		rnngpctdict[k] = pct
	end
	rnngpctdict
end


totallex = length(lex)
runningtotaldict = runningtotals(lexcounts)
runningtotalpct = rnngpct(runningtotaldict)



xs = collect(keys(runningtotaldict))
ys = collect(values(runningtotaldict))
pctys = collect(values(runningtotalpct))


CairoMakie.activate!()

tickspots = [20000,40000,60000,80000]
figx = Figure()
ax1 = Axis(figx[2, 1],
    title = "Coverage (number of words)",
    ylabel = "Words in text",
    xlabel = "Number of vocabulary items",
    yticks = (tickspots, format.(tickspots; commas=true))
)

lines!(ax1, 1:length(ys), ys)
lines!(ax1, 1:length(ys), map(n -> totallex, 1:length(ys)); color = :tomato, linestyle = :dot )

ax2 = Axis(figx[1, 1],
    title = "Coverage  (percent of text)",
    ylabel = "Percent of text",
    xlabel = "Number of vocabulary items",
)
lines!(ax2, 1:length(pctys), pctys)
lines!(ax2, 1:length(ys), map(n -> 100, 1:length(pctys)); color = :tomato, linestyle = :dot )	

figx

save("coverage.png", figx)

distincttokens = length(counts)




## SET THIS:
n = 200


summarytable = """## Augustine, *Confessions*

| Feature | Count |
| --- | --- |
| number of words (lexical tokens) |  **$(totallex)** |
| number of forms | **$(distincttokens)** |
| number of forms  appearing more than once | **$(length(repeatvocab))** |


## Vocabulary coverage


### Coverage by most frequent vocabulary items

![](./coverage.png)


$(tablerows(lexcounts, $(n)))
""" 




topN = idvals[1:n]
open("top$(n).txt", "w") do io
    write(io, join(topN, "\n"))
end


open("report.md", "w") do io
    write(io, summarytable)
end