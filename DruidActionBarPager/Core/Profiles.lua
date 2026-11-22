-- Fixed manual profiles and capability-checked current spec-group binding.
local _,ns=...
local P={};ns.Profiles=P
local entries={{id='tank',label='Tank'},{id='cat',label='Cat'},{id='balance',label='Balance'},{id='healing',label='Healing'}}
function P.List() local out={};for i,v in ipairs(entries) do out[i]={id=v.id,label=v.label} end;return out end
function P.Status() return ns.Settings.ProfileStatus() end
function P.Preview(id) return ns.Settings.StageProfile(id) end
function P.Apply(token) return ns.Settings.ApplyMapping(token) end
function P.BindCurrent() return ns.Settings.SetBinding(false) end
function P.UnbindCurrent() return ns.Settings.SetBinding(true) end
function P.OnContext()
 local changed=ns.Settings.RefreshContext()
 if changed and ns.Rebuild then
  if InCombatLockdown() then ns.Rebuild.Now(true) else ns.Rebuild.Request(true) end
 end
 return changed
end
