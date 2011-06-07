package.path = package.path .. ';../?/init.lua;../?.lua'
local request = require 'mongrel2.request'

local payloads = {}

for line in io.lines('request_payloads.txt') do
    table.insert(payloads, line)
end

context('m2-lua', function()
    context('request', function()
        context('parser sanity', function()
            for _, msg in pairs(payloads) do
                 test(msg, function()
                     local req, err = request.parse(msg)
                     assert_nil(err)
                     assert_not_nil(req)
                 end)
            end
        end)
    end)
end)
