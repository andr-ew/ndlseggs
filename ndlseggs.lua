-- ndlseggs
--
-- ndls + eggs
--
-- use arc key to switch scripts
--
-- version 0.0.1 @andrew
--
-- required: grid (any size)
--           arc 2025
--
-- documentation:
-- github.com/andr-ew/ndls
-- github.com/andr-ew/eggs

g = grid.connect()
a = arc.connect()

wide = g and g.device and g.device.cols >= 16 or false
tall = g and g.device and g.device.rows >= 16 or false
arc2 = a and a.device and string.match(a.device.name, 'arc 2')
arc_connected = not (a.name == 'none')

--device testing flags

-- test grid64
    -- wide = false
    -- arc2 = true
-- end test
-- test grid256
    -- wide = true
    -- tall = true
-- end test

varibright = true

--system libs

cs = require 'controlspec'
graph = require 'graph'
fileselect = require 'fileselect'
textentry = require 'textentry'
lfos = require 'lfo'

musicutil = require 'musicutil'

--git submodule libs

include 'lib/ndls/lib/crops/core'                                 --crops, a UI component framework
Grid = include 'lib/ndls/lib/crops/components/grid'
Arc = include 'lib/ndls/lib/crops/components/arc'
Enc = include 'lib/ndls/lib/crops/components/enc'
Key = include 'lib/ndls/lib/crops/components/key'
Screen = include 'lib/ndls/lib/crops/components/screen'

-- pattern_time = include 'lib/ndls/lib/pattern_time_extended/pattern_time_extended'

-- Produce = {}
-- Produce.grid = include 'lib/ndls/lib/produce/grid'                --some extra UI components

cartographer = include 'lib/ndls/lib/cartographer/cartographer'   --a buffer management library

-- patcher = include 'lib/ndls/lib/patcher/patcher'                  --modulation maxtrix
-- Patcher = include 'lib/ndls/lib/patcher/ui'                       --mod matrix patching UI utilities

pattern_time = include 'lib/eggs/lib/pattern_time_extended/pattern_time_extended' --pattern_time fork
mute_group = include 'lib/eggs/lib/pattern_time_extended/mute_group'              --pattern_time mute groups
pattern_param_factory = include 'lib/eggs/lib/pattern_time_extended/params'       --pattern_time params

Produce = {}                                                --additional components for crops
Produce.grid = include 'lib/eggs/lib/produce/grid'
Produce.screen = include 'lib/eggs/lib/produce/screen'

keymap = include 'lib/eggs/lib/keymap/keymap'                        --patterning grid keyboard
Keymap = include 'lib/eggs/lib/keymap/ui'

tune = include 'lib/eggs/lib/tune/tune'                              --diatonic tuning lib
tunings, scale_groups = include 'lib/eggs/lib/tune/scales'
Tune = include 'lib/eggs/lib/tune/ui'
channels = include 'lib/eggs/lib/channels'                           --tuning class

arqueggiator = include 'lib/eggs/lib/arqueggiator/arqueggiator'      --arqueggiation (arquencing) lib
Arqueggiator = include 'lib/eggs/lib/arqueggiator/ui'

patcher = include 'lib/eggs/lib/patcher/patcher'                     --modulation maxtrix
Patcher = include 'lib/eggs/lib/patcher/ui/using_source_keys'        --mod matrix patching UI utilities

nb = include 'lib/eggs/lib/nb/lib/nb'                                --nb

--script files (ndls)

metaparams = include 'lib/ndls/lib/metaparams'               --abstraction around params
windowparams = include 'lib/ndls/lib/windowparams'           --abstraction around params
include 'lib/ndls/lib/globals'                               --global variables

--TODO: no LFOs rn
-- mod_src = include 'lib/ndls/lib/modulation-sources'               --add modulation sources
sc, reg = include 'lib/ndls/lib/softcut'                     --softcut utilities
ndls_params = include 'lib/ndls/lib/params'                   --ndls params
Components = include 'lib/ndls/lib/ui/components'            --ndls's custom UI components
Ndls = {}
Ndls.grid = include 'lib/ndls/lib/ui/grid'                    --grid UI
Ndls.arc = include 'lib/ndls/lib/ui/arc'                      --arc UI
Ndls.norns = include 'lib/ndls/lib/ui/norns'                  --norns UI

--script files (eggs)

eggs = include 'lib/eggs/lib/globals'                                --global variables & objects

eggs.engines = include 'lib/eggs/lib/engines'                        --DEFINE NEW ENGINES IN THIS FILE
eggs.setup = include 'lib/eggs/lib/setup'                            --setup functions
eggs.params = include 'lib/eggs/lib/params'                          --script params

destination = include 'lib/eggs/lib/destinations/destination'        --destination prototype
jf_dest = include 'lib/eggs/lib/destinations/jf'                     --just friends output
midi_dest = include 'lib/eggs/lib/destinations/midi'                 --midi output
engine_dest = include 'lib/eggs/lib/destinations/engine'             --engine output
nb_dest = include 'lib/eggs/lib/destinations/nb'                     --nb output
crow_dests = include 'lib/eggs/lib/destinations/crow'                --crow output

