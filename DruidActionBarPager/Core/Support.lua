-- Bounded technical report. Never includes identities, frame/bar IDs or actions.
local _,ns=...
local R={};ns.Support=R
local function Safe(v)
 if not ns.Settings.Readable(v) then return 'unknown' end
 if type(v)=='number' and v==v and math.abs(v)<2147483648 then return tostring(v) end
 if type(v)=='boolean' then return tostring(v) end
 return 'unknown'
end
local function Version(v)
 return ns.Settings.Readable(v) and type(v)=='string' and #v<=64 and v:match('^%d[%w%.%-%+_ ]*$') and v or 'unknown'
end
local function Call(api,...)
 if type(api)~='function' then return end
 local ok,v=pcall(api,...);if ok and ns.Settings.Readable(v) then return v end
end
local function Meta(addon)
 local api=C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
 return Version(Call(api,addon,'Version'))
end
function R.Build()
 local lines={};local function Add(k,v)
  if #lines>=64 then return end
  local line=k..': '..v
  local size=#line;for _,s in ipairs(lines) do size=size+#s+1 end
  if size<=4096 then lines[#lines+1]=line end
 end
 Add('addon.version',Meta(ns.Constants.ADDON_NAME));Add('interface.target','16001')
 local api=GetBuildInfo;local ok,version,build,_,interface
 if type(api)=='function' then ok,version,build,_,interface=pcall(api) end
 Add('client.version',ok and Version(version) or 'unknown');Add('client.build',ok and Version(build) or 'unknown');Add('client.interface',ok and Safe(interface) or 'unknown')
 local form=Call(GetShapeshiftForm);Add('form.index',Safe(form))
 local class='unknown'
 if type(form)=='number' and form==math.floor(form) and form>0 and form<=20 then
  local success,value=pcall(ns.Forms.Classify,form)
  if success and ns.Settings.Readable(value) and ns.Constants.DEFAULT_PAGES[value]~=nil then class=value end
 elseif form==0 then class='caster' end
 Add('form.classified',class)
 local db=ns.Settings.Get();Add('paging.enabled',db and Safe(db.enabled) or 'unknown')
 local status=ns.Profiles.Status();local valid={tank=true,cat=true,balance=true,healing=true}
 Add('profile.active',valid[status.active] and status.active or 'unavailable');Add('profile.characterAvailable',Safe(status.characterAvailable));Add('profile.specAvailable',Safe(status.specAvailable))
 local snapshot;local good,value=pcall(ns.Mapping.Snapshot);if good then snapshot=value end
 snapshot=snapshot or {}
 Add('page.desired',Safe(snapshot.desired));Add('page.applied',Safe(snapshot.applied));Add('rebuild.pending',Safe(ns.Rebuild.IsPending()))
 local states={['Settings unavailable']=true,['Pending combat changes']=true,Disabled=true,['Main bar not found']=true,['Yielding to game override']=true,['Normal bar owns paging']=true}
 local state=ns.Settings.Readable(snapshot.state) and snapshot.state
 if state and type(state)=='string' and state:match('^DABP owns page %d+$') then state='DABP owns configured page' elseif not states[state] then state='unknown' end
 Add('paging.state',state)
 local info=ns.Attach.Info();local family='Generic discovery'
 for _,bar in ipairs(ns.Constants.KNOWN_BARS) do if info.name==bar.name then family=bar.name;break end end
 Add('bar.adapter',family);Add('extras.selected',db and tostring(#db.additionalBars) or 'unknown');Add('extras.missing',type(info.missingExtras)=='table' and tostring(#info.missingExtras) or 'unknown')
 local descriptor=ns.Compatibility.Describe(family)
 local methods={actionpage=true,['LibActionButton state']=true,['action-base / fixed slot']=true,['fixed slot']=true,['detected button attributes']=true}
 Add('adapter.method',methods[descriptor.method] and descriptor.method or 'unknown');Add('adapter.evidence','Offline mock contract')
 for _,name in ipairs({'Bartender4','ElvUI','Dominos','EllesmereUI','Neuron'}) do Add('metadata.'..name,Meta(name)) end
 return table.concat(lines,'\n')
end
