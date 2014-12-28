-- Converter for Andy Nobel's Blitz Basic Manic Miner to Love2D
-- by Rob Probin, Dec 2014
-- Copyright © 2014 Rob Probin

local manic_miner_url = "http://retrospec.sgn.net/download.php?link=mm&url=http://www.retrospec.sgn.net/users/anoble/files/ManicBB.zip"
local mmf = "ManicBB.zip"

bb_parser = require("utilities/bb_parser")

function love.load(arg)
    if arg[#arg] == "-debug" then require("mobdebug").start() end
    --[[
    --if love.filesystem.exists("MANIC") and love.filesystem.isDirectory("MANIC") then
    --    print("Got folder")
    if not (love.filesystem.exists(mmf) and love.filesystem.isFile(mmf)) then
        -- http://stackoverflow.com/questions/5477582/lua-love2d-how-can-i-make-it-download-a-file
        print("Download ManicBB.zip file")
        local http = require("socket.http")
        local b, c, h = http.request(manic_miner_url)
        if c ~= 200 then
            print("Couldn't download file")
            love.event.quit()
            return
        end
        love.filesystem.write("ManicBB.zip", b)
    end
    
    print("Got zip file")
    --print(love.filesystem.getSaveDirectory( ))
    local success = love.filesystem.mount(mmf, "content")
    if not success then
        print("Couldn't mount ", mmf)
        assert(success)
    end
    --local files = love.filesystem.enumerate("content"), pre-0.9
    --local files = love.filesystem.getDirectoryItems("content")
    --for k, file in ipairs(files) do
    --    print(k .. ". " .. file) --outputs something like "1. main.lua"
    --end
    local src_f = "content/MANIC/source.zip"
    assert(love.filesystem.exists(src_f))
    success = love.filesystem.mount(src_f, "src")
    if not success then
        print("Couldn't mount ", src_f)
        assert(success)
    end
    local files = love.filesystem.getDirectoryItems("src")
    for k, file in ipairs(files) do
        print(k .. ". " .. file) --outputs something like "1. main.lua"
    end
    --]]
    
    local context = bb_parser("MANIC/", "MANIC/source/", "mm-main.bb")
    if context.load_error then
        love.event.quit()
    end
    print("Code so far:")
    for _,v in ipairs(context.code) do
        print("  "..v)
    end
end

function love.draw()
    --local major, minor, revision, codename = love.getVersion();
    --local str = string.format("Version %d.%d.%d - %s", major, minor, revision, codename);
    --love.graphics.print(str, 20, 20);    
    love.graphics.print(_VERSION, 20, 20);    
end

