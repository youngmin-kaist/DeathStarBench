-- Single-endpoint workload: GET /hotels
--   frontend -> search -> {geo, rate} -> reservation -> profile
--
-- Tuned for maximum RPS. Everything is fixed rather than randomized, for three reasons:
--
--   1. STAY LENGTH is the dominant cost. services/reservation/server.go:286 loops once
--      per NIGHT per hotel (`for inDate.Before(outDate)`), building a memcached key each
--      iteration. The stock mixed workload draws inDate in [9,23] and outDate in
--      [inDate+1,24] -- averaging ~8 nights. A 1-night stay measured 2956 RPS @ p50 9.8ms
--      where a 15-night stay collapsed to 1596 RPS @ p50 6.8s on the same stack.
--   2. CACHE LOCALITY. Fixed dates and coordinates keep the rate / reservation / profile
--      memcached keys hot, so nothing falls back to mongo after warmup.
--   3. LOAD GENERATOR COST. The request is formatted once in init() and reused; request()
--      just returns a cached string. No RNG, no concat, no socket dependency.
--
-- The coordinates below land inside a populated region (27 hotels). Note that roughly
-- half of the stock workload's random coordinates return ZERO hotels, which makes those
-- requests trivial -- don't compare this script's RPS against it and conclude the stock
-- workload is faster.
--
-- Override with env vars (this wrk2 fork does not support `-- <args>`):
--   HR_LAT HR_LON HR_INDATE HR_OUTDATE

local lat     = os.getenv("HR_LAT")     or "38.0235"
local lon     = os.getenv("HR_LON")     or "-122.095"
local indate  = os.getenv("HR_INDATE")  or "2015-04-09"
local outdate = os.getenv("HR_OUTDATE") or "2015-04-10"

local req

function init(args)
  req = wrk.format("GET", "/hotels?inDate=" .. indate .. "&outDate=" .. outdate ..
                          "&lat=" .. lat .. "&lon=" .. lon, nil, nil)
end

function request()
  return req
end
