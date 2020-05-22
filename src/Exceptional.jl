# Author1: Manuel Sousa (manuelvsousa@tecnico.ulisboa.pt)
# Course:  Advanced Programming 19-20, Second Semester

import Base.error

struct DivisionByZero <: Exception end
struct NoRestartExistException <: Exception end

struct ReturnFromException <: Exception
    func::Function
    value::Any
end

struct InvokeRestartException <: Exception
    name::Any
    args::Any
end

handlers_stack = []
restarts_stack = []

function block(f)
    try
        f(f)
    catch e
        println(typeof(f))
        typeof(e) == ReturnFromException && f === e.func ? e.value : throw(e)
    end
end

# Function    : return_from
# Description : throws ReturnFromException, created to go up the call chain
#               and alert a block() when a return_from is called
# Arguments   : func-> function of the exit point which identifies a block().
#               value-> value to be returned by the corresponding block
function return_from(func, value = nothing)
    throw(ReturnFromException(func,value))
end


# Function    : error
# Description : calls signal() function to spread the signal through the handlers
function error(ex)
    try
        return signal(ex)
    catch e
        # If I see the same exception I signaled before,
        # then none of the handlers were able to handle it
        if isa(e,typeof(ex))
            print("ERROR: ")
            print(e)
            println(" was not handled.")
        end
        throw(e)
    end
end



# Function    : handler_bind
# Arguments   : func-> a function (or code in this context)
#               value-> list of handlers to associated with arg func
# Description : This function executes the func arg code and waits for an exception
#               to be thrown by signal() (eg. ReturnFromException)
#               This function also makes proper handling of handlers_stack operations (handlers context)
#               appending handlers in the beggining of the execution, and poping them
#               when the handler returns, makes a non-local transfer of control or has to terminate
#               itself for other reasons (eg. unhandled exception)
function handler_bind(func,handlers...)
    append!( handlers_stack, [handlers] )
    return_object = Any
    try
        return_object = func()
    catch e
        pop!(handlers_stack)
        throw(e)
    end
    pop!(handlers_stack)
    return return_object
end


# Function    : find_handler
# Arguments   : e-> exception to search in handlers_stack
# Description : This function grabs the current handlers, and returns the proper one for the "e" exception.
#               It assumes the handlers_stack is providing the correct handlers context.
function find_handler(e)
    if isempty(handlers_stack)
        return nothing
    end
    for i in handlers_stack[end]
        if isa(e,i.first)
            return i.second
        end
    end
end


# Function    : signal
# Arguments   : e-> exception to handle
# Description : Recursive function to propagate a signal through all the interested handlers
#               It is responsible to update handlers_stack, keeping the correct handlers context
#               between recursive calls, restoring the context stack before throwing back to [handler,restart]_bind
function signal(e)
    callback = find_handler(e)
    if callback != nothing
        # This callback can call a return_from or invoke_restart, which will throw the corresponding Exception
        # We do not try-catch this callback here as a design choise, thus, all exceptions will be sent to
        # the corresponding [handler,restart]_bind which might want to trigger very specifc actions uppon receiving them
        callback(e)
        if length(handlers_stack) > 1
            poped = pop!(handlers_stack)
            try
                signal(e)
            catch ee
                append!(handlers_stack,[poped]) # restores context
                throw(ee)
            end
        else
            println("I would like to knwo when you are called")
            throw(e)
        end
    else
        throw(e)
    end
end

function restart_bind(func,args...)
    tmp = Dict()
    for i in args
        tmp[i.first] = i.second
    end
    append!(restarts_stack,[tmp])
    return_value = Any
    try
        return_value = func()
    catch a
        try
            signal(a)
        catch e
            if isa(e,InvokeRestartException) && !isempty(restarts_stack)
                if e.name ∉ keys(restarts_stack[end])
                    pop!(restarts_stack)
                    if isempty(restarts_stack)
                        throw(NoRestartExistException())
                    else
                        throw(e)
                    end
                else
                    return_value = restarts_stack[end][e.name](e.args...)
                end
            else
                pop!(restarts_stack)
                throw(e)
            end
        end
    end
    pop!(restarts_stack)
    return return_value
end

function invoke_restart(symbol, args...)
    throw(InvokeRestartException(symbol,args))
end



function available_restart(name)
    for i in restarts_stack
        if name in keys(i)
            return true
        end
    end
    return false
end



# TESTSTST
#
#
#
#
#
#
#

mystery(n) =
    1+
    block() do outer
        1+
        block() do inner
            1+
            if n == 0
                return_from(inner, 1)
            elseif n == 1 return_from(outer, 1)
            else
                1
            end
        end
    end

mystery(0)
mystery(1)
mystery(2)

reciprocal(x) =
  x == 0 ?
    error(DivisionByZero()) :
    1/x

try
    handler_bind(()->reciprocal(0), DivisionByZero =>(c)->println("I saw a division by zero"))
catch e

end

try
    handler_bind(DivisionByZero =>
                (c)->println("I saw it too")) do
                    handler_bind(DivisionByZero =>
                        (c)->println("I saw a division by zero")) do
                            reciprocal(0)
                        end
           end
catch e

end

try
    block() do escape
        handler_bind(DivisionByZero =>
                        (c)->(println("I saw it too");
                            return_from(escape, "Done"))) do
                handler_bind(DivisionByZero =>
                            (c)->println("I saw a division by zero")) do
                reciprocal(0)
            end
        end
    end
catch e

end

try
    block() do escape handler_bind(DivisionByZero =>
                            (c)->println("I saw it too")) do
                            handler_bind(DivisionByZero =>
                                (c)->(println("I saw a division by zero"); return_from(escape, "Done"))) do
                    reciprocal(0)
               end
          end
    end
catch e

end


reciprocal(value) =
    restart_bind(:return_zero => ()->0,
             :return_value => identity,
             :retry_using => reciprocal) do
                value == 0 ? error(DivisionByZero()) : 1/value
    end



handler_bind(DivisionByZero => (c)->invoke_restart(:return_zero)) do
         1 + reciprocal(0) + 1 + 1 + 1
end

handler_bind(DivisionByZero => (c)->invoke_restart(:return_zero)) do
  1 + reciprocal(0)
end

divide(x, y) = x*reciprocal(y)

handler_bind(DivisionByZero => (c)->invoke_restart(:return_value, 3)) do
  divide(2, 0)
end

# Testes


handler_bind(DivisionByZero => (c)->invoke_restart(:return_zero)) do
         reciprocal(0)
end

handler_bind(DivisionByZero => (c)->invoke_restart(:return_value,123)) do
         reciprocal(0)
end

handler_bind(DivisionByZero => (c)->invoke_restart(:retry_using, 10)) do
  reciprocal(0)
end



handler_bind(DivisionByZero =>
        (c)-> for restart in (:return_one, :return_zero, :die_horribly)
                if available_restart(restart)
                    invoke_restart(restart)
                end
            end) do
        reciprocal(0)
    end


infinity() =
    restart_bind(:just_do_it => ()->1/0) do
        reciprocal(0)
    end

handler_bind(DivisionByZero => (c)->invoke_restart(:return_zero)) do
    infinity()
end

handler_bind(DivisionByZero => (c)->invoke_restart(:return_value, 1)) do
  infinity()
end

handler_bind(DivisionByZero => (c)->invoke_restart(:retry_using, 10)) do
  infinity()
end

handler_bind(DivisionByZero => (c)->invoke_restart(:just_do_it)) do
  infinity()
end
