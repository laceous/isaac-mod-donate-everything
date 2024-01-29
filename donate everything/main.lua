local mod = RegisterMod('Donate Everything', 1)
local json = require('json')
local game = Game()

mod.frame = -1
mod.onGameStartHasRun = false

mod.state = {}
mod.state.unjamDonationMachines = false
mod.state.unjamGreedDonationMachines = false

function mod:onGameStart()
  if mod:HasData() then
    local _, state = pcall(json.decode, mod:LoadData())
    
    if type(state) == 'table' then
      for _, v in ipairs({ 'unjamDonationMachines', 'unjamGreedDonationMachines' }) do
        if type(state[v]) == 'boolean' then
          mod.state[v] = state[v]
        end
      end
    end
  end
  
  mod.onGameStartHasRun = true
end

function mod:onGameExit()
  mod:save()
  mod.frame = -1
  mod.onGameStartHasRun = false
end

function mod:save()
  mod:SaveData(json.encode(mod.state))
end

-- start ModConfigMenu --
function mod:setupModConfigMenu()
  for _, v in ipairs({ 'Donation Machines' }) do
    ModConfigMenu.RemoveSubcategory(mod.Name, v)
  end
  for i, v in ipairs({
                      { title = 'Donation Machine', variant = 8, options = {
                                                                             { flag = GameStateFlag.STATE_DONATION_SLOT_BLOWN , text = 'Blown'     , info = { 'Toggle game state flag',
                                                                                                                                                              'Re-enter the room to apply to current machines',
                                                                                                                                                            }
                                                                             },
                                                                             { flag = GameStateFlag.STATE_DONATION_SLOT_BROKEN, text = 'Broken'    , info = { 'Toggle game state flag',
                                                                                                                                                              'Re-enter the room to apply to current machines',
                                                                                                                                                            }
                                                                             },
                                                                             { flag = GameStateFlag.STATE_DONATION_SLOT_JAMMED, text = 'Jammed'    , info = { 'Toggle game state flag',
                                                                                                                                                              'Re-enter the room to apply to current machines',
                                                                                                                                                            }
                                                                             },
                                                                             { flag = -99, field = 'unjamDonationMachines'    , text = 'Auto-unjam', info = { 'Automatically unjam donation machines?',
                                                                                                                                                              'Requires repentogon',
                                                                                                                                                            }
                                                                             },
                                                                             { flag = -1                                      , text = 'Spawn'     , info = { 'Spawn a new donation machine' } },
                                                                             { flag = -2                                      , text = 'Fix'       , info = { 'Fix broken or jammed donation machines' } },
                                                                           }
                      },
                      { title = 'Greed Donation Machine', variant = 11, options = {
                                                                                    { flag = GameStateFlag.STATE_GREED_SLOT_JAMMED    , text = 'Jammed'    , info = { 'Toggle game state flag',
                                                                                                                                                                      'Re-enter the room to apply to current machines',
                                                                                                                                                                    }
                                                                                    },
                                                                                    { flag = -99, field = 'unjamGreedDonationMachines', text = 'Auto-unjam', info = { 'Automatically unjam greed donation machines?',
                                                                                                                                                                      'Requires repentogon'
                                                                                                                                                                    }
                                                                                    },
                                                                                    { flag = -1                                       , text = 'Spawn'     , info = { 'Spawn a new greed donation machine' } },
                                                                                    { flag = -2                                       , text = 'Fix'       , info = { 'Fix jammed greed donation machines' } },
                                                                                  }
                      },
                    })
  do
    if i ~= 1 then
      ModConfigMenu.AddSpace(mod.Name, 'Donation Machines')
    end
    ModConfigMenu.AddTitle(mod.Name, 'Donation Machines', v.title)
    for _, w in ipairs(v.options) do
      ModConfigMenu.AddSetting(
        mod.Name,
        'Donation Machines',
        {
          Type = ModConfigMenu.OptionType.BOOLEAN,
          CurrentSetting = function()
            if w.flag >= 0 then
              return game:GetStateFlag(w.flag)
            elseif w.flag == -99 then
              return mod.state[w.field]
            end
            return false
          end,
          Display = function()
            if w.flag >= 0 then
              return w.text .. ' : ' .. (game:GetStateFlag(w.flag) and 'yes' or 'no')
            elseif w.flag == -99 then
              return w.text .. ' : ' .. (mod.state[w.field] and 'yes' or 'no')
            end
            return w.text
          end,
          OnChange = function(b)
            if w.flag >= 0 then
              game:SetStateFlag(w.flag, b)
            elseif w.flag == -1 then
              local room = game:GetRoom()
              Isaac.Spawn(EntityType.ENTITY_SLOT, v.variant, 0, Isaac.GetFreeNearPosition(room:GetCenterPos(), 3), Vector.Zero, nil)
            elseif w.flag == -2 then
              local slots = Isaac.FindByType(EntityType.ENTITY_SLOT, v.variant, -1, false, false)
              if #slots > 0 then
                if v.variant == 8 then
                  game:SetStateFlag(GameStateFlag.STATE_DONATION_SLOT_BLOWN, false)
                  game:SetStateFlag(GameStateFlag.STATE_DONATION_SLOT_BROKEN, false)
                  game:SetStateFlag(GameStateFlag.STATE_DONATION_SLOT_JAMMED, false)
                else -- 11
                  game:SetStateFlag(GameStateFlag.STATE_GREED_SLOT_JAMMED, false)
                end
                for _, slot in ipairs(slots) do
                  if slot:Exists() then
                    slot:Remove()
                    
                    local entity = Isaac.Spawn(slot.Type, slot.Variant, slot.SubType, slot.Position, slot.Velocity, slot.SpawnerEntity)
                    entity:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
                    entity.TargetPosition = slot.TargetPosition
                  end
                end
              end
            elseif w.flag == -99 then
              mod.state[w.field] = b
              mod:save()
            end
          end,
          Info = w.info
        }
      )
    end
  end
