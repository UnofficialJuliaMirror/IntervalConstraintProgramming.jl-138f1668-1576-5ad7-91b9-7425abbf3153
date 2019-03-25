
"""
`Contractor` represents a `Contractor` from ``\\mathbb{R}^N`` to ``\\mathbb{R}^N``.
Nout is the output dimension of the forward part.
"""
struct Contractor{N, Nout, F1<:Function, F2<:Function, ex<:Union{Operation,Expr}}
    variables::Vector{Symbol}  # input variables
    forward::GeneratedFunction{F1}
    backward::GeneratedFunction{F2}
    expression::ex
end

function Contractor(variables::Vector{Symbol}, top, forward, backward, expression)

    # @show variables
    # @show top

    N = length(variables)  # input dimension

    local Nout  # number of outputs

    if isa(top, Symbol)
        Nout = 1

    elseif isa(top, Expr) && top.head == :tuple
        Nout = length(top.args)

    else
        Nout = length(top)
    end

    Contractor{N, Nout, typeof(forward.f), typeof(backward.f), typeof(expression)}(variables, forward, backward, expression)
end

function Base.show(io::IO, C::Contractor{N,Nout,F1,F2,ex}) where {N,Nout,F1,F2,ex}
    println(io, "Contractor in $(N) dimensions:")
    println(io, "  - forward pass contracts to $(Nout) dimensions")
    println(io, "  - variables: $(C.variables)")
    print(io, "  - expression: $(C.expression)")
end



function (C::Contractor{N,Nout,F1,F2,ex})(
    A::IntervalBox{Nout,T}, X::IntervalBox{N,T}) where {N,Nout,F1,F2,ex,T}

    output, intermediate = C.forward(X)

    # @show output
    # @show intermediate

    output_box = IntervalBox(output)
    constrained = output_box ∩ A

    # if constrained is already empty, eliminate call to backward propagation:

    if isempty(constrained)
        return emptyinterval(X)
    end

    # @show X
    # @show constrained
    # @show intermediate
    # @show C.backward(X, constrained, intermediate)
    return IntervalBox{N,T}(C.backward(X, constrained, intermediate) )

end

# allow 1D contractors to take Interval instead of IntervalBox for simplicty:

(C::Contractor{N,1,F1,F2,ex})(A::Interval{T}, X::IntervalBox{N,T}) where {N,F1,F2,ex,T} = C(IntervalBox(A), X)

(C::Contractor)(X::IntervalBox{T}) where {T} = C.forward(X)[1]



function Contractor(expr::Operation)

    top, linear_AST = flatten(expr)


    forward_code, backward_code  = forward_backward(linear_AST)


    # @show top

    if isa(top, Symbol)
        top = [top]
    end

    forward = eval(forward_code)
    backward = eval(backward_code)

    Contractor(linear_AST.variables,
                    top,
                    GeneratedFunction(forward, forward_code),
                    GeneratedFunction(backward, backward_code),
                    expr)

end





function Contractor(vars, expr::Operation)

    variables = [Symbol(var) for var in vars]

    @show variables

    top, linear_AST = flatten(expr)


    forward_code, backward_code  = forward_backward(variables, linear_AST)


    # @show top

    if isa(top, Symbol)
        top = [top]
    end

    forward = eval(forward_code)
    backward = eval(backward_code)

    Contractor(variables,
                    top,
                    GeneratedFunction(forward, forward_code),
                    GeneratedFunction(backward, backward_code),
                    expr)

end

Contractor(vars, expr) = Contractor(vars, Operation(expr))  # for single variables

function make_contractor(expr::Expr)
    # println("Entering Contractor(ex) with ex=$ex")
    # expr, constraint_interval = parse_comparison(ex)

    # if constraint_interval != entireinterval()
    #     warn("Ignoring constraint; include as first argument")
    # end


    top, linear_AST = flatten(expr)

    #  @show expr
    #  @show top
    #  @show linear_AST

    forward_code, backward_code  = forward_backward(linear_AST)


    # @show top

    if isa(top, Symbol)
        top = [top]

    elseif isa(top, Expr) && top.head == :tuple
        top = top.args

    end

    # @show forward_code
    # @show backward_code

    :(Contractor($(linear_AST.variables),
                    $top,
                    GeneratedFunction($forward_code, $(Meta.quot(forward_code))),
                    GeneratedFunction($backward_code, $(Meta.quot(backward_code))),
                    $(Meta.quot(expr))))

end



"""Usage:
```
C = @contractor(x^2 + y^2)
A = -∞..1  # the constraint interval
x = y = @interval(0.5, 1.5)
C(A, x, y)

`@contractor` makes a function that takes as arguments the variables contained in the expression, in lexicographic order
```

TODO: Hygiene for global variables, or pass in parameters
"""
macro contractor(ex)
    make_contractor(ex)
end
