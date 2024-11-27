this is the chain.jl with comments. DOES NOT CONTAIN STACK OR FORK.

module Chain

export @chain

is_aside(x) = false #retruns false if its just an arg 
is_aside(x::Expr) = x.head == :macrocall && x.args[1] == Symbol("@aside") # if its an expr and the head is of type @aside return true


# Returns an expression representing a function call with symbol and firstarg if symbol is of type Symbol.
# Calls insertionerror(any) if the input is not a Symbol, handling the invalid input.
insert_first_arg(symbol::Symbol, firstarg; assignment = false) = Expr(:call, symbol, firstarg) 
insert_first_arg(any, firstarg; assignment = false) = insertionerror(any)

function insertionerror(expr) #rertuns an error
    error(
        """Can't insert a first argument into:
        $expr.

        First argument insertion works with expressions like these, where [Module.SubModule.] is optional:

        [Module.SubModule.]func
        [Module.SubModule.]func(args...)
        [Module.SubModule.]func(args...; kwargs...)
        [Module.SubModule.]@macro
        [Module.SubModule.]@macro(args...)
        @. [Module.SubModule.]func
        """
    )
end


is_moduled_symbol(x) = false  #returns fasle on just a single arg
function is_moduled_symbol(e::Expr) # if criteria is met returns true and it must be inputed as an expr
    e.head == :. &&
        length(e.args) == 2 &&
        (e.args[1] isa Symbol || is_moduled_symbol(e.args[1])) &&
        e.args[2] isa QuoteNode &&
        e.args[2].value isa Symbol
end

function insert_first_arg(e::Expr, firstarg; assignment = false)
    head = e.head
    args = e.args

    # variable = ...
    # set assignment = true and rerun with right hand side
    if !assignment && head == :(=) && length(args) == 2
        if !(args[1] isa Symbol)
            error("You can only use assignment syntax with a Symbol as a variable name, not $(args[1]).")
        end
        variable = args[1]
        righthandside = insert_first_arg(args[2], firstarg; assignment = true)
        :($variable = $righthandside)
    # Module.SubModule.symbol
    elseif is_moduled_symbol(e)
        Expr(:call, e, firstarg)

    # f(args...) --> f(firstarg, args...)
    elseif head == :call && length(args) > 0
        if length(args) ≥ 2 && Meta.isexpr(args[2], :parameters)
            Expr(head, args[1:2]..., firstarg, args[3:end]...)
        else
            Expr(head, args[1], firstarg, args[2:end]...)
        end

    # f.(args...) --> f.(firstarg, args...)
    elseif head == :. &&
            length(args) > 1 &&
            args[1] isa Symbol &&
            args[2] isa Expr &&
            args[2].head == :tuple

        Expr(head, args[1], Expr(args[2].head, firstarg, args[2].args...))

    # @. [Module.SubModule.]somesymbol --> somesymbol.(firstarg)
    elseif head == :macrocall &&
            length(args) == 3 &&
            args[1] == Symbol("@__dot__") &&
            args[2] isa LineNumberNode &&
            (is_moduled_symbol(args[3]) || args[3] isa Symbol)

        Expr(:., args[3], Expr(:tuple, firstarg))

    # @macro(args...) --> @macro(firstarg, args...)
    elseif head == :macrocall &&
        (is_moduled_symbol(args[1]) || args[1] isa Symbol) &&
        args[2] isa LineNumberNode

        if args[1] == Symbol("@__dot__")
            error("You can only use the @. macro and automatic first argument insertion if what follows is of the form `[Module.SubModule.]func`")
        end

        if length(args) >= 3 && args[3] isa Expr && args[3].head == :parameters
            # macros can have keyword arguments after ; as well
            Expr(head, args[1], args[2], args[3], firstarg, args[4:end]...)
        else
            Expr(head, args[1], args[2], firstarg, args[3:end]...)
        end

    else
        insertionerror(e)
    end
end

function rewrite(expr, replacement)
    aside = is_aside(expr)
    if aside
        length(expr.args) != 3 && error("Malformed @aside macro")
        expr = expr.args[3] # 1 is macro symbol, 2 is LineNumberNode
    end

    had_underscore, new_expr = replace_underscores(expr, replacement)

    if !aside
        if !had_underscore
            new_expr = insert_first_arg(new_expr, replacement)
        end
        replacement = gensym()
        new_expr = :(local $replacement = $new_expr)
    end

    (new_expr, replacement)
end

rewrite(l::LineNumberNode, replacement) = (l, replacement)

function rewrite_chain_block(firstpart, block)
    pushfirst!(block.args, firstpart)
    rewrite_chain_block(block)
end


#this is the main macro which creates a block by calling function on the values 
macro chain(initial_value, args...)
    block = flatten_to_single_block(initial_value, args...) #creates a block with aarguements. deos not allow for blocks in blocks. just one big block with loads(maybe none) of arguments.
    rewrite_chain_block(block)# and then this function runs on block
