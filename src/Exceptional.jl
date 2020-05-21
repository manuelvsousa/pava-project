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

function return_from(func, value = nothing)
    throw(ReturnFromException(func,value))
end

function error(ex)
    try
        return signal(ex)
    catch e
        # If I am seeing the same exception I had signaled before,
        # means none of the handlers were able to handle it
        # So, I will just print the message as described in project spec
        # and throw it in the end
        if isa(e,typeof(ex))
            print("ERROR: ")
            print(e)
            println(" was not handled.")
        end
        throw(e)
    end
end

reciprocal(x) =
  x == 0 ?
    error(DivisionByZero()) :
    1/x

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

function signal(e)
    callback = find_handler(e)
    if callback != nothing
        # This callback can perfectly throw a return_from or invoke_restart
        # We do not try-catch this callback here as a design choise, thus, all exceptions will be sent to
        # the corresponding [handler,restart]_bind functions which might trigger different actions
        # such as poping the restart/handler stacks
        callback(e)
        if length(handlers_stack) > 1
            poped = pop!(handlers_stack)
            # fds = pop!(restarts_stack)
            try
                signal(e)
            catch ee
                append!(handlers_stack,[poped])
                # append!(restarts_stack,[fds])
                throw(ee)
            end
        else
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
