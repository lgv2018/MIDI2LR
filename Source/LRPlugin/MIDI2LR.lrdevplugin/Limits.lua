--------------------------------------------------------------------------------
-- Provides methods to manage control limits.
-- This allows limited-range MIDI controls (0-127) to control a LR parameter
-- with reasonable accuracy. It limits the total range that particular MIDI
-- control affects.
-- @module Limits
--------------------------------------------------------------------------------

--[[
This file is part of MIDI2LR. Copyright 2015 by Rory Jaffe.

MIDI2LR is free software: you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later version.

MIDI2LR is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
MIDI2LR.  If not, see <http://www.gnu.org/licenses/>. 
--]]
--All variables and functions defined here must be local, except for return table

--imports
local LrDevelopController = import 'LrDevelopController'
local prefs               = import 'LrPrefs'.prefsForPlugin() 
local LrView              = import 'LrView'

--hidden 




--public--each must be in table of exports
--------------------------------------------------------------------------------
-- Derives applicable min max for a parameter.
-- Given a variable containing range limits, returns the minimum and maximum for
-- a parameter appropriate to the current mode (jpg, raw, HDR).
-- @param variable Table of parameter limits
-- @param param Identifies which parameter's limits are wanted.
-- @return Two variables, min and max, for the given parameter and mode.
--------------------------------------------------------------------------------
local function Index(variable, param)
  local _, rangemax = LrDevelopController.getRange(param)
  return variable[param..'Low'][rangemax], variable[param..'High'][rangemax]
end

--------------------------------------------------------------------------------
-- Table listing parameter names managed by Limits module.
--------------------------------------------------------------------------------
local Parameters           = {Temperature = true, Tint = true, Exposure = true}


local function ClampValue(param)
  if Parameters[param] then
    local min, max = Index(MIDI2LR,param)
    local value = LrDevelopController.getValue(param)
    if value < min then      
      MIDI2LR.PARAM_OBSERVER[param] = min
      LrDevelopController.setValue(param, min)
    elseif value > max then
      MIDI2LR.PARAM_OBSERVER[param] = max
      LrDevelopController.setValue(param, max)
    end
  end
end


--------------------------------------------------------------------------------
-- Get temperature limit preferences.
-- Returns all saved settings, including those for modes not currently in use
-- (e.g., jpg, raw, HDR).
-- @return Table containing preferences in form table['TemperatureLow'][50000],
-- where second index identifies max vaule for mode (jpg, raw, HDR).
--------------------------------------------------------------------------------
local function GetPreferences()
  local retval = {}
  for p in pairs(Parameters) do
    prefs[p..'Low'] = prefs[p..'Low'] or {} -- if uninitialized
    for i,v in pairs(prefs[p..'Low']) do--run through all saved ranges
      retval[p..'Low'][i] = v
    end
    prefs[p..'High'] = prefs[p..'High'] or {} -- if uninitialized
    for p in pairs(Parameters) do
      for i,v in pairs(prefs[p..'High']) do--run through all saved ranges
        retval[p..'High'][i] = v
      end
    end
  end
  return retval
end

--------------------------------------------------------------------------------
-- Save temperature limit preferences
-- Ignores any preferences not in the provided table.
-- @param saveme Table of preferences in form table['TemperatureLow'][50000],
-- where second index identifies max vaule for mode (jpg, raw, HDR).
-- @return nil.
--------------------------------------------------------------------------------
local function SavePreferences(saveme)
  for p in pairs(Parameters) do
    prefs[p..'Low'] = prefs[p..'Low'] or {} -- if uninitialized
    for i,v in pairs(saveme[p..'Low']) do
      prefs[p..'Low'][i] = v
    end
    prefs[p..'High'] = prefs[p..'High'] or {} -- if uninitialized
    for i,v in pairs(saveme[p..'High']) do
      prefs[p..'High'][i] = v
    end
  end
  prefs = prefs --force save -- LR may not notice changes otherwise
end

