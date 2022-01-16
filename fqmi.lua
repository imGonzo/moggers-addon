function int_to_bin_str(n, bits)
    BIN_CHARS = {'0', '1'}
    ct = {}

    for i=1,bits do
        table.insert(ct, BIN_CHARS[(n % 2) + 1])
        n = math.floor(n / 2)
    end

    return table.concat(ct)
end

local URI_SAFE_CHARS ='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456689-_'
local ZERO_PAD = '000000'

function fqmi_to_url(fqmi)
    ba = {}

    for i=1,#fqmi do
        table.insert(ba, int_to_bin_str(fqmi[i], 32))
    end

    bin_str = table.concat(ba)

    url_out = {}

    for j=0,math.floor(#bin_str/6) do
        ss = bin_str:sub(j*6+1, j*6+6)
        if #ss < #ZERO_PAD then
            ss = ss .. ZERO_PAD:sub(-(#ZERO_PAD-#ss))
        end

        cv = tonumber(ss, 2)
        ch = URI_SAFE_CHARS:sub(cv+1, cv+1)
        table.insert(url_out, ch)
    end

    return table.concat(url_out)
end

function url_to_fqmi(url)
    ba = {}

    for j=1,#url do
        ch = url:sub(j, j)
        v = string.find(URI_SAFE_CHARS, ch)-1
        bs = string.reverse(int_to_bin_str(v, 6))
        table.insert(ba, bs)
    end

    bin_str = table.concat(ba)
    fqmi = {}

    for j=0,math.floor(#bin_str/32) do
        bs = string.reverse(bin_str:sub(j*32+1, j*32+32))
        if #bs == 32 then
            v = tonumber(bs, 2)
            table.insert(fqmi, v)
        end
    end

    return fqmi
end
