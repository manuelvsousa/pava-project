# Data structures

#
# • block(func)
# • return_from(name, value=nothing)
# • available_restart(name)
# • invoke_restart(name, args...)
# • restart_bind(func, restarts...)
# • error(exception::Exception)
# • handler_bind(func, handlers...)


# Functions


# block function
# Hints: does not need to throw Exception of throwable. It gives freedom to throw other things


struct ReturnFromException <: Exception
    func::Function
    value::Int
end

function block(f)
    try
        println("block")
        f(f)
    catch e
        f === e.func ? e.value : throw(e)
    end
end

function return_form(func, value = nothing)
    throw(ReturnFromException(func,value))
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
#                     return_form(inner,11)
#                 elseif n == 1
#                     return_form(outer,1)
#                 else
#                     return_form(innerx2,2)
#                 end
#             end
#         end
#     end
# end

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

function handler_bind(func,args...)
    try
        func()
    catch e
        for i in args
            if  isa(e,i.first)
                i.second(i)
            end
        end
        rethrow()
    end
end


handler_bind(()->reciprocal(0), DivisionByZero =>(c)->println("I saw a division by zero"))


handler_bind(DivisionByZero =>
            (c)->println("I saw it too")) do
                handler_bind(DivisionByZero =>
                    (c)->println("I saw a division by zero")) do
                        reciprocal(0)
                    end
       end
