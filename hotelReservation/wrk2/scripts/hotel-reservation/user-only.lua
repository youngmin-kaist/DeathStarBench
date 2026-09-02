-- Single-endpoint workload: GET /user (frontend -> user, 1 gRPC hop, no DB on request path).
-- Always the same user, so the request is formatted once and reused: no per-request
-- string building, no RNG, no socket dependency -- the load generator stays out of the way.
--
-- Username follows cmd/user/db.go: Cornell_%x over the *string* suffix, i.e. i=1 -> "31".
-- Overridable: wrk -s user-only.lua ... -- <username> <password>

local user = os.getenv("HR_USER") or "Cornell_31"
local pass = os.getenv("HR_PASS") or "1111111111"

local req

function init(args)
  if args[1] then user = args[1] end
  if args[2] then pass = args[2] end
  local path = "/user?username=" .. user .. "&password=" .. pass
  req = wrk.format("GET", path, nil, nil)
end

function request()
  return req
end