Eggs_components = include 'lib/eggs/lib/ui/components'                    --ui components
Eggs = {}
Eggs.grid = include 'lib/eggs/lib/ui/grid'                            --grid UI
Eggs.norns = include 'lib/eggs/lib/ui/norns'                          --norns UI

script_focus = 'eggs'

--setup

eggs.setup.destinations()
local add_actions = eggs.setup.modulation_sources()
local crow_add = eggs.setup.crow(add_actions)

--ndlseggs tweaks

--NOTE: it doesn't overwrite anything
local function merge(t1, t2)
    for k2,_ in pairs(t2) do
        if t1[k2] then
            if type(t1[k2]) == 'table' and type(t2[k2]) == 'table' then
                merge(t1[k2], t2[k2])
            end
        else
            t1[k2] = t2[k2]
        end
    end
end

merge(Components, Eggs_components)

eggs.img_path = norns.state.lib..'eggs/lib/img/'

local initialized = false
do
    local ndls_read = params.action_read
    params.action_read = function(...) 
        eggs.params.action_read(...) 
        if initialized then ndls_read(...) end
    end
    local ndls_write = params.action_write
    params.action_write = function(...) 
        eggs.params.action_write(...)
        ndls_write(...)
    end
    local ndls_delete = params.action_delete
    params.action_delete = function(...) 
        eggs.params.action_delete(...)
        ndls_delete(...)
    end
end

mod_src = {}
do
    local src = {}
    do
        src.crow = {}
        --dummy
        function src.crow.update() end
    end

    do
        src.lfos = {}
        
        for i = 1,2 do
            --TODO: update to new syntax so LFOs work
            -- local action = patcher.add_source('lfo '..i, 0)

            src.lfos[i] = lfos:add{
                min = -5,
                max = 5,
                depth = 0.1,
                mode = 'free',
                period = 0.25,
                baseline = 'center',
                -- action = action,
            }
        end

        src.lfos.reset_params = function()
            for i = 1,2 do
                params:set('lfo_mode_lfo_'..i, 2)
                -- params:set('lfo_max_lfo_'..i, 5)
                -- params:set('lfo_min_lfo_'..i, -5)
                params:set('lfo_baseline_lfo_'..i, 2)
                params:set('lfo_lfo_'..i, 2)
            end
        end
    end

    mod_src = src
end

--dummy
Patcher.screen.last_connection = function() return function() end end

--params stuff pre-init

-- params.action_read = eggs.params.action_read
-- params.action_write = eggs.params.action_write
-- params.action_delete = eggs.params.action_delete

ndls_params.add_audio_params()

params:add_separator('destination')
eggs.params.add_destination_params()

params:add_separator('sep_engine', 'engine')
eggs.params.add_engine_selection_param()

params:read(nil, true) --read a first time before init to check the engine
params:lookup_param('engine_eggs'):bang()

--create UI components

local App = {}

function App.norns()
    local _ndls = Ndls.norns()
    local _eggs = Eggs.norns()

    return function()
        if script_focus == 'eggs' then
            _eggs()
        else
            _ndls()
        end
    end
end

function App.grid()
    local _ndls = Ndls.grid{
        wide = wide, tall = tall,
        varibright = varibright 
    }
    local _eggs = Eggs.grid{
        wide = wide
    }

    return function()
        if script_focus == 'eggs' then
            _eggs()
        else
            _ndls()
        end
    end
end

function App.arc()
    local _ndls = Ndls.arc{
        map = not arc2 and { 'gain', 'cut', 'st', 'len' } or { 'st', 'len', 'gain', 'cut' }, 
        rotated = arc2,
        grid_wide = wide,
    }

    return function()
        _ndls()
    end
end
    
--connect UI components
local _norns = App.norns()
crops.connect_enc(_norns)
crops.connect_key(_norns)
screen_clock = crops.connect_screen(_norns, fps.screen)

--init/cleanup

function init()

    nb:init()

    eggs.params.add_all_track_params()

    -- include 'lib/ndls/lib/params' --create ndls params (incl patcher, pset params)

    --connect UI components
    crops.connect_arc(App.arc(), a, fps.arc)

    -- params:add_separator('patcher')
    -- params:add_group('assignments', #patcher.destinations)
    -- patcher.add_assignment_params(function() 
    --     crops.dirty.grid = true; crops.dirty.screen = true
    -- end)
    -- eggs.params.add_pset_params()
    ndls_params.add_patcher_params()
    ndls_params.add_pset_params()
    
    mod_src.lfos.reset_params()
    for i = 1,2 do mod_src.lfos[i]:start() end

    sc.init()

    initialized = true

    params:read()
    params:bang()
    
    crow_add()

    eggs.setup.init()

    -- crops.connect_grid(_app.grid, g, 240)
    
    --connect UI components
    crops.connect_grid(App.grid(), g, fps.grid)
end

function cleanup()
    if params:string('autosave pset') == 'yes' then params:write() end
end

