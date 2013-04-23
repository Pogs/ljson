package.path = './?.lua;' .. package.path

local ljson = require("ljson")

local function test_read_array()
    local arr = ljson.read("[]")
    assert(ljson.is_array(arr))

    local arr = ljson.read("[2,3,5]")
    assert(#arr == 3)
    assert(arr[1] == 2)
    assert(arr[2] == 3)
    assert(arr[3] == 5)
end

local function test_read_constant()
    assert(ljson.read("true") == true)
    assert(ljson.read("false") == false)
    assert(ljson.read("null") == ljson.null)
end

local function test_read_number()
    assert(ljson.read("0") == 0)
    assert(ljson.read("42") == 42)
end

local function test_read_object()
    local obj = ljson.read("{}")
    assert(ljson.is_object(obj))
    
    local obj = ljson.read('{"the":true,"dude":false,"abides":null}')
    assert(obj.the == true)
    assert(obj.dude == false)
    assert(obj.abides == ljson.null)
end

local function test_read_string()
    assert(ljson.read("\"\"") == "")
    assert(ljson.read("\"The Dude abides.\"") == "The Dude abides.")
    assert(ljson.read("\"\\\"\\\\\\/\"") == "\"\\/")
    assert(ljson.read("\"\\b\\f\\n\\r\\t\"") == "\b\f\n\r\t")
end

local function test_skip_comment()
    assert(ljson.read("13 // thirteen") == 13)
    assert(ljson.read("// thirteen\n13") == 13)

    assert(ljson.read("/* forty */ 42 /* two */") == 42)
    assert(ljson.read([[
                         /*
                          * forty-two
                          */
                         42
                       ]]) == 42)
end

local function test_write_array()
    assert(ljson.write({2, 3, 5}) == "[2, 3, 5]")
end

local function test_write_constant()
    assert(ljson.write(true) == "true")
    assert(ljson.write(false) == "false")
    assert(ljson.write(nil) == "null")
    assert(ljson.write(ljson.null) == "null")
end

local function test_write_number()
    assert(ljson.write(0) == "0")
    assert(ljson.write(-1) == "-1")
    assert(ljson.write(42) == "42")
    assert(ljson.write(3.14) == "3.14")
end

local function test_write_object()
    assert(ljson.write({the = 2, dude = 3, abides = 5}) ==
           '{"abides": 5, "dude": 3, "the": 2}')
end

local function test_write_string()
    assert(ljson.write("The Dude abides.") == '"The Dude abides."')
end

local function test()
    test_read_array()
    test_read_constant()
    test_read_number()
    test_read_object()
    test_read_string()
    test_skip_comment()
    test_write_array()
    test_write_constant()
    test_write_number()
    test_write_object()
    test_write_string()
end

test()
