using HTTP: HTTP, request, URI
using JSON3: JSON3
using DataFrames: AbstractDataFrame, DataFrames, DataFrame!, DataFrame, rename!, groupby, combine, nrow
using Dates: Dates, Date, format, unix2datetime
using CSV: CSV, File

donativos = DataFrame([String, Float16, String, String, String, String, Date],
                      [:nombre, :cantidad, :afiliación, :comité, :ciudad, :método, :fecha],
                      0)
periods = Date("2019-01-01"):Day(1):(today() - Day(1))
"""
    busqueda_de_donativos!(datos::AbstractDataFrame, día::Date)
"""
function busqueda_de_donativos!(datos::AbstractDataFrame, día::Date)
    día = format(día, "mm/dd/yyyy")
    respuesta = request("POST",
                        URI(scheme = "https",
                            host = "serviciosenlinea.oce.pr.gov",
                            path = "/PublishedDonor/FillPublishedDonorResultsGrid",
                            query = "dateFrom=$día&dateTo=$día&loadResult=true"))
    json = JSON3.read(respuesta.body)
    json.Total ≥ 1_000 && throw(ArgumentError("$día tiene $(json.Total)"))
    isempty(json.Data) && return datos
    data = DataFrame!(json.Data)
    data[!,:Date] .= Date.(unix2datetime.(parse.(Int, SubString.(data[!,:Date], 7, 16))))
    rename!(data, [:nombre, :cantidad, :afiliación, :comité, :ciudad, :método, :fecha])
    append!(datos, data)
end
for period in periods
    sleep(0.1)
    busqueda_de_donativos!(donativos, period)
end
sort!(donativos, :fecha)
CSV.write(joinpath("data", "original", "donativos.tsv"), donativos, delim = '\t')
