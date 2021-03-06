-- Blitz Basic Parser for Manic Miner code by Andy Noble.
-- Copyright © 2014 Rob Probin
--[[
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details. 

   You should have received a copy of the GNU General Public License along
   with this program; if not, write to the Free Software Foundation, Inc.,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
--]]

class = require("utilities/middleclass")

local BB_Context = class("BB_Context")

function BB_Context:initialize()
    self.load_error = false
    self.defined_functions = {}
    self.undefined_functions = {}
    self.undefined_function_count = 0
    self.defined_variables = {}
    self.undefined_variables = {}
    self.undefined_variables_count = 0
    self.globals = {}
    self.nest_stack = {}
    self.code = {}

    self:add_external_function("LoadImage")
    self:add_external_function("LoadAnimImage")
    self:add_external_function("LoadSound")
    self:add_external_function("CreateImage")
    self:add_external_function("LoadHiScore")
end

function BB_Context:add_external_function(name)
    self.defined_functions[name] = true
end


function BB_Context:show_line(line)
    print("["..self.filename.." LINE "..self.line_num.."] "..line)
end

function BB_Context:failed(line, msg)
    print(msg)
    self:show_line(line)
    self.load_error = true
end

-- also called trim
local function strip(s)
    -- from PiL2 20.4
    local str = s:gsub("^%s*(.-)%s*$", "%1")
    return str
end

function BB_Context:do_Include(line)
    local filename = line:match('^%s*Include%s*"(.+)"%s*$')
    if filename then
        --print("Parsing: ", filename)
        local old_ln = self.line_num
        local old_filename = self.filename
        self:bb_parser(filename)
        self.line_num = old_ln
        self.filename = old_filename
    else
        print("Problem with getting filename from Include")
        self:show_line(line)
        self.load_error = true
    end
end


local token_dispatch

function BB_Context:do_function_definition(line)
    local name, parameters = line:match('^%s*Function%s*([_%a][_%w]*)%s*%((.*)%)%s*$')
    if not name or not parameters then
        print("Match failed")
        self:show_line(line)
        self.load_error = true
    elseif token_dispatch[name] then
        print("Known token")
        self:show_line(line)
        self.load_error = true
    else
        table.insert(self.nest_stack, { "Function" } )
        local p = self.parse_params(parameters)
        if p then
            table.insert(self.code, string.format("def %s(%s)", name, p))
        else
            self:failed("Couldn't parse parameters in function definition")
        end
    end
    
end

function BB_Context:check_solo_keyword(line, keyword)
    local i = line:match("^%s*([^%s]*)%s*$")
    if not i or i ~= keyword then
        print("Keyword should be alone", keyword)
        self:show_line(line)
        self.load_error = true
    end
    
    return i
end

function BB_Context:do_DoBoot(line)
    if self:check_solo_keyword(line, "DoBoot") then
        table.insert(self.code, "DoBoot()")
    end
end

function BB_Context:do_AppTitle(line)
    local m = line:match('^%s*AppTitle%s*"(.*)"%s*$')
    if m then
        table.insert(self.code, 'love.window.setTitle("' .. m .. '")')
    else
        self:failed(line, "AppTitle problem")
    end

end

function BB_Context:do_Graphics(line)
    local m = line:match('^%s*Graphics%s*(.*)%s*$')
    if m then
        local p = self:parse_params(m)
        if p and #p == 4 then
            local width = p[1]
            local height = p[2]
            local depth = p[3]      -- 0=best mode. Optional parameter.
            local full_screen_mode = p[4]   -- 0=auto, 1=fullscreen, 2=window. Optional parameter.
            local flags = 0
            local s = string.format("local success = love.window.setMode( %d, %d, %d )",
                width, height, flags)
            table.insert(self.code, s)
        else
            self:failed(line, "Failed to parse params")
        end
    else
        self:failed(line, "Failed to get params")
    end
    
