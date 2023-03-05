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
		if dt.year > 2000 then
			datafile.name = (('d%04d%02d%02d%02d%02d.csv')
								:format(dt.year, dt.mon, dt.day, dt.hour, dt.min))
		else
			local num = 1
			while file.exists(('d%012d.csv'):format(num)) do num = num + 1 end
			datafile.name = ('d%012d.csv'):format(num)
		end
		datafile.fd = file.open(datafile.name, 'w')
		datafile.fd:writeline(('#Start: %02d.%02d.%4d %2d:%02d')
							:format(dt.day, dt.mon, dt.year, dt.hour, dt.min))
		datafile.fd:writeline('#Interval: 5s')
		datafile.fd:writeline('co2ppm,t,Rh')
		ind:setBit(5, 7, 1)
	end
end

function stopRecord()
	if datafile then 
		datafile.fd:close()
		datafile.fd = nil
		if datafile.socket then datafile.socket:close() end
		datafile = nil
		measurements = 0
		ind:setBit(5, 7, 0)
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
		sck:send(ok_headers_template:format('text/plain')..datafile.name)

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
		if dt.year > 2000 then ind:setBit(5, 6, 0) end

	elseif filename == 'delete' and payload then
		if datafile and payload == datafile.name then
			stopRecord()
		end
		file.remove(payload)
	
	elseif filename:match('^calibrate\.%d+') then
		caltimer1 = tmr.create()
		state = 1
		caltimer1:alarm(500, tmr.ALARM_AUTO,
			function()
				if state == 1 then
					state = 0
					ind:setLuminance(1)
				else
					state = 1
					ind:setLuminance(4)
				end
			end)
		tmr.create():alarm(179000, tmr.ALARM_SINGLE,
			function()
				rdtimer:stop()
				ind:setStr('----')
			end)
		tmr.create():alarm(181000, tmr.ALARM_SINGLE,
			function()
				caltimer1:stop()
				caltimer1:unregister()
				caltimer1 = nil
				ind:setLuminance(4)
				ind:setStr(('%4d'):format(cal_correction))
				cal_correction = nil
				scd40:start_periodic_measurement()
				rdtimer:start()
			end)
		scd40:perform_forced_recalibration(extention)
	
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
					if datafile and filename == datafile.name then
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