--------------------------------------------------------------------------------
-- Save temperature limit preferences
-- Ignores any preferences not in the provided table. Uses current range for
-- parameter to identify mode to save
-- @param saveme Table of preferences in form table['TemperatureLow'].
-- @return nil.
--------------------------------------------------------------------------------
local function SavePreferencesOneMode(saveme)

  for p in pairs(Parameters) do
    local _, rangemax = LrDevelopController.getRange(p) 
    prefs[p..'Low'] = prefs[p..'Low'] or {} -- if uninitialized
    for i,v in pairs(saveme[p..'Low']) do
      prefs[p..'Low'][i] = v
    end
    prefs[p..'High'] = prefs[p..'High'] or {} -- if uninitialized
    for i,v in pairs(saveme[p..'High']) do
      prefs[p..'High'][i] = v
    end
  end
  prefs = prefs --force save -- LR may not notice changes otherwise
end

--------------------------------------------------------------------------------
-- Save temperature limits to a destination table
-- Ignores any preferences not in the source table. Uses current range for
-- parameter to identify mode to save
-- @param saveme Source table of preferences in form table['TemperatureLow'].
-- @param other Destination table in form table['TemperatureLow'][50000].
-- @return nil.
--------------------------------------------------------------------------------
local function SaveOtherTableOneMode(saveme, other)

  for p in pairs(Parameters) do
    local _, rangemax = LrDevelopController.getRange(p) 
    other[p..'Low'] = other[p..'Low'] or {} -- if uninitialized
    for i,v in pairs(saveme[p..'Low']) do
      other[p..'Low'][i] = v
    end
    other[p..'High'] = other[p..'High'] or {} -- if uninitialized
    for i,v in other(saveme[p..'High']) do
      other[p..'High'][i] = v
    end
  end
  prefs = prefs --force save -- LR may not notice changes otherwise
end


--------------------------------------------------------------------------------
-- Provide rows of controls for dialog boxes.
-- For the current photo type (HDR, raw, jpg, etc) will produce
-- rows that allow user to set limits.
-- @param f The LrView.osfactory to use.
-- @param obstable The observable table to bind to dialog controls.
-- @return Table of f:rows populated with the needed dialog controls.
--------------------------------------------------------------------------------
local function OptionsRows(f,obstable)
  local retval = {}
  for p in pairs(Parameters) do
    local low,high = LrDevelopController.getRange(p)
    table.insert(retval,
      f:row { 
        f:static_text {
          title = p..' Limits',
          width = LrView.share('limit_label'),
        }, -- static_text
        f:slider {
          value = LrView.bind(p..'Low'),
          min = low, 
          max = high,
          integral = true,
        }, -- slider
        f:static_text {
          title = LrView.bind(p..'Low'),
          alignment = 'right',
          width = LrView.share('limit_reading'),  
        }, -- static_text
        f:slider {
          value = LrView.bind(p..'High'),
          min = low ,
          max = high,
          integral = true,
        }, -- slider
        f:static_text {
          title = LrView.bind(p..'High'),
          alignment = 'right',
          width = LrView.share('limit_reading'),                
        }, -- static_text
        f:push_button {
          title = 'Reset to defaults',
          action = function ()
            if p == 'Temperature' and low > 0 then
              obstable.TemperatureLow = 3000
              obstable.TemperatureHigh = 9000
            else
              obstable[p..'Low'] = low
              obstable[p..'High'] = low
            end
          end,
        }, -- push_button
      }, -- row
    ) -- table.insert
  end
  return retval -- array of rows
end

--------------------------------------------------------------------------------
-- Provides min and max for given parameter and mode.
-- @param param Which parameter is being adjusted.
-- @return min, max for given param and mode.
--------------------------------------------------------------------------------
local function GetMinMax(param)
  if Parameters(param) and MIDI2LR[param..'High'] then
    return Index(MIDI2LR,param)
  else
    return LrDevelopController.getRange(param)
  end
end


return { --table of exports, setting table member name and module function it points to
  ClampValue = ClampValue,
  GetMinMax = GetMinMax,
  GetPreferences = GetPreferences,
  Index = Index,
  OptionsRows = OptionsRows,
  Parameters = Parameters,
  SavePreferences = SavePreferences,
  SavePreferencesOneMode = SavePreferencesOneMode,
}