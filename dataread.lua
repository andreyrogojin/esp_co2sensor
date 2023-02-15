i2c.setup(0,1,2,i2c.SLOW)	-- SCD41 sensor
scd40 = require"scd40"
scd40:init(0)

i2c.setup(1,1,4,i2c.SLOW)	-- indicator
ind = require"tm1637"
ind:init(1, 4, '0000')
ind:setBit(5, 6, 1)			-- No datetime

itimer = tmr.create()
itimer:alarm(200, tmr.ALARM_AUTO, function()
	local key = ind:readKeysAndUpdate()
	if key == 1 then
		if not k1wasPressed then
			k1wasPressed = true
			if not datafile then newDatafile()
			else stopRecord()
			end
		end
	else
		k1wasPressed = false
	end
end)

scd40:set_automatic_self_calibration_enabled(false)
scd40:start_periodic_measurement()

measurements = 0
function readdata()
	local co2, temp, humi, temp_dec = scd40:read_data()
	ind:setStr(('%4d'):format(co2))
	
	if datafile then
		datafile.fd:writeline(('%d,%d.%d,%d'):format(co2, temp, temp_dec, humi))
		measurements = measurements + 1
		if datafile.socket then
			datafile.socket:send(('%d,%d.%d,%d\n'):format(co2, temp, temp_dec, humi))
		end
		if measurements > 720 then
			stopRecord()
		end
	end
end

rdtimer = tmr.create()
rdtimer:alarm(5000, tmr.ALARM_AUTO, readdata)
