-- Single-endpoint workload: GET /reservation
--   frontend -> user.CheckUser  -> reservation.MakeReservation
--
-- Tuned for maximum RPS and, just as important, for a STEADY STATE that can be replayed
-- forever without the measurement drifting.
--
-- MakeReservation (services/reservation/server.go:100) is a WRITE path: on success it
-- does one mongo InsertOne PER NIGHT and grows the reservation collection without bound,
-- so throughput decays run over run. Two knobs avoid that:
--
--   1. HR_NUM larger than any seeded capacity (cmd/reservation/db.go seeds 200/250/300).
--      The capacity check at :180 returns early, so there is NO mongo insert and no
--      memcached Set -- the request is pure memcached reads. Response is HTTP 200
--      {"message":"Failed. Already reserved. "}. This is the default.
--   2. A 1-NIGHT stay. :115 loops once per night, each iteration doing two memcached
--      Get calls (date key + capacity key). One night = two gets, the floor.
--
-- Warm up first with HR_NUM=0 (see the header comment in the run instructions): those
-- requests succeed and populate the "<hotelId>_<date>_<date>" key, after which the
-- default HR_NUM=1000 path hits memcached for both keys and never touches mongo.
--
-- Username follows cmd/user/db.go: Cornell_%x over the *string* suffix, i.e. i=1 -> "31".
-- Override with env vars (this wrk2 fork does not support `-- <args>`):
--   HR_USER HR_PASS HR_HOTEL HR_INDATE HR_OUTDATE HR_NUM

local user    = os.getenv("HR_USER")    or "Cornell_31"
local pass    = os.getenv("HR_PASS")    or "1111111111"
local hotel   = os.getenv("HR_HOTEL")   or "1"
local indate  = os.getenv("HR_INDATE")  or "2015-04-09"
local outdate = os.getenv("HR_OUTDATE") or "2015-04-10"
local num     = os.getenv("HR_NUM")     or "1000"

local req

function init(args)
  req = wrk.format("GET", "/reservation?inDate=" .. indate .. "&outDate=" .. outdate ..
                          "&hotelId=" .. hotel .. "&customerName=" .. user ..
                          "&username=" .. user .. "&password=" .. pass ..
                          "&number=" .. num, nil, nil)
end

function request()
  return req
end
