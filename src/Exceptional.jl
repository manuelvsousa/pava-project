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
        typeof(e) == ReturnFromException && f === e.func ? e.value : throw(e)
    end
end

# Function    : return_from
# Description : throws ReturnFromException, created to go up the call chain
#               and alert a block() when a return_from is called
# Arguments   : func -> function of the exit point which identifies a block().
#               value -> value to be returned by the corresponding block
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
# Arguments   : func -> a function (or code in this context)
#               value -> list of handlers to associated with arg func
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
# Arguments   : e -> exception to search in handlers_stack
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
# Arguments   : e -> exception to handle
# Description : Recursive function to propagate a signal through all the interested handlers
#               It is responsible to update handlers_stack, keeping the correct context stack
#               between recursive calls, restoring it before throwing back to [handler,restart]_bind
function signal(e)
    callback = find_handler(e)
    if callback != nothing
        # This callback can call a return_from or invoke_restart, which will throw the corresponding Exception
        # We do not try-catch this callback here as a design choise, thus, all exceptions will be thrown to
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
            throw(e)
        end
    else
        throw(e)
    end
end


# Function    : restart_bind
# Arguments   : func ->  function (or code in this context)
#             : restart_functions ->  list of restart functions to associated with arg func
# Description : This function has a similiar behaviour as handler_bind, first executing the func code
#               and waiting for exceptions to be thrown. If something is catched, it will signal the Exception to
#               call the atention of interested handlers. After signaling this function waits for possible
#               invoke restarts to be called, returning their execution to the regular program flow
#               It is also reaponsible to handle the context stack of restart functions from handler to handler
#               keeping the right stack to the right binding.
function restart_bind(func,restart_functions...)
    tmp = Dict()
    for i in restart_functions
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
                        # it reached the top of the call chain
                        # there are no more restart_bind calls, meaning the restart function does not exist
                        throw(NoRestartExistException())
                    else
                        # lets throw it again, to move up in the call chain
                        # another restart_bind might have the restart function defined
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


# Function    : invoke_restart
# Arguments   : symbol ->  a symbol to identify a restart function
#             : args ->  list of args of the "symbol" restart function
# Description : Throws an Invoke Restart Exception so it can be distinguished
#               along the call chain. Contains the necessary information to identify
#               and get the restart function from the restarts stack
function invoke_restart(symbol, args...)
    throw(InvokeRestartException(symbol,args))
end


# Function    : available_restart
# Arguments   : name -> name of the restart function to search
# Description : This function go through all available restarts for a certain context
#               and returns a boolean it (arg name) is available
#               It assumes the restarts_stack is providing the correct restarts context.
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
