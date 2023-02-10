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

function newDatafile()
	if not datafile then
		local dt = rtctime.epoch2cal(rtctime.get())
		datafile = {}
		datafile.name = (('d%04d%02d%02d%02d%02d.csv')
							:format(dt.year, dt.mon, dt.day, dt.hour, dt.min))
		datafile.fd = file.open(dfname, 'w')
		datafile.fd:writeline(('#Start: %02d.%02d.%4d %2d:%02d')
							:format(dt.day, dt.mon, dt.year, dt.hour, dt.min))
		datafile.fd:writeline('#Interval: 5s')
		datafile.fd:writeline('co2ppm,t,Rh')
		ind:setDcode(5,0x80)
	end
end

function stopRecord()
	if datafile then 
		datafile.fd:close()
		if datafile.socket then datafile.socket:close() end
		datafile = nil
		measurements = 0
		ind:setDcode(5,0x0)
	end
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

	if filename:match('^list_data') then
		local lst,sizes = list_file('^d.*\.csv')
		table.sort(lst, function(a,b) return a > b end)
		local num = 1
		sck:on('sent', function(lsck)
			if num > #lst then lsck:close() return end
			lsck:send(lst[num]..'\n')
			num = num + 1
		end)
		sck:send(ok_headers_template:format(ctype(extention)))
		
	elseif filename == 'startnew' then
		newDatafile()
		sck:on('sent', function(lsck) sck:close() end)
		sck:send(ok_headers_template:format('text/plain')..dfname)

	elseif filename == 'stopnew' then
		stopRecord()
		sck:on('sent', function(lsck) lsck:close() end)
		sck:send(ok_headers_template:format('text/plain')..'END')

	elseif filename:match('^settime\.%d+') then
		rtctime.set(extention)
		local dt = rtctime.epoch2cal(rtctime.get())
		sck:on('sent', function(lsck) sck:close() end)
		sck:send(ok_headers_template:format('text/plain')..
				 ('%02d.%02d.%04d %02d:%02d\n'):format(dt.day, dt.mon, dt.year, dt.hour, dt.min))

	elseif filename == 'delete' and payload then
		if payload ~= datafile.name then
			file.remove(payload)
		end
	
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
					if filename == datafile.name then
						datafile.socket = lsck
						datafile.socket:on('sent', nil)
						datafile.socket:on('disconnection', function(s) datafile.socket = nil end)
					else
						lsck:close()
					end
				end
			end)
			sck:send(ok_headers_template:format(ctype(extention)))
		end
    end
end

srv:listen(80, function(conn)
	conn:on('receive', receiver)
end)
