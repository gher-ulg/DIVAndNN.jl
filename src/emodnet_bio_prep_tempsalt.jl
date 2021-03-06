import DIVAnd
#using PyPlot
#using CSV
using NCDatasets
using Missings
using Interpolations
using Base.Threads

#include("emodnet_bio_grid.jl");

"""
    DIVAndNN.saveinterp((lon,lat),field,(gridlon,gridlat),varname,interp_fname)

Interpolate the field `field` defined over the grid `(lon,lat)`
on the grid `(gridlon,gridlat)`. The result is saved in the NetCDF files
`interp_fname` under the same `varname`.
`lon`, `lat`, `gridlon`, `gridlat` are all vectors.
"""
function saveinterp((lon,lat),SS2,(gridlon,gridlat),varname,interp_fname)
    @info "interpolate"
    itp = interpolate((lon,lat), SS2, Gridded(Linear()));
    SSi = itp(gridlon,gridlat);

    @show extrema(SSi)

    ds = Dataset(interp_fname,"c")
    # Dimensions

    ds.dim["lon"] = length(gridlon)
    ds.dim["lat"] = length(gridlat)

    # Declare variables

    nclon = defVar(ds,"lon", Float64, ("lon",))
    nclon.attrib["units"] = "degrees_east"
    nclon.attrib["standard_name"] = "longitude"
    nclon.attrib["long_name"] = "longitude"

    nclat = defVar(ds,"lat", Float64, ("lat",))
    nclat.attrib["units"] = "degrees_north"
    nclat.attrib["standard_name"] = "latitude"
    nclat.attrib["long_name"] = "latitude"

    ncvar = defVar(ds,lowercase(varname), Float32, ("lon", "lat"))
    ncvar.attrib["_FillValue"] = Float32(9.96921e36)
    ncvar.attrib["missing_value"] = Float32(9.96921e36)
    ncvar.attrib["long_name"] = varname


    # Define variables

    nclon[:] = gridlon
    nclat[:] = gridlat
    ncvar[:] = SSi

    close(ds)
end

function prep_tempsalt(gridlon,gridlat,data_TS,datadir; k_index = 1)


for (fname,varname,lvarname) in data_TS
    interp_fname = joinpath(datadir,"$(lowercase(lvarname)).nc")

    if isfile(interp_fname)
        @info("$interp_fname is already interpolated")
        continue
    end

    @show fname
    ds = Dataset(fname)
    S = ds[varname][:,:,k_index,:];

    lon = nomissing(coord(ds[varname],"longitude")[:])
    lat = nomissing(coord(ds[varname],"latitude")[:])

    #lon = nomissing(ds["lon"][:])
    #lat = nomissing(ds["lat"][:])
    SS = nomissing(S,NaN);
    close(ds)

    @info "skip time instance without data"
    mask = .!isnan.(SS);
    count = sum(sum(mask,dims=1),dims=2)[:]
    n = findall(count .> 0)
    SS = SS[:,:,n]
    mask = mask[:,:,n]

    @info "fill"
    SS = DIVAnd.ufill(SS,mask)
#=    Threads.@threads for k = 1:size(mask,3)
        @show k
        SS[:,:,k] = DIVAnd.ufill(SS[:,:,k],mask[:,:,k])
    end
=#
    @info "average"
    SS2 = mean(SS,dims = 3)[:,:,1]

    saveinterp((lon,lat),SS2,(gridlon,gridlat),lvarname,interp_fname)
end

end
