--[[
* XIUI Hotbar - Actions Module
]]--

require('common');
local data = require('modules.hotbar.data');

local M = {};

local controlPressed = false;


function M.HandleKey(event)
   --print("Key pressed wparam: " .. tostring(event.wparam) .. " lparam: " .. tostring(event.lparam)); 
   --https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes

   -- //@TODO: Move to helper function?
   -- Parse lParam bits per Keystroke Message Flags:
   -- bit 31 - transition state: 0 = key press, 1 = key release
   local lparam = tonumber(event.lparam) or 0
   local function getBit(val, idx) return math.floor(val / (2^idx)) % 2 end
   local isRelease = (getBit(lparam, 31) == 1)

   -- Update controlPressed state for Ctrl keys (VK_CONTROL=17, VK_LCONTROL=162, VK_RCONTROL=163)
   if (event.wparam == 17 or event.wparam == 162 or event.wparam == 163) then
       controlPressed = not isRelease
   end

   if (event.wparam == 49 and controlPressed) then -- Key '1' pressed with Ctrl. 
       AshitaCore:GetChatManager():QueueCommand(-1, '/ma "Cure II" <t>')
   end

   if (event.wparam == 49) then -- Key '1' pressed. Should be configurable and mapped later
       AshitaCore:GetChatManager():QueueCommand(-1, '/ma "Cure" <t>')
   end
end

return M