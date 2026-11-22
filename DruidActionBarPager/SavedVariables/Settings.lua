-- Canonical SavedVariables writer and mapping/profile transaction owner.
local _,ns=...
local C,U=ns.Constants,ns.Util
local S={};ns.Settings=S
local db,generation,serial,history,pending=nil,0,0,{},nil
local identity,specKey,specAvailable,reason=nil,nil,false,nil
local ids={tank=true,cat=true,balance=true,healing=true}
local order={'bear','cat','travel','aquatic','moonkin','tree','prowl'}
local anchors={CENTER=true,TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
function S.Readable(v)
 if issecretvalue then local ok,b=pcall(issecretvalue,v);if not ok or b then return false end end
 if canaccessvalue then local ok,b=pcall(canaccessvalue,v);if not ok or not b then return false end end
 return true
end
local function Plain(v,n) return S.Readable(v) and type(v)=='string' and #v>0 and #v<=n and not v:find('[%z\1-\31\127|]') end
local function Page(v) return S.Readable(v) and type(v)=='number' and v==v and v>=0 and v<=C.MAX_PAGE and v==math.floor(v) end
local function Copy(m) local o={};for _,k in ipairs(order) do o[k]=m[k] end;return o end
local function Same(a,b) if not a or not b then return false end;for _,k in ipairs(order) do if a[k]~=b[k] then return false end end;return true end
function S.ValidateMapping(m)
 if not S.Readable(m) or type(m)~='table' or getmetatable(m) then return end
 local keys={};for _,k in ipairs(order) do keys[k]=true;if not Page(rawget(m,k)) then return end end
 for k in pairs(m) do if not S.Readable(k) or not keys[k] then return end end
 return Copy(m)
end
local function Defaults() local m={prowl=0};for _,k in ipairs(C.FORM_ORDER) do m[k]=C.DEFAULT_PAGES[k] end;return m end
local function Mapping()
 if not db then return end
 local m={prowl=db.prowlPage};for _,k in ipairs(C.FORM_ORDER) do m[k]=db.pages[k] end;return S.ValidateMapping(m)
end
local function Write(m) local p={};for _,k in ipairs(C.FORM_ORDER) do p[k]=m[k] end;db.pages,db.prowlPage=p,m.prowl end
local function Count(m,n) local c=0;for _ in pairs(m) do c=c+1;if c>n then return c end end;return c end
local function Identity()
 if type(UnitGUID)~='function' then return end
 local ok,v=pcall(UnitGUID,'player');if ok and Plain(v,80) then return v end
end
function S.ReadSpecGroup()
 local api=C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup
 if type(api)~='function' then api=GetActiveSpecGroup end
 if type(api)~='function' then return nil,false end
 local ok,v=pcall(api)
 if ok and S.Readable(v) and type(v)=='number' and v==v and v>=1 and v<=8 and v==math.floor(v) then return tostring(v),true end
 return nil,false
end
function S.IsDead()
 local api=UnitIsDeadOrGhost or UnitIsDead;if type(api)~='function' then return false end
 local ok,v=pcall(api,'player');return not ok or not S.Readable(v) or v==true
end
local function Active() return db and identity and db.characters[identity] end
local function ActiveID() local r=Active();return r and r.active end
local function Invalidate() generation=generation+1;history,pending={},nil end
function S.RefreshContext()
 if not db then return false end
 local guid=Identity();local group,available=S.ReadSpecGroup()
 local oldGuid,oldGroup,oldAvailable,oldActive=identity,specKey,specAvailable,ActiveID()
 identity,specKey,specAvailable=guid,group,available;reason=not guid and 'unavailable' or nil
 local r=Active();local created=false
 if guid and not r then
  if Count(db.characters,64)>=64 then reason='limit'
  else r={active='tank',profiles={},bindings={},auto=false};for id in pairs(ids) do r.profiles[id]=Copy(db.profileSeed) end;db.characters[guid]=r;created=true end
 end
 if not created and oldGuid==guid and oldGroup==group and oldAvailable==available then return false end
 Invalidate()
 if r then local bound=r.auto and group and r.bindings[group];if bound and ids[bound] then r.active=bound end;Write(r.profiles[r.active]) end
 return r~=nil or oldActive~=nil
end
local function OverLimit(original)
 local chars=rawget(original,'characters');if type(chars)~='table' then return false end
 if not S.Readable(chars) or getmetatable(chars) or Count(chars,64)>64 then return true end
 for _,r in pairs(chars) do
  if type(r)=='table' then
   if not S.Readable(r) or getmetatable(r) then return true end
   for _,f in ipairs({'profiles','bindings'}) do
    local m=rawget(r,f);local cap=f=='profiles' and 4 or 8
    if type(m)=='table' and (not S.Readable(m) or getmetatable(m) or Count(m,cap)>cap) then return true end
   end
  end
 end
 return false
end
function S.Load(name)
 if name~=C.ADDON_NAME then return false end
 db=nil;identity,specKey,specAvailable,reason=nil,nil,false,nil;Invalidate()
 local original=DruidActionBarPagerDB;if type(original)~='table' then original={} end
 if not S.Readable(original) or getmetatable(original) then reason='invalid';return false end
 local version=rawget(original,'version')
 if type(version)~='nil' and not S.Readable(version) then reason='invalid';return false end
 if S.Readable(version) and type(version)=='number' and version>C.DB_VERSION then reason='future';U.Print('Settings belong to a newer version. Install that version to use them.');return false end
 if OverLimit(original) then reason='overflow';U.Print('Profile records exceed supported limits; settings were preserved.');return false end
 version=S.Readable(version) and type(version)=='number' and version==version and version or 1
 local enabled=rawget(original,'enabled');local saved={enabled=true,version=C.DB_VERSION,characters={}}
 if S.Readable(enabled) and type(enabled)=='boolean' then saved.enabled=enabled end
 local pages=rawget(original,'pages');if type(pages)~='table' or not S.Readable(pages) then pages={} end
 local prowl=rawget(original,'prowlPage');local m={prowl=Page(prowl) and prowl or 0}
 for _,k in ipairs(C.FORM_ORDER) do
  local raw=rawget(pages,k);local v=S.Readable(raw) and (type(raw)=='number' or type(raw)=='string') and tonumber(raw) or nil
  if version<2 and ((k=='travel' and v==4) or (k=='aquatic' and v==5)) then v=0 end
  if version<3 and (k=='moonkin' or k=='tree') and v==6 then v=4 end
  m[k]=Page(v) and v or C.DEFAULT_PAGES[k]
 end
 saved.profileSeed=version<5 and Copy(m) or S.ValidateMapping(rawget(original,'profileSeed')) or Defaults()
 local chars=rawget(original,'characters')
 if type(chars)=='table' then
  for key,r in pairs(chars) do
   if Plain(key,80) and type(r)=='table' and S.Readable(r) and not getmetatable(r) then
    local active=rawget(r,'active');local fixed={active=S.Readable(active) and ids[active] and active or 'tank',profiles={},bindings={},auto=false}
    local auto=rawget(r,'auto');if S.Readable(auto) and type(auto)=='boolean' then fixed.auto=auto end
    local profiles,bindings=rawget(r,'profiles'),rawget(r,'bindings')
    for id in pairs(ids) do fixed.profiles[id]=S.ValidateMapping(type(profiles)=='table' and rawget(profiles,id)) or Copy(saved.profileSeed) end
    if type(bindings)=='table' then for i=1,8 do local key2=tostring(i);local a,b=rawget(bindings,key2),rawget(bindings,i);if S.Readable(a) and type(a)=='string' and ids[a] then fixed.bindings[key2]=a elseif S.Readable(b) and type(b)=='string' and ids[b] then fixed.bindings[key2]=b end end end
    saved.characters[key]=fixed
   end
  end
 end
 saved.additionalBars={};local bars=rawget(original,'additionalBars');local seen={}
 if type(bars)=='table' and S.Readable(bars) then for _,id in ipairs(bars) do if Plain(id,256) and not seen[id] and #saved.additionalBars<C.MAX_ADDITIONAL_BARS then saved.additionalBars[#saved.additionalBars+1]=id;seen[id]=true end end end
 local w=rawget(original,'mappingWindow');local function Coord(v) return S.Readable(v) and type(v)=='number' and v==v and math.abs(v)<=10000 end
 if type(w)=='table' and S.Readable(w) and not getmetatable(w) and Plain(rawget(w,'point'),20) and Plain(rawget(w,'relativePoint'),20) and anchors[w.point] and anchors[w.relativePoint] and Coord(w.x) and Coord(w.y) then saved.mappingWindow={point=w.point,relativePoint=w.relativePoint,x=w.x,y=w.y}
 else saved.mappingWindow={point='CENTER',relativePoint='CENTER',x=0,y=0} end
 db=saved;Write(m);DruidActionBarPagerDB=saved;S.RefreshContext();return true
end
function S.Get() return db end
function S.Mapping() local m=Mapping();return m and Copy(m) end
function S.Generation() return generation end
function S.ProfileStatus()
 local r=Active();return {active=r and r.active,characterAvailable=r~=nil,specAvailable=specAvailable,specKey=specKey,binding=r and specKey and r.bindings[specKey],reason=reason or (not specAvailable and 'unavailable' or nil)}
end
local function Context(t)
 local key,available=S.ReadSpecGroup()
 return t.db==db and t.generation==generation and t.identity==identity and t.profile==ActiveID() and Identity()==identity and key==specKey and available==specAvailable
end
local function Commit(m,journal)
 local before=Mapping();if Same(before,m) then return false end
 local r=Active();if r then r.profiles[r.active]=Copy(m) end
 Write(m);generation=generation+1;pending=nil
 if journal then serial=serial+1;history[#history+1]={id=serial,before=before,after=Copy(m),identity=identity,profile=ActiveID()};if #history>10 then table.remove(history,1) end end
 return true
end
function S.SetPage(form,page)
 if not db or not S.Readable(form) or type(form)~='string' or not Page(page) or (form~='prowl' and C.DEFAULT_PAGES[form]==nil) then return false end
 local m=Mapping();if not m then return false end;m[form]=page;Commit(m,true);return true
end
function S.SetEnabled(v)
 if not db or type(v)~='boolean' or not S.Readable(v) then return false end
 if db.enabled~=v then db.enabled=v;generation=generation+1;pending=nil end;return true
end
function S.StageMapping(mapping,source)
 if not db then return nil,reason or 'unavailable' end
 if not S.Readable(source) or type(source)~='string' then return nil,'invalid' end
 if source~='preview' and source~='import' and source~='reset' and source~='undo' then return nil,'invalid' end
 local after,before=S.ValidateMapping(mapping),Mapping();if not after or not before then return nil,'invalid' end
 local undo=source=='undo' and history[#history] or nil
 if source=='undo' and (not undo or not Same(undo.before,after) or not Same(undo.after,before)) then return nil,'conflict' end
 serial=serial+1;local changes,lines={},{}
 for _,form in ipairs(order) do if before[form]~=after[form] then changes[#changes+1]={form=form,before=before[form],after=after[form]};lines[#lines+1]=(C.FORM_LABELS[form] or 'Cat + Prowl')..': '..before[form]..' -> '..after[form] end end
 pending={id=serial,source=source,before=Copy(before),after=Copy(after),db=db,generation=generation,identity=identity,profile=ActiveID(),undo=undo}
 return {id=serial,source=source,before=Copy(before),after=Copy(after),changes=changes,lines=lines,profile=ActiveID(),characterAvailable=Active()~=nil}
end
function S.ResetPreview() return S.StageMapping(Defaults(),'reset') end
function S.UndoPreview()
 local h=history[#history];if not db or not h then return nil,'empty' end
 if h.identity~=identity or h.profile~=ActiveID() or not Same(Mapping(),h.after) then return nil,'conflict' end
 return S.StageMapping(h.before,'undo')
end
function S.StageProfile(id)
 local r=Active();if not r or not S.Readable(id) or not ids[id] then return nil,'unavailable' end
 local model,why=S.StageMapping(r.profiles[id],'preview');if model then pending.target=id;pending.targetBefore=Copy(r.profiles[id]);model.targetProfile=id end;return model,why
end
function S.ApplyMapping(model)
 if not db then return false,reason or 'unavailable' end
 if InCombatLockdown() then return false,'combat' end
 if S.IsDead() then return false,'dead' end
 if type(model)~='table' or getmetatable(model) or not pending or not S.Readable(rawget(model,'id')) or rawget(model,'id')~=pending.id then return false,'invalid' end
 local t=pending;if not Context(t) then return false,'generation' end
 if not Same(Mapping(),t.before) then return false,'conflict' end
 if t.target then
  local r=Active();if not r or not Same(r.profiles[t.target],t.targetBefore) then return false,'conflict' end
  if r.active~=t.target or not Same(t.before,t.after) then r.active=t.target;Write(t.after);Invalidate() end
 elseif t.source=='undo' then if history[#history]~=t.undo then return false,'conflict' end;Commit(t.after,false);table.remove(history)
 else Commit(t.after,true) end
 pending=nil;if ns.Rebuild then ns.Rebuild.Request(true) end;return true
end
function S.SetBinding(remove)
 local r=Active();if not r or not specAvailable or not specKey then return false,'unavailable' end
 local group,available=S.ReadSpecGroup()
 if Identity()~=identity or group~=specKey or available~=specAvailable then return false,'generation' end
 if InCombatLockdown() then return false,'combat' end;if S.IsDead() then return false,'dead' end
 r.bindings[specKey]=not remove and r.active or nil;r.auto=next(r.bindings)~=nil;generation=generation+1;pending=nil;return true
end
function S.SetExtra(slot,id)
 if not db or not S.Readable(slot) or type(slot)~='number' or slot~=math.floor(slot) or slot<1 or slot>C.MAX_ADDITIONAL_BARS then return false end
 if id~=nil and (not Plain(id,256) or slot>#db.additionalBars+1) then return false end
 for index,saved in ipairs(db.additionalBars) do if saved==id and index~=slot then return false end end
 if id then db.additionalBars[slot]=id elseif db.additionalBars[slot] then table.remove(db.additionalBars,slot) end;return true
end
function S.SaveWindow(point,relativePoint,x,y)
 local function Coord(v) return S.Readable(v) and type(v)=='number' and v==v and math.abs(v)<=10000 end
 if not db or not anchors[point] or not anchors[relativePoint] or not Coord(x) or not Coord(y) then return false end
 db.mappingWindow={point=point,relativePoint=relativePoint,x=x,y=y};return true
end
