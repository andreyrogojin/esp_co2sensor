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
	else return 'text/plain'
	end
end

function list_file(template)
	local lst = {}
	local sizes = {}
	for name,size in pairs(file.list()) do
		if name:match(template or '.*') then
			lst[#lst+1] = name
			sizes[name] = size
		end
	end
	return lst,sizes
end

srv = net.createServer(net.TCP)

function receiver(sck, data)
	-- print(data)
	local url = data:match('^GET (.+) HTTP/') or data:match('^POST (.+) HTTP/')
	if not url then sck:close() return end
	local filename = url:match('^.*/([^/]+)$')
	local extention = url:match('^.*/[^/]+[.]([^/]+)$')
	local payload = data:match('.*\r?\n\r?\n(.*)$')
	if not filename then
		filename = 'graf.html'
		extention = 'html'
	end
	-- print(url, payload)

	if filename:match('^list$') or filename:match('^list%..*$') then
		local lst,sizes = list_file()
		local num = 1
		local ishtml = extention == 'html' or extention == 'htm'
		if ishtml then
			for i,name in pairs(lst) do
				lst[i] = ('<a href="%s">%s</a>%s<br>\n'):format(name, name, sizes[name])
			end
			lst[0] = '<html><body>\n'
			num = 0
			lst[#lst+1] = '</body></html>'
		else
			for i,name in pairs(lst) do
				lst[i] = ('%s\t%s\n'):format(name, sizes[name])
			end
		end

		sck:on('sent', function(lsck)
			if num > #lst then lsck:close() return end
			lsck:send(lst[num])
			num = num + 1
		end)
		sck:send(ok_headers_template:format(ctype(extention)))
		
	elseif filename:match('^list_data') then
		local lst,sizes = list_file('^d.*\.csv')
		local ishtml = extention == 'html' or extention == 'htm'
		table.sort(lst, function(a,b) return a > b end)
		local num = 1
		if ishtml then
			for i,name in pairs(lst) do
				lst[i] = ('<a href="%s">%s</a>%s<br>\n'):format(name, name, sizes[name])
			end
			lst[0] = '<html><body>'
			num = 0
			lst[#lst+1] = '</body></html>'
		end
		sck:on('sent', function(lsck)
			if num > #lst then lsck:close() return end
			lsck:send(lst[num]..'\n')
			num = num + 1
		end)
		sck:send(ok_headers_template:format(ctype(extention)))
		
	elseif filename == 'startnew' and not datafile then
		local dt = rtctime.epoch2cal(rtctime.get())
		local name = ('d%04d%02d%02d%02d%02d.csv'):format(dt.year, dt.mon, dt.day, dt.hour, dt.min)
		datafile = file.open(name, 'w')
		sck:on('sent', function(lsck) sck:close() end)
		sck:send(ok_headers_template:format('text/plain')..name..'\n')

	elseif filename == 'stopnew' and datafile then
		datafile:close()
		datafile = nil
		if datasocket then
			datasocket:close()
			datasocket = nil
		end
		measurements = 0
		sck:on('sent', function(lsck) lsck:close() end)
		sck:send(ok_headers_template:format('text/plain')..'END')

	elseif filename:match('^settime\.%d+') then
		rtctime.set(extention)
		local dt = rtctime.epoch2cal(rtctime.get())
		sck:on('sent', function(lsck) sck:close() end)
		sck:send(ok_headers_template:format('text/plain')..
				 ('%02d.%02d.%04d %02d:%02d\n'):format(dt.day, dt.mon, dt.year, dt.hour, dt.min))
	
	elseif filename == 'getcurrent' and datafile then
		sck:on('sent', function(s)
			s:on('sent', nil)
			datasocket = s
			s:on('disconnection', function(s) datasocket = nil end)
		end)
		sck:send(ok_headers_template:format('text/csv'))
		
	else
	    local dfile = file.open(filename)
	    if not dfile then
		    sck:on('sent', function(s) s:close() end)
		    sck:send(notfound)
		else
			sck:on('sent', function(lsck)
				local data = dfile:read()
				if data then
					lsck:send(data)
				else
					dfile:close()
					lsck:close()
				end
			end)
			sck:send(ok_headers_template:format(ctype(extention)))
		end
    end
end

srv:listen(80, function(conn)
	conn:on('receive', receiver)
end)
