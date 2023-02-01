buf = {}

i2c.setup(0,1,2,i2c.SLOW)	-- SCD41 sensor
scd40 = require"scd40"
scd40:init(0)

i2c.setup(1,1,4,i2c.SLOW)	-- indicator
ind = require"tm1637"
ind:init(1, 4, '0000')
itimer = tmr.create()
k1 = 0
itimer:alarm(100, tmr.ALARM_AUTO, function()
	local key = ind:readKeysAndUpdate()
	if not key and k1 > 0 then
		if k1 < 5 then ind:setDcode(5,0x80)
		else ind:setDcode(5,0x0)
		end
		k1 = 0
	end
	if key == 1 then k1 = k1+1 end
end)

scd40:set_automatic_self_calibration_enabled(false)
scd40:start_periodic_measurement()

measurements = 0
function readdata()
	local co2, temp, humi, temp_dec = scd40:read_data()
	ind:setStr(('%4d'):format(co2))
	
	if datafile then
		if measurements == 0 then
			local dt = rtctime.epoch2cal(rtctime.get())
			datafile:writeline(('#Start: %02d.%02d.%4d %2d:%02d')
						:format(dt.day, dt.mon, dt.year, dt.hour, dt.min))
			datafile:writeline('#Interval: 5s')
			datafile:writeline('co2ppm,t,Rh')
		end
		datafile:writeline(('%d,%d.%d,%d'):format(co2, temp, temp_dec, humi))
		measurements = measurements + 1
		if datasocket then
			datasocket:send(('%d,%d.%d,%d\n'):format(co2, temp, temp_dec, humi))
		end
		if measurements > 720 then
			datafile:close()
			datafile = nil
			dfname = nil
			if datasocket then
				datasocket:close()
				datasocket = nil
			end
			measurements = 0
		end
	end
end

rdtimer = tmr.create()
rdtimer:alarm(5000, tmr.ALARM_AUTO, readdata)
