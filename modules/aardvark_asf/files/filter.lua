#!/usr/bin/env lua
local yaml = require 'lyaml'

-- Get rule-set on load
local yamlData = "foo: bar"
local f = io.open("/usr/local/etc/aardvark/ruleset.yaml", "r")
if f then
   yamlData = f:read("*a")
   f:close()
end   
local yamlRuleset = yaml.load(yamlData)


function logspam(r)
   local f = io.open("/usr/local/etc/aardvark/spammers.txt", "a")
   if f then
       f:write("[" .. os.date("%c", os.time()) .. "] " .. r.useragent_ip .. " spammed Aardvark\n")
       f:close()
   end
end

function input_filter(r)
   
   -- first, if we need to ignore this URL, we'll do so
   for k, v in pairs(yamlRuleset.ignoreurls or {}) do
      if r.uri:match(v) then
         return
      end
   end
   
   -- Now, catch bad URLs
   for k, v in pairs(yamlRuleset.spamurls or {}) do
      if r.uri:match(v) then
         logspam(r)
         return 500
      end
   end
   
   
   local auxcounter = 0
   local reqcounter = 0
   coroutine.yield() -- yield, wait for buckets
   
   -- for each bucket..
   while bucket do
      local caught = false -- bool for whether we caught anything
      
      -- Look for data in POST we don't like
      for k, v in pairs(yamlRuleset.postmatches or {}) do
         if bucket:lower():match(v) then
            logspam(r)
            caught = true
            return 500
         end
      end
      
      -- Then, check for multi-match rules
      -- First, required vars
      local mm = yamlRuleset.multimatch or {}
      for k, v in pairs(mm.required or {}) do
         if bucket:lower():match(v) then
            reqcounter = reqcounter + 1
         end
      end
      -- then, auxiliary ones
      for k, v in pairs(mm.auxiliary or {}) do
         if bucket:lower():match(v) then
            auxcounter = auxcounter + 1
         end
      end
      
      -- Now, require all req ones and at least one aux (or none if no aux)
      if reqcounter == #(mm.required or {}) and (auxcounter == 1 or #(mm.auxiliary or {}) == 0) then
         caught = true
         logspam(r)
         return 500
      end
      
      -- if nothing happened, pass through bucket
      if not caught then
         coroutine.yield(bucket)
      end
   end
end
