# Data structures

#
# • block(func) DONE
# • return_from(name, value=nothing) DONE
# • available_restart(name)
# • invoke_restart(name, args...)
# • restart_bind(func, restarts...)
# • error(exception::Exception) DONE
# • handler_bind(func, handlers...) DONE


# Functions


# block function
# Hints: does not need to throw Exception of throwable. It gives freedom to throw other things


struct ReturnFromException <: Exception
    func::Function
    value::Any
end

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

###############################
############ Tests ############
###############################

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
#
#
# mystery(n) =
#     1+
#     block() do outer
#         1+
#         block() do inner
#             1+
#             if n == 0
#                 return_from(inner, 1)
#             elseif n == 1 return_from(outer, 1)
#             else
#                 1
#             end
#         end
#     end
# end
#
# mystery(0)
# mystery(1)
# mystery(2)

###############################
############ Tests ############
###############################


import Base.error

function error(ex)
    throw(ex)
end

reciprocal(x) =
  x == 0 ?
    error(DivisionByZero()) :
    1/x

struct DivisionByZero <: Exception end

# Base.showerror(io::IO, e::DivisionByZero) = print(io, e.msg)

dict = Dict()

function handler_bind(func,handlers...)
    try
        func()
    catch e
        println("Handlers")
        println(handlers)
        for i in handlers
            # handler = i.second(i.second)
            handler = i.second(i.second)
            println(handler)
            if isa(e,i.first)
                if isa(handler,InvokeRestartStruct)
                    # println("lelelle")
                    # println(handler.second())
                    if isempty(handler.args)
                        return handler.func()
                    else
                        return handler.func(handler.args...)
                    end
                else
                    i.second(i)
                end
            end
        end
        rethrow()
    end
end
# Testes

# handler_bind(()->reciprocal(0), DivisionByZero =>(c)->println("I saw a division by zero"))
#
#
# handler_bind(DivisionByZero =>
#             (c)->println("I saw it too")) do
#                 handler_bind(DivisionByZero =>
#                     (c)->println("I saw a division by zero")) do
#                         reciprocal(0)
#                     end
#        end
#
#
# block() do escape
#     handler_bind(DivisionByZero =>
#                     (c)->(println("I saw it too"); return_from(escape, "Done"))) do
#                         handler_bind(DivisionByZero =>
#                                         (c)->println("I saw a division by zero")) do
#                         reciprocal(0)
#                         end
#     end
# end
#


struct InvokeRestartException <: Exception
    func::Function
    value::Any
end

restart_bindings = Dict()

function restart_bind(func,args...)
    for i in args
        restart_bindings[i.first] = i.second
    end
    func()
end


# This was kep a struct and not a type as imposed limitations described here:
# https://discourse.julialang.org/t/why-is-it-impossible-to-subtype-a-struct/19876/27

struct InvokeRestartStruct
    func::Any
    args::Any
end

function invoke_restart(symbol, args...)
    asd = InvokeRestartStruct(restart_bindings[symbol],args)
    asd
end

reciprocal(value) =
    restart_bind(:return_zero => ()->0,
             :return_value => identity,
             :retry_using => reciprocal) do
             println(value)
                value == 0 ? error(DivisionByZero()) : 1/value
    end


handler_bind(DivisionByZero => (c)->invoke_restart(:return_zero)) do
         reciprocal(0)
end

handler_bind(DivisionByZero => (c)->invoke_restart(:return_value,123)) do
         reciprocal(0)
end

handler_bind(DivisionByZero => (c)->invoke_restart(:retry_using, 10)) do
  reciprocal(0)
end

invoke_restart(:return_zero).first
