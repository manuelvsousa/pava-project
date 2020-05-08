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



mystery(n) =
    1 +
    block() do outer
        1 +
        block() do inner
            1 +
            block() do innerx2
                1 +
                if n == 0
                    return_form(inner,11)
                elseif n == 1
                    return_form(outer,1)
                else
                    return_form(innerx2,2)
                end
            end
        end
    end
end
