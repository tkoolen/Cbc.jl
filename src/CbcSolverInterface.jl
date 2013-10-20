module CbcMathProgSolverInterface

using Cbc.CoinMPInterface

require(joinpath(Pkg.dir("MathProgBase"),"src","MathProgSolverInterface.jl"))
importall MathProgSolverInterface


export CbcMathProgModel,
    CbcSolver,
    model,
    loadproblem,
    writeproblem,
    updatemodel,
    setsense,
    getsense,
    numvar,
    numconstr,
    setvartype,
    optimize,
    status,
    getobjval,
    getobjbound,
    getsolution,
    getrawsolver


type CbcMathProgModel <: AbstractMathProgModel
    inner::CoinProblem
end

immutable CbcSolver <: AbstractMathProgSolver
    options 
end
CbcSolver(;kwargs...) = CbcSolver(kwargs)


function CbcMathProgModel(;options...)
    c = CoinProblem()
    setOption(c, "LogLevel", 0)
    for (optname, optval) in options
        setOption(c, string(optname), optval)
    end
    return CbcMathProgModel(c)
end

model(s::CbcSolver) = CbcMathProgModel(;s.options...)

loadproblem(m::CbcMathProgModel, A, collb, colub, obj, rowlb, rowub) =
    LoadMatrix(m.inner, 1, 0.0, obj, collb, colub, rowlb, rowub, A)

function writeproblem(m::CbcMathProgModel, filename::String)
    if endswith(filename,".mps")
        WriteFile(m.inner, 3, filename)
    else
        error("Only MPS output supported")
    end
end

updatemodel(m::CbcMathProgModel) = nothing

function setsense(m::CbcMathProgModel,sense)
    if sense != :Min
        error("Only minimization sense currently supported")
    end
end

getsense(m::CbcMathProgModel) = :Min

numvar(m::CbcMathProgModel) = GetColCount(m.inner)
numconstr(m::CbcMathProgModel) = GetRowCount(m.inner)

function setvartype(m::CbcMathProgModel,vartype)
    ncol = numvar(m)
    @assert length(vartype) == ncol
    coltype = Array(Uint8,ncol)
    for i in 1:ncol
        @assert vartype[i] == 'I' || vartype[i] == 'C'
        coltype[i] = vartype[i]
    end
    LoadInteger(m.inner,coltype)
end

optimize(m::CbcMathProgModel) = OptimizeProblem(m.inner)

function status(m::CbcMathProgModel)
    stat = GetSolutionText(m.inner)
    # CoinMP status reporting is faulty,
    # add logic from CbcModel.cpp.
    objval = GetObjectValue(m.inner)
    if stat == "Optimal solution found" 
        if objval < 1e30
            return :Optimal
        else
            return :Infeasible
        end
    elseif stat == "Problem primal infeasible"
        return :Infeasible
    elseif stat == "Problem dual infeasible" # what does this mean for MIP??
        return :Unbounded
    elseif stat == "Stopped on iterations" || stat == "Stopped by user"
        return :UserLimit
    elseif stat == "Stopped due to errors"
        return :Error
    else
        error("Internal library error")
    end
end

getobjval(m::CbcMathProgModel) = GetObjectValue(m.inner)

getobjbound(m::CbcMathProgModel) = GetMipBestBound(m.inner)

getsolution(m::CbcMathProgModel) = GetSolutionValues(m.inner)

getrawsolver(m::CbcMathProgModel) = m.inner

end