end
-- end ModConfigMenu --

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)

if ModConfigMenu then
  mod:setupModConfigMenu()
end

if REPENTOGON then
  -- filtered to: DONATION_MACHINE, GREED_DONATION_MACHINE
  -- MC_PRE_SLOT_COLLISION : no coins have been removed from player, no coins have been inserted into machine
  -- MC_POST_SLOT_COLLISION : 1 coin has already been removed from player, no coins have been inserted into machine yet
  function mod:onPostSlotCollision(entitySlot, collider, low)
    if (entitySlot:GetState() == 1 or entitySlot:GetState() == 2) and entitySlot:GetTouch() == 0 and entitySlot:GetTimeout() == 0 and game:GetFrameCount() - mod.frame > 1 and collider.Type == EntityType.ENTITY_PLAYER then
      local player = collider:ToPlayer()
      local isBaby = player:GetBabySkin() ~= BabySubType.BABY_UNASSIGNED
      local isCoopGhost = player:IsCoopGhost()
      local isChild = player.Parent ~= nil
      
      -- require actual players for this
      -- babies and children can normally use donation machines
      if not isBaby and not isCoopGhost and not isChild then
        if Input.IsActionPressed(ButtonAction.ACTION_DROP, player.ControllerIndex) then
          local gameData = Isaac.GetPersistentGameData()
          local stat = entitySlot.Variant == SlotVariant.DONATION_MACHINE and EventCounter.DONATION_MACHINE_COUNTER or EventCounter.GREED_DONATION_MACHINE_COUNTER
          local count = gameData:GetEventCounter(stat) % 1000 -- normalize
          local coins = player:GetNumCoins()
          if count + coins >= 999 then
            coins = 999 - count - 1
          end
          if coins > 0 then
            player:AddCoins(coins * -1)
            gameData:IncreaseEventCounter(stat, coins)
            
            -- additional donation machine behavior
            if entitySlot.Variant == SlotVariant.DONATION_MACHINE then
              -- 1) about 2% chance to increase luck by 1
              local luck = 0
              for i = 1, coins do
                if entitySlot:GetDropRNG():RandomFloat() < 0.02 then
                  luck = luck + 1
                end
              end
              if luck > 0 then
                player:DonateLuck(luck) -- this sticks around unlike setting the Luck property
              end
              
              -- 2) increased angel chance at 10 coins if no devil deals have been taken
              game:DonateAngel(coins)
            else -- GREED_DONATION_MACHINE
              -- per player greed donation stats
              local greedDonatedStat = mod:getGreedDonatedStat(player:GetPlayerType())
              if greedDonatedStat then
                gameData:IncreaseEventCounter(greedDonatedStat, coins)
              end
              
              -- i don't think this does anything
              --game:DonateGreed(coins)
            end
          end
        end
      end
    end
    
    mod.frame = game:GetFrameCount()
  end
  
  -- filtered to: DONATION_MACHINE, GREED_DONATION_MACHINE
  function mod:onSlotUpdate(entitySlot)
    -- this can run one time before we load in our settings
    if not mod.onGameStartHasRun then
      return
    end
    
    local unjam = entitySlot.Variant == SlotVariant.DONATION_MACHINE and mod.state.unjamDonationMachines or mod.state.unjamGreedDonationMachines
    if unjam then
      local flag = entitySlot.Variant == SlotVariant.DONATION_MACHINE and GameStateFlag.STATE_DONATION_SLOT_JAMMED or GameStateFlag.STATE_GREED_SLOT_JAMMED
      if game:GetStateFlag(flag) then
        game:SetStateFlag(flag, false)
      end
      
      if entitySlot:GetState() == 3 then -- broken/jammed
        local sprite = entitySlot:GetSprite()
        local animation = sprite:GetAnimation()
        
        if animation == 'CoinJam' or animation == 'CoinJam2' or animation == 'CoinJam3' or animation == 'CoinJam4' then
          entitySlot:SetState(1)
          sprite:SetFrame('Prize', 0)
          
          -- set the correct number
          local gameData = Isaac.GetPersistentGameData()
          local stat = entitySlot.Variant == SlotVariant.DONATION_MACHINE and EventCounter.DONATION_MACHINE_COUNTER or EventCounter.GREED_DONATION_MACHINE_COUNTER
          local count = string.format('%03d', gameData:GetEventCounter(stat) % 1000)
          sprite:SetLayerFrame(1, string.sub(count, 1, 1))
          sprite:SetLayerFrame(2, string.sub(count, 2, 2))
          sprite:SetLayerFrame(3, string.sub(count, 3, 3))
        end
      end
    end
  end
  
  function mod:getGreedDonatedStat(playerType)
    local tbl = {
      [PlayerType.PLAYER_ISAAC]          = EventCounter.GREED_MODE_COINS_DONATED_WITH_ISAAC,
      [PlayerType.PLAYER_MAGDALENE]      = EventCounter.GREED_MODE_COINS_DONATED_WITH_MAGDALENE,
      [PlayerType.PLAYER_CAIN]           = EventCounter.GREED_MODE_COINS_DONATED_WITH_CAIN,
      [PlayerType.PLAYER_JUDAS]          = EventCounter.GREED_MODE_COINS_DONATED_WITH_JUDAS,
      [PlayerType.PLAYER_BLACKJUDAS]     = EventCounter.GREED_MODE_COINS_DONATED_WITH_JUDAS,
      [PlayerType.PLAYER_BLUEBABY]       = EventCounter.GREED_MODE_COINS_DONATED_WITH_BLUE,
      [PlayerType.PLAYER_EVE]            = EventCounter.GREED_MODE_COINS_DONATED_WITH_EVE,
      [PlayerType.PLAYER_SAMSON]         = EventCounter.GREED_MODE_COINS_DONATED_WITH_SAMSON,
      [PlayerType.PLAYER_AZAZEL]         = EventCounter.GREED_MODE_COINS_DONATED_WITH_AZAZEL,
      [PlayerType.PLAYER_LAZARUS]        = EventCounter.GREED_MODE_COINS_DONATED_WITH_LAZARUS,
      [PlayerType.PLAYER_LAZARUS2]       = EventCounter.GREED_MODE_COINS_DONATED_WITH_LAZARUS,
      [PlayerType.PLAYER_EDEN]           = EventCounter.GREED_MODE_COINS_DONATED_WITH_EDEN,
      [PlayerType.PLAYER_THELOST]        = 169, -- EventCounter.GREED_MODE_COINS_DONATED_WITH_THE_LOST,
      [PlayerType.PLAYER_LILITH]         = EventCounter.GREED_MODE_COINS_DONATED_WITH_LILITH,
      [PlayerType.PLAYER_KEEPER]         = EventCounter.GREED_MODE_COINS_DONATED_WITH_KEEPER,
      [PlayerType.PLAYER_APOLLYON]       = EventCounter.GREED_MODE_COINS_DONATED_WITH_APOLLYON,
      [PlayerType.PLAYER_THEFORGOTTEN]   = EventCounter.GREED_MODE_COINS_DONATED_WITH_FORGOTTEN,
      [PlayerType.PLAYER_THESOUL]        = EventCounter.GREED_MODE_COINS_DONATED_WITH_FORGOTTEN,
      [PlayerType.PLAYER_BETHANY]        = EventCounter.GREED_MODE_COINS_DONATED_WITH_BETHANY,
      [PlayerType.PLAYER_JACOB]          = EventCounter.GREED_MODE_COINS_DONATED_WITH_JACOB_AND_ESAU,
      [PlayerType.PLAYER_ESAU]           = EventCounter.GREED_MODE_COINS_DONATED_WITH_JACOB_AND_ESAU,
      [PlayerType.PLAYER_ISAAC_B]        = EventCounter.GREED_MODE_COINS_DONATED_WITH_T_ISAAC,
      [PlayerType.PLAYER_MAGDALENE_B]    = EventCounter.GREED_MODE_COINS_DONATED_WITH_T_MAGDALENE,
      [PlayerType.PLAYER_CAIN_B]         = EventCounter.GREED_MODE_COINS_DONATED_WITH_T_CAIN,
      [PlayerType.PLAYER_JUDAS_B]        = EventCounter.GREED_MODE_COINS_DONATED_WITH_T_JUDAS,
      [PlayerType.PLAYER_BLUEBABY_B]     = EventCounter.GREED_MODE_COINS_DONATED_WITH_T_BLUE_BABY,
      [PlayerType.PLAYER_EVE_B]          = EventCounter.GREED_MODE_COINS_DONATED_WITH_T_EVE,
      [PlayerType.PLAYER_SAMSON_B]       = EventCounter.GREED_MODE_COINS_DONATED_WITH_T_SAMSON,
      [PlayerType.PLAYER_AZAZEL_B]       = EventCounter.GREED_MODE_COINS_DONATED_WITH_T_AZAZEL,
      [PlayerType.PLAYER_LAZARUS_B]      = EventCounter.GREED_MODE_COINS_DONATED_WITH_T_LAZARUS,
      [PlayerType.PLAYER_LAZARUS2_B]     = EventCounter.GREED_MODE_COINS_DONATED_WITH_T_LAZARUS,
      [PlayerType.PLAYER_EDEN_B]         = EventCounter.GREED_MODE_COINS_DONATED_WITH_T_EDEN,
      [PlayerType.PLAYER_THELOST_B]      = EventCounter.GREED_MODE_COINS_DONATED_WITH_T_THE_LOST,
      [PlayerType.PLAYER_LILITH_B]       = EventCounter.GREED_MODE_COINS_DONATED_WITH_T_LILITH,
      [PlayerType.PLAYER_KEEPER_B]       = EventCounter.GREED_MODE_COINS_DONATED_WITH_T_KEEPER,
      [PlayerType.PLAYER_APOLLYON_B]     = 400, -- EventCounter.GREED_MODE_COINS_DONATED_WITH_T_APOLLYON,
      [PlayerType.PLAYER_THEFORGOTTEN_B] = 401, -- EventCounter.GREED_MODE_COINS_DONATED_WITH_T_THE_FORGOTTEN,
      [PlayerType.PLAYER_THESOUL_B]      = 401, -- EventCounter.GREED_MODE_COINS_DONATED_WITH_T_THE_FORGOTTEN,
      [PlayerType.PLAYER_BETHANY_B]      = 402, -- EventCounter.GREED_MODE_COINS_DONATED_WITH_T_BETHANY,
      [PlayerType.PLAYER_JACOB_B]        = 403, -- EventCounter.GREED_MODE_COINS_DONATED_WITH_T_JACOB_AND_ESAU,
      [PlayerType.PLAYER_JACOB2_B]       = 403, -- EventCounter.GREED_MODE_COINS_DONATED_WITH_T_JACOB_AND_ESAU,
    }
    
    return tbl[playerType]
  end
  
  mod:AddCallback(ModCallbacks.MC_POST_SLOT_COLLISION, mod.onPostSlotCollision, SlotVariant.DONATION_MACHINE)
  mod:AddCallback(ModCallbacks.MC_POST_SLOT_COLLISION, mod.onPostSlotCollision, SlotVariant.GREED_DONATION_MACHINE)
  mod:AddCallback(ModCallbacks.MC_POST_SLOT_UPDATE, mod.onSlotUpdate, SlotVariant.DONATION_MACHINE)
  mod:AddCallback(ModCallbacks.MC_POST_SLOT_UPDATE, mod.onSlotUpdate, SlotVariant.GREED_DONATION_MACHINE)
end