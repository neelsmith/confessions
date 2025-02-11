using CitableBase, CitableText, CitableCorpus
using Downloads, Markdown

localparser = true

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

tabulaerepo = joinpath(dirname(pwd()), "Tabulae.jl")
isdir(tabulaerepo)


function getparser(localparser::Bool = localparser; tabulae = tabulaerepo)
    if localparser
        parserfile = joinpath(tabulae, "scratch", "confessions-current.cex")
        stringParser(parserfile, FileReader)
    else
        tabulaeurl = "http://shot.holycross.edu/morphology/confessions-current.cex"
        stringParser(tabulaeurl, UrlReader)
    end
end



function collectfails(p, words)
    fails = []
    for (i, wd) in enumerate(words)
        if mod(i, 25) == 0
            @info("$(i)/$(length(words))")
        end
        reslts = parsetoken(lowercase(wd), parser)
        if isempty(reslts)
            @warn("Failed to parse $(wd)")
            push!(fails, wd)
        end
    end
    fails
end


function writefailcounts(badlist, countdict; fname = "fails.cex")
    failsfreqs = map(badlist) do s
        string(s, "|", countdict[s])
    end
    open(fname, "w") do io
        write(io, join(failsfreqs,"\n"))
    end
end




wordlist = collect(keys(counts))
testlist = wordlist[1:5000]

@time parser = getparser(true)
#parsetoken("codex", parser)

@time fails = collectfails(parser, testlist)
writefailcounts(fails, counts)

@time allfails = collectfails(parser, wordlist)
writefailcounts(allfails, counts; fname = "fails-all.cex")



nonsingletons = filter(counts) do (k,v)
    v > 1
end
repeatvocab = keys(nonsingletons) |> collect
@info("Number of repeated tokens: $(length(repeatvocab))")


vocab = collect(keys(counts))

filter(w -> startswith(w, "Ies"), vocab)




@time parses = map(repeatvocab) do wrd
    (token = wrd, parselist = parsetoken(wrd, parser))
end

successes = filter(parses) do tpl
    ! isempty(tpl.parselist)
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

function lexids(plist::Vector{NamedTuple{(:token, :parselist)}})
    ustrings = plist.parselist .|> lexemeurn .|> string
    ids = [replace(s, r"[^.]+\." => "") for s in ustrings]
    unique(ids)
end


idvals = successes .|> lexids |> Iterators.flatten |> collect |> unique

lexcounts = []

#=
Given lexeme:
find all analyzed tokens
find count for token
=#
function tokensforlemma(id::AbstractString, parses::Vector{NamedTuple{(:token, :parselist)}})
    #@info("Work with $(id) and a $(typeof(parses))")

    parsesforid = filter(parses) do p
        #@info("Now get lexids for a $(p)")
        allids = lexids(p)
        id in allids
    end
    map(a -> a.token, parsesforid)
end

function lexcount(id::AbstractString, parses::Vector{NamedTuple{(:token, :parselist)}}, occurrences::OrderedDict{SubString{String}, Int64})
    @info("Find count for $(id)")
    tknsforid = tokensforlemma(id, parses)
    [occurrences[tkn] for tkn in tknsforid] |> sum
    #tknsforid
end


lexcountsall = OrderedDict()
map(idvals[1:10]) do lsid
    readable = labellemm(lsid)
    numoccurrences = lexcount(lsid, successes, counts) 
    lexcountsall[readable] = numoccurrences
end

sort!(lexcountsall; rev=true, byvalue = true)
#@time lexfreqs = map(a -> lexcount(a.token, successes, counts), successes[1:100])


dicoid = "n13803"
lexcount("n13803", successes, counts)


lexcounts = countmap(idvals) |> OrderedDict
sort!(lexcounts; rev=true, byvalue=true)

lexlabels = Tabulae.lexlemma_dict_remote()
function labellemm(id::AbstractString, dict = lexlabels)
    keystring = string("ls.", id)
    key2 = string("lsx.", id)
    if haskey(dict, keystring)
        string(id, " (", dict[keystring], ")")
    elseif haskey(dict, key2)
        string(id, " (", dict[key2], ")")
    else
        keystring * " (?)"
    end
end

idlabels = [labellemm(s) for s in keys(lexcounts)]
keys(lexcounts) |> collect
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