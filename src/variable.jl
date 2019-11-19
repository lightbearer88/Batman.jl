using DataFrames

abstract type Variable end

mutable struct Parameter <: Variable
  name::String
  info::String
  min::Float64
  max::Float64
  init::Float64
  units::String
  constant::Bool
  # Post fit information
  fit::Float64
  low::Float64
  high::Float64
  likelihood_x::Array{Float64}
  likelihood_y::Array{Float64}
  function Parameter( name::String; info::String="", min::Float64=-Inf,
                      max::Float64=Inf, init::Float64=0.0, units::String="", 
                      constant=false )
    new( name, info, min, max, init, units, constant,
         0.0, 0.0, 0.0,
         Array{Float64}(undef, 0),
         Array{Float64}(undef, 0),
       )
  end
end

struct Dataset <: Variable
  name::String
  init::String
  constant::Bool
  #init::Symbol
  function Dataset( name::String ; info::String="" )
    new( name, name, true )
  end
end

function add_dataset(name, df::DataFrame)
  eval(:( $name = $df ) )
end

mutable struct NLogPDF 
  func::String
  params::Array{Variable}
  function NLogPDF(f::String, p::Variable...)
    new(f, [p...])
  end
end

# todo, move macros
macro addfunction(f)
  :($f)
end

macro dataset( name, df )
  :( $(esc(name)) = $df )
end

mutable struct NLogLikelihood
  objective::Function
  numparams::Int64
  variableList
  parameters
  function NLogLikelihood(pf::Array{NLogPDF})
    var_list = []
    for p in pf
      for v in p.params
        push!(var_list, v)
      end
    end
    vv = unique(var_list)
    params = [v for v in vv if v.constant == false]
    nparams = length(params)
    npdf = length(pf)
    matches = []
    for (idx, p) in enumerate(pf)
      match = []
      for v in p.params
        loc = findlast(x->x==v, params)
        push!(match, loc)
      end
      push!(matches, match)
    end
    seval = ""
    for (idx, p) in enumerate(pf)
      a = matches[idx]
      name = pf[idx].func
      seval *= "$name("
      for (i,v) in zip(a, p.params)
        if v.constant
          val_use = v.init
          seval *= "$val_use,"
        else
          seval *= "x[$i],"
        end
      end
      seval *= ") +"
    end
    seval = seval[1:end-1]
    @show seval
    ff = eval(Meta.parse("x->"*seval))
    new(ff, nparams, vv, params)
  end
end

function optimize_model!(n::NLogLikelihood)
  function objective(x::Vector, grad::Vector)
    if length(grad)>0
      grad = 2x
    end
    n.objective(x)
  end
  opt = Opt(:LN_SBPLX, n.numparams)
  opt.ftol_rel = 1e-4
  opt.min_objective = objective
  p0 = [v.init for v in n.parameters]
  (minf, minx, ret) = optimize!(opt, p0)

  #Results( opt, I
  return minf, minx, ret
end