end

#takes in a bunch of arguments and makes it into one big block. so no block of blocks.
function flatten_to_single_block(args...)
    blockargs = [] # makes an empty array
    for arg in args # for loop 
        if arg isa Expr && arg.head === :block # if the argument is an expr AND if the head of it is a block(bunch of code)
            append!(blockargs, arg.args)# add the argument's children / arguments at the end of the array one at a time
        else
            push!(blockargs, arg) #otherwise just push the argument to the list
        end
    end
    Expr(:block, blockargs...) #makes and returns a new expresion of type block that contains all the arguments from the list filled above.
end

function rewrite_chain_block(block) #takes a block, created from above
    block_expressions = block.args # makes a llist with each argument in the block
    isempty(block_expressions) || (length(block_expressions) == 1 && block_expressions[] isa LineNumberNode) && #checks if the list is empty, OR (it's length is one and at index one is just a LineNUmNOde) wehich is not actual code 
        error("No expressions found in chain block.") #if the left or the right of the above statement is met it hits the error. no expressions/ or argumets found

    reconvert_docstrings!(block_expressions) #if there is argumets we run this .

    # assign first line to first gensym variable
    firstvar = gensym()
    rewritten_exprs = []
    replacement = firstvar

    did_first = false
    for expr in block_expressions
        # could be an expression first or a LineNumberNode, so a bit convoluted
        # we just do the firstvar transformation for the first non LineNumberNode
        # we encounter
        #
        # so basically goes through the arguments and just changes the first non LineNUmberNode to the genreated variable. e.x : local #num123 = expresion1 and adds it to the array rewritten_expr, othereise skips the if block and goes to the function call below.
        if !(did_first || expr isa LineNumberNode)
            expr = :(local $firstvar = $expr)
            did_first = true
            push!(rewritten_exprs, expr)
            continue
        end

        rewritten, replacement = rewrite(expr, replacement) #call this function with the expresion that skiped the if above and with the replacement, and also saves what it gets in the two variables called rewritten and replacement. Does the replacement change after each iteration ??
        push!(rewritten_exprs, rewritten)
    end

    result = Expr(:block, rewritten_exprs..., replacement)

    :($(esc(result)))
end

# if a line in a chain is a string, it can be parsed as a docstring
# for whatever is on the following line. because this is unexpected behavior
# for most users, we convert all docstrings back to separate lines.
# basically takes an array and removes the @doc call and leaves the dockstrings and returns it asa n array
function reconvert_docstrings !(args::Vector) #takes in a 1D array(vector)
    # pattern matching? # finds all indices in the array wehre argument is an expresion and its head is a macrocall and of length 4 coz thats how long macros are, and starts with @doc. and stores this in an array
    docstring_indices = findall(args) do arg   
        (arg isa Expr
            && arg.head == :macrocall
            && length(arg.args) == 4
            && arg.args[1] == GlobalRef(Core, Symbol("@doc")))
    end
    # replace docstrings from back to front because this leaves the earlier indices intact
    for i in reverse(docstring_indices)
        e = args[i] 
        str = e.args[3] #argument 3 within the argument
        nextline = e.args[4] # argument 4 within the argument
        splice!(args, i:i, [str, nextline]) #remove i with str, nextLine??
    end
    args # returns the arguments as a vector filled with the new arguments
end

function replace_underscores(expr::Expr, replacement)
    found_underscore = false # boolean set at false

    # if a @chain macrocall is found, only its first arg can be replaced if it's an
    # underscore, otherwise the macro insides are left untouched
    #
    if expr.head == :macrocall && expr.args[1] == Symbol("@chain") # checks if its a macrocall and of type @cahin
        length(expr.args) < 3 && error("Malformed nested @chain macro") # checls if legnths if less than 3 then throws error
        expr.args[2] isa LineNumberNode || error("Malformed nested @chain macro") # if the 2nd arg is a line num node throw error
        arg3 = if expr.args[3] == Symbol("_") # if the 3rd arg of the expresion is an underscore it saves the underscore to be arg3. 
            found_underscore = true
            replacement
        else
            expr.args[3]# otherwise the 3rd argumetn is left as is left as it is.
        end
        newexpr = Expr(:macrocall, Symbol("@chain"), expr.args[2], arg3, expr.args[4:end]...) # new expreesion created of type macrocall adn chain and 
    # for all other expressions, their arguments are checked for underscores recursively
    # and replaced if any are found
    else
        newargs = map(x -> replace_underscores(x, replacement), expr.args)
        found_underscore = any(first.(newargs))
        newexpr = Expr(expr.head, last.(newargs)...)
    end
    return found_underscore, newexpr
end

function replace_underscores(x, replacement) 
    if x == Symbol("_")
        true, replacement # if x is an underscore it returns true and also its replacement
    else
        false, x #otherwise false and x itself
    end
end

end
