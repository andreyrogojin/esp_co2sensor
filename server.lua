-- wifi.setmode(1,false)
-- wifi.sta.config({ssid='SPrint2', pwd='1223334444', auto=false, save=false})
-- wifi.sta.connect(function() print('connected') end)

wifi.setmode(wifi.SOFTAP, false)

notfound = ('HTTP/1.0 404 Not Found\r\n'..
			'Server: ESP\r\n'..
			'Content-Type: text/plain\r\n\r\n'..
			'File not found\r\n')
ok_headers_template = ('HTTP/1.0 200 OK\r\n'..
			'Server: ESP\r\n'..
			'Content-Type: %s\r\n'..
			'Access-Control-Allow-Origin: *\r\n\r\n')

local function ctype(ext)
	if ext == 'html' or ext == 'htm' then return 'text/html'
	elseif ext == 'txt' then return 'text/plain'
	elseif ext == 'csv' then return 'text/csv'
	end
end

srv = net.createServer(net.TCP)

function receiver(sck, data)
	-- print(data)
	local url = data:match('^GET (.+) HTTP/')
	local filename = url:match('^.*/([^/]+)$')
	local extention = url:match('^.*/[^/]+[.]([^/]+)$')
	if not filename then
		filename = 'index.html'
		extention = 'html'
	end
	-- print(url, filename, extention)

	if filename == 'index.html' then
		local lst = {}
		for f,l in pairs(file.list()) do lst[#lst+1] = f end
		lst[0] = '<html><body>\n'
		lst[#lst+1] = '</body></html>'

		local num = 0
		sck:on('sent', function(lsck)
			if num > #lst then lsck:close() return end
			lsck:send(('<a href="%s">%s</a><br/>\n'):format(lst[num], lst[num]))
			num = num + 1
		end)
		sck:send(ok_headers_template:format('text/html'))
	elseif filename:match('^settime\.%d+') then
		rtctime.set(extention)
		sck:close()
		return
	else
	    local dfile = file.open(filename)
	    if not dfile then
		    sck:on('sent', function(s) s:close() end)
		    sck:send(notfound)
		    return
	    end
	    sck:on('sent', function(lsck)
		    local data = dfile:read()
		    if data then
			    lsck:send(data)
		    else
			    lsck:close()
			    dfile:close()
		    end
	    end)
	    sck:send(ok_headers_template:format(ctype(extention)))
    end
end

srv:listen(80, function(conn)
	conn:on('receive', receiver)
end)
