-- Read-only twelve-slot observations. No action movement or secure writes.
local _,ns=...
local A={};ns.Actions=A
local function Read(api,...)
 if type(api)~='function' then return false end
 local ok,a,b=pcall(api,...)
 if not ok or not ns.Settings.Readable(a) or not ns.Settings.Readable(b) then return false end
 return true,a,b
end
local function Texture(slot)
 local ok,v=Read(GetActionTexture,slot)
 if not ok then return end
 if type(v)=='number' and v==v and v>0 and v<math.huge then return v end
 if type(v)=='string' and #v<=256 and not v:find('[%z\1-\31\127|]') then return v end
end
local function Slot(index,slot)
 local out={index=index,slot=slot,state='unknown',label='Unknown'}
 local hasOK,has=Read(HasAction,slot)
 if hasOK and has==false then out.state,out.label='empty','Empty';return out end
 local ok,kind,id=Read(GetActionInfo,slot)
 if not ok then return out end
 if kind==nil then
  if not (hasOK and has==true) then out.state,out.label='empty','Empty' end
  return out
 end
 if type(kind)~='string' then return out end
 out.texture=Texture(slot)
 if kind=='spell' or kind=='item' then
  if type(id)~='number' or id~=id or id<=0 or id>=2147483648 or id~=math.floor(id) then return out end
  out.state,out.kind,out.id=kind,kind,id
  out.label=(kind=='spell' and 'Spell ' or 'Item ')..id
 else out.state,out.kind,out.label='other','other','Other' end
 return out
end
function A.Preview(form,page)
 local db=ns.Settings.Get()
 if not db or (form~='prowl' and ns.Constants.DEFAULT_PAGES[form]==nil) then return nil,'invalid' end
 local map=ns.Settings.Mapping();map[form]=page
 if not ns.Settings.ValidateMapping(map) then return nil,'invalid' end
 local mode=page==0 and (form=='prowl' and 'inherit' or 'no-switch') or 'page'
 local resolved=mode=='inherit' and db.pages.cat or page
 local model={form=form,page=page,resolvedPage=resolved,mode=mode,available=true,slots={}}
 if InCombatLockdown() then model.available,model.reason=false,'combat';return model end
 if resolved==0 then return model end
 for i=1,12 do model.slots[i]=Slot(i,(resolved-1)*12+i) end
 return model
end
