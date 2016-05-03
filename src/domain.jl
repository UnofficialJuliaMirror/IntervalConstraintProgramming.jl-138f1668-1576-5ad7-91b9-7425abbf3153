type Domain
    num_variables::Int
    constraint_expressions::Vector{Expr}
    contractors::Vector{Function}
    inputs::Vector{Vector{Int}}  # which variables are inputs of constructor i
    variable_list::Dict{Symbol, Int64}  # all the variables used in the constructors -- where are they in the list
    variables::Vector{Interval{Float64}}
end

Domain() = Domain(0, Expr[], Function[], Vector{Int}[], Dict{Symbol,Int64}(),
                Interval{Float64}[])

function input_number(d::Domain, x::Symbol)
    if haskey(d.variable_list, x)
        return d.variable_list[x]
    end

    d.num_variables += 1
    d.variable_list[x] = d.num_variables

end

doc"""Usage:
```
d = Domain()
add_constraint(d, :(x^2 + y^2 <= 1))
Use @add_constraint for nicer syntax
```
"""
function add_constraint(d::Domain, C::Expr)

    expr, constraint = parse_comparison(C)
    vars, code = forward_backward(expr, constraint)

    push!(d.constraint_expressions, C)
    push!(d.contractors, eval(make_function(vars, code)))
    push!(d.inputs, [input_number(d, var) for var in vars])
end

doc"""Usage:
```
d = Domain()
@add_constraint d x^2 + y^2 <= 1
```
"""
macro add_constraint(d, C)
    C = Meta.quot(C)
    :(add_constraint($(esc(d)), $C))
end


function initialize(d::Domain)
    d.variables = [entireinterval(Float64) for i in 1:d.num_variables]
end

function apply_contractor(d::Domain, i)
    which = d.inputs[i]
    d.variables[which] = [d.contractors[i](d.variables[which]...)...]
end

function apply_all_contractors(d::Domain)
    for i in 1:length(d.contractors)
        apply_contractor(d, i)
    end
end
