# Data structures

#
# • block(func) DONE
# • return_from(name, value=nothing) DONE
# • available_restart(name)
# • invoke_restart(name, args...) DONE
# • restart_bind(func, restarts...) DONE
# • error(exception::Exception) DONE
# • handler_bind(func, handlers...) DONE


# Functions


# block function
# Hints: does not need to throw Exception of throwable. It gives freedom to throw other things


struct ReturnFromException <: Exception
    func::Function
    value::Any
    handlers_counter::Int
    inside_handler::Bool
end

function block(f)
    try
        f(f)
    catch e
        if typeof(e) == ReturnFromException
            if f === e.func
                # if e.inside_handler
                #     println(e.handlers_counter)
                #     println(handlersG)
                #     # for i in  1: (e.handlers_counter)
                #     #     pop!(handlersG)
                #     # end
                # end
                e.value
            # else
            #     if e.inside_handler
            #         throw(ReturnFromException(e.func,e.value, e.handlers_counter + 1, true))
            #     else
            #         throw(e)
            #     end
            end
        else
            throw(e)
        end
    end
end

function return_from(func, value = nothing)
    throw(ReturnFromException(func,value, 0, false))
end

# Tunned example from project spec

# mystery(n) =
#     1 +
#     block() do outer
#         1 +
#         block() do inner
#             1 +
#             block() do innerx2
#                 1 +
#                 if n == 0
#                     return_from(inner,11)
#                 elseif n == 1
#                     return_from(outer,1)
#                 else
#                     return_from(innerx2,2)
#                 end
#             end
#         end
#     end
# end


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
end

mystery(0)
mystery(1)
mystery(2)

# println("lelelel")

import Base.error

function error(ex)
    # try
        return signal(ex)
    # catch e
    #     # println("error catch")
    #     # println(e)
    #     # println(typeof(e))
    #     if isa(e,ReturnFromException)
    #         throw(ReturnFromException(e.func,e.value, 1, true))
    #     else
    #         throw(e)
    #     end
    # end
end

reciprocal(x) =
  x == 0 ?
    error(DivisionByZero()) :
    1/x

struct DivisionByZero <: Exception end

# Base.showerror(io::IO, e::DivisionByZero) = print(io, e.msg)

dict = Dict()


handlersG = []

function handler_bind(func,handlers...)
    append!( handlersG, [handlers] )
    # println("handler_bind handlers")
    # println(handlersG)
    # println(length(handlersG))
    asddd = Any
    try
        asddd = func()
    catch e
        # println("handler_bind catch")
        # println(e)
        # println(func)
        # println(typeof(e))
        # println("current handlers")
        # println(handlersG)
        # if isa(e,ReturnFromException)
            println("ATENCAO QUE vai popar")
            pop!(handlersG)
        # end
        throw(e)
    end
    println("pop esquisito")
    println(handlersG)
    pop!(handlersG)
    println(asddd)
    return asddd
    # return # This is to avoid returning the result of pop
end


function find_handler(e)
    # println("find_handler")
    for i in handlersG[end]
        if isa(e,i.first)
            # println("encontrou")
            return i.second
        end
    end
    # println("sem handlers")
    # println(e)
end

function signal(e)
    callback = find_handler(e)
    if callback != nothing
        callback(e)

        if length(handlersG) > 1
            # println("LETS POPPPPPINNNN 3")
            asd = pop!(handlersG)
            # println("BEFORE POPPPPPINNNN 3")
            try
                signal(e)
            catch ee
                println("lets redo the fucking operation")
                println(asd)
                # comment this sectipon very well
                append!(handlersG,[asd])
                # println(ee)
                throw(ee)
            end
        else
            println("LETS POPPPPPINNNN 2")
            # pop!(handlersG)
            println(e)
            println("BEFORE POPPPPPINNNN 2")
            throw(e)
        end
    else
        throw(e)
    end
end

# Testes

handler_bind(()->reciprocal(0), DivisionByZero =>(c)->println("I saw a division by zero"))


handler_bind(DivisionByZero =>
            (c)->println("I saw it too")) do
                handler_bind(DivisionByZero =>
                    (c)->println("I saw a division by zero")) do
                        reciprocal(0)
                    end
       end


block() do escape
    handler_bind(DivisionByZero =>
                    (c)->(println("I saw it too");
                        return_from(escape, "Done"))) do
            handler_bind(DivisionByZero =>
                        (c)->println("I saw a division by zero")) do
                        println("do caralho")
            reciprocal(0)
            println("ola")
        end
    end
end

block() do escape handler_bind(DivisionByZero =>
                        (c)->println("I saw it too")) do
                        handler_bind(DivisionByZero =>
                            (c)->(println("I saw a division by zero"); return_from(escape, "Done"))) do
                reciprocal(0)
           end
      end
end


# block() do escape handler_bind(DivisionByZero =>
#                         (c)->println("I saw it too")) do
#
#                         println("qqqqqq")
#                         block() do escape2 handler_bind(DivisionByZero =>
#                                                 (c)->println("I saw it too 2")) do
#                                                 handler_bind(DivisionByZero =>
#                                                     (c)->(println("I saw a division by zero"); return_from(escape, "Done"))) do
#                                         reciprocal(0)
#                                    end
#                               end
#                         end
#                         println("qqqqqq 2")
#
#       end
# end

struct InvokeRestartStructEx <: Exception
    func::Any
    args::Any
end


restart_bindings = Dict()

function restart_bind(func,args...)
    for i in args
        restart_bindings[i.first] = i.second
    end
    try
        func()
    catch a
        try
            println("segundo try")
            println(a)
            return signal(a)
        catch e
            println("segundo catch")
            println(e)
            if isa(e,InvokeRestartStructEx)
                println("a retornar valor")
                return e.func(e.args...)
            end
        end
    end
end

function invoke_restart(symbol, args...)
    throw(InvokeRestartStructEx(restart_bindings[symbol],args))
end



## EXEMPLO A BATER
#
# handler_bind(DivisionByZero => (c)->invoke_restart(:return_zero)) do
#   1 + reciprocal(0)
# end

## EXEMPLO A BATER



reciprocal(value) =
    restart_bind(:return_zero => ()->0,
             :return_value => identity,
             :retry_using => reciprocal) do
                value == 0 ? error(DivisionByZero()) : 1/value
    end



handler_bind(DivisionByZero => (c)->invoke_restart(:return_zero)) do
         1 + reciprocal(0) + 1 + 1
end


# Testes

println(restart_bindings)

handler_bind(DivisionByZero => (c)->invoke_restart(:return_zero)) do
         reciprocal(0)
end

handler_bind(DivisionByZero => (c)->invoke_restart(:return_value,123)) do
         reciprocal(0)
end

handler_bind(DivisionByZero => (c)->invoke_restart(:retry_using, 10)) do
  reciprocal(0)
end

println(restart_bindings)


function available_restart(name)
    return name in keys(restart_bindings)
end



handler_bind(DivisionByZero =>
        (c)-> for restart in (:return_one, :return_zero, :die_horribly)
                if available_restart(restart)
                    invoke_restart(restart)
                end
            end) do
        reciprocal(0)
    end


reciprocal(0)

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