end

local variable_pattern = '[_%a][_%w]*%%?#?%$?'

function BB_Context:do_Global(line)
    local m = line:match('^%s*Global%s*(.*)%s*$')
    if m then
        local success = self:do_variable_assignment(m, true)
        if not success then
            if m:find('^'..variable_pattern..'$') then
                m = self:make_safe_identifier(m)
                self.globals[m] = true
            else
                self:failed(line, "Global didn't understand identifer")
            end
        end
    else
        self:failed(line, "Global failed")
    end
end

function BB_Context:do_Dim(line)
    local id, size = line:match('^%s*Dim%s*('..variable_pattern..')%s*%((.*)%)%s*$')
    if id and size then
        id = self:make_safe_identifier(id)
        local code = string.format("%s = {} -- %s", id, size)
        table.insert(self.code, code)
        self.globals[id] = true
    else
        self:failed(line, "Dim failed")
    end
end

function BB_Context:simple_func(line, token, output)
    if line:find('^%s*'..token..'%s*$') then
        table.insert(self.code, output)
        return true
    else
        self:failed(line, "Line not understood with "..token)
        return false
    end
end

function BB_Context:simple_func1(line, token, output)
    local param = line:match('^%s*'..token..'%s*([^%s]*)%s*$')
    if param then
        param = strip(param)
    end
    if param and param ~= "" then
        if output then
            table.insert(self.code, output)
        end
        return param
    else
        self:failed(line, "Line not understood with "..token)
    end
end

function BB_Context:do_Repeat(line)
    local success = self:simple_func(line, "Repeat", "repeat")
    table.insert(self.nest_stack, {"Repeat"} )
    table.insert(self.code, "repeat")
end

function BB_Context:do_Select(line)
    local param = self:simple_func1(line, "Select", "--Select")
    if not param then
        param = ""
    end
    table.insert(self.nest_stack, { "Select", param } )
end

