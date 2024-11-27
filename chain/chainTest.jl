import Pkg

Pkg.add("DataFrames")
Pkg.add("Chain")

using DataFrames, Chain

df = DataFrame(group = [1, 2, 1, 2, missing], weight = [1, 3, 5, 7, missing])

function adding(x::Vector{String})
    occurance = 0
    for i in x
       occurance = occurance + 1  
    end
    occurance
end


function countwrd(sent, find)
    @chain sent begin
        split(_)
        lowercase.(_)
        filter(z -> z == find, _)
        length()
    end
end

#get an array
#split it into two parts. the odd and even indexes
#map the nums to mod 2 
#
function split_odd_even(x::Vector{Int})
odds = Vector{Int64}()
even = Vector{Int64}()

    for i in 1:length(x)
        if i % 2 == 0
            push!(even, x[i])
        else
            push!(odds, x[i])
        end
    end

    return even, odds
end


function corrections(even::Vector{Int}, odds::Vector{Int})
    counter_Even = 0
    counter_Odd = 0

    for i in even
        if i % 2 != 0
            counter_Even = counter_Even + 1
        end
    end

    for s in odds
        if s % 2 == 0
            counter_Odd = counter_Odd + 1
        end
    end
    return counter_Even, counter_Odd
end


function isGood(x, y)

    if x == y && x != 0
        println("There can be " * string(x) * " swaps to make this a good Integer Vector")   
    else
        println("There can be NO swaps to make this a good Integer Vector")
    end
end

function example2(x::Vector{Int})
    @chain x begin
        split_odd_even(_) #reuturns two things, but it will pass it below as just one. how to fix this? add the second _. 
        corrections(_...)
        isGood(_...)
        
    end
end
