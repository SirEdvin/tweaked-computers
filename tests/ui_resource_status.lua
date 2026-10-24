-- Pure presentation contract doubles, not native/runtime counter evidence.
local view=require('scripts.ui.resource-status')
local registry=require('scripts.registry')
local model=require('scripts.ui.editor-model')
local limits=require('scripts.runtime.limits')
local M={}
function M.run()
  assert(view.summary(nil)=='Resource status unavailable')
  local status={state='waiting',wait={resource='work',setting='tc-callback-work',resumable=true,since_tick=7},
    resources={memory={used=200,limit=100,unit='bytes',scope='computer',setting='tc-runtime-memory-bytes',over_limit=true}},
    dropped_events={total=9007199254740991,saturated=true,last_tick=11,last_kind='signal',last_reason='queue full'}}
  local summary=view.summary(status)
  assert(summary:find('waiting',1,true) and summary:find('dropped',1,true) and summary:sub(-1)=='+')
  local details=view.details(status,{used=300,limit=200,setting='tc-draft-storage-bytes',over_limit=true})
  for _,value in ipairs({'since tick 7','200 / 100 bytes','accepted data retained','(saturated)','tick 11: signal / queue full','300 / 200 bytes','accepted drafts retained'}) do
    assert(details:find(value,1,true),value)
  end
  status.state='resource_refused'; status.wait=nil
  status.last_refusal={code='E_CAPACITY',message=string.rep('complete diagnostic ',100)..'END',resource='memory',setting='tc-runtime-memory-bytes',used=200,requested=8,limit=100,recoverable=true}
  assert(view.summary(status):find('recoverable',1,true) and not view.summary(status):find('fault',1,true))
  details=view.details(status)
  assert(details:find(status.last_refusal.message,1,true) and details:find('requested 8',1,true))
  local before=status.dropped_events.total
  view.summary(status); view.details(status)
  assert(status.dropped_events.total==before and status.last_refusal.message:sub(-3)=='END')
  log('TC_CONTRACT ui-resource-status-complete-recoverable-wait-and-loss')
  local original=storage.tweaked_computers; local limit=limits.draft_storage_bytes
  storage.tweaked_computers=nil; registry.initialize()
  local d={source='draft',base_source='base'}
  local b={documents={['tc-1']=d},session={id='tc-1',shell_draft='command'}}
  registry.get().player_drafts[1]=b
  local expected=128+#'tc-1'+#d.source+#d.base_source+#b.session.shell_draft
  limits.draft_storage_bytes=expected-1
  local retention=model.retention(1)
  assert(retention.used==expected and retention.over_limit and b.documents['tc-1']==d)
  d.shell_draft=b.session.shell_draft
  assert(model.retention(1).used==expected,'legacy/session command must not count twice')
  limits.draft_storage_bytes=nil; assert(model.retention(1)==nil,'missing policy is not a fictional limit')
  storage.tweaked_computers=original; limits.draft_storage_bytes=limit
  log('TC_CONTRACT ui-draft-retention-accounting-only-no-mutation')
  log('TC_CONTRACT_TOTAL 2')
end
return M