function BB_Context:do_Case(line)
    if #self.nest_stack == 0 then
        self:failed(line, "Case with no select")
        return
    end
    local nest_data = self.nest_stack[#self.nest_stack]
    if nest_data[1] ~= "Select" then
        self:failed(line, "Case with no select")
        return
    end
    local var = nest_data[2]
    local value = strip(line:match("^%s*Case(.*)"))
    if value == nil or value == "" then
        self:failed(line, "Select with no value")
        return
    end
    local second_case = nest_data[3]
    
    if not second_case then
        table.insert(self.code, string.format("if %s == %s then", var, value))
    else
        table.insert(self.code, string.format("elseif %s == %s then", var, value))
    end
    
    -- ensure future ones are elseif
    nest_data[3] = true
    self.nest_stack[#self.nest_stack] = nest_data
end

function BB_Context:do_End(line)
    local value = strip(line:match("^%s*End(.*)"))
    if #self.nest_stack == 0 then
        -- only one case where End without a counterpart is allowed ... program end.
        if value ~= "" then
            self:failed(line, "Unexpected End statement")
        end
        return
    end
    local nest_data = self.nest_stack[#self.nest_stack]
    local endtype = nest_data[1]
    if endtype ~= value then
        self:failed(line, "End statement is not matching " .. endtype)
        return
    end 
    table.insert(self.code, "end")
    table.remove(self.nest_stack)
end

function BB_Context:do_Until(line)
    if #self.nest_stack == 0 then
        self:failed(line, "Unexpected Until statement")
        return
    end
    local nest_data = self.nest_stack[#self.nest_stack]
    local endtype = nest_data[1]
    if endtype ~= "Repeat" then
        self:failed(line, "Until statement is not matching Repeat")
        return
    end
    local expr = strip(line:match("^%s*Until(.*)"))
    if expr == nil or expr == "" then
        self:failed(line, "Until statement has no expression")
        return
    end
    table.remove(self.nest_stack)
    local e = self:parse_expression(expr)
    if e then
        table.insert(self.code, string.format("until %s", e))
    else
        self:failed("Couldn't parse expression in Until statement")
    end
end


function BB_Context:do_If(line)
    local expr = strip(line:match("^%s*If(.*)"))
    if expr == nil or expr == "" then
        self:failed(line, "If with no expression")
        return
    end
    table.insert(self.nest_stack, { "If" } )
    local e = self:parse_expression(expr)
    if e then
        table.insert(self.code, string.format("if %s then", e))
    else
        self:failed("Couldn't parse expression in If statement")
    end
end

function BB_Context:not_implemented(line)
    --self:failed(line, "NOT IMPLEMENTED")
    table.insert(self.code, string.format('not_implemented("%q")', line))
end


token_dispatch = {
    [";"] = function() end,
    -- this functions is a call, but without brackets. We just parse this as a 
    -- keyword for the moment. It would be relatively easy to make it parse 
    -- correctly but would make spotting new keywords harder.
    DoBoot = BB_Context.do_DoBoot,

    -- normal statements
    AppTitle = BB_Context.do_AppTitle,
    Include = BB_Context.do_Include,
    Function = BB_Context.do_function_definition,
    Graphics = BB_Context.do_Graphics,
    Global = BB_Context.do_Global,
    Dim = BB_Context.do_Dim,
    Repeat = BB_Context.do_Repeat,
    Select = BB_Context.do_Select,
    Case = BB_Context.do_Case,
    End = BB_Context.do_End,
    If = BB_Context.do_If,
    Until = BB_Context.do_Until,
    
    --
    -- these are functions we haven't yet coded up Lua translations for
    --
    ["."] = BB_Context.not_implemented,
    Data = BB_Context.not_implemented,
    Else = BB_Context.not_implemented,
    StopChannel = BB_Context.not_implemented,
    While = BB_Context.not_implemented,
    Wend = BB_Context.not_implemented,
    SetBuffer = BB_Context.not_implemented,
    Flip = BB_Context.not_implemented,
    For = BB_Context.not_implemented,
    Next = BB_Context.not_implemented,
    Return = BB_Context.not_implemented,
    Color = BB_Context.not_implemented,
    Rect = BB_Context.not_implemented,
    WriteInt = BB_Context.not_implemented,
    CloseFile = BB_Context.not_implemented,
    PauseChannel = BB_Context.not_implemented,
    ResumeChannel = BB_Context.not_implemented,
    Plot = BB_Context.not_implemented,
    Line = BB_Context.not_implemented,
    WritePixelFast = BB_Context.not_implemented,
    ClsColor = BB_Context.not_implemented,
    Cls = BB_Context.not_implemented,
    SoundPitch = BB_Context.not_implemented,
    PlaySound = BB_Context.not_implemented,
    Restore = BB_Context.not_implemented,
    Read = BB_Context.not_implemented,
}


function BB_Context:parse_params(params)
    params = strip(params)
    local new_params = {}
    if #params == 0 then
        -- nothing
        return new_params
    end
    
    local i = 1
    repeat
        local s = params:find(",", i)
        if s then
            table.insert(new_params, strip(params:sub(i, s-1)))
            i = s+1
        end 
    until not s
    table.insert(new_params, strip(params:sub(i)))
    
    return new_params
end

function BB_Context:do_function_call(line)
    -- check for function of the form:
    -- "  name   ( params  )   "
    local func, params = line:match("^%s*([_%a][_%w]*)%s*%((.*)%)%s*$")
    if not func then
        return nil
    end
    
    if func and not self.defined_functions[func] then
        self.undefined_functions[func] = true
        self.undefined_function_count = self.undefined_function_count + 1
    end
    new_params = self:parse_params(params)
    if new_params then
        table.insert(self.code, func .. "(" .. table.concat(new_params, ", ") .. ")")
    else
        return nil
    end
    
    return func
end

function BB_Context:make_safe_identifier(id)
    id = strip(id)
    local c = id:sub(-1)
    if c == "$" then
        id = id:sub(1, -2) .. "_str"
    elseif c == "%" or c == "#" then
        id = id:sub(1, -2)
    end
    
    return id
end

function BB_Context:parse_expression(expression)
    local exp = expression:match("^%s*([_%w]*%$?)%s*$")
    if exp then
        -- simple expression
        return self:make_safe_identifier(exp)
    end
    
    exp = expression:match('^%s*(".*")%s*$')
    if exp then
        return exp
    end
    
    -- function expression?
    -- "  name   ( params  )   "
    local func, params = expression:match("^%s*([_%a][_%w]*)%s*%((.*)%)%s*$")    -- used to ignore everything after ')'
    if not func then
        return nil
    end
    
    if func and not self.defined_functions[func] then
        self.undefined_functions[func] = true
        self.undefined_function_count = self.undefined_function_count + 1
    end
    new_params = self:parse_params(params)
    if new_params then
        exp = func .. "(" .. table.concat(new_params, ", ") .. ")"
    else
        exp = nil
    end
      
    return exp
end

function BB_Context:do_variable_assignment(line, global)
    -- check for function of the form:
    -- "  name   =   text   "
    local exp
    local m
    --local m,  = line:match("^%s*([_%a][_%w]*%$?)%s*=%s*[_%w]+%s*$")
    --if not m then
        -- check for assignment from complex expression
        local m2
        m, index, m2 = line:match("^%s*([_%a][_%w]*%$?)%s*%(?(.*)%)?=(.+)$")
        if m2 then
            exp = self:parse_expression(m2)
        end
    --end
    
    if exp then
        m = self:make_safe_identifier(m)
        if self.globals[m] then
            global = true
        elseif global then
            self.globals[m] = true
        end
        
        if not global then
            m = 'local '..m
        end
        if not index then
            index = ""
        elseif index ~= "" then
            index = "["..index.."]"
        end
        table.insert(self.code, m  .. index .. "=" .. exp)
        return true
    else
        if m then
            self:failed(line, "Didn't understand assignment")
        end
        return false
    end
end

function BB_Context:get_initial_token(line)
    local c = line:match("^%s*([_%w]+)")
    if c then
        return c
    end
    local k = line:match("^%s*(.)")
    return k
end

function BB_Context:process_line(line)
    if line:find("^%s*$") then
        -- blank lines are ok
    else
        local token = self:get_initial_token(line)
        if token then
            local f = token_dispatch[token]
            if f then
                f(self, line)
            elseif self:do_function_call(line) then
                --print("FUNCTION CALL:", line)
            elseif self:do_variable_assignment(line) then
                --print("ASSIGNMENT:", line)
            else
                print("Error - unknown")
                self:show_line(line)
                print(token)
                self.load_error = true
            end
        else
            print("Didn't find token")
            self:show_line(line)
            self.load_error = true
        end
    end
end

function BB_Context:bb_parser(src_file)
    self.line_num = 1
    self.filename = src_file
    for line in love.filesystem.lines(self.src_dir .. src_file) do
        self:process_line(line)
        if self.load_error then
            break
        end
        self.line_num = self.line_num + 1
    end
    
    if self.undefined_function_count ~= 0 then
        self.load_error = true
        print("Undefined functions:")
        for k,_ in pairs(self.undefined_functions) do
            print("  "..k)
        end
    end
    
    if self.undefined_variables_count ~= 0 then
        self.load_error = true
        print("Undefined variables:")
        for k,_ in pairs(self.undefined_variables) do
            print("  "..k)
        end
    end
end

function bb_parser(data_dir, src_dir, src_file)
    local context = BB_Context:new()
    context.data_dir = data_dir
    context.src_dir = src_dir
    context:bb_parser(src_file)
    return context
end


return bb_parser
