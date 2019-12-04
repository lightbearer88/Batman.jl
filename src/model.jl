abstract type Model end

mutable struct Results
  opt
  model::Model
  min_objective::Float64
  min_parameters::Array{Float64}
  iterations::Int64
  lower_bounds::Array{Float64}
  upper_bounds::Array{Float64}
end

## Generic model functions
function optimize_model!(m::Model, nll::NLogLikelihood; 
                         lower_bounds=nothing, upper_bounds=nothing)
  function objective(x::Vector, grad::Vector)
    if length(grad)>0
      grad = 2x
    end
    nll.objective(x)
  end
  opt = Opt(:LN_SBPLX, nll.numparams)
  # A note here on tolerence. With nlopt one can specify four
  # types of tolerence for a stopping condition. Either on the
  # value of the objective function, or on the values of the parameters.
  # For both of these it can be relative to the scale of each, or
  # absolute. For simplicity I have forced in tolerance on the objective
  # function at an absolute scale. This is because I am assuming that
  # the function is a log-likelihood, and thus has statistical information
  # in its derivative, but may be shifting by a constant NOT a scale factor.
  opt.ftol_abs = 1e-6
  opt.lower_bounds = nll.lower_bounds
  opt.upper_bounds = nll.upper_bounds
  opt.min_objective = objective
  p0 = [v.init for v in nll.parameters]
  (minf, minx, ret) = optimize!(opt, p0)
  numevals = opt.numevals
  for (i,p) in enumerate(m.params)
    p.fit = minx[i]
  end
  Results( opt, m, copy(minf), copy(minx), numevals,
           copy(opt.lower_bounds), copy(opt.upper_bounds) )
end

function getparam(m::Model, name::String)
  for (i, p) in enumerate(m.params)
    if p.name == name
      return p
    end
  end
  return nothing
end

function add_likelihood!( m::Model, nll::NLogLikelihood )
  m.nll = nll
  m.params = nll.parameters
end
