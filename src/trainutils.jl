
"""
    linearRadius(initRadius::Float64, iteration::Int64, decay::String, epochs::Int64)

Return a neighbourhood radius. Use as the `radiusFun` parameter for `trainGigaSOM`.

# Arguments
- `initRadius`: Initial Radius
- `finalRadius`: Final Radius
- `iteration`: Training iteration
- `epochs`: Total number of epochs
"""
function linearRadius(initRadius::Float64, finalRadius::Float64,
                      iteration::Int64, epochs::Int64)

    scaledTime = scaleEpochTime(iteration,epochs)
    return initRadius*(1-scaledTime) + finalRadius*scaledTime
end


"""
    expRadius(steepness::Float64)

Return a function to be used as a `radiusFun` of `trainGigaSOM`, which causes
exponencial decay with the selected steepness.

Use: `trainGigaSOM(..., radiusFun = expRadius(0.5))`

# Arguments
- `steepness`: Steepness of exponential descent. Good values range
  from -100.0 (almost linear) to 100.0 (really quick decay).

"""
function expRadius(steepness::Float64 = 0.0)
    return (initRadius::Float64, finalRadius::Float64,
            iteration::Int64, epochs::Int64) -> begin

        scaledTime = scaleEpochTime(iteration,epochs)

        if steepness < -100.0
            # prevent floating point underflows
            error("Sanity check: steepness too low, use linearRadius instead.")
        end

        # steepness is simulated by moving both points closer to zero
        adjust = finalRadius * (1 - 1.1^(-steepness))

        if initRadius <= 0 || (initRadius-adjust) <= 0 || finalRadius <= 0
            error("Radii must be positive. (Possible alternative cause: steepness is too high.)")
        end

        initRadius -= adjust
        finalRadius -= adjust

        return adjust + initRadius * ((finalRadius/initRadius)^scaledTime)
    end
end


"""
    gridRectangular(xdim, ydim)

Create coordinates of all neurons on a rectangular SOM.

The return-value is an array of size (Number-of-neurons, 2) with
x- and y- coordinates of the neurons in the first and second
column respectively.
The distance between neighbours is 1.0.
The point of origin is bottom-left.
The first neuron sits at (0,0).

# Arguments
- `xdim`: number of neurons in x-direction
- `ydim`: number of neurons in y-direction
"""
function gridRectangular(xdim, ydim)

    grid = zeros(Float64, (xdim*ydim, 2))
    for ix in 1:xdim
        for iy in 1:ydim

            grid[ix+(iy-1)*xdim, 1] = ix-1
            grid[ix+(iy-1)*xdim, 2] = iy-1
        end
    end
    return grid
end


"""
    gaussianKernel(x, r::Float64)

Return the value of normal distribution PDF (σ=`r`, μ=0) at `x`
"""
function gaussianKernel(x, r::Float64)

    return Distributions.pdf.(Distributions.Normal(0.0,r), x)
end

function bubbleKernelSqScalar(x::Float64, r::Float64)
    if x >= r
        return 0
    else
        return sqrt(1 - x/r)
    end
end


"""
    bubbleKernel(x, r::Float64)

Return a "bubble" (spherical) distribution kernel.

"""
function bubbleKernel(x, r::Float64)
    return bubbleKernelSqScalar.(x.^2,r^2)
end

"""
    thresholdKernel(x, r::Float64)

Simple FlowSOM-like hard-threshold kernel
"""
function thresholdKernel(x, r::Float64, maxRatio=1/3, zero=1e-6)
    if r >= maxRatio*maximum(x) #prevent smoothing everything to a single point
        r = maxRatio*maximum(x)
    end
    return zero.+(x.<=r)
end

"""
    distMatrix(grid::Array, toroidal::Bool)::Array{Float64, 2}

Return the distance matrix for a non-toroidal or toroidal SOM.

# Arguments
- `grid`: coordinates of all neurons as generated by one of the `grid-`functions
with x-coordinates in 1st column and y-coordinates in 2nd column.
- `toroidal`: true for a toroidal SOM.
"""
function distMatrix(metric)
    return (grid::Matrix{Float64}) -> begin
        n = size(grid,1)
        dm = zeros(Float64, n, n)

        for i in 1:n
            for j in 1:n
                dm[i,j] = metric(grid[i,:], grid[j,:])
            end
        end

        return dm::Matrix{Float64}
    end
end

"""
    normTrainData(train::Array{Float64, 2}, norm::Symbol)

Normalise every column of training data.

# Arguments
- `train`: DataFrame with training Data
- `norm`: type of normalisation; one of `minmax, zscore, none`
"""
function normTrainData(train::Array{Float64, 2}, norm::Symbol)

    normParams = zeros(2, size(train,2))

    if  norm == :minmax
        for i in 1:size(train,2)
            normParams[1,i] = minimum(train[:,i])
            normParams[2,i] = maximum(train[:,i]) - minimum(train[:,i])
        end
    elseif norm == :zscore
        for i in 1:size(train,2)
            normParams[1,i] = mean(train[:,i])
            normParams[2,i] = std(train[:,i])
        end
    else
        for i in 1:size(train,2)
            normParams[1,i] = 0.0  # shift
            normParams[2,i] = 1.0  # scale
        end
    end

    # do the scaling:
    if norm == :none
        x = train
    else
        x = normTrainData(train, normParams)
    end

    return x, normParams
end


"""
    convertTrainingData(data)::Array{Float64,2}

Converts the training data to an Array of type Float64.

# Arguments:
- `data`: Data to be converted

"""
function convertTrainingData(data)::Array{Float64,2}
    if typeof(data) != Matrix{Float64}
        try
            train = convert(Matrix{Float64}, data)
        catch ex
            Base.showerror(STDERR, ex, backtrace())
            error("Unable to convert training data to Array{Float64,2}!")
        end
    else
        train = data
    end

    return train
end
