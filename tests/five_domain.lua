local H=dofile(TESTDIR..'/harness.lua')
local results={}
local function check(name,ok) results[#results+1]=(ok and 'PASS ' or 'FAIL ')..name end
local character,group,dead='Player-A',1,false
UnitGUID=function()return character end
UnitIsDeadOrGhost=function()return dead end
C_SpecializationInfo={GetActiveSpecGroup=function()return group end}
local ns=H.load(ADDON_FILES,{version=4,pages={bear=7,cat=3},prowlPage=0})
check('five domain APIs exist',ns.Actions and ns.Profiles and ns.Sharing and ns.Support and ns.Settings.Mapping)
if not (ns.Actions and ns.Profiles and ns.Sharing and ns.Support and ns.Settings.Mapping) then return table.concat(results,'\n') end
local map=ns.Settings.Mapping()
check('schema5 immutable seed captures legacy validated mapping',ns.Settings.Get().version==5 and ns.Settings.Get().profileSeed.bear==7)
local copy=ns.Settings.Mapping();copy.bear=9
check('mapping getter is copied',ns.Settings.Mapping().bear==7)
local draft=ns.Settings.ResetPreview();check('reset stages without writing',draft and ns.Settings.Mapping().bear==7)
check('reset applies all seven fields',ns.Settings.ApplyMapping(draft) and ns.Settings.Mapping().bear==2 and ns.Settings.Mapping().prowl==0)
local undo=ns.Settings.UndoPreview();check('undo reviews and restores legacy page',undo and ns.Settings.ApplyMapping(undo) and ns.Settings.Mapping().bear==7)
local import=ns.Sharing.Stage('DABP1;bear=2;cat=3;travel=0;aquatic=0;moonkin=4;tree=4;prowl=0')
ns.Settings.SetPage('cat',4)
check('intervening edit refuses stale import',not ns.Settings.ApplyMapping(import))
check('strict parser refuses duplicates and injection',not ns.Sharing.Parse('DABP1;bear=2;bear=3') and not ns.Sharing.Parse('return {}'))
check('sharing exports no identity',not ns.Sharing.Export():find(character,1,true))
check('profile activation changes only mapping',ns.Profiles.Apply(ns.Profiles.Preview('cat')) and ns.Profiles.Status().active=='cat')
ns.Settings.SetPage('bear',8);ns.Profiles.BindCurrent();ns.Profiles.Apply(ns.Profiles.Preview('tank'))
ns.Profiles.OnContext()
check('manual activation survives unchanged spec refresh',ns.Profiles.Status().active=='tank')
character='Player-B';ns.Profiles.OnContext()
check('new character inherits immutable seed not last working mapping',ns.Settings.Mapping().bear==7)
character='Player-A';ns.Profiles.OnContext()
check('previous character mapping retained',ns.Profiles.Status().active=='cat' and ns.Settings.Mapping().bear==8)
local before=ns.Settings.Mapping().bear;dead=true
check('reviewed apply refuses death',not ns.Settings.ApplyMapping(ns.Settings.ResetPreview()))
dead=false
local text=ns.Support.Build()
check('bounded support excludes character identity',#text<=4096 and not text:find(character,1,true))

-- Action content is observed without changing buttons or invoking actions.
local reads=0
local secret={}
issecretvalue=function(v)return v==secret end
HasAction=function(slot) reads=reads+1;return slot~=16 end
GetActionInfo=function(slot)
 reads=reads+1
 if slot==13 then return 'spell',1243 elseif slot==14 then return 'item',17021
 elseif slot==15 then return 'macro',1 elseif slot==18 then return 'spell',nil
 elseif slot==19 then return 'spell',math.huge elseif slot==20 then return 'item','123'
 elseif slot==21 then return 'spell',secret elseif slot==22 then error('fixture')
 elseif slot==23 then return 'futuretype',5 elseif slot==24 then return 'spell',1 end
end
GetActionTexture=function(slot) if slot==24 then return secret end;return 132276 end
local model=ns.Actions.Preview('bear',2)
check('preview contains exactly twelve ordered configured action slots',#model.slots==12 and model.slots[1].slot==13 and model.slots[12].slot==24)
check('spell item and real other action states stay distinct',model.slots[1].state=='spell' and model.slots[2].state=='item' and model.slots[3].state=='other' and model.slots[11].state=='other')
check('only proven absent action is Empty',model.slots[4].state=='empty' and model.slots[5].state=='unknown')
check('malformed known IDs remain Unknown',model.slots[6].state=='unknown' and model.slots[7].state=='unknown' and model.slots[8].state=='unknown' and model.slots[9].state=='unknown' and model.slots[10].state=='unknown')
check('secret textures are omitted without revealing an action label',model.slots[12].state=='spell' and model.slots[12].texture==nil)
local oldReads=reads;H.setCombat(true,true);local blocked=ns.Actions.Preview('bear',2)
check('combat preview never calls action readers',reads==oldReads and not blocked.available)
H.setCombat(false)
local zero=ns.Actions.Preview('bear',0)
check('no-switch preview never fabricates page one',zero.mode=='no-switch' and #zero.slots==0 and reads==oldReads)
ns.Settings.SetPage('cat',0);local inherited=ns.Actions.Preview('prowl',0)
check('Prowl zero inherits Cat zero without action reads',inherited.mode=='inherit' and inherited.resolvedPage==0 and #inherited.slots==0 and reads==oldReads)
check('invalid supplied pages never fall back to valid previews',not ns.Actions.Preview('bear',11) and not ns.Actions.Preview('bear','2') and not ns.Actions.Preview('bear',0/0))
HasAction=nil;GetActionInfo=nil
check('missing action APIs yield Unknown instead of Empty',ns.Actions.Preview('bear',2).slots[1].state=='unknown')
GetActionInfo=function()return nil end
check('readable legacy nil info supplies absence proof',ns.Actions.Preview('bear',2).slots[1].state=='empty')
-- Private authority ignores edits to the public review model.
ns.Settings.SetPage('bear',7);local authoritative=ns.Settings.ResetPreview();authoritative.after.bear=10
check('mutable review model cannot alter authoritative map',ns.Settings.ApplyMapping(authoritative) and ns.Settings.Mapping().bear==2)
local stale=ns.Settings.ResetPreview();character='Player-Other'
check('live identity drift refuses reviewed apply before an event',not ns.Settings.ApplyMapping(stale));character='Player-A'
local bindingBefore=ns.Settings.Get().characters[character].bindings['1'];group=2
check('binding refuses live spec-group drift before event',not ns.Profiles.BindCurrent() and ns.Settings.Get().characters[character].bindings['1']==bindingBefore and ns.Settings.Get().characters[character].bindings['2']==nil)
check('unbind refuses live spec-group drift',not ns.Profiles.UnbindCurrent())
group=1;character='Player-Other'
check('binding refuses live identity drift before event',not ns.Profiles.BindCurrent());character='Player-A'
C_SpecializationInfo.GetActiveSpecGroup=function()return secret end
check('binding refuses newly unreadable spec API',not ns.Profiles.BindCurrent())
C_SpecializationInfo=nil;GetActiveSpecGroup=nil
check('binding refuses newly missing spec API',not ns.Profiles.BindCurrent())
C_SpecializationInfo={GetActiveSpecGroup=function()return group end}
-- Same-group manual choices persist; genuine transitions choose only explicit bindings.
ns.Profiles.Apply(ns.Profiles.Preview('cat'));ns.Settings.SetPage('bear',8);ns.Profiles.BindCurrent()
ns.Profiles.Apply(ns.Profiles.Preview('tank'));ns.Settings.SetPage('bear',2)
check('equal-group context notification retains manual profile',not ns.Profiles.OnContext() and ns.Profiles.Status().active=='tank')
group=2;ns.Profiles.OnContext();check('unbound group retains manual profile',ns.Profiles.Status().active=='tank')
ns.Profiles.BindCurrent();group=1;H.setCombat(true,true);ns.Profiles.OnContext()
check('bound context transition queues desired profile safely in combat',ns.Profiles.Status().active=='cat' and ns.Settings.Mapping().bear==8 and ns.Rebuild.IsPending())
H.setCombat(false);H.fire('PLAYER_REGEN_ENABLED');H.runTimers();H.gameEvaluate()
check('queued desired profile survives combat flush',ns.Profiles.Status().active=='cat' and ns.Settings.Mapping().bear==8)
-- Bound ten-entry session history has no recursive undo records.
ns.Profiles.Apply(ns.Profiles.Preview('healing'))
for n=1,14 do ns.Settings.SetPage('bear',n%2+2) end
local undone=0
for _=1,12 do local t=ns.Settings.UndoPreview();if t and ns.Settings.ApplyMapping(t) then undone=undone+1 end end
check('history retains exactly ten mapping edits and successful undo consumes them',undone==10 and ns.Settings.UndoPreview()==nil)
ns.Settings.SetPage('bear',6);local preservedUndo=ns.Settings.UndoPreview();H.setCombat(true,true)
check('failed combat undo preserves history',not ns.Settings.ApplyMapping(preservedUndo));H.setCombat(false)
check('same reviewed undo can apply after combat',ns.Settings.ApplyMapping(preservedUndo))
local mapText=ns.Sharing.Export()
for _,bad in ipairs({mapText..';',mapText..';enabled=0',mapText..'\n',mapText:gsub('bear=%d+','bear=02'),mapText:gsub('bear=%d+','bear=-1'),mapText:gsub('bear=%d+','bear=11'),string.rep('x',257),'DABP1;bear=2;cat=3;travel=0;aquatic=0;moonkin=4;tree=4;prowl=0;bear=2'}) do
 check('strict mapping parser rejects malformed payload '..#bad,ns.Sharing.Parse(bad)==nil)
end

local oldBuild,oldMeta,oldForm,oldName=GetBuildInfo,GetAddOnMetadata,GetShapeshiftForm,UnitName
GetBuildInfo=function()return secret,secret,nil,secret end
GetAddOnMetadata=function()return '1.2.3\nPrivatePlayer' end
GetShapeshiftForm=function()return secret end
UnitName=function()error('identity reader must not be called')end
local support=ns.Support.Build();local lines=0;for _ in support:gmatch('[^\n]+') do lines=lines+1 end
check('support remains bounded with secret host data and never requests names',#support<=4096 and lines<=64 and not support:find('PrivatePlayer',1,true) and not support:find(character,1,true))
GetBuildInfo,GetAddOnMetadata,GetShapeshiftForm,UnitName=oldBuild,oldMeta,oldForm,oldName
local modern=C_SpecializationInfo;C_SpecializationInfo=nil;GetActiveSpecGroup=function()return 2 end
local legacy,available=ns.Settings.ReadSpecGroup()
check('callable legacy spec-group fallback is capability checked',legacy=='2' and available)
C_SpecializationInfo=modern;GetActiveSpecGroup=nil
local poisoned=ns.Settings.Mapping();poisoned.bear=secret
local current=ns.Settings.Mapping().bear
check('secret mapping input is rejected before any write',ns.Settings.StageMapping(poisoned,'import')==nil and ns.Settings.Mapping().bear==current)
local saved=ns.Settings.Get();local seed=saved.profileSeed.bear
character=nil;ns.Profiles.OnContext()
check('unreadable character keeps manual profile operations unavailable',not ns.Profiles.Status().characterAvailable and not ns.Profiles.Preview('tank'))
ns.Settings.SetPage('bear',9);check('legacy working edit does not mutate immutable seed',saved.profileSeed.bear==seed)
character='Player-A';ns.Profiles.OnContext()
-- Caps preserve original persistent objects before any repair.
local original={version=5,pages={bear=9},characters={}}
for i=1,65 do original.characters['Player-'..i]={} end
DruidActionBarPagerDB=original;ns.Settings.Load('DruidActionBarPager')
check('character overflow preserves original save and refuses live DB',DruidActionBarPagerDB==original and original.pages.bear==9 and ns.Settings.Get()==nil)
local excessive={version=4,pages={bear=9},characters={['Player-A']={profiles={tank={},cat={},balance={},healing={},extra={}}}}}
DruidActionBarPagerDB=excessive;ns.Settings.Load('DruidActionBarPager')
check('profile overflow preserves original old schema without migration',DruidActionBarPagerDB==excessive and excessive.version==4 and ns.Settings.Get()==nil)
local bounded={version=5,pages={bear=2},characters={['Player-A']={bindings={}}}}
for i=1,9 do bounded.characters['Player-A'].bindings[tostring(i)]='tank' end
DruidActionBarPagerDB=bounded;ns.Settings.Load('DruidActionBarPager')
check('spec-binding overflow preserves original records',DruidActionBarPagerDB==bounded and ns.Settings.Get()==nil)
DruidActionBarPagerDB={version=4,pages={bear=7,cat=3}};ns.Settings.Load('DruidActionBarPager')
local pendingFuture=ns.Settings.ResetPreview()
DruidActionBarPagerDB={version=999,pages={bear=9}};ns.Settings.Load('DruidActionBarPager')
check('future load invalidates live mapping history and earlier review tokens',ns.Settings.Get()==nil and ns.Settings.UndoPreview()==nil and not ns.Settings.ApplyMapping(pendingFuture))
return table.concat(results,'\n')
