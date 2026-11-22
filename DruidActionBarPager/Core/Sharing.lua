-- Mapping-only literal interchange. No code, identities or bar identifiers.
local _,ns=...
local S={};ns.Sharing=S
local order={'bear','cat','travel','aquatic','moonkin','tree','prowl'}
function S.Export()
 local map=ns.Settings.Mapping();if not map then return nil,'unavailable' end
 local parts={'DABP1'};for _,k in ipairs(order) do parts[#parts+1]=k..'='..map[k] end;return table.concat(parts,';')
end
function S.Parse(text)
 if not ns.Settings.Readable(text) or type(text)~='string' or #text>256 or text:find('[%z\1-\31\127]') or text:sub(1,6)~='DABP1;' then return nil,'invalid' end
 local map,keys={},{};for _,k in ipairs(order) do keys[k]=true end
 for field in (text:sub(7)..';'):gmatch('(.-);') do
  local key,raw=field:match('^([a-z]+)=(%d+)$')
  if not key or not keys[key] or map[key]~=nil or #raw>2 or tostring(tonumber(raw))~=raw then return nil,'invalid' end
  map[key]=tonumber(raw)
 end
 local valid=ns.Settings.ValidateMapping(map);if not valid then return nil,'invalid' end;return valid
end
function S.Stage(text)
 local map,why=S.Parse(text);if not map then return nil,why end
 return ns.Settings.StageMapping(map,'import')
end
